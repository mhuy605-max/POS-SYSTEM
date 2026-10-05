import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dakao_in_bill/backup/backup_models.dart';
import 'package:dakao_in_bill/backup/backup_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late ProductImageStore images;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dakao-backup-create-');
    database = AppDatabase(NativeDatabase.memory());
    images = ProductImageStore(root);
    await _populateAllTables(database, root);
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test(
    'creates deterministic versioned archive with all V1 state and image',
    () async {
      final service = BackupService(
        database: database,
        imageStore: images,
        nowUtc: () => DateTime.utc(2026, 10, 2, 6, 30),
        appVersion: '0.1.0+1',
      );
      final beforeOrderCount = await database.select(database.orders).get();
      final beforeImage = await images
          .resolve('product-images/menu.png')
          .readAsBytes();

      final first = await service.createArchive();
      final second = await service.createArchive();

      expect(
        first.suggestedFileName,
        'dakao-in-bill-20261002-063000.dakbackup',
      );
      expect(first.bytes, second.bytes);
      expect(first.manifest.magic, BackupManifest.magicValue);
      expect(first.manifest.formatVersion, 1);
      expect(first.manifest.schemaVersion, database.schemaVersion);
      expect(first.manifest.appVersion, '0.1.0+1');
      expect(first.manifest.createdAtUtc, '2026-10-02T06:30:00.000Z');

      final archive = ZipDecoder().decodeBytes(first.bytes);
      expect(archive.map((entry) => entry.name), <String>[
        'data.json',
        'images/product-images/menu.png',
        'manifest.json',
      ]);
      final dataBytes = archive.find('data.json')!.content;
      final imageBytes = archive
          .find('images/product-images/menu.png')!
          .content;
      final manifestJson = jsonDecode(
        utf8.decode(archive.find('manifest.json')!.content),
      ) as Map<String, Object?>;
      final data = jsonDecode(utf8.decode(dataBytes)) as Map<String, Object?>;
      final tables = data['tables']! as Map<String, Object?>;

      expect(tables.keys, <String>[
        'categories',
        'products',
        'orders',
        'order_items',
        'print_attempts',
        'app_settings',
        'printer_settings',
      ]);
      expect((tables['categories']! as List<Object?>), hasLength(2));
      final products = tables['products']! as List<Object?>;
      expect(products, hasLength(2));
      expect(products.last, containsPair('deleted_at', 700));
      expect(
        products.first,
        containsPair('image_path', 'product-images/menu.png'),
      );
      final orders = tables['orders']! as List<Object?>;
      expect(orders, hasLength(3));
      expect(orders[1], containsPair('status', 'PAID'));
      expect(orders[1], containsPair('paid_at', 500));
      expect(orders[1], containsPair('printed_at', 550));
      expect(orders[1], containsPair('print_count', 2));
      expect(orders[2], containsPair('status', 'CANCELLED'));
      expect(orders[2], containsPair('cancelled_at', 650));
      expect(
        orders[0],
        containsPair('receipt_settings_snapshot', contains('Quán cũ')),
      );
      expect(tables['order_items'], hasLength(3));
      expect(tables['print_attempts'], hasLength(2));
      expect(tables['app_settings'], hasLength(1));
      expect(tables['printer_settings'], hasLength(1));
      expect(imageBytes, <int>[137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);

      final entries = manifestJson['entries']! as Map<String, Object?>;
      expect(entries['data.json'], <String, Object>{
        'size': dataBytes.length,
        'sha256': sha256.convert(dataBytes).toString(),
      });
      expect(entries['images/product-images/menu.png'], <String, Object>{
        'size': imageBytes.length,
        'sha256': sha256.convert(imageBytes).toString(),
      });
      expect(await database.select(database.orders).get(), beforeOrderCount);
      expect(
        await images.resolve('product-images/menu.png').readAsBytes(),
        beforeImage,
      );
    },
  );

  test('missing referenced image fails without changing live state', () async {
    await images.resolve('product-images/menu.png').delete();
    final service = BackupService(
      database: database,
      imageStore: images,
      nowUtc: () => DateTime.utc(2026, 10, 2),
      appVersion: '0.1.0+1',
    );
    final before = await database.select(database.products).get();

    await expectLater(
      service.createArchive(),
      throwsA(isA<BackupCreationException>()),
    );

    expect(await database.select(database.products).get(), before);
  });
}

Future<void> _populateAllTables(AppDatabase database, Directory root) async {
  await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(10),
          name: 'Cơm',
          sortOrder: const Value(1),
          createdAt: 100,
          updatedAt: 110,
        ),
      );
  await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(11),
          name: 'Nước',
          isActive: const Value(false),
          createdAt: 120,
          updatedAt: 130,
        ),
      );
  final image = File(
    '${root.path}${Platform.pathSeparator}product-images${Platform.pathSeparator}menu.png',
  );
  await image.parent.create(recursive: true);
  await image.writeAsBytes(<int>[137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);
  await database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          id: const Value(20),
          categoryId: 10,
          name: 'Cơm tấm',
          description: const Value('Sườn'),
          price: 45000,
          imagePath: const Value('product-images/menu.png'),
          sortOrder: const Value(2),
          createdAt: 200,
          updatedAt: 210,
        ),
      );
  await database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          id: const Value(21),
          categoryId: 11,
          name: 'Trà đá',
          price: 5000,
          isAvailable: const Value(false),
          createdAt: 220,
          updatedAt: 230,
          deletedAt: const Value(700),
        ),
      );
  const receipt =
      '{"version":1,"shopName":"Quán cũ","address":"A","phone":"1","footer":"F"}';
  await _insertOrder(
    database,
    30,
    1,
    'token-unpaid',
    'UNPAID',
    45000,
    300,
    receipt,
  );
  await _insertOrder(
    database,
    31,
    2,
    'token-paid',
    'PAID',
    5000,
    400,
    receipt,
    paidAt: 500,
    printedAt: 550,
    printCount: 2,
  );
  await _insertOrder(
    database,
    32,
    3,
    'token-cancelled',
    'CANCELLED',
    45000,
    600,
    receipt,
    paidAt: 620,
    cancelledAt: 650,
    cancellationReason: 'Khách đổi ý',
  );
  await _insertItem(database, 40, 30, 20, 'Cơm tấm cũ', 45000);
  await _insertItem(database, 41, 31, 21, 'Trà đá cũ', 5000);
  await _insertItem(database, 42, 32, null, 'Món đã xóa', 45000);
  await database
      .into(database.printAttempts)
      .insert(
        PrintAttemptsCompanion.insert(
          id: const Value(50),
          orderId: 31,
          attemptedAt: 540,
          success: true,
        ),
      );
  await database
      .into(database.printAttempts)
      .insert(
        PrintAttemptsCompanion.insert(
          id: const Value(51),
          orderId: 31,
          attemptedAt: 545,
          success: false,
          errorMessage: const Value('WRITE_FAILED|Lỗi'),
        ),
      );
  await (database.update(
    database.appSettings,
  )..where((row) => row.id.equals(1))).write(
    const AppSettingsCompanion(
      shopName: Value('Đakao'),
      address: Value('42 Đinh Tiên Hoàng'),
      phone: Value('0908'),
      receiptFooter: Value('Cảm ơn'),
    ),
  );
  await (database.update(
    database.printerSettings,
  )..where((row) => row.id.equals(1))).write(
    const PrinterSettingsCompanion(
      printerName: Value('MP-58N'),
      printerAddress: Value('AA:BB:CC:DD:EE:FF'),
      autoReconnect: Value(false),
      autoPrint: Value(true),
    ),
  );
}

Future<void> _insertOrder(
  AppDatabase database,
  int id,
  int number,
  String token,
  String status,
  int total,
  int createdAt,
  String receipt, {
  int? paidAt,
  int? cancelledAt,
  int? printedAt,
  int printCount = 0,
  String? cancellationReason,
}) => database
    .into(database.orders)
    .insert(
      OrdersCompanion.insert(
        id: Value(id),
        orderNumber: number,
        submissionToken: token,
        status: Value(status),
        subtotal: total,
        total: total,
        createdAt: createdAt,
        paidAt: Value(paidAt),
        cancelledAt: Value(cancelledAt),
        printedAt: Value(printedAt),
        printCount: Value(printCount),
        cancellationReason: Value(cancellationReason),
        receiptSettingsSnapshot: receipt,
      ),
    );

Future<void> _insertItem(
  AppDatabase database,
  int id,
  int orderId,
  int? productId,
  String name,
  int total,
) => database
    .into(database.orderItems)
    .insert(
      OrderItemsCompanion.insert(
        id: Value(id),
        orderId: orderId,
        productId: Value(productId),
        productNameSnapshot: name,
        unitPriceSnapshot: total,
        quantity: 1,
        lineTotal: total,
      ),
    );
