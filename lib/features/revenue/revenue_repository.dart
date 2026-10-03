import 'package:drift/drift.dart';

import '../../data/app_database.dart';

final class RevenuePeriod {
  const RevenuePeriod({
    required this.startLocal,
    required this.endExclusiveLocal,
  });

  factory RevenuePeriod.today(DateTime now) {
    final start = _localDay(now);
    return RevenuePeriod(
      startLocal: start,
      endExclusiveLocal: _nextLocalDay(start),
    );
  }

  factory RevenuePeriod.lastSevenDays(DateTime now) {
    final today = _localDay(now);
    return RevenuePeriod(
      startLocal: DateTime(today.year, today.month, today.day - 6),
      endExclusiveLocal: _nextLocalDay(today),
    );
  }

  factory RevenuePeriod.thisMonth(DateTime now) {
    return RevenuePeriod(
      startLocal: DateTime(now.year, now.month),
      endExclusiveLocal: DateTime(now.year, now.month + 1),
    );
  }

  factory RevenuePeriod.custom(DateTime start, DateTime inclusiveEnd) {
    final normalizedStart = _localDay(start);
    final normalizedEnd = _localDay(inclusiveEnd);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError.value(inclusiveEnd, 'inclusiveEnd');
    }
    return RevenuePeriod(
      startLocal: normalizedStart,
      endExclusiveLocal: _nextLocalDay(normalizedEnd),
    );
  }

  final DateTime startLocal;
  final DateTime endExclusiveLocal;

  int get startEpochMillis => startLocal.millisecondsSinceEpoch;
  int get endExclusiveEpochMillis => endExclusiveLocal.millisecondsSinceEpoch;
  DateTime get inclusiveEndLocal => DateTime(
    endExclusiveLocal.year,
    endExclusiveLocal.month,
    endExclusiveLocal.day - 1,
  );
}

final class DailyRevenue {
  const DailyRevenue({required this.day, required this.amount});

  final DateTime day;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is DailyRevenue && other.day == day && other.amount == amount;

  @override
  int get hashCode => Object.hash(day, amount);
}

final class BestSeller {
  const BestSeller({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final int quantity;
  final int revenue;

  @override
  bool operator ==(Object other) =>
      other is BestSeller &&
      other.name == name &&
      other.quantity == quantity &&
      other.revenue == revenue;

  @override
  int get hashCode => Object.hash(name, quantity, revenue);
}

final class RevenueSummary {
  const RevenueSummary({
    required this.recognizedRevenue,
    required this.paidOrderCount,
    required this.unpaidAmount,
    required this.dailyRevenue,
    required this.bestSellers,
  });

  final int recognizedRevenue;
  final int paidOrderCount;
  final int unpaidAmount;
  final List<DailyRevenue> dailyRevenue;
  final List<BestSeller> bestSellers;

  @override
  bool operator ==(Object other) =>
      other is RevenueSummary &&
      other.recognizedRevenue == recognizedRevenue &&
      other.paidOrderCount == paidOrderCount &&
      other.unpaidAmount == unpaidAmount &&
      _listEquals(other.dailyRevenue, dailyRevenue) &&
      _listEquals(other.bestSellers, bestSellers);

  @override
  int get hashCode => Object.hash(
    recognizedRevenue,
    paidOrderCount,
    unpaidAmount,
    Object.hashAll(dailyRevenue),
    Object.hashAll(bestSellers),
  );
}

final class RevenueRepository {
  const RevenueRepository(this._database);

  final AppDatabase _database;

  Future<RevenueSummary> summarize(RevenuePeriod period) async {
    final rangeVariables = <Variable<Object>>[
      Variable<int>(period.startEpochMillis),
      Variable<int>(period.endExclusiveEpochMillis),
    ];
    final paidRow = await _database
        .customSelect(
          'SELECT COALESCE(SUM(total), 0) AS revenue, COUNT(*) AS paid_count '
          'FROM orders WHERE status = ? AND paid_at >= ? AND paid_at < ?',
          variables: <Variable<Object>>[
            const Variable<String>('PAID'),
            ...rangeVariables,
          ],
          readsFrom: {_database.orders},
        )
        .getSingle();
    final unpaidRow = await _database
        .customSelect(
          'SELECT COALESCE(SUM(total), 0) AS unpaid_amount '
          'FROM orders WHERE status = ?',
          variables: const <Variable<Object>>[Variable<String>('UNPAID')],
          readsFrom: {_database.orders},
        )
        .getSingle();
    final paidOrders = await _database
        .customSelect(
          'SELECT paid_at, total FROM orders '
          'WHERE status = ? AND paid_at >= ? AND paid_at < ? '
          'ORDER BY paid_at ASC, id ASC',
          variables: <Variable<Object>>[
            const Variable<String>('PAID'),
            ...rangeVariables,
          ],
          readsFrom: {_database.orders},
        )
        .get();
    final bestSellerRows = await _database
        .customSelect(
          'SELECT oi.product_name_snapshot AS name, '
          'SUM(oi.quantity) AS quantity, SUM(oi.line_total) AS revenue '
          'FROM order_items oi INNER JOIN orders o ON o.id = oi.order_id '
          'WHERE o.status = ? AND o.paid_at >= ? AND o.paid_at < ? '
          'GROUP BY oi.product_name_snapshot '
          'ORDER BY quantity DESC, revenue DESC, name ASC LIMIT 5',
          variables: <Variable<Object>>[
            const Variable<String>('PAID'),
            ...rangeVariables,
          ],
          readsFrom: {_database.orders, _database.orderItems},
        )
        .get();

    final amountsByDay = <DateTime, int>{};
    for (final row in paidOrders) {
      final paidAt = row.read<int>('paid_at');
      final day = _localDay(DateTime.fromMillisecondsSinceEpoch(paidAt));
      amountsByDay.update(
        day,
        (value) => value + row.read<int>('total'),
        ifAbsent: () => row.read<int>('total'),
      );
    }
    final dailyRevenue = <DailyRevenue>[];
    var day = period.startLocal;
    while (day.isBefore(period.endExclusiveLocal)) {
      dailyRevenue.add(DailyRevenue(day: day, amount: amountsByDay[day] ?? 0));
      day = _nextLocalDay(day);
    }

    return RevenueSummary(
      recognizedRevenue: paidRow.read<int>('revenue'),
      paidOrderCount: paidRow.read<int>('paid_count'),
      unpaidAmount: unpaidRow.read<int>('unpaid_amount'),
      dailyRevenue: List<DailyRevenue>.unmodifiable(dailyRevenue),
      bestSellers: List<BestSeller>.unmodifiable(
        bestSellerRows.map(
          (row) => BestSeller(
            name: row.read<String>('name'),
            quantity: row.read<int>('quantity'),
            revenue: row.read<int>('revenue'),
          ),
        ),
      ),
    );
  }

  Stream<RevenueSummary> watchSummary(RevenuePeriod period) {
    return _database
        .customSelect(
          'SELECT COUNT(*) AS order_count FROM orders',
          readsFrom: {_database.orders, _database.orderItems},
        )
        .watchSingle()
        .asyncMap((_) => summarize(period));
  }
}

DateTime _localDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _nextLocalDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
