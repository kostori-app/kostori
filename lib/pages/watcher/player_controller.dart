// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/anime_source/anime_play_result.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/audio_service/audio_service_manager.dart';
import 'package:kostori/foundation/audio_service/player_audio_handler.dart';
import 'package:kostori/foundation/audio_service/smtc_manager_windows.dart';
import 'package:kostori/foundation/audio_service/taskbar_manager.dart';
import 'package:kostori/foundation/device_info.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/proxy.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/watcher/editor/video_clip_editor.dart';
import 'package:kostori/pages/watcher/player_cache.dart';
import 'package:kostori/pages/watcher/player_shaders.dart';
import 'package:kostori/pages/watcher/player_video_config.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/pages/watcher/player_subtitle.dart';
import 'package:kostori/shaders/shaders_controller.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

/// 音频输出设备：`name` 为 mpv 设备标识（设置用），`description` 为友好名称（展示用）。
class AudioDeviceInfo {
  final String name;
  final String description;

  const AudioDeviceInfo(this.name, this.description);

  String get label => description.isNotEmpty ? description : name;
}

@immutable
class PlayerState {
  final int revision;

  const PlayerState({this.revision = 0});

  PlayerState next() => PlayerState(revision: revision + 1);
}

/// Anime 播放器的 Riverpod Notifier。
///
/// 播放器实例和媒体流由控制器持有，Riverpod 状态仅保存用于界面重建的
/// 版本号。界面通过 [PlayerControllerBuilder] 订阅 provider，统一接收状态变化。
class PlayerController extends Notifier<PlayerState> {
  PlayerController(this.scopeKey);

  final String scopeKey;

  @override
  PlayerState build() {
    ref.onDispose(() => unawaited(dispose()));
    return const PlayerState();
  }

  void _notifyStateChanged() {
    if (_disposed) return;
    state = state.next();
  }

  late ShadersController shadersController;
  late final PlayerAudioHandler audioHandler;
  late final Stream<String> timeStream;

  final FocusNode keyboardFocus = FocusNode();

  /// 设备设置异步加载完成后会重新创建视频输出控制器。渲染视频的组件必须
  /// 随之重建，否则播放器可能继续输出音频，而 [Video] 仍绑定旧的视频输出。
  final ValueNotifier<int> videoControllerRevision = ValueNotifier<int>(0);
  bool _disposed = false;

  StreamSubscription<PiPStatus>? _pipStatusSubscription;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;

  DateTime currentTime = DateTime.now();

  GlobalKey<OverlayState>? overlayKey;

  String? videoRenderer;
  bool hAenable = true;
  late String videoSync;
  late String hardwareDecoder;

  bool _loading = true;

  bool get loading => _loading;
  set loading(bool value) {
    if (_loading == value) return;
    _loading = value;
    _notifyStateChanged();
  }

  bool _isPortraitFullscreen = false;

  bool get isPortraitFullscreen => _isPortraitFullscreen;
  set isPortraitFullscreen(bool value) {
    if (_isPortraitFullscreen == value) return;
    _isPortraitFullscreen = value;
    _notifyStateChanged();
  }

  /// 加载流程步骤：0 解析地址 → 1 初始化播放器 → 2 加载媒体 → 3 缓冲
  int _loadingStep = 0;

  int get loadingStep => _loadingStep;
  set loadingStep(int value) {
    if (_loadingStep == value) return;
    _loadingStep = value;
    _notifyStateChanged();
  }

  /// 是否正在解析视频地址（解析结束/失败后为 false，用于覆盖层不误导）
  bool _isParsing = false;

  bool get isParsing => _isParsing;
  set isParsing(bool value) {
    if (_isParsing == value) return;
    _isParsing = value;
    _notifyStateChanged();
  }

  late Player player = Player(
    configuration: PlayerConfiguration(
      bufferSize: playerBufferSize,
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
      hwdec: hAenable
          ? resolveAndroidHardwareDecoder(
              hardwareDecoder,
              videoRenderer: videoRenderer,
            )
          : 'no',
      androidAttachSurfaceAfterVideoParameters: false,
    ),
  );

  bool _audioOutType = true;

  bool get audioOutType => _audioOutType;
  set audioOutType(bool value) {
    if (_audioOutType == value) return;
    _audioOutType = value;
    _notifyStateChanged();
  }

  bool _isPiPMode = false;

  bool get isPiPMode => _isPiPMode;
  set isPiPMode(bool value) {
    if (_isPiPMode == value) return;
    _isPiPMode = value;
    _notifyStateChanged();
  }

  bool _isFullScreen = false;

  bool get isFullScreen => _isFullScreen;
  set isFullScreen(bool value) {
    if (_isFullScreen == value) return;
    _isFullScreen = value;
    _notifyStateChanged();
  }

  /// 移动端全屏切换期间，避免重复响应系统返回键/按钮事件。
  bool _mobileFullscreenTransitioning = false;
  bool _isSeek = false;

  bool get isSeek => _isSeek;
  set isSeek(bool value) {
    if (_isSeek == value) return;
    _isSeek = value;
    _notifyStateChanged();
  }

  bool _glimmerEffect = false;

  bool get glimmerEffect => _glimmerEffect;
  set glimmerEffect(bool value) {
    if (_glimmerEffect == value) return;
    _glimmerEffect = value;
    _notifyStateChanged();
  }

  /// 视频超分
  /// 1. OFF
  /// 2. Anime4K
  int _superResolutionType = 1;

  int get superResolutionType => _superResolutionType;
  set superResolutionType(int value) {
    if (_superResolutionType == value) return;
    _superResolutionType = value;
    _notifyStateChanged();
  }

  bool _showPreviewImage = false;

  bool get showPreviewImage => _showPreviewImage;
  set showPreviewImage(bool value) {
    if (_showPreviewImage == value) return;
    _showPreviewImage = value;
    _notifyStateChanged();
  }

  bool _playing = false;

  bool get playing => _playing;
  set playing(bool value) {
    if (_playing == value) return;
    _playing = value;
    _notifyStateChanged();
  }

  Duration _currentPosition = Duration.zero;

  Duration get currentPosition => _currentPosition;
  set currentPosition(Duration value) {
    if (_currentPosition == value) return;
    _currentPosition = value;
    _notifyStateChanged();
  }

  bool _isBuffering = false;

  bool get isBuffering => _isBuffering;
  set isBuffering(bool value) {
    if (_isBuffering == value) return;
    _isBuffering = value;
    _notifyStateChanged();
  }

  bool _completed = false;

  bool get completed => _completed;
  set completed(bool value) {
    if (_completed == value) return;
    _completed = value;
    _notifyStateChanged();
  }

  /// 最近一次打开媒体是否失败：覆盖层据此隐藏加载提示
  bool _loadFailed = false;

  bool get loadFailed => _loadFailed;
  set loadFailed(bool value) {
    if (_loadFailed == value) return;
    _loadFailed = value;
    _notifyStateChanged();
  }

  /// 最近一次播放错误（详情页展示）
  String? _lastPlayError;

  String? get lastPlayError => _lastPlayError;
  set lastPlayError(String? value) {
    if (_lastPlayError == value) return;
    _lastPlayError = value;
    _notifyStateChanged();
  }

  /// 播放器中央提示（如「正在播放下一集」）：在播放器组件内部居中显示，
  /// 位置与缓冲覆盖层一致（不再用全局 showCenter，避免居中到整个页面）。
  String? _centerHintMessage;

  String? get centerHintMessage => _centerHintMessage;
  set centerHintMessage(String? value) {
    if (_centerHintMessage == value) return;
    _centerHintMessage = value;
    _notifyStateChanged();
  }

  bool _centerHintSuccess = true;

  bool get centerHintSuccess => _centerHintSuccess;
  set centerHintSuccess(bool value) {
    if (_centerHintSuccess == value) return;
    _centerHintSuccess = value;
    _notifyStateChanged();
  }

  Timer? _centerHintTimer;

  /// 是否正在加载「自动连播的下一集」：加载覆盖层据此把主文案显示为
  /// 「正在加载下一集」，加载结束后必须复位为 false，
  /// 否则后续普通缓冲会一直误显示「正在加载下一集」。
  bool _loadingNextEpisode = false;

  bool get loadingNextEpisode => _loadingNextEpisode;
  set loadingNextEpisode(bool value) {
    if (_loadingNextEpisode == value) return;
    _loadingNextEpisode = value;
    _notifyStateChanged();
  }

  /// 截图进行中的状态文案：在播放器内底部以 showMessage 样式显示，
  /// 替代原先的整屏加载弹窗（避免遮挡画面、尺寸过大）。
  String? _screenshotStatusMessage;

  String? get screenshotStatusMessage => _screenshotStatusMessage;
  set screenshotStatusMessage(String? value) {
    if (_screenshotStatusMessage == value) return;
    _screenshotStatusMessage = value;
    _notifyStateChanged();
  }

  /// 截图状态结果：null=进行中，true=成功，false=失败（决定底部提示的图标/颜色）
  bool? _screenshotStatusOk;

  bool? get screenshotStatusOk => _screenshotStatusOk;
  set screenshotStatusOk(bool? value) {
    if (_screenshotStatusOk == value) return;
    _screenshotStatusOk = value;
    _notifyStateChanged();
  }

  Timer? _screenshotStatusTimer;
  bool _screenshotBusy = false;

  /// 在播放器内底部显示一条截图状态，[autoClear] 到期后自动清除。
  void _setScreenshotStatus(String message, {bool? ok, Duration? autoClear}) {
    _screenshotStatusTimer?.cancel();
    _screenshotStatusTimer = null;
    screenshotStatusMessage = message;
    screenshotStatusOk = ok;
    if (autoClear != null) {
      _screenshotStatusTimer = Timer(autoClear, () {
        screenshotStatusMessage = null;
        screenshotStatusOk = null;
        _screenshotStatusTimer = null;
      });
    }
  }

  void showCenterHint({
    required String message,
    bool success = true,
    int seconds = 1,
  }) {
    centerHintMessage = message;
    centerHintSuccess = success;
    _centerHintTimer?.cancel();
    _centerHintTimer = Timer(Duration(seconds: seconds), () {
      centerHintMessage = null;
    });
  }

  /// 播放失败提示去抖：mpv 对失效链接会反复重试刷错误日志，短时间只弹一次
  DateTime? _lastFailToastAt;
  void toastPlayFailed(String msg) {
    lastPlayError = msg;
    final now = DateTime.now();
    if (_lastFailToastAt != null &&
        now.difference(_lastFailToastAt!).inMilliseconds < 2000) {
      return;
    }
    _lastFailToastAt = now;
    App.rootContext.showMessage(message: msg, level: LogLevel.error);
  }

  Duration _buffer = Duration.zero;

  Duration get buffer => _buffer;
  set buffer(Duration value) {
    if (_buffer == value) return;
    _buffer = value;
    _notifyStateChanged();
  }

  Duration _duration = Duration.zero;

  Duration get duration => _duration;
  set duration(Duration value) {
    if (_duration == value) return;
    _duration = value;
    _notifyStateChanged();
  }

  Uint8List? _previewImage;

  Uint8List? get previewImage => _previewImage;
  set previewImage(Uint8List? value) {
    if (_previewImage == value) return;
    _previewImage = value;
    _notifyStateChanged();
  }

  Duration? _lastPreviewTime;

  Duration? get lastPreviewTime => _lastPreviewTime;
  set lastPreviewTime(Duration? value) {
    if (_lastPreviewTime == value) return;
    _lastPreviewTime = value;
    _notifyStateChanged();
  }

  int _currentEpisoded = 1;

  int get currentEpisoded => _currentEpisoded;
  set currentEpisoded(int value) {
    if (_currentEpisoded == value) return;
    _currentEpisoded = value;
    _notifyStateChanged();
  }

  int _currentRoad = 0;

  int get currentRoad => _currentRoad;
  set currentRoad(int value) {
    if (_currentRoad == value) return;
    _currentRoad = value;
    _notifyStateChanged();
  }

  // 视频地址
  String _videoUrl = '';

  String get videoUrl => _videoUrl;
  set videoUrl(String value) {
    if (_videoUrl == value) return;
    _videoUrl = value;
    _notifyStateChanged();
  }

  String _playUrl = '';

  String get playUrl => _playUrl;
  set playUrl(String value) {
    if (_playUrl == value) return;
    _playUrl = value;
    _notifyStateChanged();
  }

  Map<String, String>? videoHeaders; // HTTP headers for video

  /// 投屏模式：投屏期间加载剧集只解析地址、不自动本地播放（由 TV 播放）
  bool castMode = false;

  /// 当前播放的结构化结果（音轨/字幕/清晰度等媒体信息，由源脚本提供）
  AnimePlayResult? _playResult;

  AnimePlayResult? get playResult => _playResult;
  set playResult(AnimePlayResult? value) {
    if (_playResult == value) return;
    _playResult = value;
    _notifyStateChanged();
  }

  String _saveAddress = '';

  String get saveAddress => _saveAddress;
  set saveAddress(String value) {
    if (_saveAddress == value) return;
    _saveAddress = value;
    _notifyStateChanged();
  }

  bool _showTabBody = false;

  bool get showTabBody => _showTabBody;
  set showTabBody(bool value) {
    if (_showTabBody == value) return;
    _showTabBody = value;
    _notifyStateChanged();
  }

  // 视频音量/亮度
  double _volume = -1;

  double get volume => _volume;
  set volume(double value) {
    if (_volume == value) return;
    _volume = value;
    _notifyStateChanged();
  }

  double _brightness = 0;

  double get brightness => _brightness;
  set brightness(double value) {
    if (_brightness == value) return;
    _brightness = value;
    _notifyStateChanged();
  }

  /// 音量增益开关（桌面端）：开启后音量上限提升至 200%，实现增益
  bool _volumeBoost = false;

  bool get volumeBoost => _volumeBoost;
  set volumeBoost(bool value) {
    if (_volumeBoost == value) return;
    _volumeBoost = value;
    _notifyStateChanged();
  }

  // 播放器倍速
  double _playerSpeed = 1.0;

  double get playerSpeed => _playerSpeed;
  set playerSpeed(double value) {
    if (_playerSpeed == value) return;
    _playerSpeed = value;
    _notifyStateChanged();
  }

  double _playbackSpeed = 1;

  double get playbackSpeed => _playbackSpeed;
  set playbackSpeed(double value) {
    if (_playbackSpeed == value) return;
    _playbackSpeed = value;
    _notifyStateChanged();
  }

  /// 一起看成员锁定：禁止手动拖动进度 / 调整倍速 / 长按快进，只能跟随房主
  bool _syncLocked = false;

  bool get syncLocked => _syncLocked;
  set syncLocked(bool value) {
    if (_syncLocked == value) return;
    _syncLocked = value;
    _notifyStateChanged();
  }

  /// 一起看房间（含房主）锁定倍速：强制 1 倍速
  bool _speedLocked = false;

  bool get speedLocked => _speedLocked;
  set speedLocked(bool value) {
    if (_speedLocked == value) return;
    _speedLocked = value;
    _notifyStateChanged();
  }

  /// 是否处于一起看房间（用于全屏弹幕设置/聊天按钮的显示）
  bool _inRoom = false;

  bool get inRoom => _inRoom;
  set inRoom(bool value) {
    if (_inRoom == value) return;
    _inRoom = value;
    _notifyStateChanged();
  }

  /// 一起看房间：同步时长者（房主）的播放位置（ms），-1 表示无同步
  int _ownerSyncPositionMs = -1;

  int get ownerSyncPositionMs => _ownerSyncPositionMs;
  set ownerSyncPositionMs(int value) {
    if (_ownerSyncPositionMs == value) return;
    _ownerSyncPositionMs = value;
    _notifyStateChanged();
  }

  /// 同步时长者（房主）是否在播放
  bool _ownerSyncPlaying = true;

  bool get ownerSyncPlaying => _ownerSyncPlaying;
  set ownerSyncPlaying(bool value) {
    if (_ownerSyncPlaying == value) return;
    _ownerSyncPlaying = value;
    _notifyStateChanged();
  }

  /// 同步时长者（房主）广播的 sentAt 时间戳（ms），用于延迟补偿
  int _ownerSyncSentAt = 0;

  int get ownerSyncSentAt => _ownerSyncSentAt;
  set ownerSyncSentAt(int value) {
    if (_ownerSyncSentAt == value) return;
    _ownerSyncSentAt = value;
    _notifyStateChanged();
  }

  /// 点击时长触发的「追上房主」回调（由一起看页面注册，复用完整同步逻辑）
  VoidCallback? onSyncToOwner;

  /// 房主估算的当前播放位置（延迟补偿后，-1 表示无同步）。
  /// 房主在播时，按「距广播的时间」补上进度；限制补偿 0~30s，避免时钟偏差跳变。
  int get ownerSyncCompensatedPositionMs {
    if (ownerSyncPositionMs < 0) return ownerSyncPositionMs;
    if (!ownerSyncPlaying) return ownerSyncPositionMs;
    final elapsed = DateTime.now().millisecondsSinceEpoch - ownerSyncSentAt;
    return ownerSyncPositionMs + elapsed.clamp(0, 30000);
  }

  /// 与同步时长者（房主）的时间差文本，如 "+5s"/"-3s"；无同步时为空
  String get ownerSyncDiffText {
    final target = ownerSyncCompensatedPositionMs;
    if (target < 0) return '';
    final diff = currentPosition.inMilliseconds - target;
    final abs = diff.abs();
    if (abs < 500) return '0s';
    final sign = diff >= 0 ? '+' : '-';
    return '$sign${(abs / 1000).round()}s';
  }

  /// 时间差对应的颜色：<1s 绿（已同步），<5s 橙，其余红（偏离较大）
  Color ownerSyncDiffColor(BuildContext context) {
    final target = ownerSyncCompensatedPositionMs;
    final diff = (currentPosition.inMilliseconds - target).abs();
    if (diff < 1000) return const Color(0xFF4CAF50);
    if (diff < 5000) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  bool _showSeekTime = false;

  bool get showSeekTime => _showSeekTime;
  set showSeekTime(bool value) {
    if (_showSeekTime == value) return;
    _showSeekTime = value;
    _notifyStateChanged();
  }

  bool _showPlaySpeed = false;

  bool get showPlaySpeed => _showPlaySpeed;
  set showPlaySpeed(bool value) {
    if (_showPlaySpeed == value) return;
    _showPlaySpeed = value;
    _notifyStateChanged();
  }

  bool _showBrightness = false;

  bool get showBrightness => _showBrightness;
  set showBrightness(bool value) {
    if (_showBrightness == value) return;
    _showBrightness = value;
    _notifyStateChanged();
  }

  bool _showVolume = false;

  bool get showVolume => _showVolume;
  set showVolume(bool value) {
    if (_showVolume == value) return;
    _showVolume = value;
    _notifyStateChanged();
  }

  bool _showVideoController = true;

  bool get showVideoController => _showVideoController;
  set showVideoController(bool value) {
    if (_showVideoController == value) return;
    _showVideoController = value;
    _notifyStateChanged();
  }

  bool _volumeSeeking = false;

  bool get volumeSeeking => _volumeSeeking;
  set volumeSeeking(bool value) {
    if (_volumeSeeking == value) return;
    _volumeSeeking = value;
    _notifyStateChanged();
  }

  bool _brightnessSeeking = false;

  bool get brightnessSeeking => _brightnessSeeking;
  set brightnessSeeking(bool value) {
    if (_brightnessSeeking == value) return;
    _brightnessSeeking = value;
    _notifyStateChanged();
  }

  bool _canHidePlayerPanel = true;

  bool get canHidePlayerPanel => _canHidePlayerPanel;
  set canHidePlayerPanel(bool value) {
    if (_canHidePlayerPanel == value) return;
    _canHidePlayerPanel = value;
    _notifyStateChanged();
  }

  bool _chatOverlayOpen = false;

  bool get chatOverlayOpen => _chatOverlayOpen;
  set chatOverlayOpen(bool value) {
    if (_chatOverlayOpen == value) return;
    _chatOverlayOpen = value;
    _notifyStateChanged();
  }

  String _animeImg = '';

  String get animeImg => _animeImg;
  set animeImg(String value) {
    if (_animeImg == value) return;
    _animeImg = value;
    _notifyStateChanged();
  }

  /// 当前观看番剧标题（初始化时从 watcher 缓存，供无 context 处使用）
  String animeTitle = '';

  /// 当前观看番剧的源 key / id
  String? animeSourceKey;

  String? animeAnimeId;

  /// 上传者
  String? animeUploader;
  String _currentSetName = '';

  String get currentSetName => _currentSetName;
  set currentSetName(String value) {
    if (_currentSetName == value) return;
    _currentSetName = value;
    _notifyStateChanged();
  }

  /// media_kit 解析出的内封轨道（含文件里 mux 的轨道；已过滤 auto/no）
  List<SubtitleTrack> _embeddedSubtitleTracks = const [];

  List<SubtitleTrack> get embeddedSubtitleTracks => _embeddedSubtitleTracks;
  set embeddedSubtitleTracks(List<SubtitleTrack> value) {
    if (_embeddedSubtitleTracks == value) return;
    _embeddedSubtitleTracks = value;
    _notifyStateChanged();
  }

  List<AudioTrack> _embeddedAudioTracks = const [];

  List<AudioTrack> get embeddedAudioTracks => _embeddedAudioTracks;
  set embeddedAudioTracks(List<AudioTrack> value) {
    if (_embeddedAudioTracks == value) return;
    _embeddedAudioTracks = value;
    _notifyStateChanged();
  }

  String? _currentSubtitleTrackId;

  String? get currentSubtitleTrackId => _currentSubtitleTrackId;
  set currentSubtitleTrackId(String? value) {
    if (_currentSubtitleTrackId == value) return;
    _currentSubtitleTrackId = value;
    _notifyStateChanged();
  }

  String? _currentAudioTrackId;

  String? get currentAudioTrackId => _currentAudioTrackId;
  set currentAudioTrackId(String? value) {
    if (_currentAudioTrackId == value) return;
    _currentAudioTrackId = value;
    _notifyStateChanged();
  }

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
    // media_kit 内封字幕/音轨 + 当前选中项
    _tracksSub = player.stream.tracks.listen((tracks) {
      embeddedSubtitleTracks = tracks.subtitle
          .where((e) => e.id != 'auto' && e.id != 'no')
          .toList();
      embeddedAudioTracks = tracks.audio
          .where((e) => e.id != 'auto' && e.id != 'no')
          .toList();
    });
    _trackSub = player.stream.track.listen((track) {
      currentSubtitleTrackId = track.subtitle.id;
      currentAudioTrackId = track.audio.id;
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
    _tracksSub?.cancel();
    _trackSub?.cancel();
    _centerHintTimer?.cancel();
    playerTimer?.cancel();
  }

  /// 本 controller 所属的 Watcher。多个详情页入栈时，`WatcherPlayer.currentState`
  /// 会指向最近挂载/返回的那个；选集/换集必须作用在自己所属的 Watcher 上，
  /// 否则会播放成另一个 anime page 的内容。
  WatcherPlayer? watcher;

  WatcherPlayer? get _ownerWatcher => watcher ?? WatcherPlayer.currentState;

  bool get hasNextEpisode => _ownerWatcher?.hasNextEpisode ?? false;

  Future<void> playNextEpisode() async {
    await _ownerWatcher?.playNextEpisode();
  }

  Future<void> playEpisode(int index, int road) async {
    await _ownerWatcher?.loadInfo(index, road);
  }

  /// 忽略种子绑定，强制用在线源播放某集（播放中从种子切回原源）
  Future<void> playEpisodeFromSource(int index, int road) async {
    await _ownerWatcher?.loadInfoFromSource(index, road);
  }

  /// 当前是否正在播放种子（loopback）媒体
  ///
  /// 不能只看「是不是回环地址」：m3u8 广告过滤代理同样是
  /// `http://127.0.0.1:<port>/playlist.m3u8`，那样开启广告过滤的
  /// HLS 剧集会被误判成 BT 播放、错误地显示「切回线上源」。
  bool get isTorrentPlayback {
    if (!playUrl.startsWith('http://127.0.0.1:')) return false;
    final path = Uri.tryParse(playUrl)?.path ?? '';
    return !path.endsWith('.m3u8');
  }

  /// 在当前播放器里播放已下载的本地文件（保持选集/进度逻辑，离线可播）
  Future<void> playLocalFile(
    String path, {
    required int index,
    required int road,
  }) async {
    await _ownerWatcher?.loadLocalFile(path, episodeIndex: index, road: road);
  }

  /// 重载当前集视频链接（重新解析地址）
  Future<void> reloadCurrent() async {
    await _ownerWatcher?.reloadCurrent();
  }

  // 更新当前集数的方法
  void updateCurrentSetName(int newEpisode) {
    final watcher = WatcherPlayer.currentState;
    // 播放器已退出（currentState 被 dispose 置空）时跳过
    if (watcher == null) return;
    final anime = watcher.anime;
    if (anime.episode == null || anime.episode!.isEmpty) {
      // 系列模式：无 episode 结构，当前集名 = 系列条目标题
      final entry = watcher.seriesAt(newEpisode - 1);
      currentSetName = entry?.title ?? '';
      videoUrl = entry?.id ?? '';
      return;
    }
    // 线路/集数可能因源数据刷新而越界，越界时清空而非抛 RangeError
    final roads = anime.episode!;
    final index = newEpisode - 1;
    if (currentRoad < 0 || currentRoad >= roads.length) {
      currentSetName = '';
      videoUrl = '';
      return;
    }
    final episodes = roads.values.elementAt(currentRoad);
    if (index < 0 || index >= episodes.length) {
      currentSetName = '';
      videoUrl = '';
      return;
    }
    currentSetName = AnimeDetails.episodeTitleOf(
      episodes.values.elementAt(index),
    );
    videoUrl = episodes.keys.elementAt(index);
  }

  /// 设置音频输出类型（true = Android 低延迟 opensles，false = audiotrack）
  Future<void> setAudioOutType(bool value) async {
    audioOutType = value;
    final pp = player.platform as NativePlayer;
    await pp.setProperty("ao", value ? "opensles" : "audiotrack");
    appdata.settings['audioOutType'] = value;
    appdata.saveData();
  }

  Future<void> changeAudioOutType() async {
    await setAudioOutType(!audioOutType);
  }

  /// 读取 libmpv 可用的音频输出设备列表（桌面端）。
  /// 返回 [AudioDeviceInfo]：`name` 为 mpv 设备标识（传给 [setAudioDevice]），
  /// `description` 为友好名称（展示用）。
  Future<List<AudioDeviceInfo>> getAudioDevices() async {
    try {
      final pp = player.platform as NativePlayer;
      final raw = await pp.getProperty("audio-device-list");
      final decoded = jsonDecode(raw.toString());
      if (decoded is List) {
        final devices = <AudioDeviceInfo>[];
        for (final e in decoded) {
          if (e is Map && e['name'] != null) {
            devices.add(
              AudioDeviceInfo(
                e['name'] as String,
                (e['description'] as String?) ?? '',
              ),
            );
          }
        }
        return devices;
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
    // 记住选择（implicitData：SettingsData 无该字段，写 settings 会被 freezed 丢弃）
    appdata.implicitData['audioDevice'] = deviceName;
    appdata.writeImplicitData();
  }

  /// 当前已选音频设备（空 = 自动）
  String get currentAudioDevice =>
      (appdata.implicitData['audioDevice'] as String?) ?? '';

  /// 音量增益开关切换
  Future<void> toggleVolumeBoost() async {
    volumeBoost = !volumeBoost;
    appdata.implicitData['volumeBoost'] = volumeBoost;
    appdata.writeImplicitData();
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
    if (_disposed) return;
    shadersController = ShadersController();
    shadersController.copyShadersToExternalDirectory();
    audioOutType = appdata.settings.s.audioOutType;
    hAenable = appdata.settings.s.haEnable;
    hardwareDecoder = appdata.settings.s.hardwareDecoder;
    videoSync = appdata.settings.s.videoSynchronizationMode;
    volumeBoost = appdata.implicitData['volumeBoost'] ?? false;
    // 恢复上次的音量（仅桌面端；-1 表示未设置，稍后默认 100）
    volume = (appdata.implicitData['volume'] as num?)?.toDouble() ?? -1;

    if (App.isAndroid) {
      final info = await DeviceInfo.getDeviceInfo();
      if (_disposed) return;

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

    if (_disposed) return;

    playerController = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        vo: videoRenderer,
        enableHardwareAcceleration: hAenable,
        hwdec: hAenable
            ? resolveAndroidHardwareDecoder(
                hardwareDecoder,
                videoRenderer: videoRenderer,
              )
            : 'no',
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    videoControllerRevision.value++;
    await applyAndroidHwdecCodecs(player);

    // 记录播放器内部日志
    playerLog.clear();
    await playerLogSubscription?.cancel();
    playerLogSubscription = player.stream.log.listen((event) {
      playerLog.add(PlayerLogEntry(event));
      if (event.level == 'error' && event.text.contains('Failed to open')) {
        lastPlayError = event.text;
        toastPlayFailed(t.failedToOpen);
        // open 对部分失败不抛异常，而是异步走 log 流；
        // 这里复位加载状态并标记失败，避免覆盖层一直显示"加载媒体数据"
        loadingStep = 0;
        isParsing = false;
        isBuffering = false;
        loadFailed = true;
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
    startPlayerStreams();

    animeImg = WatcherPlayer.currentState!.anime.cover;
    animeTitle = WatcherPlayer.currentState!.anime.title;
    animeSourceKey = WatcherPlayer.currentState!.anime.sourceKey;
    animeAnimeId = WatcherPlayer.currentState!.anime.animeId;
    animeUploader = WatcherPlayer.currentState!.anime.uploader;

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
      audioHandler.setController(this);
    }

    if (App.isWindows) {
      SMTCManagerWindows.instance.setController(this);
      TaskbarManager.instance.setController(this);
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
    superResolutionType = await applySuperResolutionShader(
      player,
      shadersController,
      type,
    );
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
    if (_disposed) return;
    _disposed = true;
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
    _persistVolumeTimer?.cancel();
    _persistVolumeTimer = null;
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
    if (App.isWindows) {
      SMTCManagerWindows.instance.hideSmtcButKeepSession();
      TaskbarManager.instance.dispose();
    }
    _pipStatusSubscription?.cancel();
    _pipStatusSubscription = null;
    videoControllerRevision.dispose();
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

  Future<void> _applyMobileFullscreenSystemUi({
    required bool fullscreen,
    required bool portrait,
  }) {
    return Future.wait<void>([
      (fullscreen
              ? SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.immersiveSticky,
                )
              : SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge))
          .catchError((_) {}),
      SystemChrome.setPreferredOrientations(
        fullscreen
            ? (portrait
                  ? const [DeviceOrientation.portraitUp]
                  : [
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ])
            : const [],
      ).catchError((_) {}),
      (fullscreen ? WakelockPlus.enable() : WakelockPlus.disable()).catchError(
        (_) {},
      ),
    ]);
  }

  /// 平台方向 API 返回后，MediaQuery 还需要至少一帧才会更新。
  /// 等待两帧可避免在退出全屏时先绘制一次错误的宽屏布局。
  Future<void> _waitForMobileLayoutSettle() async {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
  }

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
            () => FullscreenVideoPage(playerController: this),
          );
        });
      }
      // fullscreen() 统一处理窗口全屏切换 + isFullScreen 状态 + 窗口框架
      fullscreen();
      return;
    }

    // --- 移动端逻辑 ---
    if (isFullScreen) {
      if (_mobileFullscreenTransitioning) return;
      _mobileFullscreenTransitioning = true;
      try {
        // 先恢复系统方向并等待 MediaQuery 完成重排，再关闭全屏路由。
        // 路由仍在栈顶时，方向切换过程不会暴露详情页的中间布局。
        await _applyMobileFullscreenSystemUi(
          fullscreen: false,
          portrait: false,
        );
        await _waitForMobileLayoutSettle();
        if (isFullScreen) App.pop();
      } finally {
        _mobileFullscreenTransitioning = false;
      }
    } else {
      if (_mobileFullscreenTransitioning) return;
      _mobileFullscreenTransitioning = true;
      App.setMobileFullscreenTransitioning(true);
      isFullScreen = true;
      isPortraitFullscreen = isPortraitFullScreen;
      unawaited(() async {
        try {
          // 先完成方向切换，确保缩放过渡开始时播放器已经是稳定的
          // 全屏尺寸，不会把方向动画误认为路由动画。
          await _applyMobileFullscreenSystemUi(
            fullscreen: true,
            portrait: isPortraitFullScreen,
          );
          await _waitForMobileLayoutSettle();
          if (!isFullScreen) return;
          // push 只在全屏路由关闭后才完成。进入路由后必须立即释放
          // transition lock，否则退出按钮和系统返回会被误判为重复进入。
          final fullscreenRoute = App.rootContext.toFullscreen(
            () => FullscreenVideoPage(playerController: this),
          );
          App.setMobileFullscreenTransitioning(false);
          _mobileFullscreenTransitioning = false;
          await fullscreenRoute;

          // 路由也可能由系统返回手势或外部导航关闭，统一在这里收尾。
          if (isFullScreen) {
            await _applyMobileFullscreenSystemUi(
              fullscreen: false,
              portrait: false,
            );
            await _waitForMobileLayoutSettle();
            isFullScreen = false;
            isPortraitFullscreen = false;
          }
        } finally {
          App.setMobileFullscreenTransitioning(false);
          _mobileFullscreenTransitioning = false;
        }
      }());
    }
  }

  Future<void> setVolume(double value) async {
    value = value.clamp(0.0, volumeUpperBound);
    volume = value;
    _scheduleVolumePersist();
    try {
      if (App.isDesktop) {
        await player.setVolume(value);
      } else {
        FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(value / 100);
      }
    } catch (_) {}
  }

  Timer? _persistVolumeTimer;

  /// 音量变更后延迟落盘，避免滑条拖动时频繁写盘
  void _scheduleVolumePersist() {
    if (!App.isDesktop) return;
    _persistVolumeTimer?.cancel();
    _persistVolumeTimer = Timer(const Duration(milliseconds: 500), () {
      appdata.implicitData['volume'] = volume;
      appdata.writeImplicitData();
    });
  }

  Future<void> playOrPause() async {
    if (player.state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// 切换音轨（mpv aid，索引从 1 开始；源 MediaStream 通常从 0 起）
  Future<void> setAudioTrack(int index) async {
    try {
      final pp = player.platform as NativePlayer;
      await pp.waitForPlayerInitialization;
      await pp.command(['aid', '${index + 1}']);
    } catch (_) {}
  }

  /// 切换字幕（mpv sid；index < 0 关闭字幕）
  Future<void> setSubtitleTrack(int index) async {
    try {
      final pp = player.platform as NativePlayer;
      await pp.waitForPlayerInitialization;
      await pp.command(['sid', index >= 0 ? '${index + 1}' : 'no']);
    } catch (_) {}
  }

  /// 切换 media_kit 内封字幕轨道（关闭用 [SubtitleTrack.no]）
  Future<void> setEmbeddedSubtitleTrack(SubtitleTrack track) async {
    try {
      await player.setSubtitleTrack(track);
    } catch (_) {}
  }

  /// 切换 media_kit 内封音轨
  Future<void> setEmbeddedAudioTrack(AudioTrack track) async {
    try {
      await player.setAudioTrack(track);
    } catch (_) {}
  }

  /// 切换清晰度（源提供对应清晰度的播放地址时）
  Future<void> switchQuality(String url) async {
    if (url.isEmpty) return;
    try {
      final pos = currentPosition;
      await player.open(
        Media(url, httpHeaders: videoHeaders ?? {}),
        play: true,
      );
      if (pos > Duration.zero) {
        await player.seek(pos);
      }
    } catch (_) {}
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
        audioHandler.setController(this);
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

    final screenSize = MediaQuery.sizeOf(context);
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
                      // 已暂停时不再调用 pause，避免重复弹出播放/暂停覆盖层
                      if (playing) await pause(showIndicator: false);
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
                    if (playing) await pause(showIndicator: false);
                    context.to(() => ImageManipulationPage());
                  },
                  child: Center(
                    child: SizedBox(height: 20, child: Text(t.edit)),
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
      () => FullscreenVideoPage(playerController: this),
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
    // 截图进行中直接忽略，避免重复触发
    if (_screenshotBusy) return;
    _screenshotBusy = true;
    saveAddress = '';
    String? savedPath;
    String? savedFilename;
    _setScreenshotStatus(t.screenshotInProgress);

    try {
      final Uint8List? screenData = await playerController.player.screenshot();
      if (screenData == null) {
        Log.error('截图失败', '截图数据为空');
        _setScreenshotStatus(
          t.screenshotFailed,
          ok: false,
          autoClear: const Duration(seconds: 3),
        );
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '${animeTitle}_$timestamp.png';

      _setScreenshotStatus(t.savingImage);
      final file = await ImageSaver.writeFile(
        bytes: screenData,
        filename: filename,
      );
      if (file == null) {
        _setScreenshotStatus(
          t.screenshotFailed,
          ok: false,
          autoClear: const Duration(seconds: 3),
        );
        return;
      }

      savedPath = file.path;
      savedFilename = filename;
      saveAddress = file.path;

      // 先出成功提示与缩略图：媒体库扫描 / 图片列表刷新放后台执行，
      // 不阻塞「正在截图」状态的结束，缩短体感耗时
      _setScreenshotStatus(
        t.screenshotSuccess,
        ok: true,
        autoClear: const Duration(milliseconds: 1500),
      );
      if (context.mounted) {
        showScreenshotPopup(context, savedPath, savedFilename);
        Log.info('保存文件成功', savedPath);
      }
      unawaited(_postProcessScreenshot(file.parent.path));
    } catch (e) {
      _setScreenshotStatus(
        t.screenshotFailed,
        ok: false,
        autoClear: const Duration(seconds: 3),
      );
      Log.error('截图失败', '$e');
    } finally {
      _screenshotBusy = false;
    }
  }

  /// 截图落盘后的后台收尾：通知媒体库扫描 + 刷新「图片操作」页列表。
  /// 不阻塞截图主流程，否则会明显拖慢「正在截图」的结束时间。
  Future<void> _postProcessScreenshot(String folderPath) async {
    try {
      if (App.isAndroid) {
        const platform = MethodChannel('kostori/media');
        await platform.invokeMethod('scanFolder', {'path': folderPath});
      }
      await ImageSaver.refreshImageList();
    } catch (e) {
      Log.error('截图收尾失败', '$e');
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

  /// 下载当前播放的视频到本地（mp4/m3u8 均走 ffmpeg，转封装 mp4）
  Future<void> downloadCurrentVideo() async {
    // 广告过滤时 playUrl 是本地代理地址，不能用来下载；优先用源直链
    final direct =
        videoUrl.startsWith('http://') || videoUrl.startsWith('https://');
    final url = direct ? videoUrl : playUrl;
    if (url.isEmpty || url.startsWith('blob:')) return;
    await DownloadManager.instance.enqueue(
      url: url,
      title: animeTitle.isNotEmpty ? animeTitle : currentSetName,
      subtitle: currentSetName,
      cover: animeImg,
      sourceKey: animeSourceKey,
      animeId: animeAnimeId,
      animeTitle: animeTitle.isNotEmpty ? animeTitle : currentSetName,
      episode: currentSetName,
      author: animeUploader,
      headers: videoHeaders ?? const {},
      // 沿用下载弹窗里选的默认分组（= 下载目录子目录）
      group: appdata.implicitData['downloadDefaultGroup']?.toString() ?? '',
    );
    App.rootContext.showMessage(message: t.downloadQueued);
  }
}

/// Anime 播放器状态提供者。使用 family 为每个详情页分配独立的播放器实例，
/// 页面退出时由详情页 invalidate 对应 scope，触发 Notifier 生命周期释放。
final playerControllerProvider =
    NotifierProvider.family<PlayerController, PlayerState, String>(
      PlayerController.new,
    );

class PlayerControllerBuilder extends ConsumerWidget {
  const PlayerControllerBuilder({
    super.key,
    required this.playerController,
    required this.builder,
  });

  final PlayerController playerController;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerControllerProvider(playerController.scopeKey));
    return builder(context);
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
    return PlayerControllerBuilder(
      playerController: playerController,
      builder: (context) {
        return playerController.isPiPMode
            ? ValueListenableBuilder<int>(
                valueListenable: playerController.videoControllerRevision,
                builder: (context, revision, _) => Video(
                  key: ValueKey(revision),
                  controller: playerController.playerController,
                  controls: null,
                  subtitleViewConfiguration: kPlayerSubtitleViewConfiguration,
                ),
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
                child: BlurEffect(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: Icon(
                      // 与底部播放/暂停按钮一致：播放中显示暂停（可暂停），暂停时显示播放
                      widget.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
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
