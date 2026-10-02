import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'backup/backup_providers.dart';
import 'backup/restore_service.dart';
import 'data/database_provider.dart';
import 'features/products/product_image_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openProductionDatabase();
  final support = await getApplicationSupportDirectory();
  final restoreService = RestoreService(
    database: database,
    imageStore: ProductImageStore(support),
    journalDirectory: Directory(
      '${support.path}${Platform.pathSeparator}.restore-recovery',
    ),
  );
  await restoreService.recoverPendingRestore();
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        restoreServiceProvider.overrideWithValue(restoreService),
      ],
      child: const DakaoInBillApp(),
    ),
  );
}
