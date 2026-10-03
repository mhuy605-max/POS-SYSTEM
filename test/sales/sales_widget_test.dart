import 'dart:ui' show SemanticsAction, Tristate;

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
  late int productId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    products = ProductRepository(database, () => 1000);
    orders = OrderRepository(database, nowEpochMillis: () => 2000);
    final categoryId = await products.createCategory('Cà phê');
    productId = await products.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Cà phê sữa', price: 25000),
    );
  });

  tearDown(() => database.close());

  testWidgets('sales adds products and review saves exactly one order', (
    tester,
  ) async {
    await _pump(tester, database, products);

    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.pump();
    expect(find.text('2 món'), findsOneWidget);
    expect(find.text('50.000đ'), findsWidgets);

    await tester.tap(find.byKey(const Key('open-current-order')));
    await tester.pumpAndSettle();
    expect(find.text('Đơn hiện tại'), findsOneWidget);
    await tester.enterText(find.byKey(Key('cart-note-$productId')), 'Ít đá');
    await tester.tap(find.text('Mang về'));
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.tap(find.byKey(const Key('submit-order')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Đã lưu đơn #'), findsOneWidget);
    expect(await orders.listOrders(), hasLength(1));
    final saved = (await orders.listOrders()).single;
    expect(saved.status, OrderStatus.unpaid);
    expect(saved.orderType, OrderType.takeaway);
    expect(saved.items.single.note, 'Ít đá');
    expect(find.text('0 món'), findsOneWidget);
  });

  testWidgets('unavailable product is visibly disabled and cannot be added', (
    tester,
  ) async {
    await products.setProductAvailability(productId, false);
    await _pump(tester, database, products);

    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.pump();

    expect(find.text('Hết món'), findsOneWidget);
    expect(find.text('0 món'), findsOneWidget);
  });

  testWidgets('sales search state does not filter product management', (
    tester,
  ) async {
    await _pump(tester, database, products);

    await tester.enterText(
      find.byKey(const Key('sales-search')),
      'không tồn tại',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Key('sale-product-$productId')), findsNothing);

    await tester.tap(find.text('Món'));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('product-$productId')), findsOneWidget);
    final search = tester.widget<TextField>(
      find.byKey(const Key('catalog-search')),
    );
    expect(search.controller?.text ?? '', isEmpty);
  });

  testWidgets('typing an item note keeps the cursor at the end', (
    tester,
  ) async {
    await _pump(tester, database, products);
    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.tap(find.byKey(const Key('open-current-order')));
    await tester.pumpAndSettle();
    final note = find.byKey(Key('cart-note-$productId'));
    await tester.tap(note);
    await tester.showKeyboard(note);

    for (final character in 'LessIce'.split('')) {
      final current = tester.widget<EditableText>(
        find.descendant(of: note, matching: find.byType(EditableText)),
      );
      final value = current.controller.value;
      final offset = value.selection.baseOffset.clamp(0, value.text.length);
      final next = value.text.replaceRange(offset, offset, character);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: offset + 1),
        ),
      );
      await tester.pump();
    }

    final field = tester.widget<EditableText>(
      find.descendant(of: note, matching: find.byType(EditableText)),
    );
    expect(field.controller.text, 'LessIce');
  });

  testWidgets('order type controls expose button and selection semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, database, products);
    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.tap(find.byKey(const Key('open-current-order')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tại quán'));
    await tester.pumpAndSettle();

    final dineIn = tester.getSemantics(find.bySemanticsLabel('Tại quán'));
    expect(dineIn.flagsCollection.isButton, isTrue);
    expect(dineIn.flagsCollection.isEnabled, Tristate.isTrue);
    expect(dineIn.flagsCollection.isSelected, Tristate.isTrue);
    expect(dineIn.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final takeaway = tester.getSemantics(find.bySemanticsLabel('Mang về'));
    expect(takeaway.flagsCollection.isButton, isTrue);
    expect(takeaway.flagsCollection.isEnabled, Tristate.isTrue);
    expect(takeaway.flagsCollection.isSelected, Tristate.isFalse);
    expect(takeaway.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('removing one same-product line keeps the other note', (
    tester,
  ) async {
    await _pump(tester, database, products);
    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.tap(find.byKey(const Key('open-current-order')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cart-note-1')), 'Ít đá');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('sale-product-$productId')));
    await tester.tap(find.byKey(const Key('open-current-order')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cart-note-2')), 'Không đá');

    await tester.tap(find.byKey(const Key('remove-cart-line-1')));
    await tester.pump();

    expect(find.byKey(const Key('cart-note-1')), findsNothing);
    final remainingNote = find.byKey(const Key('cart-note-2'));
    expect(remainingNote, findsOneWidget);
    final remaining = tester.widget<EditableText>(
      find.descendant(of: remainingNote, matching: find.byType(EditableText)),
    );
    expect(remaining.controller.text, 'Không đá');
  });

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('sales and review fit ${width.toInt()} logical px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(tester, database, products);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(Key('sale-product-$productId')));
      await tester.tap(find.byKey(const Key('open-current-order')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
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
