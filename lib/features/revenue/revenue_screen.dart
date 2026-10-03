import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_system.dart';
import '../../app/theme.dart';
import '../../core/money.dart';
import 'revenue_chart.dart';
import 'revenue_providers.dart';
import 'revenue_repository.dart';

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(revenuePeriodProvider);
        await ref.read(revenueSummaryProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _RevenueHeader(),
          const SizedBox(height: 12),
          const _PeriodSelector(),
          const SizedBox(height: 16),
          const _RevenueSummary(),
        ],
      ),
    );
  }
}

class _RevenueHeader extends ConsumerWidget {
  const _RevenueHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(revenuePeriodControllerProvider);
    final period = ref.watch(revenuePeriodProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _periodTitle(selection.preset),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          _periodLabel(period),
          style: const TextStyle(color: AppColors.secondaryInk),
        ),
      ],
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(revenuePeriodControllerProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in RevenuePeriodPreset.values) ...[
            ChoiceChip(
              key: Key('period-${preset.name}'),
              label: Text(_presetLabel(preset)),
              selected: selection.preset == preset,
              selectedColor: AppColors.primarySoft,
              side: BorderSide(
                color: selection.preset == preset
                    ? AppColors.primary
                    : AppColors.outline,
              ),
              labelStyle: TextStyle(
                color: selection.preset == preset
                    ? AppColors.primaryStrong
                    : AppColors.secondaryInk,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => ref
                  .read(revenuePeriodControllerProvider.notifier)
                  .selectPreset(preset),
              chipAnimationStyle: AppMotion.chipStyle(context),
            ),
            if (preset != RevenuePeriodPreset.month) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _RevenueSummary extends ConsumerWidget {
  const _RevenueSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(revenueSummaryProvider);
    return summary.when(
      loading: () => const SizedBox(
        height: 320,
        child: AppLoadingState(label: 'Đang tính doanh thu'),
      ),
      error: (error, _) => AppAsyncError(
        message: 'Không thể đọc báo cáo doanh thu.',
        onRetry: () => ref.invalidate(revenueSummaryProvider),
      ),
      data: (value) => _RevenueContent(summary: value),
    );
  }
}

class _RevenueContent extends StatelessWidget {
  const _RevenueContent({required this.summary});

  final RevenueSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.payments_outlined, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'THỰC THU ĐÃ THANH TOÁN',
                        style: TextStyle(
                          color: AppColors.secondaryInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppAnimatedValue(
                  value: summary.recognizedRevenue,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatVnd(summary.recognizedRevenue),
                      key: const Key('recognized-revenue'),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Đơn đã trả trong kỳ',
                        value: '${summary.paidOrderCount} đơn',
                        valueKey: 'paid-order-count',
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Metric(
                        label: 'Tiền chưa thu hiện tại',
                        value: formatVnd(summary.unpaidAmount),
                        valueKey: 'unpaid-total',
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Doanh thu theo ngày',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                RevenueBarChart(points: summary.dailyRevenue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Món bán chạy trong kỳ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (summary.bestSellers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Chưa có món bán trong kỳ này')),
                  )
                else
                  for (
                    var index = 0;
                    index < summary.bestSellers.length;
                    index++
                  )
                    _BestSellerRow(
                      rank: index + 1,
                      item: summary.bestSellers[index],
                      maximum: summary.bestSellers.first.quantity,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.color,
  });

  final String label;
  final String value;
  final String valueKey;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.secondaryInk),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              key: Key(valueKey),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BestSellerRow extends StatelessWidget {
  const _BestSellerRow({
    required this.rank,
    required this.item,
    required this.maximum,
  });

  final int rank;
  final BestSeller item;
  final int maximum;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.surfaceHigh,
              child: Text('$rank', style: const TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.quantity} phần',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: item.quantity / maximum,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          backgroundColor: AppColors.surfaceHigh,
          color: AppColors.primary,
        ),
      ],
    ),
  );
}

String _periodTitle(RevenuePeriodPreset preset) => switch (preset) {
  RevenuePeriodPreset.today => 'Doanh thu hôm nay',
  RevenuePeriodPreset.sevenDays => 'Doanh thu 7 ngày',
  RevenuePeriodPreset.month => 'Doanh thu tháng này',
};

String _presetLabel(RevenuePeriodPreset preset) => switch (preset) {
  RevenuePeriodPreset.today => 'Hôm nay',
  RevenuePeriodPreset.sevenDays => '7 ngày',
  RevenuePeriodPreset.month => 'Tháng này',
};

String _periodLabel(RevenuePeriod period) {
  String date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
  if (period.startLocal == period.inclusiveEndLocal) {
    return date(period.startLocal);
  }
  return '${date(period.startLocal)} – ${date(period.inclusiveEndLocal)}';
}
