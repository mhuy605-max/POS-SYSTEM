enum PrintResultKind { sent, failed, unknown }

enum PrinterErrorCode {
  bluetoothUnavailable,
  bluetoothDisabled,
  permissionDenied,
  notConfigured,
  connectionFailed,
  writeFailed,
  disconnected,
  unknownOutcome,
  persistenceFailed,
  cancelledOrder,
}

enum PrinterAdapterState {
  unavailable,
  disabled,
  permissionDenied,
  disconnected,
  connected,
}

final class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

  final String name;
  final String address;
}

final class PrinterStatus {
  const PrinterStatus(this.state, {this.deviceName, this.address});
  const PrinterStatus.disconnected()
    : state = PrinterAdapterState.disconnected,
      deviceName = null,
      address = null;

  final PrinterAdapterState state;
  final String? deviceName;
  final String? address;
}

final class SavedPrinterSettings {
  const SavedPrinterSettings({
    required this.printerName,
    required this.printerAddress,
    required this.autoReconnect,
  });

  final String? printerName;
  final String? printerAddress;
  final bool autoReconnect;

  bool get isConfigured =>
      printerAddress != null && printerAddress!.trim().isNotEmpty;
}

final class PrintResult {
  const PrintResult.sent()
    : kind = PrintResultKind.sent,
      errorCode = null,
      message = 'Dữ liệu đã được gửi tới máy in; hãy kiểm tra giấy.';

  const PrintResult.failed(this.errorCode, this.message)
    : kind = PrintResultKind.failed;

  const PrintResult.unknown(this.errorCode, this.message)
    : kind = PrintResultKind.unknown;

  final PrintResultKind kind;
  final PrinterErrorCode? errorCode;
  final String message;

  bool get wasSent => kind == PrintResultKind.sent;
}
