import 'dart:io';

import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProductRepository products;
  late ProductOptionRepository options;
  late Directory imageRoot;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    products = ProductRepository(database, () => 1000);
    options = ProductOptionRepository(database, () => 1000);
    imageRoot = await Directory.systemTemp.createTemp('dakao_management_');
  });

  tearDown(() async {
    await database.close();
    await imageRoot.delete(recursive: true);
  });

  testWidgets('Món sections switch and preserve product search state', (
    tester,
  ) async {
    await _pumpApp(tester, database, products, options, imageRoot);
    await _openProducts(tester);

    expect(find.text('Món ăn'), findsOneWidget);
    expect(find.text('Danh mục'), findsOneWidget);
    expect(find.text('Tùy chọn'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalog-search')), 'cơm');

    await tester.tap(find.text('Danh mục'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-list')), findsOneWidget);
    await tester.tap(find.text('Tùy chọn'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có nhóm tùy chọn'), findsOneWidget);
    await tester.tap(find.text('Món ăn'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('catalog-search')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'cơm',
    );
  });

  testWidgets('option group lifecycle remains manageable', (tester) async {
    await _pumpApp(tester, database, products, options, imageRoot);
    await _openProducts(tester);
    await tester.tap(find.text('Tùy chọn'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('option-group-name')),
      'Món thêm',
    );
    await tester.tap(find.byKey(const Key('save-option-group')));
    await tester.pumpAndSettle();
    final group = (await options.listGroups()).single;
    expect(find.text('Món thêm'), findsOneWidget);

    await tester.tap(find.byTooltip('Đổi tên nhóm'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('option-group-name')),
      'Topping',
    );
    await tester.tap(find.byKey(const Key('save-option-group')));
    await tester.pumpAndSettle();
    expect(find.text('Topping'), findsOneWidget);

    await tester.tap(find.byKey(Key('option-group-active-${group.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã tạm ẩn'), findsOneWidget);
    await tester.tap(find.byKey(Key('option-group-active-${group.id}')));
    await tester.pumpAndSettle();
    expect((await options.getGroup(group.id)).isActive, isTrue);
  });

  testWidgets('option item accepts zero price and soft lifecycle', (
    tester,
  ) async {
    final groupId = await options.createGroup('Món thêm');
    await _pumpApp(tester, database, products, options, imageRoot);
    await _openProducts(tester);
    await tester.tap(find.text('Tùy chọn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('option-group-$groupId')));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có lựa chọn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-option-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('option-item-name')),
      'Không hành',
    );
    await tester.enterText(find.byKey(const Key('option-item-price')), '0');
    await tester.tap(find.byKey(const Key('save-option-item')));
    await tester.pumpAndSettle();
    final item = (await options.getGroup(groupId)).items.single;
    expect(find.text('Không hành'), findsOneWidget);
    expect(find.textContaining('0đ'), findsOneWidget);

    await tester.tap(find.byTooltip('Sửa lựa chọn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('option-item-name')),
      'Hành thêm',
    );
    await tester.enterText(find.byKey(const Key('option-item-price')), '15000');
    await tester.tap(find.byKey(const Key('save-option-item')));
    await tester.pumpAndSettle();
    expect(find.text('Hành thêm'), findsOneWidget);
    expect(find.textContaining('+15.000đ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-option-item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('option-item-name')), 'Trứng');
    await tester.enterText(find.byKey(const Key('option-item-price')), '10000');
    await tester.tap(find.byKey(const Key('save-option-item')));
    await tester.pumpAndSettle();
    final second = (await options.getGroup(groupId)).items.last;
    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const Key('option-item-list')),
    );
    reorderable.onReorderItem!(1, 0);
    await tester.pumpAndSettle();
    expect((await options.getGroup(groupId)).items.first.id, second.id);

    await tester.tap(find.byKey(Key('option-active-${item.id}')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã tạm ẩn'), findsOneWidget);
    await tester.tap(find.byKey(Key('option-active-${item.id}')));
    await tester.pumpAndSettle();
    expect(
      (await options.getGroup(groupId)).items
          .singleWhere((option) => option.id == item.id)
          .isActive,
      isTrue,
    );
  });

  testWidgets('product form keeps inactive attached groups selected', (
    tester,
  ) async {
    final category = await products.createCategory('Cơm');
    final group = await options.createGroup('Món thêm');
    final product = await products.createProductWithOptionGroups(
      ProductDraft(categoryId: category, name: 'Cơm sườn', price: 45000),
      [group],
    );
    await options.setGroupActive(group, false);
    await _pumpApp(tester, database, products, options, imageRoot);
    await _openProducts(tester);
    await tester.tap(find.byKey(Key('product-$product')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('product-form-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(Key('attach-option-group-$group')),
    );
    expect(checkbox.value, isTrue);
    expect(find.textContaining('Đã tạm ẩn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();
    expect(
      (await options.listAttachedGroupsForManagement(product)).single.id,
      group,
    );
  });

  testWidgets('product reorder mode opens explicitly and saves order', (
    tester,
  ) async {
    final category = await products.createCategory('Cơm');
    final first = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Một', price: 1),
    );
    final second = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Hai', price: 2),
    );
    await _pumpApp(tester, database, products, options, imageRoot);
    await _openProducts(tester);

    await tester.tap(find.byKey(const Key('reorder-products')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-reorder-list')), findsOneWidget);
    final reorderable = tester.widget<ReorderableListView>(
      find.byKey(const Key('product-reorder-list')),
    );
    reorderable.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finish-product-reorder')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog-scroll')), findsOneWidget);
    expect((await products.listProducts()).map((item) => item.id), [
      second,
      first,
    ]);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase database,
  ProductRepository products,
  ProductOptionRepository options,
  Directory imageRoot,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productRepositoryProvider.overrideWithValue(products),
        productOptionRepositoryProvider.overrideWithValue(options),
        productImageStoreProvider.overrideWith(
          (ref) async => ProductImageStore(imageRoot),
        ),
      ],
      child: const DakaoInBillApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openProducts(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text('Món')),
  );
  await tester.pumpAndSettle();
}
