import 'dart:typed_data';

import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/printing/printer_providers.dart';
import 'package:dakao_in_bill/features/printing/printer_settings_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_transport.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProductRepository products;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    products = ProductRepository(database, () => 1000);
  });

  tearDown(() => database.close());

  test(
    'selected printer persists without changing hidden auto-print value',
    () async {
      final repository = PrinterSettingsRepository(database);

      await repository.saveSelected(
        const PrinterDevice(name: 'MP-58N', address: 'AA:BB:CC:DD:EE:FF'),
      );

      final saved = await repository.load();
      final raw = await database.select(database.printerSettings).getSingle();
      expect(saved.printerName, 'MP-58N');
      expect(saved.printerAddress, 'AA:BB:CC:DD:EE:FF');
      expect(raw.autoPrint, isTrue);
    },
  );

  testWidgets(
    'permission state can refresh paired devices and select printer',
    (tester) async {
      final transport = FakeSettingsTransport(
        status: const PrinterStatus(PrinterAdapterState.permissionDenied),
        devices: const <PrinterDevice>[
          PrinterDevice(name: 'MP-58N', address: '11:22:33:44:55:66'),
        ],
      );
      await _pump(tester, database, products, transport);
      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tự động in'), findsNothing);

      await tester.tap(find.byKey(const Key('open-printer-settings')));
      await tester.pumpAndSettle();
      expect(find.text('Cần quyền Bluetooth'), findsOneWidget);

      await tester.tap(find.byKey(const Key('grant-bluetooth-permission')));
      await tester.pumpAndSettle();
      expect(transport.permissionRequests, 1);
      expect(find.text('MP-58N'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('printer-device-11:22:33:44:55:66')),
      );
      await tester.pumpAndSettle();
      final saved = await PrinterSettingsRepository(database).load();
      expect(saved.printerAddress, '11:22:33:44:55:66');
      expect(find.textContaining('Đã chọn MP-58N'), findsOneWidget);
    },
  );

  testWidgets('unavailable and disabled Bluetooth states are explicit', (
    tester,
  ) async {
    final transport = FakeSettingsTransport(
      status: const PrinterStatus(PrinterAdapterState.unavailable),
    );
    await _pump(tester, database, products, transport);
    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-printer-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị không hỗ trợ Bluetooth'), findsOneWidget);

    transport.status = const PrinterStatus(PrinterAdapterState.disabled);
    await tester.tap(find.byKey(const Key('refresh-printer-state')));
    await tester.pumpAndSettle();
    expect(find.text('Bluetooth đang tắt'), findsOneWidget);
    expect(transport.enableRequests, 0);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  ProductRepository products,
  PrinterTransport transport,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productRepositoryProvider.overrideWithValue(products),
        printerTransportProvider.overrideWithValue(transport),
      ],
      child: const DakaoInBillApp(),
    ),
  );
  await tester.pumpAndSettle();
}

final class FakeSettingsTransport implements PrinterTransport {
  FakeSettingsTransport({required this.status, this.devices = const []});

  PrinterStatus status;
  final List<PrinterDevice> devices;
  int permissionRequests = 0;
  int enableRequests = 0;

  @override
  Future<PrinterStatus> connect(String address) async {
    status = PrinterStatus(
      PrinterAdapterState.connected,
      deviceName: devices.where((item) => item.address == address).first.name,
      address: address,
    );
    return status;
  }

  @override
  Future<void> disconnect() async {
    status = const PrinterStatus.disconnected();
  }

  @override
  Future<PrinterStatus> getStatus() async => status;

  @override
  Future<List<PrinterDevice>> listPairedDevices() async => devices;

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    status = const PrinterStatus.disconnected();
    return true;
  }

  @override
  Future<PrintResult> send(String address, Uint8List bytes) async =>
      const PrintResult.sent();
}
