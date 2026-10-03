import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../data/app_database.dart';
import '../features/products/product_image_store.dart';
import 'backup_data_codec.dart';
import 'backup_models.dart';

enum RestoreCheckpoint {
  beforeDatabaseReplacement,
  afterDatabaseReplacement,
  beforeImagesPrepared,
  afterLiveImagesMovedAside,
  afterJournalRetired,
}

abstract interface class BackupRestorer {
  Future<void> replaceWith(ValidatedBackup backup);
}

final class RestoreService implements BackupRestorer {
  const RestoreService({
    required AppDatabase database,
    required ProductImageStore imageStore,
    required Directory journalDirectory,
    void Function(RestoreCheckpoint)? checkpoint,
    bool recoverOnFailure = true,
  }) : this._(
         database,
         imageStore,
         journalDirectory,
         checkpoint,
         recoverOnFailure,
       );

  const RestoreService._(
    this._database,
    this._imageStore,
    this._journalDirectory,
    this._checkpoint,
    this._recoverOnFailure,
  );

  final AppDatabase _database;
  final ProductImageStore _imageStore;
  final Directory _journalDirectory;
  final void Function(RestoreCheckpoint)? _checkpoint;
  final bool _recoverOnFailure;

  File get _marker =>
      File('${_journalDirectory.path}${Platform.pathSeparator}marker.json');
  File get _oldData =>
      File('${_journalDirectory.path}${Platform.pathSeparator}old-data.json');
  File get _targetData => File(
    '${_journalDirectory.path}${Platform.pathSeparator}target-data.json',
  );
  Directory get _oldImages =>
      Directory('${_journalDirectory.path}${Platform.pathSeparator}old-images');
  Directory get _targetImages => Directory(
    '${_journalDirectory.path}${Platform.pathSeparator}target-images',
  );

  @override
  Future<void> replaceWith(ValidatedBackup backup) async {
    await recoverPendingRestore();
    try {
      await _prepareJournal(backup);
      _checkpoint?.call(RestoreCheckpoint.beforeDatabaseReplacement);
      await BackupDataCodec(_database)
          .replaceWithCanonical(backup.canonicalData);
      _checkpoint?.call(RestoreCheckpoint.afterDatabaseReplacement);
      await _activateImages(_targetImages);
      await _retireJournal();
    } catch (_) {
      if (_recoverOnFailure) {
        if (await _marker.exists()) {
          await recoverPendingRestore();
        } else {
          await _clearJournal();
        }
      }
      rethrow;
    }
  }

  Future<void> recoverPendingRestore() async {
    if (!await _marker.exists()) {
      await _clearInactiveJournal();
      await _clearInactiveImageSwap();
      return;
    }
    final markerValue = jsonDecode(await _marker.readAsString());
    if (markerValue is! Map<String, Object?> ||
        markerValue['target_data_sha256'] is! String ||
        !await _oldData.exists() ||
        !await _targetData.exists()) {
      throw const FileSystemException('Restore recovery journal is invalid.');
    }
    final live = await BackupDataCodec(_database).exportCanonical();
    final liveHash = sha256.convert(live).toString();
    if (liveHash == markerValue['target_data_sha256']) {
      try {
        await _activateImages(_targetImages);
      } catch (_) {
        await BackupDataCodec(_database)
            .replaceWithCanonical(await _oldData.readAsBytes());
        await _restoreOldImagesAfterFailedActivation();
      }
    } else {
      await BackupDataCodec(_database)
          .replaceWithCanonical(await _oldData.readAsBytes());
      await _activateImages(_oldImages);
    }
    await _retireJournal();
  }

  Future<void> _prepareJournal(ValidatedBackup backup) async {
    await _clearJournal();
    await _journalDirectory.create(recursive: true);
    final oldCanonical = await BackupDataCodec(_database).exportCanonical();
    await _oldData.writeAsBytes(oldCanonical, flush: true);
    await _targetData.writeAsBytes(backup.canonicalData, flush: true);
    await _copyLiveImages(_oldImages);
    await _writeTargetImages(backup.images);
    final markerTemp = File('${_marker.path}.tmp');
    await markerTemp.writeAsString(
      jsonEncode(<String, Object>{
        'version': 1,
        'target_data_sha256': sha256.convert(backup.canonicalData).toString(),
      }),
      flush: true,
    );
    await markerTemp.rename(_marker.path);
  }

  Future<void> _copyLiveImages(Directory destinationRoot) async {
    final live = Directory(
      '${_imageStore.rootDirectory.path}${Platform.pathSeparator}'
      '${ProductImageStore.directoryName}',
    );
    final target = Directory(
      '${destinationRoot.path}${Platform.pathSeparator}'
      '${ProductImageStore.directoryName}',
    );
    if (await live.exists()) await _copyDirectory(live, target);
  }

  Future<void> _writeTargetImages(Map<String, Uint8List> images) async {
    for (final entry in images.entries) {
      final path = entry.key.replaceAll('/', Platform.pathSeparator);
      final file = File('${_targetImages.path}${Platform.pathSeparator}$path');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
  }

  Future<void> _activateImages(
    Directory stagedRoot, {
    bool runCheckpoint = true,
  }) async {
    final live = Directory(
      '${_imageStore.rootDirectory.path}${Platform.pathSeparator}'
      '${ProductImageStore.directoryName}',
    );
    final staged = Directory(
      '${stagedRoot.path}${Platform.pathSeparator}'
      '${ProductImageStore.directoryName}',
    );
    final incoming = Directory('${live.path}.restore-incoming');
    final previous = Directory('${live.path}.restore-previous');
    await _rollbackInterruptedImageSwap(live, incoming, previous);
    if (runCheckpoint) {
      _checkpoint?.call(RestoreCheckpoint.beforeImagesPrepared);
    }
    if (await staged.exists()) {
      await _copyDirectory(staged, incoming);
    } else {
      await incoming.create(recursive: true);
    }
    if (await live.exists()) await live.rename(previous.path);
    try {
      if (runCheckpoint) {
        _checkpoint?.call(RestoreCheckpoint.afterLiveImagesMovedAside);
      }
      await incoming.rename(live.path);
    } catch (_) {
      if (await incoming.exists()) await incoming.delete(recursive: true);
      if (await previous.exists() && !await live.exists()) {
        await previous.rename(live.path);
      }
      rethrow;
    }
  }

  Future<void> _restoreOldImagesAfterFailedActivation() async {
    await _activateImages(_oldImages, runCheckpoint: false);
  }

  Future<void> _rollbackInterruptedImageSwap(
    Directory live,
    Directory incoming,
    Directory previous,
  ) async {
    if (await previous.exists()) {
      if (await live.exists()) await live.delete(recursive: true);
      await previous.rename(live.path);
    }
    if (await incoming.exists()) await incoming.delete(recursive: true);
  }

  Future<void> _retireJournal() async {
    if (!await _marker.exists()) {
      await _clearInactiveJournal();
      await _clearInactiveImageSwap();
      return;
    }
    final retired = File('${_marker.path}.retired');
    if (await retired.exists()) await retired.delete();
    await _marker.rename(retired.path);
    _checkpoint?.call(RestoreCheckpoint.afterJournalRetired);
    await _clearInactiveJournal();
    await _clearInactiveImageSwap();
  }

  Future<void> _clearInactiveImageSwap() async {
    final live = Directory(
      '${_imageStore.rootDirectory.path}${Platform.pathSeparator}'
      '${ProductImageStore.directoryName}',
    );
    for (final suffix in const ['.restore-incoming', '.restore-previous']) {
      final directory = Directory('${live.path}$suffix');
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  Future<void> _clearInactiveJournal() async {
    if (await _journalDirectory.exists()) {
      await _journalDirectory.delete(recursive: true);
    }
  }

  Future<void> _clearJournal() async {
    if (await _marker.exists()) {
      throw const FileSystemException(
        'Cannot clear an active restore recovery journal.',
      );
    }
    await _clearInactiveJournal();
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relative = entity.path
        .substring(source.path.length)
        .replaceFirst(RegExp(r'^[\\/]'), '');
    final targetPath = '${destination.path}${Platform.pathSeparator}$relative';
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
    } else if (entity is File) {
      final target = File(targetPath);
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }
}
