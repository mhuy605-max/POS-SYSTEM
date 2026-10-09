final class BackupCanonicalUpgrader {
  const BackupCanonicalUpgrader._();

  static Map<String, Object?> v1ToV2(Map<String, Object?> source) {
    final sourceTables = source['tables']! as Map<String, Object?>;

    List<Object?> copyRows(String table) => <Object?>[
      for (final rawRow in sourceTables[table]! as List<Object?>)
        <String, Object?>{...rawRow! as Map<String, Object?>},
    ];

    final products = <Map<String, Object?>>[
      for (final rawRow in sourceTables['products']! as List<Object?>)
        <String, Object?>{...rawRow! as Map<String, Object?>},
    ];
    final ordering = [...products]
      ..sort((left, right) {
        final bySortOrder = (left['sort_order']! as int).compareTo(
          right['sort_order']! as int,
        );
        return bySortOrder != 0
            ? bySortOrder
            : (left['id']! as int).compareTo(right['id']! as int);
      });
    for (var index = 0; index < ordering.length; index += 1) {
      ordering[index]['sort_order'] = index;
    }
    products.sort(
      (left, right) => (left['id']! as int).compareTo(right['id']! as int),
    );

    final orderItems = <Object?>[
      for (final rawRow in sourceTables['order_items']! as List<Object?>)
        <String, Object?>{
          ...rawRow! as Map<String, Object?>,
          'base_unit_price_snapshot':
              (rawRow as Map<String, Object?>)['unit_price_snapshot'],
        },
    ];

    return <String, Object?>{
      'tables': <String, Object?>{
        'categories': copyRows('categories'),
        'products': products,
        'option_groups': <Object?>[],
        'option_items': <Object?>[],
        'product_option_groups': <Object?>[],
        'orders': copyRows('orders'),
        'order_items': orderItems,
        'order_item_options': <Object?>[],
        'print_attempts': copyRows('print_attempts'),
        'app_settings': copyRows('app_settings'),
        'printer_settings': copyRows('printer_settings'),
      },
    };
  }
}
