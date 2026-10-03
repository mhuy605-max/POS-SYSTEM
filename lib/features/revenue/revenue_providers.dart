import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database_provider.dart';
import 'revenue_repository.dart';

typedef RevenueClock = DateTime Function();

enum RevenuePeriodPreset { today, sevenDays, month }

final class RevenuePeriodSelection {
  const RevenuePeriodSelection(this.preset);

  final RevenuePeriodPreset preset;
}

final revenueNowProvider = Provider<RevenueClock>((ref) => DateTime.now);

final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  return RevenueRepository(ref.watch(appDatabaseProvider));
});

final revenuePeriodControllerProvider =
    NotifierProvider<RevenuePeriodController, RevenuePeriodSelection>(
      RevenuePeriodController.new,
    );

final revenuePeriodProvider = Provider<RevenuePeriod>((ref) {
  final selection = ref.watch(revenuePeriodControllerProvider);
  final now = ref.watch(revenueNowProvider)();
  return switch (selection.preset) {
    RevenuePeriodPreset.today => RevenuePeriod.today(now),
    RevenuePeriodPreset.sevenDays => RevenuePeriod.lastSevenDays(now),
    RevenuePeriodPreset.month => RevenuePeriod.thisMonth(now),
  };
});

final revenueSummaryProvider = StreamProvider.autoDispose<RevenueSummary>((
  ref,
) {
  final period = ref.watch(revenuePeriodProvider);
  return ref.watch(revenueRepositoryProvider).watchSummary(period);
});

final class RevenuePeriodController extends Notifier<RevenuePeriodSelection> {
  @override
  RevenuePeriodSelection build() =>
      const RevenuePeriodSelection(RevenuePeriodPreset.today);

  void selectPreset(RevenuePeriodPreset preset) {
    state = RevenuePeriodSelection(preset);
  }
}
