import 'dart:io';

import 'package:dakao_in_bill/core/money.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;
  late AppDatabase database;
  late OrderRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('dakao_order_test_');
    databaseFile = File('${tempDirectory.path}/orders.sqlite');
    database = AppDatabase.openFile(databaseFile);
    repository = OrderRepository(database, nowEpochMillis: () => 1700000000000);
    await _setReceiptSettings(database, shopName: 'Đakao', footer: 'Cảm ơn');
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'complete order creation atomically saves totals and snapshots',
    () async {
      final productId = await _insertProduct(
        database,
        name: 'Bánh mì',
        price: 45000,
      );

      final id = await repository.createOrder(
        OrderDraft(
          submissionToken: 'token-complete',
          orderType: OrderType.takeaway,
          lines: <DraftLine>[
            DraftLine(
              productId: productId,
              reviewedName: 'Bánh mì',
              reviewedUnitPrice: 45000,
              quantity: 2,
              note: 'Ít cay',
            ),
          ],
        ),
      );

      final saved = await repository.loadOrder(id);
      expect(saved.orderNumber, 1);
      expect(saved.status, OrderStatus.unpaid);
      expect(saved.orderType, OrderType.takeaway);
      expect(saved.subtotal, 90000);
      expect(saved.total, 90000);
      expect(saved.paidAt, isNull);
      expect(saved.items, hasLength(1));
      expect(saved.items.single.productName, 'Bánh mì');
      expect(saved.items.single.unitPrice, 45000);
      expect(saved.items.single.quantity, 2);
      expect(saved.items.single.note, 'Ít cay');
      expect(saved.items.single.lineTotal, 90000);
      expect(saved.receiptSettings.version, 1);
      expect(saved.receiptSettings.shopName, 'Đakao');
      expect(saved.receiptSettings.footer, 'Cảm ơn');
    },
  );

  test('failure during item insertion rolls back the complete order', () async {
    final productId = await _insertProduct(database, name: 'Cơm', price: 45000);
    await database.customStatement('''
      CREATE TRIGGER force_second_item_failure
      BEFORE INSERT ON order_items
      WHEN NEW.note = 'force failure'
      BEGIN
        SELECT RAISE(ABORT, 'forced item failure');
      END
    ''');

    await expectLater(
      repository.createOrder(
        OrderDraft(
          submissionToken: 'token-rollback',
          lines: <DraftLine>[
            DraftLine(
              productId: productId,
              reviewedName: 'Cơm',
              reviewedUnitPrice: 45000,
              quantity: 1,
            ),
            DraftLine(
              productId: productId,
              reviewedName: 'Cơm',
              reviewedUnitPrice: 45000,
              quantity: 1,
              note: 'force failure',
            ),
          ],
        ),
      ),
      throwsA(anything),
    );

    expect(await database.select(database.orders).get(), isEmpty);
    expect(await database.select(database.orderItems).get(), isEmpty);

    final nextId = await repository.createOrder(
      _draft(
        token: 'token-after-rollback',
        productId: productId,
        name: 'Cơm',
        price: 45000,
      ),
    );
    expect((await repository.loadOrder(nextId)).orderNumber, 1);
  });

  test(
    'duplicate submission token returns one order and one set of items',
    () async {
      final productId = await _insertProduct(
        database,
        name: 'Bún',
        price: 35000,
      );
      final firstDraft = _draft(
        token: 'same-token',
        productId: productId,
        name: 'Bún',
        price: 35000,
      );

      final firstId = await repository.createOrder(firstDraft);
      final secondId = await repository.createOrder(firstDraft);

      expect(secondId, firstId);
      expect(await database.select(database.orders).get(), hasLength(1));
      expect(await database.select(database.orderItems).get(), hasLength(1));
    },
  );

  test(
    'duplicate submission token consumes no additional order number',
    () async {
      final productId = await _insertProduct(
        database,
        name: 'Phở',
        price: 50000,
      );
      final duplicate = _draft(
        token: 'number-token',
        productId: productId,
        name: 'Phở',
        price: 50000,
      );

      await repository.createOrder(duplicate);
      await repository.createOrder(duplicate);
      final nextId = await repository.createOrder(
        _draft(
          token: 'next-token',
          productId: productId,
          name: 'Phở',
          price: 50000,
        ),
      );

      expect((await repository.loadOrder(nextId)).orderNumber, 2);
    },
  );

  test(
    'concurrent order creation allocates unique increasing numbers',
    () async {
      final productId = await _insertProduct(
        database,
        name: 'Trà',
        price: 20000,
      );

      final ids = await Future.wait(
        List<Future<int>>.generate(
          20,
          (index) => repository.createOrder(
            _draft(
              token: 'concurrent-$index',
              productId: productId,
              name: 'Trà',
              price: 20000,
            ),
          ),
        ),
      );
      final orders = await Future.wait(ids.map(repository.loadOrder));
      final numbers = orders.map((order) => order.orderNumber).toList()..sort();

      expect(numbers.toSet(), hasLength(20));
      expect(numbers, List<int>.generate(20, (index) => index + 1));
    },
  );

  test('product rename does not alter historical item name', () async {
    final productId = await _insertProduct(
      database,
      name: 'Tên cũ',
      price: 10000,
    );
    final id = await repository.createOrder(
      _draft(
        token: 'rename',
        productId: productId,
        name: 'Tên cũ',
        price: 10000,
      ),
    );

    await (database.update(database.products)
          ..where((row) => row.id.equals(productId)))
        .write(const ProductsCompanion(name: Value('Tên mới')));

    expect((await repository.loadOrder(id)).items.single.productName, 'Tên cũ');
  });

  test('product repricing does not alter historical item price', () async {
    final productId = await _insertProduct(database, name: 'Món', price: 10000);
    final id = await repository.createOrder(
      _draft(token: 'reprice', productId: productId, name: 'Món', price: 10000),
    );

    await (database.update(database.products)
          ..where((row) => row.id.equals(productId)))
        .write(const ProductsCompanion(price: Value(99000)));

    final saved = await repository.loadOrder(id);
    expect(saved.items.single.unitPrice, 10000);
    expect(saved.total, 10000);
  });

  test('availability change does not alter historical item snapshot', () async {
    final productId = await _insertProduct(database, name: 'Món', price: 12000);
    final id = await repository.createOrder(
      _draft(
        token: 'availability',
        productId: productId,
        name: 'Món',
        price: 12000,
      ),
    );

    await (database.update(database.products)
          ..where((row) => row.id.equals(productId)))
        .write(const ProductsCompanion(isAvailable: Value(false)));

    expect((await repository.loadOrder(id)).items.single.lineTotal, 12000);
  });

  test('soft deletion does not alter historical item snapshot', () async {
    final productId = await _insertProduct(database, name: 'Món', price: 13000);
    final id = await repository.createOrder(
      _draft(
        token: 'soft-delete',
        productId: productId,
        name: 'Món',
        price: 13000,
      ),
    );

    await (database.update(database.products)
          ..where((row) => row.id.equals(productId)))
        .write(const ProductsCompanion(deletedAt: Value(1700000001000)));

    expect((await repository.loadOrder(id)).items.single.productName, 'Món');
  });

  test('receipt setting changes do not alter saved receipt snapshot', () async {
    final productId = await _insertProduct(database, name: 'Món', price: 14000);
    final id = await repository.createOrder(
      _draft(token: 'receipt', productId: productId, name: 'Món', price: 14000),
    );

    await _setReceiptSettings(database, shopName: 'Quán mới', footer: 'Mới');

    final snapshot = (await repository.loadOrder(id)).receiptSettings;
    expect(snapshot.shopName, 'Đakao');
    expect(snapshot.footer, 'Cảm ơn');
  });

  test(
    'invalid quantity, negative money, and overflow save no order',
    () async {
      final productId = await _insertProduct(
        database,
        name: 'Món',
        price: 15000,
      );
      final invalidLines = <DraftLine>[
        DraftLine(
          productId: productId,
          reviewedName: 'Món',
          reviewedUnitPrice: 15000,
          quantity: 0,
        ),
        DraftLine(
          productId: productId,
          reviewedName: 'Món',
          reviewedUnitPrice: -1,
          quantity: 1,
        ),
        DraftLine(
          productId: productId,
          reviewedName: 'Món',
          reviewedUnitPrice: sqliteMaxInteger,
          quantity: 2,
        ),
      ];

      for (var index = 0; index < invalidLines.length; index++) {
        await expectLater(
          repository.createOrder(
            OrderDraft(
              submissionToken: 'invalid-$index',
              lines: <DraftLine>[invalidLines[index]],
            ),
          ),
          throwsA(isA<DomainValidationException>()),
        );
      }

      expect(await database.select(database.orders).get(), isEmpty);
    },
  );

  test(
    'historical item and receipt snapshots survive database reopen',
    () async {
      final productId = await _insertProduct(
        database,
        name: 'Bánh',
        price: 16000,
      );
      final id = await repository.createOrder(
        _draft(
          token: 'reopen-snapshot',
          productId: productId,
          name: 'Bánh',
          price: 16000,
        ),
      );
      await database.close();

      database = AppDatabase.openFile(databaseFile);
      repository = OrderRepository(
        database,
        nowEpochMillis: () => 1700000000000,
      );
      final saved = await repository.loadOrder(id);

      expect(saved.items.single.productName, 'Bánh');
      expect(saved.items.single.unitPrice, 16000);
      expect(saved.receiptSettings.shopName, 'Đakao');
      expect(saved.receiptSettings.version, 1);
    },
  );
}

OrderDraft _draft({
  required String token,
  required int productId,
  required String name,
  required int price,
}) {
  return OrderDraft(
    submissionToken: token,
    lines: <DraftLine>[
      DraftLine(
        productId: productId,
        reviewedName: name,
        reviewedUnitPrice: price,
        quantity: 1,
      ),
    ],
  );
}

Future<int> _insertProduct(
  AppDatabase database, {
  required String name,
  required int price,
}) async {
  final categoryId = await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(
          name: 'Danh mục $name',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
  return database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          categoryId: categoryId,
          name: name,
          price: price,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      );
}

Future<void> _setReceiptSettings(
  AppDatabase database, {
  required String shopName,
  required String footer,
}) {
  return (database.update(
    database.appSettings,
  )..where((row) => row.id.equals(1))).write(
    AppSettingsCompanion(
      shopName: Value(shopName),
      address: const Value('1 Đakao'),
      phone: const Value('0900000000'),
      receiptFooter: Value(footer),
    ),
  );
}
