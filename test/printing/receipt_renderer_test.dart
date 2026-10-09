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
    expect(ReceiptRenderer.itemOptionFontSize, 17.5);
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

  test('zero-option V1 receipt remains byte-for-byte unchanged', () async {
    const renderer = ReceiptRenderer();
    final legacy = await renderer.renderOrder(_order());
    final explicit = await renderer.renderOrder(
      _order(baseUnitPrice: 95000, options: const []),
    );

    expect(explicit.bytes, legacy.bytes);
    expect(explicit.heightDots, legacy.heightDots);
  });

  test(
    'configured receipt renders base and historical option detail rows',
    () async {
      const renderer = ReceiptRenderer();
      final zero = await renderer.renderOrder(
        _order(unitPrice: 35000, baseUnitPrice: 35000, note: null),
      );
      final one = await renderer.renderOrder(
        _order(
          unitPrice: 80000,
          baseUnitPrice: 35000,
          note: null,
          options: const [
            SavedOrderOption(
              id: 1,
              optionItemId: 10,
              groupName: 'Món thêm',
              optionName: 'Sườn thêm',
              priceDelta: 45000,
              displayOrder: 0,
            ),
          ],
        ),
      );
      final multiple = await renderer.renderOrder(_configuredOrder());

      expect(one.heightDots, greaterThan(zero.heightDots + 20));
      expect(multiple.heightDots, greaterThan(one.heightDots + 20));
      _expectPrintableMarginsClear(one);
      _expectPrintableMarginsClear(multiple);
    },
  );

  test('zero-price and long Vietnamese option names render safely', () async {
    const renderer = ReceiptRenderer();
    final short = await renderer.renderOrder(
      _order(
        unitPrice: 35000,
        baseUnitPrice: 35000,
        note: null,
        options: const [
          SavedOrderOption(
            id: 1,
            optionItemId: 10,
            groupName: 'Topping',
            optionName: 'Hành phi',
            priceDelta: 0,
            displayOrder: 0,
          ),
        ],
      ),
    );
    final long = await renderer.renderOrder(
      _order(
        unitPrice: 35000,
        baseUnitPrice: 35000,
        note: null,
        options: const [
          SavedOrderOption(
            id: 1,
            optionItemId: 10,
            groupName: 'Topping',
            optionName:
                'Hành phi giòn đặc biệt kèm mỡ hành và nước sốt nhà làm',
            priceDelta: 0,
            displayOrder: 0,
          ),
        ],
      ),
    );

    expect(long.heightDots, greaterThan(short.heightDots));
    _expectPrintableMarginsClear(long);
  });

  test(
    'quantity two keeps configured unit and line totals deterministic',
    () async {
      const renderer = ReceiptRenderer();
      final once = await renderer.renderOrder(_configuredOrder(quantity: 1));
      final twice = await renderer.renderOrder(_configuredOrder(quantity: 2));

      expect(once.bytes, isNot(twice.bytes));
      expect(once.widthDots, 384);
      expect(twice.widthDots, 384);
      _expectPrintableMarginsClear(twice);
    },
  );

  test('LF, CRLF and bare CR footer endings normalize identically', () async {
    const renderer = ReceiptRenderer();
    final single = await renderer.renderOrder(_order(footer: 'cảm ơn'));
    final lf = await renderer.renderOrder(
      _order(footer: 'cảm ơn\nhẹn gặp lại'),
    );
    final crlf = await renderer.renderOrder(
      _order(footer: 'cảm ơn\r\nhẹn gặp lại'),
    );
    final cr = await renderer.renderOrder(
      _order(footer: 'cảm ơn\rhẹn gặp lại'),
    );

    expect(lf.heightDots, greaterThan(single.heightDots + 10));
    expect(crlf.bytes, lf.bytes);
    expect(cr.bytes, lf.bytes);
    _expectPrintableMarginsClear(lf);
  });

  test('footer preserves internal blank lines and all later lines', () async {
    const renderer = ReceiptRenderer();
    final two = await renderer.renderOrder(
      _order(footer: 'Cảm ơn quý khách\nHẹn gặp lại!'),
    );
    final blank = await renderer.renderOrder(
      _order(footer: 'Cảm ơn quý khách\n\nHẹn gặp lại!'),
    );
    final three = await renderer.renderOrder(
      _order(footer: 'Dòng một\nDòng hai\nDòng ba'),
    );

    expect(blank.heightDots, greaterThan(two.heightDots + 20));
    expect(three.heightDots, greaterThan(two.heightDots + 10));
    expect(blank.bytes, isNot(two.bytes));
    _expectPrintableMarginsClear(blank);
    _expectPrintableMarginsClear(three);
  });

  test(
    'long Vietnamese footer wraps and final feed follows all raster bands',
    () async {
      const renderer = ReceiptRenderer();
      final short = await renderer.renderOrder(_order(footer: 'Cảm ơn'));
      final long = await renderer.renderOrder(
        _order(
          footer:
              'Cảm ơn quý khách đã ghé Đakao, kính chúc quý khách ngon miệng '
              'và hẹn gặp lại trong lần sau!',
        ),
      );

      expect(long.heightDots, greaterThan(short.heightDots + 20));
      expect(long.bytes.sublist(long.bytes.length - 3), [0x1b, 0x64, 0x06]);
      _expectPrintableMarginsClear(long);
    },
  );

  test(
    'configured receipt with blank-line footer is safe at 384 dots',
    () async {
      const renderer = ReceiptRenderer();
      final receipt = await renderer.renderOrder(
        _configuredOrder(
          quantity: 2,
          footer: 'Cảm ơn quý khách\n\nHẹn gặp lại!',
        ),
      );

      expect(receipt.widthDots, 384);
      expect(receipt.bandHeights.every((height) => height <= 160), isTrue);
      expect(receipt.bytes.sublist(receipt.bytes.length - 3), [
        0x1b,
        0x64,
        0x06,
      ]);
      _expectPrintableMarginsClear(receipt);
    },
  );

  test(
    'zero-option and option receipts share one complete six-line final feed',
    () async {
      const renderer = ReceiptRenderer();
      const footer = 'Cảm ơn quý khách\n\nHẹn gặp lại!';
      final zeroOption = await renderer.renderOrder(_order(footer: footer));
      final withOptions = await renderer.renderOrder(
        _configuredOrder(footer: footer),
      );

      _expectRasterEndsWithFeed(zeroOption, lines: 6);
      _expectRasterEndsWithFeed(withOptions, lines: 6);
      expect(
        zeroOption.bytes.sublist(zeroOption.bytes.length - 3),
        withOptions.bytes.sublist(withOptions.bytes.length - 3),
      );
    },
  );
}

SavedOrder _order({
  String productName = 'Cơm tấm Sườn Chả',
  int unitPrice = 95000,
  int? baseUnitPrice,
  int quantity = 1,
  int? total,
  String shopName = 'Đakao',
  String address = '1 Đường Đinh Tiên Hoàng',
  String phone = '0900000000',
  String footer = 'Cảm ơn quý khách',
  String? note = 'Ít mỡ',
  List<SavedOrderOption> options = const [],
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
        baseUnitPrice: baseUnitPrice,
        unitPrice: unitPrice,
        quantity: quantity,
        note: note,
        lineTotal: lineTotal,
        options: options,
      ),
    ],
  );
}

SavedOrder _configuredOrder({
  int quantity = 1,
  String footer = 'Cảm ơn quý khách',
}) => _order(
  productName: 'Cơm sườn',
  baseUnitPrice: 35000,
  unitPrice: 110000,
  quantity: quantity,
  footer: footer,
  note: null,
  options: const [
    SavedOrderOption(
      id: 1,
      optionItemId: 10,
      groupName: 'Món thêm',
      optionName: 'Sườn thêm',
      priceDelta: 45000,
      displayOrder: 0,
    ),
    SavedOrderOption(
      id: 2,
      optionItemId: 11,
      groupName: 'Món thêm',
      optionName: 'Trứng thêm',
      priceDelta: 30000,
      displayOrder: 1,
    ),
  ],
);

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

void _expectRasterEndsWithFeed(RenderedReceipt receipt, {required int lines}) {
  final rowBytes = (receipt.widthDots + 7) ~/ 8;
  var offset = 2; // ESC @
  for (final bandHeight in receipt.bandHeights) {
    expect(receipt.bytes.sublist(offset, offset + 4), [0x1d, 0x76, 0x30, 0x00]);
    final encodedRowBytes =
        receipt.bytes[offset + 4] | (receipt.bytes[offset + 5] << 8);
    final encodedHeight =
        receipt.bytes[offset + 6] | (receipt.bytes[offset + 7] << 8);
    expect(encodedRowBytes, rowBytes);
    expect(encodedHeight, bandHeight);
    offset += 8 + (rowBytes * bandHeight);
  }

  expect(offset, receipt.bytes.length - 3);
  expect(receipt.bytes.sublist(offset), [0x1b, 0x64, lines]);
}
