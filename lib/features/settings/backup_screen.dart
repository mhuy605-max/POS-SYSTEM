import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../backup/backup_providers.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupControllerProvider);
    final value = state.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu & khôi phục')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _Section(
            icon: Icons.cloud_download_outlined,
            title: 'Tạo bản sao lưu',
            body: 'Lưu dữ liệu quán, món, đơn hàng, ảnh món và cài đặt vào một tệp .dakbackup trên thiết bị.',
            child: FilledButton.icon(
              key: const Key('create-backup'),
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(backupControllerProvider.notifier)
                        .createAndSave(),
              icon: const Icon(Icons.save_alt),
              label: const Text('Tạo và lưu bản sao'),
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            icon: Icons.restore_outlined,
            title: 'Khôi phục dữ liệu',
            body: 'Chọn tệp .dakbackup để kiểm tra trước. Dữ liệu hiện tại chỉ được thay thế sau khi bạn xác nhận.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const Key('pick-backup'),
                  onPressed: state.isLoading
                      ? null
                      : () => ref
                            .read(backupControllerProvider.notifier)
                            .pickAndValidate(),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Chọn tệp sao lưu'),
                ),
                if (value?.selected case final selected?) ...[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('backup-validation-summary'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value?.selectedName ?? 'Bản sao lưu',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${selected.summary.categories} danh mục • ${selected.summary.products} món • ${selected.summary.orders} đơn • ${selected.summary.images} ảnh',
                        ),
                        Text(
                          'Tạo lúc ${selected.manifest.createdAtUtc}',
                          style: const TextStyle(color: AppColors.secondaryInk),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('restore-backup'),
                    onPressed: state.isLoading
                        ? null
                        : () => _confirmRestore(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                    ),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text('Khôi phục và thay thế dữ liệu'),
                  ),
                ],
              ],
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (state.hasError)
            const Padding(
              key: Key('backup-error'),
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Tệp sao lưu không hợp lệ hoặc không được hỗ trợ. Dữ liệu hiện tại không thay đổi.',
                style: TextStyle(color: AppColors.error, height: 1.4),
              ),
            ),
          if (!state.hasError && value?.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                value!.notice!,
                key: const Key('backup-notice'),
                style: const TextStyle(color: AppColors.secondaryInk),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Tệp sao lưu được kiểm tra tính toàn vẹn nhưng không được mã hóa. Hãy cất tệp ở nơi bạn tin cậy. Khôi phục không kết nối hoặc in qua Bluetooth.',
            style: TextStyle(color: AppColors.secondaryInk, height: 1.45),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thay thế toàn bộ dữ liệu?'),
        content: const Text(
          'Danh mục, món, đơn hàng, ảnh món và cài đặt hiện tại sẽ được thay bằng nội dung trong bản sao lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('confirm-restore'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xác nhận khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(backupControllerProvider.notifier).restoreSelected();
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: AppColors.secondaryInk, height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}
