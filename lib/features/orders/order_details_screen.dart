import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import '../printing/printer_models.dart';
import '../printing/printer_providers.dart';
import 'order_providers.dart';
import 'order_repository.dart';
import 'orders_screen.dart';

class OrderDetailsScreen extends ConsumerWidget {
  const OrderDetailsScreen({required this.orderId, super.key});
  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailsProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn')),
      body: order.when(
        loading: () => const AppLoadingState(label: 'Đang tải chi tiết đơn'),
        error: (error, _) =>
            const AppAsyncError(message: 'Không thể tải chi tiết đơn hàng.'),
        data: (value) => _Details(order: value),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(
                  '#${order.orderNumber.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _dateTime(order.createdAt),
              style: const TextStyle(color: AppColors.secondaryInk),
            ),
            if (order.orderType != null) ...[
              const SizedBox(height: 8),
              Text(
                order.orderType == OrderType.dineIn ? 'Tại quán' : 'Mang về',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 16),
            _Receipt(order: order),
          ],
        ),
      ),
      AppBottomActionSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order.status == OrderStatus.unpaid)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('mark-paid'),
                  onPressed: () => ref
                      .read(orderListControllerProvider.notifier)
                      .markPaid(order.id),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Đánh dấu đã trả'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            if (order.status != OrderStatus.cancelled) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('cancel-order'),
                  onPressed: () => _confirmCancel(context, ref),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Hủy đơn'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(48, 52),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _ReprintButton(order: order),
          ],
        ),
      ),
    ],
  );

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final paid = order.status == OrderStatus.paid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy đơn'),
        content: Text(
          paid
              ? 'Đơn này đã được đánh dấu thanh toán. V1 không có quy trình hoàn tiền. Bạn vẫn muốn hủy đơn?'
              : 'Đơn sẽ chuyển sang trạng thái đã hủy và không thể khôi phục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không hủy'),
          ),
          FilledButton(
            key: const Key('confirm-cancel-order'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hủy đơn'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(orderListControllerProvider.notifier).cancel(order.id);
    }
  }
}

class _ReprintButton extends ConsumerStatefulWidget {
  const _ReprintButton({required this.order});
  final SavedOrder order;

  @override
  ConsumerState<_ReprintButton> createState() => _ReprintButtonState();
}

class _ReprintButtonState extends ConsumerState<_ReprintButton> {
  var _busy = false;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      key: const Key('reprint-order'),
      onPressed: widget.order.status == OrderStatus.cancelled || _busy
          ? null
          : _reprint,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined),
      label: Text(
        widget.order.status == OrderStatus.cancelled
            ? 'Không thể in lại đơn đã hủy'
            : 'In lại bill',
      ),
    ),
  );

  Future<void> _reprint() async {
    setState(() => _busy = true);
    PrintResult result;
    try {
      result = await ref
          .read(printerServiceProvider)
          .reprintOrder(widget.order.id);
    } catch (_) {
      result = const PrintResult.failed(
        PrinterErrorCode.writeFailed,
        'Không thể chuẩn bị yêu cầu in lại.',
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(orderDetailsProvider(widget.order.id));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_printResultMessage(result))));
  }
}

String _printResultMessage(PrintResult result) => switch (result.kind) {
  PrintResultKind.sent => 'Dữ liệu đã gửi tới máy in; hãy kiểm tra giấy.',
  PrintResultKind.unknown =>
    'Kết quả gửi chưa rõ. Ứng dụng sẽ không tự động in lại.',
  PrintResultKind.failed => result.message,
};

class _Receipt extends StatelessWidget {
  const _Receipt({required this.order});
  final SavedOrder order;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        children: [
          Text(
            order.receiptSettings.shopName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          if (order.receiptSettings.address.isNotEmpty)
            Text(order.receiptSettings.address, textAlign: TextAlign.center),
          if (order.receiptSettings.phone.isNotEmpty)
            Text(order.receiptSettings.phone, textAlign: TextAlign.center),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          for (final item in order.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item.productName} ×${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatVnd(item.lineTotal),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatVnd(item.unitPrice)} / phần',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                ),
              ],
            ),
            if (item.note != null && item.note!.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.note!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
          const Divider(),
          Row(
            children: [
              const Text(
                'TỔNG CỘNG',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                formatVnd(order.total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (order.receiptSettings.footer.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(order.receiptSettings.footer, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

String _dateTime(int epoch) {
  final value = DateTime.fromMillisecondsSinceEpoch(epoch);
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)} • ${two(value.day)}/${two(value.month)}/${value.year}';
}
