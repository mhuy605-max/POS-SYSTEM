import 'dart:io';
import 'dart:typed_data';

import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/backup/backup_file_gateway.dart';
import 'package:dakao_in_bill/backup/backup_providers.dart';
import 'package:dakao_in_bill/backup/backup_service.dart';
import 'package:dakao_in_bill/backup/backup_models.dart';
import 'package:dakao_in_bill/backup/restore_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/sales/cart_controller.dart';
import 'package:dakao_in_bill/features/settings/backup_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late AppDatabase database;
  late FakeBackupFileGateway gateway;
  late FakeBackupRestorer restorer;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dakao-backup-widget-');
    database = AppDatabase(NativeDatabase.memory());
    gateway = FakeBackupFileGateway();
    restorer = FakeBackupRestorer();
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  testWidgets('create uses document gateway and reports save or cancellation', (
    tester,
  ) async {
    await _pump(tester, database, root, gateway, restorer);
    await tester.tap(find.byKey(const Key('create-backup')));
    await tester.pumpAndSettle();

    expect(gateway.saved, isNotNull);
    expect(gateway.saved!.name, endsWith('.dakbackup'));
    expect(gateway.saved!.bytes, isNotEmpty);
    expect(find.text('Đã lưu bản sao lưu.'), findsOneWidget);

    gateway.saveResult = false;
    await tester.tap(find.byKey(const Key('create-backup')));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy lưu bản sao lưu.'), findsOneWidget);
  });

  testWidgets('validates, summarizes, confirms, and restores selected backup', (
    tester,
  ) async {
    await (database.update(database.appSettings)
          ..where((row) => row.id.equals(1)))
        .write(const AppSettingsCompanion(shopName: Value('Đã sao lưu')));
    final staged = await BackupService(
      database: database,
      imageStore: ProductImageStore(root),
      nowUtc: () => DateTime.utc(2026, 10, 2),
      appVersion: '0.1.0+1',
    ).createArchive();
    gateway.picked = PickedBackup(name: 'quan.dakbackup', bytes: staged.bytes);
    await (database.update(database.appSettings)
          ..where((row) => row.id.equals(1)))
        .write(const AppSettingsCompanion(shopName: Value('Đã thay đổi')));
    await _pump(tester, database, root, gateway, restorer);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupScreen)),
    );
    final cartTokenBefore = container
        .read(cartControllerProvider)
        .submissionToken;

    await tester.tap(find.byKey(const Key('pick-backup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-validation-summary')), findsOneWidget);
    expect(find.textContaining('0 danh mục • 0 món • 0 đơn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();
    expect(find.text('Thay thế toàn bộ dữ liệu?'), findsOneWidget);
    expect(
      (await database.select(database.appSettings).getSingle()).shopName,
      'Đã thay đổi',
    );
    expect(restorer.calls, 0);

    await tester.tap(find.byKey(const Key('confirm-restore')));
    await tester.pumpAndSettle();
    expect(restorer.calls, 1);
    expect(find.text('Khôi phục hoàn tất.'), findsOneWidget);
    expect(
      container.read(cartControllerProvider).submissionToken,
      isNot(cartTokenBefore),
    );
  });

  testWidgets(
    'invalid file and picker cancellation leave live data unchanged',
    (tester) async {
      await (database.update(database.appSettings)
            ..where((row) => row.id.equals(1)))
          .write(const AppSettingsCompanion(shopName: Value('An toàn')));
      await _pump(tester, database, root, gateway, restorer);

      await tester.tap(find.byKey(const Key('pick-backup')));
      await tester.pumpAndSettle();
      expect(find.text('Đã hủy chọn tệp.'), findsOneWidget);

      gateway.picked = PickedBackup(
        name: 'giả.dakbackup',
        bytes: Uint8List.fromList([1, 2, 3]),
      );
      await tester.tap(find.byKey(const Key('pick-backup')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-error')), findsOneWidget);
      expect(
        (await database.select(database.appSettings).getSingle()).shopName,
        'An toàn',
      );
    },
  );

  testWidgets('restore refreshes the retained sales catalog', (tester) async {
    final repository = ProductRepository(database, () => 1000);
    final categoryId = await repository.createCategory('Cà phê');
    final oldProductId = await repository.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Món cũ', price: 20000),
    );
    final staged = await BackupService(
      database: database,
      imageStore: ProductImageStore(root),
      nowUtc: () => DateTime.utc(2026, 10, 3),
      appVersion: '0.1.0+1',
    ).createArchive();
    gateway.picked = PickedBackup(name: 'menu.dakbackup', bytes: staged.bytes);
    late int restoredProductId;
    restorer.onReplace = (_) async {
      await repository.softDeleteProduct(oldProductId);
      restoredProductId = await repository.createProduct(
        ProductDraft(
          categoryId: categoryId,
          name: 'Món đã khôi phục',
          price: 30000,
        ),
      );
    };
    await _pumpApp(tester, database, root, gateway, restorer);
    expect(find.byKey(Key('sale-product-$oldProductId')), findsOneWidget);

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sao lưu & khôi phục'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-backup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('restore-backup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-restore')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bán hàng'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('sale-product-$oldProductId')), findsNothing);
    expect(find.byKey(Key('sale-product-$restoredProductId')), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  Directory root,
  BackupFileGateway gateway,
  BackupRestorer restorer,
) async {
  tester.view.physicalSize = const Size(360, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productImageStoreProvider.overrideWith(
          (ref) async => ProductImageStore(root),
        ),
        backupFileGatewayProvider.overrideWithValue(gateway),
        restoreServiceProvider.overrideWithValue(restorer),
      ],
      child: const MaterialApp(home: BackupScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase database,
  Directory root,
  BackupFileGateway gateway,
  BackupRestorer restorer,
) async {
  tester.view.physicalSize = const Size(390, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productImageStoreProvider.overrideWith(
          (ref) async => ProductImageStore(root),
        ),
        backupFileGatewayProvider.overrideWithValue(gateway),
        restoreServiceProvider.overrideWithValue(restorer),
      ],
      child: const DakaoInBillApp(),
    ),
  );
  await tester.pumpAndSettle();
}

final class FakeBackupRestorer implements BackupRestorer {
  int calls = 0;
  Future<void> Function(ValidatedBackup backup)? onReplace;

  @override
  Future<void> replaceWith(ValidatedBackup backup) async {
    calls++;
    await onReplace?.call(backup);
  }
}

final class FakeBackupFileGateway implements BackupFileGateway {
  bool saveResult = true;
  StagedFile? saved;
  PickedBackup? picked;

  @override
  Future<PickedBackup?> pickBackup() async => picked;

  @override
  Future<bool> saveBackup(StagedFile file) async {
    saved = file;
    return saveResult;
  }
}
