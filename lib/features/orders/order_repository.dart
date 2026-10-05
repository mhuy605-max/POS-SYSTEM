import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/money.dart';
import '../../data/app_database.dart';
import '../products/product_option_repository.dart';

enum OrderStatus { unpaid, paid, cancelled }

enum OrderType { dineIn, takeaway }

final class DraftSelectedOption {
  const DraftSelectedOption({
    required this.optionItemId,
    required this.optionGroupId,
    required this.reviewedGroupName,
    required this.reviewedOptionName,
    required this.reviewedPriceDelta,
  });

  final int optionItemId;
  final int optionGroupId;
  final String reviewedGroupName;
  final String reviewedOptionName;
  final int reviewedPriceDelta;
}

final class DraftLine {
  const DraftLine({
    required this.productId,
    required this.reviewedName,
    required this.reviewedUnitPrice,
    required this.quantity,
    this.reviewedBaseUnitPrice,
    this.selectedOptions = const [],
    this.note,
  });

  final int? productId;
  final String reviewedName;
  final int? reviewedBaseUnitPrice;
  final int reviewedUnitPrice;
  final num quantity;
  final List<DraftSelectedOption> selectedOptions;
  final String? note;

  int get reviewedBasePrice => reviewedBaseUnitPrice ?? reviewedUnitPrice;
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

final class SavedOrderOption {
  const SavedOrderOption({
    required this.id,
    required this.optionItemId,
    required this.groupName,
    required this.optionName,
    required this.priceDelta,
    required this.displayOrder,
  });

  final int id;
  final int? optionItemId;
  final String groupName;
  final String optionName;
  final int priceDelta;
  final int displayOrder;
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
    int? baseUnitPrice,
    this.options = const [],
  }) : baseUnitPrice = baseUnitPrice ?? unitPrice;

  final int id;
  final int? productId;
  final String productName;
  final int baseUnitPrice;
  final int unitPrice;
  final int quantity;
  final String? note;
  final int lineTotal;
  final List<SavedOrderOption> options;
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
  OrderRepository(
    this._database, {
    required EpochClock nowEpochMillis,
    ProductOptionRepository? productOptionRepository,
  }) : _nowEpochMillis = nowEpochMillis,
       _productOptions =
           productOptionRepository ??
           ProductOptionRepository(_database, nowEpochMillis);

  final AppDatabase _database;
  final EpochClock _nowEpochMillis;
  final ProductOptionRepository _productOptions;

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
      final checkedLines =
          <
            ({
              DraftLine source,
              int quantity,
              int baseUnitPrice,
              int configuredUnitPrice,
              int total,
              List<ResolvedProductOption> options,
            })
          >[];
      for (final line in draft.lines) {
        final name = line.reviewedName.trim();
        if (name.isEmpty) {
          throw const DomainValidationException('Product name is required.');
        }
        final baseUnitPrice = line.reviewedBasePrice;
        await _verifyReviewedProduct(line, name, baseUnitPrice);
        final resolvedOptions = await _validateSelectedOptions(line);
        var configuredUnitPrice = baseUnitPrice;
        for (final option in resolvedOptions) {
          configuredUnitPrice = checkedMoneySum(
            configuredUnitPrice,
            option.priceDelta,
          );
        }
        if (line.reviewedUnitPrice != configuredUnitPrice) {
          throw const DomainValidationException(
            'Configured price changed after review; review the order again.',
          );
        }
        final lineTotal = checkedLineTotal(
          unitPrice: configuredUnitPrice,
          quantity: line.quantity,
        );
        subtotal = checkedMoneySum(subtotal, lineTotal);
        final quantity = line.quantity as int;
        checkedLines.add((
          source: line,
          quantity: quantity,
          baseUnitPrice: baseUnitPrice,
          configuredUnitPrice: configuredUnitPrice,
          total: lineTotal,
          options: resolvedOptions,
        ));
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
        final orderItemId = await _database
            .into(_database.orderItems)
            .insert(
              OrderItemsCompanion.insert(
                orderId: orderId,
                productId: Value(line.source.productId),
                productNameSnapshot: line.source.reviewedName.trim(),
                baseUnitPriceSnapshot: Value(line.baseUnitPrice),
                unitPriceSnapshot: line.configuredUnitPrice,
                quantity: line.quantity,
                note: Value(line.source.note),
                lineTotal: line.total,
              ),
            );
        for (var index = 0; index < line.options.length; index++) {
          final option = line.options[index];
          await _database
              .into(_database.orderItemOptions)
              .insert(
                OrderItemOptionsCompanion.insert(
                  orderItemId: orderItemId,
                  optionItemId: Value(option.optionItemId),
                  groupNameSnapshot: option.groupName,
                  optionNameSnapshot: option.optionName,
                  priceDeltaSnapshot: option.priceDelta,
                  displayOrder: index,
                ),
              );
        }
      }
      return orderId;
    });
  }

  Future<void> _verifyReviewedProduct(
    DraftLine line,
    String reviewedName,
    int reviewedBaseUnitPrice,
  ) async {
    final productId = line.productId;
    if (productId == null) {
      if (line.selectedOptions.isNotEmpty) {
        throw const DomainValidationException(
          'Selected options require a current product.',
        );
      }
      return;
    }
    final product = await (_database.select(
      _database.products,
    )..where((row) => row.id.equals(productId))).getSingleOrNull();
    if (product == null ||
        product.deletedAt != null ||
        !product.isAvailable ||
        product.name != reviewedName ||
        product.price != reviewedBaseUnitPrice) {
      throw const DomainValidationException(
        'Product changed after review; review the order again.',
      );
    }
  }

  Future<List<ResolvedProductOption>> _validateSelectedOptions(
    DraftLine line,
  ) async {
    if (line.selectedOptions.isEmpty) return const [];
    final productId = line.productId;
    if (productId == null) {
      throw const DomainValidationException(
        'Selected options require a current product.',
      );
    }
    final resolved = await _productOptions.resolveSelectableOptions(
      productId,
      line.selectedOptions.map((option) => option.optionItemId).toList(),
    );
    final reviewedById = <int, DraftSelectedOption>{
      for (final option in line.selectedOptions) option.optionItemId: option,
    };
    for (final current in resolved) {
      final reviewed = reviewedById[current.optionItemId];
      if (reviewed == null ||
          reviewed.optionGroupId != current.groupId ||
          reviewed.reviewedGroupName != current.groupName ||
          reviewed.reviewedOptionName != current.optionName ||
          reviewed.reviewedPriceDelta != current.priceDelta) {
        throw const DomainValidationException(
          'Option changed after review; review the order again.',
        );
      }
    }
    return resolved;
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
    final optionRows = itemRows.isEmpty
        ? const <OrderItemOption>[]
        : await (_database.select(_database.orderItemOptions)
                ..where(
                  (row) =>
                      row.orderItemId.isIn(itemRows.map((item) => item.id)),
                )
                ..orderBy([
                  (row) => OrderingTerm.asc(row.displayOrder),
                  (row) => OrderingTerm.asc(row.id),
                ]))
              .get();
    final optionsByItem = <int, List<SavedOrderOption>>{};
    for (final option in optionRows) {
      optionsByItem
          .putIfAbsent(option.orderItemId, () => <SavedOrderOption>[])
          .add(
            SavedOrderOption(
              id: option.id,
              optionItemId: option.optionItemId,
              groupName: option.groupNameSnapshot,
              optionName: option.optionNameSnapshot,
              priceDelta: option.priceDeltaSnapshot,
              displayOrder: option.displayOrder,
            ),
          );
    }

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
              baseUnitPrice: item.baseUnitPriceSnapshot,
              unitPrice: item.unitPriceSnapshot,
              quantity: item.quantity,
              note: item.note,
              lineTotal: item.lineTotal,
              options: List<SavedOrderOption>.unmodifiable(
                optionsByItem[item.id] ?? const [],
              ),
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
