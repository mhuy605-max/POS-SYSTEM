import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../orders/order_providers.dart';
import '../orders/order_repository.dart';
import '../products/product_repository.dart';

typedef CartTokenFactory = String Function();
typedef OrderSubmitter = Future<int> Function(OrderDraft draft);

final cartTokenFactoryProvider = Provider<CartTokenFactory>((ref) {
  final random = Random.secure();
  return () =>
      '${DateTime.now().microsecondsSinceEpoch}-'
      '${random.nextInt(0x7fffffff).toRadixString(16)}';
});

final orderSubmitterProvider = Provider<OrderSubmitter>((ref) {
  return ref.watch(orderServiceProvider).submitForPrint;
});

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

final class CartLine {
  const CartLine({
    required this.lineId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.note,
  });

  final int lineId;
  final int productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final String? note;

  int get lineTotal =>
      checkedLineTotal(unitPrice: unitPrice, quantity: quantity);

  CartLine copyWith({int? quantity, String? note, bool clearNote = false}) {
    return CartLine(
      lineId: lineId,
      productId: productId,
      productName: productName,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
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
  Future<int>? _submission;
  int _nextLineId = 1;

  @override
  CartState build() =>
      CartState(submissionToken: ref.read(cartTokenFactoryProvider)());

  bool addProduct(CatalogProduct product) {
    if (state.isSubmitting ||
        !product.isAvailable ||
        product.deletedAt != null) {
      return false;
    }
    final lines = [...state.lines];
    final index = lines.indexWhere(
      (line) => line.productId == product.id && line.note == null,
    );
    if (index < 0) {
      lines.add(
        CartLine(
          lineId: _nextLineId++,
          productId: product.id,
          productName: product.name,
          unitPrice: product.price,
          quantity: 1,
        ),
      );
    } else {
      lines[index] = lines[index].copyWith(quantity: lines[index].quantity + 1);
    }
    state = state.copyWith(lines: lines, clearError: true);
    return true;
  }

  void increment(int lineId) {
    if (state.isSubmitting) return;
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.lineId == lineId);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(quantity: lines[index].quantity + 1);
      state = state.copyWith(lines: lines);
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
    state = state.copyWith(lines: lines);
  }

  void remove(int lineId) {
    if (state.isSubmitting) return;
    state = state.copyWith(
      lines: state.lines.where((line) => line.lineId != lineId).toList(),
    );
  }

  void setNote(int lineId, String value) {
    if (state.isSubmitting) return;
    final lines = [...state.lines];
    final index = lines.indexWhere((line) => line.lineId == lineId);
    if (index < 0) return;
    final normalized = value.trim();
    lines[index] = lines[index].copyWith(
      note: normalized,
      clearNote: normalized.isEmpty,
    );
    state = state.copyWith(lines: lines);
  }

  void setOrderType(OrderType? value) {
    if (state.isSubmitting) return;
    state = state.copyWith(orderType: value, clearOrderType: value == null);
  }

  void clear() {
    if (state.isSubmitting) return;
    state = CartState(submissionToken: ref.read(cartTokenFactoryProvider)());
  }

  Future<int> submit() {
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
            reviewedUnitPrice: line.unitPrice,
            quantity: line.quantity,
            note: line.note,
          ),
      ],
    );
    state = state.copyWith(isSubmitting: true, clearError: true);
    final operation = _performSubmit(draft, submittedToken);
    _submission = operation;
    return operation;
  }

  Future<int> _performSubmit(OrderDraft draft, String submittedToken) async {
    try {
      final id = await ref.read(orderSubmitterProvider)(draft);
      if (state.submissionToken == submittedToken) {
        state = CartState(
          submissionToken: ref.read(cartTokenFactoryProvider)(),
        );
      }
      ref.invalidate(orderListControllerProvider);
      return id;
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
}
