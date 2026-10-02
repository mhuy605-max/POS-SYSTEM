import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database_provider.dart';
import '../orders/order_providers.dart';
import 'print_attempt_repository.dart';
import 'printer_service.dart';
import 'printer_settings_repository.dart';
import 'printer_transport.dart';
import 'receipt_renderer.dart';

final printerTransportProvider = Provider<PrinterTransport>(
  (ref) => const NativePrinterTransport(),
);

final printerSettingsRepositoryProvider = Provider<PrinterSettingsRepository>(
  (ref) => PrinterSettingsRepository(ref.watch(appDatabaseProvider)),
);

final printAttemptRepositoryProvider = Provider<PrintAttemptRepository>(
  (ref) => PrintAttemptRepository(
    ref.watch(appDatabaseProvider),
    nowEpochMillis: () => DateTime.now().millisecondsSinceEpoch,
  ),
);

final receiptRendererProvider = Provider<ReceiptRenderer>(
  (ref) => const ReceiptRenderer(),
);

final printerServiceProvider = Provider<PrinterService>(
  (ref) => PrinterService(
    orderRepository: ref.watch(orderRepositoryProvider),
    settingsRepository: ref.watch(printerSettingsRepositoryProvider),
    attemptRepository: ref.watch(printAttemptRepositoryProvider),
    renderer: ref.watch(receiptRendererProvider),
    transport: ref.watch(printerTransportProvider),
  ),
);
