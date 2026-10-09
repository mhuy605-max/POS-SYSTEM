import 'package:dakao_in_bill/core/money.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/printing/printer_models.dart';
import 'package:dakao_in_bill/features/products/product_option_repository.dart';
import 'package:dakao_in_bill/features/products/product_repository.dart';
import 'package:dakao_in_bill/features/sales/cart_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late List<OrderDraft> submissions;

  setUp(() {
    submissions = [];
    container = ProviderContainer(
      overrides: [
        cartTokenFactoryProvider.overrideWithValue(() => 'options-token'),
        orderSubmitterProvider.overrideWithValue((draft) async {
          submissions.add(draft);
          return 1;
        }),
        orderPrinterProvider.overrideWithValue(
          (_) async => const PrintResult.sent(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'zero options preserve immediate add, merge, pricing and draft mapping',
    () async {
      final controller = container.read(cartControllerProvider.notifier);
      expect(controller.addProduct(_product()), isTrue);
      expect(controller.addProduct(_product()), isTrue);

      final line = container.read(cartControllerProvider).lines.single;
      expect(line.quantity, 2);
      expect(line.baseUnitPrice, 35000);
      expect(line.unitPrice, 35000);
      expect(line.lineTotal, 70000);
      expect(line.selectedOptions, isEmpty);

      await controller.submit();
      final draft = submissions.single.lines.single;
      expect(draft.reviewedBaseUnitPrice, 35000);
      expect(draft.reviewedUnitPrice, 35000);
      expect(draft.selectedOptions, isEmpty);
    },
  );

  test(
    'one option calculates configured price and maps reviewed draft data',
    () async {
      final controller = container.read(cartControllerProvider.notifier);
      final pork = _option(
        optionId: 11,
        groupId: 4,
        groupName: 'Món thêm',
        optionName: 'Sườn thêm',
        price: 45000,
      );

      expect(
        controller.addConfiguredProduct(_product(), selectedOptions: [pork]),
        isTrue,
      );

      final line = container.read(cartControllerProvider).lines.single;
      expect(line.baseUnitPrice, 35000);
      expect(line.unitPrice, 80000);
      expect(line.lineTotal, 80000);
      await controller.submit();
      final draft = submissions.single.lines.single;
      expect(draft.reviewedBaseUnitPrice, 35000);
      expect(draft.reviewedUnitPrice, 80000);
      expect(draft.selectedOptions.single.optionItemId, 11);
      expect(draft.selectedOptions.single.optionGroupId, 4);
      expect(draft.selectedOptions.single.reviewedGroupName, 'Món thêm');
      expect(draft.selectedOptions.single.reviewedOptionName, 'Sườn thêm');
      expect(draft.selectedOptions.single.reviewedPriceDelta, 45000);
    },
  );

  test(
    'multiple options canonicalize before quantity and draft conversion',
    () async {
      final controller = container.read(cartControllerProvider.notifier);
      final pork = _option(
        optionId: 12,
        groupId: 4,
        groupName: 'Món thêm',
        optionName: 'Sườn',
        price: 45000,
        groupOrder: 0,
        optionOrder: 1,
      );
      final egg = _option(
        optionId: 11,
        groupId: 4,
        groupName: 'Món thêm',
        optionName: 'Trứng',
        price: 30000,
        groupOrder: 0,
        optionOrder: 0,
      );
      final sauce = _option(
        optionId: 20,
        groupId: 5,
        groupName: 'Sốt',
        optionName: 'Tiêu',
        price: 5000,
        groupOrder: 1,
      );

      controller.addConfiguredProduct(
        _product(),
        selectedOptions: [sauce, pork, egg],
      );
      final lineId = container.read(cartControllerProvider).lines.single.lineId;
      controller.increment(lineId);
      controller.increment(lineId);

      final line = container.read(cartControllerProvider).lines.single;
      expect(line.selectedOptions.map((option) => option.optionItemId), [
        11,
        12,
        20,
      ]);
      expect(line.unitPrice, 115000);
      expect(line.quantity, 3);
      expect(line.lineTotal, 345000);
      await controller.submit();
      expect(
        submissions.single.lines.single.selectedOptions.map(
          (option) => option.optionItemId,
        ),
        [11, 12, 20],
      );
    },
  );

  test(
    'configuration identity merges only equal options and meaningful note',
    () {
      final controller = container.read(cartControllerProvider.notifier);
      final pork = _option(optionId: 1, optionName: 'Sườn', price: 45000);
      final egg = _option(optionId: 2, optionName: 'Trứng', price: 30000);

      controller.addConfiguredProduct(
        _product(),
        selectedOptions: [pork, egg],
        note: ' Ít cay ',
      );
      controller.addConfiguredProduct(
        _product(),
        selectedOptions: [egg, pork],
        note: 'Ít cay',
      );
      controller.addConfiguredProduct(
        _product(),
        selectedOptions: [pork],
        note: 'Ít cay',
      );
      controller.addConfiguredProduct(
        _product(),
        selectedOptions: [pork, egg],
        note: 'Không cay',
      );

      final lines = container.read(cartControllerProvider).lines;
      expect(lines, hasLength(3));
      expect(lines.first.quantity, 2);
      expect(lines.first.note, 'Ít cay');
      expect(lines[1].selectedOptions.map((option) => option.optionItemId), [
        1,
      ]);
      expect(lines[2].note, 'Không cay');
    },
  );

  test('null, empty and whitespace notes share one normalized identity', () {
    final controller = container.read(cartControllerProvider.notifier);
    controller.addConfiguredProduct(_product());
    controller.addConfiguredProduct(_product(), note: '');
    controller.addConfiguredProduct(_product(), note: '   ');
    controller.addConfiguredProduct(_product(), note: ' Ít  cay ');
    controller.addConfiguredProduct(_product(), note: 'Ít  cay');
    controller.addConfiguredProduct(_product(), note: 'Ít cay');

    final lines = container.read(cartControllerProvider).lines;
    expect(lines, hasLength(3));
    expect(lines.first.quantity, 3);
    expect(lines.first.note, isNull);
    expect(lines[1].quantity, 2);
    expect(lines[1].note, 'Ít  cay');
    expect(lines[2].note, 'Ít cay');
  });

  test('duplicate option IDs are rejected without cart mutation', () {
    final controller = container.read(cartControllerProvider.notifier);
    final option = _option(optionId: 1, optionName: 'Sườn', price: 45000);

    expect(
      () => controller.addConfiguredProduct(
        _product(),
        selectedOptions: [option, option],
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(container.read(cartControllerProvider).lines, isEmpty);
  });

  test('editing options and notes recalculates while preserving quantity', () {
    final controller = container.read(cartControllerProvider.notifier);
    final pork = _option(optionId: 1, optionName: 'Sườn', price: 45000);
    final egg = _option(optionId: 2, optionName: 'Trứng', price: 30000);
    controller.addConfiguredProduct(
      _product(),
      selectedOptions: [pork],
      note: 'Cũ',
    );
    final lineId = container.read(cartControllerProvider).lines.single.lineId;
    controller.increment(lineId);

    expect(
      controller.editConfiguration(
        lineId,
        selectedOptions: [egg],
        note: ' Mới ',
      ),
      isTrue,
    );

    final line = container.read(cartControllerProvider).lines.single;
    expect(line.lineId, lineId);
    expect(line.quantity, 2);
    expect(line.note, 'Mới');
    expect(line.unitPrice, 65000);
    expect(line.lineTotal, 130000);
  });

  test('editing into an existing identity coalesces through one path', () {
    final controller = container.read(cartControllerProvider.notifier);
    final pork = _option(optionId: 1, optionName: 'Sườn', price: 45000);
    final egg = _option(optionId: 2, optionName: 'Trứng', price: 30000);
    controller.addConfiguredProduct(_product(), selectedOptions: [pork]);
    controller.addConfiguredProduct(_product(), selectedOptions: [egg]);
    final second = container.read(cartControllerProvider).lines.last;
    controller.increment(second.lineId);

    controller.editConfiguration(
      second.lineId,
      selectedOptions: [pork],
      note: null,
    );

    final line = container.read(cartControllerProvider).lines.single;
    expect(line.quantity, 3);
    expect(line.selectedOptions.single.optionItemId, 1);
  });

  test('failed edit leaves the reviewed cart unchanged', () {
    final controller = container.read(cartControllerProvider.notifier);
    final safe = _option(optionId: 1, optionName: 'An toàn', price: 1);
    controller.addConfiguredProduct(_product(), selectedOptions: [safe]);
    final before = container.read(cartControllerProvider).lines.single;
    final overflow = _option(
      optionId: 2,
      optionName: 'Quá lớn',
      price: sqliteMaxInteger,
    );

    expect(
      () => controller.editConfiguration(
        before.lineId,
        selectedOptions: [overflow],
        note: 'Không lưu',
      ),
      throwsA(isA<DomainValidationException>()),
    );

    final after = container.read(cartControllerProvider).lines.single;
    expect(after.lineId, before.lineId);
    expect(after.note, before.note);
    expect(after.unitPrice, before.unitPrice);
    expect(after.selectedOptions.single.optionItemId, 1);
  });

  test('price overflows are rejected before partial cart mutation', () {
    final controller = container.read(cartControllerProvider.notifier);
    final overflow = _option(
      optionId: 1,
      optionName: 'Quá lớn',
      price: sqliteMaxInteger,
    );
    expect(
      () => controller.addConfiguredProduct(
        _product(),
        selectedOptions: [overflow],
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(container.read(cartControllerProvider).lines, isEmpty);

    controller.addProduct(_product(price: sqliteMaxInteger));
    final maximum = container.read(cartControllerProvider).lines.single;
    expect(
      () => controller.increment(maximum.lineId),
      throwsA(isA<DomainValidationException>()),
    );
    expect(container.read(cartControllerProvider).lines.single.quantity, 1);

    controller.clear();
    final halfPlusOne = sqliteMaxInteger ~/ 2 + 1;
    controller.addConfiguredProduct(_product(price: halfPlusOne), note: 'Một');
    expect(
      () => controller.addConfiguredProduct(
        _product(price: halfPlusOne),
        note: 'Hai',
      ),
      throwsA(isA<DomainValidationException>()),
    );
    expect(container.read(cartControllerProvider).lines, hasLength(1));
    expect(container.read(cartControllerProvider).lines.single.note, 'Một');
  });

  test(
    'cart snapshots stay stable when source option collections are replaced',
    () {
      final controller = container.read(cartControllerProvider.notifier);
      final source = <ResolvedProductOption>[
        _option(optionId: 1, optionName: 'Tên cũ', price: 45000),
      ];
      controller.addConfiguredProduct(_product(), selectedOptions: source);

      source
        ..clear()
        ..add(_option(optionId: 2, optionName: 'Tên mới', price: 99999));

      final line = container.read(cartControllerProvider).lines.single;
      expect(line.selectedOptions.single.optionItemId, 1);
      expect(line.selectedOptions.single.optionName, 'Tên cũ');
      expect(line.selectedOptions.single.priceDelta, 45000);
      expect(line.unitPrice, 80000);
    },
  );
}

CatalogProduct _product({int id = 1, int price = 35000}) => CatalogProduct(
  id: id,
  categoryId: 1,
  categoryName: 'Cơm',
  name: 'Cơm sườn',
  description: null,
  price: price,
  imagePath: null,
  isAvailable: true,
  sortOrder: 0,
  deletedAt: null,
);

ResolvedProductOption _option({
  required int optionId,
  int groupId = 4,
  String groupName = 'Món thêm',
  required String optionName,
  required int price,
  int groupOrder = 0,
  int optionOrder = 0,
}) => ResolvedProductOption(
  productId: 1,
  groupId: groupId,
  optionItemId: optionId,
  groupName: groupName,
  optionName: optionName,
  priceDelta: price,
  groupSortOrder: groupOrder,
  optionSortOrder: optionOrder,
);
