import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker/models/expense.dart';
import 'package:tracker/providers/expense_provider.dart';
import 'package:tracker/screens/history_screen.dart';
import 'package:tracker/screens/home_screen.dart';
import 'package:tracker/widgets/category_pie_chart.dart';
import 'package:tracker/widgets/edit_expense_sheet.dart';

Widget wrap(Widget child, ExpenseProvider provider) {
  return ChangeNotifierProvider<ExpenseProvider>.value(
    value: provider,
    child: MaterialApp(home: child),
  );
}

Expense _e({
  int? id,
  String item = 'eggs',
  String? quantity = '3 piece',
  int amount = 50,
  String category = 'food',
}) =>
    Expense(
      id: id,
      item: item,
      quantity: quantity,
      amount: amount,
      category: category,
      createdAt: DateTime(2026, 8, 15),
    );

/// Records deletions instead of hitting the database.
class _SpyProvider extends ExpenseProvider {
  final List<int> deletedIds = [];

  @override
  Future<void> deleteExpense(int id) async {
    deletedIds.add(id);
    debugSetExpenses(expenses.where((e) => e.id != id).toList());
  }
}

void main() {
  setUpAll(() {
    // HomeScreen loads expenses from the database in initState.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('HistoryScreen', () {
    testWidgets('shows empty state', (tester) async {
      final provider = ExpenseProvider();
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      expect(find.text('No expenses yet'), findsOneWidget);
    });

    testWidgets('lists expenses with pie chart and legend', (tester) async {
      final provider = ExpenseProvider()
        ..debugSetExpenses([
          _e(),
          _e(item: 'bus fare', quantity: null, amount: 40, category: 'transport'),
        ]);
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      await tester.pumpAndSettle();

      expect(find.byType(CategoryPieChart), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('eggs'), findsOneWidget);
      expect(find.text('bus fare'), findsOneWidget);
      expect(find.text('50 ৳'), findsOneWidget);
      // Legend entries.
      expect(find.text('food · 50 ৳'), findsOneWidget);
      expect(find.text('transport · 40 ৳'), findsOneWidget);
      // Total in the chart center.
      expect(find.text('90 ৳'), findsOneWidget);
    });
  });

  group('CategoryPieChart', () {
    testWidgets('shows empty total for no data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CategoryPieChart(expenses: const [])),
      ));
      expect(find.text('0 ৳'), findsOneWidget);
    });

    testWidgets('renders one section per category', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(
          child: SizedBox(
            height: 400,
            child: CategoryPieChart(expenses: [
              _e(amount: 80),
              _e(item: 'rice', amount: 30),
              _e(item: 'bus', amount: 40, category: 'transport'),
            ]),
          ),
        )),
      ));
      expect(find.text('150 ৳'), findsOneWidget);
      // Two food slices merge into a single legend entry.
      expect(find.text('food · 110 ৳'), findsOneWidget);
      expect(find.text('transport · 40 ৳'), findsOneWidget);
    });
  });

  group('swipe to delete', () {
    testWidgets('deletes from history list', (tester) async {
      final provider = _SpyProvider()
        ..debugSetExpenses([_e(id: 1), _e(id: 2, item: 'bus fare')]);
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      await tester.pumpAndSettle();

      await tester.drag(find.text('eggs'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(provider.deletedIds, [1]);
      expect(find.text('eggs'), findsNothing);
      expect(find.text('bus fare'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deletes from home list', (tester) async {
      final provider = _SpyProvider()
        ..debugSetExpenses([_e(id: 1), _e(id: 2, item: 'bus fare')]);
      await tester.pumpWidget(wrap(const HomeScreen(), provider));
      await tester.pumpAndSettle();

      await tester.drag(find.text('eggs'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(provider.deletedIds, [1]);
      expect(find.text('eggs'), findsNothing);
      expect(find.text('bus fare'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditExpenseSheet', () {
    testWidgets('saves edited fields', (tester) async {
      Expense? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async =>
                    result = await showEditExpenseSheet(ctx, _e()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Item'), 'eggs x6');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Quantity'), '6 piece');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount (৳)'), '90');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.item, 'eggs x6');
      expect(result!.quantity, '6 piece');
      expect(result!.amount, 90);
      expect(result!.category, 'food');
    });

    testWidgets('rejects empty item and missing amount', (tester) async {
      Expense? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async =>
                    result = await showEditExpenseSheet(ctx, _e()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), '  ');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount (৳)'), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Enter an item'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
    });
  });
}
