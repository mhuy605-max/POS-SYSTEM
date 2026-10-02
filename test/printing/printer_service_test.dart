import 'dart:typed_data';

import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/orders/order_service.dart';
import 'package:dakao_in_bill/features/printing/print_attempt_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/printing/printer_service.dart';
import 'package:dakao_in_bill/features/printing/printer_settings_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_transport.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late OrderRepository orders;
  late OrderService orderService;
  late PrinterSettingsRepository settings;
  late FakePrinterTransport transport;
  late PrinterService printer;
  late int productId;
  late int orderId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    orders = OrderRepository(database, nowEpochMillis: () => 1000);
    orderService = OrderService(
      database,
      repository: orders,
      nowEpochMillis: () => 1500,
    );
    settings = PrinterSettingsRepository(database);
    transport = FakePrinterTransport();
    printer = PrinterService(
      orderRepository: orders,
      settingsRepository: settings,
      attemptRepository: PrintAttemptRepository(
        database,
        nowEpochMillis: () => 2000,
      ),
      renderer: const ReceiptRenderer(),
      transport: transport,
    );
    final category = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Món chính',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            categoryId: category,
            name: 'Cơm tấm Sườn Chả',
            price: 45000,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await (database.update(
      database.appSettings,
    )..where((row) => row.id.equals(1))).write(
      const AppSettingsCompanion(
        shopName: Value('Đakao'),
        address: Value('1 Đakao'),
        receiptFooter: Value('Cảm ơn'),
      ),
    );
    orderId = await orders.createOrder(_draft('print-order', productId));
    await settings.saveSelected(
      const PrinterDevice(name: 'MP-58N', address: '00:11:22:33:44:55'),
    );
  });

  tearDown(() => database.close());

  test('transport failure records attempt and leaves order UNPAID', () async {
    transport.results.add(
      const PrintResult.failed(
        PrinterErrorCode.connectionFailed,
        'Không thể kết nối',
      ),
    );

    final result = await printer.printOrder(orderId);

    expect(result.kind, PrintResultKind.failed);
    expect((await orders.loadOrder(orderId)).status, OrderStatus.unpaid);
    expect(await database.select(database.orders).get(), hasLength(1));
    expect(await database.select(database.printAttempts).get(), hasLength(1));
  });

  test('missing printer configuration records a useful failure', () async {
    await settings.clearSelected();

    final result = await printer.printOrder(orderId);

    expect(result.errorCode, PrinterErrorCode.notConfigured);
    expect(transport.payloads, isEmpty);
    final rows = await database.select(database.printAttempts).get();
    expect(rows.single.success, isFalse);
    expect(rows.single.errorMessage, contains('notConfigured'));
  });

  test(
    'explicit retry sends same order and increments only successful write',
    () async {
      transport.results.addAll(<PrintResult>[
        const PrintResult.failed(PrinterErrorCode.writeFailed, 'Ghi thất bại'),
        const PrintResult.sent(),
      ]);

      await printer.printOrder(orderId);
      await printer.reprintOrder(orderId);

      expect(transport.payloads, hasLength(2));
      expect(await database.select(database.orders).get(), hasLength(1));
      final row = await (database.select(
        database.orders,
      )..where((item) => item.id.equals(orderId))).getSingle();
      expect(row.printCount, 1);
      expect(row.status, 'UNPAID');
      expect(row.paidAt, isNull);
    },
  );

  test('reprint uses historical item and receipt settings snapshots', () async {
    transport.results.addAll(const <PrintResult>[
      PrintResult.sent(),
      PrintResult.sent(),
    ]);
    await printer.printOrder(orderId);
    final originalPayload = Uint8List.fromList(transport.payloads.single);

    await (database.update(
      database.products,
    )..where((row) => row.id.equals(productId))).write(
      const ProductsCompanion(name: Value('Tên mới'), price: Value(99000)),
    );
    await (database.update(
      database.appSettings,
    )..where((row) => row.id.equals(1))).write(
      const AppSettingsCompanion(
        shopName: Value('Quán mới'),
        receiptFooter: Value('Footer mới'),
      ),
    );

    await printer.reprintOrder(orderId);

    expect(transport.payloads.last, originalPayload);
  });

  test('cancelled order cannot reprint and never invokes transport', () async {
    await orderService.cancel(orderId);

    final result = await printer.reprintOrder(orderId);

    expect(result.errorCode, PrinterErrorCode.cancelledOrder);
    expect(transport.payloads, isEmpty);
    expect(await database.select(database.printAttempts).get(), isEmpty);
  });

  test('unknown outcome is not automatically resent', () async {
    transport.results.add(
      const PrintResult.unknown(
        PrinterErrorCode.unknownOutcome,
        'Không rõ dữ liệu đã gửi hết hay chưa',
      ),
    );

    final result = await printer.printOrder(orderId);

    expect(result.kind, PrintResultKind.unknown);
    expect(transport.payloads, hasLength(1));
    final row = await (database.select(
      database.orders,
    )..where((item) => item.id.equals(orderId))).getSingle();
    expect(row.printCount, 0);
  });

  test('thrown transport error is recorded as an unknown outcome', () async {
    final throwingPrinter = PrinterService(
      orderRepository: orders,
      settingsRepository: settings,
      attemptRepository: PrintAttemptRepository(
        database,
        nowEpochMillis: () => 2000,
      ),
      renderer: const ReceiptRenderer(),
      transport: ThrowingPrinterTransport(),
    );

    final result = await throwingPrinter.printOrder(orderId);

    expect(result.kind, PrintResultKind.unknown);
    final rows = await database.select(database.printAttempts).get();
    expect(rows.single.success, isFalse);
    expect(rows.single.errorMessage, startsWith('UNKNOWN_OUTCOME|'));
  });

  test('receipt rendering error is recorded as a failed attempt', () async {
    final throwingPrinter = PrinterService(
      orderRepository: orders,
      settingsRepository: settings,
      attemptRepository: PrintAttemptRepository(
        database,
        nowEpochMillis: () => 2000,
      ),
      renderer: const ThrowingReceiptRenderer(),
      transport: transport,
    );

    final result = await throwingPrinter.printOrder(orderId);

    expect(result.kind, PrintResultKind.failed);
    expect(transport.payloads, isEmpty);
    final rows = await database.select(database.printAttempts).get();
    expect(rows.single.success, isFalse);
    expect(rows.single.errorMessage, contains('writeFailed'));
  });

  test('test print creates no order or print attempt', () async {
    await database.delete(database.printAttempts).go();
    await database.delete(database.orderItems).go();
    await database.delete(database.orders).go();
    transport.results.add(const PrintResult.sent());

    final result = await printer.testPrint();

    expect(result.kind, PrintResultKind.sent);
    expect(await database.select(database.orders).get(), isEmpty);
    expect(await database.select(database.printAttempts).get(), isEmpty);
  });

  test('test print normalizes renderer and transport exceptions', () async {
    final renderFailure = PrinterService(
      orderRepository: orders,
      settingsRepository: settings,
      attemptRepository: PrintAttemptRepository(
        database,
        nowEpochMillis: () => 2000,
      ),
      renderer: const ThrowingTestPageRenderer(),
      transport: transport,
    );
    final transportFailure = PrinterService(
      orderRepository: orders,
      settingsRepository: settings,
      attemptRepository: PrintAttemptRepository(
        database,
        nowEpochMillis: () => 2000,
      ),
      renderer: const ReceiptRenderer(),
      transport: ThrowingPrinterTransport(),
    );

    expect((await renderFailure.testPrint()).kind, PrintResultKind.failed);
    expect((await transportFailure.testPrint()).kind, PrintResultKind.unknown);
    expect(await database.select(database.printAttempts).get(), isEmpty);
  });
}

OrderDraft _draft(String token, int productId) => OrderDraft(
  submissionToken: token,
  lines: <DraftLine>[
    DraftLine(
      productId: productId,
      reviewedName: 'Cơm tấm Sườn Chả',
      reviewedUnitPrice: 45000,
      quantity: 1,
      note: 'Ít mỡ',
    ),
  ],
);

final class FakePrinterTransport implements PrinterTransport {
  final List<PrintResult> results = <PrintResult>[];
  final List<Uint8List> payloads = <Uint8List>[];

  @override
  Future<PrintResult> send(String address, Uint8List bytes) async {
    payloads.add(Uint8List.fromList(bytes));
    return results.removeAt(0);
  }

  @override
  Future<PrinterStatus> connect(String address) async =>
      PrinterStatus(PrinterAdapterState.connected, address: address);

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrinterStatus> getStatus() async => const PrinterStatus.disconnected();

  @override
  Future<List<PrinterDevice>> listPairedDevices() async =>
      const <PrinterDevice>[];

  @override
  Future<bool> requestPermissions() async => true;
}

final class ThrowingPrinterTransport extends FakePrinterTransport {
  @override
  Future<PrintResult> send(String address, Uint8List bytes) async {
    throw StateError('method channel closed');
  }
}

final class ThrowingReceiptRenderer extends ReceiptRenderer {
  const ThrowingReceiptRenderer();

  @override
  Future<RenderedReceipt> renderOrder(SavedOrder order) async {
    throw StateError('font unavailable');
  }
}

final class ThrowingTestPageRenderer extends ReceiptRenderer {
  const ThrowingTestPageRenderer();

  @override
  Future<RenderedReceipt> renderTestPage() async {
    throw StateError('font unavailable');
  }
}
