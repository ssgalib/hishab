import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../channels/onnx_channel.dart';
import '../database/db_helper.dart';
import '../services/model_downloader.dart';
import '../services/model_service.dart';

/// Lifecycle of the on-device voice model.
enum ModelState { checking, missing, downloading, ready, error }

typedef ModelDownloadFn = Future<void> Function({
  required String savePath,
  required void Function(int received, int? total) onProgress,
  required bool Function() isCancelled,
});

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({@visibleForTesting ModelDownloadFn? downloadModel})
      : _downloadModel = downloadModel ?? _defaultDownload;

  static Future<void> _defaultDownload({
    required String savePath,
    required void Function(int received, int? total) onProgress,
    required bool Function() isCancelled,
  }) {
    return ModelDownloader.download(
      url: ModelDownloader.modelUrl,
      savePath: savePath,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  final ModelDownloadFn _downloadModel;

  List<Expense> _expenses = [];
  bool _isListening = false;
  bool _isProcessing = false;
  String _voiceText = '';

  /// Null while a flag is still loading from the database / filesystem.
  bool? _onboardingComplete;
  ModelState _modelState = ModelState.checking;
  int _modelReceived = 0;
  int? _modelTotal;
  String? _modelError;
  bool _modelLater = false;
  String? _modelPath;
  bool _cancelRequested = false;
  DateTime _lastProgressNotify = DateTime.fromMillisecondsSinceEpoch(0);

  List<Expense> get expenses => _expenses;
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  bool? get onboardingComplete => _onboardingComplete;

  /// Lifecycle of the voice model file (checking → missing/ready → downloading).
  ModelState get modelState => _modelState;

  /// True when the model file is present and usable.
  bool get modelReady => _modelState == ModelState.ready;

  /// True when the user picked "I'll do this later" this session — the main
  /// app stays usable (manual entry) and the mic routes to setup.
  bool get modelLater => _modelLater;
  int get modelReceived => _modelReceived;
  int? get modelTotal => _modelTotal;
  String? get modelError => _modelError;

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
    try {
      _onboardingComplete =
          await DBHelper.getSetting('onboarding_complete') == 'true';
    } catch (_) {
      _onboardingComplete = false;
    }
    notifyListeners();
  }

  /// Resolves the model file location, tells the native side, and checks
  /// whether the model is already on the device (or migrated by Kotlin from
  /// a pre-1.1 install). Call once at boot.
  Future<void> initModel() async {
    try {
      _modelPath = await ModelService.modelPath();
      await OnnxChannel.setModelPath(_modelPath!);
      _modelState = await ModelService.isDownloaded()
          ? ModelState.ready
          : ModelState.missing;
    } catch (_) {
      // Path resolution failed (storage unavailable?) — keep the gate closed
      // so the user sees the setup screen instead of a broken mic.
      _modelState = ModelState.missing;
    }
    notifyListeners();
  }

  Future<void> startModelDownload() async {
    if (_modelState == ModelState.downloading) return;
    final path = _modelPath;
    if (path == null) {
      _modelState = ModelState.error;
      _modelError = 'Storage unavailable';
      notifyListeners();
      return;
    }
    _modelState = ModelState.downloading;
    _modelReceived = 0;
    _modelTotal = null;
    _modelError = null;
    _cancelRequested = false;
    notifyListeners();

    try {
      await _downloadModel(
        savePath: path,
        onProgress: _onDownloadProgress,
        isCancelled: () => _cancelRequested,
      );
      _modelState = ModelState.ready;
      _lastProgressNotify = DateTime.now();
    } on ModelCancelledException {
      _modelState = ModelState.missing;
    } catch (e) {
      _modelState = ModelState.error;
      _modelError = e.toString();
    }
    notifyListeners();
  }

  void _onDownloadProgress(int received, int? total) {
    _modelReceived = received;
    _modelTotal = total;
    // Throttle rebuilds: at most ~5/sec.
    final now = DateTime.now();
    if (now.difference(_lastProgressNotify).inMilliseconds >= 200) {
      _lastProgressNotify = now;
      notifyListeners();
    }
  }

  void cancelModelDownload() {
    _cancelRequested = true;
  }

  /// "I'll do this later" — lasts for this session only.
  void chooseLaterWithoutModel() {
    _modelLater = true;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    try {
      await DBHelper.setSetting('onboarding_complete', 'true');
    } catch (_) {
      // A failed write must not trap the user in onboarding; the flag will
      // be re-asked next launch instead.
    }
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
