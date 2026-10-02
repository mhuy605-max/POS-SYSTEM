import 'package:dakao_in_bill/app/theme.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/revenue/revenue_providers.dart';
import 'package:dakao_in_bill/features/revenue/revenue_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  testWidgets('reacts when an order moves from UNPAID to PAID to CANCELLED', (
    tester,
  ) async {
    final id = await _insertOrder(
      database,
      number: 1,
      total: 45000,
      status: 'UNPAID',
      createdAt: _at(2, 8),
    );
    await _pumpRevenue(tester, database);

    expect(_value(tester, 'recognized-revenue'), '0đ');
    expect(_value(tester, 'unpaid-total'), '45.000đ');

    await (database.update(
      database.orders,
    )..where((row) => row.id.equals(id))).write(
      OrdersCompanion(status: const Value('PAID'), paidAt: Value(_at(2, 10))),
    );
    await tester.pumpAndSettle();
    expect(_value(tester, 'recognized-revenue'), '45.000đ');
    expect(_value(tester, 'unpaid-total'), '0đ');
    expect(_value(tester, 'paid-order-count'), '1 đơn');

    await (database.update(database.orders)..where((row) => row.id.equals(id)))
        .write(const OrdersCompanion(status: Value('CANCELLED')));
    await tester.pumpAndSettle();
    expect(_value(tester, 'recognized-revenue'), '0đ');
    expect(_value(tester, 'unpaid-total'), '0đ');
    expect(_value(tester, 'paid-order-count'), '0 đơn');
    await _disposeRevenue(tester);
  });

  testWidgets('period controls filter by paid_at', (tester) async {
    await _insertOrder(
      database,
      number: 1,
      total: 40000,
      status: 'PAID',
      createdAt: _at(1, 8),
      paidAt: _at(1, 9),
    );
    await _insertOrder(
      database,
      number: 2,
      total: 60000,
      status: 'PAID',
      createdAt: _at(1, 8),
      paidAt: _at(2, 9),
    );
    await _pumpRevenue(tester, database);

    expect(_value(tester, 'recognized-revenue'), '60.000đ');
    await tester.tap(find.byKey(const Key('period-sevenDays')));
    await tester.pumpAndSettle();
    expect(_value(tester, 'recognized-revenue'), '100.000đ');
    await _disposeRevenue(tester);
  });

  testWidgets('pull to refresh recomputes today after local midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 2, 23, 59);
    await _insertOrder(
      database,
      number: 1,
      total: 40000,
      status: 'PAID',
      createdAt: _at(2, 8),
      paidAt: _at(2, 9),
    );
    await _insertOrder(
      database,
      number: 2,
      total: 60000,
      status: 'PAID',
      createdAt: _at(3, 8),
      paidAt: _at(3, 9),
    );
    await _pumpRevenue(tester, database, clock: () => now);
    expect(_value(tester, 'recognized-revenue'), '40.000đ');
    expect(find.text('02/10/2026'), findsOneWidget);

    now = DateTime(2026, 10, 3, 0, 1);
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(_value(tester, 'recognized-revenue'), '60.000đ');
    expect(find.text('03/10/2026'), findsOneWidget);
    await _disposeRevenue(tester);
  });

  testWidgets('empty revenue renders useful zero states', (tester) async {
    await _pumpRevenue(tester, database);

    expect(_value(tester, 'recognized-revenue'), '0đ');
    expect(find.text('Chưa có doanh thu trong kỳ này'), findsOneWidget);
    expect(find.text('Chưa có món bán trong kỳ này'), findsOneWidget);
    await _disposeRevenue(tester);
  });

  for (final width in <double>[360, 390, 430]) {
    testWidgets('revenue UI fits ${width.toInt()} logical px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = await _insertOrder(
        database,
        number: 1,
        total: 3360000,
        status: 'PAID',
        createdAt: _at(2, 8),
        paidAt: _at(2, 9),
      );
      await _insertItem(database, id, 'Cơm sườn bì chả', 21, 3360000);
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;

      await _pumpRevenue(tester, database);
      FlutterError.onError = previous;

      expect(
        errors.where((error) => error.exceptionAsString().contains('overflow')),
        isEmpty,
      );
      expect(find.text('Cơm sườn bì chả'), findsOneWidget);
      await _disposeRevenue(tester);
    });
  }
}

Future<void> _pumpRevenue(
  WidgetTester tester,
  AppDatabase database, {
  RevenueClock? clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        revenueNowProvider.overrideWithValue(
          clock ?? () => DateTime(2026, 10, 2, 12),
        ),
      ],
      child: MaterialApp(
        theme: appTheme,
        home: const Scaffold(body: RevenueScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _disposeRevenue(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

String _value(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

int _at(int day, int hour) =>
    DateTime(2026, 10, day, hour).millisecondsSinceEpoch;

Future<int> _insertOrder(
  AppDatabase database, {
  required int number,
  required int total,
  required String status,
  required int createdAt,
  int? paidAt,
}) => database
    .into(database.orders)
    .insert(
      OrdersCompanion.insert(
        orderNumber: number,
        submissionToken: 'widget-revenue-$number',
        subtotal: total,
        total: total,
        createdAt: createdAt,
        status: Value(status),
        paidAt: Value(paidAt),
        receiptSettingsSnapshot: '{"version":1,"shopName":"Đakao","address":"","phone":"","footer":""}',
      ),
    );

Future<void> _insertItem(
  AppDatabase database,
  int orderId,
  String name,
  int quantity,
  int total,
) async {
  await database
      .into(database.orderItems)
      .insert(
        OrderItemsCompanion.insert(
          orderId: orderId,
          productNameSnapshot: name,
          unitPriceSnapshot: total ~/ quantity,
          quantity: quantity,
          lineTotal: total,
        ),
      );
}
