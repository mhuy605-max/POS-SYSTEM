import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            appBar: AppBar(title: const Text('Đakao In Bill')),
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
                // Stage 0 route targets only, not prototype screen designs.
                child: Center(
                  child: Text(
                    destination.label,
                    key: const Key('destination-title'),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
