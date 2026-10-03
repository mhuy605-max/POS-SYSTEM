import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/money.dart';
import '../../data/app_database.dart';

enum OrderStatus { unpaid, paid, cancelled }

enum OrderType { dineIn, takeaway }

final class DraftLine {
  const DraftLine({
    required this.productId,
    required this.reviewedName,
    required this.reviewedUnitPrice,
    required this.quantity,
    this.note,
  });

  final int? productId;
  final String reviewedName;
  final int reviewedUnitPrice;
  final num quantity;
  final String? note;
}

final class OrderDraft {
  const OrderDraft({
    required this.submissionToken,
    required this.lines,
    this.orderType,
  });

  final String submissionToken;
  final OrderType? orderType;
  final List<DraftLine> lines;
}

/// Version 1 is a JSON object containing the four shop fields below.
///
/// The version travels with every order so future schema changes can decode
/// old receipts without consulting mutable app settings.
final class ReceiptSettingsSnapshot {
  const ReceiptSettingsSnapshot({
    required this.version,
    required this.shopName,
    required this.address,
    required this.phone,
    required this.footer,
  });

  factory ReceiptSettingsSnapshot.fromJson(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?> || value['version'] != 1) {
      throw const FormatException('Unsupported receipt settings snapshot.');
    }
    return ReceiptSettingsSnapshot(
      version: 1,
      shopName: value['shopName'] as String,
      address: value['address'] as String,
      phone: value['phone'] as String,
      footer: value['footer'] as String,
    );
  }

  final int version;
  final String shopName;
  final String address;
  final String phone;
  final String footer;

  String toJson() => jsonEncode(<String, Object>{
    'version': version,
    'shopName': shopName,
    'address': address,
    'phone': phone,
    'footer': footer,
  });
}

final class SavedOrderItem {
  const SavedOrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.note,
    required this.lineTotal,
  });

  final int id;
  final int? productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final String? note;
  final int lineTotal;
}

final class SavedOrder {
  const SavedOrder({
    required this.id,
    required this.orderNumber,
    required this.submissionToken,
    required this.orderType,
    required this.status,
    required this.subtotal,
    required this.total,
    required this.createdAt,
    required this.paidAt,
    required this.cancelledAt,
    required this.cancellationReason,
    required this.receiptSettings,
    required this.items,
  });

  final int id;
  final int orderNumber;
  final String submissionToken;
  final OrderType? orderType;
  final OrderStatus status;
  final int subtotal;
  final int total;
  final int createdAt;
  final int? paidAt;
  final int? cancelledAt;
  final String? cancellationReason;
  final ReceiptSettingsSnapshot receiptSettings;
  final List<SavedOrderItem> items;
}

typedef EpochClock = int Function();

final class OrderRepository {
  OrderRepository(this._database, {required this._nowEpochMillis});

  final AppDatabase _database;
  final EpochClock _nowEpochMillis;

  Future<int> createOrder(OrderDraft draft) {
    return _database.transaction(() async {
      final existing =
          await (_database.select(_database.orders)..where(
                (row) => row.submissionToken.equals(draft.submissionToken),
              ))
              .getSingleOrNull();
      if (existing != null) {
        return existing.id;
      }

      if (draft.submissionToken.trim().isEmpty) {
        throw const DomainValidationException('Submission token is required.');
      }
      if (draft.lines.isEmpty) {
        throw const DomainValidationException('An order requires an item.');
      }

      var subtotal = 0;
      final checkedLines = <({DraftLine source, int quantity, int total})>[];
      for (final line in draft.lines) {
        final name = line.reviewedName.trim();
        if (name.isEmpty) {
          throw const DomainValidationException('Product name is required.');
        }
        final lineTotal = checkedLineTotal(
          unitPrice: line.reviewedUnitPrice,
          quantity: line.quantity,
        );
        subtotal = checkedMoneySum(subtotal, lineTotal);
        final quantity = line.quantity as int;
        await _verifyReviewedProduct(line, name);
        checkedLines.add((source: line, quantity: quantity, total: lineTotal));
      }

      final maxRow = await _database
          .customSelect(
            'SELECT MAX(order_number) AS max_number FROM orders',
            readsFrom: {_database.orders},
          )
          .getSingle();
      final maxNumber = maxRow.readNullable<int>('max_number') ?? 0;
      final orderNumber = checkedMoneySum(maxNumber, 1);

      final settings = await (_database.select(
        _database.appSettings,
      )..where((row) => row.id.equals(1))).getSingle();
      final receiptSnapshot = ReceiptSettingsSnapshot(
        version: 1,
        shopName: settings.shopName,
        address: settings.address,
        phone: settings.phone,
        footer: settings.receiptFooter,
      );

      final orderId = await _database
          .into(_database.orders)
          .insert(
            OrdersCompanion.insert(
              orderNumber: orderNumber,
              submissionToken: draft.submissionToken,
              orderType: Value(_orderTypeToStorage(draft.orderType)),
              subtotal: subtotal,
              total: subtotal,
              createdAt: _nowEpochMillis(),
              receiptSettingsSnapshot: receiptSnapshot.toJson(),
            ),
          );

      for (final line in checkedLines) {
        await _database
            .into(_database.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                orderId: orderId,
                productId: Value(line.source.productId),
                productNameSnapshot: line.source.reviewedName.trim(),
                unitPriceSnapshot: line.source.reviewedUnitPrice,
                quantity: line.quantity,
                note: Value(line.source.note),
                lineTotal: line.total,
              ),
            );
      }
      return orderId;
    });
  }

  Future<void> _verifyReviewedProduct(
    DraftLine line,
    String reviewedName,
  ) async {
    final productId = line.productId;
    if (productId == null) {
      return;
    }
    final product = await (_database.select(
      _database.products,
    )..where((row) => row.id.equals(productId))).getSingleOrNull();
    if (product == null ||
        product.deletedAt != null ||
        !product.isAvailable ||
        product.name != reviewedName ||
        product.price != line.reviewedUnitPrice) {
      throw const DomainValidationException(
        'Product changed after review; review the order again.',
      );
    }
  }

  Future<SavedOrder> loadOrder(int id) async {
    final order = await (_database.select(
      _database.orders,
    )..where((row) => row.id.equals(id))).getSingle();
    final itemRows =
        await (_database.select(_database.orderItems)
              ..where((row) => row.orderId.equals(id))
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();

    return SavedOrder(
      id: order.id,
      orderNumber: order.orderNumber,
      submissionToken: order.submissionToken,
      orderType: _orderTypeFromStorage(order.orderType),
      status: _statusFromStorage(order.status),
      subtotal: order.subtotal,
      total: order.total,
      createdAt: order.createdAt,
      paidAt: order.paidAt,
      cancelledAt: order.cancelledAt,
      cancellationReason: order.cancellationReason,
      receiptSettings: ReceiptSettingsSnapshot.fromJson(
        order.receiptSettingsSnapshot,
      ),
      items: itemRows
          .map(
            (item) => SavedOrderItem(
              id: item.id,
              productId: item.productId,
              productName: item.productNameSnapshot,
              unitPrice: item.unitPriceSnapshot,
              quantity: item.quantity,
              note: item.note,
              lineTotal: item.lineTotal,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<List<SavedOrder>> listOrders({OrderStatus? status}) async {
    final query = _database.select(_database.orders)
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    if (status != null) {
      query.where((row) => row.status.equals(_statusToStorage(status)));
    }
    final rows = await query.get();
    return Future.wait(rows.map((row) => loadOrder(row.id)));
  }
}

String? _orderTypeToStorage(OrderType? type) => switch (type) {
  OrderType.dineIn => 'DINE_IN',
  OrderType.takeaway => 'TAKEAWAY',
  null => null,
};

OrderType? _orderTypeFromStorage(String? value) => switch (value) {
  'DINE_IN' => OrderType.dineIn,
  'TAKEAWAY' => OrderType.takeaway,
  null => null,
  _ => throw StateError('Unknown order type: $value'),
};

OrderStatus _statusFromStorage(String value) => switch (value) {
  'UNPAID' => OrderStatus.unpaid,
  'PAID' => OrderStatus.paid,
  'CANCELLED' => OrderStatus.cancelled,
  _ => throw StateError('Unknown order status: $value'),
};

String _statusToStorage(OrderStatus status) => switch (status) {
  OrderStatus.unpaid => 'UNPAID',
  OrderStatus.paid => 'PAID',
  OrderStatus.cancelled => 'CANCELLED',
};
