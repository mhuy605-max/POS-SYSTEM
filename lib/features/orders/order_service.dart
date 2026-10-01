import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import 'order_repository.dart';

final class InvalidOrderTransitionException implements Exception {
  const InvalidOrderTransitionException(this.from, this.to);

  final OrderStatus from;
  final OrderStatus to;

  @override
  String toString() => 'Invalid order transition: $from -> $to';
}

final class OrderService {
  OrderService(
    this._database, {
    required this._repository,
    required this._nowEpochMillis,
  });

  final AppDatabase _database;
  final OrderRepository _repository;
  final EpochClock _nowEpochMillis;

  Future<SavedOrder> markPaid(int orderId) async {
    await _database.transaction(() async {
      final order = await (_database.select(
        _database.orders,
      )..where((row) => row.id.equals(orderId))).getSingle();
      switch (order.status) {
        case 'UNPAID':
          await (_database.update(
            _database.orders,
          )..where((row) => row.id.equals(orderId))).write(
            OrdersCompanion(
              status: const Value('PAID'),
              paidAt: Value(_nowEpochMillis()),
            ),
          );
          return;
        case 'PAID':
          return;
        case 'CANCELLED':
          throw const InvalidOrderTransitionException(
            OrderStatus.cancelled,
            OrderStatus.paid,
          );
        default:
          throw StateError('Unknown order status: ${order.status}');
      }
    });
    return _repository.loadOrder(orderId);
  }

  Future<SavedOrder> cancel(int orderId, {String? reason}) async {
    await _database.transaction(() async {
      final order = await (_database.select(
        _database.orders,
      )..where((row) => row.id.equals(orderId))).getSingle();
      if (order.status == 'CANCELLED') {
        throw const InvalidOrderTransitionException(
          OrderStatus.cancelled,
          OrderStatus.cancelled,
        );
      }
      if (order.status != 'UNPAID' && order.status != 'PAID') {
        throw StateError('Unknown order status: ${order.status}');
      }
      final normalizedReason = reason?.trim();
      await (_database.update(
        _database.orders,
      )..where((row) => row.id.equals(orderId))).write(
        OrdersCompanion(
          status: const Value('CANCELLED'),
          cancelledAt: Value(_nowEpochMillis()),
          cancellationReason: Value(
            normalizedReason == null || normalizedReason.isEmpty
                ? null
                : normalizedReason,
          ),
        ),
      );
    });
    return _repository.loadOrder(orderId);
  }
}
