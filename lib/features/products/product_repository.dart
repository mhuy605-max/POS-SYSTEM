import 'package:drift/drift.dart';

import '../../core/money.dart';
import '../../data/app_database.dart';
import '../orders/order_repository.dart' show EpochClock;

final class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;
}

final class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.isAvailable,
    required this.sortOrder,
    required this.deletedAt,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final String name;
  final String? description;
  final int price;
  final String? imagePath;
  final bool isAvailable;
  final int sortOrder;
  final int? deletedAt;
}

final class ProductDraft {
  const ProductDraft({
    required this.categoryId,
    required this.name,
    required this.price,
    this.description,
    this.imagePath,
    this.isAvailable = true,
  });

  final int categoryId;
  final String name;
  final String? description;
  final int price;
  final String? imagePath;
  final bool isAvailable;
}

final class ProductRepository {
  ProductRepository(this._database, this._nowEpochMillis);

  final AppDatabase _database;
  final EpochClock _nowEpochMillis;

  Future<List<CatalogCategory>> listCategories() async {
    final rows =
        await (_database.select(_database.categories)..orderBy([
              (row) => OrderingTerm.asc(row.sortOrder),
              (row) => OrderingTerm.asc(row.id),
            ]))
            .get();
    return rows.map(_mapCategory).toList(growable: false);
  }

  Future<CatalogCategory> getCategory(int id) async {
    final row = await (_database.select(
      _database.categories,
    )..where((row) => row.id.equals(id))).getSingle();
    return _mapCategory(row);
  }

  Future<int> createCategory(String name) async {
    final checkedName = _checkedName(name, field: 'Category name');
    return _database.transaction(() async {
      final maxOrder = await _maxValue('categories', 'sort_order');
      final now = _nowEpochMillis();
      return _database
          .into(_database.categories)
          .insert(
            CategoriesCompanion.insert(
              name: checkedName,
              sortOrder: Value(maxOrder + 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<void> renameCategory(int id, String name) async {
    await (_database.update(
      _database.categories,
    )..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(_checkedName(name, field: 'Category name')),
        updatedAt: Value(_nowEpochMillis()),
      ),
    );
  }

  Future<void> setCategoryActive(int id, bool isActive) async {
    await (_database.update(
      _database.categories,
    )..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        isActive: Value(isActive),
        updatedAt: Value(_nowEpochMillis()),
      ),
    );
  }

  Future<void> moveCategory(int id, int newIndex) async {
    await _database.transaction(() async {
      final categories = await listCategories();
      final currentIndex = categories.indexWhere(
        (category) => category.id == id,
      );
      if (currentIndex < 0) {
        throw StateError('Category $id does not exist.');
      }
      final target = newIndex.clamp(0, categories.length - 1);
      final reordered = [...categories];
      final moved = reordered.removeAt(currentIndex);
      reordered.insert(target, moved);
      final now = _nowEpochMillis();
      for (var index = 0; index < reordered.length; index++) {
        await (_database.update(
          _database.categories,
        )..where((row) => row.id.equals(reordered[index].id))).write(
          CategoriesCompanion(sortOrder: Value(index), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<List<CatalogProduct>> listProducts({
    String search = '',
    int? categoryId,
  }) async {
    final query =
        _database.select(_database.products).join([
            innerJoin(
              _database.categories,
              _database.categories.id.equalsExp(_database.products.categoryId),
            ),
          ])
          ..where(_database.products.deletedAt.isNull())
          ..orderBy([
            OrderingTerm.asc(_database.products.sortOrder),
            OrderingTerm.asc(_database.products.id),
          ]);
    if (categoryId != null) {
      query.where(_database.products.categoryId.equals(categoryId));
    }
    final rows = await query.get();
    final normalizedSearch = search.trim().toLowerCase();
    return rows
        .map(_mapJoinedProduct)
        .where(
          (product) =>
              normalizedSearch.isEmpty ||
              product.name.toLowerCase().contains(normalizedSearch),
        )
        .toList(growable: false);
  }

  Future<CatalogProduct> getProduct(int id) async {
    final query = _database.select(_database.products).join([
      innerJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.products.categoryId),
      ),
    ])..where(_database.products.id.equals(id));
    return _mapJoinedProduct(await query.getSingle());
  }

  Future<int> createProduct(ProductDraft draft) async {
    final checked = await _validateDraft(draft);
    return _database.transaction(() async {
      final maxOrder = await _maxValue('products', 'sort_order');
      final now = _nowEpochMillis();
      return _database
          .into(_database.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: checked.categoryId,
              name: checked.name,
              description: Value(checked.description),
              price: checked.price,
              imagePath: Value(checked.imagePath),
              isAvailable: Value(checked.isAvailable),
              sortOrder: Value(maxOrder + 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<void> updateProduct(int id, ProductDraft draft) async {
    final checked = await _validateDraft(draft);
    final changed =
        await (_database.update(
          _database.products,
        )..where((row) => row.id.equals(id))).write(
          ProductsCompanion(
            categoryId: Value(checked.categoryId),
            name: Value(checked.name),
            description: Value(checked.description),
            price: Value(checked.price),
            imagePath: Value(checked.imagePath),
            isAvailable: Value(checked.isAvailable),
            updatedAt: Value(_nowEpochMillis()),
          ),
        );
    if (changed != 1) {
      throw StateError('Product $id does not exist.');
    }
  }

  Future<void> setProductAvailability(int id, bool isAvailable) async {
    await (_database.update(
      _database.products,
    )..where((row) => row.id.equals(id))).write(
      ProductsCompanion(
        isAvailable: Value(isAvailable),
        updatedAt: Value(_nowEpochMillis()),
      ),
    );
  }

  Future<void> softDeleteProduct(int id) async {
    await (_database.update(
      _database.products,
    )..where((row) => row.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: Value(_nowEpochMillis()),
        updatedAt: Value(_nowEpochMillis()),
      ),
    );
  }

  Future<void> restoreProduct(int id) async {
    await (_database.update(
      _database.products,
    )..where((row) => row.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(_nowEpochMillis()),
      ),
    );
  }

  Future<ProductDraft> _validateDraft(ProductDraft draft) async {
    if (draft.price < 0) {
      throw const DomainValidationException('Price cannot be negative.');
    }
    if (draft.price > sqliteMaxInteger) {
      throw const DomainValidationException('Price exceeds SQLite limits.');
    }
    final name = _checkedName(draft.name, field: 'Product name');
    if (name.length > 40) {
      throw const DomainValidationException(
        'Product name cannot exceed 40 characters.',
      );
    }
    await getCategory(draft.categoryId);
    final description = _trimmedOrNull(draft.description);
    final imagePath = _trimmedOrNull(draft.imagePath);
    return ProductDraft(
      categoryId: draft.categoryId,
      name: name,
      price: draft.price,
      description: description,
      imagePath: imagePath,
      isAvailable: draft.isAvailable,
    );
  }

  Future<int> _maxValue(String table, String column) async {
    final row = await _database
        .customSelect('SELECT MAX($column) AS maximum FROM $table')
        .getSingle();
    return row.readNullable<int>('maximum') ?? -1;
  }

  CatalogProduct _mapJoinedProduct(TypedResult row) {
    final product = row.readTable(_database.products);
    final category = row.readTable(_database.categories);
    return CatalogProduct(
      id: product.id,
      categoryId: product.categoryId,
      categoryName: category.name,
      name: product.name,
      description: product.description,
      price: product.price,
      imagePath: product.imagePath,
      isAvailable: product.isAvailable,
      sortOrder: product.sortOrder,
      deletedAt: product.deletedAt,
    );
  }
}

CatalogCategory _mapCategory(Category row) => CatalogCategory(
  id: row.id,
  name: row.name,
  sortOrder: row.sortOrder,
  isActive: row.isActive,
);

String _checkedName(String value, {required String field}) {
  final result = value.trim();
  if (result.isEmpty) {
    throw DomainValidationException('$field is required.');
  }
  return result;
}

String? _trimmedOrNull(String? value) {
  final result = value?.trim();
  return result == null || result.isEmpty ? null : result;
}
