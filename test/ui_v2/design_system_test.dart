import 'package:dakao_in_bill/app/design_system.dart';
import 'package:dakao_in_bill/app/theme.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/orders/order_repository.dart';
import 'package:dakao_in_bill/features/orders/orders_screen.dart';
import 'package:dakao_in_bill/features/revenue/revenue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

void main() {
  test('warm utility palette keeps brand and semantic colors distinct', () {
    expect(AppColors.primary, const Color(0xFFB9470B));
    expect(AppColors.primaryStrong, const Color(0xFF923607));
    expect(AppColors.primarySoft, const Color(0xFFFBE9DE));
    expect(AppColors.canvas, const Color(0xFFFAF8F5));
    expect(AppColors.surfaceLow, const Color(0xFFF3F0EB));
    expect(AppColors.ink, const Color(0xFF211F1D));
    expect(AppColors.secondaryInk, const Color(0xFF716C66));
    expect(AppColors.outline, const Color(0xFFE8E2DC));
    expect(AppColors.success, const Color(0xFF3D7654));
    expect(AppColors.error, const Color(0xFFAF443B));
    expect(AppColors.warning, isNot(AppColors.success));
    expect(AppColors.warning, isNot(AppColors.primary));
  });

  test('status foregrounds meet normal-text contrast on soft surfaces', () {
    expect(
      _contrast(AppColors.success, AppColors.successSoft),
      greaterThan(4.5),
    );
    expect(_contrast(AppColors.error, AppColors.errorSoft), greaterThan(4.5));
    expect(
      _contrast(AppColors.warning, AppColors.warningSoft),
      greaterThan(4.5),
    );
  });

  testWidgets('order status badges use semantic status colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const Scaffold(
          body: Column(
            children: [
              OrderStatusBadge(key: Key('unpaid'), status: OrderStatus.unpaid),
              OrderStatusBadge(key: Key('paid'), status: OrderStatus.paid),
              OrderStatusBadge(
                key: Key('cancelled'),
                status: OrderStatus.cancelled,
              ),
            ],
          ),
        ),
      ),
    );

    Color background(String key) => tester
        .widget<AnimatedContainer>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .decoration
        .let((value) => value as BoxDecoration)
        .color!;

    expect(background('unpaid'), AppColors.warningSoft);
    expect(background('paid'), AppColors.successSoft);
    expect(background('cancelled'), AppColors.errorSoft);
  });

  testWidgets('empty state keeps its action reachable at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.restaurant_outlined,
            title: 'Chưa có món nào',
            message: 'Thêm món đầu tiên để bắt đầu bán hàng.',
            actionLabel: 'Thêm món đầu tiên',
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.text('Chưa có món nào'), findsOneWidget);
    expect(find.text('Thêm món đầu tiên để bắt đầu bán hàng.'), findsOneWidget);
    final action = tester.getSize(
      find.ancestor(
        of: find.text('Thêm món đầu tiên'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(action.height, greaterThanOrEqualTo(AppSizes.touchTarget));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state remains usable with larger system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Chưa có đơn hàng nào',
            message:
                'Đơn hàng mới sẽ xuất hiện ở đây sau khi bạn lưu và in bill.',
            actionLabel: 'Quay lại bán hàng',
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.text('Chưa có đơn hàng nào'), findsOneWidget);
    expect(find.text('Quay lại bán hàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion resolves transition duration to zero', (
    tester,
  ) async {
    late Duration duration;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            duration = AppMotion.duration(context, AppMotion.standard);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(duration, Duration.zero);
  });

  testWidgets('revenue period selection uses brand color', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: appTheme,
          home: const Scaffold(body: RevenueScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selected = tester.widget<ChoiceChip>(
      find
          .byWidgetPredicate(
            (widget) => widget is ChoiceChip && widget.selected,
          )
          .first,
    );
    expect(selected.selectedColor, AppColors.primarySoft);
    expect(selected.selectedColor, isNot(AppColors.successSoft));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + .05) / (darker.computeLuminance() + .05);
}
