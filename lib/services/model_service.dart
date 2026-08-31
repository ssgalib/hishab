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
  static const whisperDirName = 'whisper';

  /// The three files that make up the Whisper Base EN speech model.
  static const whisperFiles = [
    'base.en-encoder.int8.onnx',
    'base.en-decoder.int8.onnx',
    'base.en-tokens.txt',
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

  /// Directory holding the downloaded speech (Whisper) model files.
  static Future<String> whisperDir() async {
    final override = debugPathOverride;
    if (override != null) return '$override/../whisper';
    _cachedDir ??= (await getApplicationSupportDirectory()).path;
    return '$_cachedDir/$whisperDirName';
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
  static Future<bool> isWhisperDownloaded() async {
    final dir = Directory(await whisperDir());
    if (!dir.existsSync()) return false;
    for (final name in whisperFiles) {
      final f = File('${dir.path}/$name');
      if (!f.existsSync() || f.lengthSync() == 0) return false;
    }
    return true;
  }
}
