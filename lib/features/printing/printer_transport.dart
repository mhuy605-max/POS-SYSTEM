import 'package:flutter/services.dart';

import 'printer_models.dart';

abstract interface class PrinterTransport {
  Future<PrinterStatus> getStatus();
  Future<bool> requestPermissions();
  Future<List<PrinterDevice>> listPairedDevices();
  Future<PrinterStatus> connect(String address);
  Future<PrintResult> send(String address, Uint8List bytes);
  Future<void> disconnect();
}

final class NativePrinterTransport implements PrinterTransport {
  const NativePrinterTransport({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dakao_in_bill/printer');

  final MethodChannel _channel;

  @override
  Future<PrinterStatus> getStatus() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('getState');
      return _statusFromMap(value);
    } on PlatformException catch (error) {
      return PrinterStatus(
        _adapterState(error.code),
        deviceName: null,
        address: null,
      );
    } on MissingPluginException {
      return const PrinterStatus(PrinterAdapterState.unavailable);
    }
  }

  @override
  Future<bool> requestPermissions() async =>
      await _channel.invokeMethod<bool>('requestPermissions') ?? false;

  @override
  Future<List<PrinterDevice>> listPairedDevices() async {
    final values = await _channel.invokeListMethod<Object?>(
      'listPairedDevices',
    );
    return <PrinterDevice>[
      for (final value in values ?? const <Object?>[])
        if (value is Map)
          PrinterDevice(
            name: value['name'] as String? ?? 'Máy in Bluetooth',
            address: value['address'] as String,
          ),
    ];
  }

  @override
  Future<PrinterStatus> connect(String address) async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('connect', {
        'address': address,
      });
      return _statusFromMap(value);
    } on PlatformException catch (error) {
      return PrinterStatus(_adapterState(error.code));
    } on MissingPluginException {
      return const PrinterStatus(PrinterAdapterState.unavailable);
    }
  }

  @override
  Future<PrintResult> send(String address, Uint8List bytes) async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('write', {
        'address': address,
        'bytes': bytes,
      });
      final kind = value?['kind'] as String?;
      final code = _errorCode(value?['code'] as String?);
      final message = value?['message'] as String? ?? 'Lỗi máy in.';
      return switch (kind) {
        'sent' => const PrintResult.sent(),
        'unknown' => PrintResult.unknown(code, message),
        _ => PrintResult.failed(code, message),
      };
    } on PlatformException catch (error) {
      return PrintResult.failed(
        _errorCode(error.code),
        error.message ?? 'Không thể gửi dữ liệu tới máy in.',
      );
    }
  }

  @override
  Future<void> disconnect() => _channel.invokeMethod<void>('disconnect');
}

PrinterStatus _statusFromMap(Map<String, Object?>? value) => PrinterStatus(
  _adapterState(value?['state'] as String?),
  deviceName: value?['name'] as String?,
  address: value?['address'] as String?,
);

PrinterAdapterState _adapterState(String? value) => switch (value) {
  'unavailable' => PrinterAdapterState.unavailable,
  'disabled' => PrinterAdapterState.disabled,
  'permissionDenied' => PrinterAdapterState.permissionDenied,
  'connected' => PrinterAdapterState.connected,
  _ => PrinterAdapterState.disconnected,
};

PrinterErrorCode _errorCode(String? value) => switch (value) {
  'bluetoothUnavailable' => PrinterErrorCode.bluetoothUnavailable,
  'bluetoothDisabled' => PrinterErrorCode.bluetoothDisabled,
  'permissionDenied' => PrinterErrorCode.permissionDenied,
  'notConfigured' => PrinterErrorCode.notConfigured,
  'connectionFailed' => PrinterErrorCode.connectionFailed,
  'disconnected' => PrinterErrorCode.disconnected,
  'unknownOutcome' => PrinterErrorCode.unknownOutcome,
  _ => PrinterErrorCode.writeFailed,
};
