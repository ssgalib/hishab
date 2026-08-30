import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:tracker/channels/onnx_channel.dart';
import 'package:tracker/database/db_helper.dart';
import 'package:tracker/main.dart';
import 'package:tracker/models/expense_parser.dart';
import 'package:tracker/providers/expense_provider.dart';
import 'package:tracker/screens/home_screen.dart';
import 'package:tracker/services/model_service.dart';
import 'package:tracker/widgets/app_bottom_nav.dart';
import 'package:tracker/widgets/category_pie_chart.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await DBHelper.reset();
    // The app tests start past the first-run onboarding.
    await DBHelper.setSetting('onboarding_complete', 'true');
  });

  tearDown(() async {
    await DBHelper.reset();
  });

  Future<void> skipWithoutModel() async {
    if (!await ModelService.isDownloaded()) {
      markTestSkipped(
          'voice model not present on this device — download it once in-app');
    }
  }

  testWidgets('ONNX inference produces a parseable expense on device',
      (tester) async {
    await skipWithoutModel();
    await OnnxChannel.loadTokenizer();

    final raw = await OnnxChannel.runInference('bought 3 eggs for 50 taka');
    expect(raw, isNotEmpty);

    final expense = ExpenseParser.fromRawJson(raw);
    expect(expense, isNotNull,
        reason: 'raw model output: "$raw"');
  });

  testWidgets('parse -> save -> history (pie chart) -> edit flow',
      (tester) async {
    await skipWithoutModel();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ExpenseProvider(),
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    // Resolve the provider from the widget tree.
    final ctx = tester.element(find.byType(AppBottomNav));
    final provider = ctx.read<ExpenseProvider>();

    // Run on-device inference (STT is exercised separately on physical hardware).
    final raw = await OnnxChannel.runInference('took a bus fare for 40 taka');
    final expense = ExpenseParser.fromRawJson(raw);
    expect(expense, isNotNull, reason: 'raw: "$raw"');
    await provider.addExpense(expense!);
    await tester.pump(const Duration(milliseconds: 500));

    // Home tab shows the grouped list with a Day/Month/Year toggle.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text(expense.item), findsOneWidget);

    // Floating mic button hovers at the bottom right on the home tab.
    expect(find.byTooltip('Tap to speak'), findsOneWidget);

    // Switch to the History tab via the bottom navigation bar.
    await tester.tap(find.byIcon(Icons.pie_chart));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryPieChart), findsOneWidget);
    expect(find.text(expense.item), findsOneWidget);

    // Back to the home tab.
    await tester.tap(find.byIcon(Icons.receipt_long));
    await tester.pumpAndSettle();
    expect(find.text('Day'), findsOneWidget);
  });
}
