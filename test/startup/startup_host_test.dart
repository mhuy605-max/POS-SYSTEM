import 'dart:async';

import 'package:dakao_in_bill/app/startup.dart';
import 'package:dakao_in_bill/backup/restore_service.dart';
import 'package:dakao_in_bill/data/app_database.dart';
import 'package:dakao_in_bill/backup/backup_models.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup shows real work then enters the app without delay', (
    tester,
  ) async {
    final completion = Completer<StartupDependencies>();
    await tester.pumpWidget(
      StartupHost(initialize: () => completion.future, animateEntrance: false),
    );

    expect(find.byKey(const Key('startup-loading')), findsOneWidget);
    expect(find.text('Đakao In Bill'), findsOneWidget);

    final database = AppDatabase(NativeDatabase.memory());
    completion.complete(
      StartupDependencies(database: database, restoreService: _Restorer()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('sales-search')), findsOneWidget);
    expect(find.byKey(const Key('startup-loading')), findsNothing);
  });

  testWidgets('startup failure is actionable and retry can recover', (
    tester,
  ) async {
    var attempts = 0;
    final database = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      StartupHost(
        animateEntrance: false,
        initialize: () async {
          attempts++;
          if (attempts == 1) throw StateError('open failed');
          return StartupDependencies(
            database: database,
            restoreService: _Restorer(),
          );
        },
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('startup-error')), findsOneWidget);
    expect(find.text('Không thể khởi động ứng dụng'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(find.byKey(const Key('sales-search')), findsOneWidget);
  });
}

final class _Restorer implements BackupRestorer {
  @override
  Future<void> replaceWith(ValidatedBackup backup) async {}
}
