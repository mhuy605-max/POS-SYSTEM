import 'dart:io';

import 'package:dakao_in_bill/backup/backup_data_codec.dart';
import 'package:dakao_in_bill/backup/backup_service.dart';
import 'package:dakao_in_bill/backup/backup_validator.dart';
import 'package:dakao_in_bill/backup/restore_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late File sourceFile;
  late File liveFile;
  late Directory sourceFiles;
  late Directory liveFiles;
  late Directory journal;
  late AppDatabase source;
  late AppDatabase live;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dakao-restore-');
    sourceFile = File('${root.path}${Platform.pathSeparator}source.sqlite');
    liveFile = File('${root.path}${Platform.pathSeparator}live.sqlite');
    sourceFiles = Directory(
      '${root.path}${Platform.pathSeparator}source-files',
    );
    liveFiles = Directory('${root.path}${Platform.pathSeparator}live-files');
    journal = Directory('${root.path}${Platform.pathSeparator}restore-journal');
    source = AppDatabase.openFile(sourceFile);
    live = AppDatabase.openFile(liveFile);
    await _populateSource(source, sourceFiles);
    await _populateOldLive(live, liveFiles);
  });

  tearDown(() async {
    await source.close();
    await live.close();
    await root.delete(recursive: true);
  });

  test(
    'round trip restores every table, images, and survives reopen',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final sourceCanonical = await BackupDataCodec(source).exportCanonical();
      final sourceRevenue = await _paidRevenue(source);
      final service = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
      );

      await service.replaceWith(validated);

      expect(await BackupDataCodec(live).exportCanonical(), sourceCanonical);
      expect(await _paidRevenue(live), sourceRevenue);
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/menu.png')
            .readAsBytes(),
        _validPng,
      );
      expect(await journal.exists(), isFalse);

      await live.close();
      live = AppDatabase.openFile(liveFile);
      expect(await BackupDataCodec(live).exportCanonical(), sourceCanonical);
      expect(await _paidRevenue(live), sourceRevenue);

      await (live.update(live.products)..where((row) => row.id.equals(20)))
          .write(const ProductsCompanion(name: Value('Tên mới')));
      final order = await (live.select(
        live.orders,
      )..where((row) => row.id.equals(30))).getSingle();
      final item = await (live.select(
        live.orderItems,
      )..where((row) => row.id.equals(40))).getSingle();
      expect(order.receiptSettingsSnapshot, contains('Quán nguồn'));
      expect(item.productNameSnapshot, 'Cơm tấm cũ');
      expect(item.baseUnitPriceSnapshot, 35000);
      expect(item.unitPriceSnapshot, 110000);
      final options =
          await (live.select(live.orderItemOptions)
                ..where((row) => row.orderItemId.equals(40))
                ..orderBy([(row) => OrderingTerm.asc(row.displayOrder)]))
              .get();
      expect(options.map((row) => row.optionNameSnapshot), [
        'Sườn thêm',
        'Trứng thêm',
      ]);
      expect(options.map((row) => row.priceDeltaSnapshot), [45000, 30000]);
      final current = await (live.select(
        live.optionItems,
      )..where((row) => row.id.equals(60))).getSingle();
      expect(current.name, 'Sườn đặc biệt');
      expect(current.priceDelta, 50000);
      expect(current.isActive, isFalse);
      final restoredProducts = await (live.select(
        live.products,
      )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
      expect(restoredProducts.map((row) => row.sortOrder), [4, 1]);
      final restoredGroup = await (live.select(
        live.optionGroups,
      )..where((row) => row.id.equals(55))).getSingle();
      expect(restoredGroup.sortOrder, 2);
      final restoredCatalogOptions = await (live.select(
        live.optionItems,
      )..orderBy([(row) => OrderingTerm.asc(row.sortOrder)])).get();
      expect(restoredCatalogOptions.map((row) => row.sortOrder), [0, 1, 2]);
      expect(await live.select(live.productOptionGroups).get(), hasLength(2));
      final saved = await OrderRepository(
        live,
        nowEpochMillis: () => 0,
      ).loadOrder(30);
      final receipt = await const ReceiptRenderer().renderOrder(saved);
      expect(receipt.widthDots, 384);
      expect(saved.receiptSettings.footer, 'Dòng 1\nDòng 2');
    },
  );

  test(
    'failure before database replacement preserves old usable state',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final before = await BackupDataCodec(live).exportCanonical();
      final oldImage = await ProductImageStore(liveFiles)
          .resolve('product-images/old.png')
          .readAsBytes();
      final service = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
        checkpoint: (point) {
          if (point == RestoreCheckpoint.beforeDatabaseReplacement) {
            throw StateError('injected');
          }
        },
      );

      await expectLater(service.replaceWith(validated), throwsStateError);

      expect(await BackupDataCodec(live).exportCanonical(), before);
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/old.png')
            .readAsBytes(),
        oldImage,
      );
      expect(await journal.exists(), isFalse);
    },
  );

  test(
    'failure after database commit recovers a complete target state',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final expected = await BackupDataCodec(source).exportCanonical();
      final service = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
        checkpoint: (point) {
          if (point == RestoreCheckpoint.afterDatabaseReplacement) {
            throw StateError('injected');
          }
        },
      );

      await expectLater(service.replaceWith(validated), throwsStateError);

      expect(await BackupDataCodec(live).exportCanonical(), expected);
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/menu.png')
            .exists(),
        isTrue,
      );
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/old.png')
            .exists(),
        isFalse,
      );
      expect(await journal.exists(), isFalse);
    },
  );

  test(
    'startup reconciliation finishes an interrupted committed restore',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final expected = await BackupDataCodec(source).exportCanonical();
      final interrupted = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
        recoverOnFailure: false,
        checkpoint: (point) {
          if (point == RestoreCheckpoint.afterDatabaseReplacement) {
            throw StateError('simulated process stop');
          }
        },
      );
      await expectLater(interrupted.replaceWith(validated), throwsStateError);
      expect(await journal.exists(), isTrue);

      final startup = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
      );
      await startup.recoverPendingRestore();

      expect(await BackupDataCodec(live).exportCanonical(), expected);
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/menu.png')
            .exists(),
        isTrue,
      );
      expect(await journal.exists(), isFalse);
    },
  );

  test(
    'image activation failure rolls database and images back together',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final before = await BackupDataCodec(live).exportCanonical();
      final service = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
        checkpoint: (point) {
          if (point == RestoreCheckpoint.beforeImagesPrepared) {
            throw const FileSystemException('simulated disk failure');
          }
        },
      );

      await expectLater(
        service.replaceWith(validated),
        throwsA(isA<FileSystemException>()),
      );

      expect(await BackupDataCodec(live).exportCanonical(), before);
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/old.png')
            .exists(),
        isTrue,
      );
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/menu.png')
            .exists(),
        isFalse,
      );
      expect(await journal.exists(), isFalse);
    },
  );

  test(
    'startup rolls an interrupted image directory swap forward safely',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final interrupted = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
        recoverOnFailure: false,
        checkpoint: (point) {
          if (point == RestoreCheckpoint.afterLiveImagesMovedAside) {
            throw StateError('simulated process stop');
          }
        },
      );
      await expectLater(interrupted.replaceWith(validated), throwsStateError);

      final startup = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
      );
      await startup.recoverPendingRestore();

      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/menu.png')
            .exists(),
        isTrue,
      );
      expect(await journal.exists(), isFalse);
    },
  );

  test(
    'startup ignores and removes a journal retired before cleanup',
    () async {
      final validated = await _validatedSource(source, sourceFiles);
      final expected = await BackupDataCodec(source).exportCanonical();
      final interrupted = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
        recoverOnFailure: false,
        checkpoint: (point) {
          if (point == RestoreCheckpoint.afterJournalRetired) {
            throw StateError('simulated process stop');
          }
        },
      );
      await expectLater(interrupted.replaceWith(validated), throwsStateError);
      expect(
        File('${journal.path}${Platform.pathSeparator}marker.json')
            .existsSync(),
        isFalse,
      );
      final stalePrevious = Directory(
        '${liveFiles.path}${Platform.pathSeparator}'
        '${ProductImageStore.directoryName}.restore-previous',
      );
      expect(await stalePrevious.exists(), isTrue);
      final staleImage = File(
        '${stalePrevious.path}${Platform.pathSeparator}old.png',
      );
      if (await staleImage.exists()) await staleImage.delete();

      final startup = RestoreService(
        database: live,
        imageStore: ProductImageStore(liveFiles),
        journalDirectory: journal,
      );
      await startup.recoverPendingRestore();

      expect(await BackupDataCodec(live).exportCanonical(), expected);
      expect(
        await ProductImageStore(liveFiles)
            .resolve('product-images/menu.png')
            .readAsBytes(),
        _validPng,
      );
      expect(await stalePrevious.exists(), isFalse);
      expect(await journal.exists(), isFalse);
    },
  );
}

Future<dynamic> _validatedSource(AppDatabase database, Directory files) async {
  final staged = await BackupService(
    database: database,
    imageStore: ProductImageStore(files),
    nowUtc: () => DateTime.utc(2026, 10, 2),
    appVersion: '0.1.0+1',
  ).createArchive();
  return BackupValidator(schemaVersion: database.schemaVersion)
      .validateBytes(staged.bytes);
}

Future<void> _populateSource(AppDatabase db, Directory files) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(10),
          name: 'Cơm',
          createdAt: 100,
          updatedAt: 100,
        ),
      );
  final image = ProductImageStore(files).resolve('product-images/menu.png');
  await image.parent.create(recursive: true);
  await image.writeAsBytes(_validPng);
  await db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          id: const Value(20),
          categoryId: 10,
          name: 'Cơm tấm',
          price: 35000,
          imagePath: const Value('product-images/menu.png'),
          sortOrder: const Value(4),
          createdAt: 200,
          updatedAt: 200,
        ),
      );
  await db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          id: const Value(21),
          categoryId: 10,
          name: 'Cơm chả',
          price: 40000,
          sortOrder: const Value(1),
          createdAt: 201,
          updatedAt: 201,
        ),
      );
  await db.customStatement(
    'INSERT INTO option_groups '
    '(id, name, sort_order, is_active, created_at, updated_at) '
    "VALUES (55, 'Món thêm', 2, 1, 210, 260)",
  );
  await db.customStatement(
    'INSERT INTO option_items '
    '(id, group_id, name, price_delta, sort_order, is_active, created_at, updated_at) '
    "VALUES (60, 55, 'Sườn đặc biệt', 50000, 0, 0, 220, 270), "
    "(61, 55, 'Trứng thêm', 35000, 1, 1, 221, 271), "
    "(62, 55, 'Bì thêm', 15000, 2, 1, 222, 272)",
  );
  await db.customStatement(
    'INSERT INTO product_option_groups (product_id, option_group_id) '
    'VALUES (20, 55), (21, 55)',
  );
  const receipt =
      '{"version":1,"shopName":"Quán nguồn","address":"A","phone":"1","footer":"Dòng 1\\nDòng 2"}';
  await _order(db, 30, 1, 'unpaid', 'UNPAID', 300, receipt, total: 110000);
  await _order(db, 31, 2, 'paid', 'PAID', 400, receipt, paidAt: 450);
  await _order(
    db,
    32,
    3,
    'cancelled',
    'CANCELLED',
    500,
    receipt,
    paidAt: 520,
    cancelledAt: 550,
  );
  await _item(db, 40, 30, base: 35000, unit: 110000);
  await _item(db, 41, 31);
  await _item(db, 42, 32);
  await db.customStatement(
    'INSERT INTO order_item_options '
    '(id, order_item_id, option_item_id, group_name_snapshot, '
    'option_name_snapshot, price_delta_snapshot, display_order) VALUES '
    "(70, 40, 60, 'Món thêm', 'Sườn thêm', 45000, 0), "
    "(71, 40, 61, 'Món thêm', 'Trứng thêm', 30000, 1)",
  );
  await db
      .into(db.printAttempts)
      .insert(
        PrintAttemptsCompanion.insert(
          id: const Value(50),
          orderId: 31,
          attemptedAt: 470,
          success: true,
        ),
      );
  await (db.update(db.appSettings)..where((row) => row.id.equals(1))).write(
    const AppSettingsCompanion(shopName: Value('Quán nguồn')),
  );
  await (db.update(db.printerSettings)..where((row) => row.id.equals(1))).write(
    const PrinterSettingsCompanion(
      printerName: Value('MP-58N'),
      printerAddress: Value('AA:BB'),
      autoReconnect: Value(false),
      autoPrint: Value(true),
    ),
  );
}

Future<void> _populateOldLive(AppDatabase db, Directory files) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: const Value(90),
          name: 'Dữ liệu cũ',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
  final image = ProductImageStore(files).resolve('product-images/old.png');
  await image.parent.create(recursive: true);
  await image.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 9]);
}

Future<void> _order(
  AppDatabase db,
  int id,
  int number,
  String token,
  String status,
  int createdAt,
  String receipt, {
  int? paidAt,
  int? cancelledAt,
  int total = 45000,
}) => db
    .into(db.orders)
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
        receiptSettingsSnapshot: receipt,
      ),
    );

Future<void> _item(
  AppDatabase db,
  int id,
  int orderId, {
  int base = 45000,
  int unit = 45000,
}) => db
    .into(db.orderItems)
    .insert(
      OrderItemsCompanion.insert(
        id: Value(id),
        orderId: orderId,
        productId: const Value(20),
        productNameSnapshot: 'Cơm tấm cũ',
        baseUnitPriceSnapshot: Value(base),
        unitPriceSnapshot: unit,
        quantity: 1,
        lineTotal: unit,
      ),
    );

Future<int> _paidRevenue(AppDatabase db) async {
  final rows = await (db.select(
    db.orders,
  )..where((row) => row.status.equals('PAID'))).get();
  return rows.fold<int>(0, (total, row) => total + row.total);
}

const _validPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  4,
  0,
  0,
  0,
  181,
  28,
  12,
  2,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  100,
  248,
  15,
  0,
  1,
  5,
  1,
  1,
  39,
  24,
  227,
  102,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
