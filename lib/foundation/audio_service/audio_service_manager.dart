import 'package:audio_service/audio_service.dart';
import 'package:kostori/foundation/audio_service/player_audio_handler.dart';
import 'package:kostori/foundation/log.dart';

class AudioServiceManager {
  static final AudioServiceManager _instance = AudioServiceManager._internal();

  factory AudioServiceManager() => _instance;

  AudioServiceManager._internal();

  PlayerAudioHandler? _handler;
  bool _isInitialized = false;

  PlayerAudioHandler get handler {
    if (!_isInitialized) {
      Log.addLog(
        LogLevel.error,
        'handler',
        "AudioHandler has not been initialized yet",
      );
      throw Exception('AudioHandler has not been initialized yet');
    }
    return _handler!;
  }

  // 初始化 handler
  Future<void> initializeHandler() async {
    _handler = await AudioService.init(
      builder: () => PlayerAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.axlmly.kostori',
        androidNotificationChannelName: 'Kostori',
        androidNotificationChannelDescription: 'Kostori Media Notification',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
    _isInitialized = true;
  }
}
