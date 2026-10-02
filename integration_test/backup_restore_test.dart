import 'dart:io';

import 'package:dakao_in_bill/backup/backup_data_codec.dart';
import 'package:dakao_in_bill/backup/backup_service.dart';
import 'package:dakao_in_bill/backup/backup_validator.dart';
import 'package:dakao_in_bill/backup/restore_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('production SQLite and files round trip through .dakbackup', (
    tester,
  ) async {
    final base = await getTemporaryDirectory();
    final root = Directory(
      '${base.path}${Platform.pathSeparator}'
      'stage6-${DateTime.now().microsecondsSinceEpoch}',
    );
    await root.create(recursive: true);
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final databaseFile = File(
      '${root.path}${Platform.pathSeparator}dakao.sqlite',
    );
    final files = Directory('${root.path}${Platform.pathSeparator}files');
    final images = ProductImageStore(files);
    var database = AppDatabase.openFile(databaseFile);
    addTearDown(() => database.close());

    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(10),
            name: 'Cơm',
            createdAt: 100,
            updatedAt: 100,
          ),
        );
    final image = images.resolve('product-images/menu.png');
    await image.parent.create(recursive: true);
    await image.writeAsBytes(_validPng);
    await database
        .into(database.products)
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
        '{"version":1,"shopName":"Đakao API 36","address":"A","phone":"1","footer":"F"}';
    await _insertOrder(database, 30, 1, 'unpaid', 'UNPAID', receipt);
    await _insertOrder(database, 31, 2, 'paid', 'PAID', receipt, paidAt: 500);
    await _insertOrder(
      database,
      32,
      3,
      'cancelled',
      'CANCELLED',
      receipt,
      paidAt: 520,
      cancelledAt: 550,
    );
    for (final entry in const [(40, 30), (41, 31), (42, 32)]) {
      await database
          .into(database.orderItems)
          .insert(
            OrderItemsCompanion.insert(
              id: Value(entry.$1),
              orderId: entry.$2,
              productId: const Value(20),
              productNameSnapshot: 'Cơm tấm lịch sử',
              unitPriceSnapshot: 45000,
              quantity: 1,
              lineTotal: 45000,
            ),
          );
    }
    await (database.update(database.appSettings)
          ..where((row) => row.id.equals(1)))
        .write(const AppSettingsCompanion(shopName: Value('Đakao API 36')));

    final expected = await BackupDataCodec(database).exportCanonical();
    final staged = await BackupService(
      database: database,
      imageStore: images,
      nowUtc: () => DateTime.utc(2026, 10, 2),
      appVersion: '0.1.0+1',
    ).createArchive();
    final validated = const BackupValidator(schemaVersion: 1)
        .validateBytes(staged.bytes);

    await (database.delete(database.orderItems)).go();
    await (database.delete(database.orders)).go();
    await (database.delete(database.products)).go();
    await image.delete();
    await RestoreService(
      database: database,
      imageStore: images,
      journalDirectory: Directory(
        '${files.path}${Platform.pathSeparator}.restore-recovery',
      ),
    ).replaceWith(validated);

    expect(await BackupDataCodec(database).exportCanonical(), expected);
    expect(await image.exists(), isTrue);
    expect(
      (await database.select(database.orders).get()).map(
        (order) => order.status,
      ),
      ['UNPAID', 'PAID', 'CANCELLED'],
    );
    expect(
      (await database.select(database.orders).get())
          .where((order) => order.status == 'PAID')
          .fold<int>(0, (sum, order) => sum + order.total),
      45000,
    );

    await database.close();
    database = AppDatabase.openFile(databaseFile);
    expect(await BackupDataCodec(database).exportCanonical(), expected);
    final historical = await (database.select(
      database.orderItems,
    )..where((row) => row.id.equals(40))).getSingle();
    expect(historical.productNameSnapshot, 'Cơm tấm lịch sử');
  });
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

Future<void> _insertOrder(
  AppDatabase database,
  int id,
  int number,
  String token,
  String status,
  String receipt, {
  int? paidAt,
  int? cancelledAt,
}) => database
    .into(database.orders)
    .insert(
      OrdersCompanion.insert(
        id: Value(id),
        orderNumber: number,
        submissionToken: token,
        status: Value(status),
        subtotal: 45000,
        total: 45000,
        createdAt: 300 + id,
        paidAt: Value(paidAt),
        cancelledAt: Value(cancelledAt),
        receiptSettingsSnapshot: receipt,
      ),
    );
