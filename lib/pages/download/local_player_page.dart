import 'dart:async';
import 'dart:ui' as ui;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/system_status_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_controller.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// 本地视频播放页（播放已下载的 mp4）
class LocalPlayerPage extends StatelessWidget {
  final String filePath;

  const LocalPlayerPage({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LocalPlayerView(filePath: filePath),
    );
  }
}

/// 全屏播放路由（参考 watcher FullscreenVideoPage）：横屏沉浸式，
/// 复用同一 filePath 的 Riverpod provider（同一个 Player）。
/// 系统返回 = 退出全屏。
class LocalFullscreenVideoPage extends ConsumerStatefulWidget {
  final String filePath;

  const LocalFullscreenVideoPage({super.key, required this.filePath});

  @override
  ConsumerState<LocalFullscreenVideoPage> createState() =>
      _LocalFullscreenVideoPageState();
}

class _LocalFullscreenVideoPageState
    extends ConsumerState<LocalFullscreenVideoPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref
              .read(localPlayerControllerProvider(widget.filePath).notifier)
              .toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LocalPlayerView(filePath: widget.filePath),
      ),
    );
  }
}

/// 本地播放器视图：控件布局与手势照搬 watcher 播放器
/// （player_item_panel / player_item / player_item_base_panel）：
/// 侧边栏、顶部、底部进度+控制、FadeTransition、MouseRegion、
/// 点击/双击/长按 2x / 左右滑动 seek / 上下滑动音量·亮度、磨砂 HUD。
class LocalPlayerView extends ConsumerStatefulWidget {
  final String filePath;

  const LocalPlayerView({super.key, required this.filePath});

  @override
  ConsumerState<LocalPlayerView> createState() => _LocalPlayerViewState();
}

class _LocalPlayerViewState extends ConsumerState<LocalPlayerView>
    with TickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> fadeAnimation;
  Timer? hideTimer;

  LocalPlayerController get ctrl =>
      ref.read(localPlayerControllerProvider(widget.filePath).notifier);

  /// 当前状态（方法里访问，build 内用 ref.watch 的 state）
  LocalPlayerState get st => ref.read(localPlayerControllerProvider(widget.filePath));

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1,
    );
    fadeAnimation = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    animationController.dispose();
    super.dispose();
  }

  // ---- 控件显示/隐藏（照搬 player_item）----

  void displayVideoController() {
    animationController.forward();
    hideTimer?.cancel();
    startHideTimer();
    ctrl.showControlsDirect(true);
  }

  void hideVideoController() {
    animationController.reverse();
    hideTimer?.cancel();
    ctrl.showControlsDirect(false);
  }

  void _handleTap() {
    if (FocusManager.instance.primaryFocus?.hasFocus == true) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (st.showControls) {
      hideVideoController();
    } else {
      displayVideoController();
    }
  }

  void _handleDoubleTap() {
    ctrl.playOrPause();
  }

  void _handleHove() {
    if (!st.showControls) {
      displayVideoController();
    }
    hideTimer?.cancel();
    startHideTimer();
  }

  void startHideTimer() {
    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        ctrl.showControlsDirect(false);
        animationController.reverse();
      }
      hideTimer = null;
    });
  }

  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  void _onHorizontalDragStart() {
    if (st.showControls) {
      animationController.reverse();
    }
    // 照搬 watcher：拖动时停止进度同步 + 暂停，避免进度回退
    ctrl.stopPositionSync();
    ctrl.pause();
    ctrl.setShowSeekTime(true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final scale = 180000 / MediaQuery.sizeOf(context).width;
    // 基于上次 seekPreview 累积（watcher 同款），避免只反映最后一段位移
    final base = st.seekPreview ?? st.position;
    final ms = (base.inMilliseconds + (details.delta.dx * scale).round())
        .clamp(0, st.duration.inMilliseconds);
    ctrl.setSeekPreview(Duration(milliseconds: ms));
  }

  void _onHorizontalDragEnd() {
    final target = st.seekPreview ?? st.position;
    // 照搬 watcher onHorizontalDragEnd 顺序：play → seek → 恢复同步
    ctrl.play();
    ctrl.seek(target);
    ctrl.startPositionSync();
    ctrl.setShowSeekTime(false);
    displayVideoController();
  }

  Future<void> _onVerticalDragUpdate(DragUpdateDetails details) async {
    final totalWidth = MediaQuery.sizeOf(context).width;
    final totalHeight = MediaQuery.sizeOf(context).height;
    final tapPosition = details.localPosition.dx;
    final sectionWidth = totalWidth / 2;
    final delta = details.delta.dy;

    if (tapPosition < sectionWidth) {
      // 左半屏调亮度
      ctrl.setShowBrightness(true);
      final level = totalHeight * 2;
      final result = (st.brightness - delta / level).clamp(0.0, 1.0);
      await ctrl.setBrightness(result);
    } else {
      // 右半屏调音量
      ctrl.setShowVolume(true);
      final level = totalHeight * 0.03;
      final v = (st.volume - delta / level).clamp(0.0, 1.0);
      await ctrl.setVolume(v);
    }
  }

  void _onVerticalDragEnd() {
    ctrl.setShowVolume(false);
    ctrl.setShowBrightness(false);
    FlutterVolumeController.updateShowSystemUI(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localPlayerControllerProvider(widget.filePath));
    final c = ctrl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: state.error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      state.error,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : state.loading
          ? const Center(child: PolygonRefreshIndicator())
          : _buildPlayerArea(context, state, c),
    );
  }

  /// 播放区域：桌面端包 MouseRegion（hover 显示控件），移动端纯手势 Stack
  Widget _buildPlayerArea(
    BuildContext context,
    LocalPlayerState state,
    LocalPlayerController c,
  ) {
    final stack = Stack(
      children: [
        Positioned.fill(
          child: Video(
            controller: c.controller,
            controls: null,
            fit: BoxFit.contain,
          ),
        ),
        // 径向渐变遮罩（照搬 player_item AmbientShaderVideo）：
        // 边缘渐暗，随控件淡入淡出
        FadeTransition(
          opacity: fadeAnimation,
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
        // tap 手势层（照搬 player_item 618：点击/双击/长按 2x，位于面板之下）
        // opaque：命中并短路，确保 tap/双击/长按收到事件
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onDoubleTap: _handleDoubleTap,
            onLongPressStart: (_) => c.startSpeedBoost(),
            onLongPressEnd: (_) => c.stopSpeedBoost(),
          ),
        ),
        // 控件层（面板）
        if (state.showControls)
          FadeTransition(
            opacity: fadeAnimation,
            child: _buildPanel(state),
          ),
        // 滑动手势层（照搬 player_item 679：位于面板之上）
        // translucent：加入 hit path 但不短路，让下层 tap 层也能收事件。
        // bottom 避开底部控制面板，避免面板内横向拖动（进度条等）误触发 seek
        Positioned.fill(
          left: 16,
          top: 25,
          right: 15,
          bottom: MediaQuery.paddingOf(context).bottom + 70,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _onHorizontalDragStart(),
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: (_) => _onHorizontalDragEnd(),
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: (_) => _onVerticalDragEnd(),
          ),
        ),
        if (state.showSeekTime) _buildSeekIndicator(state),
        if (state.showVolume) _buildLevelHUD(state, isBrightness: false),
        if (state.showBrightness) _buildLevelHUD(state, isBrightness: true),
        if (state.speed != 1.0 && !state.showControls)
          _buildSpeedIndicator(state),
      ],
    );
    if (!App.isDesktop) return stack;
    return MouseRegion(
      cursor: (state.fullscreen && !state.showControls)
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      onHover: (p) {
        if (p.position.dy > 50 &&
            p.position.dy < MediaQuery.of(context).size.height - 70) {
          _handleHove();
        } else {
          if (!state.showControls) {
            animationController.forward();
            ctrl.showControlsDirect(true);
          }
        }
      },
      child: stack,
    );
  }

  /// 控件层面板：照搬 PlayerItemPanel（侧边栏/顶部/底部，全屏透明 Stack）
  Widget _buildPanel(LocalPlayerState state) {
    return Stack(
      children: [
        _buildSideBar(),
        _buildTopBar(),
        _buildBottomBar(state),
      ],
    );
  }

  // ---- 侧边栏（照搬 right:10 top:40）----

  Widget _buildSideBar() {
    return Positioned(
      right: 10,
      // 状态栏 + 顶栏高度，避免与顶栏按钮重合
      top: MediaQuery.paddingOf(context).top + 48,
      child: Column(
        children: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.fit_screen),
            tooltip: t.screenshotShare,
            onPressed: ctrl.captureScreenshot,
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.seekBy(const Duration(seconds: 80)),
          ),
        ],
      ),
    );
  }

  // ---- 顶部（照搬：返回 + Marquee 标题 + 倍速）----

  /// 顶部时间状态条（照搬 player_item_panel 全屏时的时间/电池/网络）
  Widget _buildTimeStatusBar() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Utils.buildTimeIcon(now),
          const SizedBox(width: 6),
          StreamBuilder<String>(
            stream: Stream.periodic(
              const Duration(seconds: 1),
              (_) => _formatNow(),
            ),
            initialData: _formatNow(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? '--:--:--',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: Theme.of(context).textTheme.titleMedium!.fontSize,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: Colors.white24),
          const SizedBox(width: 8),
          BatteryWidget(),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: Colors.white24),
          const SizedBox(width: 8),
          NetworkStatusWidget(),
          const SizedBox(width: 6),
          if (App.isAndroid)
            SizedBox(width: 32, child: SpeedMonitorWidget()),
          if (App.isAndroid) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 0, right: 10),
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () {
                  // 照搬 watcher player_item_panel：全屏时退出全屏，否则返回
                  if (st.fullscreen) {
                    ctrl.toggleFullscreen();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              const Spacer(),
              if (st.fullscreen) _buildTimeStatusBar(),
              TextButton(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () {
                  if (st.speed < 2) {
                    ctrl.setRate(2);
                  } else {
                    ctrl.setRate(1);
                  }
                },
                child: Text(
                  '${st.speed}X',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 底部（照搬：信息行 + 进度条 + 控制行）----

  Widget _buildBottomBar(LocalPlayerState state) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 控制行：播放/暂停 + 进度条 + 全屏
            Row(
              children: [
                IconButton(
                  color: Colors.white,
                  icon: Icon(
                    state.playing ? Icons.pause : Icons.play_arrow,
                    size: 30,
                  ),
                  onPressed: ctrl.playOrPause,
                ),
                Expanded(
                  child: ProgressBar(
                    thumbRadius: 8,
                    thumbGlowRadius: 18,
                    timeLabelLocation: TimeLabelLocation.none,
                    timeLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.0,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    progress: state.position,
                    buffered: state.buffer,
                    total: state.duration,
                    onSeek: ctrl.seek,
                  ),
                ),
                IconButton(
                  color: Colors.white,
                  icon: Icon(
                    state.fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                  tooltip: t.fullscreen,
                  onPressed: ctrl.toggleFullscreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- HUD 指示 ----

  Widget _buildSeekIndicator(LocalPlayerState state) {
    // 照搬 base_panel 的 _SeekHUD：方向配色 + 磨砂玻璃 + 目标时间/总时长 + 进度条
    final target = state.seekPreview ?? state.position;
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        icon,
                        key: ValueKey(icon),
                        color: accent,
                        size: 22,
                      ),
                    ),
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
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// 亮度/音量 HUD（照搬 base_panel _LevelSliderHUD）：
  /// 顶部居中 top:50，磨砂玻璃 + 等级图标 + 进度条 + 数值
  Widget _buildLevelHUD(
    LocalPlayerState state, {
    required bool isBrightness,
  }) {
    final accent = isBrightness
        ? const Color(0xFFF5A623)
        : const Color(0xFF4DB6FF);
    final value = isBrightness
        ? state.brightness * 100
        : state.volume * 100;
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

  /// 播放速度 HUD（照搬 base_panel showPlaySpeed）：顶部居中
  Widget _buildSpeedIndicator(LocalPlayerState state) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 80,
      left: 0,
      right: 0,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.toOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedPlayIconWave(
                      size: 14,
                      count: state.speed.toInt(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${state.speed.toInt()}X',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 磨砂玻璃容器（照搬 base_panel _FrostedGlass）
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
