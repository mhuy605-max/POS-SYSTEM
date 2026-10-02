import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'revenue_chart.dart';
import 'revenue_providers.dart';
import 'revenue_repository.dart';

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(revenuePeriodControllerProvider);
    final period = ref.watch(revenuePeriodProvider);
    final summary = ref.watch(revenueSummaryProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(revenuePeriodProvider);
        await ref.read(revenueSummaryProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            'BÁO CÁO BÁN HÀNG',
            style: TextStyle(
              color: AppColors.secondaryInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _periodTitle(selection.preset),
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _periodLabel(period),
            style: const TextStyle(color: AppColors.secondaryInk),
          ),
          const SizedBox(height: 12),
          _PeriodSelector(selection: selection),
          const SizedBox(height: 16),
          summary.when(
            loading: () => const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể đọc doanh thu: $error'),
              ),
            ),
            data: (value) => _RevenueContent(summary: value),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.selection});

  final RevenuePeriodSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in RevenuePeriodPreset.values) ...[
            ChoiceChip(
              key: Key('period-${preset.name}'),
              label: Text(_presetLabel(preset)),
              selected: selection.preset == preset,
              onSelected: (_) => ref
                  .read(revenuePeriodControllerProvider.notifier)
                  .selectPreset(preset),
            ),
            if (preset != RevenuePeriodPreset.month) const SizedBox(width: 8),
          ],
        ],
      ),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatVnd(summary.recognizedRevenue),
                    key: const Key('recognized-revenue'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
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
                        color: AppColors.error,
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                          fontWeight: FontWeight.w800,
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
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
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
                fontWeight: FontWeight.w800,
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
