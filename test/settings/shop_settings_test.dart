import 'dart:io';

import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/settings/shop_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late File databaseFile;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dakao-settings-');
    databaseFile = File('${root.path}${Platform.pathSeparator}settings.sqlite');
    database = AppDatabase.openFile(databaseFile);
  });

  tearDown(() async {
    await database.close();
    await root.delete(recursive: true);
  });

  test('shop settings are trimmed and persist after database reopen', () async {
    final repository = ShopSettingsRepository(database);

    await repository.save(
      const ShopSettingsDraft(
        shopName: '  Đakao In Bill  ',
        address: '  42 Đinh Tiên Hoàng  ',
        phone: '  0908 123 456  ',
        receiptFooter: '  Cảm ơn quý khách!  ',
      ),
    );
    await database.close();
    database = AppDatabase.openFile(databaseFile);

    expect(
      await ShopSettingsRepository(database).load(),
      const ShopSettings(
        shopName: 'Đakao In Bill',
        address: '42 Đinh Tiên Hoàng',
        phone: '0908 123 456',
        receiptFooter: 'Cảm ơn quý khách!',
      ),
    );
  });

  test('blank shop name is rejected without changing saved settings', () async {
    final repository = ShopSettingsRepository(database);
    await repository.save(
      const ShopSettingsDraft(
        shopName: 'Đakao',
        address: '',
        phone: '',
        receiptFooter: '',
      ),
    );

    await expectLater(
      repository.save(
        const ShopSettingsDraft(
          shopName: '   ',
          address: 'A',
          phone: '1',
          receiptFooter: 'F',
        ),
      ),
      throwsA(isA<ShopSettingsValidationException>()),
    );
    expect((await repository.load()).shopName, 'Đakao');
  });

  test(
    'updated settings affect new orders but never old receipt snapshots',
    () async {
      final settings = ShopSettingsRepository(database);
      await settings.save(
        const ShopSettingsDraft(
          shopName: 'Đakao cũ',
          address: 'Địa chỉ cũ',
          phone: '0900',
          receiptFooter: 'Lời cũ',
        ),
      );
      final categoryId = await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(name: 'Món', createdAt: 1, updatedAt: 1),
          );
      final productId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              categoryId: categoryId,
              name: 'Cơm tấm',
              price: 45000,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final orders = OrderRepository(database, nowEpochMillis: () => 1000);
      final oldId = await orders.createOrder(_draft('old-order', productId));
      final oldJson = await _snapshot(database, oldId);

      await settings.save(
        const ShopSettingsDraft(
          shopName: 'Đakao mới',
          address: 'Địa chỉ mới',
          phone: '0911',
          receiptFooter: 'Lời mới',
        ),
      );
      final newId = await orders.createOrder(_draft('new-order', productId));

      expect(await _snapshot(database, oldId), oldJson);
      expect(
        (await orders.loadOrder(oldId)).receiptSettings.shopName,
        'Đakao cũ',
      );
      final newSnapshot = (await orders.loadOrder(newId)).receiptSettings;
      expect(newSnapshot.shopName, 'Đakao mới');
      expect(newSnapshot.address, 'Địa chỉ mới');
      expect(newSnapshot.phone, '0911');
      expect(newSnapshot.footer, 'Lời mới');
    },
  );
}

OrderDraft _draft(String token, int productId) => OrderDraft(
  submissionToken: token,
  lines: <DraftLine>[
    DraftLine(
      productId: productId,
      reviewedName: 'Cơm tấm',
      reviewedUnitPrice: 45000,
      quantity: 1,
    ),
  ],
);

Future<String> _snapshot(AppDatabase database, int orderId) async {
  final row = await (database.select(
    database.orders,
  )..where((order) => order.id.equals(orderId))).getSingle();
  return row.receiptSettingsSnapshot;
}
