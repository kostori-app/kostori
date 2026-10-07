import 'package:flutter/services.dart';

class ExternalVideoIntent {
  ExternalVideoIntent._();

  static const _channel = MethodChannel('kostori/external_intent');
  static const _events = EventChannel('kostori/external_intent/events');

  static Stream<String>? _videoPathStream;

  static Stream<String> get videoPaths => _videoPathStream ??= _events
      .receiveBroadcastStream()
      .where((value) => value is String)
      .cast<String>();

  static Future<String?> getInitialVideoPath() async {
    try {
      return await _channel.invokeMethod<String>('getInitialVideo');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
