import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database_provider.dart';
import 'order_repository.dart';
import 'order_service.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    ref.watch(appDatabaseProvider),
    nowEpochMillis: () => DateTime.now().millisecondsSinceEpoch,
  );
});

final orderServiceProvider = Provider<OrderService>((ref) {
  return OrderService(
    ref.watch(appDatabaseProvider),
    repository: ref.watch(orderRepositoryProvider),
    nowEpochMillis: () => DateTime.now().millisecondsSinceEpoch,
  );
});

enum OrderListFilter { all, unpaid, paid }

final orderListFilterProvider =
    NotifierProvider<OrderListFilterController, OrderListFilter>(
      OrderListFilterController.new,
    );

final class OrderListFilterController extends Notifier<OrderListFilter> {
  @override
  OrderListFilter build() => OrderListFilter.all;

  void select(OrderListFilter value) => state = value;
}

final orderListControllerProvider =
    AsyncNotifierProvider<OrderListController, List<SavedOrder>>(
      OrderListController.new,
    );

final orderDetailsProvider = FutureProvider.family<SavedOrder, int>((ref, id) {
  return ref.watch(orderRepositoryProvider).loadOrder(id);
});

final class OrderListController extends AsyncNotifier<List<SavedOrder>> {
  OrderListFilter get filter => ref.read(orderListFilterProvider);

  @override
  Future<List<SavedOrder>> build() => _load(ref.watch(orderListFilterProvider));

  void setFilter(OrderListFilter value) {
    ref.read(orderListFilterProvider.notifier).select(value);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(filter));
  }

  Future<SavedOrder> markPaid(int id) async {
    final result = await ref.read(orderServiceProvider).markPaid(id);
    ref.invalidate(orderDetailsProvider(id));
    await refresh();
    return result;
  }

  Future<SavedOrder> cancel(int id, {String? reason}) async {
    final result = await ref
        .read(orderServiceProvider)
        .cancel(id, reason: reason);
    ref.invalidate(orderDetailsProvider(id));
    await refresh();
    return result;
  }

  Future<List<SavedOrder>> _load(OrderListFilter filter) {
    final status = switch (filter) {
      OrderListFilter.all => null,
      OrderListFilter.unpaid => OrderStatus.unpaid,
      OrderListFilter.paid => OrderStatus.paid,
    };
    return ref.read(orderRepositoryProvider).listOrders(status: status);
  }
}
