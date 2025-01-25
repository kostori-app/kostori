import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/state_controller.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:window_manager/window_manager.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  @observable
  bool loading = true;

  late final player = Player();
  late final playerController = VideoController(player);

  late final AnimeDetails anime;

  var focusNode = FocusNode();
  @observable
  bool isFullScreen = false;

  String currentEpisode; // 当前集

  @observable
  bool playing = false;
  @observable
  Duration currentPosition = Duration.zero;
  @observable
  bool isBuffering = true;
  @observable
  bool completed = false;
  @observable
  Duration buffer = Duration.zero;
  @observable
  Duration duration = Duration.zero;

  int currentEpisoded = 1;

  int currentRoad = 0;

  @observable
  bool showTabBody = false;

  // 视频音量/亮度
  @observable
  double volume = 0;
  @observable
  double brightness = 0;

  // 播放器倍速
  @observable
  double playerSpeed = 1.0;

  double playbackSpeed = 1;

  ValueNotifier<String> currentEpisodeNotifier;

  _PlayerController({required this.anime, required this.currentEpisode})
      : currentEpisodeNotifier = ValueNotifier<String>(currentEpisode);

  void playNextEpisode(BuildContext context) {
    // 播放下一集的逻辑
    WatcherState.currentState!.playNextEpisode(); // 这里传递当前集数
  }

  void playEpisode(int index, int road) {
    // 播放指定集数的逻辑
    // logic.order = index + 1; // 更新当前集数
    WatcherState.currentState!.loadInfo(index, road); // 加载信息
  }

  // 更新当前集数的方法
  void updateCurrentEpisode(String newEpisode) {
    currentEpisodeNotifier.value = newEpisode;
    // print(currentEpisode);
  }

  // pc端
  void toggleFullscreen(BuildContext context, {VoidCallback? onExit}) {
    windowManager.setFullScreen(!isFullScreen);
    if (isFullScreen) {
      focusNode.requestFocus();
      context.pop(); // 退出全屏，返回原页面
      onExit?.call(); // 调用退出全屏回调
    } else {
      focusNode.requestFocus();
      // 进入全屏，使用 App.globalTo 跳转到全屏页面
      App.rootContext.to(() => FullscreenVideoPage(
          playerController: this as PlayerController,
          onExit: onExit)); // 传递当前的 PlayerController
    }

    isFullScreen = !isFullScreen;

    if (isFullScreen) {
      StateController.find<WindowFrameController>().hideWindowFrame();
    } else {
      StateController.find<WindowFrameController>().showWindowFrame();
    }
  }

  void setPlaybackSpeed(double rate) {
    playbackSpeed = rate;
    player.setRate(rate);
  }

  void longPressFastForwardStart() {
    player.setRate(playbackSpeed * 2);
  }

  void longPressFastForwardEnd() {
    player.setRate(playbackSpeed);
  }

  void dispose() {
    currentEpisodeNotifier.dispose();
    player.dispose(); // 释放播放器资源
    focusNode.dispose(); // 释放焦点节点
  }

  // 移动端
  Future<void> enterFullScreen(BuildContext context,
      {VoidCallback? onExit}) async {
    if (isFullScreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.of(context).pop(); // 退出全屏，返回原页面
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      onExit?.call(); // 调用退出全屏回调
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
          overlays: SystemUiOverlay.values);
      // 进入全屏，使用 App.globalTo 跳转到全屏页面
      App.rootContext.to(() => FullscreenVideoPage(
          playerController: this as PlayerController,
          onExit: onExit)); // 传递当前的 PlayerController
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    isFullScreen = !isFullScreen;
  }

  Future playOrPause() async {
    if (player.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future seek(Duration duration) async {
    await player.seek(duration);
  }

  Future pause() async {
    await player.pause();
    playing = false;
  }

  Future play() async {
    await player.play();
    playing = true;
  }
}

class FullscreenVideoPage extends StatelessWidget {
  final PlayerController playerController;

  final VoidCallback? onExit;

  const FullscreenVideoPage(
      {required this.playerController, super.key, this.onExit});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, _) async {
        onExit?.call(); // 调用退出全屏回调
      },
      child: Scaffold(
        body: VideoPage(
          playerController: playerController,
        ),
      ),
    );
  }
}
