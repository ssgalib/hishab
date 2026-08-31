import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'channels/onnx_channel.dart';
import 'models/expense.dart';
import 'models/expense_parser.dart';
import 'providers/expense_provider.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/model_setup_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/sherpa_speech.dart';
import 'theme/app_theme.dart';
import 'utils/format.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/edit_expense_sheet.dart';
import 'widgets/glass.dart';
import 'widgets/mic_button.dart';
import 'widgets/parse_error_sheet.dart';
import 'widgets/voice_caption.dart';

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

  /// Context below the Navigator, for sheets and snackbars triggered from
  /// the voice flow (the App state's own context sits above MaterialApp).
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Preload the tokenizer, the onboarding flag, and the model state while
    // the app boots.
    OnnxChannel.loadTokenizer();
    final provider = context.read<ExpenseProvider>();
    provider.loadOnboardingFlag();
    provider.initModel();
  }

  void _snack(String message, {SnackBarAction? action}) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _saveExpense(Expense expense) async {
    try {
      await context.read<ExpenseProvider>().addExpense(expense);
    } catch (_) {
      if (!mounted) return;
      _snack("Couldn't save — please try again.");
      return;
    }
    if (!mounted) return;
    _snack('Saved · ${fmtTaka(expense.amount)}');
    setState(() => _tab = 0);
  }

  Future<void> _handleMicPressed() async {
    final provider = context.read<ExpenseProvider>();

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _snack(
        status.isPermanentlyDenied
            ? 'Microphone is off for Hishab — enable it in Settings.'
            : 'Microphone permission denied',
        action: status.isPermanentlyDenied
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      );
      return;
    }

    provider.setVoiceText('');
    provider.setListening(true);
    String spokenText;
    try {
      spokenText = await SherpaSpeech.startListening(
        onPartial: provider.setVoiceText,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          unawaited(SherpaSpeech.stopListening());
          throw TimeoutException('listening timed out');
        },
      );
    } on TimeoutException {
      if (!mounted) return;
      provider.setListening(false);
      provider.setProcessing(false);
      _snack("Didn't hear anything. Tap the mic and try again.");
      return;
    } on Exception catch (_) {
      if (!mounted) return;
      provider.setListening(false);
      provider.setProcessing(false);
      _snack('Microphone failed. Close other apps using it and try again.');
      return;
    }
    if (!mounted) return;
    provider.setListening(false);

    if (spokenText.isEmpty) {
      provider.setProcessing(false);
      _snack('No speech detected');
      return;
    }

    provider.setVoiceText(spokenText);
    provider.setProcessing(true);
    String rawJson;
    try {
      rawJson = await OnnxChannel.runInference(spokenText);
    } catch (_) {
      // Model load failure, OOM, ONNX error — never leave the mic wedged.
      if (!mounted) return;
      provider.setProcessing(false);
      _snack("Couldn't analyze that — tap the mic and try again.");
      return;
    }
    if (!mounted) return;
    provider.setProcessing(false);

    final expense = ExpenseParser.fromRawJson(rawJson);
    if (expense == null) {
      await _handleParseError(spokenText);
      return;
    }
    await _reviewAndSave(expense, spokenText);
  }

  /// Opens the review sheet for a parsed expense and saves on confirm.
  Future<void> _reviewAndSave(Expense expense, String heard) async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    final saved = await showEditExpenseSheet(navigatorContext, expense, heard);
    if (!mounted) return;
    if (saved == null) {
      _snack('Entry discarded');
      return;
    }
    await _saveExpense(saved);
  }

  Future<void> _handleParseError(String heard) async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    final action = await showParseErrorSheet(navigatorContext, heard: heard);
    if (!mounted || action == null) return;
    if (action == ParseErrorAction.retry) {
      await _handleMicPressed();
    } else {
      await _addManually();
    }
  }

  Future<void> _addManually() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    final saved = await showEditExpenseSheet(navigatorContext);
    if (saved == null || !mounted) return;
    await _saveExpense(saved);
  }

  /// Called when the mic is tapped while listening: stops the recognizer.
  /// The pending [SherpaSpeech.startListening] future then completes with
  /// the final transcript.
  Future<void> _stopListening() async {
    await SherpaSpeech.stopListening();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final onboarding = provider.onboardingComplete;
    final showSetup =
        onboarding == true && !provider.modelReady && !provider.modelLater;

    final checking = provider.modelState == ModelState.checking ||
        provider.whisperState == ModelState.checking;

    return MaterialApp(
      title: 'Hishab',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      home: onboarding == null || checking
          ? const Scaffold(
              backgroundColor: AppColors.bg,
              body: SizedBox.expand(),
            )
          : onboarding == false
              ? OnboardingScreen(onFinish: _finishOnboarding)
              : showSetup
                  ? ModelSetupScreen()
                  : _mainScaffold(provider),
    );
  }

  void _finishOnboarding() {
    context.read<ExpenseProvider>().completeOnboarding();
  }

  Widget _mainScaffold(ExpenseProvider provider) {
    final media = MediaQuery.of(context);
    final listening = provider.isListening;
    final processing = provider.isProcessing;
    final modelReady = provider.modelReady;

    void openModelSetup() {
      final navigatorContext = _navigatorKey.currentContext;
      if (navigatorContext == null) return;
      Navigator.of(navigatorContext).push(
        MaterialPageRoute<void>(
          builder: (_) => const ModelSetupScreen(popWhenReady: true),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [HomeScreen(), HistoryScreen()],
          ),
          if (listening || processing)
            Positioned(
              top: media.padding.top + 8,
              left: 20,
              right: 20,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: VoiceCaption(
                    label: listening
                        ? 'Listening — tap to stop'
                        : 'Parsing your expense…',
                    text: provider.voiceText,
                    processing: processing,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: AppBottomNav.height + media.padding.bottom + 16,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MicButton(
                  state: listening
                      ? MicState.listening
                      : processing
                      ? MicState.processing
                      : MicState.idle,
                  onTap: modelReady
                      ? (listening
                          ? _stopListening
                          : _handleMicPressed)
                      : openModelSetup,
                ),
                Positioned(
                  left: (media.size.width - 72) / 2 - 94,
                  top: 21,
                  child: _TypeButton(onTap: _addManually),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Type an expense',
      child: GlassContainer(
        radius: 999,
        shadowColor: AppColors.warmShadow,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.add, size: 20, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}
