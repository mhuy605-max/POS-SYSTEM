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

  test('V2 schema creates option persistence and enforces its constraints', () async {
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
        'option_groups',
        'option_items',
        'product_option_groups',
        'order_item_options',
      }),
    );

    final columns = await database
        .customSelect('PRAGMA table_info(order_items)')
        .get();
    final columnNames = columns.map((row) => row.read<String>('name')).toSet();
    expect(columnNames, contains('base_unit_price_snapshot'));

    await database.customStatement(
      'INSERT INTO option_groups '
      '(id, name, sort_order, is_active, created_at, updated_at) '
      'VALUES (1, ?, 0, 1, 1, 1)',
      ['Món thêm'],
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO option_items '
        '(group_id, name, price_delta, sort_order, is_active, created_at, updated_at) '
        "VALUES (1, 'Sai', -1, 0, 1, 1, 1)",
      ),
      throwsA(anything),
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO option_items '
        '(group_id, name, price_delta, sort_order, is_active, created_at, updated_at) '
        "VALUES (999, 'Không hợp lệ', 0, 0, 1, 1, 1)",
      ),
      throwsA(anything),
    );

    await database.customStatement(
      'INSERT INTO categories '
      "(id, name, created_at, updated_at) VALUES (1, 'Cơm', 1, 1)",
    );
    await database.customStatement(
      'INSERT INTO products '
      "(id, category_id, name, price, created_at, updated_at) "
      "VALUES (1, 1, 'Cơm sườn', 45000, 1, 1)",
    );
    await database.customStatement(
      'INSERT INTO product_option_groups (product_id, option_group_id) '
      'VALUES (1, 1)',
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO product_option_groups (product_id, option_group_id) '
        'VALUES (1, 1)',
      ),
      throwsA(anything),
    );
    const receipt =
        '{"version":1,"shopName":"Đakao","address":"","phone":"","footer":""}';
    await database.customStatement(
      'INSERT INTO orders '
      '(id, order_number, submission_token, status, subtotal, total, created_at, '
      'receipt_settings_snapshot) VALUES (1, 1, ?, ?, 45000, 45000, 1, ?)',
      ['schema-v2', 'UNPAID', receipt],
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO order_items '
        '(id, order_id, product_id, product_name_snapshot, '
        'base_unit_price_snapshot, unit_price_snapshot, quantity, line_total) '
        "VALUES (2, 1, 1, 'Sai', -1, 45000, 1, 45000)",
      ),
      throwsA(anything),
    );
    await database.customStatement(
      'INSERT INTO order_items '
      '(id, order_id, product_id, product_name_snapshot, '
      'base_unit_price_snapshot, unit_price_snapshot, quantity, line_total) '
      "VALUES (1, 1, 1, 'Cơm sườn', 45000, 45000, 1, 45000)",
    );
    await database.customStatement(
      'INSERT INTO order_item_options '
      '(order_item_id, group_name_snapshot, option_name_snapshot, '
      "price_delta_snapshot, display_order) VALUES (1, 'Món thêm', 'Trứng', 0, 0)",
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO order_item_options '
        '(order_item_id, group_name_snapshot, option_name_snapshot, '
        "price_delta_snapshot, display_order) VALUES (1, 'Món thêm', 'Sai', -1, 2)",
      ),
      throwsA(anything),
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO order_item_options '
        '(order_item_id, group_name_snapshot, option_name_snapshot, '
        "price_delta_snapshot, display_order) VALUES (1, 'Món thêm', 'Chả', 0, 0)",
      ),
      throwsA(anything),
    );
    await expectLater(
      database.customStatement(
        'INSERT INTO order_item_options '
        '(order_item_id, group_name_snapshot, option_name_snapshot, '
        "price_delta_snapshot, display_order) VALUES (1, '', 'Chả', 0, 1)",
      ),
      throwsA(anything),
    );
  });
}
