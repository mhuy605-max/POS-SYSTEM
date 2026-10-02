import 'package:drift/drift.dart';

import '../../data/app_database.dart';
import 'printer_models.dart';

typedef PrintClock = int Function();

final class PrintAttemptRepository {
  PrintAttemptRepository(this._database, {required this._nowEpochMillis});

  final AppDatabase _database;
  final PrintClock _nowEpochMillis;

  Future<void> record(int orderId, PrintResult result) async {
    final attemptedAt = _nowEpochMillis();
    await _database.transaction(() async {
      await _database
          .into(_database.printAttempts)
          .insert(
            PrintAttemptsCompanion.insert(
              orderId: orderId,
              attemptedAt: attemptedAt,
              success: result.wasSent,
              errorMessage: Value(_storedError(result)),
            ),
          );
      if (result.wasSent) {
        await _database.customUpdate(
          'UPDATE orders SET print_count = print_count + 1, printed_at = ? '
          'WHERE id = ?',
          variables: <Variable<Object>>[
            Variable<int>(attemptedAt),
            Variable<int>(orderId),
          ],
          updates: {_database.orders},
        );
      }
    });
  }
}

String? _storedError(PrintResult result) {
  if (result.kind == PrintResultKind.sent) return null;
  final prefix = result.kind == PrintResultKind.unknown
      ? 'UNKNOWN_OUTCOME'
      : 'FAILED';
  return '$prefix|${result.errorCode?.name ?? 'unknown'}|${result.message}';
}
