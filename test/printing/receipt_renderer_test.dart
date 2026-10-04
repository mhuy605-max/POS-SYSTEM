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

  test('receipt typography uses the accepted MP-58N hierarchy', () {
    expect(ReceiptRenderer.shopNameFontSize, 30);
    expect(ReceiptRenderer.contactFontSize, 18.5);
    expect(ReceiptRenderer.orderHeadingFontSize, 25);
    expect(ReceiptRenderer.dateTimeFontSize, 17.5);
    expect(ReceiptRenderer.orderTypeFontSize, 18.5);
    expect(ReceiptRenderer.itemNameFontSize, 25);
    expect(ReceiptRenderer.itemPriceFontSize, 20);
    expect(ReceiptRenderer.itemNoteFontSize, 16);
    expect(ReceiptRenderer.grandTotalFontSize, 27);
    expect(ReceiptRenderer.footerFontSize, 18.5);
  });

  test(
    'long Vietnamese shop and address wrap inside printable width',
    () async {
      const renderer = ReceiptRenderer();
      final regular = await renderer.renderOrder(_order());
      final wrapped = await renderer.renderOrder(
        _order(
          shopName: 'Đakao In Bill Cơm Tấm Sườn Bì Chả Đặc Biệt',
          address: '123 Đường Nguyễn Văn Trỗi, Phường Phú Nhuận, Thành phố Hồ Chí Minh',
          phone: 'Điện thoại đặt món: 0900 000 000 — 028 1234 5678',
        ),
      );

      expect(wrapped.heightDots, greaterThan(regular.heightDots + 40));
      _expectPrintableMarginsClear(wrapped);
    },
  );

  test('long Vietnamese item names wrap inside the printable width', () async {
    const renderer = ReceiptRenderer();
    final short = await renderer.renderOrder(_order(productName: 'Cơm chả'));
    final wrapped = await renderer.renderOrder(
      _order(
        productName:
            'Cơm sườn bì chả đặc biệt thêm trứng ốp la và hành phi × phần lớn',
      ),
    );

    expect(wrapped.heightDots, greaterThan(short.heightDots + 20));
    _expectPrintableMarginsClear(wrapped);
  });

  test(
    'large VND item prices remain complete within printable width',
    () async {
      const renderer = ReceiptRenderer();
      final regular = await renderer.renderOrder(_order());
      final large = await renderer.renderOrder(
        _order(unitPrice: 999999999999999, quantity: 9),
      );

      expect(large.heightDots, greaterThan(regular.heightDots));
      _expectPrintableMarginsClear(large);
    },
  );

  test('large VND grand total uses a safe continuation line', () async {
    const renderer = ReceiptRenderer();
    final regular = await renderer.renderOrder(_order());
    final large = await renderer.renderOrder(_order(total: 999999999999999999));

    expect(large.heightDots, greaterThan(regular.heightDots + 20));
    _expectPrintableMarginsClear(large);
  });
}

SavedOrder _order({
  String productName = 'Cơm tấm Sườn Chả',
  int unitPrice = 95000,
  int quantity = 1,
  int? total,
  String shopName = 'Đakao',
  String address = '1 Đường Đinh Tiên Hoàng',
  String phone = '0900000000',
  String footer = 'Cảm ơn quý khách',
}) {
  final lineTotal = unitPrice * quantity;
  return SavedOrder(
    id: 7,
    orderNumber: 124,
    submissionToken: 'receipt-render',
    orderType: OrderType.takeaway,
    status: OrderStatus.paid,
    subtotal: lineTotal,
    total: total ?? lineTotal,
    createdAt: 1760000000000,
    paidAt: 1760000001000,
    cancelledAt: null,
    cancellationReason: null,
    receiptSettings: ReceiptSettingsSnapshot(
      version: 1,
      shopName: shopName,
      address: address,
      phone: phone,
      footer: footer,
    ),
    items: <SavedOrderItem>[
      SavedOrderItem(
        id: 1,
        productId: 3,
        productName: productName,
        unitPrice: unitPrice,
        quantity: quantity,
        note: 'Ít mỡ',
        lineTotal: lineTotal,
      ),
    ],
  );
}

void _expectPrintableMarginsClear(RenderedReceipt receipt) {
  const marginBytes = 2; // 16 dots on each side of a 384-dot receipt.
  final rowBytes = receipt.widthDots ~/ 8;
  var offset = 2; // ESC @
  for (final bandHeight in receipt.bandHeights) {
    expect(receipt.bytes.sublist(offset, offset + 4), [0x1d, 0x76, 0x30, 0x00]);
    offset += 8;
    for (var row = 0; row < bandHeight; row++) {
      final rowStart = offset + (row * rowBytes);
      expect(
        receipt.bytes.sublist(rowStart, rowStart + marginBytes),
        everyElement(0),
      );
      expect(
        receipt.bytes.sublist(
          rowStart + rowBytes - marginBytes,
          rowStart + rowBytes,
        ),
        everyElement(0),
      );
    }
    offset += rowBytes * bandHeight;
  }
}
