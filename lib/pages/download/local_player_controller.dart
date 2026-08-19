import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
      seekPreview: clearSeekPreview
          ? null
          : seekPreview ?? this.seekPreview,
      showSeekTime: showSeekTime ?? this.showSeekTime,
      showVolume: showVolume ?? this.showVolume,
      showBrightness: showBrightness ?? this.showBrightness,
      volume: volume ?? this.volume,
      brightness: brightness ?? this.brightness,
    );
  }
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

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<Duration>? _bufSub;

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
    // 初始即进入可交互状态，open 异步进行（否则加载期间手势/返回全部不可用）
    return const LocalPlayerState(loading: false);
  }

  Future<void> _init(String filePath) async {
    try {
      final p = Player();
      _player = p;
      _controller = VideoController(p);
      _posSub = p.stream.position.listen(
        (v) => _update(state.copyWith(position: v)),
      );
      _durSub = p.stream.duration.listen(
        (v) => _update(state.copyWith(duration: v)),
      );
      _bufSub = p.stream.buffer.listen(
        (v) => _update(state.copyWith(buffer: v)),
      );
      _subs.add(_posSub!);
      _subs.add(_durSub!);
      _subs.add(_bufSub!);
      _subs.add(
        p.stream.playing.listen((v) => _update(state.copyWith(playing: v))),
      );
      _subs.add(
        p.stream.buffering.listen((v) => _update(state.copyWith(buffering: v))),
      );
      await p.open(Media(filePath), play: true);
    } catch (e) {
      _update(state.copyWith(error: e.toString()));
    }
  }

  void _update(LocalPlayerState next) {
    if (state == next) return;
    state = next;
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (state.showControls) {
        _update(state.copyWith(showControls: false));
      }
    });
  }

  void play() => player.play();

  void pause() => player.pause();

  void playOrPause() => state.playing ? player.pause() : player.play();

  void seek(Duration target) => player.seek(target);

  /// 相对快进/快退（限制在时长范围内）
  void seekBy(Duration delta) {
    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (state.duration > Duration.zero && target > state.duration) {
      target = state.duration;
    }
    player.seek(target);
  }

  /// 循环切换倍速
  void cycleSpeed() {
    const speeds = [1.0, 1.25, 1.5, 2.0, 0.5];
    final idx = speeds.indexOf(state.speed);
    final next = speeds[(idx + 1) % speeds.length];
    setRate(next);
  }

  void setRate(double rate) {
    player.setRate(rate);
    _update(state.copyWith(speed: rate));
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

  void setSeekPreview(Duration? d) =>
      _update(state.copyWith(seekPreview: d));

  void setShowSeekTime(bool v) =>
      _update(state.copyWith(showSeekTime: v, clearSeekPreview: !v));

  Future<void> setVolume(double v) async {
    v = v.clamp(0.0, 1.0);
    try {
      if (App.isDesktop) {
        await player.setVolume(v);
      } else {
        FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(v);
      }
    } catch (_) {}
    _update(state.copyWith(volume: v));
  }

  void setShowVolume(bool v) =>
      _update(state.copyWith(showVolume: v));

  Future<void> setBrightness(double b) async {
    b = b.clamp(0.0, 1.0);
    try {
      await ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(b);
    } catch (_) {}
    _update(state.copyWith(brightness: b));
  }

  void setShowBrightness(bool v) =>
      _update(state.copyWith(showBrightness: v));

  /// 长按倍速（watcher 交互：按住 2x，松开恢复）
  void startSpeedBoost() {
    final next = state.speed * 2 > 4 ? 4.0 : state.speed * 2;
    player.setRate(next);
    _update(state.copyWith(speed: next));
  }

  void stopSpeedBoost() {
    final next = (state.speed / 2).clamp(0.5, 4.0);
    player.setRate(next);
    _update(state.copyWith(speed: next));
  }

  /// 全屏（参考 watcher PlayerController.toggleFullScreen 移动端逻辑）：
  /// 进入全屏 → 沉浸式 + 横屏 + 打开全屏路由；退出 → 恢复 + pop 全屏路由
  Future<void> toggleFullscreen() async {
    final next = !state.fullscreen;
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

  /// 停止进度同步（左右滑动 seek 时暂停，照搬 watcher stopPlayerStreams）
  void stopPositionSync() {
    _posSub?.cancel();
    _durSub?.cancel();
    _bufSub?.cancel();
  }

  /// 恢复进度同步（照搬 watcher startPlayerStreams）
  void startPositionSync() {
    stopPositionSync();
    _posSub = player.stream.position.listen(
      (v) => _update(state.copyWith(position: v)),
    );
    _durSub = player.stream.duration.listen(
      (v) => _update(state.copyWith(duration: v)),
    );
    _bufSub = player.stream.buffer.listen(
      (v) => _update(state.copyWith(buffer: v)),
    );
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
      final filename =
          '${base}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = await ImageSaver.writeFile(
        bytes: data,
        filename: filename,
      );
      if (file == null) return;
      App.rootContext.showMessage(
        message: '${t.screenshotSuccess}: ${file.path}',
      );
    } catch (_) {
      App.rootContext.showMessage(message: t.screenshotFailed);
    }
  }

  void _disposeInternal() {
    _hideTimer?.cancel();
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
final localPlayerControllerProvider = NotifierProvider.autoDispose.family<
  LocalPlayerController,
  LocalPlayerState,
  String
>((filePath) => LocalPlayerController(filePath));
