import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/csv_export.dart';
import '../utils/format.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/edit_expense_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/glass.dart';

enum HistoryRange { thisMonth, lastMonth, all }

extension HistoryRangeX on HistoryRange {
  String get label => switch (this) {
        HistoryRange.thisMonth => 'This month',
        HistoryRange.lastMonth => 'Last month',
        HistoryRange.all => 'All time',
      };

  bool contains(Expense e, DateTime now) => switch (this) {
        HistoryRange.thisMonth =>
          e.createdAt.year == now.year && e.createdAt.month == now.month,
        HistoryRange.lastMonth =>
          e.createdAt.year == DateTime(now.year, now.month - 1).year &&
              e.createdAt.month == DateTime(now.year, now.month - 1).month,
        HistoryRange.all => true,
      };
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryRange _range = HistoryRange.thisMonth;
  String _query = '';

  List<Expense> _filtered(List<Expense> expenses) {
    final now = DateTime.now();
    return expenses
        .where((e) => _range.contains(e, now))
        .where((e) =>
            _query.isEmpty ||
            e.item.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> _exportCsv() async {
    final expenses = _filtered(context.read<ExpenseProvider>().expenses);
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nothing to export')));
      return;
    }
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final file = File('${Directory.systemTemp.path}/expenses-$stamp.csv');
    await file.writeAsString(expensesToCsv(expenses));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Expense export',
      ),
    );
  }

  Future<void> _clearAll() async {
    final provider = context.read<ExpenseProvider>();
    final count = provider.expenses.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dialogFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text(
          'Delete all expenses?',
          style: TextStyle(fontSize: 18),
        ),
        content: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'This will permanently remove '),
            TextSpan(
              text: '$count expense${count == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.fg),
            ),
            const TextSpan(
              text: " from this device. This can't be undone.",
            ),
          ]),
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.bgDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await provider.clearAll();
    }
  }

  void _deleteWithUndo(Expense expense) {
    context.read<ExpenseProvider>().deleteExpense(expense.id!);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Expense deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                context.read<ExpenseProvider>().restoreExpense(expense),
          ),
        ),
      );
  }

  Future<void> _openSheet(Expense expense) async {
    final updated = await showEditExpenseSheet(context, expense);
    if (updated != null && mounted) {
      await context.read<ExpenseProvider>().updateExpense(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final expenses = _filtered(provider.expenses);
    final searching = _query.isNotEmpty;
    final total = totalOf(expenses);

    return SafeArea(
      top: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 240),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 14),
            child: Row(
              children: [
                const Text(
                  'History',
                  style: TextStyle(fontSize: 21, letterSpacing: -0.42),
                ),
                const Spacer(),
                GlassIconBtn(
                  icon: Icons.download,
                  tooltip: 'Export CSV',
                  onTap: _exportCsv,
                ),
                const SizedBox(width: 4),
                GlassIconBtn(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete all expenses',
                  color: AppColors.danger,
                  onTap: _clearAll,
                ),
              ],
            ),
          ),
          _SearchBox(
            query: _query,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          if (searching)
            _SearchResults(
              query: _query,
              hits: expenses,
              onTap: _openSheet,
            )
          else ...[
            Row(
              children: [
                _RangeSelect(
                  range: _range,
                  onSelected: (r) => setState(() => _range = r),
                ),
                const Spacer(),
                Text(
                  '${expenses.length} expense${expenses.length == 1 ? '' : 's'} · ${fmtTaka(total)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            GlassContainer(
              radius: 20,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CategoryPieChart(expenses: expenses),
                  const SizedBox(height: 12),
                  const Text(
                    'Share of spending by category',
                    style: TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            GlassContainer(
              radius: 20,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(20),
              child: _Legend(expenses: expenses),
            ),
            if (expenses.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final e in expenses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ObjectKey(e),
                    direction: DismissDirection.endToStart,
                    background: const _DeleteBackground(),
                    onDismissed: (_) => _deleteWithUndo(e),
                    child: ExpenseTile(
                      expense: e,
                      showTime: false,
                      onTap: () => _openSheet(e),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

int totalOf(List<Expense> expenses) =>
    expenses.fold(0, (sum, e) => sum + e.amount);

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.query, required this.onChanged});

  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search items, e.g. rickshaw',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          if (query.isNotEmpty)
            GestureDetector(
              onTap: () => onChanged(''),
              child: const Icon(Icons.close, size: 18, color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _RangeSelect extends StatelessWidget {
  const _RangeSelect({required this.range, required this.onSelected});

  final HistoryRange range;
  final ValueChanged<HistoryRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<HistoryRange>(
      initialValue: range,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.surface,
      itemBuilder: (_) => [
        for (final r in HistoryRange.values)
          PopupMenuItem(
            value: r,
            child: Text(r.label, style: const TextStyle(fontSize: 12)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.glassFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(range.label, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.hits,
    required this.onTap,
  });

  final String query;
  final List<Expense> hits;
  final ValueChanged<Expense> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, left: 4, bottom: 4),
          child: Text(
            '${hits.length} match${hits.length == 1 ? '' : 'es'} for “${query.trim()}”'
                .toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.54,
              color: AppColors.muted,
            ),
          ),
        ),
        if (hits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No items match “${query.trim()}”.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          )
        else
          for (final e in hits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ExpenseTile(expense: e, showTime: false, onTap: () => onTap(e)),
            ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.expenses});

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

    if (entries.isEmpty) {
      return const Row(
        children: [
          Text(
            'No expenses in this range',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      );
    }

    return Column(
      children: [
        for (final entry in entries) ...[
          _LegendRow(
            info: entry.key,
            amount: entry.value,
            pct: entry.value * 100 / grandTotal,
          ),
          if (entry != entries.last)
            const Divider(height: 1, color: AppColors.hairline),
        ],
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL IN RANGE',
              style: TextStyle(fontSize: 10, letterSpacing: 0.5, color: AppColors.muted),
            ),
            Text(fmtTaka(grandTotal), style: const TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.info,
    required this.amount,
    required this.pct,
  });

  final CategoryInfo info;
  final int amount;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: info.color,
              boxShadow: [
                BoxShadow(
                  color: info.color.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(info.label, style: const TextStyle(fontSize: 13))),
          Text(
            '${fmtTaka(amount)} · ${pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.delete_outline, color: AppColors.bgDeep),
    );
  }
}
