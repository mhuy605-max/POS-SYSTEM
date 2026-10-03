import 'dart:typed_data';

import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/orders/order_providers.dart';
import 'package:dakao_in_bill/features/orders/order_service.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/printing/printer_providers.dart';
import 'package:dakao_in_bill/features/printing/printer_settings_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_transport.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:dakao_in_bill/features/revenue/revenue_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete local sale and payment flow survives app rebuild', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final products = ProductRepository(database, () => 1000);
    final now = DateTime(2026, 10, 2, 12);
    final orders = OrderRepository(
      database,
      nowEpochMillis: () => now.millisecondsSinceEpoch,
    );
    final category = await products.createCategory('Cà phê');
    final product = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Cà phê sữa', price: 25000),
    );
    await PrinterSettingsRepository(database).saveSelected(
      const PrinterDevice(name: 'Fake 58mm', address: 'FA:KE:00:00:00:01'),
    );
    final transport = _IntegrationTransport(orders);

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            productRepositoryProvider.overrideWithValue(products),
            orderRepositoryProvider.overrideWithValue(orders),
            orderServiceProvider.overrideWithValue(
              OrderService(
                database,
                repository: orders,
                nowEpochMillis: () => now.millisecondsSinceEpoch,
              ),
            ),
            revenueNowProvider.overrideWithValue(() => now),
            printerTransportProvider.overrideWithValue(transport),
            receiptRendererProvider.overrideWithValue(
              const _IntegrationRenderer(),
            ),
          ],
          child: const DakaoInBillApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.byKey(Key('sale-product-$product')));
    await tester.tap(find.byKey(const Key('open-current-order')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('cart-note-$product')), 'Ít đá');
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump(const Duration(milliseconds: 500));

    final saved = (await orders.listOrders()).single;
    expect(saved.status, OrderStatus.unpaid);
    expect(saved.items.single.note, 'Ít đá');
    expect(transport.sendCount, 1);
    expect(transport.orderExistedWhenSent, isTrue);

    await _openDestination(tester, 'Doanh thu');
    expect(_revenueValue(tester, 'recognized-revenue'), '0đ');
    expect(_revenueValue(tester, 'unpaid-total'), '25.000đ');

    await _openDestination(tester, 'Đơn hàng');
    await tester.tap(find.text('#0001'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mark-paid')));
    await tester.pumpAndSettle();
    expect((await orders.loadOrder(saved.id)).status, OrderStatus.paid);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openDestination(tester, 'Doanh thu');
    expect(_revenueValue(tester, 'recognized-revenue'), '25.000đ');
    expect(_revenueValue(tester, 'unpaid-total'), '0đ');

    // Dispose the first ProviderScope so the rebuild models a fresh process
    // and creates a new router at its initial sales location.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await _openDestination(tester, 'Doanh thu');
    expect(_revenueValue(tester, 'recognized-revenue'), '25.000đ');
    await _openDestination(tester, 'Đơn hàng');
    expect(find.text('#0001'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    await tester.tap(find.text('#0001'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-order')));
    await tester.pumpAndSettle();
    expect((await orders.loadOrder(saved.id)).status, OrderStatus.cancelled);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openDestination(tester, 'Doanh thu');
    expect(_revenueValue(tester, 'recognized-revenue'), '0đ');
    expect(_revenueValue(tester, 'unpaid-total'), '0đ');
  });
}

Future<void> _openDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

String _revenueValue(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

final class _IntegrationTransport implements PrinterTransport {
  _IntegrationTransport(this.orders);
  final OrderRepository orders;
  var sendCount = 0;
  var orderExistedWhenSent = false;

  @override
  Future<PrinterStatus> connect(String address) async =>
      PrinterStatus(PrinterAdapterState.connected, address: address);

  @override
  Future<void> disconnect() async {}

  @override
  Future<PrinterStatus> getStatus() async => const PrinterStatus.disconnected();

  @override
  Future<List<PrinterDevice>> listPairedDevices() async => const [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<PrintResult> send(String address, Uint8List bytes) async {
    sendCount++;
    orderExistedWhenSent = (await orders.listOrders()).isNotEmpty;
    return const PrintResult.sent();
  }
}

final class _IntegrationRenderer extends ReceiptRenderer {
  const _IntegrationRenderer();

  @override
  Future<RenderedReceipt> renderOrder(SavedOrder order) async =>
      RenderedReceipt(
        bytes: Uint8List.fromList(<int>[0x1b, 0x40, 0x0a]),
        widthDots: 384,
        heightDots: 1,
        bandHeights: const <int>[1],
      );
}
