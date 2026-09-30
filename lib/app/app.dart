import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class DakaoInBillApp extends ConsumerWidget {
  const DakaoInBillApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Đakao In Bill',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
