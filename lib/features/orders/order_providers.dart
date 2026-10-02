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

final orderListControllerProvider =
    AsyncNotifierProvider<OrderListController, List<SavedOrder>>(
      OrderListController.new,
    );

final orderDetailsProvider = FutureProvider.family<SavedOrder, int>((ref, id) {
  return ref.watch(orderRepositoryProvider).loadOrder(id);
});

final class OrderListController extends AsyncNotifier<List<SavedOrder>> {
  OrderListFilter filter = OrderListFilter.all;

  @override
  Future<List<SavedOrder>> build() => _load();

  Future<void> setFilter(OrderListFilter value) async {
    filter = value;
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
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

  Future<List<SavedOrder>> _load() {
    final status = switch (filter) {
      OrderListFilter.all => null,
      OrderListFilter.unpaid => OrderStatus.unpaid,
      OrderListFilter.paid => OrderStatus.paid,
    };
    return ref.read(orderRepositoryProvider).listOrders(status: status);
  }
}
