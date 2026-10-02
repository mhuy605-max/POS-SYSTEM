import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../printing/printer_models.dart';
import '../printing/printer_settings_controller.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(printerSettingsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Máy in Bluetooth 58mm'),
        actions: [
          IconButton(
            key: const Key('refresh-printer-state'),
            onPressed: () =>
                ref.read(printerSettingsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Không thể đọc máy in: $error')),
        data: (value) => _PrinterSettingsBody(state: value),
      ),
    );
  }
}

class _PrinterSettingsBody extends ConsumerWidget {
  const _PrinterSettingsBody({required this.state});
  final PrinterSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(printerSettingsControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(state.status.state),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: state.status.state == PrinterAdapterState.connected
                        ? AppColors.success
                        : AppColors.secondaryInk,
                  ),
                ),
                if (state.settings.isConfigured) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Đã chọn ${state.settings.printerName ?? 'Máy in'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    state.settings.printerAddress!,
                    style: const TextStyle(color: AppColors.secondaryInk),
                  ),
                ],
                if (state.status.state == PrinterAdapterState.permissionDenied)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.icon(
                      key: const Key('grant-bluetooth-permission'),
                      onPressed: controller.requestPermission,
                      icon: const Icon(Icons.bluetooth),
                      label: const Text('Cho phép Bluetooth'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Thiết bị đã ghép đôi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (state.devices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Không tìm thấy thiết bị đã ghép đôi. Ghép đôi trong Cài đặt Android rồi làm mới.',
              ),
            ),
          )
        else
          for (final device in state.devices)
            Card(
              child: ListTile(
                key: Key('printer-device-${device.address}'),
                minTileHeight: 64,
                leading: const Icon(Icons.print_outlined),
                title: Text(device.name),
                subtitle: Text(device.address),
                trailing: state.settings.printerAddress == device.address
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : const Icon(Icons.chevron_right),
                onTap: () => controller.select(device),
              ),
            ),
        if (state.settings.isConfigured) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const Key('reconnect-printer'),
            onPressed: controller.reconnect,
            icon: const Icon(Icons.bluetooth_connected),
            label: const Text('Kết nối lại'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('test-print'),
            onPressed: controller.testPrint,
            icon: const Icon(Icons.print_outlined),
            label: const Text('In trang kiểm tra'),
          ),
          if (state.status.state == PrinterAdapterState.connected) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('disconnect-printer'),
              onPressed: controller.disconnect,
              child: const Text('Ngắt kết nối'),
            ),
          ],
        ],
        if (state.lastResult != null) ...[
          const SizedBox(height: 12),
          Text(
            state.lastResult!.message,
            key: const Key('printer-result'),
            style: TextStyle(
              color: state.lastResult!.kind == PrintResultKind.failed
                  ? AppColors.error
                  : AppColors.secondaryInk,
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          'Ứng dụng liệt kê thiết bị Bluetooth đã ghép đôi. Không bật Bluetooth hoặc tự động gửi lại dữ liệu khi kết quả chưa rõ.',
          style: TextStyle(color: AppColors.secondaryInk),
        ),
      ],
    );
  }
}

String _statusLabel(PrinterAdapterState state) => switch (state) {
  PrinterAdapterState.unavailable => 'Thiết bị không hỗ trợ Bluetooth',
  PrinterAdapterState.disabled => 'Bluetooth đang tắt',
  PrinterAdapterState.permissionDenied => 'Cần quyền Bluetooth',
  PrinterAdapterState.disconnected => 'Chưa kết nối',
  PrinterAdapterState.connected => 'Đã kết nối',
};
