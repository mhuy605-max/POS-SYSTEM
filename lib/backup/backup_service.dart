import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../data/app_database.dart';
import '../features/products/product_image_store.dart';
import 'backup_data_codec.dart';
import 'backup_models.dart';

final class BackupService {
  const BackupService({
    required AppDatabase database,
    required ProductImageStore imageStore,
    required DateTime Function() nowUtc,
    required String appVersion,
  }) : this._(database, imageStore, nowUtc, appVersion);

  const BackupService._(
    this._database,
    this._imageStore,
    this._nowUtc,
    this._appVersion,
  );

  final AppDatabase _database;
  final ProductImageStore _imageStore;
  final DateTime Function() _nowUtc;
  final String _appVersion;

  Future<StagedBackup> createArchive() async {
    try {
      final createdAt = _nowUtc().toUtc();
      final codec = BackupDataCodec(_database);
      final dataMap = await codec.exportMap();
      final dataBytes = Uint8List.fromList(utf8.encode(jsonEncode(dataMap)));
      final imagePaths = _referencedImagePaths(dataMap);
      final entryBytes = <String, Uint8List>{'data.json': dataBytes};

      for (final relativePath in imagePaths) {
        _requireSafeImagePath(relativePath);
        final file = _imageStore.resolve(relativePath);
        if (!await file.exists()) {
          throw BackupCreationException(
            'Referenced product image is missing: $relativePath',
          );
        }
        entryBytes['images/$relativePath'] = await file.readAsBytes();
      }

      final manifest = BackupManifest(
        magic: BackupManifest.magicValue,
        formatVersion: 1,
        schemaVersion: _database.schemaVersion,
        appVersion: _appVersion,
        createdAtUtc: createdAt.toIso8601String(),
        entries: <String, BackupEntryMetadata>{
          for (final entry in entryBytes.entries)
            entry.key: BackupEntryMetadata(
              size: entry.value.length,
              sha256: sha256.convert(entry.value).toString(),
            ),
        },
      );
      final manifestBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest.toJson())),
      );
      final archive = Archive();
      for (final entry in entryBytes.entries) {
        archive.addFile(_archiveFile(entry.key, entry.value, createdAt));
      }
      archive.addFile(_archiveFile('manifest.json', manifestBytes, createdAt));
      final bytes = ZipEncoder().encodeBytes(archive, modified: createdAt);

      return StagedBackup(
        bytes: bytes,
        suggestedFileName: _fileName(createdAt),
        manifest: manifest,
      );
    } on BackupCreationException {
      rethrow;
    } on Object catch (error) {
      throw BackupCreationException('Could not create backup: $error');
    }
  }
}

ArchiveFile _archiveFile(String name, Uint8List bytes, DateTime createdAt) {
  final file = ArchiveFile.bytes(name, bytes);
  final seconds = createdAt.millisecondsSinceEpoch ~/ 1000;
  file.creationTime = seconds;
  file.lastModTime = seconds;
  return file;
}

List<String> _referencedImagePaths(Map<String, Object> data) {
  final tables = data['tables']! as Map<String, Object>;
  final products = tables['products']! as List<Object>;
  final paths = <String>{
    for (final product in products)
      if ((product as Map<String, Object?>)['image_path']
          case final String path)
        path,
  }.toList()..sort();
  return paths;
}

void _requireSafeImagePath(String path) {
  final segments = path.split('/');
  final safe =
      path.startsWith('${ProductImageStore.directoryName}/') &&
      !path.contains('\\') &&
      !path.contains(':') &&
      !path.startsWith('/') &&
      segments.every(
        (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
      );
  if (!safe) {
    throw BackupCreationException('Unsafe product image path: $path');
  }
}

String _fileName(DateTime value) {
  String two(int part) => part.toString().padLeft(2, '0');
  return 'dakao-in-bill-${value.year}${two(value.month)}${two(value.day)}-'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}.dakbackup';
}
