import 'package:flutter/services.dart';

class SpeechChannel {
  static const _channel = MethodChannel('com.expense.tracker/speech');

  /// Called with intermediate recognition results while listening.
  static void Function(String partial)? onPartial;

  static Future<String> startListening() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPartialResult') {
        onPartial?.call(call.arguments as String? ?? '');
      }
      return null;
    });
    try {
      final result = await _channel.invokeMethod<String>('startListening');
      return result ?? '';
    } finally {
      _channel.setMethodCallHandler(null);
    }
  }

  static Future<void> stopListening() async {
    await _channel.invokeMethod('stopListening');
  }
}
