import 'print_attempt_repository.dart';
import 'printer_models.dart';
import 'printer_settings_repository.dart';
import 'printer_transport.dart';
import 'receipt_renderer.dart';
import '../orders/order_repository.dart';

final class PrinterService {
  const PrinterService({
    required this.orderRepository,
    required this.settingsRepository,
    required this.attemptRepository,
    required this.renderer,
    required this.transport,
  });

  final OrderRepository orderRepository;
  final PrinterSettingsRepository settingsRepository;
  final PrintAttemptRepository attemptRepository;
  final ReceiptRenderer renderer;
  final PrinterTransport transport;

  Future<PrintResult> printOrder(int orderId) async {
    final order = await orderRepository.loadOrder(orderId);
    if (order.status == OrderStatus.cancelled) {
      return const PrintResult.failed(
        PrinterErrorCode.cancelledOrder,
        'Không thể in lại đơn đã hủy.',
      );
    }
    final settings = await settingsRepository.load();
    if (!settings.isConfigured) {
      final result = const PrintResult.failed(
        PrinterErrorCode.notConfigured,
        'Chưa cấu hình máy in Bluetooth.',
      );
      await _record(orderId, result);
      return result;
    }
    final RenderedReceipt receipt;
    try {
      receipt = await renderer.renderOrder(order);
    } catch (_) {
      return _record(
        orderId,
        const PrintResult.failed(
          PrinterErrorCode.writeFailed,
          'Không thể tạo dữ liệu hóa đơn để in.',
        ),
      );
    }
    final PrintResult result;
    try {
      result = await transport.send(settings.printerAddress!, receipt.bytes);
    } catch (_) {
      return _record(
        orderId,
        const PrintResult.unknown(
          PrinterErrorCode.unknownOutcome,
          'Kết nối máy in dừng bất ngờ; dữ liệu có thể đã được gửi. '
          'Ứng dụng sẽ không tự động in lại.',
        ),
      );
    }
    return _record(orderId, result);
  }

  Future<PrintResult> reprintOrder(int orderId) => printOrder(orderId);

  Future<PrintResult> testPrint() async {
    final settings = await settingsRepository.load();
    if (!settings.isConfigured) {
      return const PrintResult.failed(
        PrinterErrorCode.notConfigured,
        'Chưa cấu hình máy in Bluetooth.',
      );
    }
    final RenderedReceipt page;
    try {
      page = await renderer.renderTestPage();
    } catch (_) {
      return const PrintResult.failed(
        PrinterErrorCode.writeFailed,
        'Không thể tạo trang kiểm tra.',
      );
    }
    try {
      return await transport.send(settings.printerAddress!, page.bytes);
    } catch (_) {
      return const PrintResult.unknown(
        PrinterErrorCode.unknownOutcome,
        'Kết nối máy in dừng bất ngờ; trang kiểm tra có thể đã được gửi.',
      );
    }
  }

  Future<PrintResult> _record(int orderId, PrintResult result) async {
    try {
      await attemptRepository.record(orderId, result);
      return result;
    } catch (_) {
      if (result.kind == PrintResultKind.sent ||
          result.kind == PrintResultKind.unknown) {
        return const PrintResult.unknown(
          PrinterErrorCode.persistenceFailed,
          'Dữ liệu có thể đã được gửi nhưng không lưu được kết quả. '
          'Không tự động in lại.',
        );
      }
      return const PrintResult.failed(
        PrinterErrorCode.persistenceFailed,
        'Không lưu được kết quả gửi máy in.',
      );
    }
  }
}
