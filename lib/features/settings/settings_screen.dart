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
        Text(
          'Thiết bị & ứng dụng',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Card(
          child: InkWell(
            key: const Key('open-printer-settings'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/settings/printer'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.print_outlined,
                    color: AppColors.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Máy in Bluetooth 58mm',
                          style: TextStyle(fontWeight: FontWeight.w800),
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

String _summary(PrinterAdapterState state) => switch (state) {
  PrinterAdapterState.connected => 'Đã kết nối',
  PrinterAdapterState.unavailable => 'Không hỗ trợ Bluetooth',
  PrinterAdapterState.disabled => 'Bluetooth đang tắt',
  PrinterAdapterState.permissionDenied => 'Cần quyền Bluetooth',
  PrinterAdapterState.disconnected => 'Chưa kết nối',
};
