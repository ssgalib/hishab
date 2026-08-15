import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: expenses.isEmpty
          ? const Center(child: Text('No expenses yet'))
          : ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (ctx, i) {
                final e = expenses[i];
                return Dismissible(
                  key: Key(e.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      context.read<ExpenseProvider>().deleteExpense(e.id!),
                  child: ListTile(
                    title: Text(e.item),
                    subtitle: Text(
                      '${e.category} · ${e.createdAt.day}/${e.createdAt.month}/${e.createdAt.year}',
                    ),
                    trailing: Text('${e.amount} ৳',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
    );
  }
}
