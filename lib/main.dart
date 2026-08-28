import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'channels/onnx_channel.dart';
import 'channels/speech_channel.dart';
import 'models/expense_parser.dart';
import 'providers/expense_provider.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';

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

    final expense = ExpenseParser.fromRawJson(rawJson);
    if (expense != null) {
      await provider.addExpense(expense);
      if (!mounted) return;
      provider.setStatus(
        'Saved: ${expense.item} — ${expense.amount} taka (${expense.category})',
      );
    } else {
      provider.setStatus('Could not parse: $rawJson');
    }
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
            ? FloatingActionButton(
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
