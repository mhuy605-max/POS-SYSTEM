import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/products/catalog_controller.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog controller composes query state and mutations', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = ProductRepository(database, () => 1000);
    final rice = await repository.createCategory('Cơm');
    final drinks = await repository.createCategory('Nước');
    await repository.createProduct(
      ProductDraft(categoryId: rice, name: 'Cơm sườn', price: 45000),
    );
    await repository.createProduct(
      ProductDraft(categoryId: drinks, name: 'Trà đá', price: 5000),
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        productRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      (await container.read(catalogControllerProvider.future)).products,
      hasLength(2),
    );
    await container.read(catalogControllerProvider.notifier).setSearch('trà');
    var state = await container.read(catalogControllerProvider.future);
    expect(state.products.single.name, 'Trà đá');
    expect(state.search, 'trà');

    await container.read(catalogControllerProvider.notifier).setCategory(rice);
    state = await container.read(catalogControllerProvider.future);
    expect(state.products, isEmpty);
    expect(state.categoryId, rice);
  });
}
