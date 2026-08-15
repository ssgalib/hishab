import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../channels/speech_channel.dart';
import '../channels/onnx_channel.dart';
import '../models/expense_parser.dart';
import '../providers/expense_provider.dart';
import 'history_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    OnnxChannel.loadTokenizer();
    context.read<ExpenseProvider>().loadExpenses();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SummaryScreen())),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              provider.statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          GestureDetector(
            onTap: provider.isListening || provider.isProcessing
                ? null
                : _handleMicPressed,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.isListening
                    ? Colors.red
                    : provider.isProcessing
                        ? Colors.orange
                        : Colors.blue,
              ),
              child: Icon(
                provider.isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            provider.isListening
                ? 'Tap to stop'
                : provider.isProcessing
                    ? 'Processing...'
                    : 'Tap to speak',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: provider.expenses.length > 10
                  ? 10
                  : provider.expenses.length,
              itemBuilder: (ctx, i) {
                final e = provider.expenses[i];
                return ListTile(
                  leading: _categoryIcon(e.category),
                  title: Text(e.item),
                  subtitle: Text(e.quantity != null
                      ? '${e.quantity} · ${e.category}'
                      : e.category),
                  trailing: Text('${e.amount} ৳',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon(String category) {
    const icons = {
      'food': Icons.restaurant,
      'transport': Icons.directions_car,
      'utilities': Icons.bolt,
      'rent': Icons.home,
      'medicine': Icons.medical_services,
      'education': Icons.school,
      'entertainment': Icons.movie,
      'mobile': Icons.phone_android,
    };
    return Icon(icons[category] ?? Icons.attach_money);
  }
}
