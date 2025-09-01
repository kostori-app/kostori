import 'dart:async';

import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import '../log.dart';

class TaskbarManager {
  TaskbarManager._privateConstructor();

  static final TaskbarManager instance = TaskbarManager._privateConstructor();
  PlayerController? _controller;

  // 用于存放所有事件监听的订阅，方便统一取消
  final List<StreamSubscription> _subscriptions = [];

  void setController(PlayerController controller) {
    try {
      _clearListeners();
      _controller = controller;
      final player = controller.player;
      WindowsTaskbar.setThumbnailTooltip('Kostori');
      WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate);
      _subscriptions.add(
        player.stream.playing.listen(
          (playing) => WindowsTaskbar.setThumbnailToolbar([
            !playing
                ? ThumbnailToolbarButton(
                    ThumbnailToolbarAssetIcon(
                      'assets/img/audio_service_play_arrow.ico',
                    ),
                    '播放',
                    () {
                      _controller?.play();
                    },
                  )
                : ThumbnailToolbarButton(
                    ThumbnailToolbarAssetIcon(
                      'assets/img/audio_service_pause.ico',
                    ),
                    '暂停',
                    () {
                      _controller?.pause();
                    },
                  ),
            ThumbnailToolbarButton(
              ThumbnailToolbarAssetIcon(
                'assets/img/audio_service_skip_next.ico',
              ),
              '下一集',
              () {
                _controller?.playNextEpisode();
              },
            ),
          ]),
        ),
      );

      _subscriptions.add(
        player.stream.position.listen((pos) {
          final duration = player.state.duration.inMilliseconds;
          WindowsTaskbar.setProgress(pos.inMilliseconds, duration);
        }),
      );
    } catch (e) {
      Log.addLog(LogLevel.error, 'TaskbarManager setController error', '$e');
    }
  }

  void dispose() async {
    _clearListeners();
    WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
    WindowsTaskbar.resetThumbnailToolbar();
    // WindowsTaskbar.resetFlashTaskbarAppIcon();
    // WindowsTaskbar.resetOverlayIcon();
    WindowsTaskbar.resetWindowTitle();
  }

  /// 清理所有监听
  void _clearListeners() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
