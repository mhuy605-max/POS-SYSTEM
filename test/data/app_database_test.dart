import 'dart:io';

import 'package:dakao_in_bill/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late File databaseFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('dakao_db_test_');
    databaseFile = File('${tempDirectory.path}/app.sqlite');
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('database persists rows across close and reopen', () async {
    var database = AppDatabase.openFile(databaseFile);
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Món nước',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await database.close();

    database = AppDatabase.openFile(databaseFile);
    final categories = await database.select(database.categories).get();
    await database.close();

    expect(categories, hasLength(1));
    expect(categories.single.name, 'Món nước');
  });

  test('foreign keys are enabled and enforced', () async {
    final database = AppDatabase.openFile(databaseFile);
    addTearDown(database.close);

    final pragma = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(pragma.read<int>('foreign_keys'), 1);

    await expectLater(
      database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: 999,
              name: 'Không hợp lệ',
              price: 45000,
              createdAt: 1000,
              updatedAt: 1000,
            ),
          ),
      throwsA(anything),
    );
  });

  test('products require a category', () async {
    final database = AppDatabase.openFile(databaseFile);
    addTearDown(database.close);

    await expectLater(
      database.customStatement(
        'INSERT INTO products '
        '(name, price, created_at, updated_at) VALUES (?, ?, ?, ?)',
        <Object>['Không có danh mục', 45000, 1000, 1000],
      ),
      throwsA(anything),
    );
  });

  test(
    'V1 schema contains the seven approved tables and order additions',
    () async {
      final database = AppDatabase.openFile(databaseFile);
      addTearDown(database.close);

      final rows = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get();
      final names = rows.map((row) => row.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>{
          'app_settings',
          'categories',
          'order_items',
          'orders',
          'print_attempts',
          'printer_settings',
          'products',
        }),
      );

      final columns = await database
          .customSelect('PRAGMA table_info(orders)')
          .get();
      final columnNames = columns
          .map((row) => row.read<String>('name'))
          .toSet();
      expect(columnNames, contains('submission_token'));
      expect(columnNames, contains('receipt_settings_snapshot'));
    },
  );
}
