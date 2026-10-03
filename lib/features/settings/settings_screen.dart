import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../printing/printer_models.dart';
import '../printing/printer_settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printer = ref.watch(printerSettingsControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsEntry(
          key: const Key('open-shop-settings'),
          icon: Icons.storefront_outlined,
          title: 'Thông tin quán & bill',
          subtitle: 'Tên quán, liên hệ và lời nhắn trên bill',
          onTap: () => context.push('/settings/shop'),
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            key: const Key('open-printer-settings'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/settings/printer'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const _SettingsIcon(icon: Icons.print_outlined),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Máy in Bluetooth 58mm',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          printer.when(
                            loading: () => 'Đang kiểm tra…',
                            error: (_, _) => 'Không thể đọc trạng thái',
                            data: (value) => _summary(value.status.state),
                          ),
                          style: const TextStyle(color: AppColors.secondaryInk),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SettingsEntry(
          key: const Key('open-backup-settings'),
          icon: Icons.settings_backup_restore_outlined,
          title: 'Sao lưu & khôi phục',
          subtitle: 'Xuất và khôi phục tệp .dakbackup cục bộ',
          onTap: () => context.push('/settings/backup'),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.offline_bolt_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dữ liệu đơn hàng và cấu hình được lưu cục bộ trên thiết bị.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsEntry extends StatelessWidget {
  const _SettingsEntry({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _SettingsIcon(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.secondaryInk),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: SizedBox.square(
      dimension: 44,
      child: Icon(icon, color: AppColors.primary, size: 23),
    ),
  );
}

String _summary(PrinterAdapterState state) => switch (state) {
  PrinterAdapterState.connected => 'Đã kết nối',
  PrinterAdapterState.unavailable => 'Không hỗ trợ Bluetooth',
  PrinterAdapterState.disabled => 'Bluetooth đang tắt',
  PrinterAdapterState.permissionDenied => 'Cần quyền Bluetooth',
  PrinterAdapterState.disconnected => 'Chưa kết nối',
};
