import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/products/category_management_screen.dart';
import '../features/products/product_form_screen.dart';
import '../features/products/option_management_screen.dart';
import '../features/products/product_reorder_screen.dart';
import '../features/products/products_screen.dart';
import '../features/revenue/revenue_screen.dart';
import '../features/orders/order_details_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/sales/review_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/settings/printer_settings_screen.dart';
import '../features/settings/backup_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/shop_settings_screen.dart';
import 'theme.dart';
import 'design_system.dart';

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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          for (final destination in _destinations)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: destination.path,
                  pageBuilder: (context, state) => NoTransitionPage<void>(
                    key: ValueKey(destination.path),
                    child: switch (destination.path) {
                      '/sales' => const SalesScreen(),
                      '/orders' => const OrdersScreen(),
                      '/revenue' => const RevenueScreen(),
                      '/products' => const ProductsScreen(),
                      '/settings' => const SettingsScreen(),
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
        path: '/settings/printer',
        builder: (context, state) => const PrinterSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/shop',
        builder: (context, state) => const ShopSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupScreen(),
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
      GoRoute(
        path: '/products/reorder',
        builder: (context, state) => const ProductReorderScreen(),
      ),
      GoRoute(
        path: '/products/options/:id',
        builder: (context, state) => OptionGroupDetailScreen(
          groupId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = navigationShell.currentIndex;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const SizedBox.square(
                dimension: 44,
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(_destinations[selectedIndex].label),
          ],
        ),
      ),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: NavigationBar(
          animationDuration: AppMotion.duration(context, AppMotion.navigation),
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == selectedIndex,
          ),
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.icon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}
