import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/database_provider.dart';
import 'product_image_store.dart';
import 'product_option_repository.dart';
import 'product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    ref.watch(appDatabaseProvider),
    () => DateTime.now().millisecondsSinceEpoch,
  );
});

final productOptionRepositoryProvider = Provider<ProductOptionRepository>((
  ref,
) {
  return ProductOptionRepository(
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

final optionManagementControllerProvider =
    AsyncNotifierProvider<OptionManagementController, List<CatalogOptionGroup>>(
      OptionManagementController.new,
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

  Future<int> createProductWithOptionGroups(
    ProductDraft draft,
    List<int> groupIds,
  ) async {
    final id = await _repository.createProductWithOptionGroups(draft, groupIds);
    _notifyCatalogChanged();
    await refresh();
    return id;
  }

  Future<void> updateProduct(int id, ProductDraft draft) async {
    await _repository.updateProduct(id, draft);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> updateProductWithOptionGroups(
    int id,
    ProductDraft draft,
    List<int> groupIds,
  ) async {
    await _repository.updateProductWithOptionGroups(id, draft, groupIds);
    _notifyCatalogChanged();
    await refresh();
  }

  Future<void> reorderProducts(List<int> productIds) async {
    await _repository.reorderVisibleProducts(productIds);
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

final class OptionManagementController
    extends AsyncNotifier<List<CatalogOptionGroup>> {
  ProductOptionRepository get _repository =>
      ref.read(productOptionRepositoryProvider);

  @override
  Future<List<CatalogOptionGroup>> build() => _repository.listGroups();

  Future<int> createGroup(String name) async {
    final id = await _repository.createGroup(name);
    await refresh();
    return id;
  }

  Future<void> renameGroup(int id, String name) async {
    await _repository.renameGroup(id, name);
    await refresh();
  }

  Future<void> setGroupActive(int id, bool value) async {
    await _repository.setGroupActive(id, value);
    await refresh();
  }

  Future<int> createOption({
    required int groupId,
    required String name,
    required int priceDelta,
  }) async {
    final id = await _repository.createOption(
      groupId: groupId,
      name: name,
      priceDelta: priceDelta,
    );
    await refresh();
    return id;
  }

  Future<void> updateOption(
    int id, {
    required String name,
    required int priceDelta,
  }) async {
    await _repository.updateOption(id, name: name, priceDelta: priceDelta);
    await refresh();
  }

  Future<void> setOptionActive(int id, bool value) async {
    await _repository.setOptionActive(id, value);
    await refresh();
  }

  Future<void> reorderOptions(int groupId, List<int> optionIds) async {
    await _repository.reorderOptions(groupId, optionIds);
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<CatalogOptionGroup>>();
    state = await AsyncValue.guard(_repository.listGroups);
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
