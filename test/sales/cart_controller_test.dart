import 'dart:async';

import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/sales/cart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late List<OrderDraft> submissions;
  var nextOrderId = 41;

  setUp(() {
    submissions = <OrderDraft>[];
    var tokenNumber = 0;
    container = ProviderContainer(
      overrides: [
        cartTokenFactoryProvider.overrideWithValue(
          () => 'token-${++tokenNumber}',
        ),
        orderSubmitterProvider.overrideWithValue((draft) async {
          submissions.add(draft);
          return nextOrderId;
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test('available product can be added and repeated add increments', () {
    final controller = container.read(cartControllerProvider.notifier);

    expect(controller.addProduct(_product()), isTrue);
    expect(controller.addProduct(_product()), isTrue);

    final state = container.read(cartControllerProvider);
    expect(state.lines, hasLength(1));
    expect(state.lines.single.quantity, 2);
    expect(state.total, 30000);
  });

  test('unavailable product cannot be added', () {
    final controller = container.read(cartControllerProvider.notifier);

    expect(controller.addProduct(_product(isAvailable: false)), isFalse);
    expect(container.read(cartControllerProvider).lines, isEmpty);
  });

  test('decrement removes final quantity and explicit remove works', () {
    final controller = container.read(cartControllerProvider.notifier);
    controller.addProduct(_product());
    controller.addProduct(_product());

    controller.decrement(1);
    expect(container.read(cartControllerProvider).lines.single.quantity, 1);
    controller.decrement(1);
    expect(container.read(cartControllerProvider).lines, isEmpty);

    controller.addProduct(_product());
    controller.remove(
      container.read(cartControllerProvider).lines.single.lineId,
    );
    expect(container.read(cartControllerProvider).lines, isEmpty);
  });

  test('item notes and optional order type are retained', () {
    final controller = container.read(cartControllerProvider.notifier);
    controller.addProduct(_product());
    controller.setNote(1, 'Ít cay');

    expect(container.read(cartControllerProvider).lines.single.note, 'Ít cay');
    expect(container.read(cartControllerProvider).orderType, isNull);
    controller.setOrderType(OrderType.dineIn);
    expect(container.read(cartControllerProvider).orderType, OrderType.dineIn);
    controller.setOrderType(OrderType.takeaway);
    expect(
      container.read(cartControllerProvider).orderType,
      OrderType.takeaway,
    );
    controller.setOrderType(null);
    expect(container.read(cartControllerProvider).orderType, isNull);
  });

  test('same product lines keep independent notes and controls', () {
    final controller = container.read(cartControllerProvider.notifier);
    controller.addProduct(_product());
    final firstLine = container.read(cartControllerProvider).lines.single;
    controller.setNote(firstLine.lineId, 'Ít đá');
    controller.addProduct(_product());
    final lines = container.read(cartControllerProvider).lines;

    expect(lines, hasLength(2));
    expect(lines.map((line) => line.lineId).toSet(), hasLength(2));
    final secondLine = lines.last;
    controller.setNote(secondLine.lineId, 'Không đá');
    controller.increment(secondLine.lineId);

    final updated = container.read(cartControllerProvider).lines;
    expect(updated.first.note, 'Ít đá');
    expect(updated.first.quantity, 1);
    expect(updated.last.note, 'Không đá');
    expect(updated.last.quantity, 2);

    controller.remove(secondLine.lineId);
    expect(container.read(cartControllerProvider).lines.single.note, 'Ít đá');
  });

  test(
    'successful submit creates UNPAID draft, clears and rotates token',
    () async {
      final controller = container.read(cartControllerProvider.notifier);
      controller.addProduct(_product());
      controller.setNote(1, 'Không hành');
      final originalToken = container
          .read(cartControllerProvider)
          .submissionToken;

      final result = await controller.submit();

      expect(result, nextOrderId);
      expect(submissions, hasLength(1));
      expect(submissions.single.submissionToken, originalToken);
      expect(submissions.single.orderType, isNull);
      expect(submissions.single.lines.single.note, 'Không hành');
      final state = container.read(cartControllerProvider);
      expect(state.lines, isEmpty);
      expect(state.submissionToken, isNot(originalToken));
    },
  );

  test('failed submit keeps cart and submission token for retry', () async {
    final failing = ProviderContainer(
      overrides: [
        cartTokenFactoryProvider.overrideWithValue(() => 'retry-token'),
        orderSubmitterProvider.overrideWithValue(
          (_) async => throw StateError('disk full'),
        ),
      ],
    );
    addTearDown(failing.dispose);
    final controller = failing.read(cartControllerProvider.notifier);
    controller.addProduct(_product());

    await expectLater(controller.submit(), throwsStateError);

    final state = failing.read(cartControllerProvider);
    expect(state.lines, hasLength(1));
    expect(state.submissionToken, 'retry-token');
    expect(state.isSubmitting, isFalse);
  });

  test(
    'double submit shares one in-flight operation and clears once',
    () async {
      final gate = Completer<int>();
      var calls = 0;
      final guarded = ProviderContainer(
        overrides: [
          cartTokenFactoryProvider.overrideWithValue(() => 'double-token'),
          orderSubmitterProvider.overrideWithValue((_) {
            calls++;
            return gate.future;
          }),
        ],
      );
      addTearDown(guarded.dispose);
      final controller = guarded.read(cartControllerProvider.notifier);
      controller.addProduct(_product());

      final first = controller.submit();
      final second = controller.submit();
      gate.complete(7);

      expect(await first, 7);
      expect(await second, 7);
      expect(calls, 1);
      expect(guarded.read(cartControllerProvider).lines, isEmpty);
    },
  );

  test('cart cannot mutate while a submission is in flight', () async {
    final gate = Completer<int>();
    final guarded = ProviderContainer(
      overrides: [
        cartTokenFactoryProvider.overrideWithValue(() => 'locked-token'),
        orderSubmitterProvider.overrideWithValue((_) => gate.future),
      ],
    );
    addTearDown(guarded.dispose);
    final controller = guarded.read(cartControllerProvider.notifier);
    controller.addProduct(_product());
    final line = guarded.read(cartControllerProvider).lines.single;

    final submission = controller.submit();
    expect(controller.addProduct(_product(id: 2)), isFalse);
    controller.increment(line.lineId);
    controller.decrement(line.lineId);
    controller.setNote(line.lineId, 'Changed');
    controller.setOrderType(OrderType.takeaway);
    controller.clear();

    final locked = guarded.read(cartControllerProvider);
    expect(locked.lines, hasLength(1));
    expect(locked.lines.single.quantity, 1);
    expect(locked.lines.single.note, isNull);
    expect(locked.orderType, isNull);
    expect(locked.submissionToken, 'locked-token');

    gate.complete(9);
    expect(await submission, 9);
    expect(guarded.read(cartControllerProvider).lines, isEmpty);
  });
}

CatalogProduct _product({int id = 1, bool isAvailable = true}) =>
    CatalogProduct(
      id: id,
      categoryId: 2,
      categoryName: 'Cà phê',
      name: 'Cà phê sữa',
      description: null,
      price: 15000,
      imagePath: null,
      isAvailable: isAvailable,
      sortOrder: 0,
      deletedAt: null,
    );
