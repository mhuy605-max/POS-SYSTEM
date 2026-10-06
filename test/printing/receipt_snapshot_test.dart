import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/settings/shop_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'saved option and multiline footer snapshots render immutably',
    () async {
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
      final toppingGroupId = await options.createGroup('Topping');
      final eggId = await options.createOption(
        groupId: toppingGroupId,
        name: 'Trứng thêm',
        priceDelta: 30000,
      );
      await options.attachGroupToProduct(productId, groupId);
      await options.attachGroupToProduct(productId, toppingGroupId);
      await settings.save(
        const ShopSettingsDraft(
          shopName: 'Đakao',
          address: '',
          phone: '',
          receiptFooter: 'Cảm ơn quý khách\n\nHẹn gặp lại!',
        ),
      );

      final orderId = await orders.createOrder(
        OrderDraft(
          submissionToken: 'configured-receipt',
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
                  optionGroupId: toppingGroupId,
                  reviewedGroupName: 'Topping',
                  reviewedOptionName: 'Trứng thêm',
                  reviewedPriceDelta: 30000,
                ),
              ],
            ),
          ],
        ),
      );
      const renderer = ReceiptRenderer();
      final before = await orders.loadOrder(orderId);
      final beforeRaster = await renderer.renderOrder(before);

      await options.renameGroup(groupId, 'Nhóm mới');
      await options.updateOption(
        loinId,
        name: 'Sườn đổi tên',
        priceDelta: 99000,
      );
      await options.setOptionActive(eggId, false);
      await options.detachGroupFromProduct(productId, groupId);
      await options.detachGroupFromProduct(productId, toppingGroupId);
      await settings.save(
        const ShopSettingsDraft(
          shopName: 'Đakao mới',
          address: '',
          phone: '',
          receiptFooter: 'Footer mới',
        ),
      );

      final historical = await orders.loadOrder(orderId);
      final afterRaster = await renderer.renderOrder(historical);
      final item = historical.items.single;
      expect(item.baseUnitPrice, 35000);
      expect(item.unitPrice, 110000);
      expect(item.quantity, 2);
      expect(item.lineTotal, 220000);
      expect(historical.total, 220000);
      expect(item.options.map((option) => option.optionName), [
        'Sườn thêm',
        'Trứng thêm',
      ]);
      expect(item.options.map((option) => option.priceDelta), [45000, 30000]);
      expect(item.options.map((option) => option.displayOrder), [0, 1]);
      expect(item.options.map((option) => option.groupName), [
        'Món thêm',
        'Topping',
      ]);
      expect(
        historical.receiptSettings.footer,
        'Cảm ơn quý khách\n\nHẹn gặp lại!',
      );
      expect(historical.receiptSettings.shopName, 'Đakao');
      expect(afterRaster.bytes, beforeRaster.bytes);
      expect(afterRaster.widthDots, 384);
      expect(afterRaster.bytes.sublist(afterRaster.bytes.length - 3), [
        0x1b,
        0x64,
        0x04,
      ]);
    },
  );
}
