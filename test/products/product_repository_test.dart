import 'dart:io';

import 'package:dakao_in_bill/core/money.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;
  late AppDatabase database;
  late ProductRepository repository;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('dakao_catalog_');
    databaseFile = File('${tempDirectory.path}/catalog.sqlite');
    database = AppDatabase.openFile(databaseFile);
    repository = ProductRepository(database, () => 1700000000000);
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('creates and renames categories with stable ordering', () async {
    final rice = await repository.createCategory('Cơm tấm');
    final drinks = await repository.createCategory('Nước');
    await repository.renameCategory(drinks, 'Nước giải khát');

    final categories = await repository.listCategories();
    expect(categories.map((item) => item.name), ['Cơm tấm', 'Nước giải khát']);
    expect(categories.map((item) => item.sortOrder), [0, 1]);
    expect(categories.first.id, rice);
  });

  test('category can be deactivated and activated without deletion', () async {
    final id = await repository.createCategory('Món thêm');
    await repository.setCategoryActive(id, false);
    expect((await repository.getCategory(id)).isActive, isFalse);

    await repository.setCategoryActive(id, true);
    expect((await repository.getCategory(id)).isActive, isTrue);
  });

  test('category ordering can be changed and remains contiguous', () async {
    await repository.createCategory('Một');
    await repository.createCategory('Hai');
    final third = await repository.createCategory('Ba');
    await repository.moveCategory(third, 0);

    final categories = await repository.listCategories();
    expect(categories.map((item) => item.name), ['Ba', 'Một', 'Hai']);
    expect(categories.map((item) => item.sortOrder), [0, 1, 2]);
  });

  test('creates product with approved catalog fields', () async {
    final categoryId = await repository.createCategory('Cơm tấm');
    final id = await repository.createProduct(
      ProductDraft(
        categoryId: categoryId,
        name: 'Cơm sườn',
        description: 'Sườn nướng than',
        price: 45000,
        imagePath: 'product-images/rice.jpg',
      ),
    );

    final product = await repository.getProduct(id);
    expect(product.name, 'Cơm sườn');
    expect(product.description, 'Sườn nướng than');
    expect(product.price, 45000);
    expect(product.imagePath, 'product-images/rice.jpg');
    expect(product.isAvailable, isTrue);
    expect(product.sortOrder, 0);
  });

  test('edits product name, price, and category', () async {
    final rice = await repository.createCategory('Cơm');
    final extras = await repository.createCategory('Món thêm');
    final id = await repository.createProduct(
      ProductDraft(categoryId: rice, name: 'Tên cũ', price: 10000),
    );

    await repository.updateProduct(
      id,
      ProductDraft(categoryId: extras, name: 'Tên mới', price: 25000),
    );

    final product = await repository.getProduct(id);
    expect(product.name, 'Tên mới');
    expect(product.price, 25000);
    expect(product.categoryId, extras);
  });

  test('availability toggle keeps product manageable', () async {
    final id = await _createProduct(repository, name: 'Canh');
    await repository.setProductAvailability(id, false);

    final products = await repository.listProducts();
    expect(products.single.id, id);
    expect(products.single.isAvailable, isFalse);
  });

  test(
    'soft delete excludes product from active queries and can restore it',
    () async {
      final id = await _createProduct(repository, name: 'Trà đá');
      await repository.softDeleteProduct(id);

      expect(await repository.listProducts(), isEmpty);
      expect((await repository.getProduct(id)).deletedAt, 1700000000000);

      await repository.restoreProduct(id);
      expect((await repository.listProducts()).single.id, id);
    },
  );

  test('invalid product prices and blank names are rejected', () async {
    final categoryId = await repository.createCategory('Cơm');
    await expectLater(
      repository.createProduct(
        ProductDraft(categoryId: categoryId, name: 'Sai', price: -1),
      ),
      throwsA(isA<DomainValidationException>()),
    );
    await expectLater(
      repository.createProduct(
        ProductDraft(categoryId: categoryId, name: '  ', price: 0),
      ),
      throwsA(isA<DomainValidationException>()),
    );
    await expectLater(
      repository.createProduct(
        ProductDraft(
          categoryId: categoryId,
          name: 'Quá lớn',
          price: sqliteMaxInteger + 1,
        ),
      ),
      throwsA(isA<DomainValidationException>()),
    );
  });

  test(
    'search is case insensitive and category filter composes with it',
    () async {
      final rice = await repository.createCategory('Cơm tấm');
      final drinks = await repository.createCategory('Nước');
      await repository.createProduct(
        ProductDraft(categoryId: rice, name: 'Cơm Sườn', price: 45000),
      );
      await repository.createProduct(
        ProductDraft(categoryId: rice, name: 'Cơm gà', price: 40000),
      );
      await repository.createProduct(
        ProductDraft(categoryId: drinks, name: 'Trà đá', price: 5000),
      );

      expect(
        (await repository.listProducts(search: 'SƯỜN')).single.name,
        'Cơm Sườn',
      );
      expect(
        (await repository.listProducts(
          search: 'cơm',
          categoryId: rice,
        )).map((item) => item.name),
        ['Cơm Sườn', 'Cơm gà'],
      );
      expect(
        await repository.listProducts(search: 'cơm', categoryId: drinks),
        isEmpty,
      );
    },
  );

  test('product ordering is stable within its category', () async {
    final categoryId = await repository.createCategory('Cơm');
    await repository.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Một', price: 1),
    );
    await repository.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Hai', price: 2),
    );

    final products = await repository.listProducts();
    expect(products.map((item) => item.name), ['Một', 'Hai']);
    expect(products.map((item) => item.sortOrder), [0, 1]);
  });

  test('visible reorder preserves soft-deleted product slots', () async {
    final first = await _createProduct(repository, name: 'Một');
    final hidden = await _createProduct(repository, name: 'Ẩn');
    final third = await _createProduct(repository, name: 'Ba');
    final fourth = await _createProduct(repository, name: 'Bốn');
    await repository.softDeleteProduct(hidden);

    await repository.reorderVisibleProducts([fourth, third, first]);

    expect((await repository.listProducts()).map((item) => item.name), [
      'Bốn',
      'Ba',
      'Một',
    ]);
    expect((await repository.getProduct(hidden)).sortOrder, 1);
    await repository.restoreProduct(hidden);
    expect((await repository.listProducts()).map((item) => item.name), [
      'Bốn',
      'Ẩn',
      'Ba',
      'Một',
    ]);
  });

  test('reorder requires the complete current visible product set', () async {
    final first = await _createProduct(repository, name: 'Một');
    await _createProduct(repository, name: 'Hai');

    await expectLater(
      repository.reorderVisibleProducts([first]),
      throwsA(isA<DomainValidationException>()),
    );
    expect((await repository.listProducts()).map((item) => item.name), [
      'Một',
      'Hai',
    ]);
  });

  test(
    'manual order survives edits, filters, appends, and database reopen',
    () async {
      final rice = await repository.createCategory('Cơm');
      final drinks = await repository.createCategory('Nước');
      final first = await repository.createProduct(
        ProductDraft(categoryId: rice, name: 'Cơm sườn', price: 45000),
      );
      final second = await repository.createProduct(
        ProductDraft(categoryId: drinks, name: 'Trà đào', price: 30000),
      );
      final third = await repository.createProduct(
        ProductDraft(categoryId: rice, name: 'Cơm gà', price: 40000),
      );

      await repository.reorderVisibleProducts([third, second, first]);
      await repository.updateProduct(
        second,
        ProductDraft(categoryId: drinks, name: 'Trà đào lớn', price: 35000),
      );
      await repository.setProductAvailability(first, false);
      final appended = await repository.createProduct(
        ProductDraft(categoryId: rice, name: 'Cơm chả', price: 38000),
      );

      expect((await repository.listProducts()).map((item) => item.id), [
        third,
        second,
        first,
        appended,
      ]);
      expect(
        (await repository.listProducts(categoryId: rice))
            .map((item) => item.id),
        [third, first, appended],
      );
      expect(
        (await repository.listProducts(search: 'cơm')).map((item) => item.id),
        [third, first, appended],
      );

      await database.close();
      database = AppDatabase.openFile(databaseFile);
      repository = ProductRepository(database, () => 1700000000200);
      expect((await repository.listProducts()).map((item) => item.id), [
        third,
        second,
        first,
        appended,
      ]);
    },
  );

  test('product and option attachments save atomically', () async {
    final categoryId = await repository.createCategory('Cơm');
    final options = ProductOptionRepository(database, () => 1700000000000);
    final groupId = await options.createGroup('Món thêm');
    final productId = await repository.createProductWithOptionGroups(
      ProductDraft(categoryId: categoryId, name: 'Cơm', price: 45000),
      [groupId],
    );
    expect(
      (await options.listAttachedGroupsForManagement(productId)).single.id,
      groupId,
    );

    await expectLater(
      repository.updateProductWithOptionGroups(
        productId,
        ProductDraft(
          categoryId: categoryId,
          name: 'Tên không được lưu',
          price: 1,
        ),
        [999999],
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect((await repository.getProduct(productId)).name, 'Cơm');
    expect(
      (await options.listAttachedGroupsForManagement(productId)).single.id,
      groupId,
    );
  });

  test('product edits leave historical order snapshots unchanged', () async {
    final productId = await _createProduct(
      repository,
      name: 'Cơm cũ',
      price: 45000,
    );
    final orderRepository = OrderRepository(
      database,
      nowEpochMillis: () => 1700000000100,
    );
    final orderId = await orderRepository.createOrder(
      OrderDraft(
        submissionToken: 'catalog-edit-snapshot',
        lines: [
          DraftLine(
            productId: productId,
            reviewedName: 'Cơm cũ',
            reviewedUnitPrice: 45000,
            quantity: 1,
          ),
        ],
      ),
    );
    final categoryId = (await repository.getProduct(productId)).categoryId;
    await repository.updateProduct(
      productId,
      ProductDraft(categoryId: categoryId, name: 'Cơm mới', price: 99000),
    );

    final order = await orderRepository.loadOrder(orderId);
    expect(order.items.single.productName, 'Cơm cũ');
    expect(order.items.single.unitPrice, 45000);
  });

  test('soft deletion leaves historical order snapshots unchanged', () async {
    final productId = await _createProduct(
      repository,
      name: 'Bún',
      price: 35000,
    );
    final orderRepository = OrderRepository(
      database,
      nowEpochMillis: () => 1700000000100,
    );
    final orderId = await orderRepository.createOrder(
      OrderDraft(
        submissionToken: 'catalog-delete-snapshot',
        lines: [
          DraftLine(
            productId: productId,
            reviewedName: 'Bún',
            reviewedUnitPrice: 35000,
            quantity: 2,
          ),
        ],
      ),
    );
    await repository.softDeleteProduct(productId);

    final order = await orderRepository.loadOrder(orderId);
    expect(order.items.single.productName, 'Bún');
    expect(order.items.single.lineTotal, 70000);
  });

  test('catalog data persists after database reopen', () async {
    final productId = await _createProduct(
      repository,
      name: 'Cà phê',
      price: 20000,
    );
    await database.close();

    database = AppDatabase.openFile(databaseFile);
    repository = ProductRepository(database, () => 1700000000200);

    final product = await repository.getProduct(productId);
    expect(product.name, 'Cà phê');
    expect((await repository.listCategories()).single.name, 'Danh mục');
  });
}

Future<int> _createProduct(
  ProductRepository repository, {
  required String name,
  int price = 10000,
}) async {
  final categories = await repository.listCategories();
  final categoryId = categories.isEmpty
      ? await repository.createCategory('Danh mục')
      : categories.first.id;
  return repository.createProduct(
    ProductDraft(categoryId: categoryId, name: name, price: price),
  );
}
