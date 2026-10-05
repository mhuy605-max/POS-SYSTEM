import 'package:dakao_in_bill/data/app_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';
import '../generated_migrations/schema_v1.dart' as v1;

const _receiptSnapshot =
    '{"version":1,"shopName":"Đakao","address":"42 Đakao","phone":"0908","footer":"Cảm ơn"}';

void main() {
  test('populated V1 database migrates losslessly to schema V2', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: AppDatabase.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, old) {
        batch.customStatement(
          "INSERT INTO categories (id, name, sort_order, is_active, created_at, updated_at) VALUES "
          "(10, 'Cơm', 4, 1, 100, 101), (11, 'Nước', 1, 1, 110, 111)",
        );
        batch.customStatement(
          "INSERT INTO products (id, category_id, name, description, price, image_path, is_available, sort_order, created_at, updated_at, deleted_at) VALUES "
          "(20, 10, 'Cơm sườn', 'Mô tả', 45000, 'product-images/rice.png', 1, 9, 200, 201, NULL), "
          "(21, 11, 'Trà đá', NULL, 5000, NULL, 0, 2, 210, 211, NULL), "
          "(22, 10, 'Món cũ', NULL, 30000, NULL, 1, 2, 220, 221, 999)",
        );
        batch.customStatement(
          'INSERT INTO orders (id, order_number, submission_token, order_type, status, subtotal, total, created_at, paid_at, cancelled_at, printed_at, print_count, cancellation_reason, receipt_settings_snapshot) VALUES '
          '(30, 1, ?, NULL, ?, 45000, 45000, 300, NULL, NULL, NULL, 0, NULL, ?), '
          '(31, 2, ?, ?, ?, 5000, 5000, 400, 450, NULL, 460, 1, NULL, ?), '
          '(32, 3, ?, ?, ?, 30000, 30000, 500, 520, 550, NULL, 0, ?, ?)',
          [
            'token-unpaid',
            'UNPAID',
            _receiptSnapshot,
            'token-paid',
            'TAKEAWAY',
            'PAID',
            _receiptSnapshot,
            'token-cancelled',
            'DINE_IN',
            'CANCELLED',
            'Khách đổi ý',
            _receiptSnapshot,
          ],
        );
        batch.customStatement(
          "INSERT INTO order_items (id, order_id, product_id, product_name_snapshot, unit_price_snapshot, quantity, note, line_total) VALUES "
          "(40, 30, 20, 'Cơm sườn', 45000, 1, NULL, 45000), "
          "(41, 31, 21, 'Trà đá', 5000, 1, 'Ít đá', 5000), "
          "(42, 32, 22, 'Món cũ', 30000, 1, NULL, 30000)",
        );
        batch.customStatement(
          "INSERT INTO print_attempts (id, order_id, attempted_at, success, error_message) "
          "VALUES (50, 31, 470, 1, NULL)",
        );
        batch.customStatement(
          "INSERT INTO app_settings (id, shop_name, address, phone, receipt_footer) "
          "VALUES (1, 'Đakao', '42 Đakao', '0908', 'Cảm ơn')",
        );
        batch.customStatement(
          "INSERT INTO printer_settings (id, printer_name, printer_address, auto_reconnect, auto_print) "
          "VALUES (1, 'MP-58N', 'AA:BB', 1, 1)",
        );
      },
      validateItems: (database) async {
        Future<List<Map<String, Object?>>> rows(String sql) async =>
            (await database.customSelect(sql).get())
                .map((row) => row.data)
                .toList(growable: false);

        expect(
          await rows(
            'SELECT id, name, sort_order, is_active, created_at, updated_at '
            'FROM categories ORDER BY id',
          ),
          [
            {
              'id': 10,
              'name': 'Cơm',
              'sort_order': 4,
              'is_active': 1,
              'created_at': 100,
              'updated_at': 101,
            },
            {
              'id': 11,
              'name': 'Nước',
              'sort_order': 1,
              'is_active': 1,
              'created_at': 110,
              'updated_at': 111,
            },
          ],
        );
        expect(
          await rows(
            'SELECT id, category_id, name, description, price, image_path, '
            'is_available, sort_order, created_at, updated_at, deleted_at '
            'FROM products ORDER BY id',
          ),
          [
            {
              'id': 20,
              'category_id': 10,
              'name': 'Cơm sườn',
              'description': 'Mô tả',
              'price': 45000,
              'image_path': 'product-images/rice.png',
              'is_available': 1,
              'sort_order': 2,
              'created_at': 200,
              'updated_at': 201,
              'deleted_at': null,
            },
            {
              'id': 21,
              'category_id': 11,
              'name': 'Trà đá',
              'description': null,
              'price': 5000,
              'image_path': null,
              'is_available': 0,
              'sort_order': 0,
              'created_at': 210,
              'updated_at': 211,
              'deleted_at': null,
            },
            {
              'id': 22,
              'category_id': 10,
              'name': 'Món cũ',
              'description': null,
              'price': 30000,
              'image_path': null,
              'is_available': 1,
              'sort_order': 1,
              'created_at': 220,
              'updated_at': 221,
              'deleted_at': 999,
            },
          ],
        );
        expect(
          await rows(
            'SELECT id, order_number, submission_token, order_type, status, '
            'subtotal, total, created_at, paid_at, cancelled_at, printed_at, '
            'print_count, cancellation_reason, receipt_settings_snapshot '
            'FROM orders ORDER BY id',
          ),
          [
            {
              'id': 30,
              'order_number': 1,
              'submission_token': 'token-unpaid',
              'order_type': null,
              'status': 'UNPAID',
              'subtotal': 45000,
              'total': 45000,
              'created_at': 300,
              'paid_at': null,
              'cancelled_at': null,
              'printed_at': null,
              'print_count': 0,
              'cancellation_reason': null,
              'receipt_settings_snapshot': _receiptSnapshot,
            },
            {
              'id': 31,
              'order_number': 2,
              'submission_token': 'token-paid',
              'order_type': 'TAKEAWAY',
              'status': 'PAID',
              'subtotal': 5000,
              'total': 5000,
              'created_at': 400,
              'paid_at': 450,
              'cancelled_at': null,
              'printed_at': 460,
              'print_count': 1,
              'cancellation_reason': null,
              'receipt_settings_snapshot': _receiptSnapshot,
            },
            {
              'id': 32,
              'order_number': 3,
              'submission_token': 'token-cancelled',
              'order_type': 'DINE_IN',
              'status': 'CANCELLED',
              'subtotal': 30000,
              'total': 30000,
              'created_at': 500,
              'paid_at': 520,
              'cancelled_at': 550,
              'printed_at': null,
              'print_count': 0,
              'cancellation_reason': 'Khách đổi ý',
              'receipt_settings_snapshot': _receiptSnapshot,
            },
          ],
        );
        expect(
          await rows(
            'SELECT id, order_id, product_id, product_name_snapshot, '
            'base_unit_price_snapshot, unit_price_snapshot, quantity, note, line_total '
            'FROM order_items ORDER BY id',
          ),
          [
            {
              'id': 40,
              'order_id': 30,
              'product_id': 20,
              'product_name_snapshot': 'Cơm sườn',
              'unit_price_snapshot': 45000,
              'base_unit_price_snapshot': 45000,
              'quantity': 1,
              'note': null,
              'line_total': 45000,
            },
            {
              'id': 41,
              'order_id': 31,
              'product_id': 21,
              'product_name_snapshot': 'Trà đá',
              'unit_price_snapshot': 5000,
              'base_unit_price_snapshot': 5000,
              'quantity': 1,
              'note': 'Ít đá',
              'line_total': 5000,
            },
            {
              'id': 42,
              'order_id': 32,
              'product_id': 22,
              'product_name_snapshot': 'Món cũ',
              'unit_price_snapshot': 30000,
              'base_unit_price_snapshot': 30000,
              'quantity': 1,
              'note': null,
              'line_total': 30000,
            },
          ],
        );
        expect(await rows('SELECT * FROM app_settings'), [
          {
            'id': 1,
            'shop_name': 'Đakao',
            'address': '42 Đakao',
            'phone': '0908',
            'receipt_footer': 'Cảm ơn',
          },
        ]);
        expect(await rows('SELECT * FROM printer_settings'), [
          {
            'id': 1,
            'printer_name': 'MP-58N',
            'printer_address': 'AA:BB',
            'auto_reconnect': 1,
            'auto_print': 1,
          },
        ]);
        expect(await rows('SELECT * FROM print_attempts'), [
          {
            'id': 50,
            'order_id': 31,
            'attempted_at': 470,
            'success': 1,
            'error_message': null,
          },
        ]);
        for (final table in const [
          'option_groups',
          'option_items',
          'product_option_groups',
          'order_item_options',
        ]) {
          expect(await rows('SELECT * FROM $table'), isEmpty);
        }
        expect(await rows('PRAGMA foreign_key_check'), isEmpty);
      },
      options: const ValidationOptions(validateDropped: true),
    );
  });
}
