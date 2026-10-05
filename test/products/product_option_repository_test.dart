import 'dart:io';

import 'package:dakao_in_bill/core/money.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;
  late AppDatabase database;
  late ProductRepository products;
  late ProductOptionRepository repository;
  var now = 1700000000000;

  setUp(() async {
    now = 1700000000000;
    tempDirectory = await Directory.systemTemp.createTemp('dakao_options_');
    databaseFile = File('${tempDirectory.path}/options.sqlite');
    database = AppDatabase.openFile(databaseFile);
    products = ProductRepository(database, () => now);
    repository = ProductOptionRepository(database, () => now);
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'creates trimmed active groups by appending deterministic order',
    () async {
      final firstId = await repository.createGroup('  Món thêm  ');
      final secondId = await repository.createGroup('Kích cỡ');

      final groups = await repository.listGroups();
      expect(groups.map((group) => group.id), [firstId, secondId]);
      expect(groups.map((group) => group.name), ['Món thêm', 'Kích cỡ']);
      expect(groups.map((group) => group.sortOrder), [0, 1]);
      expect(groups.every((group) => group.isActive), isTrue);
      expect(groups.first.createdAt, now);
      expect(groups.first.updatedAt, now);
    },
  );

  test('rejects a blank group name before writing', () async {
    await expectLater(
      repository.createGroup(' \n '),
      throwsA(isA<DomainValidationException>()),
    );
    expect(await repository.listGroups(), isEmpty);
  });

  test('renames a group without changing identity or order', () async {
    final id = await repository.createGroup('Tên cũ');
    await repository.createGroup('Nhóm hai');
    now++;

    await repository.renameGroup(id, '  Tên mới ');

    final group = await repository.getGroup(id);
    expect(group.id, id);
    expect(group.name, 'Tên mới');
    expect(group.sortOrder, 0);
    expect(group.createdAt, 1700000000000);
    expect(group.updatedAt, now);
  });

  test(
    'deactivates and reactivates a group without losing its contents',
    () async {
      final groupId = await repository.createGroup('Món thêm');
      final optionId = await repository.createOption(
        groupId: groupId,
        name: 'Trứng',
        priceDelta: 30000,
      );
      final productId = await _createProduct(products, name: 'Cơm tấm');
      await repository.attachGroupToProduct(productId, groupId);

      await repository.setGroupActive(groupId, false);
      expect((await repository.listGroups()).single.isActive, isFalse);
      expect((await repository.getGroup(groupId)).items.single.id, optionId);
      expect((await repository.listGroups(includeInactive: false)), isEmpty);
      expect(
        (await repository.listAttachedGroupsForManagement(productId)).single.id,
        groupId,
      );
      expect(await repository.listSelectableGroupsForSales(productId), isEmpty);

      await repository.setGroupActive(groupId, true);
      expect(
        (await repository.listSelectableGroupsForSales(productId)).single.id,
        groupId,
      );
    },
  );

  test('creates options with integer VND and validates input', () async {
    final groupId = await repository.createGroup('Món thêm');
    final first = await repository.createOption(
      groupId: groupId,
      name: '  Sườn thêm ',
      priceDelta: 45000,
    );
    final free = await repository.createOption(
      groupId: groupId,
      name: 'Rau thêm',
      priceDelta: 0,
    );

    final group = await repository.getGroup(groupId);
    expect(group.items.map((item) => item.id), [first, free]);
    expect(group.items.map((item) => item.name), ['Sườn thêm', 'Rau thêm']);
    expect(group.items.map((item) => item.priceDelta), [45000, 0]);
    expect(group.items.map((item) => item.sortOrder), [0, 1]);
    expect(group.items.every((item) => item.isActive), isTrue);

    await expectLater(
      repository.createOption(groupId: groupId, name: ' ', priceDelta: 1),
      throwsA(isA<DomainValidationException>()),
    );
    await expectLater(
      repository.createOption(groupId: groupId, name: 'Sai', priceDelta: -1),
      throwsA(isA<DomainValidationException>()),
    );
    await expectLater(
      repository.createOption(groupId: 9999, name: 'Sai', priceDelta: 1),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'updates an option name and price while preserving identity and order',
    () async {
      final groupId = await repository.createGroup('Món thêm');
      final id = await repository.createOption(
        groupId: groupId,
        name: 'Trứng',
        priceDelta: 20000,
      );
      now++;

      await repository.updateOption(
        id,
        name: '  Trứng ốp la ',
        priceDelta: 30000,
      );

      final option = (await repository.getGroup(groupId)).items.single;
      expect(option.id, id);
      expect(option.name, 'Trứng ốp la');
      expect(option.priceDelta, 30000);
      expect(option.sortOrder, 0);
      expect(option.createdAt, 1700000000000);
      expect(option.updatedAt, now);

      await expectLater(
        repository.updateOption(id, name: 'Sai', priceDelta: -1),
        throwsA(isA<DomainValidationException>()),
      );
      expect(
        (await repository.getGroup(groupId)).items.single.priceDelta,
        30000,
      );
    },
  );

  test(
    'option soft lifecycle is retained for management and filtered in sales',
    () async {
      final groupId = await repository.createGroup('Món thêm');
      final optionId = await repository.createOption(
        groupId: groupId,
        name: 'Bì',
        priceDelta: 15000,
      );
      final productId = await _createProduct(products, name: 'Cơm');
      await repository.attachGroupToProduct(productId, groupId);

      await repository.setOptionActive(optionId, false);
      expect(
        (await repository.getGroup(groupId)).items.single.isActive,
        isFalse,
      );
      expect(
        (await repository.listAttachedGroupsForManagement(productId))
            .single
            .items
            .single
            .id,
        optionId,
      );
      expect(
        (await repository.listSelectableGroupsForSales(productId)).single.items,
        isEmpty,
      );

      await repository.setOptionActive(optionId, true);
      expect(
        (await repository.listSelectableGroupsForSales(productId))
            .single
            .items
            .single
            .id,
        optionId,
      );
    },
  );

  test(
    'reorders every option in one group and persists after reopen',
    () async {
      final groupId = await repository.createGroup('Món thêm');
      final first = await _createOption(repository, groupId, 'Một');
      final second = await _createOption(repository, groupId, 'Hai');
      final third = await _createOption(repository, groupId, 'Ba');
      await repository.setOptionActive(second, false);

      await repository.reorderOptions(groupId, [third, first, second]);
      await database.close();
      database = AppDatabase.openFile(databaseFile);
      repository = ProductOptionRepository(database, () => now);

      final items = (await repository.getGroup(groupId)).items;
      expect(items.map((item) => item.id), [third, first, second]);
      expect(items.map((item) => item.sortOrder), [0, 1, 2]);
      expect(items.last.isActive, isFalse);
    },
  );

  test('invalid reorders are rejected atomically', () async {
    final groupId = await repository.createGroup('Nhóm một');
    final first = await _createOption(repository, groupId, 'Một');
    final second = await _createOption(repository, groupId, 'Hai');
    final otherGroup = await repository.createGroup('Nhóm hai');
    final foreign = await _createOption(repository, otherGroup, 'Ngoài');

    for (final invalid in <List<int>>[
      [first, first],
      [first],
      [first, foreign],
      [first, 9999],
    ]) {
      await expectLater(
        repository.reorderOptions(groupId, invalid),
        throwsA(anyOf(isA<DomainValidationException>(), isA<StateError>())),
      );
      final items = (await repository.getGroup(groupId)).items;
      expect(items.map((item) => item.id), [first, second]);
      expect(items.map((item) => item.sortOrder), [0, 1]);
    }
  });

  test(
    'reuses groups across products and attaches many groups to one product',
    () async {
      final rice = await _createProduct(products, name: 'Cơm');
      final noodles = await _createProduct(products, name: 'Bún');
      final extras = await repository.createGroup('Món thêm');
      final sauces = await repository.createGroup('Nước sốt');

      await repository.attachGroupToProduct(rice, extras);
      await repository.attachGroupToProduct(rice, sauces);
      await repository.attachGroupToProduct(noodles, extras);
      await repository.attachGroupToProduct(rice, extras);

      expect(
        (await repository.listAttachedGroupsForManagement(rice))
            .map((group) => group.id),
        [extras, sauces],
      );
      expect(
        (await repository.listAttachedGroupsForManagement(noodles))
            .map((group) => group.id),
        [extras],
      );
    },
  );

  test(
    'detach removes only the requested link and keeps catalog definitions',
    () async {
      final firstProduct = await _createProduct(products, name: 'Cơm');
      final secondProduct = await _createProduct(products, name: 'Bún');
      final groupId = await repository.createGroup('Món thêm');
      final optionId = await _createOption(repository, groupId, 'Chả');
      await repository.attachGroupToProduct(firstProduct, groupId);
      await repository.attachGroupToProduct(secondProduct, groupId);

      await repository.detachGroupFromProduct(firstProduct, groupId);

      expect(
        await repository.listAttachedGroupsForManagement(firstProduct),
        isEmpty,
      );
      expect(
        (await repository.listAttachedGroupsForManagement(secondProduct))
            .single
            .id,
        groupId,
      );
      expect((await repository.getGroup(groupId)).items.single.id, optionId);
    },
  );

  test(
    'replaces attachments atomically and rejects duplicates or invalid IDs',
    () async {
      final productId = await _createProduct(products, name: 'Cơm');
      final first = await repository.createGroup('Một');
      final second = await repository.createGroup('Hai');
      final third = await repository.createGroup('Ba');
      await repository.setProductOptionGroups(productId, [first, second]);

      await repository.setProductOptionGroups(productId, [third, second]);
      expect(
        (await repository.listAttachedGroupsForManagement(productId))
            .map((group) => group.id),
        [second, third],
      );

      for (final invalid in <List<int>>[
        [second, second],
        [second, 9999],
      ]) {
        await expectLater(
          repository.setProductOptionGroups(productId, invalid),
          throwsA(anyOf(isA<DomainValidationException>(), isA<StateError>())),
        );
        expect(
          (await repository.listAttachedGroupsForManagement(productId))
              .map((group) => group.id),
          [second, third],
        );
      }
    },
  );

  test(
    'rejects attachments to deleted products without partial mutation',
    () async {
      final productId = await _createProduct(products, name: 'Cơm');
      final groupId = await repository.createGroup('Món thêm');
      await products.softDeleteProduct(productId);

      await expectLater(
        repository.attachGroupToProduct(productId, groupId),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.setProductOptionGroups(productId, [groupId]),
        throwsA(isA<StateError>()),
      );
      final count = await database.select(database.productOptionGroups).get();
      expect(count, isEmpty);
    },
  );

  test(
    'sales query filters inactive data and keeps canonical ordering',
    () async {
      final productId = await _createProduct(products, name: 'Cơm');
      final firstGroup = await repository.createGroup('Món thêm');
      final secondGroup = await repository.createGroup('Nước sốt');
      final first = await _createOption(repository, firstGroup, 'Sườn');
      final inactiveOption = await _createOption(
        repository,
        firstGroup,
        'Trứng',
      );
      final third = await _createOption(repository, firstGroup, 'Chả');
      await repository.reorderOptions(firstGroup, [
        third,
        first,
        inactiveOption,
      ]);
      await repository.setOptionActive(inactiveOption, false);
      await _createOption(repository, secondGroup, 'Sốt tiêu');
      await repository.attachGroupToProduct(productId, firstGroup);
      await repository.attachGroupToProduct(productId, secondGroup);
      await repository.setGroupActive(secondGroup, false);

      final groups = await repository.listSelectableGroupsForSales(productId);
      expect(groups.map((group) => group.id), [firstGroup]);
      expect(groups.single.items.map((item) => item.id), [third, first]);
      expect(
        await repository.listSelectableGroupsForSales(
          await _createProduct(products, name: 'Không cấu hình'),
        ),
        isEmpty,
      );
    },
  );

  test('batched validation returns current canonical option data', () async {
    final productId = await _createProduct(products, name: 'Cơm');
    expect(
      await repository.resolveSelectableOptions(productId, const []),
      isEmpty,
    );
    final firstGroup = await repository.createGroup('Món thêm');
    final secondGroup = await repository.createGroup('Sốt');
    final first = await _createOption(repository, firstGroup, 'Trứng', 30000);
    final second = await _createOption(repository, secondGroup, 'Tiêu', 5000);
    await repository.attachGroupToProduct(productId, firstGroup);
    await repository.attachGroupToProduct(productId, secondGroup);
    await repository.renameGroup(firstGroup, 'Phần thêm');
    await repository.updateOption(first, name: 'Trứng thêm', priceDelta: 35000);

    final resolved = await repository.resolveSelectableOptions(productId, [
      second,
      first,
    ]);

    expect(resolved.map((item) => item.optionItemId), [first, second]);
    expect(resolved.first.groupName, 'Phần thêm');
    expect(resolved.first.optionName, 'Trứng thêm');
    expect(resolved.first.priceDelta, 35000);
    expect(resolved.first.groupSortOrder, 0);
    expect(resolved.first.optionSortOrder, 0);
  });

  test(
    'batched validation rejects duplicate and non-selectable options',
    () async {
      final productId = await _createProduct(products, name: 'Cơm');
      final groupId = await repository.createGroup('Món thêm');
      final optionId = await _createOption(repository, groupId, 'Trứng');

      await expectLater(
        repository.resolveSelectableOptions(productId, [optionId]),
        throwsA(isA<DomainValidationException>()),
      );
      await repository.attachGroupToProduct(productId, groupId);
      await expectLater(
        repository.resolveSelectableOptions(productId, [optionId, optionId]),
        throwsA(isA<DomainValidationException>()),
      );
      await repository.setOptionActive(optionId, false);
      await expectLater(
        repository.resolveSelectableOptions(productId, [optionId]),
        throwsA(isA<DomainValidationException>()),
      );
      await repository.setOptionActive(optionId, true);
      await repository.setGroupActive(groupId, false);
      await expectLater(
        repository.resolveSelectableOptions(productId, [optionId]),
        throwsA(isA<DomainValidationException>()),
      );
    },
  );
}

Future<int> _createProduct(
  ProductRepository repository, {
  required String name,
}) async {
  final categories = await repository.listCategories();
  final categoryId = categories.isEmpty
      ? await repository.createCategory('Danh mục')
      : categories.first.id;
  return repository.createProduct(
    ProductDraft(categoryId: categoryId, name: name, price: 45000),
  );
}

Future<int> _createOption(
  ProductOptionRepository repository,
  int groupId,
  String name, [
  int priceDelta = 10000,
]) {
  return repository.createOption(
    groupId: groupId,
    name: name,
    priceDelta: priceDelta,
  );
}
