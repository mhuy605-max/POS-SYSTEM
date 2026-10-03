import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/money.dart';
import 'revenue_repository.dart';

class RevenueBarChart extends StatelessWidget {
  const RevenueBarChart({required this.points, super.key});

  final List<DailyRevenue> points;

  @override
  Widget build(BuildContext context) {
    if (points.every((point) => point.amount == 0)) {
      return const SizedBox(
        height: 132,
        child: Center(child: Text('Chưa có doanh thu trong kỳ này')),
      );
    }
    final maximum = points.fold<int>(
      0,
      (value, point) => math.max(value, point.amount),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(
          constraints.maxWidth,
          points.length * 48.0,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final point in points)
                  Expanded(
                    child: Semantics(
                      label:
                          '${_dayLabel(point.day)}: ${formatVnd(point.amount)}',
                      child: Tooltip(
                        message: formatVnd(point.amount),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 24,
                              height: math.max(6, 108 * point.amount / maximum),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _dayLabel(point.day),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _dayLabel(DateTime day) => '${day.day}/${day.month}';
