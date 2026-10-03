import 'package:dakao_in_bill/app/app.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the branded shell and navigates all five destinations', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const DakaoInBillApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bán hàng'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in [
      'Bán hàng',
      'Đơn hàng',
      'Doanh thu',
      'Món',
      'Cài đặt',
    ]) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      switch (label) {
        case 'Bán hàng':
          expect(find.byKey(const Key('sales-search')), findsOneWidget);
        case 'Đơn hàng':
          expect(find.byKey(const Key('orders-filter')), findsOneWidget);
        case 'Doanh thu':
          expect(find.byKey(const Key('recognized-revenue')), findsOneWidget);
        case 'Món':
          expect(find.byKey(const Key('catalog-search')), findsOneWidget);
        case 'Cài đặt':
          expect(
            find.byKey(const Key('open-printer-settings')),
            findsOneWidget,
          );
        default:
          expect(
            tester
                .widget<Text>(find.byKey(const Key('destination-title')))
                .data,
            label,
          );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
