import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../database/db_helper.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> _expenses = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String _voiceText = '';

  /// Null while the flag is still loading from the database.
  bool? _onboardingComplete;

  List<Expense> get expenses => _expenses;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  bool? get onboardingComplete => _onboardingComplete;

  /// Text heard so far (partial results stream in while listening, then the
  /// final recognition when processing starts). Drives the voice caption.
  String get voiceText => _voiceText;

  @visibleForTesting
  void debugSetExpenses(List<Expense> expenses) {
    _expenses = List.of(expenses);
    notifyListeners();
  }

  Future<void> loadExpenses() async {
    try {
      _expenses = await DBHelper.getAllExpenses();
    } catch (_) {
      _expenses = const [];
    }
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

  void setVoiceText(String value) {
    if (_voiceText == value) return;
    _voiceText = value;
    notifyListeners();
  }

  Future<void> loadOnboardingFlag() async {
    _onboardingComplete =
        await DBHelper.getSetting('onboarding_complete') == 'true';
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await DBHelper.setSetting('onboarding_complete', 'true');
    _onboardingComplete = true;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await DBHelper.insertExpense(expense);
    await loadExpenses();
  }

  Future<void> updateExpense(Expense expense) async {
    await DBHelper.updateExpense(expense);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    // Remove optimistically so the dismissed tile leaves the widget tree in
    // the same frame as the swipe, then persist and reconcile from the DB.
    _expenses = List.of(_expenses)..removeWhere((e) => e.id == id);
    notifyListeners();
    await DBHelper.deleteExpense(id);
    await loadExpenses();
  }

  /// Re-inserts a previously deleted [expense] (keeps its original date).
  Future<void> restoreExpense(Expense expense) async {
    await DBHelper.insertExpense(
      Expense(
        item: expense.item,
        quantity: expense.quantity,
        amount: expense.amount,
        category: expense.category,
        createdAt: expense.createdAt,
      ),
    );
    await loadExpenses();
  }

  Future<void> clearAll() async {
    _expenses = const [];
    notifyListeners();
    await DBHelper.clearAll();
  }
}
