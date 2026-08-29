import '../models/expense.dart';
import 'format.dart';

/// How entries are grouped on the home screen.
enum DateGroupMode { day, month, year }

extension DateGroupModeX on DateGroupMode {
  String get label => switch (this) {
        DateGroupMode.day => 'Day',
        DateGroupMode.month => 'Month',
        DateGroupMode.year => 'Year',
      };
}

class ExpenseGroup {
  final String title;
  final List<Expense> expenses;

  const ExpenseGroup(this.title, this.expenses);

  int get subtotal =>
      expenses.fold(0, (sum, e) => sum + e.amount);
}

/// Groups [expenses] (any order) by calendar day/month/year and returns the
/// groups newest first; entries inside each group are newest first.
///
/// [now] drives the "Today"/"Yesterday" day labels; defaults to the real clock.
List<ExpenseGroup> groupExpenses(
  List<Expense> expenses,
  DateGroupMode mode, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final buckets = <String, List<Expense>>{};
  for (final e in expenses) {
    final key = switch (mode) {
      DateGroupMode.day =>
        '${e.createdAt.year}-${_two(e.createdAt.month)}-${_two(e.createdAt.day)}',
      DateGroupMode.month =>
        '${e.createdAt.year}-${_two(e.createdAt.month)}',
      DateGroupMode.year => '${e.createdAt.year}',
    };
    (buckets[key] ??= []).add(e);
  }

  final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final key in keys)
      ExpenseGroup(
        _titleFor(key, mode, now),
        buckets[key]!..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ];
}

/// Total amount spent on the calendar day of [day].
int totalOnDate(List<Expense> expenses, DateTime day) => expenses
    .where((e) =>
        e.createdAt.year == day.year &&
        e.createdAt.month == day.month &&
        e.createdAt.day == day.day)
    .fold(0, (sum, e) => sum + e.amount);

/// Total amount spent in the calendar month of [month].
int totalInMonth(List<Expense> expenses, DateTime month) => expenses
    .where((e) =>
        e.createdAt.year == month.year &&
        e.createdAt.month == month.month)
    .fold(0, (sum, e) => sum + e.amount);

String _titleFor(String key, DateGroupMode mode, DateTime now) {
  if (mode == DateGroupMode.year) return key;
  final parts = key.split('-').map(int.parse).toList();
  if (mode == DateGroupMode.month) return '${monthName(parts[1])} ${parts[0]}';
  return dayGroupTitle(DateTime(parts[0], parts[1], parts[2]), now);
}

String _two(int n) => n.toString().padLeft(2, '0');
