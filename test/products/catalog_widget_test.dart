import 'dart:io';

import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/app/theme.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProductRepository repository;
  late Directory imageRoot;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ProductRepository(database, () => 1000);
    imageRoot = await Directory.systemTemp.createTemp('dakao_images_');
  });

  tearDown(() async {
    await database.close();
    await imageRoot.delete(recursive: true);
  });

  testWidgets(
    'catalog searches, filters, and keeps unavailable products visible',
    (tester) async {
      final rice = await repository.createCategory('Cơm');
      final drinks = await repository.createCategory('Nước');
      final riceId = await repository.createProduct(
        ProductDraft(categoryId: rice, name: 'Cơm sườn', price: 45000),
      );
      await repository.createProduct(
        ProductDraft(categoryId: drinks, name: 'Trà đá', price: 5000),
      );
      await _pumpApp(tester, database, repository, imageRoot);
      await _openCatalog(tester);

      await tester.tap(find.byKey(Key('availability-$riceId')));
      await tester.pumpAndSettle();
      expect(find.text('Hết món'), findsOneWidget);
      expect(find.text('Cơm sườn'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('catalog-search')), 'trà');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Trà đá'), findsOneWidget);
      expect(find.text('Cơm sườn'), findsNothing);

      await tester.tap(find.text('Cơm').last);
      await tester.pumpAndSettle();
      expect(find.text('Không tìm thấy món'), findsOneWidget);
      expect(find.text('Thử từ khóa hoặc danh mục khác.'), findsOneWidget);
    },
  );

  testWidgets('adds a product through the approved form flow', (tester) async {
    await repository.createCategory('Cơm tấm');
    await _pumpApp(tester, database, repository, imageRoot);
    await _openCatalog(tester);

    await tester.tap(find.byKey(const Key('add-product')));
    await tester.pumpAndSettle();
    expect(find.text('Thêm món'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('product-form-scroll')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Tùy chọn').last).style?.color,
      AppColors.secondaryInk,
    );
    await tester.drag(
      find.byKey(const Key('product-form-scroll')),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('product-name')),
      'Cơm sườn bì',
    );
    await tester.enterText(find.byKey(const Key('product-price')), '55000');
    await tester.tap(find.byKey(const Key('save-product')));
    await tester.pumpAndSettle();

    expect(find.text('Cơm sườn bì'), findsOneWidget);
    expect(find.text('55.000đ'), findsOneWidget);
  });

  testWidgets('empty catalog and filtered miss have distinct guidance', (
    tester,
  ) async {
    await _pumpApp(tester, database, repository, imageRoot);
    await _openCatalog(tester);

    expect(find.text('Chưa có món nào'), findsOneWidget);
    expect(find.text('Thêm món đầu tiên để bắt đầu bán hàng.'), findsOneWidget);
    expect(find.text('Thêm món đầu tiên'), findsOneWidget);
    expect(find.byKey(const Key('add-product')), findsOneWidget);
    expect(find.text('Thêm món mới'), findsNothing);

    final categoryId = await repository.createCategory('Món Việt');
    await repository.createProduct(
      ProductDraft(
        categoryId: categoryId,
        name: 'Bún thịt nướng chả giò đặc biệt',
        price: 65000,
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _pumpApp(tester, database, repository, imageRoot);
    await _openCatalog(tester);
    await tester.enterText(
      find.byKey(const Key('catalog-search')),
      'không tồn tại',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Không tìm thấy món'), findsOneWidget);
    expect(find.text('Thử từ khóa hoặc danh mục khác.'), findsOneWidget);
    expect(find.text('Thêm món đầu tiên'), findsNothing);
    expect(find.byKey(const Key('add-product')), findsNothing);
  });

  testWidgets('soft delete offers a working restore action', (tester) async {
    final categoryId = await repository.createCategory('Cơm');
    final productId = await repository.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Món thử', price: 10000),
    );
    await _pumpApp(tester, database, repository, imageRoot);
    await _openCatalog(tester);

    await tester.tap(find.byKey(Key('product-$productId')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('product-form-scroll')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-product')));
    await tester.pumpAndSettle();
    expect(find.text('Món thử'), findsNothing);

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(find.text('Món thử'), findsOneWidget);
    expect((await repository.getProduct(productId)).deletedAt, isNull);
  });

  testWidgets(
    'category management creates, renames, and deactivates a category',
    (tester) async {
      await repository.createCategory('Tên cũ');
      await _pumpApp(tester, database, repository, imageRoot);
      await _openCatalog(tester);

      await tester.tap(find.byKey(const Key('manage-categories')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('new-category-name')),
        'Món thêm',
      );
      await tester.tap(find.byKey(const Key('add-category')));
      await tester.pumpAndSettle();
      expect(find.text('Món thêm'), findsOneWidget);

      await tester.tap(find.byTooltip('Đổi tên').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('rename-category-field')),
        'Cơm tấm',
      );
      await tester.tap(find.byKey(const Key('confirm-rename-category')));
      await tester.pumpAndSettle();
      expect(find.text('Cơm tấm'), findsOneWidget);

      final first = (await repository.listCategories()).first;
      await tester.tap(find.byKey(Key('category-active-${first.id}')));
      await tester.pumpAndSettle();
      expect((await repository.getCategory(first.id)).isActive, isFalse);
    },
  );

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
      'catalog screens do not overflow at ${width.toInt()} logical px',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final categoryId = await repository.createCategory('Cơm tấm');
        await repository.createProduct(
          ProductDraft(
            categoryId: categoryId,
            name: 'Cơm sườn bì chả đặc biệt',
            price: 55000,
          ),
        );
        await _pumpApp(tester, database, repository, imageRoot);
        await _openCatalog(tester);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('add-product')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('manage-categories')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppDatabase database,
  ProductRepository repository,
  Directory imageRoot,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productRepositoryProvider.overrideWithValue(repository),
        productImageStoreProvider.overrideWith(
          (ref) async => ProductImageStore(imageRoot),
        ),
      ],
      child: const DakaoInBillApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCatalog(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text('Món')),
  );
  await tester.pumpAndSettle();
}
