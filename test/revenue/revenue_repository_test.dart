import 'dart:io';

import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/print_attempt_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/printing/printer_service.dart';
import 'package:dakao_in_bill/features/printing/printer_settings_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_transport.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:dakao_in_bill/features/revenue/revenue_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late RevenueRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = RevenueRepository(database);
  });

  tearDown(() => database.close());

  test(
    'revenue uses PAID status and paid_at inside the selected period',
    () async {
      final today = RevenuePeriod.custom(_date(2), _date(2));
      await _insertOrder(
        database,
        number: 1,
        total: 90000,
        createdAt: _day(1, 20),
        status: 'PAID',
        paidAt: _day(2, 8),
      );
      await _insertOrder(
        database,
        number: 2,
        total: 70000,
        createdAt: _day(2, 8),
        status: 'PAID',
        paidAt: _day(1, 23),
      );
      await _insertOrder(
        database,
        number: 3,
        total: 50000,
        createdAt: _day(2, 9),
        status: 'CANCELLED',
        paidAt: _day(2, 10),
      );
      await _insertOrder(
        database,
        number: 4,
        total: 35000,
        createdAt: _day(2, 11),
        status: 'UNPAID',
      );

      final summary = await repository.summarize(today);

      expect(summary.recognizedRevenue, 90000);
      expect(summary.paidOrderCount, 1);
      expect(summary.unpaidAmount, 35000);
      expect(summary.dailyRevenue.single.amount, 90000);
    },
  );

  test(
    'status transitions move integer totals between approved metrics',
    () async {
      final period = RevenuePeriod.custom(_date(2), _date(2));
      final paidLater = await _insertOrder(
        database,
        number: 1,
        total: 45000,
        createdAt: _day(1, 22),
        status: 'UNPAID',
      );
      final cancelledUnpaid = await _insertOrder(
        database,
        number: 2,
        total: 30000,
        createdAt: _day(2, 8),
        status: 'UNPAID',
      );

      var summary = await repository.summarize(period);
      expect(summary.recognizedRevenue, 0);
      expect(summary.unpaidAmount, 75000);

      await (database.update(
        database.orders,
      )..where((row) => row.id.equals(paidLater))).write(
        OrdersCompanion(status: const Value('PAID'), paidAt: Value(_day(2, 9))),
      );
      summary = await repository.summarize(period);
      expect(summary.recognizedRevenue, 45000);
      expect(summary.unpaidAmount, 30000);

      await (database.update(database.orders)
            ..where((row) => row.id.equals(cancelledUnpaid)))
          .write(const OrdersCompanion(status: Value('CANCELLED')));
      summary = await repository.summarize(period);
      expect(summary.recognizedRevenue, 45000);
      expect(summary.unpaidAmount, 0);

      await (database.update(database.orders)
            ..where((row) => row.id.equals(paidLater)))
          .write(const OrdersCompanion(status: Value('CANCELLED')));
      summary = await repository.summarize(period);
      expect(summary.recognizedRevenue, 0);
      expect(summary.paidOrderCount, 0);
      expect(summary.unpaidAmount, 0);
    },
  );

  test('multiple PAID orders sum once and empty periods return zero', () async {
    await _insertOrder(
      database,
      number: 1,
      total: 90000,
      createdAt: _day(2),
      status: 'PAID',
      paidAt: _day(2, 7),
    );
    await _insertOrder(
      database,
      number: 2,
      total: 125000,
      createdAt: _day(2),
      status: 'PAID',
      paidAt: _day(2, 12),
    );

    expect(
      (await repository.summarize(RevenuePeriod.custom(_date(2), _date(2))))
          .recognizedRevenue,
      215000,
    );
    final empty = await repository.summarize(
      RevenuePeriod.custom(_date(3), _date(3)),
    );
    expect(empty.recognizedRevenue, 0);
    expect(empty.paidOrderCount, 0);
    expect(empty.dailyRevenue.single.amount, 0);
    expect(empty.bestSellers, isEmpty);
  });

  test(
    'best sellers use paid historical item snapshots in the period',
    () async {
      final paid = await _insertOrder(
        database,
        number: 1,
        total: 120000,
        createdAt: _day(1),
        status: 'PAID',
        paidAt: _day(2, 8),
      );
      final cancelled = await _insertOrder(
        database,
        number: 2,
        total: 90000,
        createdAt: _day(2),
        status: 'CANCELLED',
        paidAt: _day(2, 9),
      );
      await _insertItem(database, paid, 'Cơm tấm', 2, 80000);
      await _insertItem(database, paid, 'Coca-Cola', 1, 40000);
      await _insertItem(database, cancelled, 'Không tính', 20, 90000);

      final summary = await repository.summarize(
        RevenuePeriod.custom(_date(2), _date(2)),
      );

      expect(summary.recognizedRevenue, 120000);
      expect(summary.bestSellers.map((item) => item.name), [
        'Cơm tấm',
        'Coca-Cola',
      ]);
      expect(summary.bestSellers.first.quantity, 2);
    },
  );

  test('print attempts never affect revenue or unpaid totals', () async {
    final orderId = await _insertOrder(
      database,
      number: 1,
      total: 60000,
      createdAt: _day(2),
      status: 'PAID',
      paidAt: _day(2, 10),
    );
    final period = RevenuePeriod.custom(_date(2), _date(2));
    final before = await repository.summarize(period);

    for (final success in [false, true]) {
      await database
          .into(database.printAttempts)
          .insert(
            PrintAttemptsCompanion.insert(
              orderId: orderId,
              attemptedAt: _day(2, 11),
              success: success,
              errorMessage: success
                  ? const Value.absent()
                  : const Value('failed'),
            ),
          );
    }

    final after = await repository.summarize(period);
    expect(after, before);
  });

  test(
    'real successful and failed reprints leave reactive revenue unchanged',
    () async {
      final orderId = await _insertOrder(
        database,
        number: 1,
        total: 60000,
        createdAt: _day(2),
        status: 'PAID',
        paidAt: _day(2, 10),
      );
      await _insertItem(database, orderId, 'Cơm tấm', 1, 60000);
      final settings = PrinterSettingsRepository(database);
      await settings.saveSelected(
        const PrinterDevice(name: 'MP-58N', address: '00:11:22:33:44:55'),
      );
      final transport = _RevenuePrinterTransport()
        ..results.addAll(const <PrintResult>[
          PrintResult.sent(),
          PrintResult.failed(PrinterErrorCode.writeFailed, 'Ghi thất bại'),
        ]);
      final printer = PrinterService(
        orderRepository: OrderRepository(
          database,
          nowEpochMillis: () => _day(2, 11),
        ),
        settingsRepository: settings,
        attemptRepository: PrintAttemptRepository(
          database,
          nowEpochMillis: () => _day(2, 11),
        ),
        renderer: const ReceiptRenderer(),
        transport: transport,
      );
      final period = RevenuePeriod.custom(_date(2), _date(2));
      final before = await repository.summarize(period);
      final unchangedEmission = expectLater(
        repository.watchSummary(period).take(2),
        emitsInOrder(<RevenueSummary>[before, before]),
      );
      await Future<void>.delayed(Duration.zero);

      expect((await printer.reprintOrder(orderId)).kind, PrintResultKind.sent);
      await unchangedEmission;
      expect(
        (await database.select(database.orders).getSingle()).printCount,
        1,
      );

      expect(
        (await printer.reprintOrder(orderId)).kind,
        PrintResultKind.failed,
      );
      expect(await repository.summarize(period), before);
    },
  );

  test('summary persists and recalculates after database reopen', () async {
    await database.close();
    final root = await Directory.systemTemp.createTemp('dakao-revenue-');
    addTearDown(() => root.delete(recursive: true));
    final file = File('${root.path}${Platform.pathSeparator}revenue.sqlite');
    var fileDatabase = AppDatabase.openFile(file);
    await _insertOrder(
      fileDatabase,
      number: 1,
      total: 88000,
      createdAt: _day(1),
      status: 'PAID',
      paidAt: _day(2, 13),
    );
    await fileDatabase.close();

    fileDatabase = AppDatabase.openFile(file);
    final reopened = await RevenueRepository(fileDatabase)
        .summarize(RevenuePeriod.custom(_date(2), _date(2)));
    expect(reopened.recognizedRevenue, 88000);
    await fileDatabase.close();
    database = AppDatabase(NativeDatabase.memory());
  });
}

final class _RevenuePrinterTransport implements PrinterTransport {
  final List<PrintResult> results = <PrintResult>[];

  @override
  Future<PrintResult> send(String address, Uint8List bytes) async =>
      results.removeAt(0);

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

int _day(int day, [int hour = 0]) => _date(day, hour).millisecondsSinceEpoch;

DateTime _date(int day, [int hour = 0]) => DateTime(2026, 10, day, hour);

Future<int> _insertOrder(
  AppDatabase database, {
  required int number,
  required int total,
  required int createdAt,
  required String status,
  int? paidAt,
}) => database
    .into(database.orders)
    .insert(
      OrdersCompanion.insert(
        orderNumber: number,
        submissionToken: 'revenue-$number',
        subtotal: total,
        total: total,
        createdAt: createdAt,
        status: Value(status),
        paidAt: Value(paidAt),
        receiptSettingsSnapshot: '{"version":1,"shopName":"Đakao","address":"","phone":"","footer":""}',
      ),
    );

Future<void> _insertItem(
  AppDatabase database,
  int orderId,
  String name,
  int quantity,
  int total,
) async {
  await database
      .into(database.orderItems)
      .insert(
        OrderItemsCompanion.insert(
          orderId: orderId,
          productNameSnapshot: name,
          unitPriceSnapshot: total ~/ quantity,
          quantity: quantity,
          lineTotal: total,
        ),
      );
}
