import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import 'printer_models.dart';

final class PrinterSettingsRepository {
  const PrinterSettingsRepository(this._database);

  final AppDatabase _database;

  Future<SavedPrinterSettings> load() async {
    final row = await (_database.select(
      _database.printerSettings,
    )..where((item) => item.id.equals(1))).getSingle();
    return SavedPrinterSettings(
      printerName: row.printerName,
      printerAddress: row.printerAddress,
      autoReconnect: row.autoReconnect,
    );
  }

  Future<void> saveSelected(PrinterDevice device) {
    return (_database.update(
      _database.printerSettings,
    )..where((row) => row.id.equals(1))).write(
      PrinterSettingsCompanion(
        printerName: Value(device.name),
        printerAddress: Value(device.address),
      ),
    );
  }

  Future<void> clearSelected() {
    return (_database.update(
      _database.printerSettings,
    )..where((row) => row.id.equals(1))).write(
      const PrinterSettingsCompanion(
        printerName: Value(null),
        printerAddress: Value(null),
      ),
    );
  }
}
