import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
  ];
}

@TableIndex(
  name: 'products_category_deleted_available',
  columns: {#categoryId, #deletedAt, #isAvailable},
)
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get price => integer()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
    'CHECK (price >= 0)',
  ];
}

class OptionGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
  ];
}

@TableIndex(
  name: 'option_items_group_active_order',
  columns: {#groupId, #isActive, #sortOrder},
)
class OptionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(OptionGroups, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text()();
  IntColumn get priceDelta => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(name)) > 0)',
    'CHECK (price_delta >= 0)',
  ];
}

class ProductOptionGroups extends Table {
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get optionGroupId =>
      integer().references(OptionGroups, #id, onDelete: KeyAction.restrict)();

  @override
  Set<Column<Object>> get primaryKey => {productId, optionGroupId};
}

@TableIndex(name: 'orders_status_created', columns: {#status, #createdAt})
@TableIndex(name: 'orders_paid_at', columns: {#paidAt})
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderNumber => integer().unique()();
  TextColumn get submissionToken => text().unique()();
  TextColumn get orderType => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('UNPAID'))();
  IntColumn get subtotal => integer()();
  IntColumn get total => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get paidAt => integer().nullable()();
  IntColumn get cancelledAt => integer().nullable()();
  IntColumn get printedAt => integer().nullable()();
  IntColumn get printCount => integer().withDefault(const Constant(0))();
  TextColumn get cancellationReason => text().nullable()();
  TextColumn get receiptSettingsSnapshot => text()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (order_number > 0)',
    'CHECK (length(trim(submission_token)) > 0)',
    "CHECK (order_type IS NULL OR order_type IN ('DINE_IN', 'TAKEAWAY'))",
    "CHECK (status IN ('UNPAID', 'PAID', 'CANCELLED'))",
    'CHECK (subtotal >= 0)',
    'CHECK (total >= 0)',
    'CHECK (total = subtotal)',
    'CHECK (print_count >= 0)',
    'CHECK (length(receipt_settings_snapshot) > 0)',
  ];
}

@TableIndex(name: 'order_items_order_id', columns: {#orderId})
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId =>
      integer().references(Orders, #id, onDelete: KeyAction.restrict)();
  IntColumn get productId => integer().nullable().references(
    Products,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get productNameSnapshot => text()();
  late final IntColumn baseUnitPriceSnapshot = integer()
      // ignore: recursive_getters
      .check(baseUnitPriceSnapshot.isBiggerOrEqualValue(0))
      .withDefault(const Constant(0))();
  IntColumn get unitPriceSnapshot => integer()();
  IntColumn get quantity => integer()();
  TextColumn get note => text().nullable()();
  IntColumn get lineTotal => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(product_name_snapshot)) > 0)',
    'CHECK (unit_price_snapshot >= 0)',
    'CHECK (quantity > 0)',
    'CHECK (line_total >= 0)',
    'CHECK (line_total = unit_price_snapshot * quantity)',
  ];
}

@TableIndex(
  name: 'order_item_options_order_display',
  columns: {#orderItemId, #displayOrder},
  unique: true,
)
class OrderItemOptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderItemId =>
      integer().references(OrderItems, #id, onDelete: KeyAction.restrict)();
  IntColumn get optionItemId => integer().nullable().references(
    OptionItems,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get groupNameSnapshot => text()();
  TextColumn get optionNameSnapshot => text()();
  IntColumn get priceDeltaSnapshot => integer()();
  IntColumn get displayOrder => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim(group_name_snapshot)) > 0)',
    'CHECK (length(trim(option_name_snapshot)) > 0)',
    'CHECK (price_delta_snapshot >= 0)',
  ];
}

@TableIndex(
  name: 'print_attempts_order_attempted',
  columns: {#orderId, #attemptedAt},
)
class PrintAttempts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId =>
      integer().references(Orders, #id, onDelete: KeyAction.restrict)();
  IntColumn get attemptedAt => integer()();
  BoolColumn get success => boolean()();
  TextColumn get errorMessage => text().nullable()();
}

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get shopName => text().withDefault(const Constant(''))();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get receiptFooter => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>['CHECK (id = 1)'];
}

class PrinterSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get printerName => text().nullable()();
  TextColumn get printerAddress => text().nullable()();
  BoolColumn get autoReconnect => boolean().withDefault(const Constant(true))();
  BoolColumn get autoPrint => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => <String>['CHECK (id = 1)'];
}
