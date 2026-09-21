import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../providers/dashboard_providers.dart';

/// Bar chart of how many 1-star ... 5-star ratings there are.
class RatingDistributionChart extends StatelessWidget {
  const RatingDistributionChart({super.key, required this.stats});

  final FeedbackStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = stats.distribution;
    final tallest = counts.reduce(math.max);

    // The two-line label under each bar grows with the system font size, so
    // the space reserved for it (and the chart's height) must grow too.
    final scaler = MediaQuery.textScalerOf(context);
    final labelSpace = scaler.scale(36) + 16;

    // Screen readers cannot read a painted chart, so describe it in words.
    final summary = [
      for (var star = 5; star >= 1; star--) '$star star: ${counts[star - 1]}',
    ].join(', ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rating distribution', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 140 + labelSpace,
              child: stats.total == 0
                  ? Center(
                      child: Text(
                        'No ratings yet',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Semantics(
                      label: 'Rating distribution. $summary',
                      excludeSemantics: true,
                      child: BarChart(
                        BarChartData(
                          // Headroom above the tallest bar.
                          maxY: math.max(tallest, 1) * 1.15,
                          alignment: BarChartAlignment.spaceAround,
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: labelSpace,
                                getTitlesWidget: (value, meta) {
                                  final star = value.toInt();
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$star★',
                                          style: theme.textTheme.labelMedium,
                                        ),
                                        Text(
                                          '${counts[star - 1]}',
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (var star = 1; star <= 5; star++)
                              BarChartGroupData(
                                x: star,
                                barRods: [
                                  BarChartRodData(
                                    toY: counts[star - 1].toDouble(),
                                    width: 24,
                                    color: _colorFor(theme, star),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ],
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
  }

  /// Low ratings in the error colour, high ones in amber, so the shape of the
  /// chart reads at a glance.
  Color _colorFor(ThemeData theme, int star) {
    if (star <= 2) return theme.colorScheme.error;
    if (star == 3) return theme.colorScheme.outline;
    return Colors.amber.shade700;
  }
}
