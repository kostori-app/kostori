import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:media_kit/media_kit.dart';

class PlayerAudioHandler extends BaseAudioHandler {
  PlayerController? _controller;

  int _headsetClicksCount = 0;
  Timer? _headsetButtonClickTimer;
  bool _willPlayWhenReady = true;

  Timer _createHeadsetClicksTimer(FutureOr<void> Function() callback) {
    return Timer(const Duration(milliseconds: 250), () async {
      try {
        await callback();
      } finally {
        _headsetButtonClickTimer?.cancel();
        _headsetButtonClickTimer = null;
        _headsetClicksCount = 0;
      }
    });
  }

  // 用于存放所有事件监听的订阅，方便统一取消
  final List<StreamSubscription> _subscriptions = [];

  // 页面初始化 PlayerController 后调用
  void setController(PlayerController controller) {
    try {
      _clearListeners();

      _controller = controller;

      final player = controller.player;

      // 监听播放状态
      _subscriptions.add(
        player.stream.playing.listen((_) => _broadcastState()),
      );

      // 监听播放完成事件
      _subscriptions.add(
        player.stream.completed.listen((_) => _broadcastState()),
      );

      // 监听缓冲状态变化
      _subscriptions.add(
        player.stream.buffering.listen((_) => _broadcastState()),
      );

      // 监听播放进度变化
      _subscriptions.add(
        player.stream.position.listen((_) => _broadcastState()),
      );

      // 设置 Controller 后，立即广播一次当前状态
      _broadcastState();
      Log.addLog(LogLevel.info, "setController", '初始化系统通知栏');
    } catch (e) {
      Log.addLog(LogLevel.error, "setController", e.toString());
    }
  }

  // 统一的取消监听方法
  Future<void> _clearListeners() async {
    try {
      for (final subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();
    } catch (e) {
      Log.addLog(LogLevel.error, "_clearListeners", e.toString());
    }
  }

  void _broadcastState() {
    // 如果 controller 不存在了，就不要广播了
    if (_controller == null) return;

    final player = _controller!.player;

    final title = _controller!.currentSetName;
    final artUri = _controller!.animeImg;

    mediaItem.add(
      MediaItem(
        id: _controller!.videoUrl,
        title: WatcherState.currentState!.widget.anime.title,
        artUri: artUri.isNotEmpty ? Uri.parse(artUri) : null,
        artist: title,
        duration: _controller!.duration,
        album: '',
        genre: '',
      ),
    );
    playbackState.add(
      playbackState.value.copyWith(
        playing: player.state.playing,
        updatePosition: player.state.position,
        bufferedPosition: player.state.buffer,
        controls: [
          player.state.playing
              ? MediaControl(
                  androidIcon: 'drawable/audio_service_pause',
                  label: 'Pause',
                  action: MediaAction.pause,
                )
              : MediaControl(
                  androidIcon: 'drawable/audio_service_play_arrow',
                  label: 'Play',
                  action: MediaAction.play,
                ),
          MediaControl(
            androidIcon: 'drawable/audio_service_skip_next',
            label: 'SkipToNext',
            action: MediaAction.skipToNext,
          ),
          MediaControl(
            androidIcon: 'drawable/audio_service_stop',
            label: 'Stop',
            action: MediaAction.stop,
          ),
        ],
        processingState: _getProcessingState(player.state),
        queueIndex: 0,
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
      ),
    );

    if (appdata.settings['debugInfo']) {
      Log.addLog(
        LogLevel.info,
        "_broadcastState",
        "更新状态中: \n playing: ${player.state.playing} \n updatePosition: ${player.state.position} \n bufferedPosition: ${player.state.buffer} \n updated: ${playbackState.value} \n duration: ${_controller!.duration} \n _getProcessingState: ${_getProcessingState(player.state)}",
      );
    }
  }

  AudioProcessingState _getProcessingState(PlayerState playerState) {
    if (playerState.buffering) return AudioProcessingState.buffering;
    if (playerState.completed) return AudioProcessingState.completed;
    return AudioProcessingState.ready;
  }

  @override
  Future<void> play() {
    Log.addLog(LogLevel.info, "AudioService.play", "${_controller?.playing}");
    _willPlayWhenReady = true;
    return _controller?.play(isAudioHandler: false) ?? Future.value();
  }

  @override
  Future<void> pause() {
    Log.addLog(LogLevel.info, "AudioService.pause", "${_controller?.playing}");
    _willPlayWhenReady = false;
    return _controller?.pause() ?? Future.value();
  }

  @override
  Future<void> skipToNext() {
    Log.addLog(
      LogLevel.info,
      "AudioService.skipToNext",
      "${_controller?.playing}",
    );
    return _controller?.playNextEpisode() ?? Future.value();
  }

  @override
  Future<void> stop() async {
    try {
      await _clearListeners().then((_) async {
        if (_controller != null) {
          try {
            await _controller!.pause();
          } catch (_) {
          } finally {
            playbackState.add(
              PlaybackState(
                playing: false,
                processingState: AudioProcessingState.idle,
              ),
            );
            mediaItem.add(null);
          }
        }
      });

      Log.addLog(LogLevel.info, "stop", "updated: ${playbackState.value}");
    } catch (e) {
      Log.addLog(LogLevel.error, "stop", e.toString());
    }
  }

  @override
  Future<void> seek(Duration position) =>
      _controller?.player.seek(position) ?? Future.value();

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button == MediaButton.next) {
      skipToNext();
      return;
    }

    _headsetClicksCount++;

    _headsetButtonClickTimer?.cancel();

    if (_headsetClicksCount == 1) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(
        _willPlayWhenReady ? pause : play,
      );
    } else if (_headsetClicksCount == 2) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(skipToNext);
    }
  }

  @override
  Future<void> fastForward() async {
    final player = _controller?.player;
    if (player == null) return;

    final current = player.state.position;
    final target = current + const Duration(seconds: 10);

    await player.seek(target);
  }

  @override
  Future<void> rewind() async {
    final player = _controller?.player;
    if (player == null) return;

    final current = player.state.position;
    var target = current - const Duration(seconds: 10);
    if (target < Duration.zero) {
      target = Duration.zero;
    }

    await player.seek(target);
  }
}
