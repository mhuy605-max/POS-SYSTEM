import 'dart:io';

import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDirectory;
  late AppDatabase database;
  late OrderRepository repository;
  late int now;
  late OrderService service;
  late int productId;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('dakao_status_test_');
    database = AppDatabase.openFile(
      File('${tempDirectory.path}/status.sqlite'),
    );
    repository = OrderRepository(database, nowEpochMillis: () => 1000);
    now = 2000;
    service = OrderService(
      database,
      repository: repository,
      nowEpochMillis: () => now,
    );
    productId = await _insertProduct(database);
  });

  tearDown(() async {
    await database.close();
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('new order starts UNPAID and mark-paid records paid_at', () async {
    final id = await repository.createOrder(_draft('pay', productId));
    expect((await repository.loadOrder(id)).status, OrderStatus.unpaid);

    await service.markPaid(id);

    final paid = await repository.loadOrder(id);
    expect(paid.status, OrderStatus.paid);
    expect(paid.paidAt, 2000);
  });

  test(
    'repeated mark-paid is idempotent and preserves original paid_at',
    () async {
      final id = await repository.createOrder(_draft('pay-twice', productId));
      await service.markPaid(id);
      now = 9000;

      await service.markPaid(id);

      final paid = await repository.loadOrder(id);
      expect(paid.status, OrderStatus.paid);
      expect(paid.paidAt, 2000);
    },
  );

  test('UNPAID can transition to CANCELLED', () async {
    final id = await repository.createOrder(_draft('cancel-unpaid', productId));

    await service.cancel(id, reason: 'Khách đổi ý');

    final cancelled = await repository.loadOrder(id);
    expect(cancelled.status, OrderStatus.cancelled);
    expect(cancelled.cancelledAt, 2000);
    expect(cancelled.cancellationReason, 'Khách đổi ý');
    expect(cancelled.paidAt, isNull);
  });

  test('PAID can transition to CANCELLED and preserves paid_at', () async {
    final id = await repository.createOrder(_draft('cancel-paid', productId));
    await service.markPaid(id);
    now = 3000;

    await service.cancel(id);

    final cancelled = await repository.loadOrder(id);
    expect(cancelled.status, OrderStatus.cancelled);
    expect(cancelled.paidAt, 2000);
    expect(cancelled.cancelledAt, 3000);
  });

  test('CANCELLED cannot transition to another state', () async {
    final id = await repository.createOrder(_draft('terminal', productId));
    await service.cancel(id);

    await expectLater(
      service.markPaid(id),
      throwsA(isA<InvalidOrderTransitionException>()),
    );
    await expectLater(
      service.cancel(id),
      throwsA(isA<InvalidOrderTransitionException>()),
    );
    expect((await repository.loadOrder(id)).status, OrderStatus.cancelled);
  });
}

OrderDraft _draft(String token, int productId) => OrderDraft(
  submissionToken: token,
  lines: <DraftLine>[
    DraftLine(
      productId: productId,
      reviewedName: 'Món',
      reviewedUnitPrice: 10000,
      quantity: 1,
    ),
  ],
);

Future<int> _insertProduct(AppDatabase database) async {
  final categoryId = await database
      .into(database.categories)
      .insert(
        CategoriesCompanion.insert(
          name: 'Danh mục',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
  return database
      .into(database.products)
      .insert(
        ProductsCompanion.insert(
          categoryId: categoryId,
          name: 'Món',
          price: 10000,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
}
