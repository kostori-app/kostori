import 'dart:async';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:smtc_windows/smtc_windows.dart';

class SMTCManagerWindows {
  // 单例
  SMTCManagerWindows._privateConstructor();

  static final SMTCManagerWindows instance =
      SMTCManagerWindows._privateConstructor();

  SMTCWindows? _smtc;
  bool _isEnabled = false;

  PlayerController? _controller;

  // 用于存放所有事件监听的订阅，方便统一取消
  final List<StreamSubscription> _subscriptions = [];

  Future<void> init() async {
    try {
      await SMTCWindows.initialize();
      _smtc = SMTCWindows(
        enabled: true,
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: false,
          stopEnabled: false,
          fastForwardEnabled: false,
          rewindEnabled: false,
        ),
      );

      _isEnabled = true;
    } catch (e, st) {
      Log.addLog(LogLevel.error, 'Failed to initialize SMTCWindows', '$e\n$st');
    }
  }

  // 页面初始化 PlayerController 后调用
  void setController(PlayerController controller) {
    try {
      // 如果之前有 Controller，先清理旧的监听
      _clearListeners();
      _ensureEnabled();
      _controller = controller;
      final player = controller.player;

      // 监听播放状态 -> 通知 SMTC 播放状态
      _subscriptions.add(
        player.stream.playing.listen((isPlaying) {
          _ensureEnabled();
          _smtc?.setPlaybackStatus(
            isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
          );
        }),
      );

      // 监听媒体信息 -> 更新 Metadata
      _subscriptions.add(
        player.stream.position.listen((_) {
          final title = _controller!.currentSetName;
          final artUri = _controller!.animeImg;
          updateMetadata(
            MusicMetadata(
              title: WatcherState.currentState!.anime.title,
              artist: title,
              album: '',
              thumbnail: artUri,
            ),
          );
        }),
      );

      // 监听播放进度 -> 更新 Timeline
      _subscriptions.add(
        player.stream.position.listen((pos) {
          final duration = player.state.duration.inMilliseconds;
          updateTimeline(pos.inMilliseconds, duration);
        }),
      );

      _subscriptions.add(
        _smtc?.buttonPressStream.listen((event) {
              switch (event) {
                case PressedButton.play:
                  _controller?.playOrPause();
                  break;
                case PressedButton.pause:
                  _controller?.pause();
                  break;
                case PressedButton.next:
                  _controller?.playNextEpisode();
                  break;
                default:
                  break;
              }
            })
            as StreamSubscription,
      );
    } catch (e) {
      Log.addLog(LogLevel.error, 'SMTC setController error', '$e');
    }
  }

  void hideSmtcButKeepSession() {
    if (_smtc == null) return;
    if (_isEnabled == false) return;
    _isEnabled = false;
    _clearListeners();
    // 设置状态为停止，这样不会显示正在播放的 UI
    _smtc!.setPlaybackStatus(PlaybackStatus.stopped);
    _smtc!.disableSmtc();
  }

  /// 清理所有监听
  void _clearListeners() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _ensureEnabled() {
    if (!_isEnabled && _smtc != null) {
      _smtc!.enableSmtc();
      _isEnabled = true;
    }
  }

  void onPlay() {
    _ensureEnabled();
    _smtc?.setPlaybackStatus(PlaybackStatus.playing);
  }

  void onPause() {
    _ensureEnabled();
    _smtc?.setPlaybackStatus(PlaybackStatus.paused);
  }

  void updateMetadata(MusicMetadata metadata) {
    _ensureEnabled();
    _smtc?.updateMetadata(metadata);
  }

  void updateTimeline(int positionMS, int? durationMS) {
    _ensureEnabled();
    _smtc?.updateTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: durationMS ?? 0,
        positionMs: positionMS,
      ),
    );
  }
}
