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
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Checkpoint 5 management flows persist on Android', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final products = ProductRepository(database, () => 1000);
    final options = ProductOptionRepository(database, () => 1000);
    final category = await products.createCategory('Cơm');
    final rice = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Cơm sườn', price: 45000),
    );
    final second = await products.createProduct(
      ProductDraft(categoryId: category, name: 'Cơm gà', price: 40000),
    );
    final root = Directory(
      '${(await getTemporaryDirectory()).path}/checkpoint5-images',
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          productRepositoryProvider.overrideWithValue(products),
          productOptionRepositoryProvider.overrideWithValue(options),
          productImageStoreProvider.overrideWith(
            (ref) async => ProductImageStore(root),
          ),
        ],
        child: const DakaoInBillApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await _openProducts(tester);

    // Flow A: create the reusable group and all four configured choices.
    await tester.tap(find.text('Tùy chọn'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('add-option-group')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.enterText(
      find.byKey(const Key('option-group-name')),
      'Món thêm',
    );
    await tester.tap(find.byKey(const Key('save-option-group')));
    await tester.pump(const Duration(milliseconds: 700));
    final groupId = (await options.listGroups()).single.id;
    await tester.tap(find.byKey(Key('option-group-$groupId')));
    await tester.pump(const Duration(milliseconds: 700));

    for (final entry in const [
      ('Sườn thêm', 45000),
      ('Trứng thêm', 30000),
      ('Bì thêm', 15000),
      ('Chả thêm', 20000),
    ]) {
      await tester.tap(find.byKey(const Key('add-option-item')));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.enterText(
        find.byKey(const Key('option-item-name')),
        entry.$1,
      );
      await tester.enterText(
        find.byKey(const Key('option-item-price')),
        entry.$2.toString(),
      );
      await tester.tap(find.byKey(const Key('save-option-item')));
      await tester.pump(const Duration(milliseconds: 700));
    }
    expect(find.text('+45.000đ · Đang bật'), findsOneWidget);
    expect(find.text('+30.000đ · Đang bật'), findsOneWidget);
    expect(find.text('+15.000đ · Đang bật'), findsOneWidget);
    expect(find.text('+20.000đ · Đang bật'), findsOneWidget);
    final initial = await options.getGroup(groupId);
    expect(initial.items.map((item) => item.name), [
      'Sườn thêm',
      'Trứng thêm',
      'Bì thêm',
      'Chả thêm',
    ]);
    final reordered = tester.widget<ReorderableListView>(
      find.byKey(const Key('option-item-list')),
    );
    reordered.onReorderItem!(3, 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect((await options.getGroup(groupId)).items.first.name, 'Chả thêm');
    final loinId = initial.items.first.id;
    await tester.tap(find.byKey(Key('option-active-$loinId')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      (await options.getGroup(groupId)).items
          .singleWhere((item) => item.id == loinId)
          .isActive,
      isFalse,
    );
    await tester.tap(find.byKey(Key('option-active-$loinId')));
    await tester.pump(const Duration(milliseconds: 700));
    final restoredLoin = (await options.getGroup(groupId)).items
        .singleWhere((item) => item.id == loinId);
    expect(restoredLoin.isActive, isTrue);
    expect(restoredLoin.name, 'Sườn thêm');
    expect(restoredLoin.priceDelta, 45000);
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('4 lựa chọn · Đang bật'), findsOneWidget);

    // Flow B: attach, reopen, then preserve the attachment while inactive.
    await tester.tap(find.text('Món ăn'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(Key('product-$rice')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.drag(
      find.byKey(const Key('product-form-scroll')),
      const Offset(0, -900),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(Key('attach-option-group-$groupId')));
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      (await options.listAttachedGroupsForManagement(rice)).single.id,
      groupId,
    );

    await tester.tap(find.text('Tùy chọn'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(Key('option-group-active-$groupId')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('confirm-deactivate-option-group')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.text('Món ăn'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(Key('product-$rice')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.drag(
      find.byKey(const Key('product-form-scroll')),
      const Offset(0, -900),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(Key('attach-option-group-$groupId')),
          )
          .value,
      isTrue,
    );
    expect(find.textContaining('Đã tạm ẩn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      (await options.listAttachedGroupsForManagement(rice)).single.id,
      groupId,
    );
    await tester.tap(find.text('Tùy chọn'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(Key('option-group-active-$groupId')));
    await tester.pump(const Duration(milliseconds: 700));

    // Flow C: explicit reorder screen persists the sales-facing order.
    await tester.tap(find.text('Món ăn'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('reorder-products')));
    await tester.pump(const Duration(milliseconds: 700));
    final productList = tester.widget<ReorderableListView>(
      find.byKey(const Key('product-reorder-list')),
    );
    productList.onReorderItem!(1, 0);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('finish-product-reorder')));
    await tester.pump(const Duration(seconds: 1));
    expect((await products.listProducts()).map((item) => item.id), [
      second,
      rice,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}

Future<void> _openProducts(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text('Món')),
  );
  await tester.pump(const Duration(milliseconds: 700));
}
