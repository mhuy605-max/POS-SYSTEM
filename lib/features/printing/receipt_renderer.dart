import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../orders/order_repository.dart';

final class RenderedReceipt {
  const RenderedReceipt({
    required this.bytes,
    required this.widthDots,
    required this.heightDots,
    required this.bandHeights,
  });

  final Uint8List bytes;
  final int widthDots;
  final int heightDots;
  final List<int> bandHeights;
}

class ReceiptRenderer {
  const ReceiptRenderer({this.widthDots = 384, this.maxBandHeight = 160});

  static const shopNameFontSize = 30.0;
  static const contactFontSize = 18.5;
  static const orderHeadingFontSize = 25.0;
  static const dateTimeFontSize = 17.5;
  static const orderTypeFontSize = 18.5;
  static const itemNameFontSize = 25.0;
  static const itemPriceFontSize = 20.0;
  static const itemOptionFontSize = 17.5;
  static const itemNoteFontSize = 16.0;
  static const grandTotalFontSize = 27.0;
  static const footerFontSize = 18.5;

  final int widthDots;
  final int maxBandHeight;

  Future<RenderedReceipt> renderOrder(SavedOrder order) {
    final settings = order.receiptSettings;
    final footerBlocks = _footerBlocks(settings.footer);
    final blocks = <_ReceiptBlock>[
      _ReceiptBlock(
        settings.shopName,
        shopNameFontSize,
        FontWeight.w800,
        centered: true,
      ),
      if (settings.address.isNotEmpty)
        _ReceiptBlock(
          settings.address,
          contactFontSize,
          FontWeight.w500,
          centered: true,
        ),
      if (settings.phone.isNotEmpty)
        _ReceiptBlock(
          settings.phone,
          contactFontSize,
          FontWeight.w500,
          centered: true,
        ),
      const _ReceiptBlock.separator(),
      _ReceiptBlock(
        'ĐƠN #${order.orderNumber.toString().padLeft(4, '0')}',
        orderHeadingFontSize,
        FontWeight.w800,
        centered: true,
      ),
      _ReceiptBlock(
        _dateTime(order.createdAt),
        dateTimeFontSize,
        FontWeight.w500,
        centered: true,
      ),
      if (order.orderType != null)
        _ReceiptBlock(
          order.orderType == OrderType.dineIn ? 'Tại quán' : 'Mang về',
          orderTypeFontSize,
          FontWeight.w700,
          centered: true,
        ),
      const _ReceiptBlock.separator(),
      for (final item in order.items) ...[
        _ReceiptBlock(
          '${item.productName} ×${item.quantity}',
          itemNameFontSize,
          FontWeight.w700,
        ),
        _ReceiptBlock.price(
          '${formatVnd(item.unitPrice)} / phần',
          formatVnd(item.lineTotal),
          itemPriceFontSize,
          FontWeight.w500,
        ),
        if (item.options.isNotEmpty) ...[
          _ReceiptBlock.price(
            '  Cơ bản',
            _detailPrice(item.baseUnitPrice, item.quantity),
            itemOptionFontSize,
            FontWeight.w500,
          ),
          for (final option in item.options)
            _ReceiptBlock.price(
              '  + ${option.optionName}',
              _detailPrice(option.priceDelta, item.quantity),
              itemOptionFontSize,
              FontWeight.w500,
            ),
        ],
        if (item.note != null && item.note!.trim().isNotEmpty)
          _ReceiptBlock(
            'Ghi chú: ${item.note}',
            itemNoteFontSize,
            FontWeight.w500,
          ),
      ],
      const _ReceiptBlock.separator(),
      _ReceiptBlock.price(
        'TỔNG CỘNG:',
        formatVnd(order.total),
        grandTotalFontSize,
        FontWeight.w800,
      ),
      if (footerBlocks.isNotEmpty) ...[
        const _ReceiptBlock.separator(),
        ...footerBlocks,
      ],
    ];
    return _render(blocks);
  }

  Future<RenderedReceipt> renderTestPage() => _render(const <_ReceiptBlock>[
    _ReceiptBlock('ĐAKAO IN BILL', 25, FontWeight.w800, centered: true),
    _ReceiptBlock.separator(),
    _ReceiptBlock('TRANG KIỂM TRA MÁY IN', 19, FontWeight.w800, centered: true),
    _ReceiptBlock(
      'Đakao • Cơm tấm • Sườn • Chả',
      16,
      FontWeight.w600,
      centered: true,
    ),
    _ReceiptBlock(
      'Đây không phải hóa đơn bán hàng.',
      15,
      FontWeight.w500,
      centered: true,
    ),
  ]);

  Future<RenderedReceipt> _render(List<_ReceiptBlock> blocks) async {
    const separatorMargin = 16.0;
    const textMargin = 18.0;
    const verticalPadding = 14.0;
    const priceColumnGap = 12.0;
    const stackedPriceGap = 3.0;
    final availableWidth = widthDots - (textMargin * 2);
    final layouts = <_ReceiptBlockLayout?>[];
    var height = verticalPadding;
    for (final block in blocks) {
      if (block.separator) {
        layouts.add(null);
        height += 18;
        continue;
      }
      if (block.spacerHeight != null) {
        layouts.add(null);
        height += block.spacerHeight!;
        continue;
      }
      final left = _painter(block.text, block);
      final rightText = block.rightText;
      if (rightText == null) {
        left.layout(maxWidth: availableWidth);
        final layout = _ReceiptBlockLayout(left: left);
        layouts.add(layout);
        height += layout.height + 7;
        continue;
      }

      final right = _painter(rightText, block, textAlign: TextAlign.right);
      left.layout();
      right.layout();
      final stacked =
          left.width + right.width + priceColumnGap > availableWidth;
      if (stacked) {
        left.layout(maxWidth: availableWidth);
        right.layout(minWidth: availableWidth, maxWidth: availableWidth);
      }
      final layout = _ReceiptBlockLayout(
        left: left,
        right: right,
        stacked: stacked,
        stackedGap: stackedPriceGap,
      );
      layouts.add(layout);
      height += layout.height + 7;
    }
    height += verticalPadding;
    final imageHeight = height.ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    var y = verticalPadding;
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final layout = layouts[index];
      if (block.separator) {
        canvas.drawLine(
          Offset(separatorMargin, y + 6),
          Offset(widthDots - separatorMargin, y + 6),
          Paint()..color = Colors.black,
        );
        y += 18;
        continue;
      }
      if (block.spacerHeight != null) {
        y += block.spacerHeight!;
        continue;
      }
      final left = layout!.left;
      if (layout.right == null) {
        final x = block.centered ? (widthDots - left.width) / 2 : textMargin;
        left.paint(canvas, Offset(x, y));
      } else if (layout.stacked) {
        left.paint(canvas, Offset(textMargin, y));
        layout.right!.paint(
          canvas,
          Offset(textMargin, y + left.height + layout.stackedGap),
        );
      } else {
        left.paint(canvas, Offset(textMargin, y));
        layout.right!.paint(
          canvas,
          Offset(widthDots - textMargin - layout.right!.width, y),
        );
      }
      y += layout.height + 7;
    }
    final image = await recorder.endRecording().toImage(widthDots, imageHeight);
    return _encodeImage(image);
  }

  TextPainter _painter(
    String text,
    _ReceiptBlock block, {
    TextAlign? textAlign,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.black,
        fontFamily: 'PlusJakartaSans',
        fontSize: block.fontSize,
        fontWeight: block.fontWeight,
        height: 1.25,
      ),
    ),
    textAlign:
        textAlign ?? (block.centered ? TextAlign.center : TextAlign.left),
    textDirection: TextDirection.ltr,
  );

  Future<RenderedReceipt> _encodeImage(ui.Image image) async {
    final imageHeight = image.height;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (rgba == null) throw StateError('Could not rasterize receipt.');
    final bands = <int>[];
    final output = BytesBuilder(copy: false)..add(const <int>[0x1b, 0x40]);
    final rowBytes = (widthDots + 7) ~/ 8;
    for (var bandTop = 0; bandTop < imageHeight; bandTop += maxBandHeight) {
      final bandHeight = (imageHeight - bandTop).clamp(0, maxBandHeight);
      bands.add(bandHeight);
      output.add(<int>[
        0x1d,
        0x76,
        0x30,
        0x00,
        rowBytes & 0xff,
        (rowBytes >> 8) & 0xff,
        bandHeight & 0xff,
        (bandHeight >> 8) & 0xff,
      ]);
      final raster = Uint8List(rowBytes * bandHeight);
      for (var row = 0; row < bandHeight; row++) {
        final sourceY = bandTop + row;
        for (var x = 0; x < widthDots; x++) {
          final offset = ((sourceY * widthDots) + x) * 4;
          final red = rgba.getUint8(offset);
          final green = rgba.getUint8(offset + 1);
          final blue = rgba.getUint8(offset + 2);
          final alpha = rgba.getUint8(offset + 3);
          final luminance = (red * 299 + green * 587 + blue * 114) ~/ 1000;
          if (alpha > 0 && luminance < 180) {
            raster[(row * rowBytes) + (x ~/ 8)] |= 0x80 >> (x % 8);
          }
        }
      }
      output.add(raster);
    }
    output.add(const <int>[0x1b, 0x64, 0x04]);
    return RenderedReceipt(
      bytes: output.takeBytes(),
      widthDots: widthDots,
      heightDots: imageHeight,
      bandHeights: List<int>.unmodifiable(bands),
    );
  }
}

final class _ReceiptBlock {
  const _ReceiptBlock(
    this.text,
    this.fontSize,
    this.fontWeight, {
    this.centered = false,
  }) : rightText = null,
       separator = false,
       spacerHeight = null;

  const _ReceiptBlock.price(
    this.text,
    this.rightText,
    this.fontSize,
    this.fontWeight,
  ) : centered = false,
      separator = false,
      spacerHeight = null;

  const _ReceiptBlock.spacer(this.spacerHeight)
    : text = '',
      fontSize = 0,
      fontWeight = FontWeight.w500,
      centered = false,
      rightText = null,
      separator = false;

  const _ReceiptBlock.separator()
    : text = '',
      fontSize = 0,
      fontWeight = FontWeight.w500,
      centered = false,
      rightText = null,
      separator = true,
      spacerHeight = null;

  final String text;
  final String? rightText;
  final double fontSize;
  final FontWeight fontWeight;
  final bool centered;
  final bool separator;
  final double? spacerHeight;
}

final class _ReceiptBlockLayout {
  const _ReceiptBlockLayout({
    required this.left,
    this.right,
    this.stacked = false,
    this.stackedGap = 0,
  });

  final TextPainter left;
  final TextPainter? right;
  final bool stacked;
  final double stackedGap;

  double get height => stacked
      ? left.height + stackedGap + right!.height
      : right == null
      ? left.height
      : left.height > right!.height
      ? left.height
      : right!.height;
}

String _dateTime(int epoch) {
  final value = DateTime.fromMillisecondsSinceEpoch(epoch);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} • '
      '${two(value.day)}/${two(value.month)}/${value.year}';
}

String _detailPrice(int price, int quantity) =>
    quantity == 1 ? formatVnd(price) : '${formatVnd(price)} × $quantity';

List<_ReceiptBlock> _footerBlocks(String source) {
  // TextPainter recognizes LF and CRLF as line breaks, but treats a bare CR
  // as part of one line. Split normalized logical lines explicitly so pasted
  // footer text behaves identically and blank paragraphs retain their height.
  final normalized = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) return const [];
  return [
    for (final line in normalized.split('\n'))
      if (line.isEmpty)
        const _ReceiptBlock.spacer(ReceiptRenderer.footerFontSize * 1.25 + 7)
      else
        _ReceiptBlock(
          line,
          ReceiptRenderer.footerFontSize,
          FontWeight.w600,
          centered: true,
        ),
  ];
}
