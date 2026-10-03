import 'package:dakao_in_bill/data/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated_migrations/schema.dart';

void main() {
  test('runtime V1 schema matches the retained Drift baseline', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final database = AppDatabase(NativeDatabase.memory());

    await verifier.migrateAndValidate(
      database,
      1,
      options: const ValidationOptions(validateDropped: true),
    );
    await database.close();
  });
}
