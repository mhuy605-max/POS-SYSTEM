import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database_provider.dart';
import 'product_image_store.dart';
import 'product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    ref.watch(appDatabaseProvider),
    () => DateTime.now().millisecondsSinceEpoch,
  );
});

final productImageStoreProvider = FutureProvider<ProductImageStore>((
  ref,
) async {
  return ProductImageStore(await getApplicationSupportDirectory());
});

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogState>(
      CatalogController.new,
    );

final categoryControllerProvider =
    AsyncNotifierProvider<CategoryController, List<CatalogCategory>>(
      CategoryController.new,
    );

final catalogRevisionProvider = NotifierProvider<CatalogRevision, int>(
  CatalogRevision.new,
);

final class CatalogRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final class CatalogState {
  const CatalogState({
    required this.categories,
    required this.products,
    this.search = '',
    this.categoryId,
  });

  final List<CatalogCategory> categories;
  final List<CatalogProduct> products;
  final String search;
  final int? categoryId;
}

final class CatalogController extends AsyncNotifier<CatalogState> {
  ProductRepository get _repository => ref.read(productRepositoryProvider);

  @override
  Future<CatalogState> build() => _load();

  Future<void> setSearch(String value) async {
    final current = state.value ?? await future;
    state = AsyncData(
      await _load(search: value, categoryId: current.categoryId),
    );
  }

  Future<void> setCategory(int? categoryId) async {
    final current = state.value ?? await future;
    state = AsyncData(
      await _load(search: current.search, categoryId: categoryId),
    );
  }

  Future<int> createProduct(ProductDraft draft) async {
    final id = await _repository.createProduct(draft);
    _notifyCatalogChanged();
    await refresh();
    return id;
  }

  Future<void> updateProduct(int id, ProductDraft draft) async {
    await _repository.updateProduct(id, draft);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> setAvailability(int id, bool value) async {
    await _repository.setProductAvailability(id, value);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> deleteProduct(int id) async {
    await _repository.softDeleteProduct(id);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> restoreProduct(int id) async {
    await _repository.restoreProduct(id);
    _notifyCatalogChanged();
    await refresh();
  }

  void _notifyCatalogChanged() =>
      ref.read(catalogRevisionProvider.notifier).bump();

  Future<void> refresh() async {
    final current = state.value;
    state = const AsyncLoading<CatalogState>();
    state = await AsyncValue.guard(
      () =>
          _load(search: current?.search ?? '', categoryId: current?.categoryId),
    );
  }

  Future<CatalogState> _load({String search = '', int? categoryId}) async {
    final categories = await _repository.listCategories();
    final effectiveCategoryId =
        categories.any(
          (category) => category.id == categoryId && category.isActive,
        )
        ? categoryId
        : null;
    final products = await _repository.listProducts(
      search: search,
      categoryId: effectiveCategoryId,
    );
    return CatalogState(
      categories: categories,
      products: products,
      search: search,
      categoryId: effectiveCategoryId,
    );
  }
}

final class CategoryController extends AsyncNotifier<List<CatalogCategory>> {
  ProductRepository get _repository => ref.read(productRepositoryProvider);

  @override
  Future<List<CatalogCategory>> build() => _repository.listCategories();

  Future<void> create(String name) async {
    await _repository.createCategory(name);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> rename(int id, String name) async {
    await _repository.renameCategory(id, name);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> setActive(int id, bool value) async {
    await _repository.setCategoryActive(id, value);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> move(int id, int newIndex) async {
    await _repository.moveCategory(id, newIndex);
    _notifyCatalogChanged();
    await refresh();
  }

  void _notifyCatalogChanged() =>
      ref.read(catalogRevisionProvider.notifier).bump();

  Future<void> refresh() async {
    state = const AsyncLoading<List<CatalogCategory>>();
    state = await AsyncValue.guard(_repository.listCategories);
  }
}
