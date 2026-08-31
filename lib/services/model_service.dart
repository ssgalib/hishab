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

  /// Directories left behind by the 1.2–1.3 third-party speech-model
  /// experiments (SenseVoice/Whisper/Parakeet).
  static const _legacyDirs = ['speech', 'whisper'];

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

  /// Deletes speech-model downloads left behind by the 1.2–1.3 experiments
  /// (~900 MB). Best-effort; safe to call repeatedly; no-op in tests.
  static Future<void> deleteExperimentalSpeechDownloads() async {
    try {
      if (debugPathOverride != null) return;
      _cachedDir ??= (await getApplicationSupportDirectory()).path;
      for (final name in _legacyDirs) {
        final dir = Directory('$_cachedDir/$name');
        if (dir.existsSync()) {
          try {
            dir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {
      // Storage probing must never stall boot.
    }
  }
}
