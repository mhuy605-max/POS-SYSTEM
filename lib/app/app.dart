import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_system.dart';
import 'router.dart';
import 'theme.dart';

class DakaoInBillApp extends ConsumerWidget {
  const DakaoInBillApp({this.animateEntrance = false, super.key});

  final bool animateEntrance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Đakao In Bill',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => _AppEntrance(
        animate: animateEntrance,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _AppEntrance extends StatelessWidget {
  const _AppEntrance({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!animate || reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.startup,
      curve: AppMotion.curve,
      child: child,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
    );
  }
}
