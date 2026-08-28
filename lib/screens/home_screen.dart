import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/categories.dart';
import '../utils/grouping.dart';
import '../widgets/edit_expense_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateGroupMode _groupMode = DateGroupMode.day;

  @override
  void initState() {
    super.initState();
    context.read<ExpenseProvider>().loadExpenses();
  }

  Future<void> _openSheet(Expense expense) async {
    final saved = await showEditExpenseSheet(context, expense);
    if (saved == null || !mounted) return;
    final provider = context.read<ExpenseProvider>();
    if (saved.id == null) {
      await provider.addExpense(saved);
    } else {
      await provider.updateExpense(saved);
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
    final expenses = provider.expenses;
    final now = DateTime.now();
    final groups = groupExpenses(expenses, _groupMode);
    // Flat render list: alternating group headers and their entries.
    final items = <Object>[
      for (final group in groups) ...[group, ...group.expenses],
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Tracker')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              provider.statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _TotalChip(
                    label: 'Today',
                    amount: totalOnDate(expenses, now),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TotalChip(
                    label: monthName(now.month),
                    amount: totalInMonth(expenses, now),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<DateGroupMode>(
              segments: [
                for (final mode in DateGroupMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {_groupMode},
              onSelectionChanged: (selection) =>
                  setState(() => _groupMode = selection.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: expenses.isEmpty
                ? const Center(child: Text('No expenses yet.\nTap the mic to add one!',
                    textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      if (item is ExpenseGroup) {
                        return _GroupHeader(group: item);
                      }
                      final expense = item as Expense;
                      return Dismissible(
                        key: ObjectKey(expense),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _deleteWithUndo(expense),
                        child: _HomeExpenseTile(
                          expense: expense,
                          onTap: () => _openSheet(expense),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Compact today/month summary chip.
class _TotalChip extends StatelessWidget {
  const _TotalChip({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          Text('$amount ৳',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final ExpenseGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            group.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          Text('${group.subtotal} ৳',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
        ],
      ),
    );
  }
}

class _HomeExpenseTile extends StatelessWidget {
  const _HomeExpenseTile({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = categoryInfo(expense.category);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: info.color.withValues(alpha: 0.15),
        foregroundColor: info.color,
        child: Icon(info.icon, size: 20),
      ),
      title: Text(expense.item),
      subtitle: Text(expense.quantity != null
          ? '${expense.quantity} · ${info.name}'
          : info.name),
      trailing: Text('${expense.amount} ৳',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }
}
