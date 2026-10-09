import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dakao_in_bill/backup/backup_models.dart';
import 'package:dakao_in_bill/backup/backup_validator.dart';
import 'package:dakao_in_bill/backup/restore_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/products/product_image_store.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 archive upgrades and restores into V2 without data loss', () async {
    final root = await Directory.systemTemp.createTemp('dakao-v1-restore-');
    final files = Directory('${root.path}${Platform.pathSeparator}files');
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await database.close();
      await root.delete(recursive: true);
    });
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: const Value(99),
            name: 'Dữ liệu đang dùng',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    final validated = const BackupValidator(schemaVersion: 2)
        .validateBytes(_v1Archive());
    await RestoreService(
      database: database,
      imageStore: ProductImageStore(files),
      journalDirectory: Directory(
        '${root.path}${Platform.pathSeparator}journal',
      ),
    ).replaceWith(validated);

    expect(validated.manifest.schemaVersion, 1);
    final products = await (database.select(
      database.products,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    expect(products.map((row) => row.id), [20, 21, 22]);
    expect(products.map((row) => row.sortOrder), [2, 0, 1]);
    expect(products.last.deletedAt, 999);
    expect(await database.select(database.optionGroups).get(), isEmpty);
    expect(await database.select(database.optionItems).get(), isEmpty);
    expect(await database.select(database.productOptionGroups).get(), isEmpty);
    expect(await database.select(database.orderItemOptions).get(), isEmpty);
    final items = await (database.select(
      database.orderItems,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    expect(items.map((row) => row.baseUnitPriceSnapshot), [45000, 5000, 45000]);
    expect(items.map((row) => row.unitPriceSnapshot), [45000, 5000, 45000]);
    final orders = await (database.select(
      database.orders,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    expect(orders.map((row) => row.status), ['UNPAID', 'PAID', 'CANCELLED']);
    expect(orders[1].paidAt, 500);
    expect(orders[2].cancelledAt, 650);
    expect(orders.map((row) => row.total), [45000, 5000, 45000]);
    expect(orders.first.submissionToken, 'token-unpaid');
    expect(orders.first.receiptSettingsSnapshot, contains('Dòng 1'));
    expect((await database.select(database.printAttempts).get()).single.id, 50);
    expect(
      (await database.select(database.appSettings).get()).single.shopName,
      'Đakao V1',
    );
    expect(
      (await database.select(database.printerSettings).get())
          .single
          .printerName,
      'MP-58N',
    );
    expect(
      await ProductImageStore(files)
          .resolve('product-images/menu.png')
          .readAsBytes(),
      _validPng,
    );
  });
}

Uint8List _v1Archive() {
  final data = <String, Object?>{
    'tables': <String, Object?>{
      'categories': <Object?>[
        {
          'id': 10,
          'name': 'Cơm',
          'sort_order': 0,
          'is_active': true,
          'created_at': 100,
          'updated_at': 100,
        },
        {
          'id': 11,
          'name': 'Nước',
          'sort_order': 1,
          'is_active': true,
          'created_at': 101,
          'updated_at': 101,
        },
      ],
      'products': <Object?>[
        _product(20, 10, 'Cơm tấm', 45000, 9, 'product-images/menu.png'),
        _product(21, 11, 'Trà đá', 5000, -3, null),
        _product(22, 10, 'Món ẩn', 45000, -3, null, deletedAt: 999),
      ],
      'orders': <Object?>[
        _order(30, 1, 'token-unpaid', 'UNPAID', 45000, 300),
        _order(31, 2, 'token-paid', 'PAID', 5000, 400, paidAt: 500),
        _order(
          32,
          3,
          'token-cancelled',
          'CANCELLED',
          45000,
          600,
          paidAt: 620,
          cancelledAt: 650,
        ),
      ],
      'order_items': <Object?>[
        _item(40, 30, 20, 'Cơm tấm cũ', 45000, note: 'Ít cơm'),
        _item(41, 31, 21, 'Trà đá cũ', 5000),
        _item(42, 32, null, 'Món đã xóa', 45000),
      ],
      'print_attempts': <Object?>[
        {
          'id': 50,
          'order_id': 31,
          'attempted_at': 540,
          'success': true,
          'error_message': null,
        },
      ],
      'app_settings': <Object?>[
        {
          'id': 1,
          'shop_name': 'Đakao V1',
          'address': '42 Đinh Tiên Hoàng',
          'phone': '0908',
          'receipt_footer': 'Dòng 1\nDòng 2',
        },
      ],
      'printer_settings': <Object?>[
        {
          'id': 1,
          'printer_name': 'MP-58N',
          'printer_address': 'AA:BB',
          'auto_reconnect': true,
          'auto_print': true,
        },
      ],
    },
  };
  final dataBytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
  final imageBytes = Uint8List.fromList(_validPng);
  final entries = <String, Uint8List>{
    'data.json': dataBytes,
    'images/product-images/menu.png': imageBytes,
  };
  final manifest = <String, Object?>{
    'magic': BackupManifest.magicValue,
    'format_version': 1,
    'schema_version': 1,
    'app_version': '1.0.0+1',
    'created_at_utc': '2026-10-02T06:30:00.000Z',
    'entries': <String, Object?>{
      for (final entry in entries.entries)
        entry.key: <String, Object?>{
          'size': entry.value.length,
          'sha256': sha256.convert(entry.value).toString(),
        },
    },
  };
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  archive.addFile(
    ArchiveFile.bytes(
      'manifest.json',
      Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
    ),
  );
  return ZipEncoder().encodeBytes(archive);
}

Map<String, Object?> _product(
  int id,
  int categoryId,
  String name,
  int price,
  int sortOrder,
  String? imagePath, {
  int? deletedAt,
}) => <String, Object?>{
  'id': id,
  'category_id': categoryId,
  'name': name,
  'description': null,
  'price': price,
  'image_path': imagePath,
  'is_available': true,
  'sort_order': sortOrder,
  'created_at': 200 + id,
  'updated_at': 200 + id,
  'deleted_at': deletedAt,
};

Map<String, Object?> _order(
  int id,
  int number,
  String token,
  String status,
  int total,
  int createdAt, {
  int? paidAt,
  int? cancelledAt,
}) => <String, Object?>{
  'id': id,
  'order_number': number,
  'submission_token': token,
  'order_type': null,
  'status': status,
  'subtotal': total,
  'total': total,
  'created_at': createdAt,
  'paid_at': paidAt,
  'cancelled_at': cancelledAt,
  'printed_at': null,
  'print_count': 0,
  'cancellation_reason': status == 'CANCELLED' ? 'Khách đổi ý' : null,
  'receipt_settings_snapshot':
      '{"version":1,"shopName":"Đakao V1","address":"A",'
      '"phone":"1","footer":"Dòng 1\\nDòng 2"}',
};

Map<String, Object?> _item(
  int id,
  int orderId,
  int? productId,
  String name,
  int price, {
  String? note,
}) => <String, Object?>{
  'id': id,
  'order_id': orderId,
  'product_id': productId,
  'product_name_snapshot': name,
  'unit_price_snapshot': price,
  'quantity': 1,
  'note': note,
  'line_total': price,
};

const _validPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  4,
  0,
  0,
  0,
  181,
  28,
  12,
  2,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  100,
  248,
  15,
  0,
  1,
  5,
  1,
  1,
  39,
  24,
  227,
  102,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
