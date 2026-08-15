import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../database/db_helper.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String _statusMessage = '';

  List<Expense> get expenses => _expenses;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  String get statusMessage => _statusMessage;

  @visibleForTesting
  void debugSetExpenses(List<Expense> expenses) {
    _expenses = List.of(expenses);
    notifyListeners();
  }

  Future<void> loadExpenses() async {
    _expenses = await DBHelper.getAllExpenses();
    notifyListeners();
  }

  void setListening(bool value) {
    _isListening = value;
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void setStatus(String message) {
    _statusMessage = message;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await DBHelper.insertExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    await DBHelper.deleteExpense(id);
    await loadExpenses();
  }
}
