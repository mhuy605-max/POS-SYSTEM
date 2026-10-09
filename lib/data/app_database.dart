import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Categories,
    Products,
    OptionGroups,
    OptionItems,
    ProductOptionGroups,
    Orders,
    OrderItems,
    OrderItemOptions,
    PrintAttempts,
    AppSettings,
    PrinterSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.openFile(File file) {
    return AppDatabase(
      NativeDatabase(
        file,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(appSettings).insert(const AppSettingsCompanion());
      await into(printerSettings).insert(const PrinterSettingsCompanion());
    },
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('Unsupported database migration: $from -> $to');
      }

      await migrator.createTable(optionGroups);
      await migrator.createTable(optionItems);
      await migrator.createIndex(optionItemsGroupActiveOrder);
      await migrator.createTable(productOptionGroups);
      await migrator.addColumn(orderItems, orderItems.baseUnitPriceSnapshot);
      await customStatement(
        'UPDATE order_items '
        'SET base_unit_price_snapshot = unit_price_snapshot',
      );
      await migrator.createTable(orderItemOptions);
      await migrator.createIndex(orderItemOptionsOrderDisplay);

      final productRows = await customSelect(
        'SELECT id FROM products ORDER BY sort_order ASC, id ASC',
      ).get();
      for (var index = 0; index < productRows.length; index++) {
        await customStatement(
          'UPDATE products SET sort_order = ? WHERE id = ?',
          <Object>[index, productRows[index].read<int>('id')],
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
