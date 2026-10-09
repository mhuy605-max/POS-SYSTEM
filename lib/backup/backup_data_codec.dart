import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/app_database.dart';

final class BackupDataCodec {
  const BackupDataCodec(this._database);

  final AppDatabase _database;

  Future<Map<String, Object>> exportMap() {
    return _database.transaction(() async {
      final categories =
          await (_database.select(_database.categories)
                ..orderBy(<OrderingTerm Function($CategoriesTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final products =
          await (_database.select(_database.products)
                ..orderBy(<OrderingTerm Function($ProductsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final optionGroups =
          await (_database.select(_database.optionGroups)
                ..orderBy(<OrderingTerm Function($OptionGroupsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final optionItems =
          await (_database.select(_database.optionItems)
                ..orderBy(<OrderingTerm Function($OptionItemsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final productOptionGroups =
          await (_database.select(_database.productOptionGroups)
                ..orderBy(<OrderingTerm Function($ProductOptionGroupsTable)>[
                  (row) => OrderingTerm.asc(row.productId),
                  (row) => OrderingTerm.asc(row.optionGroupId),
                ]))
              .get();
      final orders =
          await (_database.select(_database.orders)
                ..orderBy(<OrderingTerm Function($OrdersTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final orderItems =
          await (_database.select(_database.orderItems)
                ..orderBy(<OrderingTerm Function($OrderItemsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final orderItemOptions =
          await (_database.select(_database.orderItemOptions)
                ..orderBy(<OrderingTerm Function($OrderItemOptionsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final printAttempts =
          await (_database.select(_database.printAttempts)
                ..orderBy(<OrderingTerm Function($PrintAttemptsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final appSettings =
          await (_database.select(_database.appSettings)
                ..orderBy(<OrderingTerm Function($AppSettingsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
      final printerSettings =
          await (_database.select(_database.printerSettings)
                ..orderBy(<OrderingTerm Function($PrinterSettingsTable)>[
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();

      return <String, Object>{
        'tables': <String, Object>{
          'categories': <Object>[
            for (final row in categories)
              <String, Object>{
                'id': row.id,
                'name': row.name,
                'sort_order': row.sortOrder,
                'is_active': row.isActive,
                'created_at': row.createdAt,
                'updated_at': row.updatedAt,
              },
          ],
          'products': <Object>[
            for (final row in products)
              <String, Object?>{
                'id': row.id,
                'category_id': row.categoryId,
                'name': row.name,
                'description': row.description,
                'price': row.price,
                'image_path': row.imagePath,
                'is_available': row.isAvailable,
                'sort_order': row.sortOrder,
                'created_at': row.createdAt,
                'updated_at': row.updatedAt,
                'deleted_at': row.deletedAt,
              },
          ],
          'option_groups': <Object>[
            for (final row in optionGroups)
              <String, Object>{
                'id': row.id,
                'name': row.name,
                'sort_order': row.sortOrder,
                'is_active': row.isActive,
                'created_at': row.createdAt,
                'updated_at': row.updatedAt,
              },
          ],
          'option_items': <Object>[
            for (final row in optionItems)
              <String, Object>{
                'id': row.id,
                'group_id': row.groupId,
                'name': row.name,
                'price_delta': row.priceDelta,
                'sort_order': row.sortOrder,
                'is_active': row.isActive,
                'created_at': row.createdAt,
                'updated_at': row.updatedAt,
              },
          ],
          'product_option_groups': <Object>[
            for (final row in productOptionGroups)
              <String, Object>{
                'product_id': row.productId,
                'option_group_id': row.optionGroupId,
              },
          ],
          'orders': <Object>[
            for (final row in orders)
              <String, Object?>{
                'id': row.id,
                'order_number': row.orderNumber,
                'submission_token': row.submissionToken,
                'order_type': row.orderType,
                'status': row.status,
                'subtotal': row.subtotal,
                'total': row.total,
                'created_at': row.createdAt,
                'paid_at': row.paidAt,
                'cancelled_at': row.cancelledAt,
                'printed_at': row.printedAt,
                'print_count': row.printCount,
                'cancellation_reason': row.cancellationReason,
                'receipt_settings_snapshot': row.receiptSettingsSnapshot,
              },
          ],
          'order_items': <Object>[
            for (final row in orderItems)
              <String, Object?>{
                'id': row.id,
                'order_id': row.orderId,
                'product_id': row.productId,
                'product_name_snapshot': row.productNameSnapshot,
                'base_unit_price_snapshot': row.baseUnitPriceSnapshot,
                'unit_price_snapshot': row.unitPriceSnapshot,
                'quantity': row.quantity,
                'note': row.note,
                'line_total': row.lineTotal,
              },
          ],
          'order_item_options': <Object>[
            for (final row in orderItemOptions)
              <String, Object?>{
                'id': row.id,
                'order_item_id': row.orderItemId,
                'option_item_id': row.optionItemId,
                'group_name_snapshot': row.groupNameSnapshot,
                'option_name_snapshot': row.optionNameSnapshot,
                'price_delta_snapshot': row.priceDeltaSnapshot,
                'display_order': row.displayOrder,
              },
          ],
          'print_attempts': <Object>[
            for (final row in printAttempts)
              <String, Object?>{
                'id': row.id,
                'order_id': row.orderId,
                'attempted_at': row.attemptedAt,
                'success': row.success,
                'error_message': row.errorMessage,
              },
          ],
          'app_settings': <Object>[
            for (final row in appSettings)
              <String, Object>{
                'id': row.id,
                'shop_name': row.shopName,
                'address': row.address,
                'phone': row.phone,
                'receipt_footer': row.receiptFooter,
              },
          ],
          'printer_settings': <Object>[
            for (final row in printerSettings)
              <String, Object?>{
                'id': row.id,
                'printer_name': row.printerName,
                'printer_address': row.printerAddress,
                'auto_reconnect': row.autoReconnect,
                'auto_print': row.autoPrint,
              },
          ],
        },
      };
    });
  }

  Future<Uint8List> exportCanonical() async {
    final data = await exportMap();
    return Uint8List.fromList(utf8.encode(jsonEncode(data)));
  }

  Future<void> replaceWithCanonical(Uint8List bytes) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?> ||
        decoded['tables'] is! Map<String, Object?>) {
      throw const FormatException('Invalid canonical backup data.');
    }
    final tables = decoded['tables']! as Map<String, Object?>;
    List<Map<String, Object?>> rows(String name) {
      final value = tables[name];
      if (value is! List<Object?>) {
        throw FormatException('Invalid table $name.');
      }
      return [
        for (final row in value)
          if (row is Map<String, Object?>)
            row
          else
            throw FormatException('Invalid row in $name.'),
      ];
    }

    await _database.transaction(() async {
      for (final table in const <String>[
        'print_attempts',
        'order_item_options',
        'order_items',
        'orders',
        'product_option_groups',
        'option_items',
        'option_groups',
        'products',
        'categories',
        'app_settings',
        'printer_settings',
      ]) {
        await _database.customStatement('DELETE FROM $table');
      }
      await _database.customStatement(
        "DELETE FROM sqlite_sequence WHERE name IN ('categories', 'products', "
        "'option_groups', 'option_items', 'orders', 'order_items', "
        "'order_item_options', 'print_attempts')",
      );
      for (final row in rows('categories')) {
        await _insert('categories', const [
          'id',
          'name',
          'sort_order',
          'is_active',
          'created_at',
          'updated_at',
        ], row);
      }
      for (final row in rows('products')) {
        await _insert('products', const [
          'id',
          'category_id',
          'name',
          'description',
          'price',
          'image_path',
          'is_available',
          'sort_order',
          'created_at',
          'updated_at',
          'deleted_at',
        ], row);
      }
      for (final row in rows('option_groups')) {
        await _insert('option_groups', const [
          'id',
          'name',
          'sort_order',
          'is_active',
          'created_at',
          'updated_at',
        ], row);
      }
      for (final row in rows('option_items')) {
        await _insert('option_items', const [
          'id',
          'group_id',
          'name',
          'price_delta',
          'sort_order',
          'is_active',
          'created_at',
          'updated_at',
        ], row);
      }
      for (final row in rows('product_option_groups')) {
        await _insert('product_option_groups', const [
          'product_id',
          'option_group_id',
        ], row);
      }
      for (final row in rows('orders')) {
        await _insert('orders', const [
          'id',
          'order_number',
          'submission_token',
          'order_type',
          'status',
          'subtotal',
          'total',
          'created_at',
          'paid_at',
          'cancelled_at',
          'printed_at',
          'print_count',
          'cancellation_reason',
          'receipt_settings_snapshot',
        ], row);
      }
      for (final row in rows('order_items')) {
        await _insert('order_items', const [
          'id',
          'order_id',
          'product_id',
          'product_name_snapshot',
          'base_unit_price_snapshot',
          'unit_price_snapshot',
          'quantity',
          'note',
          'line_total',
        ], row);
      }
      for (final row in rows('order_item_options')) {
        await _insert('order_item_options', const [
          'id',
          'order_item_id',
          'option_item_id',
          'group_name_snapshot',
          'option_name_snapshot',
          'price_delta_snapshot',
          'display_order',
        ], row);
      }
      for (final row in rows('print_attempts')) {
        await _insert('print_attempts', const [
          'id',
          'order_id',
          'attempted_at',
          'success',
          'error_message',
        ], row);
      }
      for (final row in rows('app_settings')) {
        await _insert('app_settings', const [
          'id',
          'shop_name',
          'address',
          'phone',
          'receipt_footer',
        ], row);
      }
      for (final row in rows('printer_settings')) {
        await _insert('printer_settings', const [
          'id',
          'printer_name',
          'printer_address',
          'auto_reconnect',
          'auto_print',
        ], row);
      }
    });
  }

  Future<void> _insert(
    String table,
    List<String> columns,
    Map<String, Object?> row,
  ) {
    final placeholders = List.filled(columns.length, '?').join(', ');
    return _database.customStatement(
      'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)',
      [for (final column in columns) _sqliteValue(row[column])],
    );
  }
}

Object? _sqliteValue(Object? value) => value is bool ? (value ? 1 : 0) : value;
