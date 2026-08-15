import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:tracker/channels/onnx_channel.dart';
import 'package:tracker/database/db_helper.dart';
import 'package:tracker/main.dart';
import 'package:tracker/models/expense_parser.dart';
import 'package:tracker/providers/expense_provider.dart';
import 'package:tracker/screens/history_screen.dart';
import 'package:tracker/screens/home_screen.dart';
import 'package:tracker/screens/summary_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await DBHelper.reset();
  });

  tearDown(() async {
    await DBHelper.reset();
  });

  testWidgets('ONNX inference produces a parseable expense on device',
      (tester) async {
    await OnnxChannel.loadTokenizer();

    final raw = await OnnxChannel.runInference('bought 3 eggs for 50 taka');
    expect(raw, isNotEmpty);

    final expense = ExpenseParser.fromRawJson(raw);
    expect(expense, isNotNull,
        reason: 'raw model output: "$raw"');
  });

  testWidgets('parse -> save -> history -> summary flow', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ExpenseProvider(),
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    // Resolve the provider from the widget tree.
    final ctx = tester.element(find.byType(MaterialApp));
    final provider = ctx.read<ExpenseProvider>();

    // Run on-device inference (STT is exercised separately on physical hardware).
    final raw = await OnnxChannel.runInference('took a bus fare for 40 taka');
    final expense = ExpenseParser.fromRawJson(raw);
    expect(expense, isNotNull, reason: 'raw: "$raw"');
    await provider.addExpense(expense!);

    // Re-pump so the UI reflects the saved expense.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);

    // History shows the saved expense.
    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text(expense.item), findsWidgets);

    // Back to home, then open the summary.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsOneWidget);
  });
}
