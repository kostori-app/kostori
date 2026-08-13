// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/audio_service/audio_service_manager.dart';
import 'package:kostori/foundation/audio_service/player_audio_handler.dart';
import 'package:kostori/foundation/audio_service/smtc_manager_windows.dart';
import 'package:kostori/foundation/audio_service/taskbar_manager.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/device_info.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/proxy.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/watcher/editor/video_clip_editor.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/shaders/shaders_controller.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:mobx/mobx.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

part 'player_controller.g.dart';

class PlayerController = _PlayerController with _$PlayerController;

abstract class _PlayerController with Store {
  late ShadersController shadersController;
  late final PlayerAudioHandler audioHandler;
  late final Stream<String> timeStream;

  final FocusNode keyboardFocus = FocusNode();

  StreamSubscription<PiPStatus>? _pipStatusSubscription;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;

  DateTime currentTime = DateTime.now();

  GlobalKey<OverlayState>? overlayKey;

  String? videoRenderer;
  bool hAenable = true;
  late String videoSync;
  late String hardwareDecoder;

  @observable
  bool loading = true;
  @observable
  bool isPortraitFullscreen = false;

  late Player player = Player(
    configuration: PlayerConfiguration(
      bufferSize: 1500 * 1024 * 1024,
      logLevel: MPVLogLevel.v,
      protocolWhitelist: const [
        'file',
        'http',
        'https',
        'tcp',
        'tls',
        'crypto',
        'hls',
        'applehttp',
        'udp',
        'rtp',
        'data',
        'httpproxy',
        'content',
        'fd',
      ],
    ),
  );
  late VideoController playerController = VideoController(
    player,
    configuration: VideoControllerConfiguration(
      vo: videoRenderer,
      enableHardwareAcceleration: hAenable,
      hwdec: hAenable ? hardwareDecoder : 'no',
      androidAttachSurfaceAfterVideoParameters: false,
    ),
  );

  @observable
  bool audioOutType = true;

  @observable
  bool isPiPMode = false;

  @observable
  bool isFullScreen = false;
  @observable
  bool isSeek = false;
  @observable
  bool glimmerEffect = false;

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K
  @observable
  int superResolutionType = 1;
  @observable
  bool showPreviewImage = false;
  @observable
  bool playing = false;
  @observable
  Duration currentPosition = Duration.zero;
  @observable
  bool isBuffering = false;
  @observable
  bool completed = false;
  @observable
  Duration buffer = Duration.zero;
  @observable
  Duration duration = Duration.zero;
  @observable
  Uint8List? previewImage;
  @observable
  Duration? lastPreviewTime;
  @observable
  int currentEpisoded = 1;
  @observable
  int currentRoad = 0;

  // 视频地址
  @observable
  String videoUrl = '';
  @observable
  String playUrl = ''; // 实际播放的 URL（可能是代理 URL）
  Map<String, String>? videoHeaders; // HTTP headers for video
  @observable
  String saveAddress = '';
  @observable
  bool showTabBody = false;

  // 视频音量/亮度
  @observable
  double volume = -1;
  @observable
  double brightness = 0;

  /// 音量增益开关（桌面端）：开启后音量上限提升至 200%，实现增益
  @observable
  bool volumeBoost = false;

  // 播放器倍速
  @observable
  double playerSpeed = 1.0;

  @observable
  double playbackSpeed = 1;

  /// 一起看成员锁定：禁止手动拖动进度 / 调整倍速 / 长按快进，只能跟随房主
  @observable
  bool syncLocked = false;

  /// 一起看房间（含房主）锁定倍速：强制 1 倍速
  @observable
  bool speedLocked = false;

  /// 是否处于一起看房间（用于全屏弹幕设置/聊天按钮的显示）
  @observable
  bool inRoom = false;

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
  @observable
  bool chatOverlayOpen = false;
  @observable
  String animeImg = '';
  @observable
  String currentSetName = '';

  late WindowFrameController windowFrame;

  // 播放器实时状态
  bool get playerPlaying => player.state.playing;

  bool get playerBuffering => player.state.buffering;

  bool get playerCompleted => player.state.completed;

  double get playerVolume => player.state.volume;

  Duration get playerPosition => player.state.position;

  Duration get playerBuffer => player.state.buffer;

  Duration get playerDuration => player.state.duration;

  int? get playerWidth => player.state.width;

  int? get playerHeight => player.state.height;

  VideoParams get playerVideoParams => player.state.videoParams;

  AudioParams get playerAudioParams => player.state.audioParams;

  Playlist get playerPlaylist => player.state.playlist;

  AudioTrack get playerAudioTracks => player.state.track.audio;

  VideoTrack get playerVideoTracks => player.state.track.video;

  String get playerAudioBitrate => player.state.audioBitrate.toString();

  /// 播放器内部日志
  List<PlayerLogEntry> playerLog = [];

  /// 播放器日志订阅
  StreamSubscription<PlayerLog>? playerLogSubscription;

  bool _isInit = false;

  _PlayerController();

  Timer? playerTimer;

  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  void startPlayerStreams() {
    // 先清理旧订阅，避免重复监听导致泄漏与重复 setState
    stopPlayerStreams();
    _positionSub = player.stream.position.listen((pos) {
      currentPosition = pos;
    });
    _bufferSub = player.stream.buffer.listen((buf) {
      buffer = buf;
    });
    _durationSub = player.stream.duration.listen((dur) {
      duration = dur;
    });
    _playingSub = player.stream.playing.listen((p) {
      playing = p;
    });
    _bufferingSub = player.stream.buffering.listen((b) {
      isBuffering = b;
    });
    _completedSub = player.stream.completed.listen((c) {
      completed = c;
    });

    // 音量/亮度保持 Timer 但降低频率，且只在非 seeking 时才查询
    playerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!volumeSeeking) {
        if (App.isDesktop) {
          volume = player.state.volume;
        } else {
          FlutterVolumeController.getVolume().then((value) {
            volume = (value ?? 0.0) * 100;
          });
        }
      }
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

  void stopPlayerStreams() {
    _positionSub?.cancel();
    _bufferSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _bufferingSub?.cancel();
    _completedSub?.cancel();
    playerTimer?.cancel();
  }

  Future<void> playNextEpisode() async {
    WatcherState.currentState!.playNextEpisode();
  }

  void playEpisode(int index, int road) {
    WatcherState.currentState!.loadInfo(index, road);
  }

  // 更新当前集数的方法
  void updateCurrentSetName(int newEpisode) {
    currentSetName = WatcherState.currentState!.anime.episode!.values
        .elementAt(currentRoad)
        .values
        .elementAt(newEpisode - 1);
    videoUrl = WatcherState.currentState!.anime.episode!.values
        .elementAt(currentRoad)
        .keys
        .elementAt(newEpisode - 1);
  }

  Future<void> changeAudioOutType() async {
    audioOutType = !audioOutType;
    var pp = player.platform as NativePlayer;
    if (audioOutType) {
      await pp.setProperty("ao", "opensles");
    } else {
      await pp.setProperty("ao", "audiotrack");
    }
    appdata.settings['audioOutType'] = audioOutType;
    appdata.saveData();
  }

  /// 读取 libmpv 可用的音频输出设备列表（桌面端）。
  /// 返回的设备名可直接传给 [setAudioDevice]。
  Future<List<String>> getAudioDevices() async {
    try {
      final pp = player.platform as NativePlayer;
      final raw = await pp.getProperty("audio-device-list");
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        final names = <String>[];
        for (final e in decoded) {
          if (e is Map && e['name'] != null) {
            names.add(e['name'] as String);
          }
        }
        return names;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 设置音频输出设备（桌面端）。传空字符串恢复自动选择。
  Future<void> setAudioDevice(String deviceName) async {
    final pp = player.platform as NativePlayer;
    if (deviceName.isEmpty) {
      await pp.setProperty('audio-device', 'auto');
    } else {
      await pp.setProperty('audio-device', deviceName);
    }
    // 记住选择
    appdata.settings['audioDevice'] = deviceName;
    appdata.saveData();
  }

  /// 当前已选音频设备（空 = 自动）
  String get currentAudioDevice =>
      (appdata.settings['audioDevice'] as String?) ?? '';

  /// 音量增益开关切换
  Future<void> toggleVolumeBoost() async {
    volumeBoost = !volumeBoost;
    appdata.settings['volumeBoost'] = volumeBoost;
    appdata.saveData();
    // 增益关闭时若当前音量超 100，钳回 100
    if (!volumeBoost && volume > 100) {
      await setVolume(100);
    }
  }

  /// 当前音量上限（桌面端开启增益后为 200）
  double get volumeUpperBound => volumeBoost ? 200.0 : 100.0;

  String formatNow() {
    final now = DateTime.now();
    currentTime = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> changePlayerSettings() async {
    shadersController = ShadersController();
    shadersController.copyShadersToExternalDirectory();
    audioOutType = appdata.settings.s.audioOutType;
    hAenable = appdata.settings.s.haEnable;
    hardwareDecoder = appdata.settings.s.hardwareDecoder;
    videoSync = appdata.settings.s.videoSynchronizationMode;
    volumeBoost = appdata.settings['volumeBoost'] ?? false;

    if (App.isAndroid) {
      final info = await DeviceInfo.getDeviceInfo();

      final String androidVideoRenderer =
          appdata.settings['androidVideoRenderer'] ?? 'auto';

      if (androidVideoRenderer == 'auto') {
        // Android 14 及以上使用基于 Vulkan 的 MPV GPU-NEXT 视频输出，着色器性能更好
        // GPU-NEXT 需要 Vulkan 1.2 支持
        // 避免 Android 14 及以下设备上部分机型 Vulkan 支持不佳导致的黑屏问题
        final int androidSdkVersion =
            (info as AndroidDeviceInfo).version.sdkInt;
        if (androidSdkVersion >= 34) {
          videoRenderer = 'gpu-next';
        } else {
          videoRenderer = 'gpu';
        }
      } else {
        videoRenderer = androidVideoRenderer;
      }
    }

    if (videoRenderer == 'mediacodec_embed') {
      hAenable = true;
      hardwareDecoder = 'mediacodec';
      superResolutionType = 1;
    }

    playerController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: videoRenderer,
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable ? hardwareDecoder : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );

    // 记录播放器内部日志
    playerLog.clear();
    await playerLogSubscription?.cancel();
    playerLogSubscription = player.stream.log.listen((event) {
      playerLog.add(PlayerLogEntry(event));
      if (event.level == 'error' && event.text.contains('Failed to open')) {
        App.rootContext.showMessage(message: 'Failed to open');
      }
    });

    var pp = player.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    await pp.setProperty('tls-verify', 'no');
    await pp.setProperty('insecure', 'yes');
    await pp.setProperty("video-sync", videoSync);

    if (App.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (audioOutType) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
    }

    if (appdata.settings['proxy'] != 'direct' &&
        appdata.settings['proxy'] != null) {
      final proxyAddr = await getProxy();
      if (proxyAddr != null) {
        final proxyUrl = proxyAddr.startsWith('http://')
            ? proxyAddr
            : 'http://$proxyAddr';
        await pp.setProperty('http-proxy', proxyUrl);
        PlayLog.info('Player: HTTP 代理设置', proxyUrl);
      }
    }

    glimmerEffect = appdata.implicitData['glimmerEffect'] ?? false;
    await player.setAudioTrack(AudioTrack.auto());

    player.setPlaylistMode(PlaylistMode.none);
    // playerTimer = getPlayerTimer();
    startPlayerStreams();

    animeImg = WatcherState.currentState!.anime.cover;

    timeStream = Stream.periodic(
      const Duration(seconds: 1),
      (_) => formatNow(),
    ).asBroadcastStream();

    if (App.isAndroid) {
      Timer? debounceTimer;
      _pipStatusSubscription = Floating().pipStatusStream.distinct().listen((
        status,
      ) {
        debounceTimer?.cancel();
        debounceTimer = Timer(const Duration(milliseconds: 100), () {
          if (status == PiPStatus.enabled && !isPiPMode) {
            enterPiPMode();
          } else if (status != PiPStatus.enabled && isPiPMode) {
            App.rootContext.pop();
            isPiPMode = false;
          }
        });
      });
    }

    if (App.isAndroid) {
      audioHandler = AudioServiceManager().handler;
      audioHandler.setController(this as PlayerController);
    }

    if (App.isDesktop) {
      SMTCManagerWindows.instance.setController(this as PlayerController);
      TaskbarManager.instance.setController(this as PlayerController);
    }
    if (superResolutionType != 1) {
      await setShader(superResolutionType);
    }
    if (App.isDesktop) {
      volume = volume != -1 ? volume : 100;
      await setVolume(volume);
    } else {
      // mobile is using system volume, don't setVolume here,
      // or iOS will mute if system volume is too low (#732)
      await FlutterVolumeController.getVolume().then((value) {
        volume = (value ?? 0.0) * 100;
      });
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
          shadersController.shadersDirectory.path,
          mpvAnime4KShadersLite,
        ),
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
          shadersController.shadersDirectory.path,
          mpvAnime4KShaders,
        ),
      ]);
      superResolutionType = 3;
      return;
    }
    await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
    superResolutionType = 1;
  }

  void setPlaybackSpeed(double rate) {
    playbackSpeed = speedLocked ? 1 : rate;
    player.setRate(playbackSpeed);
  }

  void longPressFastForwardStart() {
    if (speedLocked) return;
    player.setRate(playbackSpeed * 2);
  }

  void longPressFastForwardEnd() {
    player.setRate(playbackSpeed);
  }

  Future<void> dispose() async {
    // 先取消所有流订阅与定时器，避免播放器销毁后继续回调/泄漏
    stopPlayerStreams();
    _positionSub = null;
    _bufferSub = null;
    _durationSub = null;
    _playingSub = null;
    _bufferingSub = null;
    _completedSub = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayTimer?.cancel();
    _overlayTimer = null;
    try {
      await playerLogSubscription?.cancel();
    } catch (_) {}
    playerLogSubscription = null;
    if (App.isAndroid) {
      try {
        audioHandler.clearController();
      } catch (e) {
        PlayLog.error("clearController", e.toString());
      }
    }
    if (App.isDesktop) {
      SMTCManagerWindows.instance.hideSmtcButKeepSession();
      TaskbarManager.instance.dispose();
    }
    _pipStatusSubscription?.cancel();
    _pipStatusSubscription = null;
    await player.dispose();
  }

  void fullscreen() async {
    if (!App.isDesktop) return;
    await windowManager.setFullScreen(!isFullScreen);
    isFullScreen = !isFullScreen;
    WindowFrame.of(App.rootContext).setWindowFrame(!isFullScreen);
  }

  void initWindow() {
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

  void disposeWindow() {
    if (!App.isDesktop) return;
    windowFrame.removeCloseListener(onWindowClose);
  }

  @action
  Future<void> toggleFullScreen(
    BuildContext context, {
    bool isPortraitFullScreen = false,
  }) async {
    if (App.isDesktop) {
      // --- PC 端逻辑 ---
      if (isFullScreen) {
        // 退出全屏
        App.pop();
      } else {
        // 进入全屏
        Future.microtask(() {
          App.rootContext.toFadeScale(
            () =>
                FullscreenVideoPage(playerController: this as PlayerController),
          );
        });
      }
      // fullscreen() 统一处理窗口全屏切换 + isFullScreen 状态 + 窗口框架
      fullscreen();
      return;
    }

    // --- 移动端逻辑 ---
    if (isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      App.pop();
      // 恢复全部方向，避免残留"仅竖屏"导致 MIUI 禁用分屏/自由窗口
      SystemChrome.setPreferredOrientations([]);
      isPortraitFullscreen = false;
      WakelockPlus.disable();
    } else {
      WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: SystemUiOverlay.values,
      );
      if (isPortraitFullScreen) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      App.rootContext.toFadeScale(
        () => FullscreenVideoPage(playerController: this as PlayerController),
      );
    }

    // 移动端全屏状态翻转
    isFullScreen = !isFullScreen;
    if (isPortraitFullScreen) {
      isPortraitFullscreen = !isPortraitFullscreen;
    }
  }

  @action
  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, volumeUpperBound);
    volume = value;
    try {
      if (App.isDesktop) {
        await player.setVolume(value);
      } else {
        FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(value / 100);
      }
    } catch (_) {}
  }

  Future<void> playOrPause() async {
    if (player.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  // 播放/暂停渐隐覆盖层（中上方、半透明磨砂、停留约 0.6s）
  Timer? _playPauseIndicatorTimer;
  OverlayEntry? _playPauseIndicatorEntry;

  void _showPlayPauseIndicator(bool isPlaying) {
    final overlayState = overlayKey?.currentState;
    if (overlayState == null) return;
    // 刷新停留：每次播放/暂停都重建覆盖层并重置渐隐计时
    _playPauseIndicatorTimer?.cancel();
    _playPauseIndicatorTimer = null;
    _playPauseIndicatorEntry?.remove();
    _playPauseIndicatorEntry = null;
    final entry = OverlayEntry(
      builder: (context) => _PlayPauseIndicator(
        isPlaying: isPlaying,
        onFadeOutComplete: () {
          _playPauseIndicatorEntry?.remove();
          _playPauseIndicatorEntry = null;
        },
      ),
    );
    _playPauseIndicatorEntry = entry;
    overlayState.insert(entry);
  }

  Future<void> seek(Duration duration) async {
    // 一起看成员：禁止手动拖动进度，只能跟随房主同步
    if (syncLocked) return;
    await player.seek(duration);
  }

  Future<void> pause({bool showIndicator = true}) async {
    await player.pause();
    playing = false;
    if (showIndicator) _showPlayPauseIndicator(false);
  }

  Future<void> play({
    bool isAudioHandler = true,
    bool showIndicator = true,
  }) async {
    if (isAudioHandler) {
      if (App.isAndroid) {
        final audioHandler = AudioServiceManager().handler;
        audioHandler.setController(this as PlayerController);
      }
    }
    await player.play();
    playing = true;
    if (showIndicator) _showPlayPauseIndicator(true);
  }

  void showScreenshotPopup(BuildContext context, String image, String name) {
    final overlayState = overlayKey?.currentState ?? Overlay.of(context);
    _overlayTimer?.cancel();
    _overlayTimer = null;

    _overlayEntry?.remove();
    _overlayEntry = null;

    final screenSize = MediaQuery.of(context).size;
    double overlayWidth = screenSize.width * 0.2;
    overlayWidth = overlayWidth.clamp(180.0, 240.0);
    final overlayHeight = overlayWidth * 9 / 16;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        right: 60,
        top: isPortraitFullscreen ? null : 60,
        bottom: isPortraitFullscreen ? 160 : null,
        child: Material(
          elevation: 8,
          color: Colors.black.toOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: overlayWidth,
            height: overlayHeight,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      await pause();
                      Log.info('image图片路径', image);
                      final file = File(image);
                      final data = await file.readAsBytes();
                      await Share.shareFile(
                        data: data,
                        filename: name,
                        mime: 'image/png',
                      );
                    },
                    onLongPress: () async {},
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(File(image), fit: BoxFit.cover),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Text(
                            t.tapToShare,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    await pause();
                    context.to(() => ImageManipulationPage());
                  },
                  child: Center(
                    child: SizedBox(height: 20, child: Text(t.editing)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _overlayEntry = entry;
    overlayState.insert(_overlayEntry!);

    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (_overlayEntry?.mounted ?? false) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
      _overlayTimer = null;
    });
  }

  Future<void> enterPiPMode() async {
    App.rootContext.toFadeScale(
      () => FullscreenVideoPage(playerController: this as PlayerController),
    );
    await Floating().enable(ImmediatePiP(aspectRatio: Rational(16, 9)));
    isPiPMode = true;
    await play();
  }

  Future<void> exitPiPMode() async {
    await Floating().cancelOnLeavePiP();
    isPiPMode = false;
  }

  Future<void> captureAndSaveScreenshot({required BuildContext context}) async {
    saveAddress = '';
    App.rootContext.showMessage(message: t.screenshotInProgress);

    try {
      final Uint8List? screenData = await playerController.player.screenshot();
      if (screenData == null) {
        Log.error('截图失败', '截图数据为空');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final title = WatcherState.currentState!.anime.title;
      final filename = '${title}_$timestamp.png';

      final file = await ImageSaver.writeFile(
        bytes: screenData,
        filename: filename,
      );

      if (file == null) return;

      saveAddress = file.path;
      showScreenshotPopup(context, saveAddress, filename);
      ImageSaver.showResult(success: true, message: t.screenshotSuccess);
      Log.info('保存文件成功', file.path);

      if (App.isAndroid) {
        const platform = MethodChannel('kostori/media');
        await platform.invokeMethod('scanFolder', {'path': file.parent.path});
      }
    } catch (e) {
      ImageSaver.showResult(success: false, message: t.screenshotFailed);
      Log.error('截图失败', '$e');
    }
  }

  Future<void> openVideoClipEditor({required BuildContext context}) async {
    await pause();

    if (!context.mounted) return;

    showVideoClipEditor(
      context: context,
      videoUrl: playUrl.isNotEmpty ? playUrl : videoUrl,
      httpHeaders: videoHeaders,
      currentPosition: currentPosition,
      duration: duration,
    );
  }
}

class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  PlayerController get playerController => widget.playerController;

  @override
  void dispose() {
    if (playerController.isFullScreen) {
      playerController.fullscreen();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return playerController.isPiPMode
            ? Video(
                controller: playerController.playerController,
                controls: null,
              )
            : VideoPage(playerController: playerController);
      },
    );
  }
}

/// 播放/暂停渐隐覆盖层：屏幕中上方，半透明磨砂，停留约 0.6s 后渐隐消失
class _PlayPauseIndicator extends StatefulWidget {
  const _PlayPauseIndicator({
    required this.isPlaying,
    required this.onFadeOutComplete,
  });

  final bool isPlaying;
  final VoidCallback onFadeOutComplete;

  @override
  State<_PlayPauseIndicator> createState() => _PlayPauseIndicatorState();
}

class _PlayPauseIndicatorState extends State<_PlayPauseIndicator> {
  double _opacity = 1;
  Timer? _timer;

  static const _hold = Duration(milliseconds: 600);
  static const _fade = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    // 停留约 0.6s 后开始渐隐，渐隐完成移除覆盖层
    _timer = Timer(_hold, () {
      if (!mounted) return;
      setState(() => _opacity = 0);
      Future.delayed(_fade, () {
        if (mounted) widget.onFadeOutComplete();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: const Alignment(0, -0.35),
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: _fade,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              clipBehavior: Clip.antiAlias,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.isPlaying
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
