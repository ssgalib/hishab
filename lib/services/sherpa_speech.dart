import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'model_service.dart';

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
  static sherpa.OfflineRecognizer? _offline;
  static bool _offlineFailed = false;
  static sherpa.OnlineStream? _stream;
  static AudioRecorder? _recorder;
  static StreamSubscription<Uint8List>? _micSub;
  static Completer<String>? _pending;
  static void Function(String partial)? _onPartial;
  static String _lastPartial = '';
  static final List<Float32List> _buffer = [];
  static int _bufferedSamples = 0;
  static const _maxBufferedSamples = 16000 * 30; // cap: 30 s of audio

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

  static bool get whisperLoaded => _offline != null;

  /// Creates the offline final-pass recognizer (SenseVoice Small — strong
  /// on Asian-accented English) once its model files are downloaded. Idempotent, never throws — when anything is
  /// missing or fails, recognition simply falls back to the streaming
  /// transcript.
  static Future<void> loadOfflineRecognizer(String dir) async {
    try {
      if (_offline != null || _offlineFailed) return;
      await ensureLoaded();
      if (_offlineFailed) return;
      for (final name in ModelService.speechFiles) {
        if (!File('$dir/$name').existsSync()) return;
      }
      _offline = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          model: sherpa.OfflineModelConfig(
            transducer: sherpa.OfflineTransducerModelConfig(
              encoder: '$dir/encoder.int8.onnx',
              decoder: '$dir/decoder.int8.onnx',
              joiner: '$dir/joiner.int8.onnx',
            ),
            tokens: '$dir/tokens.txt',
            numThreads: 2,
            debug: false,
          ),
        ),
      );
    } catch (_) {
      _offlineFailed = true;
    }
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
      androidConfig: AndroidRecordConfig(
        // The source Google's own recognizer uses: noise suppression and
        // automatic gain control tuned for ASR. Raw MIC audio is far too
        // fragile for accented speech at arm's length.
        audioSource: AndroidAudioSource.voiceRecognition,
      ),
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    _micSub = micStream.listen((data) async {
      if (_pending == null || completer.isCompleted) return;
      try {
        // Chunks arrive at arbitrary byte offsets/sizes — drop a trailing
        // odd byte and decode via ByteData (no alignment requirement).
        final usable = data.lengthInBytes & ~1;
        if (usable == 0) return;
        final view = ByteData.view(
            data.buffer, data.offsetInBytes, usable);
        final floats = Float32List(usable ~/ 2);
        for (var i = 0; i < floats.length; i++) {
          floats[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
        }
        // Keep the audio for the offline final pass (bounded).
        if (_bufferedSamples < _maxBufferedSamples) {
          _buffer.add(floats);
          _bufferedSamples += floats.length;
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
      } catch (_) {
        // A malformed chunk must never kill the listening session.
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
    var text = '';
    if (stream != null && recognizer != null) {
      stream.inputFinished();
      while (recognizer.isReady(stream)) {
        recognizer.decode(stream);
      }
      text = recognizer.getResult(stream).text.trim();
    }

    // Final pass: the accent-robust offline model re-recognizes the same
    // audio; its transcript is what Gemma parses.
    if (_offline != null && _bufferedSamples > 0) {
      try {
        final all = Float32List(_bufferedSamples);
        var at = 0;
        for (final chunk in _buffer) {
          all.setAll(at, chunk);
          at += chunk.length;
        }
        _buffer.clear();
        _bufferedSamples = 0;
        final offlineStream = _offline!.createStream();
        offlineStream.acceptWaveform(samples: all, sampleRate: 16000);
        _offline!.decode(offlineStream);
        final offlineText = _offline!.getResult(offlineStream).text.trim();
        if (offlineText.isNotEmpty) text = offlineText;
      } catch (_) {
        _buffer.clear();
        _bufferedSamples = 0;
        // Keep the streaming transcript on any offline-pass failure.
      }
    } else {
      _buffer.clear();
      _bufferedSamples = 0;
    }

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
