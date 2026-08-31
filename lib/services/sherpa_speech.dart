import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// On-device streaming speech recognition using sherpa-onnx with a bundled
/// streaming Zipformer (English, 20M params, INT8) — replaces Android's
/// SpeechRecognizer entirely.
///
/// Contract-compatible with the old native channel:
///   `startListening(onPartial)` → `Future<String>` final text
///   `stopListening()` → stops early; the pending future completes
/// Partials stream live while listening; a trailing-silence endpoint also
/// finalizes automatically.
class SherpaSpeech {
  SherpaSpeech._();

  static const _channelAssets = [
    'tokens.txt',
    'encoder-epoch-99-avg-1.int8.onnx',
    'decoder-epoch-99-avg-1.int8.onnx',
    'joiner-epoch-99-avg-1.int8.onnx',
  ];

  static bool _bindingsReady = false;
  static sherpa.OnlineRecognizer? _recognizer;
  static sherpa.OnlineStream? _stream;
  static AudioRecorder? _recorder;
  static StreamSubscription<Uint8List>? _micSub;
  static Completer<String>? _pending;
  static void Function(String partial)? _onPartial;
  static String _lastPartial = '';

  /// Loads the native lib and copies the bundled model to a readable path.
  /// Cheap no-op after the first call; safe to call at boot.
  static Future<void> ensureLoaded() async {
    if (_bindingsReady) return;
    sherpa.initBindings();
    final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/asr');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    for (final name in _channelAssets) {
      final target = File('${dir.path}/$name');
      if (!target.existsSync()) {
        final data = await rootBundle.load('assets/asr/$name');
        await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
    }
    _recognizer ??= sherpa.OnlineRecognizer(
      sherpa.OnlineRecognizerConfig(
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '${dir.path}/encoder-epoch-99-avg-1.int8.onnx',
            decoder: '${dir.path}/decoder-epoch-99-avg-1.int8.onnx',
            joiner: '${dir.path}/joiner-epoch-99-avg-1.int8.onnx',
          ),
          tokens: '${dir.path}/tokens.txt',
          numThreads: 2,
          debug: false,
        ),
        enableEndpoint: true,
        // ~2.4 s of silence finalizes the utterance on its own.
        rule1MinTrailingSilence: 2.4,
        rule2MinTrailingSilence: 1.2,
      ),
    );
    _bindingsReady = true;
  }

  static bool get isReady => _bindingsReady;

  /// Starts listening. Resolves with the final transcript when the user
  /// stops (stopListening), an endpoint is detected, or input ends.
  static Future<String> startListening({
    required void Function(String partial) onPartial,
  }) async {
    await ensureLoaded();
    if (_pending != null) {
      throw StateError('Already listening');
    }
    _onPartial = onPartial;
    _lastPartial = '';
    final completer = _pending = Completer<String>();

    final recognizer = _recognizer!;
    final stream = _stream = recognizer.createStream();
    final recorder = _recorder = AudioRecorder();

    final micStream = await recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    _micSub = micStream.listen((data) async {
      if (_pending == null || completer.isCompleted) return;
      // PCM16LE mono -> float in [-1, 1].
      final samples = Int16List.view(
          data.buffer, data.offsetInBytes, data.lengthInBytes ~/ 2);
      final floats = Float32List(samples.length);
      for (var i = 0; i < samples.length; i++) {
        floats[i] = samples[i] / 32768.0;
      }
      stream.acceptWaveform(samples: floats, sampleRate: 16000);
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
      final text = recognizer.getResult(stream).text.trim();
      if (text.isNotEmpty && text != _lastPartial) {
        _lastPartial = text;
        _onPartial?.call(text);
      }
      if (recognizer.isEndpoint(stream)) {
        await _finalize();
      }
    }, onError: (Object e) {
      _completeIfPending('');
    });

    return completer.future;
  }

  /// Stops the current session; the pending [startListening] future then
  /// completes with the final transcript.
  static Future<void> stopListening() async {
    await _finalize();
  }

  static Future<void> _finalize() async {
    final stream = _stream;
    final recognizer = _recognizer;
    if (stream != null && recognizer != null) {
      stream.inputFinished();
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
    }
    final text = recognizer?.getResult(stream!).text.trim() ?? '';
    await _micSub?.cancel();
    await _recorder?.stop();
    await _recorder?.dispose();
    _recorder = null;
    _micSub = null;
    _stream = null;
    _completeIfPending(text);
  }

  static void _completeIfPending(String text) {
    final pending = _pending;
    _pending = null;
    _onPartial = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete(text);
    }
  }
}
