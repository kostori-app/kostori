import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/widget_utils.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/proxy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

class HeaderEntry {
  final String key;
  final String value;

  const HeaderEntry(this.key, this.value);

  HeaderEntry copyWith({String? key, String? value}) =>
      HeaderEntry(key ?? this.key, value ?? this.value);
}

class VideoTestState {
  final String url;
  final List<HeaderEntry> headers;
  final bool playing;
  final bool buffering;
  final bool completed;
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final double speed;
  final List<PlayerLogEntry> logs;

  const VideoTestState({
    this.url = '',
    this.headers = const [],
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffer = Duration.zero,
    this.speed = 1.0,
    this.logs = const [],
  });

  VideoTestState copyWith({
    String? url,
    List<HeaderEntry>? headers,
    bool? playing,
    bool? buffering,
    bool? completed,
    Duration? position,
    Duration? duration,
    Duration? buffer,
    double? speed,
    List<PlayerLogEntry>? logs,
  }) => VideoTestState(
    url: url ?? this.url,
    headers: headers ?? this.headers,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    completed: completed ?? this.completed,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffer: buffer ?? this.buffer,
    speed: speed ?? this.speed,
    logs: logs ?? this.logs,
  );
}

class VideoTestNotifier extends StateNotifier<VideoTestState> {
  final Player player = Player(
    configuration: PlayerConfiguration(
      bufferSize: 64 * 1024 * 1024,
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

  late final VideoController videoController;

  final List<StreamSubscription> _subs = [];

  VideoTestNotifier() : super(const VideoTestState()) {
    videoController = VideoController(player);
    _applyProxy();
    _listenStreams();
  }

  void _listenStreams() {
    _subs.addAll([
      player.stream.playing.listen((v) => state = state.copyWith(playing: v)),
      player.stream.buffering.listen(
        (v) => state = state.copyWith(buffering: v),
      ),
      player.stream.completed.listen(
        (v) => state = state.copyWith(completed: v),
      ),
      player.stream.position.listen((v) => state = state.copyWith(position: v)),
      player.stream.duration.listen((v) => state = state.copyWith(duration: v)),
      player.stream.buffer.listen((v) => state = state.copyWith(buffer: v)),
      player.stream.log.listen((event) {
        state = state.copyWith(logs: [...state.logs, PlayerLogEntry(event)]);
      }),
    ]);
  }

  Future<void> load(String url, List<HeaderEntry> headers) async {
    if (url.trim().isEmpty) return;
    final headerMap = {
      for (final h in headers)
        if (h.key.trim().isNotEmpty) h.key.trim(): h.value.trim(),
    };
    state = state.copyWith(
      url: url,
      headers: headers,
      position: Duration.zero,
      duration: Duration.zero,
      completed: false,
    );
    await player.open(
      Media(url, httpHeaders: headerMap.isEmpty ? null : headerMap),
    );
  }

  Future<void> togglePlay() async {
    await player.playOrPause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    await player.setRate(speed);
    state = state.copyWith(speed: speed);
  }

  Future<void> _applyProxy() async {
    var pp = player.platform as NativePlayer;
    await pp.setProperty('tls-verify', 'no');
    await pp.setProperty('insecure', 'yes');
    if (appdata.settings['proxy'] != 'direct' &&
        appdata.settings['proxy'] != null) {
      final proxyAddr = await getProxy();
      if (proxyAddr != null) {
        final proxyUrl = proxyAddr.startsWith('http://')
            ? proxyAddr
            : 'http://$proxyAddr';
        await pp.setProperty('http-proxy', proxyUrl);
      }
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }
}

final videoTestProvider =
    StateNotifierProvider.autoDispose<VideoTestNotifier, VideoTestState>(
      (ref) => VideoTestNotifier(),
    );

class VideoTestPage extends ConsumerStatefulWidget {
  const VideoTestPage({super.key, this.url});

  /// 可选：进入页面后自动播放该视频地址
  final String? url;

  @override
  ConsumerState<VideoTestPage> createState() => _VideoTestPageState();
}

class _VideoTestPageState extends ConsumerState<VideoTestPage> {
  @override
  void initState() {
    super.initState();
    final url = widget.url;
    if (url != null && url.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(videoTestProvider.notifier).load(url, const []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(videoTestProvider.notifier);

    return Scaffold(
      appBar: Appbar(title: Text(t.videoTestLabel)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _PlayerView(videoController: notifier.videoController),
                const _BufferingOverlay(),
                const _CompletedOverlay(),
              ],
            ),
          ),

          const _ControlPanel(),
        ],
      ),
    );
  }
}

/// 播放器视图（布局照搬本地播放器）：全屏 Video + 径向渐变遮罩 +
/// 点击/双击/长按 2x / 左右滑动 seek / 上下音量亮度 + 底部控件 + HUD。
class _PlayerView extends ConsumerStatefulWidget {
  const _PlayerView({required this.videoController});

  final VideoController videoController;

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView>
    with TickerProviderStateMixin {
  bool _showControls = true;
  Timer? _hideTimer;
  late final AnimationController _animCtrl;
  late final Animation<double> _fade;

  Duration? _seekPreview;
  bool _showSeekTime = false;
  bool _showVolume = false;
  bool _showBrightness = false;
  double _volume = 1.0;
  double _brightness = 1.0;
  double _boostSpeed = 0.0; // 长按 2x 临时倍速（0 = 未加速）

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1,
    );
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _showControlsDirect(bool v) {
    setState(() => _showControls = v);
  }

  void _displayControls() {
    _animCtrl.forward();
    _hideTimer?.cancel();
    _startHideTimer();
    _showControlsDirect(true);
  }

  void _hideControls() {
    _animCtrl.reverse();
    _hideTimer?.cancel();
    _showControlsDirect(false);
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _animCtrl.reverse();
        _showControlsDirect(false);
      }
      _hideTimer = null;
    });
  }

  void _handleTap() {
    if (_showControls) {
      _hideControls();
    } else {
      _displayControls();
    }
  }

  Future<void> _handleDoubleTap() async {
    await ref.read(videoTestProvider.notifier).togglePlay();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final s = ref.read(videoTestProvider);
    final scale = 180000 / MediaQuery.sizeOf(context).width;
    final base = _seekPreview ?? s.position;
    final ms = (base.inMilliseconds + (details.delta.dx * scale).round())
        .clamp(0, s.duration.inMilliseconds);
    setState(() => _seekPreview = Duration(milliseconds: ms));
  }

  Future<void> _onHorizontalDragEnd() async {
    final target = _seekPreview;
    final notifier = ref.read(videoTestProvider.notifier);
    if (target != null) {
      await notifier.seek(target);
    }
    setState(() {
      _seekPreview = null;
      _showSeekTime = false;
    });
  }

  Future<void> _onVerticalDragUpdate(DragUpdateDetails details) async {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    final delta = details.delta.dy;
    if (details.localPosition.dx < w / 2) {
      setState(() => _showBrightness = true);
      final result = (_brightness - delta / (h * 2)).clamp(0.0, 1.0);
      _brightness = result;
      try {
        await ScreenBrightnessPlatform.instance
            .setApplicationScreenBrightness(result);
      } catch (_) {}
    } else {
      setState(() => _showVolume = true);
      final v = (_volume - delta / (h * 0.03)).clamp(0.0, 1.0);
      _volume = v;
      try {
        FlutterVolumeController.updateShowSystemUI(false);
        await FlutterVolumeController.setVolume(v);
      } catch (_) {}
    }
  }

  void _onVerticalDragEnd() {
    setState(() {
      _showVolume = false;
      _showBrightness = false;
    });
    FlutterVolumeController.updateShowSystemUI(true);
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoTestProvider);
    final displaySpeed = _boostSpeed > 0 ? _boostSpeed : state.speed;
    return Stack(
      children: [
        Positioned.fill(
          child: Video(
            controller: widget.videoController,
            controls: NoVideoControls,
            fill: Colors.black,
          ),
        ),
        // 径向渐变遮罩（照搬本地播放器）
        FadeTransition(
          opacity: _fade,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  Colors.black.toOpacity(0.2),
                  Colors.black.toOpacity(0.5),
                  Colors.black.toOpacity(0.7),
                ],
                stops: const [0.0, 0.6, 0.85, 1.0],
              ),
            ),
          ),
        ),
        // tap 手势层
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onDoubleTap: _handleDoubleTap,
            onLongPressStart: (_) {
              setState(() => _boostSpeed = 2.0);
              ref.read(videoTestProvider.notifier).setSpeed(2.0);
            },
            onLongPressEnd: (_) {
              setState(() => _boostSpeed = 0.0);
              ref.read(videoTestProvider.notifier).setSpeed(1.0);
            },
          ),
        ),
        // 滑动手势层
        Positioned.fill(
          left: 16,
          top: 25,
          right: 15,
          bottom: MediaQuery.paddingOf(context).bottom + 70,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              setState(() => _showSeekTime = true);
            },
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: (_) => _onHorizontalDragEnd(),
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: (_) => _onVerticalDragEnd(),
          ),
        ),
        // 底部控件
        if (_showControls)
          FadeTransition(
            opacity: _fade,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildBottomBar(state, displaySpeed),
            ),
          ),
        // HUD
        if (_showSeekTime) _buildSeekHud(state),
        if (_showVolume) _buildLevelHud(volume: _volume, isBrightness: false),
        if (_showBrightness)
          _buildLevelHud(brightness: _brightness, isBrightness: true),
        if (_boostSpeed > 0) _buildSpeedHud(displaySpeed),
      ],
    );
  }

  Widget _buildBottomBar(VideoTestState state, double speed) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              color: Colors.white,
              icon: Icon(
                state.playing ? Icons.pause : Icons.play_arrow,
                size: 30,
              ),
              onPressed: () => ref.read(videoTestProvider.notifier).togglePlay(),
            ),
            Expanded(
              child: ProgressBar(
                thumbRadius: 8,
                thumbGlowRadius: 18,
                timeLabelLocation: TimeLabelLocation.none,
                progress: state.position,
                buffered: state.buffer,
                total: state.duration,
                onSeek: (d) => ref.read(videoTestProvider.notifier).seek(d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${speed}x',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekHud(VideoTestState state) {
    final target = _seekPreview ?? state.position;
    final current = state.position;
    final total = state.duration;
    final isForward = target > current;
    final diffSec = (target - current).inSeconds.abs().clamp(0, 999);
    final totalSec = total.inSeconds > 0 ? total.inSeconds : 1;
    final progress = (target.inMilliseconds / (totalSec * 1000)).clamp(
      0.0,
      1.0,
    );
    final accent = isForward
        ? const Color(0xFF2ED8A7)
        : const Color(0xFFFF7A6B);
    final icon = isForward
        ? Icons.fast_forward_rounded
        : Icons.fast_rewind_rounded;
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: _frostedGlass(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isForward
                          ? t.seekForward(s: diffSec)
                          : t.seekBackward(s: diffSec),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmtDuration(target),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' / ${_fmtDuration(total)}',
                          style: TextStyle(
                            color: Colors.white.toOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Container(color: Colors.white.toOpacity(0.15)),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(color: accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelHud({
    double? volume,
    double? brightness,
    required bool isBrightness,
  }) {
    final accent = isBrightness
        ? const Color(0xFFF5A623)
        : const Color(0xFF4DB6FF);
    final value = isBrightness ? (brightness ?? 1) * 100 : (volume ?? 1) * 100;
    final icon = isBrightness
        ? Icons.brightness_7_rounded
        : (value <= 0
              ? Icons.volume_off_rounded
              : value < 50
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: _frostedGlass(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  height: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(color: Colors.white.toOpacity(0.15)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 110 * (value.clamp(0, 100) / 100),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: accent.toOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${value.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedHud(double speed) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 80,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: _frostedGlass(
            child: Text(
              '${speed.toInt()}X',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _frostedGlass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.toOpacity(0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.toOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _BufferingOverlay extends ConsumerWidget {
  const _BufferingOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buffering = ref.watch(videoTestProvider.select((s) => s.buffering));
    final hasUrl = ref.watch(videoTestProvider.select((s) => s.url.isNotEmpty));
    if (!buffering || !hasUrl) return const SizedBox.shrink();
    return const Center(child: PolygonRefreshIndicator());
  }
}

class _CompletedOverlay extends ConsumerWidget {
  const _CompletedOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(videoTestProvider.select((s) => s.completed));
    if (!completed) return const SizedBox.shrink();
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              t.vtPlaybackComplete,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(videoTestProvider.notifier).seek(Duration.zero),
              icon: const Icon(Icons.replay),
              label: Text(t.vtReplay),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends ConsumerWidget {
  const _ControlPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 6),
          _DragHandle(),
          SizedBox(height: 8),
          _ProgressRow(),
          _PlaybackRow(),
          _UrlRow(),
          SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _ProgressRow extends ConsumerStatefulWidget {
  const _ProgressRow();

  @override
  ConsumerState<_ProgressRow> createState() => _ProgressRowState();
}

class _ProgressRowState extends ConsumerState<_ProgressRow> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(videoTestProvider.select((s) => s.position));
    final duration = ref.watch(videoTestProvider.select((s) => s.duration));
    final buffer = ref.watch(videoTestProvider.select((s) => s.buffer));
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ProgressBar(
        thumbRadius: 8,
        thumbGlowRadius: 18,
        timeLabelLocation: TimeLabelLocation.sides,
        timeLabelTextStyle: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        progressBarColor: cs.primary,
        bufferedBarColor: cs.primary.withValues(alpha: 0.25),
        baseBarColor: cs.outlineVariant.withValues(alpha: 0.4),
        thumbColor: cs.primary,
        thumbGlowColor: cs.primary.withValues(alpha: 0.2),
        progress: _dragPosition ?? position,
        buffered: buffer,
        total: duration > Duration.zero ? duration : const Duration(seconds: 1),
        onSeek: (d) {
          ref.read(videoTestProvider.notifier).seek(d);
        },
        onDragStart: (_) {
          setState(() => _dragPosition = position);
        },
        onDragUpdate: (details) {
          setState(() => _dragPosition = details.timeStamp);
        },
        onDragEnd: () {
          setState(() => _dragPosition = null);
        },
      ),
    );
  }
}

class _PlaybackRow extends ConsumerWidget {
  const _PlaybackRow();

  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(videoTestProvider.select((s) => s.playing));
    final speed = ref.watch(videoTestProvider.select((s) => s.speed));
    final hasUrl = ref.watch(videoTestProvider.select((s) => s.url.isNotEmpty));
    final notifier = ref.read(videoTestProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: hasUrl ? notifier.togglePlay : null,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            iconSize: 28,
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: hasUrl
                ? () {
                    final pos = ref.read(videoTestProvider).position;
                    notifier.seek(
                      Duration(
                        milliseconds: (pos.inMilliseconds - 10000).clamp(
                          0,
                          9999999,
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.replay_10_rounded),
            color: cs.onSurface,
          ),
          IconButton(
            onPressed: hasUrl
                ? () {
                    final s = ref.read(videoTestProvider);
                    final target = (s.position.inMilliseconds + 10000).clamp(
                      0,
                      s.duration.inMilliseconds,
                    );
                    notifier.seek(Duration(milliseconds: target));
                  }
                : null,
            icon: const Icon(Icons.forward_10_rounded),
            color: cs.onSurface,
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              final s = ref.read(videoTestProvider);
              final notifier = ref.read(videoTestProvider.notifier);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => Sheet(
                  title: t.watcherDetailsLogs,
                  icon: Icons.info_outline_rounded,
                  initialSize: 0.65,
                  builder: (_, sc) => VideoInfoSheet.fromPlayer(
                    player: notifier.player,
                    videoUrl: s.url,
                    logs: s.logs,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: t.watcherDetailsLogs,
          ),
          const SizedBox(width: 4),
          PopupMenuButton<double>(
            initialValue: speed,
            onSelected: notifier.setSpeed,
            itemBuilder: (_) => _speeds
                .map(
                  (s) => PopupMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        if (s == speed)
                          Icon(Icons.check, size: 16, color: cs.primary)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text('${s}x'),
                      ],
                    ),
                  ),
                )
                .toList(),
            child: Chip(
              label: Text('${speed}x'),
              labelStyle: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
              side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
              backgroundColor: cs.primary.withValues(alpha: 0.08),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlRow extends ConsumerStatefulWidget {
  const _UrlRow();

  @override
  ConsumerState<_UrlRow> createState() => _UrlRowState();
}

class _UrlRowState extends ConsumerState<_UrlRow> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: ref.read(videoTestProvider).url);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _load() {
    FocusScope.of(context).unfocus();
    final headers = ref.read(videoTestProvider).headers;
    ref.read(videoTestProvider.notifier).load(_urlCtrl.text.trim(), headers);
  }

  void _openHeaderSheet() {
    final headerState = GlobalKey<_HeaderSheetState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Sheet(
        title: t.vtHeaders,
        icon: Icons.tune_rounded,
        initialSize: 0.6,
        headerTrailing: TextButton.icon(
          onPressed: () => headerState.currentState?.addRow(),
          icon: const Icon(Icons.add, size: 16),
          label: Text(t.add),
        ),
        footer: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => headerState.currentState?.clearAll(),
                child: Text(t.clear),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => headerState.currentState?.apply(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(t.vtApplyAndLoad),
              ),
            ],
          ),
        ),
        builder: (ctx, sc) => _HeaderSheet(
          key: headerState,
          scrollController: sc,
          initialHeaders: ref.read(videoTestProvider).headers,
          onApply: (headers) {
            ref
                .read(videoTestProvider.notifier)
                .load(_urlCtrl.text.trim(), headers);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final headerCount = ref.watch(
      videoTestProvider.select((s) => s.headers.length),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: t.vtInputUrlHint,
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.link_rounded, size: 18),
                suffixIcon: _urlCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _urlCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _load(),
              textInputAction: TextInputAction.go,
            ),
          ),
          const SizedBox(width: 8),
          // Headers button
          Badge(
            isLabelVisible: headerCount > 0,
            label: Text('$headerCount'),
            child: IconButton(
              onPressed: _openHeaderSheet,
              icon: const Icon(Icons.tune_rounded),
              tooltip: t.requestHeaders,
              style: IconButton.styleFrom(
                foregroundColor: headerCount > 0 ? cs.primary : null,
                backgroundColor: headerCount > 0
                    ? cs.primary.withValues(alpha: 0.1)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _urlCtrl.text.trim().isNotEmpty ? _load : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t.vtLoad),
          ),
        ],
      ),
    );
  }
}

class _HeaderSheet extends StatefulWidget {
  const _HeaderSheet({
    super.key,
    required this.initialHeaders,
    required this.onApply,
    required this.scrollController,
  });

  final List<HeaderEntry> initialHeaders;
  final void Function(List<HeaderEntry>) onApply;
  final ScrollController scrollController;

  @override
  State<_HeaderSheet> createState() => _HeaderSheetState();
}

class _HeaderSheetState extends State<_HeaderSheet> {
  late final List<_HeaderRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialHeaders
        .map(
          (h) => _HeaderRow(
            keyCtrl: TextEditingController(text: h.key),
            valueCtrl: TextEditingController(text: h.value),
          ),
        )
        .toList();
    if (_rows.isEmpty) addRow();
  }

  void addRow() {
    setState(() {
      _rows.add(
        _HeaderRow(
          keyCtrl: TextEditingController(),
          valueCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  void apply() {
    final headers = _rows
        .map((r) => HeaderEntry(r.keyCtrl.text.trim(), r.valueCtrl.text.trim()))
        .where((h) => h.key.isNotEmpty)
        .toList();
    widget.onApply(headers);
    Navigator.of(context).pop();
  }

  void clearAll() {
    setState(() {
      for (final r in _rows) {
        r.dispose();
      }
      _rows.clear();
    });
  }

  static const _presets = {
    'Referer': '',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Origin': '',
  };

  void _addPreset(String key, String value) {
    for (final r in _rows) {
      if (r.keyCtrl.text.trim() == key) return;
    }
    setState(() {
      _rows.add(
        _HeaderRow(
          keyCtrl: TextEditingController(text: key),
          valueCtrl: TextEditingController(text: value),
        ),
      );
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _presets.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12),
                        ),
                        avatar: const Icon(Icons.add_circle_outline, size: 14),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _addPreset(e.key, e.value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: _rows.isEmpty
                ? Center(child: Text(t.vtNoHeaders, textAlign: TextAlign.center))
                : ListView.separated(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _HeaderRowTile(
                      row: _rows[i],
                      onRemove: () => _removeRow(i),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow {
  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;

  _HeaderRow({required this.keyCtrl, required this.valueCtrl});

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

class _HeaderRowTile extends StatelessWidget {
  const _HeaderRowTile({required this.row, required this.onRemove});

  final _HeaderRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: _CompactField(
            controller: row.keyCtrl,
            hint: 'Key',
            prefixIcon: Icons.key_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 6,
          child: _CompactField(
            controller: row.valueCtrl,
            hint: 'Value',
            prefixIcon: Icons.text_fields_rounded,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline),
          iconSize: 20,
          color: cs.error,
          visualDensity: VisualDensity.compact,
          tooltip: t.delete,
        ),
      ],
    );
  }
}

class _CompactField extends StatelessWidget {
  const _CompactField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
  });

  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(prefixIcon, size: 14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
