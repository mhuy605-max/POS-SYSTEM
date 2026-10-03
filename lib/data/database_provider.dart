import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('AppDatabase must be provided at application startup.');
});

Future<AppDatabase> openProductionDatabase() async {
  final root = await getApplicationSupportDirectory();
  final databaseDirectory = Directory(
    '${root.path}${Platform.pathSeparator}data',
  );
  await databaseDirectory.create(recursive: true);
  return AppDatabase.openFile(
    File('${databaseDirectory.path}${Platform.pathSeparator}dakao.sqlite'),
  );
}
