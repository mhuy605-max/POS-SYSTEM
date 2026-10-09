import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/core/money.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/sales/cart_controller.dart';
import 'package:dakao_in_bill/features/sales/configure_item_sheet.dart';
import 'package:dakao_in_bill/features/sales/review_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProductRepository products;
  late ProductOptionRepository options;
  late OrderRepository orders;
  late int plainProductId;
  late int configuredProductId;
  late int extrasId;
  late int saucesId;
  late int eggId;
  late int sauceId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    products = ProductRepository(database, () => 1000);
    options = ProductOptionRepository(database, () => 1000);
    orders = OrderRepository(
      database,
      nowEpochMillis: () => 2000,
      productOptionRepository: options,
    );
    final categoryId = await products.createCategory('Cơm');
    plainProductId = await products.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Cơm thường', price: 30000),
    );
    configuredProductId = await products.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Cơm sườn', price: 35000),
    );
    extrasId = await options.createGroup('Món thêm');
    eggId = await options.createOption(
      groupId: extrasId,
      name: 'Trứng ốp la rất dài để kiểm tra hiển thị',
      priceDelta: 10000,
    );
    saucesId = await options.createGroup('Nước sốt');
    sauceId = await options.createOption(
      groupId: saucesId,
      name: 'Sốt tiêu',
      priceDelta: 0,
    );
    await options.attachGroupToProduct(configuredProductId, extrasId);
    await options.attachGroupToProduct(configuredProductId, saucesId);
  });

  tearDown(() => database.close());

  testWidgets(
    'plain product stays immediate and configured product opens once',
    (tester) async {
      await _pump(tester, database, products, options, orders);

      await tester.tap(find.byKey(Key('sale-product-$plainProductId')));
      await tester.pump();
      expect(find.text('1 món'), findsOneWidget);

      await tester.tap(find.byKey(Key('sale-product-$configuredProductId')));
      await tester.tap(find.byKey(Key('sale-product-$configuredProductId')));
      await _boundedPump(tester);

      expect(find.byKey(const Key('configure-item-scroll')), findsOneWidget);
      expect(find.byKey(Key('configure-option-$eggId')), findsOneWidget);
      expect(find.byKey(Key('configure-option-$sauceId')), findsOneWidget);
      expect(find.text('35.000đ'), findsWidgets);
      final cart = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('configure-item-scroll'))),
      ).read(cartControllerProvider);
      expect(cart.itemCount, 1);

      await tester.tap(find.byKey(const Key('confirm-configured-item')));
      await _boundedPump(tester);
      final afterZeroSelection = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('open-current-order'))),
      ).read(cartControllerProvider);
      expect(afterZeroSelection.itemCount, 2);
      expect(afterZeroSelection.lines.last.unitPrice, 35000);
      expect(afterZeroSelection.lines.last.selectedOptions, isEmpty);
    },
  );

  testWidgets('inactive groups use immediate add without an empty sheet', (
    tester,
  ) async {
    await options.setGroupActive(extrasId, false);
    await options.setGroupActive(saucesId, false);
    await _pump(tester, database, products, options, orders);
    await tester.tap(find.byKey(Key('sale-product-$configuredProductId')));
    await tester.pump();
    expect(find.byKey(const Key('configure-item-scroll')), findsNothing);
    expect(find.text('1 món'), findsOneWidget);
  });

  testWidgets('all inactive options use immediate add without an empty sheet', (
    tester,
  ) async {
    await options.setOptionActive(eggId, false);
    await options.setOptionActive(sauceId, false);
    await _pump(tester, database, products, options, orders);
    await tester.tap(find.byKey(Key('sale-product-$configuredProductId')));
    await tester.pump();
    expect(find.byKey(const Key('configure-item-scroll')), findsNothing);
    expect(find.text('1 món'), findsOneWidget);
  });

  testWidgets('overflow disables confirm and leaves the sheet recoverable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConfigureItemSheet(
              context: context,
              productId: 1,
              productName: 'Món thử',
              baseUnitPrice: 10,
              selectableOptions: const [
                ResolvedProductOption(
                  productId: 1,
                  groupId: 1,
                  optionItemId: 1,
                  groupName: 'Món thêm',
                  optionName: 'Phần thêm',
                  priceDelta: sqliteMaxInteger - 5,
                  groupSortOrder: 0,
                  optionSortOrder: 0,
                ),
              ],
              onSubmit: (_, _) async => null,
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await _boundedPump(tester);
    await tester.tap(find.byKey(const Key('configure-option-1')));
    await tester.pump();

    expect(find.text('Vượt giới hạn'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('confirm-configured-item')),
    );
    expect(confirm.onPressed, isNull);
    await tester.tap(find.byKey(const Key('configure-option-1')));
    await tester.pump();
    expect(find.text('Vượt giới hạn'), findsNothing);
  });

  testWidgets('optional multi-select shows live price and review snapshots', (
    tester,
  ) async {
    await _pump(tester, database, products, options, orders);
    await _openConfiguration(tester, configuredProductId);

    await tester.tap(find.byKey(Key('configure-option-$eggId')));
    await tester.tap(find.byKey(Key('configure-option-$sauceId')));
    await tester.drag(
      find.byKey(const Key('configure-item-scroll')),
      const Offset(0, -500),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byKey(const Key('configure-item-note')),
      'Ít hành',
    );
    await tester.pump();
    expect(find.text('45.000đ'), findsWidgets);
    expect(find.text('0đ'), findsWidgets);

    await tester.tap(find.byKey(const Key('confirm-configured-item')));
    await _boundedPump(tester);
    expect(find.text('1 món'), findsOneWidget);
    await tester.tap(find.byKey(const Key('open-current-order')));
    await _boundedPump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));
    final line = ProviderScope.containerOf(
      tester.element(find.byType(ReviewScreen)),
    ).read(cartControllerProvider).lines.single;

    expect(
      find.byKey(Key('cart-option-${line.lineId}-$eggId')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('cart-option-${line.lineId}-$sauceId')),
      findsOneWidget,
    );
    expect(find.text('45.000đ'), findsWidgets);
    expect(line.note, 'Ít hành');
    expect(line.selectedOptions.map((item) => item.optionItemId), [
      eggId,
      sauceId,
    ]);
  });

  testWidgets(
    'edit restores snapshot, preserves quantity and coalesces lines',
    (tester) async {
      await _pump(tester, database, products, options, orders);
      await _openConfiguration(tester, configuredProductId);
      await tester.tap(find.byKey(Key('configure-option-$eggId')));
      await tester.tap(find.byKey(const Key('confirm-configured-item')));
      await _boundedPump(tester);
      await _openConfiguration(tester, configuredProductId);
      await tester.tap(find.byKey(Key('configure-option-$sauceId')));
      await tester.tap(find.byKey(const Key('confirm-configured-item')));
      await _boundedPump(tester);
      await tester.tap(find.byKey(const Key('open-current-order')));
      await _boundedPump(tester);

      await tester.tap(find.byTooltip('Tăng').first);
      await tester.pump();
      var cart = ProviderScope.containerOf(
        tester.element(find.byType(ReviewScreen)),
      ).read(cartControllerProvider);
      final eggLine = cart.lines.firstWhere(
        (line) => line.selectedOptions.single.optionItemId == eggId,
      );
      await tester.tap(find.byKey(Key('edit-cart-line-${eggLine.lineId}')));
      await _boundedPump(tester);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(Key('configure-option-$eggId')),
            )
            .value,
        isTrue,
      );

      await tester.tap(find.byKey(Key('configure-option-$eggId')));
      await tester.tap(find.byKey(Key('configure-option-$sauceId')));
      await tester.tap(find.byKey(const Key('confirm-configured-item')));
      await _boundedPump(tester);

      cart = ProviderScope.containerOf(
        tester.element(find.byType(ReviewScreen)),
      ).read(cartControllerProvider);
      expect(cart.lines, hasLength(1));
      expect(cart.lines.single.quantity, 3);
      expect(cart.lines.single.selectedOptions.single.optionItemId, sauceId);
    },
  );

  testWidgets('stale option rejects submit with stable cart and no order', (
    tester,
  ) async {
    await _pump(tester, database, products, options, orders);
    await _openConfiguration(tester, configuredProductId);
    await tester.tap(find.byKey(Key('configure-option-$eggId')));
    await tester.tap(find.byKey(const Key('confirm-configured-item')));
    await _boundedPump(tester);
    await tester.tap(find.byKey(const Key('open-current-order')));
    await _boundedPump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReviewScreen)),
    );
    final before = container.read(cartControllerProvider).lines.single;

    await options.updateOption(eggId, name: 'Trứng mới', priceDelta: 20000);
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Món có thể đã thay đổi'), findsOneWidget);
    expect(await orders.listOrders(), isEmpty);
    final after = container.read(cartControllerProvider).lines.single;
    expect(
      after.selectedOptions.single.optionName,
      before.selectedOptions.single.optionName,
    );
    expect(after.unitPrice, before.unitPrice);
    expect(after.quantity, before.quantity);
  });
}

Future<void> _openConfiguration(WidgetTester tester, int productId) async {
  await tester.tap(find.byKey(Key('sale-product-$productId')));
  await _boundedPump(tester);
  expect(find.byKey(const Key('configure-item-scroll')), findsOneWidget);
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  ProductRepository products,
  ProductOptionRepository options,
  OrderRepository orders,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productRepositoryProvider.overrideWithValue(products),
        productOptionRepositoryProvider.overrideWithValue(options),
        orderSubmitterProvider.overrideWithValue(orders.createOrder),
        orderPrinterProvider.overrideWithValue(
          (_) async => const PrintResult.sent(),
        ),
      ],
      child: const DakaoInBillApp(),
    ),
  );
  await _boundedPump(tester);
}

Future<void> _boundedPump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}
