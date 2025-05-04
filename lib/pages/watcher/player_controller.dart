import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:window_manager/window_manager.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  @observable
  bool loading = true;

  late final player = Player(
    configuration: PlayerConfiguration(
      bufferSize: 1500 * 1024 * 1024,
      osc: false,
      logLevel: MPVLogLevel.info,
    ),
  );
  late final playerController = VideoController(
    player,
    configuration: VideoControllerConfiguration(
      enableHardwareAcceleration: hAenable,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
    ),
  );

  var focusNode = FocusNode();
  @observable
  bool isFullScreen = false;

  // String currentEpisode; // 当前集

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

  bool hAenable = true;

  String currentSetName = '';

  late WindowFrameController windowFrame;

  bool _isInit = false;

  _PlayerController();

  void playNextEpisode(BuildContext context) {
    // 播放下一集的逻辑
    WatcherState.currentState!.playNextEpisode(); // 这里传递当前集数
  }

  void playEpisode(int index, int road) {
    // 播放指定集数的逻辑
    WatcherState.currentState!.loadInfo(index, road); // 加载信息
  }

  // 更新当前集数的方法
  void updateCurrentSetName(int newEpisode) {
    // currentEpisodeNotifier.value = newEpisode;
    currentSetName = WatcherState.currentState!.widget.anime.episode!.values
        .elementAt(currentRoad)
        .values
        .elementAt(newEpisode - 1);
  }

  Future<void> changePlayerSettings() async {
    var pp = player.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (App.isAndroid) {
      await pp.setProperty("volume-max", "100");
      await pp.setProperty("ao", "opensles");
    }

    await player.setAudioTrack(
      AudioTrack.auto(),
    );

    player.setPlaylistMode(PlaylistMode.none);
  }

  // pc
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

    if (isFullScreen) {
      fullscreen();
    } else {
      fullscreen();
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
    // currentEpisodeNotifier.dispose();
    player.dispose(); // 释放播放器资源
    focusNode.dispose(); // 释放焦点节点
  }

  void fullscreen() async {
    if (!App.isDesktop) return;
    // await windowManager.hide();
    await windowManager.setFullScreen(!isFullScreen);
    await windowManager.show();
    isFullScreen = !isFullScreen;
    WindowFrame.of(App.rootContext).setWindowFrame(!isFullScreen);
  }

  void initReaderWindow() {
    if (!App.isDesktop || _isInit) return;
    windowFrame = WindowFrame.of(App.rootContext);
    windowFrame.addCloseListener(onWindowClose);
    _isInit = true;
  }

  bool onWindowClose() {
    if (Navigator.of(App.rootContext).canPop()) {
      Navigator.of(App.rootContext).pop();
      return false;
    } else {
      return true;
    }
  }

  void disposeReaderWindow() {
    if (!App.isDesktop) return;
    windowFrame.removeCloseListener(onWindowClose);
  }

  // 移动
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
