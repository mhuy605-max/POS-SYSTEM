import 'dart:typed_data';

final class BackupEntryMetadata {
  const BackupEntryMetadata({required this.size, required this.sha256});

  final int size;
  final String sha256;

  Map<String, Object> toJson() => <String, Object>{
    'size': size,
    'sha256': sha256,
  };

  factory BackupEntryMetadata.fromJson(Map<String, Object?> json) {
    return BackupEntryMetadata(
      size: _requiredInt(json, 'size'),
      sha256: _requiredString(json, 'sha256'),
    );
  }
}

final class BackupManifest {
  const BackupManifest({
    required this.magic,
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAtUtc,
    required this.entries,
  });

  static const String magicValue = 'DAKAO_IN_BILL_BACKUP';

  final String magic;
  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final String createdAtUtc;
  final Map<String, BackupEntryMetadata> entries;

  Map<String, Object> toJson() => <String, Object>{
    'magic': magic,
    'format_version': formatVersion,
    'schema_version': schemaVersion,
    'app_version': appVersion,
    'created_at_utc': createdAtUtc,
    'entries': <String, Object>{
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    },
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final rawEntries = json['entries'];
    if (rawEntries is! Map<String, Object?>) {
      throw const FormatException('Invalid manifest entries.');
    }
    return BackupManifest(
      magic: _requiredString(json, 'magic'),
      formatVersion: _requiredInt(json, 'format_version'),
      schemaVersion: _requiredInt(json, 'schema_version'),
      appVersion: _requiredString(json, 'app_version'),
      createdAtUtc: _requiredString(json, 'created_at_utc'),
      entries: <String, BackupEntryMetadata>{
        for (final entry in rawEntries.entries)
          entry.key: BackupEntryMetadata.fromJson(
            _requiredMap(entry.value, 'entry ${entry.key}'),
          ),
      },
    );
  }
}

final class BackupSummary {
  const BackupSummary({
    required this.categories,
    required this.products,
    required this.orders,
    required this.images,
  });

  final int categories;
  final int products;
  final int orders;
  final int images;
}

final class ValidatedBackup {
  const ValidatedBackup({
    required this.manifest,
    required this.canonicalData,
    required this.data,
    required this.images,
    required this.summary,
  });

  final BackupManifest manifest;
  final Uint8List canonicalData;
  final Map<String, Object?> data;
  final Map<String, Uint8List> images;
  final BackupSummary summary;
}

final class StagedBackup {
  const StagedBackup({
    required this.bytes,
    required this.suggestedFileName,
    required this.manifest,
  });

  final Uint8List bytes;
  final String suggestedFileName;
  final BackupManifest manifest;
}

final class BackupCreationException implements Exception {
  const BackupCreationException(this.message);

  final String message;

  @override
  String toString() => 'BackupCreationException: $message';
}

final class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => 'BackupValidationException: $message';
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('Invalid $key.');
  return value;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key.');
  }
  return value;
}

Map<String, Object?> _requiredMap(Object? value, String name) {
  if (value is! Map<String, Object?>) {
    throw FormatException('Invalid $name.');
  }
  return value;
}
