import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dakao_in_bill/backup/backup_canonical_upgrader.dart';
import 'package:dakao_in_bill/backup/backup_models.dart';
import 'package:dakao_in_bill/backup/backup_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Uint8List valid;

  setUp(() {
    valid = _archive(_validData());
  });

  test('accepts a complete compatible archive and reports its contents', () {
    final result = const BackupValidator(schemaVersion: 1).validateBytes(valid);

    expect(result.manifest.magic, BackupManifest.magicValue);
    expect(result.summary.categories, 1);
    expect(result.summary.products, 1);
    expect(result.summary.orders, 1);
    expect(result.summary.images, 1);
    expect(result.images.keys, ['product-images/menu.png']);
  });

  test('rejects malformed ZIP and malformed JSON', () {
    final validator = const BackupValidator(schemaVersion: 1);

    expect(
      () => validator.validateBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () => validator.validateBytes(
        _archive(_validData(), dataBytes: Uint8List.fromList(utf8.encode('{'))),
      ),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects wrong magic and unsupported future format version', () {
    expect(
      () =>
          const BackupValidator(schemaVersion: 1)
              .validateBytes(_archive(_validData(), magic: 'OTHER')),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () =>
          const BackupValidator(schemaVersion: 1)
              .validateBytes(_archive(_validData(), formatVersion: 2)),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects incompatible schema and missing required entries', () {
    final validator = const BackupValidator(schemaVersion: 1);
    expect(
      () => validator.validateBytes(_archive(_validData(), schemaVersion: 2)),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () => validator.validateBytes(_archive(_validData(), omitData: true)),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('schema 2 accepts and canonically upgrades a valid schema 1 backup', () {
    final legacy = _validData();
    final products = _tables(legacy)['products']! as List<Object?>;
    (products.first! as Map<String, Object?>)['sort_order'] = 9;
    products.addAll(<Object?>[
      {
        ...(products.first! as Map<String, Object?>),
        'id': 21,
        'name': 'Trà đá',
        'image_path': null,
        'sort_order': -3,
      },
      {
        ...(products.first! as Map<String, Object?>),
        'id': 22,
        'name': 'Món ẩn',
        'image_path': null,
        'sort_order': -3,
        'deleted_at': 999,
      },
    ]);

    final result = const BackupValidator(schemaVersion: 2)
        .validateBytes(_archive(legacy));
    final tables = _tables(result.data);

    expect(result.manifest.schemaVersion, 1);
    expect(tables.keys.toSet(), {
      'categories',
      'products',
      'option_groups',
      'option_items',
      'product_option_groups',
      'orders',
      'order_items',
      'order_item_options',
      'print_attempts',
      'app_settings',
      'printer_settings',
    });
    expect(tables['option_groups'], isEmpty);
    expect(tables['option_items'], isEmpty);
    expect(tables['product_option_groups'], isEmpty);
    expect(tables['order_item_options'], isEmpty);
    expect(
      (tables['order_items']! as List<Object?>).single,
      containsPair('base_unit_price_snapshot', 45000),
    );
    final upgradedProducts = tables['products']! as List<Object?>;
    expect(upgradedProducts.map((row) => (row! as Map)['id']), [20, 21, 22]);
    expect(upgradedProducts.map((row) => (row! as Map)['sort_order']), [
      2,
      0,
      1,
    ]);
    expect(jsonDecode(utf8.decode(result.canonicalData)), result.data);
  });

  test('canonical upgrader does not mutate its schema 1 input', () {
    final source = _validData();
    final before = jsonEncode(source);

    BackupCanonicalUpgrader.v1ToV2(source);

    expect(jsonEncode(source), before);
  });

  test(
    'schema 2 strictly validates its declared shape and configured price',
    () {
      final validV2 = BackupCanonicalUpgrader.v1ToV2(_validData());
      expect(
        () =>
            const BackupValidator(schemaVersion: 2)
                .validateBytes(_archive(validV2, schemaVersion: 2)),
        returnsNormally,
      );
      expect(
        () =>
            const BackupValidator(schemaVersion: 1)
                .validateBytes(_archive(validV2, schemaVersion: 2)),
        throwsA(isA<BackupValidationException>()),
        reason: 'the preserved V1.0 compatibility boundary rejects schema 2',
      );

      final missingTable = BackupCanonicalUpgrader.v1ToV2(_validData());
      _tables(missingTable).remove('option_groups');
      final missingBase = BackupCanonicalUpgrader.v1ToV2(_validData());
      ((_tables(missingBase)['order_items']! as List<Object?>).single!
              as Map<String, Object?>)
          .remove('base_unit_price_snapshot');
      final wrongPrice = BackupCanonicalUpgrader.v1ToV2(_validData());
      ((_tables(wrongPrice)['order_items']! as List<Object?>).single!
              as Map<String, Object?>)['base_unit_price_snapshot'] =
          1;

      for (final malformed in [missingTable, missingBase, wrongPrice]) {
        expect(
          () =>
              const BackupValidator(schemaVersion: 2)
                  .validateBytes(_archive(malformed, schemaVersion: 2)),
          throwsA(isA<BackupValidationException>()),
        );
      }
    },
  );

  test('rejects a missing required table and extra table', () {
    final missing = _validData();
    _tables(missing).remove('orders');
    final extra = _validData();
    _tables(extra)['users'] = <Object>[];

    for (final data in [missing, extra]) {
      expect(
        () =>
            const BackupValidator(schemaVersion: 1)
                .validateBytes(_archive(data)),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('rejects duplicate, traversal, and unknown archive paths', () {
    final duplicate = _withDuplicateDataEntry(valid);
    final traversal = _archive(
      _validData(),
      extraEntries: {'../outside.png': Uint8List.fromList(_pngBytes)},
    );
    final unknown = _archive(
      _validData(),
      extraEntries: {
        'notes.txt': Uint8List.fromList([1]),
      },
    );

    for (final bytes in [duplicate, traversal, unknown]) {
      expect(
        () => const BackupValidator(schemaVersion: 1).validateBytes(bytes),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('rejects checksum and declared-size mismatches', () {
    final badHash = _archive(_validData(), dataSha256: '0' * 64);
    final badSize = _archive(_validData(), dataSizeAdjustment: 1);

    for (final bytes in [badHash, badSize]) {
      expect(
        () => const BackupValidator(schemaVersion: 1).validateBytes(bytes),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('rejects undeclared, missing, and corrupt referenced images', () {
    final undeclared = _archive(
      _validData(),
      extraEntries: {
        'images/product-images/extra.png': Uint8List.fromList(_pngBytes),
      },
    );
    final missing = _archive(_validData(), omitImage: true);
    final corrupt = _archive(
      _validData(),
      imageBytes: Uint8List.fromList(utf8.encode('not an image')),
    );
    final truncated = _archive(
      _validData(),
      imageBytes: Uint8List.fromList(_pngBytes.take(12).toList()),
    );
    final corruptPayload = _archive(
      _validData(),
      imageBytes: _corruptPngPayload(Uint8List.fromList(_pngBytes)),
    );

    for (final bytes in [
      undeclared,
      missing,
      corrupt,
      truncated,
      corruptPayload,
    ]) {
      expect(
        () => const BackupValidator(schemaVersion: 1).validateBytes(bytes),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('rejects bounded archive, entry, and row expansion', () {
    expect(
      () => const BackupValidator(
        schemaVersion: 1,
        maxArchiveBytes: 100,
      ).validateBytes(valid),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () => const BackupValidator(
        schemaVersion: 1,
        maxEntryBytes: 10,
      ).validateBytes(valid),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () => const BackupValidator(
        schemaVersion: 1,
        maxRowsPerTable: 0,
      ).validateBytes(valid),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      () => const BackupValidator(
        schemaVersion: 1,
        maxImagePixels: 0,
      ).validateBytes(valid),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test(
    'bounds actual decompression when ZIP headers understate entry size',
    () {
      final data = _validData();
      ((_tables(data)['products']! as List<Object?>).first!
              as Map<String, Object?>)['description'] =
          'A' * 50000;
      final understated = _understateZipEntrySize(
        _archive(data),
        'data.json',
        1,
      );

      expect(
        () => const BackupValidator(
          schemaVersion: 1,
          maxEntryBytes: 4096,
        ).validateBytes(understated),
        throwsA(isA<BackupValidationException>()),
      );
    },
  );

  test('rejects symlink-mode entries before ZIP content expansion', () {
    final data = _validData();
    ((_tables(data)['products']! as List<Object?>).first!
            as Map<String, Object?>)['description'] =
        'A' * 50000;
    final malicious = _markZipEntryAsSymlink(_archive(data), 'data.json');

    expect(
      () => const BackupValidator(
        schemaVersion: 1,
        maxEntryBytes: 4096,
      ).validateBytes(malicious),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('rejects duplicate IDs, order numbers, and submission tokens', () {
    final duplicateId = _validData();
    (_tables(duplicateId)['categories']! as List<Object?>).add(
      Map<String, Object?>.from(
        (_tables(duplicateId)['categories']! as List<Object?>).first!
            as Map<String, Object?>,
      ),
    );
    final duplicateNumber = _validData();
    final ordersByNumber = _tables(duplicateNumber)['orders']! as List<Object?>;
    ordersByNumber.add({
      ...(ordersByNumber.first! as Map<String, Object?>),
      'id': 31,
      'submission_token': 'another',
    });
    final duplicateToken = _validData();
    final ordersByToken = _tables(duplicateToken)['orders']! as List<Object?>;
    ordersByToken.add({
      ...(ordersByToken.first! as Map<String, Object?>),
      'id': 31,
      'order_number': 2,
    });

    for (final data in [duplicateId, duplicateNumber, duplicateToken]) {
      expect(
        () =>
            const BackupValidator(schemaVersion: 1)
                .validateBytes(_archive(data)),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('rejects bad foreign keys, enum values, and totals', () {
    final badForeignKey = _validData();
    ((_tables(badForeignKey)['products']! as List<Object?>).first!
            as Map<String, Object?>)['category_id'] =
        999;
    final badEnum = _validData();
    ((_tables(badEnum)['orders']! as List<Object?>).first!
            as Map<String, Object?>)['status'] =
        'REFUNDED';
    final badTotal = _validData();
    ((_tables(badTotal)['orders']! as List<Object?>).first!
            as Map<String, Object?>)['total'] =
        40000;

    for (final data in [badForeignKey, badEnum, badTotal]) {
      expect(
        () =>
            const BackupValidator(schemaVersion: 1)
                .validateBytes(_archive(data)),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });

  test('rejects invalid singleton rows and receipt snapshots', () {
    final badSingleton = _validData();
    ((_tables(badSingleton)['app_settings']! as List<Object?>).first!
            as Map<String, Object?>)['id'] =
        2;
    final badReceipt = _validData();
    ((_tables(badReceipt)['orders']! as List<Object?>).first!
            as Map<String, Object?>)['receipt_settings_snapshot'] =
        '{}';

    for (final data in [badSingleton, badReceipt]) {
      expect(
        () =>
            const BackupValidator(schemaVersion: 1)
                .validateBytes(_archive(data)),
        throwsA(isA<BackupValidationException>()),
      );
    }
  });
}

const _pngBytes = <int>[
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

Map<String, Object?> _validData() => <String, Object?>{
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
    ],
    'products': <Object?>[
      {
        'id': 20,
        'category_id': 10,
        'name': 'Cơm tấm',
        'description': null,
        'price': 45000,
        'image_path': 'product-images/menu.png',
        'is_available': true,
        'sort_order': 0,
        'created_at': 200,
        'updated_at': 200,
        'deleted_at': null,
      },
    ],
    'orders': <Object?>[
      {
        'id': 30,
        'order_number': 1,
        'submission_token': 'token-1',
        'order_type': null,
        'status': 'PAID',
        'subtotal': 45000,
        'total': 45000,
        'created_at': 300,
        'paid_at': 400,
        'cancelled_at': null,
        'printed_at': 500,
        'print_count': 1,
        'cancellation_reason': null,
        'receipt_settings_snapshot': '{"version":1,"shopName":"Đakao","address":"A","phone":"1","footer":"F"}',
      },
    ],
    'order_items': <Object?>[
      {
        'id': 40,
        'order_id': 30,
        'product_id': 20,
        'product_name_snapshot': 'Cơm tấm',
        'unit_price_snapshot': 45000,
        'quantity': 1,
        'note': null,
        'line_total': 45000,
      },
    ],
    'print_attempts': <Object?>[
      {
        'id': 50,
        'order_id': 30,
        'attempted_at': 500,
        'success': true,
        'error_message': null,
      },
    ],
    'app_settings': <Object?>[
      {
        'id': 1,
        'shop_name': 'Đakao',
        'address': 'A',
        'phone': '1',
        'receipt_footer': 'F',
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

Map<String, Object?> _tables(Map<String, Object?> data) =>
    data['tables']! as Map<String, Object?>;

Uint8List _archive(
  Map<String, Object?> data, {
  String magic = BackupManifest.magicValue,
  int formatVersion = 1,
  int schemaVersion = 1,
  Uint8List? dataBytes,
  Uint8List? imageBytes,
  bool omitData = false,
  bool omitImage = false,
  String? dataSha256,
  int dataSizeAdjustment = 0,
  Map<String, Uint8List> extraEntries = const {},
}) {
  final encodedData =
      dataBytes ?? Uint8List.fromList(utf8.encode(jsonEncode(data)));
  final encodedImage = imageBytes ?? Uint8List.fromList(_pngBytes);
  final entries = <String, Uint8List>{
    if (!omitData) 'data.json': encodedData,
    if (!omitImage) 'images/product-images/menu.png': encodedImage,
    ...extraEntries,
  };
  final declared = <String, Object?>{
    for (final entry in entries.entries)
      entry.key: <String, Object?>{
        'size': entry.value.length,
        'sha256': sha256.convert(entry.value).toString(),
      },
  };
  if (declared['data.json'] case final Map<String, Object?> metadata) {
    metadata['size'] = encodedData.length + dataSizeAdjustment;
    metadata['sha256'] = dataSha256 ?? sha256.convert(encodedData).toString();
  }
  final manifest = <String, Object?>{
    'magic': magic,
    'format_version': formatVersion,
    'schema_version': schemaVersion,
    'app_version': '0.1.0+1',
    'created_at_utc': '2026-10-02T06:30:00.000Z',
    'entries': declared,
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

Uint8List _understateZipEntrySize(
  Uint8List archive,
  String entryName,
  int claimedSize,
) {
  final result = Uint8List.fromList(archive);
  final name = utf8.encode(entryName);
  for (var offset = 0; offset + 30 <= result.length; offset++) {
    final signature = _uint32Le(result, offset);
    final isLocal = signature == 0x04034b50;
    final isCentral = signature == 0x02014b50;
    if (!isLocal && !isCentral) continue;
    final nameLengthOffset = offset + (isLocal ? 26 : 28);
    final nameOffset = offset + (isLocal ? 30 : 46);
    final nameLength = _uint16Le(result, nameLengthOffset);
    if (nameLength != name.length || nameOffset + nameLength > result.length) {
      continue;
    }
    var matches = true;
    for (var index = 0; index < name.length; index++) {
      if (result[nameOffset + index] != name[index]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      _writeUint32Le(result, offset + (isLocal ? 22 : 24), claimedSize);
    }
  }
  return result;
}

int _uint16Le(Uint8List bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _uint32Le(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

void _writeUint32Le(Uint8List bytes, int offset, int value) {
  for (var index = 0; index < 4; index++) {
    bytes[offset + index] = (value >> (8 * index)) & 0xff;
  }
}

Uint8List _markZipEntryAsSymlink(Uint8List archive, String entryName) {
  final result = Uint8List.fromList(archive);
  final name = utf8.encode(entryName);
  for (var offset = 0; offset + 46 <= result.length; offset++) {
    if (_uint32Le(result, offset) != 0x02014b50) continue;
    final nameLength = _uint16Le(result, offset + 28);
    if (nameLength != name.length || offset + 46 + nameLength > result.length) {
      continue;
    }
    var matches = true;
    for (var index = 0; index < name.length; index++) {
      if (result[offset + 46 + index] != name[index]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      _writeUint32Le(result, offset + 38, 0xa0000000);
    }
  }
  return result;
}

Uint8List _corruptPngPayload(Uint8List source) {
  final result = Uint8List.fromList(source);
  for (var offset = 8; offset + 12 <= result.length;) {
    final length =
        (result[offset] << 24) |
        (result[offset + 1] << 16) |
        (result[offset + 2] << 8) |
        result[offset + 3];
    final type = ascii.decode(result.sublist(offset + 4, offset + 8));
    if (type == 'IDAT' && length > 0) {
      result[offset + 8] ^= 0xff;
      return result;
    }
    offset += length + 12;
  }
  throw StateError('Test PNG has no IDAT payload.');
}

Uint8List _withDuplicateDataEntry(Uint8List original) {
  final archive = ZipDecoder().decodeBytes(original);
  archive.addFile(
    ArchiveFile.bytes('evil.json', Uint8List.fromList(utf8.encode('{}'))),
  );
  final encoded = ZipEncoder().encodeBytes(archive);
  final from = utf8.encode('evil.json');
  final to = utf8.encode('data.json');
  for (var i = 0; i <= encoded.length - from.length; i++) {
    var match = true;
    for (var j = 0; j < from.length; j++) {
      if (encoded[i + j] != from[j]) {
        match = false;
        break;
      }
    }
    if (match) {
      encoded.setRange(i, i + to.length, to);
    }
  }
  return encoded;
}
