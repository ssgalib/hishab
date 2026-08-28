import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'channels/onnx_channel.dart';
import 'channels/speech_channel.dart';
import 'models/expense.dart';
import 'models/expense_parser.dart';
import 'providers/expense_provider.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/edit_expense_sheet.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: const App(),
    ),
  );
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Preload the tokenizer while the app boots.
    OnnxChannel.loadTokenizer();
  }

  Future<void> _handleMicPressed() async {
    final provider = context.read<ExpenseProvider>();

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      provider.setStatus('Microphone permission denied');
      return;
    }

    provider.setListening(true);
    provider.setStatus('Listening...');
    final spokenText = await SpeechChannel.startListening();
    if (!mounted) return;
    provider.setListening(false);

    if (spokenText.isEmpty) {
      provider.setStatus('No speech detected');
      return;
    }

    provider.setStatus('Recognized: "$spokenText"\nProcessing...');
    provider.setProcessing(true);

    final rawJson = await OnnxChannel.runInference(spokenText);
    if (!mounted) return;
    provider.setProcessing(false);

    var expense = ExpenseParser.fromRawJson(rawJson);
    expense ??= Expense(
      item: spokenText,
      amount: 0,
      category: 'food',
      createdAt: DateTime.now(),
    );

    if (ExpenseParser.needsReview(expense)) {
      // Missing amount or item: let the user fix it before saving.
      provider.setStatus('Review details for: "$spokenText"');
      final saved = await showEditExpenseSheet(context, expense);
      if (!mounted) return;
      if (saved == null) {
        provider.setStatus('Entry discarded');
        return;
      }
      expense = saved;
    }

    await provider.addExpense(expense);
    if (!mounted) return;
    provider.setStatus(
      'Saved: ${expense.item} — ${expense.amount} taka (${expense.category})',
    );
  }

  Future<void> _addManually() async {
    final provider = context.read<ExpenseProvider>();
    final saved = await showEditExpenseSheet(context);
    if (saved == null || !mounted) return;
    await provider.addExpense(saved);
    provider.setStatus('Saved: ${saved.item} — ${saved.amount} taka');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: const [
            HomeScreen(),
            HistoryScreen(),
          ],
        ),
        floatingActionButton: _tab == 0
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'addManual',
                    tooltip: 'Add manually',
                    onPressed: _addManually,
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'mic',
                    onPressed:
                        provider.isListening || provider.isProcessing
                            ? null
                            : _handleMicPressed,
                    tooltip: 'Tap to speak',
                    backgroundColor: provider.isListening
                        ? Theme.of(context).colorScheme.error
                        : provider.isProcessing
                            ? Colors.orange
                            : null,
                    child: Icon(provider.isListening
                        ? Icons.mic
                        : Icons.mic_none),
                  ),
                ],
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
