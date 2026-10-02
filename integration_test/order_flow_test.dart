import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
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
    final orders = OrderRepository(database, nowEpochMillis: () => 2000);
    final category = await products.createCategory('Cà phê');
    final product = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Cà phê sữa', price: 25000),
    );

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            productRepositoryProvider.overrideWithValue(products),
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

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Đơn hàng'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('#0001'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mark-paid')));
    await tester.pumpAndSettle();
    expect((await orders.loadOrder(saved.id)).status, OrderStatus.paid);

    // Dispose the first ProviderScope so the rebuild models a fresh process
    // and creates a new router at its initial sales location.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Đơn hàng'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('#0001'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);
  });
}
