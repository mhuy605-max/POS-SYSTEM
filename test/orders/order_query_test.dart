import 'dart:io';

import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late OrderRepository repository;
  late OrderService service;
  late int productId;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dakao_order_query_');
    database = AppDatabase.openFile(File('${directory.path}/orders.sqlite'));
    repository = OrderRepository(database, nowEpochMillis: () => 1000);
    service = OrderService(
      database,
      repository: repository,
      nowEpochMillis: () => 2000,
    );
    final category = await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(name: 'Món', createdAt: 1, updatedAt: 1),
        );
    productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            categoryId: category,
            name: 'Bún bò',
            price: 45000,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'list returns persisted orders newest first and filters payment state',
    () async {
      final unpaidId = await repository.createOrder(
        _draft('unpaid', productId),
      );
      final paidId = await repository.createOrder(_draft('paid', productId));
      await service.markPaid(paidId);

      expect((await repository.listOrders()).map((o) => o.id), [
        paidId,
        unpaidId,
      ]);
      expect(
        (await repository.listOrders(status: OrderStatus.unpaid))
            .map((o) => o.id),
        [unpaidId],
      );
      expect(
        (await repository.listOrders(status: OrderStatus.paid))
            .map((o) => o.id),
        [paidId],
      );
    },
  );

  test(
    'service submit delegates atomic creation and stays idempotent',
    () async {
      final draft = _draft('same', productId);

      final first = await service.submitForPrint(draft);
      final second = await service.submitForPrint(draft);

      expect(second, first);
      expect(await repository.listOrders(), hasLength(1));
    },
  );
}

OrderDraft _draft(String token, int productId) => OrderDraft(
  submissionToken: token,
  lines: [
    DraftLine(
      productId: productId,
      reviewedName: 'Bún bò',
      reviewedUnitPrice: 45000,
      quantity: 1,
    ),
  ],
);
