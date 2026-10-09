import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/sales/cart_controller.dart';
import 'package:dakao_in_bill/features/sales/review_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Checkpoint 6 sales option flows persist on Android', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final products = ProductRepository(database, () => 1000);
    final options = ProductOptionRepository(database, () => 1000);
    final orders = OrderRepository(
      database,
      nowEpochMillis: () => 2000,
      productOptionRepository: options,
    );
    final categoryId = await products.createCategory('Cơm');
    final plainId = await products.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Cơm thường', price: 30000),
    );
    final riceId = await products.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Cơm sườn', price: 35000),
    );
    final extras = await options.createGroup('Món thêm');
    final loinId = await options.createOption(
      groupId: extras,
      name: 'Sườn thêm',
      priceDelta: 45000,
    );
    final eggId = await options.createOption(
      groupId: extras,
      name: 'Trứng thêm',
      priceDelta: 30000,
    );
    await options.attachGroupToProduct(riceId, extras);

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
    await _pump(tester);

    // Flow 1: the V1 product path remains an immediate synchronous add.
    await tester.tap(find.byKey(Key('sale-product-$plainId')));
    await tester.pump();
    expect(find.text('1 món'), findsOneWidget);

    // Flow 2: one option produces the expected configured unit price.
    await _addConfiguration(tester, riceId, [loinId], 'Nướng kỹ');
    var cart = _cart(tester);
    expect(cart.lines.last.unitPrice, 80000);
    expect(cart.lines.last.note, 'Nướng kỹ');

    // Flows 3 and 5: combined options calculate correctly and stay separate.
    await _addConfiguration(tester, riceId, [loinId, eggId], null);
    cart = _cart(tester);
    expect(cart.lines.last.unitPrice, 110000);
    expect(cart.lines, hasLength(3));

    // Add a third configuration to edit into the first configured line.
    await _addConfiguration(tester, riceId, [eggId], null);
    await tester.tap(find.byKey(const Key('open-current-order')));
    await _pump(tester);
    cart = _cart(tester);
    final eggLine = cart.lines.singleWhere(
      (line) =>
          line.productId == riceId &&
          line.selectedOptions.length == 1 &&
          line.selectedOptions.single.optionItemId == eggId,
    );
    final edit = find.byKey(Key('edit-cart-line-${eggLine.lineId}'));
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await _pump(tester);
    expect(edit, findsOneWidget);
    await tester.tap(edit);
    await _pump(tester);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(Key('configure-option-$eggId')))
          .value,
      isTrue,
    );

    // Flows 4 and 6: edit through the sheet and coalesce identical identity.
    await tester.tap(find.byKey(Key('configure-option-$eggId')));
    await tester.tap(find.byKey(Key('configure-option-$loinId')));
    await tester.enterText(
      find.byKey(const Key('configure-item-note')),
      'Nướng kỹ',
    );
    await tester.tap(find.byKey(const Key('confirm-configured-item')));
    await _pump(tester);
    cart = _cart(tester);
    expect(cart.lines, hasLength(3));
    final coalesced = cart.lines.singleWhere(
      (line) => line.productId == riceId && line.selectedOptions.length == 1,
    );
    expect(coalesced.selectedOptions.single.optionItemId, loinId);
    expect(coalesced.quantity, 2);
    final coalescedOption = find.byKey(
      Key('cart-option-${coalesced.lineId}-$loinId'),
    );
    await tester.scrollUntilVisible(
      coalescedOption,
      -300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(coalescedOption, findsOneWidget);

    // Flow 7: submit via the real cart mapping and verify immutable snapshots.
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    final saved = (await orders.listOrders()).single;
    expect(saved.total, 300000);
    expect(saved.items, hasLength(3));
    final combined = saved.items.singleWhere(
      (item) => item.options.length == 2,
    );
    expect(combined.unitPrice, 110000);
    expect(combined.options.map((item) => item.optionName), [
      'Sườn thêm',
      'Trứng thêm',
    ]);
    final savedCoalesced = saved.items.singleWhere(
      (item) => item.options.length == 1,
    );
    expect(savedCoalesced.quantity, 2);
    expect(savedCoalesced.options.single.priceDelta, 45000);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}

CartState _cart(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(
    find.byType(ReviewScreen).evaluate().isNotEmpty
        ? find.byType(ReviewScreen)
        : find.byKey(const Key('open-current-order')),
  ),
).read(cartControllerProvider);

Future<void> _addConfiguration(
  WidgetTester tester,
  int productId,
  List<int> optionIds,
  String? note,
) async {
  await tester.tap(find.byKey(Key('sale-product-$productId')));
  await _pump(tester);
  for (final optionId in optionIds) {
    await tester.tap(find.byKey(Key('configure-option-$optionId')));
  }
  if (note != null) {
    await tester.enterText(find.byKey(const Key('configure-item-note')), note);
  }
  await tester.tap(find.byKey(const Key('confirm-configured-item')));
  await _pump(tester);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}
