import 'dart:io';

import 'package:dakao_in_bill/core/money.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;
  late AppDatabase database;
  late ProductRepository products;
  late ProductOptionRepository options;
  late OrderRepository orders;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'dakao_order_options_',
    );
    databaseFile = File('${tempDirectory.path}/orders.sqlite');
    database = AppDatabase.openFile(databaseFile);
    products = ProductRepository(database, () => 1700000000000);
    options = ProductOptionRepository(database, () => 1700000000000);
    orders = OrderRepository(
      database,
      nowEpochMillis: () => 1700000000000,
      productOptionRepository: options,
    );
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'zero-option order preserves V1 price and empty option behavior',
    () async {
      final productId = await _createProduct(products, 'Cơm', 35000);

      final orderId = await orders.createOrder(
        _draft(
          token: 'zero-options',
          productId: productId,
          productName: 'Cơm',
          basePrice: 35000,
        ),
      );

      final saved = await orders.loadOrder(orderId);
      expect(saved.total, 35000);
      expect(saved.items.single.baseUnitPrice, 35000);
      expect(saved.items.single.unitPrice, 35000);
      expect(saved.items.single.lineTotal, 35000);
      expect(saved.items.single.options, isEmpty);
      expect(await database.select(database.orderItemOptions).get(), isEmpty);
    },
  );

  test('persists multiple groups canonically with base, effective, line and order totals', () async {
    final productId = await _createProduct(products, 'Cơm sườn', 35000);
    final extras = await options.createGroup('Món thêm');
    final sauces = await options.createGroup('Nước sốt');
    final pork = await _createOption(options, extras, 'Sườn thêm', 45000);
    final egg = await _createOption(options, extras, 'Trứng thêm', 30000);
    final pepper = await _createOption(options, sauces, 'Sốt tiêu', 5000);
    await options.reorderOptions(extras, [egg, pork]);
    await options.setProductOptionGroups(productId, [sauces, extras]);

    final orderId = await orders.createOrder(
      _draft(
        token: 'multiple-options',
        productId: productId,
        productName: 'Cơm sườn',
        basePrice: 35000,
        effectivePrice: 115000,
        quantity: 2,
        selectedOptions: [
          _reviewedOption(
            optionId: pepper,
            groupId: sauces,
            groupName: 'Nước sốt',
            optionName: 'Sốt tiêu',
            price: 5000,
          ),
          _reviewedOption(
            optionId: pork,
            groupId: extras,
            groupName: 'Món thêm',
            optionName: 'Sườn thêm',
            price: 45000,
          ),
          _reviewedOption(
            optionId: egg,
            groupId: extras,
            groupName: 'Món thêm',
            optionName: 'Trứng thêm',
            price: 30000,
          ),
        ],
      ),
    );
    await database.close();
    database = AppDatabase.openFile(databaseFile);
    orders = OrderRepository(database, nowEpochMillis: () => 1700000000001);

    final saved = await orders.loadOrder(orderId);
    final item = saved.items.single;
    expect(saved.subtotal, 230000);
    expect(saved.total, 230000);
    expect(item.baseUnitPrice, 35000);
    expect(item.unitPrice, 115000);
    expect(item.lineTotal, 230000);
    expect(item.options.map((option) => option.optionItemId), [
      egg,
      pork,
      pepper,
    ]);
    expect(item.options.map((option) => option.displayOrder), [0, 1, 2]);
    expect(item.options.map((option) => option.priceDelta), [
      30000,
      45000,
      5000,
    ]);
  });

  test('catalog mutations never reinterpret saved option snapshots', () async {
    final fixture = await _fixture(products, options);
    final draft = fixture.draft('immutable');
    final orderId = await orders.createOrder(draft);

    await options.renameGroup(fixture.groupId, 'Nhóm mới');
    await options.updateOption(
      fixture.optionId,
      name: 'Sườn thêm mới',
      priceDelta: 50000,
    );
    await options.setOptionActive(fixture.optionId, false);
    await options.setGroupActive(fixture.groupId, false);
    await options.detachGroupFromProduct(fixture.productId, fixture.groupId);

    final saved = await orders.loadOrder(orderId);
    final snapshot = saved.items.single.options.single;
    expect(snapshot.groupName, 'Món thêm');
    expect(snapshot.optionName, 'Sườn thêm');
    expect(snapshot.priceDelta, 45000);
    expect(saved.items.single.baseUnitPrice, 35000);
    expect(saved.items.single.unitPrice, 80000);
  });

  test(
    'stale price, option name, and group name are rejected atomically',
    () async {
      final priceFixture = await _fixture(products, options, suffix: 'price');
      final stalePrice = priceFixture.draft('stale-price');
      await options.updateOption(
        priceFixture.optionId,
        name: 'Sườn thêm',
        priceDelta: 50000,
      );
      await expectLater(
        orders.createOrder(stalePrice),
        throwsA(isA<DomainValidationException>()),
      );

      final optionFixture = await _fixture(products, options, suffix: 'option');
      final staleOptionName = optionFixture.draft('stale-option-name');
      await options.updateOption(
        optionFixture.optionId,
        name: 'Tên mới',
        priceDelta: 45000,
      );
      await expectLater(
        orders.createOrder(staleOptionName),
        throwsA(isA<DomainValidationException>()),
      );

      final groupFixture = await _fixture(products, options, suffix: 'group');
      final staleGroupName = groupFixture.draft('stale-group-name');
      await options.renameGroup(groupFixture.groupId, 'Nhóm mới');
      await expectLater(
        orders.createOrder(staleGroupName),
        throwsA(isA<DomainValidationException>()),
      );

      await _expectNoPartialRows(database);
    },
  );

  test(
    'inactive or detached catalog configuration is rejected atomically',
    () async {
      final inactiveOption = await _fixture(products, options, suffix: 'item');
      final itemDraft = inactiveOption.draft('inactive-option');
      await options.setOptionActive(inactiveOption.optionId, false);
      await expectLater(
        orders.createOrder(itemDraft),
        throwsA(isA<DomainValidationException>()),
      );

      final inactiveGroup = await _fixture(products, options, suffix: 'group');
      final groupDraft = inactiveGroup.draft('inactive-group');
      await options.setGroupActive(inactiveGroup.groupId, false);
      await expectLater(
        orders.createOrder(groupDraft),
        throwsA(isA<DomainValidationException>()),
      );

      final detached = await _fixture(products, options, suffix: 'detach');
      final detachedDraft = detached.draft('detached-group');
      await options.detachGroupFromProduct(
        detached.productId,
        detached.groupId,
      );
      await expectLater(
        orders.createOrder(detachedDraft),
        throwsA(isA<DomainValidationException>()),
      );

      await _expectNoPartialRows(database);
    },
  );

  test(
    'duplicate, mismatched, and nonexistent reviewed options are rejected',
    () async {
      final fixture = await _fixture(products, options);
      final reviewed = fixture.reviewedOption;
      final invalidDrafts = <OrderDraft>[
        fixture.draft('duplicate', selectedOptions: [reviewed, reviewed]),
        fixture.draft(
          'wrong-group',
          selectedOptions: [
            DraftSelectedOption(
              optionItemId: fixture.optionId,
              optionGroupId: fixture.groupId + 999,
              reviewedGroupName: 'Món thêm',
              reviewedOptionName: 'Sườn thêm',
              reviewedPriceDelta: 45000,
            ),
          ],
        ),
        fixture.draft(
          'missing-option',
          selectedOptions: [
            DraftSelectedOption(
              optionItemId: 999999,
              optionGroupId: fixture.groupId,
              reviewedGroupName: 'Món thêm',
              reviewedOptionName: 'Sườn thêm',
              reviewedPriceDelta: 45000,
            ),
          ],
        ),
      ];

      for (final draft in invalidDrafts) {
        await expectLater(
          orders.createOrder(draft),
          throwsA(isA<DomainValidationException>()),
        );
      }
      await _expectNoPartialRows(database);
    },
  );

  test(
    'effective, option-sum, configured, and order overflows save nothing',
    () async {
      final fixture = await _fixture(products, options);
      await expectLater(
        orders.createOrder(
          fixture.draft('wrong-effective', effectivePrice: 79999),
        ),
        throwsA(isA<DomainValidationException>()),
      );

      final overflowProduct = await _createProduct(
        products,
        'Giá lớn',
        sqliteMaxInteger - 5,
      );
      final overflowGroup = await options.createGroup('Thêm lớn');
      final overflowOption = await _createOption(
        options,
        overflowGroup,
        'Thêm',
        10,
      );
      await options.attachGroupToProduct(overflowProduct, overflowGroup);
      await expectLater(
        orders.createOrder(
          _draft(
            token: 'overflow',
            productId: overflowProduct,
            productName: 'Giá lớn',
            basePrice: sqliteMaxInteger - 5,
            effectivePrice: sqliteMaxInteger,
            selectedOptions: [
              _reviewedOption(
                optionId: overflowOption,
                groupId: overflowGroup,
                groupName: 'Thêm lớn',
                optionName: 'Thêm',
                price: 10,
              ),
            ],
          ),
        ),
        throwsA(isA<DomainValidationException>()),
      );

      final optionSumProduct = await _createProduct(
        products,
        'Tổng tùy chọn',
        0,
      );
      final optionSumGroup = await options.createGroup('Nhóm tổng');
      final maximum = await _createOption(
        options,
        optionSumGroup,
        'Tối đa',
        sqliteMaxInteger,
      );
      final plusOne = await _createOption(options, optionSumGroup, 'Một', 1);
      await options.attachGroupToProduct(optionSumProduct, optionSumGroup);
      await expectLater(
        orders.createOrder(
          _draft(
            token: 'option-sum-overflow',
            productId: optionSumProduct,
            productName: 'Tổng tùy chọn',
            basePrice: 0,
            effectivePrice: sqliteMaxInteger,
            selectedOptions: [
              _reviewedOption(
                optionId: maximum,
                groupId: optionSumGroup,
                groupName: 'Nhóm tổng',
                optionName: 'Tối đa',
                price: sqliteMaxInteger,
              ),
              _reviewedOption(
                optionId: plusOne,
                groupId: optionSumGroup,
                groupName: 'Nhóm tổng',
                optionName: 'Một',
                price: 1,
              ),
            ],
          ),
        ),
        throwsA(isA<DomainValidationException>()),
      );

      final halfPlusOne = sqliteMaxInteger ~/ 2 + 1;
      final orderTotalProduct = await _createProduct(
        products,
        'Tổng đơn lớn',
        halfPlusOne,
      );
      await expectLater(
        orders.createOrder(
          OrderDraft(
            submissionToken: 'order-total-overflow',
            lines: [
              for (var index = 0; index < 2; index++)
                DraftLine(
                  productId: orderTotalProduct,
                  reviewedName: 'Tổng đơn lớn',
                  reviewedUnitPrice: halfPlusOne,
                  quantity: 1,
                ),
            ],
          ),
        ),
        throwsA(isA<DomainValidationException>()),
      );

      await _expectNoPartialRows(database);
    },
  );

  test(
    'same submission token returns original snapshots after catalog changes',
    () async {
      final fixture = await _fixture(products, options);
      final draft = fixture.draft('idempotent-options');
      final firstId = await orders.createOrder(draft);
      await options.updateOption(
        fixture.optionId,
        name: 'Tên mới',
        priceDelta: 50000,
      );

      final retryId = await orders.createOrder(draft);

      expect(retryId, firstId);
      expect(await database.select(database.orders).get(), hasLength(1));
      expect(await database.select(database.orderItems).get(), hasLength(1));
      expect(
        await database.select(database.orderItemOptions).get(),
        hasLength(1),
      );
      final snapshot = (await orders.loadOrder(firstId))
          .items
          .single
          .options
          .single;
      expect(snapshot.optionName, 'Sườn thêm');
      expect(snapshot.priceDelta, 45000);
    },
  );

  test(
    'option snapshot insertion failure rolls back the whole order',
    () async {
      final fixture = await _fixture(products, options);
      await database.customStatement('''
      CREATE TRIGGER force_option_snapshot_failure
      BEFORE INSERT ON order_item_options
      BEGIN
        SELECT RAISE(ABORT, 'forced option snapshot failure');
      END
    ''');

      await expectLater(
        orders.createOrder(fixture.draft('snapshot-failure')),
        throwsA(anything),
      );

      await _expectNoPartialRows(database);
    },
  );
}

final class _Fixture {
  const _Fixture({
    required this.productId,
    required this.groupId,
    required this.optionId,
  });

  final int productId;
  final int groupId;
  final int optionId;

  DraftSelectedOption get reviewedOption => _reviewedOption(
    optionId: optionId,
    groupId: groupId,
    groupName: 'Món thêm',
    optionName: 'Sườn thêm',
    price: 45000,
  );

  OrderDraft draft(
    String token, {
    int effectivePrice = 80000,
    List<DraftSelectedOption>? selectedOptions,
  }) {
    return _draft(
      token: token,
      productId: productId,
      productName: 'Cơm sườn',
      basePrice: 35000,
      effectivePrice: effectivePrice,
      selectedOptions: selectedOptions ?? [reviewedOption],
    );
  }
}

Future<_Fixture> _fixture(
  ProductRepository products,
  ProductOptionRepository options, {
  String suffix = '',
}) async {
  final productId = await _createProduct(products, 'Cơm sườn', 35000);
  final groupId = await options.createGroup('Món thêm');
  final optionId = await _createOption(options, groupId, 'Sườn thêm', 45000);
  await options.attachGroupToProduct(productId, groupId);
  return _Fixture(productId: productId, groupId: groupId, optionId: optionId);
}

OrderDraft _draft({
  required String token,
  required int productId,
  required String productName,
  required int basePrice,
  int? effectivePrice,
  int quantity = 1,
  List<DraftSelectedOption> selectedOptions = const [],
}) {
  return OrderDraft(
    submissionToken: token,
    lines: [
      DraftLine(
        productId: productId,
        reviewedName: productName,
        reviewedBaseUnitPrice: basePrice,
        reviewedUnitPrice: effectivePrice ?? basePrice,
        quantity: quantity,
        selectedOptions: selectedOptions,
      ),
    ],
  );
}

DraftSelectedOption _reviewedOption({
  required int optionId,
  required int groupId,
  required String groupName,
  required String optionName,
  required int price,
}) {
  return DraftSelectedOption(
    optionItemId: optionId,
    optionGroupId: groupId,
    reviewedGroupName: groupName,
    reviewedOptionName: optionName,
    reviewedPriceDelta: price,
  );
}

Future<int> _createProduct(
  ProductRepository products,
  String name,
  int price,
) async {
  final categories = await products.listCategories();
  final categoryId = categories.isEmpty
      ? await products.createCategory('Danh mục')
      : categories.first.id;
  return products.createProduct(
    ProductDraft(categoryId: categoryId, name: name, price: price),
  );
}

Future<int> _createOption(
  ProductOptionRepository options,
  int groupId,
  String name,
  int price,
) {
  return options.createOption(groupId: groupId, name: name, priceDelta: price);
}

Future<void> _expectNoPartialRows(AppDatabase database) async {
  expect(await database.select(database.orders).get(), isEmpty);
  expect(await database.select(database.orderItems).get(), isEmpty);
  expect(await database.select(database.orderItemOptions).get(), isEmpty);
}
