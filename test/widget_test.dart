import 'package:dakao_in_bill/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the branded shell and navigates all five destinations', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Đakao In Bill'), findsOneWidget);
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
      expect(
        tester.widget<Text>(find.byKey(const Key('destination-title'))).data,
        label,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
