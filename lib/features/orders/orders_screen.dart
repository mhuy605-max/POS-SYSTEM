import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import 'order_providers.dart';
import 'order_repository.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: ref.read(orderListControllerProvider.notifier).refresh,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _OrderFilters()),
          const _OrderResults(),
        ],
      ),
    );
  }
}

class _OrderFilters extends ConsumerWidget {
  const _OrderFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(orderListFilterProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SegmentedButton<OrderListFilter>(
        key: const Key('orders-filter'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: OrderListFilter.all, label: Text('Tất cả')),
          ButtonSegment(value: OrderListFilter.unpaid, label: Text('Chưa trả')),
          ButtonSegment(value: OrderListFilter.paid, label: Text('Đã trả')),
        ],
        selected: {filter},
        onSelectionChanged: (value) => ref
            .read(orderListControllerProvider.notifier)
            .setFilter(value.single),
      ),
    );
  }
}

class _OrderResults extends ConsumerWidget {
  const _OrderResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(orderListControllerProvider);
    final filter = ref.watch(orderListFilterProvider);
    return orders.when(
      loading: () => const SliverFillRemaining(
        child: AppLoadingState(label: 'Đang tải đơn hàng'),
      ),
      error: (error, _) => SliverFillRemaining(
        child: AppAsyncError(
          message: 'Không thể tải danh sách đơn hàng.',
          onRetry: ref.read(orderListControllerProvider.notifier).refresh,
        ),
      ),
      data: (items) => items.isEmpty
          ? SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.receipt_long_outlined,
                title: filter == OrderListFilter.all
                    ? 'Chưa có đơn hàng'
                    : 'Chưa có đơn phù hợp',
                message: filter == OrderListFilter.all
                    ? 'Đơn đã lưu sẽ xuất hiện tại đây.'
                    : 'Thử chọn trạng thái khác để xem đơn.',
              ),
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryStrong,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
    final (label, tone) = switch (status) {
      OrderStatus.unpaid => ('Chưa thanh toán', AppStatusTone.warning),
      OrderStatus.paid => ('Đã thanh toán', AppStatusTone.success),
      OrderStatus.cancelled => ('Đã hủy', AppStatusTone.error),
    };
    return AppStatusBadge(label: label, tone: tone);
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
