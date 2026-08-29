import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker/database/db_helper.dart';
import 'package:tracker/models/expense.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DBHelper.reset();
  });

  tearDown(() async {
    await DBHelper.reset();
  });

  test('settings round-trip', () async {
    expect(await DBHelper.getSetting('onboarding_complete'), isNull);
    await DBHelper.setSetting('onboarding_complete', 'true');
    expect(await DBHelper.getSetting('onboarding_complete'), 'true');
    await DBHelper.setSetting('onboarding_complete', 'false');
    expect(await DBHelper.getSetting('onboarding_complete'), 'false');
  });

  test('insert and get all expenses', () async {
    await DBHelper.insertExpense(Expense(
      item: 'eggs',
      quantity: '3 piece',
      amount: 50,
      category: 'food',
      createdAt: DateTime(2026, 8, 15, 10),
    ));
    await DBHelper.insertExpense(Expense(
      item: 'bus fare',
      amount: 40,
      category: 'transport',
      createdAt: DateTime(2026, 8, 15, 11),
    ));

    final all = await DBHelper.getAllExpenses();
    expect(all.length, 2);
    expect(all.first.item, 'bus fare'); // ordered by created_at DESC
  });

  test('totals by category', () async {
    await DBHelper.insertExpense(Expense(
      item: 'eggs',
      amount: 50,
      category: 'food',
      createdAt: DateTime(2026, 8, 15, 10),
    ));
    await DBHelper.insertExpense(Expense(
      item: 'rice',
      amount: 30,
      category: 'food',
      createdAt: DateTime(2026, 8, 15, 11),
    ));
    await DBHelper.insertExpense(Expense(
      item: 'bus',
      amount: 40,
      category: 'transport',
      createdAt: DateTime(2026, 8, 15, 12),
    ));

    final totals = await DBHelper.getTotalByCategory();
    expect(totals['food'], 80);
    expect(totals['transport'], 40);
  });

  test('update expense', () async {
    final id = await DBHelper.insertExpense(Expense(
      item: 'eggs',
      quantity: '3 piece',
      amount: 50,
      category: 'food',
      createdAt: DateTime(2026, 8, 15, 10),
    ));
    final stored = (await DBHelper.getAllExpenses()).single;
    expect(stored.id, id);

    await DBHelper.updateExpense(stored.copyWith(
      item: 'eggs x6',
      quantity: '6 piece',
      amount: 90,
      category: 'food',
    ));

    final updated = (await DBHelper.getAllExpenses()).single;
    expect(updated.item, 'eggs x6');
    expect(updated.quantity, '6 piece');
    expect(updated.amount, 90);
  });

  test('delete expense', () async {
    final id = await DBHelper.insertExpense(Expense(
      item: 'eggs',
      amount: 50,
      category: 'food',
      createdAt: DateTime(2026, 8, 15, 10),
    ));
    await DBHelper.deleteExpense(id);
    final all = await DBHelper.getAllExpenses();
    expect(all, isEmpty);
  });

  test('filter by category', () async {
    await DBHelper.insertExpense(Expense(
      item: 'eggs',
      amount: 50,
      category: 'food',
      createdAt: DateTime(2026, 8, 15, 10),
    ));
    await DBHelper.insertExpense(Expense(
      item: 'bus',
      amount: 40,
      category: 'transport',
      createdAt: DateTime(2026, 8, 15, 11),
    ));
    final food = await DBHelper.getExpensesByCategory('food');
    expect(food.length, 1);
    expect(food.first.item, 'eggs');
  });
}
