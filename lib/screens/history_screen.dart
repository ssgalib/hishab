import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/categories.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/edit_expense_sheet.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses yet'))
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
                    onDismissed: (_) => context
                        .read<ExpenseProvider>()
                        .deleteExpense(e.id!),
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
