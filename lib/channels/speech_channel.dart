import 'package:flutter/services.dart';

class SpeechChannel {
  static const _channel = MethodChannel('com.expense.tracker/speech');

  static Future<String> startListening() async {
    final result = await _channel.invokeMethod<String>('startListening');
    return result ?? '';
  }

  static Future<void> stopListening() async {
    await _channel.invokeMethod('stopListening');
  }
}
