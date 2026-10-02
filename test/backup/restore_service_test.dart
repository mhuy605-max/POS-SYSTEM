import 'dart:io';

import 'package:dakao_in_bill/backup/backup_data_codec.dart';
import 'package:dakao_in_bill/backup/backup_service.dart';
import 'package:dakao_in_bill/backup/backup_validator.dart';
import 'package:dakao_in_bill/backup/restore_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
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
  return const BackupValidator(schemaVersion: 1).validateBytes(staged.bytes);
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
          price: 45000,
          imagePath: const Value('product-images/menu.png'),
          createdAt: 200,
          updatedAt: 200,
        ),
      );
  const receipt =
      '{"version":1,"shopName":"Quán nguồn","address":"A","phone":"1","footer":"F"}';
  await _order(db, 30, 1, 'unpaid', 'UNPAID', 300, receipt);
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
  await _item(db, 40, 30);
  await _item(db, 41, 31);
  await _item(db, 42, 32);
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
}) => db
    .into(db.orders)
    .insert(
      OrdersCompanion.insert(
        id: Value(id),
        orderNumber: number,
        submissionToken: token,
        status: Value(status),
        subtotal: 45000,
        total: 45000,
        createdAt: createdAt,
        paidAt: Value(paidAt),
        cancelledAt: Value(cancelledAt),
        receiptSettingsSnapshot: receipt,
      ),
    );

Future<void> _item(AppDatabase db, int id, int orderId) => db
    .into(db.orderItems)
    .insert(
      OrderItemsCompanion.insert(
        id: Value(id),
        orderId: orderId,
        productId: const Value(20),
        productNameSnapshot: 'Cơm tấm cũ',
        unitPriceSnapshot: 45000,
        quantity: 1,
        lineTotal: 45000,
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
