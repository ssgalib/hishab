import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/categories.dart';
import '../utils/csv_export.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/edit_expense_sheet.dart';

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
  bool _searching = false;
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
    final expenses = context.read<ExpenseProvider>().expenses;
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to export')),
      );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all expenses?'),
        content: const Text(
          'This permanently removes every entry from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ExpenseProvider>().clearAll();
    }
  }

  void _deleteWithUndo(Expense expense) {
    context.read<ExpenseProvider>().deleteExpense(expense.id!);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${expense.item}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () =>
              context.read<ExpenseProvider>().restoreExpense(expense),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final expenses = _filtered(provider.expenses);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search items',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<HistoryRange>(
              segments: [
                for (final r in HistoryRange.values)
                  ButtonSegment(value: r, label: Text(r.label)),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.ios_share),
            onPressed: _exportCsv,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear all data')),
            ],
          ),
        ],
      ),
      body: expenses.isEmpty
          ? Center(
              child: Text(_query.isEmpty
                  ? 'No expenses in this range'
                  : 'No matches for "$_query"'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CategoryPieChart(expenses: expenses),
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in expenses)
                  Dismissible(
                    key: ObjectKey(e),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteWithUndo(e),
                    child: _ExpenseTile(expense: e),
                  ),
              ],
            ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final info = categoryInfo(expense.category);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: info.color.withValues(alpha: 0.15),
        foregroundColor: info.color,
        child: Icon(info.icon, size: 20),
      ),
      title: Text(expense.item),
      subtitle: Text(
        '${info.name} · ${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}',
      ),
      trailing: Text('${expense.amount} ৳',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () async {
        final updated = await showEditExpenseSheet(context, expense);
        if (updated != null && context.mounted) {
          await context.read<ExpenseProvider>().updateExpense(updated);
        }
      },
    );
  }
}
