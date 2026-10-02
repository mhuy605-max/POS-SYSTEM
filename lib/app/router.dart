import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/products/category_management_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/products_screen.dart';
import '../features/orders/order_details_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/sales/review_screen.dart';
import '../features/sales/sales_screen.dart';

const _destinations = [
  (path: '/sales', label: 'Bán hàng', icon: Icons.point_of_sale_outlined),
  (path: '/orders', label: 'Đơn hàng', icon: Icons.receipt_long_outlined),
  (path: '/revenue', label: 'Doanh thu', icon: Icons.bar_chart_outlined),
  (path: '/products', label: 'Món', icon: Icons.restaurant_outlined),
  (path: '/settings', label: 'Cài đặt', icon: Icons.settings_outlined),
];

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/sales',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final selectedIndex = _destinations.indexWhere(
            (destination) => destination.path == state.uri.path,
          );
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(Icons.receipt_long_outlined, size: 24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    selectedIndex < 0
                        ? 'Đakao In Bill'
                        : _destinations[selectedIndex].label,
                  ),
                ],
              ),
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) {
                context.go(_destinations[index].path);
              },
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
              ],
            ),
          );
        },
        routes: [
          for (final destination in _destinations)
            GoRoute(
              path: destination.path,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: switch (destination.path) {
                  '/sales' => const SalesScreen(),
                  '/orders' => const OrdersScreen(),
                  '/products' => const ProductsScreen(),
                  _ => Center(
                    child: Text(
                      destination.label,
                      key: const Key('destination-title'),
                    ),
                  ),
                },
              ),
            ),
        ],
      ),
      GoRoute(
        path: '/sales/current',
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) =>
            OrderDetailsScreen(orderId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/products/add',
        builder: (context, state) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/:id/edit',
        builder: (context, state) => ProductFormScreen(
          productId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/products/categories',
        builder: (context, state) => const CategoryManagementScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
