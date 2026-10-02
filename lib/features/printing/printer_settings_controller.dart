import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'printer_models.dart';
import 'printer_providers.dart';

final printerSettingsControllerProvider =
    AsyncNotifierProvider<PrinterSettingsController, PrinterSettingsState>(
      PrinterSettingsController.new,
    );

final class PrinterSettingsState {
  const PrinterSettingsState({
    required this.settings,
    required this.status,
    required this.devices,
    this.lastResult,
  });

  final SavedPrinterSettings settings;
  final PrinterStatus status;
  final List<PrinterDevice> devices;
  final PrintResult? lastResult;

  PrinterSettingsState copyWith({
    SavedPrinterSettings? settings,
    PrinterStatus? status,
    List<PrinterDevice>? devices,
    PrintResult? lastResult,
  }) => PrinterSettingsState(
    settings: settings ?? this.settings,
    status: status ?? this.status,
    devices: devices ?? this.devices,
    lastResult: lastResult ?? this.lastResult,
  );
}

final class PrinterSettingsController
    extends AsyncNotifier<PrinterSettingsState> {
  @override
  Future<PrinterSettingsState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> requestPermission() async {
    await ref.read(printerTransportProvider).requestPermissions();
    await refresh();
  }

  Future<void> select(PrinterDevice device) async {
    await ref.read(printerSettingsRepositoryProvider).saveSelected(device);
    final status = await ref
        .read(printerTransportProvider)
        .connect(device.address);
    final current = state.value ?? await _load();
    state = AsyncData(
      current.copyWith(
        settings: await ref.read(printerSettingsRepositoryProvider).load(),
        status: status,
      ),
    );
  }

  Future<void> reconnect() async {
    final current = state.value ?? await _load();
    final address = current.settings.printerAddress;
    if (address == null) return;
    final status = await ref.read(printerTransportProvider).connect(address);
    state = AsyncData(current.copyWith(status: status));
  }

  Future<void> disconnect() async {
    await ref.read(printerTransportProvider).disconnect();
    final current = state.value ?? await _load();
    state = AsyncData(
      current.copyWith(status: const PrinterStatus.disconnected()),
    );
  }

  Future<void> testPrint() async {
    final result = await ref.read(printerServiceProvider).testPrint();
    final current = state.value ?? await _load();
    state = AsyncData(current.copyWith(lastResult: result));
  }

  Future<PrinterSettingsState> _load() async {
    final transport = ref.read(printerTransportProvider);
    final settings = await ref.read(printerSettingsRepositoryProvider).load();
    final status = await transport.getStatus();
    var devices = const <PrinterDevice>[];
    if (status.state == PrinterAdapterState.disconnected ||
        status.state == PrinterAdapterState.connected) {
      try {
        devices = await transport.listPairedDevices();
      } catch (_) {
        devices = const <PrinterDevice>[];
      }
    }
    return PrinterSettingsState(
      settings: settings,
      status: status,
      devices: devices,
    );
  }
}
