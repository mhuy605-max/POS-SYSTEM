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

  final int widthDots;
  final int maxBandHeight;

  Future<RenderedReceipt> renderOrder(SavedOrder order) {
    final settings = order.receiptSettings;
    final blocks = <_ReceiptBlock>[
      _ReceiptBlock(settings.shopName, 25, FontWeight.w800, centered: true),
      if (settings.address.isNotEmpty)
        _ReceiptBlock(settings.address, 16, FontWeight.w500, centered: true),
      if (settings.phone.isNotEmpty)
        _ReceiptBlock(settings.phone, 16, FontWeight.w500, centered: true),
      const _ReceiptBlock.separator(),
      _ReceiptBlock(
        'ĐƠN #${order.orderNumber.toString().padLeft(4, '0')}',
        21,
        FontWeight.w800,
        centered: true,
      ),
      _ReceiptBlock(
        _dateTime(order.createdAt),
        15,
        FontWeight.w500,
        centered: true,
      ),
      if (order.orderType != null)
        _ReceiptBlock(
          order.orderType == OrderType.dineIn ? 'Tại quán' : 'Mang về',
          16,
          FontWeight.w700,
          centered: true,
        ),
      const _ReceiptBlock.separator(),
      for (final item in order.items) ...[
        _ReceiptBlock(
          '${item.productName} ×${item.quantity}',
          18,
          FontWeight.w700,
        ),
        _ReceiptBlock(
          '${formatVnd(item.unitPrice)} / phần    ${formatVnd(item.lineTotal)}',
          15,
          FontWeight.w500,
        ),
        if (item.note != null && item.note!.trim().isNotEmpty)
          _ReceiptBlock('Ghi chú: ${item.note}', 14, FontWeight.w500),
      ],
      const _ReceiptBlock.separator(),
      _ReceiptBlock(
        'TỔNG CỘNG: ${formatVnd(order.total)}',
        22,
        FontWeight.w800,
      ),
      if (settings.footer.isNotEmpty) ...[
        const _ReceiptBlock.separator(),
        _ReceiptBlock(settings.footer, 16, FontWeight.w600, centered: true),
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
    const margin = 16.0;
    const verticalPadding = 14.0;
    final painters = <TextPainter?>[];
    var height = verticalPadding;
    for (final block in blocks) {
      if (block.separator) {
        painters.add(null);
        height += 18;
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: block.text,
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'PlusJakartaSans',
            fontSize: block.fontSize,
            fontWeight: block.fontWeight,
            height: 1.25,
          ),
        ),
        textAlign: block.centered ? TextAlign.center : TextAlign.left,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: widthDots - (margin * 2));
      painters.add(painter);
      height += painter.height + 7;
    }
    height += verticalPadding;
    final imageHeight = height.ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    var y = verticalPadding;
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      final painter = painters[index];
      if (block.separator) {
        canvas.drawLine(
          Offset(margin, y + 6),
          Offset(widthDots - margin, y + 6),
          Paint()..color = Colors.black,
        );
        y += 18;
        continue;
      }
      final x = block.centered ? (widthDots - painter!.width) / 2 : margin;
      painter!.paint(canvas, Offset(x, y));
      y += painter.height + 7;
    }
    final image = await recorder.endRecording().toImage(widthDots, imageHeight);
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
  }) : separator = false;

  const _ReceiptBlock.separator()
    : text = '',
      fontSize = 0,
      fontWeight = FontWeight.w500,
      centered = false,
      separator = true;

  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final bool centered;
  final bool separator;
}

String _dateTime(int epoch) {
  final value = DateTime.fromMillisecondsSinceEpoch(epoch);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} • '
      '${two(value.day)}/${two(value.month)}/${value.year}';
}
