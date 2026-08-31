import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Where the on-device voice model lives, and whether it's present.
///
/// Dart and Kotlin must agree on the location: `getApplicationSupportDirectory()`
/// maps to the app's internal `files/` directory on Android, which is exactly
/// where `OnnxChannel.kt` looks by default.
class ModelService {
  ModelService._();

  static const modelFileName = 'model.onnx';
  static const modelDirName = 'models';
  static const speechDirName = 'speech';

  /// Which speech model is active. Swapping models means changing this id,
  /// the file list, and the base URL in [ModelDownloader].
  static const speechModelId = 'nemo-parakeet-tdt-0.6b-v2-int8';

  /// The files that make up the active speech model.
  static const speechFiles = [
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
  ];

  @visibleForTesting
  static String? debugPathOverride;

  static String? _cachedDir;

  /// Absolute path of the downloaded parser model file.
  static Future<String> modelPath() async {
    final override = debugPathOverride;
    if (override != null) return override;
    _cachedDir ??= (await getApplicationSupportDirectory()).path;
    return '$_cachedDir/$modelDirName/$modelFileName';
  }

  /// Directory holding the downloaded speech model files, isolated per
  /// model id so switching models never mixes incompatible files.
  static Future<String> speechDir() async {
    final override = debugPathOverride;
    if (override != null) return '$override/../speech/$speechModelId';
    _cachedDir ??= (await getApplicationSupportDirectory()).path;
    return '$_cachedDir/$speechDirName/$speechModelId';
  }

  /// Partial download target, kept for resuming interrupted downloads.
  static Future<String> partPath() async => '${await modelPath()}.part';

  /// True when a model file exists on disk (any non-empty file; deeper
  /// validation happens when ONNX opens it).
  static Future<bool> isDownloaded() async {
    final override = debugPathOverride;
    if (override != null) {
      final f = File(override);
      return f.existsSync() && f.lengthSync() > 0;
    }
    final file = File(await modelPath());
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// True when all speech-model files are present.
  static Future<bool> isSpeechDownloaded() async {
    final dir = Directory(await speechDir());
    if (!dir.existsSync()) return false;
    for (final name in speechFiles) {
      final f = File('${dir.path}/$name');
      if (!f.existsSync() || f.lengthSync() == 0) return false;
    }
    return true;
  }

  /// Deletes leftovers from previously active speech models so abandoned
  /// downloads don't squat storage. Best-effort; no-op in tests.
  static Future<void> sweepStaleSpeechModels() async {
    if (debugPathOverride != null) return;
    _cachedDir ??= (await getApplicationSupportDirectory()).path;
    final root = Directory('$_cachedDir/$speechDirName');
    if (!root.existsSync()) return;
    for (final entry in root.listSync()) {
      if (entry.path.endsWith('/$speechModelId')) continue;
      try {
        entry.deleteSync(recursive: true);
      } catch (_) {}
    }
    for (final name in speechFiles) {
      final stale = File('${root.path}/$name');
      if (stale.existsSync()) {
        try {
          stale.deleteSync();
        } catch (_) {}
      }
    }
  }
}
