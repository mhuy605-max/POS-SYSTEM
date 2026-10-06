import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

import 'backup_canonical_upgrader.dart';
import 'backup_models.dart';

final class BackupValidator {
  const BackupValidator({
    required this.schemaVersion,
    this.maxArchiveBytes = 128 * 1024 * 1024,
    this.maxEntryBytes = 32 * 1024 * 1024,
    this.maxExpandedBytes = 256 * 1024 * 1024,
    this.maxRowsPerTable = 100000,
    this.maxImageDimension = 8192,
    this.maxImagePixels = 16 * 1024 * 1024,
  });

  final int schemaVersion;
  final int maxArchiveBytes;
  final int maxEntryBytes;
  final int maxExpandedBytes;
  final int maxRowsPerTable;
  final int maxImageDimension;
  final int maxImagePixels;

  ValidatedBackup validateBytes(Uint8List bytes) {
    try {
      return _validate(bytes);
    } on BackupValidationException {
      rethrow;
    } on Object catch (error) {
      throw BackupValidationException('Invalid backup: $error');
    }
  }

  ValidatedBackup _validate(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxArchiveBytes) {
      throw const BackupValidationException('Backup file size is invalid.');
    }
    _rejectSymlinkEntriesBeforeDecode(bytes);
    final headerNames = <String>[];
    final archive = ZipDecoder().decodeBytes(
      bytes,
      verify: true,
      callback: (entry) => headerNames.add(entry.name),
    );
    if (headerNames.length != headerNames.toSet().length) {
      throw const BackupValidationException('Duplicate archive entry.');
    }
    var expandedBytes = 0;
    for (final entry in archive) {
      _requireSafeArchivePath(entry.name);
      if (!entry.isFile || entry.symbolicLink != null) {
        throw const BackupValidationException('Unsupported archive entry.');
      }
      if (entry.size < 0 || entry.size > maxEntryBytes) {
        throw const BackupValidationException('Archive entry is too large.');
      }
      expandedBytes += entry.size;
      if (expandedBytes > maxExpandedBytes) {
        throw const BackupValidationException('Expanded backup is too large.');
      }
    }

    final manifestEntry = archive.find('manifest.json');
    final dataEntry = archive.find('data.json');
    if (manifestEntry == null || dataEntry == null) {
      throw const BackupValidationException(
        'Required backup entry is missing.',
      );
    }
    final manifest = BackupManifest.fromJson(
      _decodeMap(
        _entryBytes(
          manifestEntry,
          limit: maxEntryBytes,
          totalRemaining: maxExpandedBytes,
        ),
        'manifest.json',
      ),
    );
    if (manifest.magic != BackupManifest.magicValue) {
      throw const BackupValidationException('Backup magic is invalid.');
    }
    if (manifest.formatVersion != 1) {
      throw const BackupValidationException('Backup version is unsupported.');
    }
    final supportedSchema = switch (schemaVersion) {
      1 => manifest.schemaVersion == 1,
      2 => manifest.schemaVersion == 1 || manifest.schemaVersion == 2,
      _ => false,
    };
    if (!supportedSchema) {
      throw const BackupValidationException('Database schema is incompatible.');
    }
    final createdAt = DateTime.tryParse(manifest.createdAtUtc);
    if (createdAt == null || !createdAt.isUtc) {
      throw const BackupValidationException('Creation timestamp is invalid.');
    }

    final actualNames = archive
        .map((entry) => entry.name)
        .where((name) => name != 'manifest.json')
        .toSet();
    if (actualNames.any(
      (name) => name != 'data.json' && !name.startsWith('images/'),
    )) {
      throw const BackupValidationException('Unsupported archive entry.');
    }
    if (!actualNames.contains('data.json') ||
        actualNames.length != manifest.entries.length ||
        !actualNames.containsAll(manifest.entries.keys) ||
        !manifest.entries.keys.toSet().containsAll(actualNames)) {
      throw const BackupValidationException('Archive entries are undeclared.');
    }
    final verifiedBytes = <String, Uint8List>{};
    for (final metadata in manifest.entries.entries) {
      final entry = archive.find(metadata.key);
      if (entry == null) {
        throw const BackupValidationException('Declared entry is missing.');
      }
      final remaining =
          maxExpandedBytes -
          verifiedBytes.values.fold<int>(0, (sum, value) => sum + value.length);
      final content = _entryBytes(
        entry,
        limit: metadata.value.size < maxEntryBytes
            ? metadata.value.size
            : maxEntryBytes,
        totalRemaining: remaining,
      );
      if (content.length != metadata.value.size ||
          sha256.convert(content).toString() != metadata.value.sha256) {
        throw const BackupValidationException('Entry integrity check failed.');
      }
      verifiedBytes[metadata.key] = content;
    }

    final sourceData = _decodeMap(verifiedBytes['data.json']!, 'data.json');
    final sourceTables = _validateTables(sourceData, manifest.schemaVersion);
    _validateBusinessData(sourceTables, manifest.schemaVersion);

    final data = manifest.schemaVersion == 1 && schemaVersion == 2
        ? BackupCanonicalUpgrader.v1ToV2(sourceData)
        : sourceData;
    final canonicalData = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    final tables = _validateTables(data, schemaVersion);
    final imagePaths = _validateBusinessData(tables, schemaVersion);
    final images = <String, Uint8List>{};
    for (final path in imagePaths) {
      _requireSafeImagePath(path);
      final archivePath = 'images/$path';
      final content = verifiedBytes[archivePath];
      if (content == null) {
        throw const BackupValidationException('Referenced image is missing.');
      }
      if (!_isSupportedImage(
        content,
        maxDimension: maxImageDimension,
        maxPixels: maxImagePixels,
      )) {
        throw const BackupValidationException('Product image is corrupt.');
      }
      images[path] = content;
    }
    final expectedImageEntries = imagePaths
        .map((path) => 'images/$path')
        .toSet();
    final actualImageEntries = verifiedBytes.keys
        .where((path) => path.startsWith('images/'))
        .toSet();
    if (actualImageEntries.length != expectedImageEntries.length ||
        !actualImageEntries.containsAll(expectedImageEntries)) {
      throw const BackupValidationException('Backup contains unknown images.');
    }

    return ValidatedBackup(
      manifest: manifest,
      canonicalData: canonicalData,
      data: data,
      images: images,
      summary: BackupSummary(
        categories: tables['categories']!.length,
        products: tables['products']!.length,
        orders: tables['orders']!.length,
        images: images.length,
      ),
    );
  }

  Map<String, List<Object?>> _validateTables(
    Map<String, Object?> data,
    int payloadSchemaVersion,
  ) {
    if (data.keys.length != 1 || data['tables'] is! Map<String, Object?>) {
      throw const BackupValidationException('Data root is invalid.');
    }
    final raw = data['tables']! as Map<String, Object?>;
    const v1Names = <String>{
      'categories',
      'products',
      'orders',
      'order_items',
      'print_attempts',
      'app_settings',
      'printer_settings',
    };
    const v2Names = <String>{
      ...v1Names,
      'option_groups',
      'option_items',
      'product_option_groups',
      'order_item_options',
    };
    final names = switch (payloadSchemaVersion) {
      1 => v1Names,
      2 => v2Names,
      _ => throw const BackupValidationException(
        'Database schema is incompatible.',
      ),
    };
    if (raw.keys.length != names.length ||
        !raw.keys.toSet().containsAll(names)) {
      throw const BackupValidationException('Required table set is invalid.');
    }
    return <String, List<Object?>>{
      for (final name in names)
        name: _requiredRows(raw[name], name, maxRowsPerTable),
    };
  }

  Set<String> _validateBusinessData(
    Map<String, List<Object?>> tables,
    int payloadSchemaVersion,
  ) {
    final categoryIds = _validateRows(
      tables['categories']!,
      'categories',
      const {
        'id',
        'name',
        'sort_order',
        'is_active',
        'created_at',
        'updated_at',
      },
      (row) {
        _positiveInt(row, 'id');
        _nonBlank(row, 'name');
        _int(row, 'sort_order');
        _bool(row, 'is_active');
        _int(row, 'created_at');
        _int(row, 'updated_at');
      },
    );
    final imagePaths = <String>{};
    final productIds = _validateRows(
      tables['products']!,
      'products',
      const {
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
      },
      (row) {
        _positiveInt(row, 'id');
        if (!categoryIds.contains(_positiveInt(row, 'category_id'))) {
          throw const BackupValidationException('Product category is missing.');
        }
        _nonBlank(row, 'name');
        _nullableString(row, 'description');
        if (_int(row, 'price') < 0) _invalid('price');
        final path = _nullableString(row, 'image_path');
        if (path != null) imagePaths.add(path);
        _bool(row, 'is_available');
        _int(row, 'sort_order');
        _int(row, 'created_at');
        _int(row, 'updated_at');
        _nullableInt(row, 'deleted_at');
      },
    );
    var optionGroupIds = <int>{};
    var optionItemIds = <int>{};
    if (payloadSchemaVersion == 2) {
      optionGroupIds = _validateRows(
        tables['option_groups']!,
        'option_groups',
        const {
          'id',
          'name',
          'sort_order',
          'is_active',
          'created_at',
          'updated_at',
        },
        (row) {
          _positiveInt(row, 'id');
          _nonBlank(row, 'name');
          _int(row, 'sort_order');
          _bool(row, 'is_active');
          _int(row, 'created_at');
          _int(row, 'updated_at');
        },
      );
      optionItemIds = _validateRows(
        tables['option_items']!,
        'option_items',
        const {
          'id',
          'group_id',
          'name',
          'price_delta',
          'sort_order',
          'is_active',
          'created_at',
          'updated_at',
        },
        (row) {
          _positiveInt(row, 'id');
          if (!optionGroupIds.contains(_positiveInt(row, 'group_id'))) {
            _invalid('option group_id');
          }
          _nonBlank(row, 'name');
          if (_int(row, 'price_delta') < 0) _invalid('price_delta');
          _int(row, 'sort_order');
          _bool(row, 'is_active');
          _int(row, 'created_at');
          _int(row, 'updated_at');
        },
      );
      final attachments = <(int, int)>{};
      _validateRowsWithoutId(
        tables['product_option_groups']!,
        'product_option_groups',
        const {'product_id', 'option_group_id'},
        (row) {
          final productId = _positiveInt(row, 'product_id');
          final groupId = _positiveInt(row, 'option_group_id');
          if (!productIds.contains(productId) ||
              !optionGroupIds.contains(groupId) ||
              !attachments.add((productId, groupId))) {
            _invalid('product option group');
          }
        },
      );
    }
    final orderNumbers = <int>{};
    final tokens = <String>{};
    final orderTotals = <int, int>{};
    final orderIds = _validateRows(
      tables['orders']!,
      'orders',
      const {
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
      },
      (row) {
        final id = _positiveInt(row, 'id');
        final number = _positiveInt(row, 'order_number');
        if (!orderNumbers.add(number)) _invalid('order_number');
        final token = _nonBlank(row, 'submission_token');
        if (!tokens.add(token)) _invalid('submission_token');
        final orderType = _nullableString(row, 'order_type');
        if (orderType != null && !{'DINE_IN', 'TAKEAWAY'}.contains(orderType)) {
          _invalid('order_type');
        }
        final status = _string(row, 'status');
        if (!{'UNPAID', 'PAID', 'CANCELLED'}.contains(status)) {
          _invalid('status');
        }
        final subtotal = _int(row, 'subtotal');
        final total = _int(row, 'total');
        if (subtotal < 0 || total != subtotal) _invalid('total');
        orderTotals[id] = total;
        _int(row, 'created_at');
        final paidAt = _nullableInt(row, 'paid_at');
        final cancelledAt = _nullableInt(row, 'cancelled_at');
        _nullableInt(row, 'printed_at');
        if (_int(row, 'print_count') < 0) _invalid('print_count');
        _nullableString(row, 'cancellation_reason');
        if (status == 'UNPAID' && (paidAt != null || cancelledAt != null)) {
          _invalid('UNPAID timestamps');
        }
        if (status == 'PAID' && (paidAt == null || cancelledAt != null)) {
          _invalid('PAID timestamps');
        }
        if (status == 'CANCELLED' && cancelledAt == null) {
          _invalid('CANCELLED timestamps');
        }
        _validateReceiptSnapshot(_nonBlank(row, 'receipt_settings_snapshot'));
      },
    );
    final itemSums = <int, int>{};
    final itemBasePrices = <int, int>{};
    final itemEffectivePrices = <int, int>{};
    final itemIds = _validateRows(
      tables['order_items']!,
      'order_items',
      <String>{
        'id',
        'order_id',
        'product_id',
        'product_name_snapshot',
        if (payloadSchemaVersion == 2) 'base_unit_price_snapshot',
        'unit_price_snapshot',
        'quantity',
        'note',
        'line_total',
      },
      (row) {
        final itemId = _positiveInt(row, 'id');
        final orderId = _positiveInt(row, 'order_id');
        if (!orderIds.contains(orderId)) _invalid('order_id');
        final productId = _nullableInt(row, 'product_id');
        if (productId != null && !productIds.contains(productId)) {
          _invalid('product_id');
        }
        _nonBlank(row, 'product_name_snapshot');
        final price = _int(row, 'unit_price_snapshot');
        final basePrice = payloadSchemaVersion == 2
            ? _int(row, 'base_unit_price_snapshot')
            : price;
        final quantity = _int(row, 'quantity');
        final lineTotal = _int(row, 'line_total');
        if (basePrice < 0 ||
            price < 0 ||
            quantity <= 0 ||
            lineTotal != price * quantity) {
          _invalid('line_total');
        }
        itemBasePrices[itemId] = basePrice;
        itemEffectivePrices[itemId] = price;
        _nullableString(row, 'note');
        itemSums[orderId] = (itemSums[orderId] ?? 0) + lineTotal;
      },
    );
    if (payloadSchemaVersion == 2) {
      final optionDeltas = <int, int>{};
      final displayOrders = <int, Set<int>>{};
      _validateRows(
        tables['order_item_options']!,
        'order_item_options',
        const {
          'id',
          'order_item_id',
          'option_item_id',
          'group_name_snapshot',
          'option_name_snapshot',
          'price_delta_snapshot',
          'display_order',
        },
        (row) {
          _positiveInt(row, 'id');
          final itemId = _positiveInt(row, 'order_item_id');
          if (!itemIds.contains(itemId)) _invalid('option order_item_id');
          final optionItemId = _nullableInt(row, 'option_item_id');
          if (optionItemId != null && !optionItemIds.contains(optionItemId)) {
            _invalid('option_item_id');
          }
          _nonBlank(row, 'group_name_snapshot');
          _nonBlank(row, 'option_name_snapshot');
          final delta = _int(row, 'price_delta_snapshot');
          if (delta < 0) _invalid('price_delta_snapshot');
          final displayOrder = _int(row, 'display_order');
          if (displayOrder < 0 ||
              !(displayOrders[itemId] ??= <int>{}).add(displayOrder)) {
            _invalid('display_order');
          }
          optionDeltas[itemId] = (optionDeltas[itemId] ?? 0) + delta;
        },
      );
      for (final itemId in itemIds) {
        if (itemEffectivePrices[itemId] !=
            itemBasePrices[itemId]! + (optionDeltas[itemId] ?? 0)) {
          _invalid('configured unit price');
        }
      }
    }
    for (final entry in orderTotals.entries) {
      if ((itemSums[entry.key] ?? 0) != entry.value) _invalid('order item sum');
    }
    _validateRows(
      tables['print_attempts']!,
      'print_attempts',
      const {'id', 'order_id', 'attempted_at', 'success', 'error_message'},
      (row) {
        _positiveInt(row, 'id');
        if (!orderIds.contains(_positiveInt(row, 'order_id'))) {
          _invalid('print order_id');
        }
        _int(row, 'attempted_at');
        _bool(row, 'success');
        _nullableString(row, 'error_message');
      },
    );
    _validateSingleton(
      tables['app_settings']!,
      const {'id', 'shop_name', 'address', 'phone', 'receipt_footer'},
      (row) {
        _string(row, 'shop_name');
        _string(row, 'address');
        _string(row, 'phone');
        _string(row, 'receipt_footer');
      },
    );
    _validateSingleton(
      tables['printer_settings']!,
      const {
        'id',
        'printer_name',
        'printer_address',
        'auto_reconnect',
        'auto_print',
      },
      (row) {
        _nullableString(row, 'printer_name');
        _nullableString(row, 'printer_address');
        _bool(row, 'auto_reconnect');
        _bool(row, 'auto_print');
      },
    );
    return imagePaths;
  }
}

Map<String, Object?> _decodeMap(Uint8List bytes, String name) {
  final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  if (decoded is! Map<String, Object?>) {
    throw BackupValidationException('$name must contain a JSON object.');
  }
  return decoded;
}

Uint8List _entryBytes(ArchiveFile entry, {int? limit, int? totalRemaining}) {
  if (limit == null || totalRemaining == null) {
    final bytes = entry.readBytes();
    if (bytes == null) {
      throw const BackupValidationException('Entry is unreadable.');
    }
    return bytes;
  }
  final output = _BoundedOutputStream(
    limit < totalRemaining ? limit : totalRemaining,
  );
  entry.decompress(output);
  return output.getBytes();
}

final class _BoundedOutputStream extends OutputMemoryStream {
  _BoundedOutputStream(this.maximum)
    : super(size: maximum <= 0 ? 1 : (maximum < 32768 ? maximum : 32768));

  final int maximum;

  void _requireCapacity(int count) {
    if (count < 0 || length + count > maximum) {
      throw const BackupValidationException('Expanded backup is too large.');
    }
  }

  @override
  void writeByte(int value) {
    _requireCapacity(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _requireCapacity(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _requireCapacity(stream.length);
    super.writeStream(stream);
  }

  @override
  void writeBackReference(int distance, int count) {
    _requireCapacity(count);
    super.writeBackReference(distance, count);
  }
}

List<Object?> _requiredRows(Object? value, String name, int limit) {
  if (value is! List<Object?> || value.length > limit) {
    throw BackupValidationException('Invalid or oversized table: $name.');
  }
  return value;
}

Set<int> _validateRows(
  List<Object?> rows,
  String name,
  Set<String> keys,
  void Function(Map<String, Object?>) validate,
) {
  final ids = <int>{};
  for (final value in rows) {
    if (value is! Map<String, Object?> ||
        value.keys.length != keys.length ||
        !value.keys.toSet().containsAll(keys)) {
      throw BackupValidationException('Invalid row in $name.');
    }
    validate(value);
    if (!ids.add(_positiveInt(value, 'id'))) {
      throw BackupValidationException('Duplicate ID in $name.');
    }
  }
  return ids;
}

void _validateRowsWithoutId(
  List<Object?> rows,
  String name,
  Set<String> keys,
  void Function(Map<String, Object?>) validate,
) {
  for (final value in rows) {
    if (value is! Map<String, Object?> ||
        value.keys.length != keys.length ||
        !value.keys.toSet().containsAll(keys)) {
      throw BackupValidationException('Invalid row in $name.');
    }
    validate(value);
  }
}

void _validateSingleton(
  List<Object?> rows,
  Set<String> keys,
  void Function(Map<String, Object?>) validate,
) {
  if (rows.length != 1) _invalid('singleton row');
  _validateRows(rows, 'settings', keys, (row) {
    if (_positiveInt(row, 'id') != 1) _invalid('singleton id');
    validate(row);
  });
}

void _validateReceiptSnapshot(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map<String, Object?> ||
      decoded['version'] != 1 ||
      decoded['shopName'] is! String ||
      decoded['address'] is! String ||
      decoded['phone'] is! String ||
      decoded['footer'] is! String) {
    _invalid('receipt_settings_snapshot');
  }
}

int _positiveInt(Map<String, Object?> row, String key) {
  final value = _int(row, key);
  if (value <= 0) _invalid(key);
  return value;
}

int _int(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! int) _invalid(key);
  return value;
}

int? _nullableInt(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value != null && value is! int) _invalid(key);
  return value as int?;
}

String _string(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! String) _invalid(key);
  return value;
}

String _nonBlank(Map<String, Object?> row, String key) {
  final value = _string(row, key);
  if (value.trim().isEmpty) _invalid(key);
  return value;
}

String? _nullableString(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value != null && value is! String) _invalid(key);
  return value as String?;
}

bool _bool(Map<String, Object?> row, String key) {
  final value = row[key];
  if (value is! bool) _invalid(key);
  return value;
}

Never _invalid(String name) {
  throw BackupValidationException('Invalid $name.');
}

void _requireSafeArchivePath(String path) {
  final segments = path.split('/');
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.contains('\\') ||
      path.contains(':') ||
      segments.any(
        (segment) => segment.isEmpty || segment == '.' || segment == '..',
      )) {
    throw const BackupValidationException('Unsafe archive path.');
  }
}

void _requireSafeImagePath(String path) {
  _requireSafeArchivePath(path);
  if (!path.startsWith('product-images/') || path.split('/').length != 2) {
    throw const BackupValidationException('Unsafe product image path.');
  }
}

bool _isSupportedImage(
  Uint8List bytes, {
  required int maxDimension,
  required int maxPixels,
}) {
  try {
    final decoder = image.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (decoder == null ||
        info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width > maxDimension ||
        info.height > maxDimension ||
        info.width > maxPixels ~/ info.height) {
      return false;
    }
    final decoded = decoder.decode(bytes, frame: 0);
    return decoded != null &&
        decoded.width == info.width &&
        decoded.height == info.height;
  } on Object {
    return false;
  }
}

void _rejectSymlinkEntriesBeforeDecode(Uint8List bytes) {
  const endSignature = 0x06054b50;
  var end = -1;
  final earliest = bytes.length > 65557 ? bytes.length - 65557 : 0;
  for (var offset = bytes.length - 22; offset >= earliest; offset--) {
    if (_readUint32Le(bytes, offset) == endSignature) {
      end = offset;
      break;
    }
  }
  if (end < 0 || end + 22 > bytes.length) {
    throw const BackupValidationException('ZIP directory is invalid.');
  }
  final entryCount = _readUint16Le(bytes, end + 10);
  final centralSize = _readUint32Le(bytes, end + 12);
  final centralOffset = _readUint32Le(bytes, end + 16);
  if (entryCount == 0xffff ||
      centralSize == 0xffffffff ||
      centralOffset == 0xffffffff ||
      centralOffset + centralSize > end) {
    throw const BackupValidationException('ZIP directory is unsupported.');
  }
  var offset = centralOffset;
  for (var index = 0; index < entryCount; index++) {
    if (offset + 46 > bytes.length ||
        _readUint32Le(bytes, offset) != 0x02014b50) {
      throw const BackupValidationException('ZIP directory is invalid.');
    }
    final externalAttributes = _readUint32Le(bytes, offset + 38);
    if (((externalAttributes >> 16) & 0xf000) == 0xa000) {
      throw const BackupValidationException('Unsupported archive entry.');
    }
    final nameLength = _readUint16Le(bytes, offset + 28);
    final extraLength = _readUint16Le(bytes, offset + 30);
    final commentLength = _readUint16Le(bytes, offset + 32);
    offset += 46 + nameLength + extraLength + commentLength;
    if (offset > bytes.length) {
      throw const BackupValidationException('ZIP directory is invalid.');
    }
  }
  if (offset != centralOffset + centralSize) {
    throw const BackupValidationException('ZIP directory is invalid.');
  }
}

int _readUint16Le(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 2 > bytes.length) {
    throw const BackupValidationException('ZIP directory is invalid.');
  }
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _readUint32Le(Uint8List bytes, int offset) {
  if (offset < 0 || offset + 4 > bytes.length) {
    throw const BackupValidationException('ZIP directory is invalid.');
  }
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}
