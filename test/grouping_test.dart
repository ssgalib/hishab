import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/models/expense.dart';
import 'package:tracker/utils/grouping.dart';

Expense _e(int year, int month, int day, int amount,
        {String item = 'x', int hour = 10}) =>
    Expense(
      item: item,
      amount: amount,
      category: 'food',
      createdAt: DateTime(year, month, day, hour),
    );

void main() {
  final now = DateTime(2026, 8, 29);

  test('groups by day with subtotals, newest first', () {
    final groups = groupExpenses([
      _e(2026, 8, 25, 50),
      _e(2026, 8, 24, 40),
      _e(2026, 8, 25, 10, item: 'rice', hour: 12),
    ], DateGroupMode.day, now: now);

    expect(groups.length, 2);
    expect(groups[0].title, 'Tue, Aug 25');
    expect(groups[0].subtotal, 60);
    expect(groups[0].expenses.map((e) => e.item), ['rice', 'x']);
    expect(groups[1].title, 'Mon, Aug 24');
    expect(groups[1].subtotal, 40);
  });

  test('day titles use Today/Yesterday relative to now', () {
    final groups = groupExpenses([
      _e(2026, 8, 29, 50),
      _e(2026, 8, 28, 40),
    ], DateGroupMode.day, now: now);

    expect(groups[0].title, 'Today');
    expect(groups[1].title, 'Yesterday');
  });

  test('groups by month', () {
    final groups = groupExpenses([
      _e(2026, 8, 2, 50),
      _e(2026, 7, 30, 40),
      _e(2026, 8, 20, 10),
    ], DateGroupMode.month, now: now);

    expect(groups.length, 2);
    expect(groups[0].title, 'August 2026');
    expect(groups[0].subtotal, 60);
    expect(groups[1].title, 'July 2026');
  });

  test('groups by year', () {
    final groups = groupExpenses([
      _e(2025, 12, 31, 50),
      _e(2026, 1, 1, 40),
      _e(2026, 6, 15, 10),
    ], DateGroupMode.year, now: now);

    expect(groups.length, 2);
    expect(groups[0].title, '2026');
    expect(groups[0].subtotal, 50);
    expect(groups[1].title, '2025');
  });

  test('mode labels', () {
    expect(DateGroupMode.day.label, 'Day');
    expect(DateGroupMode.month.label, 'Month');
    expect(DateGroupMode.year.label, 'Year');
  });

  test('empty input yields no groups', () {
    expect(groupExpenses([], DateGroupMode.day), isEmpty);
  });

  test('totalOnDate and totalInMonth', () {    final expenses = [
      _e(2026, 8, 25, 50, hour: 9),
      _e(2026, 8, 25, 10, hour: 20),
      _e(2026, 8, 24, 40),
      _e(2026, 7, 30, 40),
    ];
    expect(totalOnDate(expenses, DateTime(2026, 8, 25)), 60);
    expect(totalOnDate(expenses, DateTime(2026, 8, 24)), 40);
    expect(totalOnDate(expenses, DateTime(2026, 1, 1)), 0);
    expect(totalInMonth(expenses, DateTime(2026, 8, 1)), 100);
    expect(totalInMonth(expenses, DateTime(2026, 7, 15)), 40);
    expect(totalInMonth(expenses, DateTime(2025, 8, 1)), 0);
  });
}
