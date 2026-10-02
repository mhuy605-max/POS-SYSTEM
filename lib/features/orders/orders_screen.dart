import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'order_providers.dart';
import 'order_repository.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderListControllerProvider);
    final filter = ref.read(orderListControllerProvider.notifier).filter;
    return RefreshIndicator(
      onRefresh: ref.read(orderListControllerProvider.notifier).refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Danh sách đơn hàng',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<OrderListFilter>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: OrderListFilter.all,
                        label: Text('Tất cả'),
                      ),
                      ButtonSegment(
                        value: OrderListFilter.unpaid,
                        label: Text('Chưa trả'),
                      ),
                      ButtonSegment(
                        value: OrderListFilter.paid,
                        label: Text('Đã trả'),
                      ),
                    ],
                    selected: {filter},
                    onSelectionChanged: (value) => ref
                        .read(orderListControllerProvider.notifier)
                        .setFilter(value.single),
                  ),
                ],
              ),
            ),
          ),
          orders.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(child: Text('Không thể tải đơn: $error')),
            ),
            data: (items) => items.isEmpty
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Chưa có đơn phù hợp.')),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _OrderCard(order: items[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final SavedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: InkWell(
      key: Key('order-${order.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/orders/${order.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${order.orderNumber.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _time(order.createdAt),
                  style: const TextStyle(color: AppColors.secondaryInk),
                ),
                const Spacer(),
                if (order.orderType != null) _TypeBadge(type: order.orderType!),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.items
                  .map((item) => '${item.productName} ×${item.quantity}')
                  .join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  formatVnd(order.total),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                OrderStatusBadge(status: order.status),
              ],
            ),
            if (order.status == OrderStatus.unpaid) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
            ],
          ],
        ),
      ),
    ),
  );
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({required this.status, super.key});
  final OrderStatus status;
  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      OrderStatus.unpaid => (
        'Chưa thanh toán',
        const Color(0xFFFFDCC3),
        const Color(0xFF6E3900),
      ),
      OrderStatus.paid => (
        'Đã thanh toán',
        AppColors.successContainer,
        AppColors.success,
      ),
      OrderStatus.cancelled => (
        'Đã hủy',
        const Color(0xFFFFDAD6),
        AppColors.error,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final OrderType type;
  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(type == OrderType.dineIn ? 'Tại quán' : 'Mang về'),
  );
}

String _time(int epoch) {
  final value = DateTime.fromMillisecondsSinceEpoch(epoch);
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/${value.year} • $hour:$minute';
}
