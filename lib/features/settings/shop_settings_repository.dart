import 'package:drift/drift.dart';

import '../../data/app_database.dart';

final class ShopSettings {
  const ShopSettings({
    required this.shopName,
    required this.address,
    required this.phone,
    required this.receiptFooter,
  });

  final String shopName;
  final String address;
  final String phone;
  final String receiptFooter;

  @override
  bool operator ==(Object other) =>
      other is ShopSettings &&
      other.shopName == shopName &&
      other.address == address &&
      other.phone == phone &&
      other.receiptFooter == receiptFooter;

  @override
  int get hashCode => Object.hash(shopName, address, phone, receiptFooter);
}

final class ShopSettingsDraft {
  const ShopSettingsDraft({
    required this.shopName,
    required this.address,
    required this.phone,
    required this.receiptFooter,
  });

  final String shopName;
  final String address;
  final String phone;
  final String receiptFooter;
}

final class ShopSettingsValidationException implements Exception {
  const ShopSettingsValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ShopSettingsRepository {
  const ShopSettingsRepository(this._database);

  final AppDatabase _database;

  Future<ShopSettings> load() => _query().getSingle().then(_map);

  Stream<ShopSettings> watch() => _query().watchSingle().map(_map);

  Future<void> save(ShopSettingsDraft draft) async {
    final shopName = draft.shopName.trim();
    if (shopName.isEmpty) {
      throw const ShopSettingsValidationException(
        'Tên trên bill không được để trống.',
      );
    }
    await (_database.update(
      _database.appSettings,
    )..where((row) => row.id.equals(1))).write(
      AppSettingsCompanion(
        shopName: Value(shopName),
        address: Value(draft.address.trim()),
        phone: Value(draft.phone.trim()),
        receiptFooter: Value(draft.receiptFooter.trim()),
      ),
    );
  }

  SimpleSelectStatement<$AppSettingsTable, AppSetting> _query() =>
      _database.select(_database.appSettings)..where((row) => row.id.equals(1));

  ShopSettings _map(AppSetting row) => ShopSettings(
    shopName: row.shopName,
    address: row.address,
    phone: row.phone,
    receiptFooter: row.receiptFooter,
  );
}
