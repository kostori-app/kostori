// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';

import 'package:extended_tabs/extended_tabs.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/audio_service/audio_service_manager.dart';
import 'package:kostori/foundation/audio_service/player_audio_handler.dart';
import 'package:kostori/foundation/audio_service/smtc_manager_windows.dart';
import 'package:kostori/foundation/audio_service/taskbar_manager.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/shaders/shaders_controller.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
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

  GlobalKey<OverlayState>? overlayKey;

  @observable
  bool loading = true;
  @observable
  bool isPortraitFullscreen = false;

  late final player = Player(
    configuration: PlayerConfiguration(
      bufferSize: 1500 * 1024 * 1024,
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
  bool audioOutType = true;

  @observable
  bool isPiPMode = false;

  @observable
  bool isFullScreen = false;
  @observable
  bool isSeek = false;

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
  bool isBuffering = true;
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
  bool showTabBody = false;

  // 视频音量/亮度
  @observable
  double volume = -1;
  @observable
  double brightness = 0;

  // 播放器倍速
  @observable
  double playerSpeed = 1.0;

  @observable
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
  List<PlayerLog> playerLog = [];

  /// 播放器日志订阅
  StreamSubscription<PlayerLog>? playerLogSubscription;

  bool _isInit = false;

  _PlayerController();

  Timer? playerTimer;

  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

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
        if (App.isDesktop) {
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
    appdata.writeImplicitData();
  }

  String formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> changePlayerSettings() async {
    shadersController = ShadersController();
    shadersController.copyShadersToExternalDirectory();
    audioOutType = appdata.settings['audioOutType'] ?? true;

    // 记录播放器内部日志
    playerLog.clear();
    await playerLogSubscription?.cancel();
    playerLogSubscription = player.stream.log.listen((event) {
      playerLog.add(event);
    });

    var pp = player.platform as NativePlayer;
    // media-kit 默认启用硬盘作为双重缓存，这可以维持大缓存的前提下减轻内存压力
    // media-kit 内部硬盘缓存目录按照 Linux 配置，这导致该功能在其他平台上被损坏
    // 该设置可以在所有平台上正确启用双重缓存
    await pp.setProperty("demuxer-cache-dir", await Utils.getPlayerTempPath());
    await pp.setProperty("af", "scaletempo2=max-speed=8");
    if (App.isAndroid) {
      await pp.setProperty("volume-max", "100");
      if (audioOutType) {
        await pp.setProperty("ao", "opensles");
      } else {
        await pp.setProperty("ao", "audiotrack");
      }
    }

    await player.setAudioTrack(AudioTrack.auto());

    player.setPlaylistMode(PlaylistMode.none);
    playerTimer = getPlayerTimer();

    animeImg = WatcherState.currentState!.anime.cover;

    timeStream = Stream.periodic(
      const Duration(seconds: 1),
      (_) => formatNow(),
    ).asBroadcastStream();

    if (App.isAndroid) {
      Timer? debounceTimer;
      _pipStatusSubscription = Floating().pipStatusStream
          .distinct() // 避免重复状态
          .listen((status) {
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
    playbackSpeed = rate;
    player.setRate(rate);
  }

  void longPressFastForwardStart() {
    player.setRate(playbackSpeed * 2);
  }

  void longPressFastForwardEnd() {
    player.setRate(playbackSpeed);
  }

  Future<void> dispose() async {
    _overlayEntry?.remove();
    _overlayEntry = null;
    try {
      await playerLogSubscription?.cancel();
    } catch (_) {}
    if (App.isAndroid) {
      try {
        audioHandler.stop();
      } catch (e) {
        Log.addLog(LogLevel.error, "clearController", e.toString());
      }
    }
    if (App.isDesktop) {
      SMTCManagerWindows.instance.hideSmtcButKeepSession();
      TaskbarManager.instance.dispose();
    }
    _pipStatusSubscription?.cancel();
    player.dispose();
  }

  void fullscreen() async {
    if (!App.isDesktop) return;
    // await windowManager.hide();
    await windowManager.setFullScreen(!isFullScreen);
    // await windowManager.show();
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

  Future<void> toggleFullScreen(
    BuildContext context, {
    bool isPortraitFullScreen = false,
  }) async {
    if (App.isDesktop) {
      // --- PC 端逻辑 ---
      await windowManager.setFullScreen(!isFullScreen);

      if (isFullScreen) {
        // 退出全屏
        App.pop();
      } else {
        // 进入全屏
        Future.microtask(() {
          App.rootContext.to(
            () =>
                FullscreenVideoPage(playerController: this as PlayerController),
          );
        });
      }
    } else {
      // --- 移动端逻辑 ---

      if (isFullScreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        App.pop();
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

        App.rootContext.to(
          () => FullscreenVideoPage(playerController: this as PlayerController),
        );
      }
    }

    if (App.isDesktop) {
      fullscreen();
      return;
    }
    isFullScreen = !isFullScreen;
    if (isPortraitFullScreen) {
      isPortraitFullscreen = !isPortraitFullscreen;
    }
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, 100.0);
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

  Future<void> seek(Duration duration) async {
    await player.seek(duration);
  }

  Future<void> pause() async {
    await player.pause();
    playing = false;
  }

  Future<void> play({bool isAudioHandler = true}) async {
    if (isAudioHandler) {
      if (App.isAndroid) {
        final audioHandler = AudioServiceManager().handler;
        audioHandler.setController(this as PlayerController);
      }
    }
    await player.play();
    playing = true;
  }

  void showScreenshotPopup(BuildContext context, String image, String name) {
    final overlayState = overlayKey?.currentState ?? Overlay.of(context);
    _overlayTimer?.cancel();
    _overlayTimer = null;

    _overlayEntry?.remove();
    _overlayEntry = null;

    final screenSize = MediaQuery.of(context).size;
    double overlayWidth = screenSize.width * 0.2;
    overlayWidth = overlayWidth.clamp(120.0, 240.0);
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
                      Log.addLog(LogLevel.info, 'image图片路径', image);
                      final file = File(image);
                      final data = await file.readAsBytes();
                      await Share.shareFile(
                        data: data,
                        filename: name,
                        mime: 'image/png',
                      );
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(File(image), fit: BoxFit.cover),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Text('点击分享', style: TextStyle(fontSize: 12)),
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
                  child: Center(child: SizedBox(height: 20, child: Text('编辑'))),
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
    App.rootContext.to(
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
    var isPaddingCheckError =
        MediaQuery.of(context).viewPadding.top <= 0 ||
        MediaQuery.of(context).viewPadding.top > 50;
    return Hero(
      tag: WatcherState.currentState!.anime.id,
      child: Observer(
        builder: (context) {
          return playerController.isPiPMode
              ? isPaddingCheckError
                    ? MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          viewPadding: const EdgeInsets.only(
                            top: 15,
                            bottom: 15,
                          ),
                          padding: const EdgeInsets.only(top: 15, bottom: 15),
                        ),
                        child: Video(
                          controller: playerController.playerController,
                          controls: null,
                        ),
                      )
                    : Video(
                        controller: playerController.playerController,
                        controls: null,
                      )
              : VideoPage(playerController: playerController);
        },
      ),
    );
  }
}

class ParamCard extends StatelessWidget {
  final String title;
  final Map<String, Object?> params;

  const ParamCard({super.key, required this.title, required this.params});

  @override
  Widget build(BuildContext context) {
    // 拼接所有文本用于长按复制
    final String allText = [
      title,
      ...params.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}'),
    ].join('\n');

    return Material(
      elevation: 2,
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.white.toOpacity(0.72)
          : const Color(0xFF1E1E1E).toOpacity(0.72),
      shadowColor: Theme.of(context).colorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: allText));
          App.rootContext.showMessage(message: '复制成功');
        },
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...params.entries
                  .where((e) => e.value != null)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${e.key}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(text: e.value.toString()),
                          ],
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class MediaInfoWidget extends StatelessWidget {
  final VideoParams? videoParams;
  final AudioParams? audioParams;
  final AudioTrack? audioTrack;
  final VideoTrack? videoTrack;
  final String? audioBitrate;

  const MediaInfoWidget({
    super.key,
    this.videoParams,
    this.audioParams,
    this.audioTrack,
    this.videoTrack,
    this.audioBitrate,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = [];

    // ==== Video Card ====
    if (videoParams != null) {
      final Map<String, Object?> videoMap = {
        'Pixel Format'.tl: videoParams!.pixelformat,
        'HW Pixel Format'.tl: videoParams!.hwPixelformat,
        'Resolution'.tl: '${videoParams!.w}x${videoParams!.h}',
        'Display Width'.tl: videoParams!.dw,
        'Display Height'.tl: videoParams!.dh,
        'Aspect'.tl: videoParams!.aspect,
        'Pixel Aspect Ratio'.tl: videoParams!.par,
        'Colormatrix'.tl: videoParams!.colormatrix,
        'Color Levels'.tl: videoParams!.colorlevels,
        'Primaries'.tl: videoParams!.primaries,
        'Gamma'.tl: videoParams!.gamma,
        'Signal Peak'.tl: videoParams!.sigPeak,
        'Lights'.tl: videoParams!.light,
        'Chroma Location'.tl: videoParams!.chromaLocation,
        'Rotate'.tl: videoParams!.rotate,
        'Stereo In'.tl: videoParams!.stereoIn,
        'Average Bpp'.tl: videoParams!.averageBpp,
        'Alpha'.tl: videoParams!.alpha,
      };

      // 合并 VideoTrack 信息
      if (videoTrack != null) {
        videoMap.addAll({
          'Track ID'.tl: videoTrack!.id,
          'Track Title'.tl: videoTrack!.title,
          'Track Language'.tl: videoTrack!.language,
          'Track Image'.tl: videoTrack!.image,
          'Track Album Art'.tl: videoTrack!.albumart,
          'Track Codec'.tl: videoTrack!.codec,
          'Track Decoder'.tl: videoTrack!.decoder,
          'Track Width'.tl: videoTrack!.w,
          'Track Height'.tl: videoTrack!.h,
          'Track Channels Count'.tl: videoTrack!.channelscount,
          'Track Channels'.tl: videoTrack!.channels,
          'Track Sample Rate'.tl: videoTrack!.samplerate,
          'Track FPS'.tl: videoTrack!.fps,
          'Track Bitrate'.tl: videoTrack!.bitrate,
          'Track Rotate'.tl: videoTrack!.rotate,
          'Track PAR'.tl: videoTrack!.par,
          'Track Audio Channels'.tl: videoTrack!.audiochannels,
        });
      }

      cards.add(ParamCard(title: 'Video'.tl, params: videoMap));
    }

    // ==== Audio Card ====
    if (audioParams != null) {
      final Map<String, Object?> audioMap = {
        'Format'.tl: audioParams!.format,
        'Sample Rate'.tl: audioParams!.sampleRate,
        'Channels'.tl: audioParams!.channels,
        'Channel Count'.tl: audioParams!.channelCount,
        'HR Channels'.tl: audioParams!.hrChannels,
      };

      // 合并 AudioTrack 信息
      if (audioTrack != null) {
        audioMap.addAll({
          'Track ID'.tl: audioTrack!.id,
          'Track Title'.tl: audioTrack!.title,
          'Track Language'.tl: audioTrack!.language,
          'URI Track'.tl: audioTrack!.uri,
          'Track Image'.tl: audioTrack!.image,
          'Track Album Art'.tl: audioTrack!.albumart,
          'Track Codec'.tl: audioTrack!.codec,
          'Track Decoder'.tl: audioTrack!.decoder,
          'Track Width'.tl: audioTrack!.w,
          'Track Height'.tl: audioTrack!.h,
          'Channels Count'.tl: audioTrack!.channelscount,
          'Channels'.tl: audioTrack!.channels,
          'Track Sample Rate'.tl: audioTrack!.samplerate,
          'FPS'.tl: audioTrack!.fps,
          'Bitrate'.tl: audioTrack!.bitrate,
          'Rotate'.tl: audioTrack!.rotate,
          'PAR'.tl: audioTrack!.par,
          'Audio Channels'.tl: audioTrack!.audiochannels,
        });
      }

      if (audioBitrate != null) {
        audioMap.addAll({'AudioBitrate'.tl: audioBitrate});
      }

      cards.add(ParamCard(title: 'Audio'.tl, params: audioMap));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: card,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class MediaWidget extends StatelessWidget {
  final Media media;

  const MediaWidget({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    final String allText = media.uri;

    return Material(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: allText));
          App.rootContext.showMessage(message: '复制成功');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Media'.tl,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(media.uri, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoInfoSheet extends StatefulWidget {
  final PlayerController playerController;

  const VideoInfoSheet({super.key, required this.playerController});

  @override
  _VideoInfoSheetState createState() => _VideoInfoSheetState();
}

class _VideoInfoSheetState extends State<VideoInfoSheet>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabControllerZero;
  late TabController _tabControllerOne;

  @override
  void initState() {
    super.initState();
    _tabControllerZero = TabController(length: 2, vsync: this);
    _tabControllerOne = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SizedBox(
      child: Column(
        children: [
          ExtendedTabBar(
            controller: _tabControllerZero,
            tabs: [
              Tab(text: 'Status'.tl),
              Tab(text: 'Log'.tl),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          Expanded(
            child: ExtendedTabBarView(
              shouldIgnorePointerWhenScrolling: false,
              controller: _tabControllerZero,
              children: [_buildVideoInfoTab(), _buildVideoLogTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfoTab() {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 单独显示 Media
              if (widget.playerController.playerPlaylist.medias.isNotEmpty)
                MediaWidget(
                  media: widget.playerController.playerPlaylist.medias.first,
                ),

              Material(
                child: InkWell(
                  onLongPress: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.playerController.videoUrl),
                    );
                    App.rootContext.showMessage(message: '复制成功');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          'Source'.tl,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'URI: ${widget.playerController.videoUrl}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              MediaInfoWidget(
                videoParams: widget.playerController.playerVideoParams,
                audioParams: widget.playerController.playerAudioParams,
                audioTrack: widget.playerController.playerAudioTracks,
                videoTrack: widget.playerController.playerVideoTracks,
                audioBitrate: widget.playerController.playerAudioBitrate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLogTab() {
    final logs = widget.playerController.playerLog;

    // 按等级分类
    final Map<String, List<PlayerLog>> logsByLevel = {
      'info': [],
      'warn': [],
      'error': [],
    };
    for (var log in logs) {
      if (logsByLevel.containsKey(log.level)) {
        logsByLevel[log.level]!.add(log);
      } else {
        logsByLevel['info']!.add(log);
      }
    }

    return Scaffold(
      appBar: ExtendedTabBar(
        controller: _tabControllerOne,
        tabs: logsByLevel.keys
            .map((level) => Tab(text: level.toUpperCase()))
            .toList(),
      ),
      body: ExtendedTabBarView(
        shouldIgnorePointerWhenScrolling: false,
        controller: _tabControllerOne,
        children: logsByLevel.keys.map((level) {
          final levelLogs = logsByLevel[level]!;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: ListView.separated(
              itemCount: levelLogs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = levelLogs[index];
                return Material(
                  elevation: 2,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.white.toOpacity(0.85)
                      : const Color(0xFF1E1E1E).toOpacity(0.85),
                  shadowColor: Theme.of(context).colorScheme.shadow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 6,
                              ),
                              child: Text(
                                log.prefix,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: log.level == 'error'
                                    ? Theme.of(context).colorScheme.error
                                    : log.level == 'warn'
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.errorContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 6,
                              ),
                              child: Text(
                                log.level,
                                style: TextStyle(
                                  color: log.level == 'error'
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          log.text,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: log.text));
                              App.rootContext.showMessage(message: '复制成功');
                            },
                            child: Text("Copy".tl),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.copy),
        onPressed: () {
          Clipboard.setData(
            ClipboardData(text: widget.playerController.playerLog.join('\n')),
          );
          App.rootContext.showMessage(message: '复制成功');
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
