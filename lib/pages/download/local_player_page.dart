import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/system_status_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/download/local_player_controller.dart';
import 'package:kostori/pages/watcher/player_hud.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';
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

/// 本地播放器视图：侧边栏、顶部、底部进度+控制、FadeTransition、
/// MouseRegion、点击/双击/长按 2x / 左右滑动 seek / 上下滑动音量·亮度、磨砂 HUD。
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
  LocalPlayerState get st =>
      ref.read(localPlayerControllerProvider(widget.filePath));

  /// 竖屏全屏（对齐 anime page 播放器的 isPortraitFullscreen）
  bool get isPortraitFullscreen =>
      st.fullscreen && MediaQuery.orientationOf(context) == Orientation.portrait;

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

  // 控件显示/隐藏
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
    // 拖动时停止进度同步 + 暂停，避免进度回退
    ctrl.stopPositionSync();
    ctrl.pause();
    ctrl.setShowSeekTime(true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final scale = 180000 / MediaQuery.sizeOf(context).width;
    // 基于上次 seekPreview 累积，避免只反映最后一段位移
    final base = st.seekPreview ?? st.position;
    final ms = (base.inMilliseconds + (details.delta.dx * scale).round()).clamp(
      0,
      st.duration.inMilliseconds,
    );
    ctrl.setSeekPreview(Duration(milliseconds: ms));
  }

  void _onHorizontalDragEnd() {
    final target = st.seekPreview ?? st.position;
    // 顺序：play → seek → 恢复同步
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
      // 整屏高度滑满 ≈ 满量程变化（此前除数是 height*0.03，轻微上滑就冲到 100%）
      final level = totalHeight;
      final result = (st.brightness - delta / level).clamp(0.0, 1.0);
      await ctrl.setBrightness(result);
    } else {
      // 右半屏调音量
      ctrl.setShowVolume(true);
      final level = totalHeight;
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
        // 径向渐变遮罩：边缘渐暗，随控件淡入淡出
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
        // tap 手势层：点击/双击/长按 2x，位于面板之下
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
          FadeTransition(opacity: fadeAnimation, child: _buildPanel(state)),
        // 滑动手势层：位于面板之上
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
        if (state.showSeekTime && state.seekPreview != null)
          _buildSeekIndicator(state),
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
            p.position.dy < MediaQuery.sizeOf(context).height - 70) {
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

  /// 控件层面板：侧边栏/顶部/底部，全屏透明 Stack
  Widget _buildPanel(LocalPlayerState state) {
    return Stack(
      children: [_buildSideBar(), _buildTopBar(state), _buildBottomBar(state)],
    );
  }

  // 侧边栏
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

  // ---- 顶部（返回 + Marquee 标题 + 倍速）----

  /// 顶部时间状态条（全屏时的时间/电池/网络）
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
          if (App.isAndroid) SizedBox(width: 32, child: SpeedMonitorWidget()),
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

  /// 标题（超宽时滚动 Marquee）
  Widget _buildTitle() {
    final text = ctrl.title;
    const style = TextStyle(color: Colors.white, fontSize: 16);
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final shouldScroll = textPainter.width >= constraints.maxWidth - 30;
        return SizedBox(
          height: 24,
          child: ClipRect(
            child: shouldScroll
                ? Marquee(
                    text: text,
                    style: style,
                    scrollAxis: Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    blankSpace: 10.0,
                    velocity: 40.0,
                    pauseAfterRound: Duration.zero,
                    startPadding: 10.0,
                    accelerationDuration: Duration.zero,
                    decelerationDuration: Duration.zero,
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(LocalPlayerState state) {
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
                  // 全屏时退出全屏，否则返回
                  if (state.fullscreen) {
                    ctrl.toggleFullscreen();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              // 标题集数显示
              Expanded(child: _buildTitle()),
              if (state.fullscreen) _buildTimeStatusBar(),
              TextButton(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () {
                  if (state.speed < 2) {
                    ctrl.setRate(2);
                  } else {
                    ctrl.setRate(1);
                  }
                },
                child: Text(
                  '${state.speed}X',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              // 播放器详情
              if (!state.fullscreen)
                IconButton(
                  color: Colors.white,
                  icon: const Icon(Icons.info_outline),
                  tooltip: t.playerDetails,
                  onPressed: _showVideoInfo,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 播放器详情（复用 watcher 的 VideoInfoSheet，直接读取 media_kit Player）
  void _showVideoInfo() {
    showModalBottomSheet(
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 3 / 4,
        maxWidth: MediaQuery.sizeOf(context).width <= 600
            ? MediaQuery.sizeOf(context).width
            : (App.isDesktop
                  ? MediaQuery.sizeOf(context).width * 9 / 16
                  : MediaQuery.sizeOf(context).width),
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (_) => Sheet(
        title: t.watcherDetailsLogs,
        icon: Icons.info_outline_rounded,
        builder: (_, _) => VideoInfoSheet.fromPlayer(
          player: ctrl.player,
          videoUrl: widget.filePath,
          logs: const [],
          playbackOk: st.error.isNotEmpty
              ? false
              : (st.duration > Duration.zero || st.playing ? true : null),
          playbackError: st.error.isEmpty ? null : st.error,
          firstFrame: st.duration > Duration.zero,
        ),
      ),
    );
  }

  // ---- 底部（信息行 + 进度条 + 控制行）----

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
            // 信息行：时长（右对齐，位于进度条上方，和 anime page 播放器一致）
            Padding(
              padding: const EdgeInsets.only(right: 10, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${Utils.durationToString(state.position)} / ${Utils.durationToString(state.duration)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 控制行：播放/暂停 + 进度条 + 全屏
            Row(
              children: [
                IconButton(
                  color: Colors.white,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      state.playing ? Icons.pause : Icons.play_arrow,
                      key: ValueKey<bool>(state.playing),
                      size: 30,
                    ),
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

  // HUD 指示
  Widget _buildSeekIndicator(LocalPlayerState state) {
    // 复用 anime page 播放器的快进/快退 HUD（PlayerSeekHud）
    return Positioned(
      top: playerHudTop(isPortraitFullscreen: isPortraitFullscreen),
      left: 0,
      right: 0,
      child: Center(
        child: PlayerSeekHud(
          target: state.seekPreview ?? state.position,
          current: state.position,
          total: state.duration,
        ),
      ),
    );
  }

  /// 亮度/音量 HUD：顶部居中（复用 anime page 播放器的 PlayerLevelHud）
  Widget _buildLevelHUD(LocalPlayerState state, {required bool isBrightness}) {
    final value = isBrightness ? state.brightness * 100 : state.volume * 100;
    return Positioned(
      top: playerHudTop(isPortraitFullscreen: isPortraitFullscreen),
      left: 0,
      right: 0,
      child: Center(
        child: PlayerLevelHud(isBrightness: isBrightness, value: value),
      ),
    );
  }

  /// 播放速度 HUD：顶部居中
  Widget _buildSpeedIndicator(LocalPlayerState state) {
    return Positioned(
      top: playerHudTop(isPortraitFullscreen: isPortraitFullscreen),
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
                    AnimatedPlayIconWave(size: 14, count: state.speed.toInt()),
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
}
