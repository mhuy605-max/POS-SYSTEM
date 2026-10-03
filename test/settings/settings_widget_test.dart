import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/data/database_provider.dart';
import 'package:dakao_in_bill/features/settings/settings_screen.dart';
import 'package:dakao_in_bill/features/settings/shop_settings_repository.dart';
import 'package:dakao_in_bill/features/settings/shop_settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
      'Settings root fits all approved entries at ${width.toInt()} px',
      (tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('open-shop-settings')), findsOneWidget);
        expect(find.byKey(const Key('open-printer-settings')), findsOneWidget);
        expect(find.byKey(const Key('open-backup-settings')), findsOneWidget);
        expect(find.textContaining('Tự động in'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shop form previews, validates, and persists trimmed values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: ShopSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final name = find.byKey(const Key('shop-name-field'));
    await tester.enterText(name, '  Quán Đakao mới  ');
    await tester.pumpAndSettle();
    expect(find.text('QUÁN ĐAKAO MỚI'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-shop-settings')));
    await tester.pumpAndSettle();

    expect(
      (await ShopSettingsRepository(database).load()).shopName,
      'Quán Đakao mới',
    );
    expect(find.text('Đã lưu thông tin quán.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('shop-name-field')), '   ');
    await tester.tap(find.byKey(const Key('save-shop-settings')));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên quán.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
