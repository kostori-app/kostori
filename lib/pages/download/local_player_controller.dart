import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/window_frame.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/pages/watcher/player_cache.dart';
import 'package:kostori/pages/watcher/player_shaders.dart';
import 'package:kostori/pages/watcher/player_video_config.dart';
import 'package:kostori/shaders/shaders_controller.dart';
import 'package:kostori/utils/io.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

const String kLocalPlayerPosKeyPrefix = 'localPlayerPos:';

/// 生成稳定的播放进度存储 key。
///
/// 种子串流走本地回环端口，而端口每次会话都是随机的（`TorrentStreamServer`
/// 用端口 0 绑定），直接用完整 URL 当 key 会导致两件事：
/// 1. 进度永远存不上 —— 「自动跳转上次位置」对 BT 播放完全失效；
/// 2. 每 10 秒往 implicitData 多写一条随机端口记录，配置文件无限膨胀。
///
/// 因此把回环地址的端口抹掉，让同一个文件始终命中同一条记录。
/// 非回环地址（含普通本地路径）原样保留。
String localPlayerPosKey(String path) {
  final normalized = path.replaceFirstMapped(
    RegExp(r'^(https?)://(?:127\.0\.0\.1|localhost)(?::\d+)?(/.*)?$'),
    (m) => '${m.group(1)}://kostori-loopback${m.group(2) ?? ''}',
  );
  return '$kLocalPlayerPosKeyPrefix$normalized';
}

/// 本地播放器状态
class LocalPlayerState {
  final bool loading;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final bool showControls;
  final double speed;
  final bool fullscreen;
  final String error;

  /// 左右滑动 seek 预览（非空时显示）
  final Duration? seekPreview;
  final bool showSeekTime;
  final bool showVolume;
  final bool showBrightness;
  final double volume;
  final double brightness;

  /// 可选字幕/音轨（来自 media_kit，含 auto/no 占位项）
  final List<SubtitleTrack> subtitleTracks;
  final List<AudioTrack> audioTracks;

  /// 当前选中的字幕/音轨 id（media_kit `Track.id`）
  final String? subtitleTrackId;
  final String? audioTrackId;

  /// 超分辨率挡位：1 关 / 2 效率 / 3 质量
  final int superResolutionType;

  const LocalPlayerState({
    this.loading = true,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.showControls = true,
    this.speed = 1.0,
    this.fullscreen = false,
    this.error = '',
    this.seekPreview,
    this.showSeekTime = false,
    this.showVolume = false,
    this.showBrightness = false,
    this.volume = 1.0,
    this.brightness = 1.0,
    this.subtitleTracks = const [],
    this.audioTracks = const [],
    this.subtitleTrackId,
    this.audioTrackId,
    this.superResolutionType = 1,
  });

  LocalPlayerState copyWith({
    bool? loading,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    Duration? buffer,
    bool? showControls,
    double? speed,
    bool? fullscreen,
    String? error,
    Duration? seekPreview,
    bool clearSeekPreview = false,
    bool? showSeekTime,
    bool? showVolume,
    bool? showBrightness,
    double? volume,
    double? brightness,
    List<SubtitleTrack>? subtitleTracks,
    List<AudioTrack>? audioTracks,
    String? subtitleTrackId,
    String? audioTrackId,
    int? superResolutionType,
  }) {
    return LocalPlayerState(
      loading: loading ?? this.loading,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      buffer: buffer ?? this.buffer,
      showControls: showControls ?? this.showControls,
      speed: speed ?? this.speed,
      fullscreen: fullscreen ?? this.fullscreen,
      error: error ?? this.error,
      seekPreview: clearSeekPreview ? null : seekPreview ?? this.seekPreview,
      showSeekTime: showSeekTime ?? this.showSeekTime,
      showVolume: showVolume ?? this.showVolume,
      showBrightness: showBrightness ?? this.showBrightness,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      audioTracks: audioTracks ?? this.audioTracks,
      subtitleTrackId: subtitleTrackId ?? this.subtitleTrackId,
      audioTrackId: audioTrackId ?? this.audioTrackId,
      superResolutionType: superResolutionType ?? this.superResolutionType,
    );
  }

  /// 值相等。
  ///
  /// 没有它时 `state == next` 走的是引用比较、永远为 false，
  /// 播放器每个 position / buffer 事件都会触发一次 Riverpod 状态写入，
  /// 造成整页重建。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalPlayerState &&
        loading == other.loading &&
        playing == other.playing &&
        buffering == other.buffering &&
        position == other.position &&
        duration == other.duration &&
        buffer == other.buffer &&
        showControls == other.showControls &&
        speed == other.speed &&
        fullscreen == other.fullscreen &&
        error == other.error &&
        seekPreview == other.seekPreview &&
        showSeekTime == other.showSeekTime &&
        showVolume == other.showVolume &&
        showBrightness == other.showBrightness &&
        volume == other.volume &&
        brightness == other.brightness &&
        subtitleTrackId == other.subtitleTrackId &&
        audioTrackId == other.audioTrackId &&
        superResolutionType == other.superResolutionType &&
        _sameTracks(subtitleTracks, other.subtitleTracks) &&
        _sameTracks(audioTracks, other.audioTracks);
  }

  static bool _sameTracks<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    loading,
    playing,
    buffering,
    position,
    duration,
    buffer,
    showControls,
    speed,
    fullscreen,
    error,
    seekPreview,
    showSeekTime,
    showVolume,
    showBrightness,
    volume,
    brightness,
    subtitleTrackId,
    audioTrackId,
    superResolutionType,
    subtitleTracks.length,
    audioTracks.length,
  ]);
}

/// 本地播放器控制器：Riverpod Notifier 响应式同步 media_kit 播放状态，
/// 对齐 watcher 的 PlayerController 架构（observable → 控件层自动重建）。
class LocalPlayerController extends Notifier<LocalPlayerState> {
  LocalPlayerController(this.filePath);

  final String filePath;

  Player? _player;
  VideoController? _controller;
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _hideTimer;
  Timer? _levelTimer;
  Timer? _posSaveTimer;
  bool _disposed = false;

  /// 播放器（mpv）日志，供「播放器详情」展示
  final List<PlayerLogEntry> playerLog = [];
  static const _maxPlayerLog = 2000;

  Future<void>? _openFuture;
  bool _seekBusy = false;
  Duration? _seekPending;
  bool _userSeeked = false;
  double? _speedHold;

  /// 超分辨率 shader（与 watcher 共用 applySuperResolutionShader）
  ShadersController? _shaders;
  Future<void>? _shadersReady;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _bufSub;

  /// 可被 [startPositionSync] 重建的那三个订阅；重建时先从 [_subs] 里摘掉旧的
  List<StreamSubscription<dynamic>> _restartable = const [];

  Player get player => _player!;
  VideoController get controller => _controller!;

  /// 标题（文件名）
  String get title {
    final name = filePath.split('/').last.split('\\').last;
    return name.isEmpty ? filePath : name;
  }

  @override
  LocalPlayerState build() {
    ref.onDispose(_disposeInternal);
    _init(filePath);
    _resetHideTimer();
    _startLevelSync();
    // 初始即进入可交互状态，open 异步进行（否则加载期间手势/返回全部不可用）
    return const LocalPlayerState(loading: false);
  }

  Future<void> _init(String filePath) async {
    try {
      final p = Player(
        configuration: PlayerConfiguration(
          bufferSize: localPlayerBufferSize,
          logLevel: MPVLogLevel.v,
        ),
      );
      _player = p;
      _controller = VideoController(
        p,
        configuration: playerVideoControllerConfiguration(),
      );
      // 超分辨率 shader 目录准备（异步，不阻塞播放）
      _shaders = ShadersController();
      _shadersReady = _shaders!.copyShadersToExternalDirectory();
      _posSub = p.stream.position.listen((v) {
        if (_disposed) return;
        _update(state.copyWith(position: v));
      });
      _durSub = p.stream.duration.listen((v) {
        if (_disposed) return;
        _update(state.copyWith(duration: v));
      });
      _bufSub = p.stream.buffer.listen((v) {
        if (_disposed) return;
        _update(state.copyWith(buffer: v));
      });
      _subs.add(_posSub!);
      _subs.add(_durSub!);
      _subs.add(_bufSub!);
      // 这三个订阅在 [startPositionSync] 里会被重建并塞进 _subs，
      // 旧的必须一并移除，否则每次滑动 seek 都往 _subs 里追加 3 条
      // 已取消的订阅。
      _restartable = [_posSub!, _durSub!, _bufSub!];
      _subs.add(
        p.stream.playing.listen((v) {
          if (_disposed) return;
          _update(state.copyWith(playing: v));
        }),
      );
      _subs.add(
        p.stream.buffering.listen((v) {
          if (_disposed) return;
          _update(state.copyWith(buffering: v));
        }),
      );
      // 播放错误：详情页的诊断信息要用
      _subs.add(
        p.stream.error.listen((e) {
          if (_disposed) return;
          _update(state.copyWith(error: e));
        }),
      );
      // mpv 日志：收集给「播放器详情」展示，error/fatal 同时落盘
      _subs.add(
        p.stream.log.listen((e) {
          if (_disposed) return;
          // media_kit 初始化期间会尝试设置旧版 mpv 没有的 OSC 属性；
          // 这是无害兼容探测，不应伪装成播放失败或刷屏写入错误日志。
          if (e.text.contains('property not found') &&
              e.text.contains('_setProperty(osc, 1)')) {
            return;
          }
          playerLog.add(PlayerLogEntry(e));
          if (playerLog.length > _maxPlayerLog) playerLog.removeAt(0);
          if (e.level == 'error' || e.level == 'fatal') {
            Log.error('LocalPlayer', e.text);
          }
        }),
      );
      // 可选字幕/音轨（内封轨道也在这里）与当前选中项
      _subs.add(
        p.stream.tracks.listen((t) {
          if (_disposed) return;
          _update(
            state.copyWith(subtitleTracks: t.subtitle, audioTracks: t.audio),
          );
        }),
      );
      _subs.add(
        p.stream.track.listen((t) {
          if (_disposed) return;
          _update(
            state.copyWith(
              subtitleTrackId: t.subtitle.id,
              audioTrackId: t.audio.id,
            ),
          );
        }),
      );
      await applyAndroidHwdecCodecs(p);
      final open = p.open(Media(filePath), play: true);
      _openFuture = open;
      await open;
      await _restorePosition();
      _posSaveTimer?.cancel();
      _posSaveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _savePosition();
      });
    } catch (e) {
      if (_disposed) return;
      _update(state.copyWith(error: e.toString()));
    }
  }

  static const String _posKeyPrefix = kLocalPlayerPosKeyPrefix;

  String get _posKey => localPlayerPosKey(filePath);

  /// 「自动跳转到上次播放位置」开启时，恢复本地文件的上次播放进度
  Future<void> _restorePosition() async {
    if (appdata.implicitData['playerAutoResume'] == false) return;
    final saved = (appdata.implicitData[_posKey] as num?)?.toInt() ?? 0;
    if (saved <= 0) return;
    final p = _player;
    if (p == null) return;
    try {
      // 等拿到真实时长再判断是否接近结尾（避免一进来就播完）
      final duration = await p.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 5));
      if (_disposed || !identical(p, _player) || _userSeeked) return;
      if ((duration - Duration(milliseconds: saved)).abs() <=
          const Duration(seconds: 3)) {
        return;
      }
      await seek(Duration(milliseconds: saved));
    } catch (_) {}
  }

  /// 记录本地文件当前播放进度（关闭「自动跳转上次位置」时仍记录，便于再次开启）
  void _savePosition() {
    final p = _player;
    if (_disposed || p == null) return;
    final pos = p.state.position.inMilliseconds;
    if (pos <= 0) return;
    final key = _posKey;
    // 清掉历史遗留的随机端口记录（旧版本直接用完整 URL 当 key），避免配置无限膨胀
    for (final old in appdata.implicitData.keys.toList()) {
      if (!old.startsWith(_posKeyPrefix) || old == key) continue;
      if (localPlayerPosKey(old.substring(_posKeyPrefix.length)) == key) {
        appdata.implicitData.remove(old);
      }
    }
    appdata.implicitData[key] = pos;
    appdata.writeImplicitData();
  }

  void _update(LocalPlayerState next) {
    if (_disposed) return;
    if (state == next) return;
    state = next;
  }

  void _resetHideTimer() {
    if (_disposed) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_disposed) return;
      if (state.showControls) {
        _update(state.copyWith(showControls: false));
      }
    });
  }

  /// 与 anime page 播放器对齐：state.volume / state.brightness 均为 0..1。
  /// 读取系统真实音量/亮度，避免沿用默认 1.0 导致首次上滑直接显示 100。
  Future<void> _syncSystemLevels() async {
    if (_disposed) return;
    try {
      if (App.isDesktop) {
        final v = player.state.volume / 100;
        if (_disposed) return;
        _update(state.copyWith(volume: v.clamp(0.0, 1.0)));
      } else {
        final v = await FlutterVolumeController.getVolume();
        if (v != null) {
          if (_disposed) return;
          _update(state.copyWith(volume: v.clamp(0.0, 1.0)));
        }
      }
    } catch (_) {}
    if (!App.isDesktop) {
      try {
        final b = await ScreenBrightnessPlatform.instance.application;
        if (_disposed) return;
        _update(state.copyWith(brightness: b.clamp(0.0, 1.0)));
      } catch (_) {}
    }
  }

  /// 周期同步系统音量/亮度（滑动调整期间跳过，避免与手势互相覆盖）
  void _startLevelSync() {
    _levelTimer?.cancel();
    _syncSystemLevels();
    _levelTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_disposed) return;
      if (state.showVolume || state.showBrightness) return;
      _syncSystemLevels();
    });
  }

  void play() {
    final p = _player;
    if (_disposed || p == null) return;
    p.play();
  }

  void pause() {
    final p = _player;
    if (_disposed || p == null) return;
    p.pause();
  }

  void playOrPause() {
    final p = _player;
    if (_disposed || p == null) return;
    if (state.playing) {
      p.pause();
    } else {
      p.play();
    }
  }

  Future<void> seek(Duration target) async {
    final p = _player;
    if (_disposed || p == null) return;
    _userSeeked = true;
    target = _clampSeekTarget(p, target);

    if (_seekBusy) {
      _seekPending = target;
      return;
    }
    _seekBusy = true;
    try {
      final open = _openFuture;
      if (open != null) {
        try {
          await open;
        } catch (_) {}
      }
      Duration? next = target;
      while (next != null) {
        if (_disposed || !identical(p, _player)) break;
        try {
          await p.seek(next);
        } catch (_) {
          break;
        }
        next = _seekPending;
        _seekPending = null;
      }
    } finally {
      _seekBusy = false;
      _seekPending = null;
    }
  }

  Duration _clampSeekTarget(Player p, Duration target) {
    if (target < Duration.zero) return Duration.zero;
    final d = p.state.duration;
    if (d > Duration.zero && target > d) return d;
    return target;
  }

  /// 相对快进/快退（限制在时长范围内）
  void seekBy(Duration delta) {
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) {
      target = state.duration;
    }
    seek(target);
  }

  /// 循环切换倍速
  void cycleSpeed() {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.5];
    final idx = speeds.indexOf(state.speed);
    final next = speeds[(idx + 1) % speeds.length];
    setRate(next);
  }

  void setRate(double rate) {
    final p = _player;
    if (_disposed || p == null) return;
    p.setRate(rate);
    _update(state.copyWith(speed: rate));
  }

  /// 设置超分辨率挡位（1 关 / 2 效率 / 3 质量），与 watcher 播放器一致
  Future<void> setSuperResolution(int type) async {
    final s = _shaders;
    if (s == null) return;
    try {
      await _shadersReady;
      if (_disposed) return;
      final next = await applySuperResolutionShader(player, s, type);
      if (_disposed) return;
      _update(state.copyWith(superResolutionType: next));
    } catch (_) {}
  }

  void toggleControls() {
    _update(state.copyWith(showControls: !state.showControls));
    if (state.showControls) _resetHideTimer();
  }

  /// 直接设置控件显隐（配合动画层使用，不重置隐藏计时）
  void showControlsDirect(bool visible) {
    _update(state.copyWith(showControls: visible));
  }

  // ---- seek 预览 / 音量 / 亮度 HUD（对齐 watcher 手势）----

  void setSeekPreview(Duration? d) => _update(state.copyWith(seekPreview: d));

  void setShowSeekTime(bool v) =>
      _update(state.copyWith(showSeekTime: v, clearSeekPreview: !v));

  Future<void> setVolume(double v) async {
    v = v.clamp(0.0, 1.0);
    try {
      if (App.isDesktop) {
        await player.setVolume(v * 100);
      } else {
        FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(v);
      }
    } catch (_) {}
    if (_disposed) return;
    _update(state.copyWith(volume: v));
  }

  void setShowVolume(bool v) => _update(state.copyWith(showVolume: v));

  Future<void> setBrightness(double b) async {
    b = b.clamp(0.0, 1.0);
    try {
      await ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(b);
    } catch (_) {}
    if (_disposed) return;
    _update(state.copyWith(brightness: b));
  }

  void setShowBrightness(bool v) => _update(state.copyWith(showBrightness: v));

  /// 切换字幕轨道（关闭用 [SubtitleTrack.no]）
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    try {
      await player.setSubtitleTrack(track);
    } catch (_) {}
  }

  /// 切换音轨
  Future<void> setAudioTrack(AudioTrack track) async {
    try {
      await player.setAudioTrack(track);
    } catch (_) {}
  }

  /// 长按倍速（按住 = 当前倍速 ×2，松开恢复原始倍速）
  void startSpeedBoost() {
    final p = _player;
    if (_disposed || p == null) return;
    _speedHold ??= state.speed;
    final next = (_speedHold! * 2).clamp(0.5, 8.0);
    p.setRate(next);
    _update(state.copyWith(speed: next));
  }

  void stopSpeedBoost() {
    final base = _speedHold;
    _speedHold = null;
    final p = _player;
    if (_disposed || p == null || base == null) return;
    p.setRate(base);
    _update(state.copyWith(speed: base));
  }

  /// 全屏（对齐 watcher PlayerController.toggleFullScreen）：
  /// PC 端切系统窗口全屏 + 隐藏自绘窗框；移动端沉浸式 + 横屏 + 全屏路由。
  Future<void> toggleFullscreen() async {
    final next = !state.fullscreen;

    // --- PC 端逻辑 ---
    if (App.isDesktop) {
      if (state.fullscreen) {
        App.rootContext.pop();
      } else {
        Future.microtask(() {
          App.rootContext.toFadeScale(
            () => LocalFullscreenVideoPage(filePath: filePath),
          );
        });
      }
      await windowManager.setFullScreen(next);
      _update(state.copyWith(fullscreen: next));
      WindowFrame.of(App.rootContext).setWindowFrame(!next);
      _resetHideTimer();
      return;
    }

    // --- 移动端逻辑 ---
    _update(state.copyWith(fullscreen: next));
    if (next) {
      WakelockPlus.enable();
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      Future.microtask(() {
        App.rootContext.toFadeScale(
          () => LocalFullscreenVideoPage(filePath: filePath),
        );
      });
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // 恢复全部方向，避免残留"仅横屏"导致 MIUI 禁用分屏/自由窗口
      SystemChrome.setPreferredOrientations([]);
      WakelockPlus.disable();
      App.rootContext.pop();
    }
    _resetHideTimer();
  }

  /// 停止进度同步（左右滑动 seek 时暂停）
  void stopPositionSync() {
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    _posSub = null;
    _durSub = null;
    _bufSub = null;
    // 从 _subs 里摘掉，避免重建时越攒越多（每次滑动 seek 攒 3 条）
    if (_restartable.isNotEmpty) {
      _subs.removeWhere(_restartable.contains);
      _restartable = const [];
    }
  }

  /// 恢复进度同步
  void startPositionSync() {
    final p = _player;
    if (_disposed || p == null) return;
    stopPositionSync();
    _posSub = p.stream.position.listen((v) {
      if (_disposed) return;
      _update(state.copyWith(position: v));
    });
    _durSub = p.stream.duration.listen((v) {
      if (_disposed) return;
      _update(state.copyWith(duration: v));
    });
    _bufSub = p.stream.buffer.listen((v) {
      if (_disposed) return;
      _update(state.copyWith(buffer: v));
    });
    _restartable = [_posSub!, _durSub!, _bufSub!];
    _subs.addAll(_restartable);
  }

  /// 截图保存
  Future<void> captureScreenshot() async {
    App.rootContext.showMessage(message: t.screenshotInProgress);
    try {
      final data = await player.screenshot();
      if (data == null) {
        App.rootContext.showMessage(message: t.screenshotFailed);
        return;
      }
      final dot = title.lastIndexOf('.');
      final base = dot > 0 ? title.substring(0, dot) : title;
      final filename = '${base}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await ImageSaver.writeFile(bytes: data, filename: filename);
      if (file == null) return;
      App.rootContext.showMessage(
        message: '${t.screenshotSuccess}: ${file.path}',
      );
      // 图片列表刷新放后台，不阻塞截图结束
      unawaited(ImageSaver.refreshImageList());
    } catch (_) {
      App.rootContext.showMessage(message: t.screenshotFailed);
    }
  }

  void _disposeInternal() {
    _savePosition();
    _disposed = true;
    _seekPending = null;
    _hideTimer?.cancel();
    _levelTimer?.cancel();
    _posSaveTimer?.cancel();
    // 进度同步订阅会在 seek 后重建，未记录在 _subs 里，单独取消
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    _controller = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    WakelockPlus.disable();
  }
}

/// 本地播放器 provider（页面退出时 autoDispose 销毁 Player）
final localPlayerControllerProvider = NotifierProvider.autoDispose
    .family<LocalPlayerController, LocalPlayerState, String>(
      (filePath) => LocalPlayerController(filePath),
    );
