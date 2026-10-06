import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/settings/shop_settings_repository.dart';
import 'package:dakao_in_bill/features/settings/shop_settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Checkpoint 7 saved receipt renders historically on Android', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final products = ProductRepository(database, () => 1000);
    final options = ProductOptionRepository(database, () => 1000);
    final orders = OrderRepository(
      database,
      nowEpochMillis: () => 2000,
      productOptionRepository: options,
    );
    final settings = ShopSettingsRepository(database);
    const footer = 'Cảm ơn quý khách\n\nHẹn gặp lại!';
    await settings.save(
      const ShopSettingsDraft(
        shopName: 'Đakao',
        address: 'Đakao, TP.HCM',
        phone: '0900000000',
        receiptFooter: footer,
      ),
    );

    // Exercise the existing in-app settings preview with the multiline value.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ShopSettingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(footer), findsWidgets);
    expect(tester.takeException(), isNull);

    final categoryId = await products.createCategory('Cơm');
    final productId = await products.createProduct(
      ProductDraft(categoryId: categoryId, name: 'Cơm sườn', price: 35000),
    );
    final groupId = await options.createGroup('Món thêm');
    final loinId = await options.createOption(
      groupId: groupId,
      name: 'Sườn thêm',
      priceDelta: 45000,
    );
    final eggId = await options.createOption(
      groupId: groupId,
      name: 'Trứng thêm',
      priceDelta: 30000,
    );
    await options.attachGroupToProduct(productId, groupId);
    final orderId = await orders.createOrder(
      OrderDraft(
        submissionToken: 'checkpoint7-android',
        lines: [
          DraftLine(
            productId: productId,
            reviewedName: 'Cơm sườn',
            reviewedBaseUnitPrice: 35000,
            reviewedUnitPrice: 110000,
            quantity: 2,
            selectedOptions: [
              DraftSelectedOption(
                optionItemId: loinId,
                optionGroupId: groupId,
                reviewedGroupName: 'Món thêm',
                reviewedOptionName: 'Sườn thêm',
                reviewedPriceDelta: 45000,
              ),
              DraftSelectedOption(
                optionItemId: eggId,
                optionGroupId: groupId,
                reviewedGroupName: 'Món thêm',
                reviewedOptionName: 'Trứng thêm',
                reviewedPriceDelta: 30000,
              ),
            ],
          ),
        ],
      ),
    );
    const renderer = ReceiptRenderer();
    final saved = await orders.loadOrder(orderId);
    final first = await renderer.renderOrder(saved);

    await options.updateOption(loinId, name: 'Tên mới', priceDelta: 99000);
    await options.setOptionActive(eggId, false);
    await options.detachGroupFromProduct(productId, groupId);
    await settings.save(
      const ShopSettingsDraft(
        shopName: 'Đakao mới',
        address: '',
        phone: '',
        receiptFooter: 'Footer mới',
      ),
    );

    final historical = await orders.loadOrder(orderId);
    final second = await renderer.renderOrder(historical);
    expect(historical.items.single.lineTotal, 220000);
    expect(historical.items.single.options.map((option) => option.optionName), [
      'Sườn thêm',
      'Trứng thêm',
    ]);
    expect(historical.receiptSettings.footer, footer);
    expect(second.bytes, first.bytes);
    expect(second.widthDots, 384);
    expect(second.bandHeights.every((height) => height <= 160), true);
    expect(second.bytes.sublist(second.bytes.length - 3), [0x1b, 0x64, 0x06]);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
