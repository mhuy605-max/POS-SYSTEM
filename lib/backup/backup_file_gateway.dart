import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

final class PickedBackup {
  const PickedBackup({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class BackupFileGateway {
  Future<bool> saveBackup(StagedFile file);

  Future<PickedBackup?> pickBackup();
}

final class StagedFile {
  const StagedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

final class AndroidDocumentBackupFileGateway implements BackupFileGateway {
  const AndroidDocumentBackupFileGateway();

  @override
  Future<bool> saveBackup(StagedFile file) async {
    final result = await FilePicker.saveFile(
      fileName: file.name,
      bytes: file.bytes,
      mimeType: 'application/octet-stream',
      dialogTitle: 'Lưu bản sao lưu Đakao In Bill',
    );
    return result != null;
  }

  @override
  Future<PickedBackup?> pickBackup() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Chọn bản sao lưu Đakao In Bill',
      type: FileType.custom,
      allowedExtensions: const ['dakbackup'],
    );
    if (picked == null) return null;
    return PickedBackup(name: picked.name, bytes: await picked.readAsBytes());
  }
}
