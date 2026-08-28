import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/models/expense.dart';
import 'package:tracker/utils/csv_export.dart';

Expense _e(String item, int amount, {String? quantity, String category = 'food'}) =>
    Expense(
      item: item,
      quantity: quantity,
      amount: amount,
      category: category,
      createdAt: DateTime(2026, 8, 29, 10, 30),
    );

void main() {
  test('writes header and one row per expense', () {
    final csv = expensesToCsv([
      _e('eggs', 50, quantity: '3 piece'),
      _e('bus fare', 40, category: 'transport'),
    ]);
    final lines = csv.trim().split('\n');
    expect(lines[0], 'date,item,quantity,amount,category');
    expect(lines.length, 3);
    expect(lines[1], '2026-08-29T10:30:00.000,eggs,3 piece,50,food');
    expect(lines[2], '2026-08-29T10:30:00.000,bus fare,,40,transport');
  });

  test('escapes commas and quotes', () {
    final csv = expensesToCsv([_e('rice, "gold"', 10)]);
    expect(csv, contains('"rice, ""gold"""'));
  });
}
