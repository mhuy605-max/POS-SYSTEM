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

void main() {
  late AppDatabase database;
  late ProductRepository products;
  late OrderRepository orders;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    products = ProductRepository(database, () => 1000);
    orders = OrderRepository(database, nowEpochMillis: () => 2000);
    final category = await products.createCategory('Món chính');
    final product = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Tên lúc bán', price: 42000),
    );
    await orders.createOrder(
      OrderDraft(
        submissionToken: 'widget-order',
        lines: [
          DraftLine(
            productId: product,
            reviewedName: 'Tên lúc bán',
            reviewedUnitPrice: 42000,
            quantity: 2,
            note: 'Không hành',
          ),
        ],
      ),
    );
    await products.updateProduct(
      product,
      ProductDraft(categoryId: category, name: 'Tên mới', price: 99000),
    );
  });

  tearDown(() => database.close());

  testWidgets('orders list, detail snapshots, and mark-paid update', (
    tester,
  ) async {
    await _pump(tester, database, products);
    await _openOrders(tester);

    expect(find.text('#0001'), findsOneWidget);
    expect(find.text('84.000đ'), findsOneWidget);
    await tester.tap(find.text('#0001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tên lúc bán'), findsOneWidget);
    expect(find.text('Tên mới'), findsNothing);
    expect(find.text('Không hành'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mark-paid')));
    await tester.pumpAndSettle();
    expect(find.text('Đã thanh toán'), findsWidgets);
  });

  testWidgets(
    'paid cancellation requires confirmation and cancelled reprint is disabled',
    (tester) async {
      await _pump(tester, database, products);
      await _openOrders(tester);
      await tester.tap(find.text('#0001'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mark-paid')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancel-order')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('đã được đánh dấu thanh toán'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirm-cancel-order')));
      await tester.pumpAndSettle();

      expect(find.text('Đã hủy'), findsWidgets);
      final reprint = tester.widget<OutlinedButton>(
        find.byKey(const Key('reprint-order')),
      );
      expect(reprint.onPressed, isNull);
    },
  );

  testWidgets('UNPAID and PAID filters show matching orders', (tester) async {
    await _pump(tester, database, products);
    await _openOrders(tester);
    await tester.tap(find.text('Đã trả'));
    await tester.pumpAndSettle();
    expect(find.text('#0001'), findsNothing);
    await tester.tap(find.text('Chưa trả'));
    await tester.pumpAndSettle();
    expect(find.text('#0001'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  ProductRepository products,
) async {
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

Future<void> _openOrders(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Đơn hàng'),
    ),
  );
  await tester.pumpAndSettle();
}
