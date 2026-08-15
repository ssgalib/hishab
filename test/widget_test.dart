import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tracker/models/expense.dart';
import 'package:tracker/providers/expense_provider.dart';
import 'package:tracker/screens/history_screen.dart';
import 'package:tracker/screens/summary_screen.dart';

void main() {
  Widget wrap(Widget child, ExpenseProvider provider) {
    return ChangeNotifierProvider<ExpenseProvider>.value(
      value: provider,
      child: MaterialApp(home: child),
    );
  }

  group('HistoryScreen', () {
    testWidgets('shows empty state', (tester) async {
      final provider = ExpenseProvider();
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      expect(find.text('No expenses yet'), findsOneWidget);
    });

    testWidgets('lists expenses', (tester) async {
      final provider = ExpenseProvider()
        ..debugSetExpenses([
          Expense(
            item: 'eggs',
            quantity: '3 piece',
            amount: 50,
            category: 'food',
            createdAt: DateTime(2026, 8, 15),
          ),
          Expense(
            item: 'bus fare',
            amount: 40,
            category: 'transport',
            createdAt: DateTime(2026, 8, 15),
          ),
        ]);
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      await tester.pump();
      expect(find.text('eggs'), findsOneWidget);
      expect(find.text('bus fare'), findsOneWidget);
      expect(find.text('50 ৳'), findsOneWidget);
    });
  });

  group('SummaryScreen', () {
    testWidgets('shows empty state', (tester) async {
      await tester.pumpWidget(wrap(
        SummaryScreen(totalsLoader: () async => {}),
        ExpenseProvider(),
      ));
      await tester.pump();
      expect(find.text('No data yet'), findsOneWidget);
    });

    testWidgets('shows category totals with bars', (tester) async {
      await tester.pumpWidget(wrap(
        SummaryScreen(totalsLoader: _fakeTotals),
        ExpenseProvider(),
      ));
      await tester.pump();
      expect(find.text('food'), findsOneWidget);
      expect(find.text('80 ৳'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    });
  });
}

Future<Map<String, int>> _fakeTotals() async => {
  'food': 80,
  'transport': 40,
};
