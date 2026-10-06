import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product_option_repository.dart';
import '../products/product_repository.dart';
import '../printing/printer_models.dart';
import '../printing/printer_providers.dart';

typedef CartTokenFactory = String Function();
typedef OrderSubmitter = Future<int> Function(OrderDraft draft);
typedef OrderPrinter = Future<PrintResult> Function(int orderId);

final cartTokenFactoryProvider = Provider<CartTokenFactory>((ref) {
  final random = Random.secure();
  return () =>
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${random.nextInt(0x7fffffff).toRadixString(16)}';
});

final orderSubmitterProvider = Provider<OrderSubmitter>((ref) {
  return ref.watch(orderServiceProvider).submitForPrint;
});

final orderPrinterProvider = Provider<OrderPrinter>((ref) {
  return ref.watch(printerServiceProvider).printOrder;
});

final class OrderSubmissionResult {
  const OrderSubmissionResult({
    required this.orderId,
    required this.printResult,
  });

  final int orderId;
  final PrintResult printResult;
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

final class CartSelectedOption {
  const CartSelectedOption({
    required this.optionItemId,
    required this.optionGroupId,
    required this.groupName,
    required this.optionName,
    required this.priceDelta,
    required this.groupSortOrder,
    required this.optionSortOrder,
  });

  factory CartSelectedOption.fromResolved(ResolvedProductOption option) {
    return CartSelectedOption(
      optionItemId: option.optionItemId,
      optionGroupId: option.groupId,
      groupName: option.groupName,
      optionName: option.optionName,
      priceDelta: option.priceDelta,
      groupSortOrder: option.groupSortOrder,
      optionSortOrder: option.optionSortOrder,
    );
  }

  final int optionItemId;
  final int optionGroupId;
  final String groupName;
  final String optionName;
  final int priceDelta;
  final int groupSortOrder;
  final int optionSortOrder;
}

final class CartLine {
  factory CartLine({
    required int lineId,
    required int productId,
    required String productName,
    required int baseUnitPrice,
    required int quantity,
    List<CartSelectedOption> selectedOptions = const [],
    String? note,
  }) {
    final canonicalOptions = _canonicalOptions(selectedOptions);
    final normalizedNote = _normalizeNote(note);
    final configuredUnitPrice = _configuredUnitPrice(
      baseUnitPrice,
      canonicalOptions,
    );
    checkedLineTotal(unitPrice: configuredUnitPrice, quantity: quantity);
    return CartLine._(
      lineId: lineId,
      productId: productId,
      productName: productName,
      baseUnitPrice: baseUnitPrice,
      unitPrice: configuredUnitPrice,
      quantity: quantity,
      selectedOptions: List<CartSelectedOption>.unmodifiable(canonicalOptions),
      note: normalizedNote,
    );
  }

  const CartLine._({
    required this.lineId,
    required this.productId,
    required this.productName,
    required this.baseUnitPrice,
    required this.unitPrice,
    required this.quantity,
    required this.selectedOptions,
    required this.note,
  });

  final int lineId;
  final int productId;
  final String productName;
  final int baseUnitPrice;
  final int unitPrice;
  final int quantity;
  final List<CartSelectedOption> selectedOptions;
  final String? note;

  int get lineTotal =>
      checkedLineTotal(unitPrice: unitPrice, quantity: quantity);

  CartLine copyWith({
    int? quantity,
    List<CartSelectedOption>? selectedOptions,
    String? note,
    bool clearNote = false,
  }) {
    return CartLine(
      lineId: lineId,
      productId: productId,
      productName: productName,
      baseUnitPrice: baseUnitPrice,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

final class CartState {
  const CartState({
    required this.submissionToken,
    this.lines = const [],
    this.orderType,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final String submissionToken;
  final List<CartLine> lines;
  final OrderType? orderType;
  final bool isSubmitting;
  final String? errorMessage;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get total =>
      lines.fold(0, (sum, line) => checkedMoneySum(sum, line.lineTotal));

  CartState copyWith({
    String? submissionToken,
    List<CartLine>? lines,
    OrderType? orderType,
    bool clearOrderType = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CartState(
      submissionToken: submissionToken ?? this.submissionToken,
      lines: lines ?? this.lines,
      orderType: clearOrderType ? null : (orderType ?? this.orderType),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final class CartController extends Notifier<CartState> {
  Future<OrderSubmissionResult>? _submission;
  int _nextLineId = 1;

  @override
  CartState build() =>
      CartState(submissionToken: ref.read(cartTokenFactoryProvider)());

  bool addProduct(CatalogProduct product) => addConfiguredProduct(product);

  bool addConfiguredProduct(
    CatalogProduct product, {
    Iterable<ResolvedProductOption> selectedOptions = const [],
    String? note,
  }) {
    if (state.isSubmitting ||
        !product.isAvailable ||
        product.deletedAt != null) {
      return false;
    }
    final reviewedOptions = _reviewedOptionsForProduct(
      product.id,
      selectedOptions,
    );
    final incoming = CartLine(
      lineId: _nextLineId,
      productId: product.id,
      productName: product.name,
      baseUnitPrice: product.price,
      quantity: 1,
      selectedOptions: reviewedOptions,
      note: note,
    );
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (line) => _sameConfiguration(line, incoming),
    );
    if (index < 0) {
      lines.add(incoming);
    } else {
      lines[index] = lines[index].copyWith(quantity: lines[index].quantity + 1);
    }
    _commitLines(lines, clearError: true);
    if (index < 0) _nextLineId++;
    return true;
  }

  void increment(int lineId) {
    if (state.isSubmitting) return;
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.lineId == lineId);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(quantity: lines[index].quantity + 1);
      _commitLines(lines);
    }
  }

  void decrement(int lineId) {
    if (state.isSubmitting) return;
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.lineId == lineId);
    if (index < 0) return;
    if (lines[index].quantity == 1) {
      lines.removeAt(index);
    } else {
      lines[index] = lines[index].copyWith(quantity: lines[index].quantity - 1);
    }
    _commitLines(lines);
  }

  void remove(int lineId) {
    if (state.isSubmitting) return;
    _commitLines(state.lines.where((line) => line.lineId != lineId).toList());
  }

  void setNote(int lineId, String value) {
    if (state.isSubmitting) return;
    final line = state.lines.where((line) => line.lineId == lineId).firstOrNull;
    if (line == null) return;
    _editLine(line, selectedOptions: line.selectedOptions, note: value);
  }

  bool editConfiguration(
    int lineId, {
    required Iterable<ResolvedProductOption> selectedOptions,
    required String? note,
  }) {
    if (state.isSubmitting) return false;
    final line = state.lines.where((line) => line.lineId == lineId).firstOrNull;
    if (line == null) return false;
    final reviewedOptions = _reviewedOptionsForProduct(
      line.productId,
      selectedOptions,
    );
    _editLine(line, selectedOptions: reviewedOptions, note: note);
    return true;
  }

  void _editLine(
    CartLine line, {
    required List<CartSelectedOption> selectedOptions,
    required String? note,
  }) {
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (candidate) => candidate.lineId == line.lineId,
    );
    if (index < 0) return;
    lines[index] = line.copyWith(
      selectedOptions: selectedOptions,
      note: note,
      clearNote: _normalizeNote(note) == null,
    );
    _commitLines(_coalesce(lines));
  }

  void setOrderType(OrderType? value) {
    if (state.isSubmitting) return;
    state = state.copyWith(orderType: value, clearOrderType: value == null);
  }

  void clear() {
    if (state.isSubmitting) return;
    state = CartState(submissionToken: ref.read(cartTokenFactoryProvider)());
  }

  Future<OrderSubmissionResult> submit() {
    final existing = _submission;
    if (existing != null) return existing;
    if (state.lines.isEmpty) {
      return Future.error(const DomainValidationException('Cart is empty.'));
    }
    final submittedToken = state.submissionToken;
    final draft = OrderDraft(
      submissionToken: submittedToken,
      orderType: state.orderType,
      lines: [
        for (final line in state.lines)
          DraftLine(
            productId: line.productId,
            reviewedName: line.productName,
            reviewedBaseUnitPrice: line.baseUnitPrice,
            reviewedUnitPrice: line.unitPrice,
            quantity: line.quantity,
            note: line.note,
            selectedOptions: [
              for (final option in line.selectedOptions)
                DraftSelectedOption(
                  optionItemId: option.optionItemId,
                  optionGroupId: option.optionGroupId,
                  reviewedGroupName: option.groupName,
                  reviewedOptionName: option.optionName,
                  reviewedPriceDelta: option.priceDelta,
                ),
            ],
          ),
      ],
    );
    state = state.copyWith(isSubmitting: true, clearError: true);
    final operation = _performSubmit(draft, submittedToken);
    _submission = operation;
    return operation;
  }

  Future<OrderSubmissionResult> _performSubmit(
    OrderDraft draft,
    String submittedToken,
  ) async {
    try {
      final id = await ref.read(orderSubmitterProvider)(draft);
      if (state.submissionToken == submittedToken) {
        state = CartState(
          submissionToken: ref.read(cartTokenFactoryProvider)(),
          isSubmitting: true,
        );
      }
      ref.invalidate(orderListControllerProvider);
      PrintResult printResult;
      try {
        printResult = await ref.read(orderPrinterProvider)(id);
      } catch (_) {
        printResult = const PrintResult.failed(
          PrinterErrorCode.writeFailed,
          'Đơn đã được lưu nhưng không thể gửi tới máy in.',
        );
      }
      state = state.copyWith(isSubmitting: false);
      return OrderSubmissionResult(orderId: id, printResult: printResult);
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Không thể lưu đơn. Vui lòng thử lại.',
      );
      rethrow;
    } finally {
      _submission = null;
    }
  }

  List<CartSelectedOption> _reviewedOptionsForProduct(
    int productId,
    Iterable<ResolvedProductOption> options,
  ) {
    final reviewed = <CartSelectedOption>[];
    for (final option in options) {
      if (option.productId != productId) {
        throw const DomainValidationException(
          'Selected option belongs to another product.',
        );
      }
      reviewed.add(CartSelectedOption.fromResolved(option));
    }
    return _canonicalOptions(reviewed);
  }

  void _commitLines(List<CartLine> lines, {bool clearError = false}) {
    _checkedCartTotal(lines);
    state = state.copyWith(lines: lines, clearError: clearError);
  }
}

List<CartLine> _coalesce(List<CartLine> lines) {
  final result = <CartLine>[];
  for (final line in lines) {
    final existingIndex = result.indexWhere(
      (candidate) => _sameConfiguration(candidate, line),
    );
    if (existingIndex < 0) {
      result.add(line);
    } else {
      final existing = result[existingIndex];
      result[existingIndex] = existing.copyWith(
        quantity: existing.quantity + line.quantity,
      );
    }
  }
  _checkedCartTotal(result);
  return result;
}

bool _sameConfiguration(CartLine left, CartLine right) {
  if (left.productId != right.productId ||
      left.productName != right.productName ||
      left.baseUnitPrice != right.baseUnitPrice ||
      left.note != right.note ||
      left.selectedOptions.length != right.selectedOptions.length) {
    return false;
  }
  for (var index = 0; index < left.selectedOptions.length; index++) {
    if (!_sameOption(
      left.selectedOptions[index],
      right.selectedOptions[index],
    )) {
      return false;
    }
  }
  return true;
}

bool _sameOption(CartSelectedOption left, CartSelectedOption right) {
  return left.optionItemId == right.optionItemId &&
      left.optionGroupId == right.optionGroupId &&
      left.groupName == right.groupName &&
      left.optionName == right.optionName &&
      left.priceDelta == right.priceDelta &&
      left.groupSortOrder == right.groupSortOrder &&
      left.optionSortOrder == right.optionSortOrder;
}

List<CartSelectedOption> _canonicalOptions(
  Iterable<CartSelectedOption> options,
) {
  final result = options.toList(growable: false);
  final ids = result.map((option) => option.optionItemId).toSet();
  if (ids.length != result.length) {
    throw const DomainValidationException(
      'Selected options cannot contain duplicates.',
    );
  }
  result.sort((left, right) {
    final groupOrder = left.groupSortOrder.compareTo(right.groupSortOrder);
    if (groupOrder != 0) return groupOrder;
    final groupId = left.optionGroupId.compareTo(right.optionGroupId);
    if (groupId != 0) return groupId;
    final optionOrder = left.optionSortOrder.compareTo(right.optionSortOrder);
    if (optionOrder != 0) return optionOrder;
    return left.optionItemId.compareTo(right.optionItemId);
  });
  return result;
}

int _configuredUnitPrice(
  int baseUnitPrice,
  Iterable<CartSelectedOption> options,
) {
  var result = baseUnitPrice;
  for (final option in options) {
    result = checkedMoneySum(result, option.priceDelta);
  }
  return result;
}

int _checkedCartTotal(Iterable<CartLine> lines) {
  var result = 0;
  for (final line in lines) {
    result = checkedMoneySum(result, line.lineTotal);
  }
  return result;
}

String? _normalizeNote(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
