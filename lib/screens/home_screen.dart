import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/grouping.dart';
import '../widgets/edit_expense_sheet.dart';
import '../widgets/expense_tile.dart';
import '../widgets/glass.dart';

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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Expense deleted'),
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
    final groups = groupExpenses(expenses, _groupMode, now: now);
    final monthExpenses = expenses
        .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month)
        .toList();
    final todayExpenses = expenses.where((e) {
      final d = e.createdAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();

    return SafeArea(
      top: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
        children: [
          const _AppBar(),
          const SizedBox(height: 14),
          _SummaryCard(
            todayTotal: totalOnDate(expenses, now),
            todayCount: todayExpenses.length,
            monthTotal: totalInMonth(expenses, now),
            monthCount: monthExpenses.length,
          ),
          const SizedBox(height: 18),
          GlassSegmented(
            segments: {
              for (final mode in DateGroupMode.values) mode: mode.label,
            },
            selected: _groupMode,
            onSelected: (mode) => setState(() => _groupMode = mode),
          ),
          if (expenses.isEmpty)
            const _EmptyState()
          else ...[
            const SizedBox(height: 24),
            _ListHead(
              title: switch (_groupMode) {
                DateGroupMode.day => 'All expenses',
                DateGroupMode.month => 'By month',
                DateGroupMode.year => 'By year',
              },
              count: expenses.length,
              total: totalOf(expenses),
            ),
            const SizedBox(height: 8),
            for (final group in groups) ...[
              _GroupHeader(group: group),
              const SizedBox(height: 8),
              for (final expense in group.expenses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ObjectKey(expense),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => _deleteWithUndo(expense),
                    child: ExpenseTile(
                      expense: expense,
                      showDate: _groupMode != DateGroupMode.day,
                      onTap: () => _openSheet(expense),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }
}

int totalOf(List<Expense> expenses) =>
    expenses.fold(0, (sum, e) => sum + e.amount);

class _AppBar extends StatelessWidget {
  const _AppBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hishab',
                style: TextStyle(fontSize: 24, letterSpacing: -0.48),
              ),
              SizedBox(height: 2),
              Text(
                'YOUR MONEY, ON YOUR PHONE',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const Spacer(),
          GlassContainer(
            radius: 999,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            shadowColor: null,
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 12, color: AppColors.muted),
                SizedBox(width: 6),
                Text(
                  'STAYS ON THIS DEVICE',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.todayTotal,
    required this.todayCount,
    required this.monthTotal,
    required this.monthCount,
  });

  final int todayTotal;
  final int todayCount;
  final int monthTotal;
  final int monthCount;

  @override
  Widget build(BuildContext context) {
    String cap(int count, {bool today = false}) {
      if (today && count == 0) return 'No expenses today';
      return '$count expense${count == 1 ? '' : 's'}${today ? ' today' : ''}';
    }

    return GlassContainer(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Stat(
              label: 'TODAY',
              value: fmtTaka(todayTotal),
              valueColor: AppColors.accentInk,
              caption: cap(todayCount, today: true),
            ),
          ),
          Container(width: 1, height: 56, color: AppColors.hairline),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _Stat(
                label: 'THIS MONTH',
                value: fmtTaka(monthTotal),
                caption: cap(monthCount),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.caption,
    this.valueColor = AppColors.fg,
  });

  final String label;
  final String value;
  final String caption;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            height: 1.2,
            letterSpacing: -0.84,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ListHead extends StatelessWidget {
  const _ListHead({
    required this.title,
    required this.count,
    required this.total,
  });

  final String title;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.54,
              color: AppColors.fg.withValues(alpha: 0.62),
            ),
          ),
          const Spacer(),
          Text(
            '$count expense${count == 1 ? '' : 's'} · ${fmtTaka(total)}',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
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
    final ink = AppColors.fg.withValues(alpha: 0.62);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.group,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.title.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, letterSpacing: 1.54, color: ink),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${group.expenses.length} · ${fmtTaka(group.subtotal)}',
            style: TextStyle(fontSize: 11, color: ink),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 52, bottom: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.mic_none, size: 30, color: AppColors.accentInk),
          ),
          const SizedBox(height: 20),
          const Text('No expenses yet',
              style: TextStyle(fontSize: 20, letterSpacing: -0.4)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Tap the mic and say something like '),
                TextSpan(
                  text: '“bought 3 eggs for 50 taka”',
                  style: TextStyle(color: AppColors.fg),
                ),
                TextSpan(
                  text:
                      '. No account, no internet — everything stays on this phone.',
                ),
              ]),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _PhraseCard('Rickshaw to the bazar, 60 taka'),
          const SizedBox(height: 8),
          const _PhraseCard('Mobile recharge, 100 taka'),
          const SizedBox(height: 8),
          const _PhraseCard('3 eggs for 50 taka'),
        ],
      ),
    );
  }
}

class _PhraseCard extends StatelessWidget {
  const _PhraseCard(this.phrase);

  final String phrase;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Try saying: '),
            TextSpan(text: '“$phrase”', style: const TextStyle(color: AppColors.fg)),
          ]),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
    );
  }
}
