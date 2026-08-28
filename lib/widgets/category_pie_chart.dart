import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../utils/categories.dart';

/// Circular pie chart showing the share of total spending per category.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  startDegreeOffset: -90,
                  sections: [
                    for (final entry in entries)
                      PieChartSectionData(
                        value: entry.value.toDouble(),
                        color: entry.key.color,
                        radius: 40,
                        title: '${(entry.value * 100 / grandTotal).round()}%',
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$grandTotal ৳',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const Text('total', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final entry in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entry.key.color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('${entry.key.name} · ${entry.value} ৳',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
