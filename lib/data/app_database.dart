import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Categories,
    Products,
    Orders,
    OrderItems,
    PrintAttempts,
    AppSettings,
    PrinterSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.openFile(File file) {
    return AppDatabase(
      NativeDatabase(
        file,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(appSettings).insert(const AppSettingsCompanion());
      await into(printerSettings).insert(const PrinterSettingsCompanion());
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
