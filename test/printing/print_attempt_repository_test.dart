import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/print_attempt_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late OrderRepository orders;
  late PrintAttemptRepository attempts;
  late int orderId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    orders = OrderRepository(database, nowEpochMillis: () => 1000);
    attempts = PrintAttemptRepository(database, nowEpochMillis: () => 2000);
    final category = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(name: 'Món', createdAt: 1, updatedAt: 1),
        );
    final product = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            categoryId: category,
            name: 'Cơm tấm',
            price: 45000,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    orderId = await orders.createOrder(
      OrderDraft(
        submissionToken: 'attempt-order',
        lines: <DraftLine>[
          DraftLine(
            productId: product,
            reviewedName: 'Cơm tấm',
            reviewedUnitPrice: 45000,
            quantity: 1,
          ),
        ],
      ),
    );
  });

  tearDown(() => database.close());

  test(
    'sent attempt increments print count and stores transmission time',
    () async {
      await attempts.record(orderId, const PrintResult.sent());

      final order = await (database.select(
        database.orders,
      )..where((row) => row.id.equals(orderId))).getSingle();
      final rows = await database.select(database.printAttempts).get();
      expect(order.printCount, 1);
      expect(order.printedAt, 2000);
      expect(rows.single.success, isTrue);
      expect(rows.single.errorMessage, isNull);
    },
  );

  test('failed and unknown attempts do not increment print count', () async {
    await attempts.record(
      orderId,
      const PrintResult.failed(
        PrinterErrorCode.connectionFailed,
        'Không thể kết nối',
      ),
    );
    await attempts.record(
      orderId,
      const PrintResult.unknown(
        PrinterErrorCode.unknownOutcome,
        'Có thể đã gửi một phần dữ liệu',
      ),
    );

    final order = await (database.select(
      database.orders,
    )..where((row) => row.id.equals(orderId))).getSingle();
    final rows = await (database.select(
      database.printAttempts,
    )..orderBy([(row) => OrderingTerm.asc(row.id)])).get();
    expect(order.printCount, 0);
    expect(order.printedAt, isNull);
    expect(rows, hasLength(2));
    expect(rows.every((row) => !row.success), isTrue);
    expect(rows.last.errorMessage, startsWith('UNKNOWN_OUTCOME|'));
  });
}
