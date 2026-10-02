import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/receipt_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Vietnamese receipt raster is deterministic and 384 dots wide',
    () async {
      const renderer = ReceiptRenderer();
      final order = _order();

      final first = await renderer.renderOrder(order);
      final second = await renderer.renderOrder(order);

      expect(first.widthDots, 384);
      expect(first.heightDots, greaterThan(0));
      expect(first.bytes, isNotEmpty);
      expect(first.bytes, second.bytes);
      expect(first.bandHeights, isNotEmpty);
      expect(first.bandHeights.every((height) => height <= 160), isTrue);
      expect(first.bytes, containsAllInOrder(<int>[0x1d, 0x76, 0x30]));
    },
  );

  test('test page is distinct from an order receipt', () async {
    const renderer = ReceiptRenderer();

    final receipt = await renderer.renderOrder(_order());
    final testPage = await renderer.renderTestPage();

    expect(testPage.widthDots, 384);
    expect(testPage.bytes, isNot(receipt.bytes));
    expect(testPage.bytes, isNotEmpty);
  });
}

SavedOrder _order() => const SavedOrder(
  id: 7,
  orderNumber: 124,
  submissionToken: 'receipt-render',
  orderType: OrderType.takeaway,
  status: OrderStatus.paid,
  subtotal: 95000,
  total: 95000,
  createdAt: 1760000000000,
  paidAt: 1760000001000,
  cancelledAt: null,
  cancellationReason: null,
  receiptSettings: ReceiptSettingsSnapshot(
    version: 1,
    shopName: 'Đakao',
    address: '1 Đường Đinh Tiên Hoàng',
    phone: '0900000000',
    footer: 'Cảm ơn quý khách',
  ),
  items: <SavedOrderItem>[
    SavedOrderItem(
      id: 1,
      productId: 3,
      productName: 'Cơm tấm Sườn Chả',
      unitPrice: 95000,
      quantity: 1,
      note: 'Ít mỡ',
      lineTotal: 95000,
    ),
  ],
);
