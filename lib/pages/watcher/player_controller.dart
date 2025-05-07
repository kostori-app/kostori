import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/shaders/shaders_controller.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  late ShadersController shadersController;
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
      enableHardwareAcceleration: true,
      hwdec: 'auto-safe',
      androidAttachSurfaceAfterVideoParameters: false,
    ),
  );

  @observable
  bool isFullScreen = false;

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K
  @observable
  int superResolutionType = 1;

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

  @observable
  bool showSeekTime = false;
  @observable
  bool showPlaySpeed = false;
  @observable
  bool showBrightness = false;
  @observable
  bool showVolume = false;
  @observable
  bool showVideoController = true;
  @observable
  bool volumeSeeking = false;
  @observable
  bool brightnessSeeking = false;
  @observable
  bool canHidePlayerPanel = true;

  String currentSetName = '';

  late WindowFrameController windowFrame;

  bool _isInit = false;

  _PlayerController();

  Timer? playerTimer;

  Timer getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      playing = player.state.playing;
      isBuffering = player.state.buffering;
      currentPosition = player.state.position;
      buffer = player.state.buffer;
      duration = player.state.duration;
      completed = player.state.completed;
      // 音量相关
      if (!volumeSeeking) {
        if (Utils.isDesktop()) {
          volume = player.state.volume;
        } else {
          FlutterVolumeController.getVolume().then((value) {
            final volumes = value ?? 0.0;
            volume = volumes * 100;
          });
        }
      }
      // 亮度相关
      if (!App.isWindows &&
          !App.isMacOS &&
          !App.isLinux &&
          !brightnessSeeking) {
        ScreenBrightnessPlatform.instance.application.then((value) {
          brightness = value;
        });
      }
    });
  }

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
    currentSetName = WatcherState.currentState!.widget.anime.episode!.values
        .elementAt(currentRoad)
        .values
        .elementAt(newEpisode - 1);
  }

  Future<void> changePlayerSettings() async {
    shadersController = ShadersController();
    shadersController.copyShadersToExternalDirectory();
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
    playerTimer = getPlayerTimer();

    if (superResolutionType != 1) {
      await setShader(superResolutionType);
    }
  }

  Future<void> setShader(int type, {bool synchronized = true}) async {
    var pp = player.platform as NativePlayer;
    await pp.waitForPlayerInitialization;
    await pp.waitForVideoControllerInitializationIfAttached;
    if (type == 2) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShadersLite),
      ]);
      superResolutionType = 2;
      return;
    }
    if (type == 3) {
      await pp.command([
        'change-list',
        'glsl-shaders',
        'set',
        Utils.buildShadersAbsolutePath(
            shadersController.shadersDirectory.path, mpvAnime4KShaders),
      ]);
      superResolutionType = 3;
      return;
    }
    await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
    superResolutionType = 1;
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
    player.dispose(); // 释放播放器资源
  }

  void fullscreen() async {
    if (!App.isDesktop) return;
    // await windowManager.hide();
    await windowManager.setFullScreen(!isFullScreen);
    // await windowManager.show();
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
  Future<void> enterFullScreen(BuildContext context) async {
    if (isFullScreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      Navigator.of(context).pop(); // 退出全屏，返回原页面
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
          overlays: SystemUiOverlay.values);
      // 进入全屏，使用 App.globalTo 跳转到全屏页面
      App.rootContext.to(() => FullscreenVideoPage(
          playerController:
              this as PlayerController)); // 传递当前的 PlayerController
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    isFullScreen = !isFullScreen;
  }

  // pc
  void toggleFullscreen(BuildContext context) {
    windowManager.setFullScreen(!isFullScreen);
    if (isFullScreen) {
      App.rootContext.pop(); // 退出全屏，返回原页面
    } else {
      Future.microtask(() {
        App.rootContext.to(() =>
            FullscreenVideoPage(playerController: this as PlayerController));
      });
    }

    fullscreen();
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, 100.0);
    volume = value;
    try {
      if (Utils.isDesktop()) {
        await player.setVolume(value);
      } else {
        await FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(value / 100);
      }
    } catch (_) {}
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

class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: Scaffold(
        body: VideoPage(
          playerController: widget.playerController,
        ),
      ),
    );
  }
}
