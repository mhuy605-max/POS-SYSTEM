import 'package:drift/drift.dart';

import '../../core/money.dart';
import '../../data/app_database.dart';
import '../orders/order_repository.dart' show EpochClock;

final class CatalogOptionItem {
  const CatalogOptionItem({
    required this.id,
    required this.groupId,
    required this.name,
    required this.priceDelta,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int groupId;
  final String name;
  final int priceDelta;
  final int sortOrder;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
}

final class CatalogOptionGroup {
  const CatalogOptionGroup({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final int createdAt;
  final int updatedAt;
  final List<CatalogOptionItem> items;
}

final class ResolvedProductOption {
  const ResolvedProductOption({
    required this.productId,
    required this.groupId,
    required this.optionItemId,
    required this.groupName,
    required this.optionName,
    required this.priceDelta,
    required this.groupSortOrder,
    required this.optionSortOrder,
  });

  final int productId;
  final int groupId;
  final int optionItemId;
  final String groupName;
  final String optionName;
  final int priceDelta;
  final int groupSortOrder;
  final int optionSortOrder;
}

final class ProductOptionRepository {
  ProductOptionRepository(this._database, this._nowEpochMillis);

  final AppDatabase _database;
  final EpochClock _nowEpochMillis;

  Future<List<CatalogOptionGroup>> listGroups({bool includeInactive = true}) {
    return _loadGroups(
      includeInactiveGroups: includeInactive,
      includeInactiveItems: true,
    );
  }

  Future<CatalogOptionGroup> getGroup(int id) async {
    final groups = await _loadGroups(
      groupIds: {id},
      includeInactiveGroups: true,
      includeInactiveItems: true,
    );
    if (groups.isEmpty) {
      throw StateError('Option group $id does not exist.');
    }
    return groups.single;
  }

  Future<int> createGroup(String name) async {
    final checkedName = _checkedName(name, field: 'Option group name');
    return _database.transaction(() async {
      final maxOrder = await _maxSortOrder('option_groups');
      final now = _nowEpochMillis();
      return _database
          .into(_database.optionGroups)
          .insert(
            OptionGroupsCompanion.insert(
              name: checkedName,
              sortOrder: Value(maxOrder + 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<void> renameGroup(int id, String name) async {
    final changed =
        await (_database.update(
          _database.optionGroups,
        )..where((row) => row.id.equals(id))).write(
          OptionGroupsCompanion(
            name: Value(_checkedName(name, field: 'Option group name')),
            updatedAt: Value(_nowEpochMillis()),
          ),
        );
    if (changed != 1) {
      throw StateError('Option group $id does not exist.');
    }
  }

  Future<void> setGroupActive(int id, bool isActive) async {
    final changed =
        await (_database.update(
          _database.optionGroups,
        )..where((row) => row.id.equals(id))).write(
          OptionGroupsCompanion(
            isActive: Value(isActive),
            updatedAt: Value(_nowEpochMillis()),
          ),
        );
    if (changed != 1) {
      throw StateError('Option group $id does not exist.');
    }
  }

  Future<int> createOption({
    required int groupId,
    required String name,
    required int priceDelta,
  }) async {
    final checkedName = _checkedName(name, field: 'Option name');
    _checkPriceDelta(priceDelta);
    return _database.transaction(() async {
      await _requireGroup(groupId);
      final maxOrder = await _maxSortOrder(
        'option_items',
        whereSql: 'group_id = ?',
        variables: [Variable<int>(groupId)],
      );
      final now = _nowEpochMillis();
      return _database
          .into(_database.optionItems)
          .insert(
            OptionItemsCompanion.insert(
              groupId: groupId,
              name: checkedName,
              priceDelta: priceDelta,
              sortOrder: Value(maxOrder + 1),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  Future<void> updateOption(
    int id, {
    required String name,
    required int priceDelta,
  }) async {
    final checkedName = _checkedName(name, field: 'Option name');
    _checkPriceDelta(priceDelta);
    final changed =
        await (_database.update(
          _database.optionItems,
        )..where((row) => row.id.equals(id))).write(
          OptionItemsCompanion(
            name: Value(checkedName),
            priceDelta: Value(priceDelta),
            updatedAt: Value(_nowEpochMillis()),
          ),
        );
    if (changed != 1) {
      throw StateError('Option item $id does not exist.');
    }
  }

  Future<void> setOptionActive(int id, bool isActive) async {
    final changed =
        await (_database.update(
          _database.optionItems,
        )..where((row) => row.id.equals(id))).write(
          OptionItemsCompanion(
            isActive: Value(isActive),
            updatedAt: Value(_nowEpochMillis()),
          ),
        );
    if (changed != 1) {
      throw StateError('Option item $id does not exist.');
    }
  }

  /// Reorders the complete item set for [groupId], including inactive items.
  ///
  /// Requiring the complete set keeps inactive items in explicit stable slots
  /// and makes reactivation deterministic. Validation occurs before any update.
  Future<void> reorderOptions(int groupId, List<int> optionIds) {
    return _database.transaction(() async {
      await _requireGroup(groupId);
      _rejectDuplicates(optionIds, field: 'Option IDs');
      final existing =
          await (_database.select(_database.optionItems)
                ..where((row) => row.groupId.equals(groupId))
                ..orderBy([
                  (row) => OrderingTerm.asc(row.sortOrder),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final existingIds = existing.map((item) => item.id).toSet();
      if (optionIds.length != existing.length ||
          !existingIds.containsAll(optionIds)) {
        throw const DomainValidationException(
          'Reorder must contain every option from exactly one group.',
        );
      }

      final now = _nowEpochMillis();
      for (var index = 0; index < optionIds.length; index++) {
        await (_database.update(
          _database.optionItems,
        )..where((row) => row.id.equals(optionIds[index]))).write(
          OptionItemsCompanion(sortOrder: Value(index), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<void> attachGroupToProduct(int productId, int groupId) {
    return _database.transaction(() async {
      await _requireCurrentProduct(productId);
      await _requireGroup(groupId);
      await _database
          .into(_database.productOptionGroups)
          .insert(
            ProductOptionGroupsCompanion.insert(
              productId: productId,
              optionGroupId: groupId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  Future<void> detachGroupFromProduct(int productId, int groupId) async {
    await (_database.delete(_database.productOptionGroups)..where(
          (row) =>
              row.productId.equals(productId) &
              row.optionGroupId.equals(groupId),
        ))
        .go();
  }

  Future<void> setProductOptionGroups(int productId, List<int> groupIds) {
    return _database.transaction(() async {
      _rejectDuplicates(groupIds, field: 'Option group IDs');
      await _requireCurrentProduct(productId);
      await _requireGroups(groupIds);

      await (_database.delete(
        _database.productOptionGroups,
      )..where((row) => row.productId.equals(productId))).go();
      for (final groupId in groupIds) {
        await _database
            .into(_database.productOptionGroups)
            .insert(
              ProductOptionGroupsCompanion.insert(
                productId: productId,
                optionGroupId: groupId,
              ),
            );
      }
    });
  }

  Future<List<CatalogOptionGroup>> listAttachedGroupsForManagement(
    int productId,
  ) async {
    await _requireCurrentProduct(productId);
    final attachments = await (_database.select(
      _database.productOptionGroups,
    )..where((row) => row.productId.equals(productId))).get();
    return _loadGroups(
      groupIds: attachments.map((row) => row.optionGroupId).toSet(),
      includeInactiveGroups: true,
      includeInactiveItems: true,
    );
  }

  Future<List<CatalogOptionGroup>> listSelectableGroupsForSales(
    int productId,
  ) async {
    await _requireCurrentProduct(productId);
    final attachments = await (_database.select(
      _database.productOptionGroups,
    )..where((row) => row.productId.equals(productId))).get();
    return _loadGroups(
      groupIds: attachments.map((row) => row.optionGroupId).toSet(),
      includeInactiveGroups: false,
      includeInactiveItems: false,
    );
  }

  Future<List<ResolvedProductOption>> resolveSelectableOptions(
    int productId,
    List<int> optionItemIds,
  ) async {
    _rejectDuplicates(optionItemIds, field: 'Selected option IDs');
    await _requireCurrentProduct(productId);
    if (optionItemIds.isEmpty) return const [];

    final query =
        _database.select(_database.optionItems).join([
            innerJoin(
              _database.optionGroups,
              _database.optionGroups.id.equalsExp(
                _database.optionItems.groupId,
              ),
            ),
            innerJoin(
              _database.productOptionGroups,
              _database.productOptionGroups.optionGroupId.equalsExp(
                _database.optionGroups.id,
              ),
            ),
          ])
          ..where(_database.optionItems.id.isIn(optionItemIds))
          ..where(_database.productOptionGroups.productId.equals(productId))
          ..orderBy([
            OrderingTerm.asc(_database.optionGroups.sortOrder),
            OrderingTerm.asc(_database.optionGroups.id),
            OrderingTerm.asc(_database.optionItems.sortOrder),
            OrderingTerm.asc(_database.optionItems.id),
          ]);
    final rows = await query.get();
    if (rows.length != optionItemIds.length ||
        rows.any(
          (row) =>
              !row.readTable(_database.optionGroups).isActive ||
              !row.readTable(_database.optionItems).isActive,
        )) {
      throw const DomainValidationException(
        'One or more selected options are not currently selectable.',
      );
    }

    return rows
        .map((row) {
          final group = row.readTable(_database.optionGroups);
          final option = row.readTable(_database.optionItems);
          return ResolvedProductOption(
            productId: productId,
            groupId: group.id,
            optionItemId: option.id,
            groupName: group.name,
            optionName: option.name,
            priceDelta: option.priceDelta,
            groupSortOrder: group.sortOrder,
            optionSortOrder: option.sortOrder,
          );
        })
        .toList(growable: false);
  }

  Future<List<CatalogOptionGroup>> _loadGroups({
    Set<int>? groupIds,
    required bool includeInactiveGroups,
    required bool includeInactiveItems,
  }) async {
    if (groupIds != null && groupIds.isEmpty) return const [];
    final groupQuery = _database.select(_database.optionGroups)
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (groupIds != null) {
      groupQuery.where((row) => row.id.isIn(groupIds));
    }
    if (!includeInactiveGroups) {
      groupQuery.where((row) => row.isActive.equals(true));
    }
    final groups = await groupQuery.get();
    if (groups.isEmpty) return const [];

    final selectedGroupIds = groups.map((group) => group.id).toSet();
    final itemQuery = _database.select(_database.optionItems)
      ..where((row) => row.groupId.isIn(selectedGroupIds))
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.id),
      ]);
    if (!includeInactiveItems) {
      itemQuery.where((row) => row.isActive.equals(true));
    }
    final items = await itemQuery.get();
    final itemsByGroup = <int, List<CatalogOptionItem>>{};
    for (final item in items) {
      itemsByGroup.putIfAbsent(item.groupId, () => []).add(_mapItem(item));
    }

    return groups
        .map(
          (group) => CatalogOptionGroup(
            id: group.id,
            name: group.name,
            sortOrder: group.sortOrder,
            isActive: group.isActive,
            createdAt: group.createdAt,
            updatedAt: group.updatedAt,
            items: List<CatalogOptionItem>.unmodifiable(
              itemsByGroup[group.id] ?? const [],
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _requireCurrentProduct(int productId) async {
    final product = await (_database.select(
      _database.products,
    )..where((row) => row.id.equals(productId))).getSingleOrNull();
    if (product == null || product.deletedAt != null) {
      throw StateError('Current product $productId does not exist.');
    }
  }

  Future<void> _requireGroup(int groupId) async {
    final group = await (_database.select(
      _database.optionGroups,
    )..where((row) => row.id.equals(groupId))).getSingleOrNull();
    if (group == null) {
      throw StateError('Option group $groupId does not exist.');
    }
  }

  Future<void> _requireGroups(List<int> groupIds) async {
    if (groupIds.isEmpty) return;
    final groups = await (_database.select(
      _database.optionGroups,
    )..where((row) => row.id.isIn(groupIds))).get();
    if (groups.length != groupIds.length) {
      throw StateError('One or more option groups do not exist.');
    }
  }

  Future<int> _maxSortOrder(
    String table, {
    String? whereSql,
    List<Variable<Object>> variables = const [],
  }) async {
    final where = whereSql == null ? '' : ' WHERE $whereSql';
    final row = await _database
        .customSelect(
          'SELECT MAX(sort_order) AS maximum FROM $table$where',
          variables: variables,
        )
        .getSingle();
    return row.readNullable<int>('maximum') ?? -1;
  }
}

CatalogOptionItem _mapItem(OptionItem item) => CatalogOptionItem(
  id: item.id,
  groupId: item.groupId,
  name: item.name,
  priceDelta: item.priceDelta,
  sortOrder: item.sortOrder,
  isActive: item.isActive,
  createdAt: item.createdAt,
  updatedAt: item.updatedAt,
);

String _checkedName(String value, {required String field}) {
  final checked = value.trim();
  if (checked.isEmpty) {
    throw DomainValidationException('$field is required.');
  }
  return checked;
}

void _checkPriceDelta(int priceDelta) {
  if (priceDelta < 0) {
    throw const DomainValidationException('Option price cannot be negative.');
  }
  if (priceDelta > sqliteMaxInteger) {
    throw const DomainValidationException(
      'Option price exceeds SQLite limits.',
    );
  }
}

void _rejectDuplicates(List<int> ids, {required String field}) {
  if (ids.toSet().length != ids.length) {
    throw DomainValidationException('$field cannot contain duplicates.');
  }
}
