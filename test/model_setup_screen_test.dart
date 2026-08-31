import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tracker/providers/expense_provider.dart';
import 'package:tracker/screens/model_setup_screen.dart';
import 'package:tracker/services/model_downloader.dart';
import 'package:tracker/services/model_service.dart';

const _onnxChannel = MethodChannel('com.expense.tracker/onnx');

Future<ExpenseProvider> pump(WidgetTester tester,
    {required ModelDownloadFn downloadRun}) async {
  // initModel talks to the native side; unmocked channels never reply in
  // widget tests, which would hang the await forever.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _onnxChannel,
    (call) async => true,
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(_onnxChannel, null));

  final provider = ExpenseProvider(downloadModel: downloadRun);
  await tester.pumpWidget(
    ChangeNotifierProvider<ExpenseProvider>.value(
      value: provider,
      child: const MaterialApp(home: ModelSetupScreen()),
    ),
  );
  await provider.initModel();
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  setUpAll(() {
    final tmp = Directory.systemTemp.createTempSync('model_setup_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    // Points the file check at an empty temp dir → model "missing".
    ModelService.debugPathOverride = '${tmp.path}/models/model.onnx';
  });

  tearDownAll(() {
    ModelService.debugPathOverride = null;
  });

  testWidgets('idle state shows download button and later link',
      (tester) async {
    await pump(tester, downloadRun: ({required url, required savePath, required onProgress, required isCancelled}) async {});

    expect(find.text('One-time setup'), findsOneWidget);
    expect(find.text('~1.2 GB'), findsOneWidget);
      expect(find.text('Parser + speech models, downloaded once'), findsOneWidget);
    expect(find.text('Download model — free'), findsOneWidget);
    expect(find.text("I'll do this later"), findsOneWidget);
  });

  testWidgets('download progresses to model ready', (tester) async {
    final done = Completer<void>();
    final provider = await pump(
      tester,
      downloadRun: ({required url, required savePath, required onProgress, required isCancelled}) =>
          done.future,
    );

    await tester.tap(find.text('Download model — free'));
    await tester.pump();
    expect(provider.modelState, ModelState.downloading);
    expect(find.text('Cancel'), findsOneWidget);

    done.complete();
    await tester.pumpAndSettle();
    expect(provider.modelReady, isTrue);
    expect(find.textContaining('Model ready'), findsOneWidget);
  });

  testWidgets('failure shows the error state with retry', (tester) async {
    final provider = await pump(
      tester,
      downloadRun:
          ({required url, required savePath, required onProgress, required isCancelled}) async =>
              throw const ModelDownloadException('offline'),
    );

    await tester.tap(find.text('Download model — free'));
    await tester.pumpAndSettle();

    expect(provider.modelState, ModelState.error);
    expect(find.text('Download failed. Check your connection and try again.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('"I\'ll do this later" marks the session', (tester) async {
    final provider = await pump(
      tester,
      downloadRun:
          ({required url, required savePath, required onProgress, required isCancelled}) async {},
    );

    await tester.tap(find.text("I'll do this later"));
    await tester.pumpAndSettle();

    expect(provider.modelLater, isTrue);
    expect(provider.modelReady, isFalse);
  });
}
