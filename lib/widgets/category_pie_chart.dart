import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/format.dart';

/// 208px donut showing the share of spending per category, with the grand
/// total in the center. Legend lives in the History screen's legend card.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final totals = <CategoryInfo, int>{};
    var grandTotal = 0;
    for (final e in expenses) {
      final info = categoryInfo(e.category);
      totals[info] = (totals[info] ?? 0) + e.amount;
      grandTotal += e.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      width: 208,
      height: 208,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 68,
              startDegreeOffset: -90,
              sections: [
                if (entries.isEmpty)
                  PieChartSectionData(
                    value: 1,
                    color: AppColors.border,
                    radius: 30,
                    showTitle: false,
                  )
                else
                  for (final entry in entries)
                    PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: entry.key.color,
                      radius: 30,
                      showTitle: false,
                    ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fmtTaka(grandTotal),
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  letterSpacing: -0.72,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'SPENT IN RANGE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.08,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
