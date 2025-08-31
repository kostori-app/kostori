import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:media_kit/media_kit.dart';

class PlayerAudioHandler extends BaseAudioHandler {
  PlayerController? _controller;

  // 用于存放所有事件监听的订阅，方便统一取消
  final List<StreamSubscription> _subscriptions = [];

  // 页面初始化 PlayerController 后调用
  void setController(PlayerController controller) {
    try {
      // 如果之前有 Controller，先清理旧的监听
      _clearListeners();

      _controller = controller;

      // --- 核心改动：在这里设置事件监听 ---
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

  // 当播放页面销毁时调用
  Future<void> clearController() async {
    await stop();
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
    return _controller?.play(isAudioHandler: false) ?? Future.value();
  }

  @override
  Future<void> pause() {
    Log.addLog(LogLevel.info, "AudioService.pause", "${_controller?.playing}");
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
          await _controller!.pause();
        }

        playbackState.add(
          PlaybackState(
            playing: false,
            processingState: AudioProcessingState.idle,
          ),
        );
        mediaItem.add(null);
      });

      Log.addLog(LogLevel.info, "stop", "updated: ${playbackState.value}");
    } catch (e) {
      Log.addLog(LogLevel.error, "stop", e.toString());
    }
  }

  @override
  Future<void> seek(Duration position) =>
      _controller?.player.seek(position) ?? Future.value();
}
