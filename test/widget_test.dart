import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tracker/models/expense.dart';
import 'package:tracker/providers/expense_provider.dart';
import 'package:tracker/screens/history_screen.dart';
import 'package:tracker/screens/home_screen.dart';
import 'package:tracker/screens/onboarding_screen.dart';
import 'package:tracker/utils/format.dart';
import 'package:tracker/widgets/category_pie_chart.dart';
import 'package:tracker/widgets/edit_expense_sheet.dart';

Widget wrap(Widget child, ExpenseProvider provider) {
  return ChangeNotifierProvider<ExpenseProvider>.value(
    value: provider,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// The redesigned screens put the chart + search above the ledger, so a
/// taller-than-default surface keeps list rows inside the finder viewport.
Future<void> useTallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Phone-like surface for sheet tests so the category grid lays out at
/// realistic chip sizes.
Future<void> usePhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Expense _e({
  int? id,
  String item = 'eggs',
  String? quantity = '3 piece',
  int amount = 50,
  String category = 'food',
}) {
  // Always inside the current month so the "This month" default filter
  // keeps the fixtures visible no matter when the suite runs.
  final now = DateTime.now();
  return Expense(
    id: id,
    item: item,
    quantity: quantity,
    amount: amount,
    category: category,
    createdAt: DateTime(now.year, now.month, 15, 10, 30),
  );
}

/// Records deletions instead of hitting the database.
class _SpyProvider extends ExpenseProvider {
  final List<int> deletedIds = [];
  final List<String> restored = [];

  @override
  Future<void> deleteExpense(int id) async {
    deletedIds.add(id);
    debugSetExpenses(expenses.where((e) => e.id != id).toList());
  }

  @override
  Future<void> restoreExpense(Expense expense) async {
    restored.add(expense.item);
    debugSetExpenses([...expenses, expense]);
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
      expect(find.text('No expenses in this range'), findsOneWidget);
    });

    testWidgets('lists expenses with pie chart and legend', (tester) async {
      await useTallSurface(tester);
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
      expect(find.text('৳50'), findsOneWidget);
      // Legend entries: capitalized label + "amount · percent".
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('৳50 · 55.6%'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('৳40 · 44.4%'), findsOneWidget);
      expect(find.text('TOTAL IN RANGE'), findsOneWidget);
      expect(find.text('৳90'), findsNWidgets(2)); // chart center + legend total
    });
  });

  group('CategoryPieChart', () {
    testWidgets('shows empty total for no data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: CategoryPieChart(expenses: const [])),
        ),
      ));
      expect(find.text('৳0'), findsOneWidget);
    });

    testWidgets('renders one section per category with center total',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 300,
              child: CategoryPieChart(expenses: [
                _e(amount: 80),
                _e(item: 'rice', amount: 30),
                _e(item: 'bus', amount: 40, category: 'transport'),
              ]),
            ),
          ),
        ),
      ));
      expect(find.text('৳150'), findsOneWidget);
    });
  });

  group('swipe to delete', () {
    testWidgets('deletes from history list with undo', (tester) async {
      await useTallSurface(tester);
      final provider = _SpyProvider()
        ..debugSetExpenses([_e(id: 1), _e(id: 2, item: 'bus fare')]);
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      await tester.pumpAndSettle();
      debugPrint('SURFACE: ${tester.view.physicalSize}');
      debugPrint('provider expenses: ${provider.expenses.length} '
          'first: ${provider.expenses.firstOrNull?.item} '
          'date: ${provider.expenses.firstOrNull?.createdAt}');
      debugPrint('eggs onstage: ' '${find.text('eggs').evaluate().length}'
          ' offstage: ' '${find.text('eggs', skipOffstage: false).evaluate().length}');
      debugPrint('exceptions: ${tester.takeException()}');
      final screenProvider = tester.element(find.byType(HistoryScreen)).read<ExpenseProvider>();
      debugPrint('same instance: ${identical(screenProvider, provider)} '
          'screen expenses: ${screenProvider.expenses.length} '
          'screen state: ${screenProvider.modelState}');

      await tester.ensureVisible(find.text('eggs', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.drag(find.text('eggs'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(provider.deletedIds, [1]);
      expect(find.text('eggs'), findsNothing);
      expect(find.text('bus fare'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(provider.restored, ['eggs']);
    });

    testWidgets('deletes from home list', (tester) async {
      await useTallSurface(tester);
      final provider = _SpyProvider()
        ..debugSetExpenses([_e(id: 1), _e(id: 2, item: 'bus fare')]);
      await tester.pumpWidget(wrap(const HomeScreen(), provider));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('eggs', skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.drag(find.text('eggs'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(provider.deletedIds, [1]);
      expect(find.text('eggs'), findsNothing);
      expect(find.text('bus fare'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HomeScreen totals', () {
    testWidgets('shows today and this-month totals', (tester) async {
      await useTallSurface(tester);
      final now = DateTime.now();
      // Pick an "earlier this month" day that can never collide with today
      // (the suite must pass on the 1st of the month too).
      final otherDay = now.day == 1 ? 2 : 1;
      Expense at(DateTime d) => Expense(
            item: 'x',
            amount: 100,
            category: 'food',
            createdAt: d,
          );
      final provider = ExpenseProvider()
        ..debugSetExpenses([
          at(DateTime(now.year, now.month, now.day)),
          at(DateTime(now.year, now.month, now.day).add(const Duration(hours: 2))),
          at(DateTime(now.year, now.month, otherDay)),
          at(DateTime(now.year, now.month - 1, 15)),
        ]);
      await tester.pumpWidget(wrap(const HomeScreen(), provider));
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsNWidgets(2)); // summary + group header
      expect(find.text('৳200'), findsOneWidget);
      expect(find.text('৳300'), findsOneWidget);
      // Group header for today shows count and subtotal.
      expect(find.text('2 · ৳200'), findsOneWidget);
    });
  });

  group('HistoryScreen filters', () {
    final now = DateTime.now();

    List<Expense> fixtures() => [
          Expense(
            id: 1,
            item: 'this month eggs',
            amount: 50,
            category: 'food',
            createdAt: DateTime(now.year, now.month, 3),
          ),
          Expense(
            id: 2,
            item: 'last month bus',
            amount: 40,
            category: 'transport',
            createdAt: DateTime(now.year, now.month - 1, 10),
          ),
          Expense(
            id: 3,
            item: 'old rent',
            amount: 5000,
            category: 'rent',
            createdAt: DateTime(now.year - 1, 6, 1),
          ),
        ];

    Future<void> pickRange(
      WidgetTester tester,
      String current,
      String target,
    ) async {
      await tester.tap(find.text(current));
      await tester.pumpAndSettle();
      await tester.tap(find.text(target).last);
      await tester.pumpAndSettle();
    }

    testWidgets('range dropdown filters list and chart', (tester) async {
      await useTallSurface(tester);
      final provider = ExpenseProvider()..debugSetExpenses(fixtures());
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      await tester.pumpAndSettle();

      expect(find.text('this month eggs'), findsOneWidget);
      expect(find.text('last month bus'), findsNothing);
      expect(find.text('old rent'), findsNothing);

      await pickRange(tester, 'This month', 'Last month');
      expect(find.text('last month bus'), findsOneWidget);
      expect(find.text('this month eggs'), findsNothing);

      await pickRange(tester, 'Last month', 'All time');
      expect(find.text('this month eggs'), findsOneWidget);
      expect(find.text('last month bus'), findsOneWidget);
      expect(find.text('old rent'), findsOneWidget);
    });

    testWidgets('search shows matching results instead of the chart',
        (tester) async {
      await useTallSurface(tester);
      final provider = ExpenseProvider()..debugSetExpenses(fixtures());
      await tester.pumpWidget(wrap(const HistoryScreen(), provider));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'eggs');
      await tester.pumpAndSettle();

      expect(find.text('this month eggs'), findsOneWidget);
      expect(find.text('old rent'), findsNothing);
      expect(find.textContaining('MATCH FOR'), findsOneWidget);

      // Chart is replaced while searching.
      expect(find.byType(CategoryPieChart), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No items match “zzz”.'), findsOneWidget);
    });
  });

  group('HomeScreen grouping toggle', () {
    final now = DateTime.now();

    Iterable<String> visibleTitles(WidgetTester tester) => tester
        .widgetList<Text>(find.byWidgetPredicate(
          (w) => w is Text &&
              w.data != null &&
              w.style?.letterSpacing == 1.54 &&
              w.overflow == TextOverflow.ellipsis,
        ))
        .map((t) => t.data!);

    Expense expenseAt(DateTime at, String item, int amount) => Expense(
          item: item,
          amount: amount,
          category: 'food',
          createdAt: at,
        );

    testWidgets('switching day/month/year regroups the list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // loadExpenses() in HomeScreen.initState stays pending in the widget
      // test fake-async zone, so seeding the provider directly is stable.
      final provider = ExpenseProvider()
        ..debugSetExpenses([
          expenseAt(DateTime(2026, 8, 25, 10), 'rice', 50),
          expenseAt(DateTime(2026, 8, 25, 12), 'eggs', 10),
          expenseAt(DateTime(2026, 8, 24, 9), 'bus fare', 40),
          expenseAt(DateTime(2026, 7, 30, 18), 'recharge', 40),
          expenseAt(DateTime(2025, 12, 31, 23), 'old item', 50),
        ]);

      final dayTitles = [
        dayGroupTitle(DateTime(2026, 8, 25), now).toUpperCase(),
        dayGroupTitle(DateTime(2026, 8, 24), now).toUpperCase(),
        dayGroupTitle(DateTime(2026, 7, 30), now).toUpperCase(),
        dayGroupTitle(DateTime(2025, 12, 31), now).toUpperCase(),
      ];

      await tester.pumpWidget(wrap(const HomeScreen(), provider));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), dayTitles);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(
        visibleTitles(tester),
        ['AUGUST 2026', 'JULY 2026', 'DECEMBER 2025'],
      );

      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['2026', '2025']);

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), dayTitles);
    });
  });

  group('EditExpenseSheet', () {
    testWidgets('create mode returns a new unsaved expense', (tester) async {
      await usePhoneSurface(tester);
      Expense? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result = await showEditExpenseSheet(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('New expense'), findsOneWidget);
      expect(find.text('Save expense'), findsOneWidget); // disabled label

      await tester.enterText(find.byKey(const Key('itemField')), 'tea');
      await tester.enterText(find.byKey(const Key('amountField')), '15');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.id, isNull);
      expect(result!.item, 'tea');
      expect(result!.amount, 15);
      expect(result!.category, 'food');
    });

    testWidgets('saves edited fields', (tester) async {
      await usePhoneSurface(tester);
      Expense? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async =>
                    result = await showEditExpenseSheet(ctx, _e(id: 1)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit expense'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('itemField')), 'eggs x6');
      await tester.enterText(find.byKey(const Key('quantityField')), '6 piece');
      await tester.enterText(find.byKey(const Key('amountField')), '90');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.item, 'eggs x6');
      expect(result!.quantity, '6 piece');
      expect(result!.amount, 90);
      expect(result!.category, 'food');
    });

    testWidgets('saves an edited date', (tester) async {
      await useTallSurface(tester);
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

      await tester.ensureVisible(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      // Pick TODAY — always selectable (the picker clamps to past dates).
      await tester.tap(find.text('${DateTime.now().day}'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      final now = DateTime.now();
      expect(result!.createdAt, DateTime(now.year, now.month, now.day));
    });

    testWidgets('save stays disabled without item and amount',
        (tester) async {
      await usePhoneSurface(tester);
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

      await tester.enterText(find.byKey(const Key('itemField')), '  ');
      await tester.enterText(find.byKey(const Key('amountField')), '');
      await tester.pumpAndSettle();

      // Disabled button is a no-op and the sheet stays open.
      await tester.ensureVisible(find.text('Save expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save expense'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Save expense'), findsOneWidget);
    });

    testWidgets('voice review shows heard text and amounts hint',
        (tester) async {
      await usePhoneSurface(tester);
      Expense? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result = await showEditExpenseSheet(
                  ctx,
                  Expense(
                    item: 'Rickshaw to the bazar',
                    amount: 0,
                    category: 'transport',
                    createdAt: DateTime(2026, 8, 29),
                  ),
                  'took a rickshaw to the bazar',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Almost there'), findsOneWidget);
      expect(find.text('“took a rickshaw to the bazar”'), findsOneWidget);
      expect(find.text('No amount heard — add one to save.'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('amountField')), '60');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Save ৳'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.amount, 60);
      expect(result!.category, 'transport');
    });
  });

  group('OnboardingScreen', () {
    Future<void> pump(WidgetTester tester, void Function() onFinish) {
      return tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(onFinish: onFinish),
      ));
    }

    testWidgets('walks through all steps to the ready screen',
        (tester) async {
      var finished = false;
      await pump(tester, () => finished = true);

      expect(find.text('Meet Hishab'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Your money stays on your phone.'), findsOneWidget);
      expect(find.text('NO UPLOADS'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump(); // flush the gesture into an animation frame
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text("Say it like you'd tell a friend."), findsOneWidget);
      expect(find.text('TAP TO TRY IT'), findsOneWidget);
      expect(find.text('Try: "Rickshaw to the bazar, 60 taka"'),
          findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump(); // flush the gesture into an animation frame
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Use your microphone?'), findsOneWidget);
      expect(find.text('Allow microphone'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text("You're all set."), findsOneWidget);
      expect(find.text('Start tracking'), findsOneWidget);
      // Footer with dots/actions is hidden on the last step.
      expect(find.text('Continue'), findsNothing);

      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
    });

    testWidgets('skip jumps straight to the end and finishes',
        (tester) async {
      var finished = false;
      await pump(tester, () => finished = true);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text("You're all set."), findsOneWidget);
      expect(finished, isFalse);

      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
    });
  });
}
