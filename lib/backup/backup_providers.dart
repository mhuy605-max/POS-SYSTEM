import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database_provider.dart';
import '../features/orders/order_providers.dart';
import '../features/printing/printer_settings_controller.dart';
import '../features/products/catalog_controller.dart';
import '../features/revenue/revenue_providers.dart';
import '../features/sales/cart_controller.dart';
import '../features/settings/shop_settings_controller.dart';
import 'backup_file_gateway.dart';
import 'backup_models.dart';
import 'backup_service.dart';
import 'backup_validator.dart';
import 'restore_service.dart';

final backupFileGatewayProvider = Provider<BackupFileGateway>(
  (ref) => const AndroidDocumentBackupFileGateway(),
);

final backupServiceProvider = FutureProvider<BackupService>((ref) async {
  return BackupService(
    database: ref.watch(appDatabaseProvider),
    imageStore: await ref.watch(productImageStoreProvider.future),
    nowUtc: () => DateTime.now().toUtc(),
    appVersion: '0.1.0+1',
  );
});

final restoreServiceProvider = Provider<BackupRestorer>((ref) {
  throw StateError('RestoreService must be provided at application startup.');
});

final backupControllerProvider =
    AsyncNotifierProvider<BackupController, BackupUiState>(
      BackupController.new,
    );

final class BackupUiState {
  const BackupUiState({this.selected, this.selectedName, this.notice});

  final ValidatedBackup? selected;
  final String? selectedName;
  final String? notice;

  BackupUiState copyWith({
    ValidatedBackup? selected,
    String? selectedName,
    String? notice,
    bool clearSelection = false,
  }) => BackupUiState(
    selected: clearSelection ? null : selected ?? this.selected,
    selectedName: clearSelection ? null : selectedName ?? this.selectedName,
    notice: notice,
  );
}

final class BackupController extends AsyncNotifier<BackupUiState> {
  @override
  Future<BackupUiState> build() async => const BackupUiState();

  Future<void> createAndSave() async {
    final current = state.value ?? const BackupUiState();
    state = const AsyncLoading<BackupUiState>();
    state = await AsyncValue.guard(() async {
      final service = await ref.read(backupServiceProvider.future);
      final staged = await service.createArchive();
      final saved = await ref
          .read(backupFileGatewayProvider)
          .saveBackup(
            StagedFile(name: staged.suggestedFileName, bytes: staged.bytes),
          );
      return current.copyWith(
        notice: saved ? 'Đã lưu bản sao lưu.' : 'Đã hủy lưu bản sao lưu.',
      );
    });
  }

  Future<void> pickAndValidate() async {
    final current = state.value ?? const BackupUiState();
    state = const AsyncLoading<BackupUiState>();
    state = await AsyncValue.guard(() async {
      final picked = await ref.read(backupFileGatewayProvider).pickBackup();
      if (picked == null) {
        return current.copyWith(notice: 'Đã hủy chọn tệp.');
      }
      final database = ref.read(appDatabaseProvider);
      final validated = BackupValidator(schemaVersion: database.schemaVersion)
          .validateBytes(picked.bytes);
      return BackupUiState(
        selected: validated,
        selectedName: picked.name,
        notice: 'Bản sao lưu hợp lệ.',
      );
    });
  }

  Future<void> restoreSelected() async {
    final current = state.value;
    final selected = current?.selected;
    if (selected == null) return;
    state = const AsyncLoading<BackupUiState>();
    state = await AsyncValue.guard(() async {
      final service = ref.read(restoreServiceProvider);
      await service.replaceWith(selected);
      _invalidateRestoredState();
      return const BackupUiState(notice: 'Khôi phục hoàn tất.');
    });
  }

  void _invalidateRestoredState() {
    ref.invalidate(cartControllerProvider);
    ref.invalidate(catalogControllerProvider);
    ref.invalidate(categoryControllerProvider);
    ref.invalidate(orderListControllerProvider);
    ref.invalidate(revenueSummaryProvider);
    ref.invalidate(shopSettingsProvider);
    ref.invalidate(printerSettingsControllerProvider);
  }
}
