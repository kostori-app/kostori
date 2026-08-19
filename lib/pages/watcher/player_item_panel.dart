// ignore_for_file: use_build_context_synchronously
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/system_status_widget.dart';
import 'package:kostori/foundation/anime_source/anime_play_result.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/pages/watcher/danmaku_settings.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/volume_slider_popup.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.playerController,
    required this.openMenu,
    this.onChatToggle,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.startHideTimer,
    required this.cancelHideTimer,
    required this.showVideoInfo,
    required this.buildMenuItems,
  });

  final PlayerController playerController;
  final void Function() openMenu;
  final VoidCallback? onChatToggle;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final AnimationController animationController;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() showVideoInfo;
  final Widget buildMenuItems;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  PlayerController get playerController => widget.playerController;
  late final Animation<double> fadeAnimation;
  final TextEditingController textController = TextEditingController();

  bool glimmerEffect = appdata.implicitData['glimmerEffect'] ?? false;

  /// 快捷输入框焦点回调（稳定方法引用，避免 Observer 频繁重建时创建新闭包
  /// 导致 _QuickChatInput 收到新的 widget 字段、打断中文输入法组词）
  void _onQuickChatFocusChanged(bool hasFocus) {
    playerController.canHidePlayerPanel = !hasFocus;
    if (hasFocus) {
      widget.cancelHideTimer();
    } else {
      widget.startHideTimer();
    }
  }

  @override
  void initState() {
    super.initState();
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 侧边栏:截图,快进
            Positioned(
              right: 10,
              top: 40,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: IgnorePointer(
                  ignoring: !playerController.showVideoController,
                  child: MouseRegion(
                    cursor:
                        (playerController.isFullScreen &&
                            widget.animationController.value == 0)
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onEnter: (_) {
                      widget.cancelHideTimer();
                    },
                    onExit: (_) {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                    },
                    child: Column(
                      children: [
                        IconButton(
                          icon: Icon(Icons.fit_screen, color: Colors.white),
                          onPressed: () async {
                            await playerController.captureAndSaveScreenshot(
                              context: context,
                            );
                          },
                          onLongPress: () async {
                            await playerController.openVideoClipEditor(
                              context: context,
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            playerController.seek(
                              playerController.currentPosition +
                                  const Duration(seconds: 80),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 自定义顶部组件
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: IgnorePointer(
                  ignoring: !playerController.showVideoController,
                  child: MouseRegion(
                    cursor:
                        (playerController.isFullScreen &&
                            widget.animationController.value == 0)
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onEnter: (_) {
                      widget.cancelHideTimer();
                    },
                    onExit: (_) {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10, left: 0),
                      child: Row(
                        children: [
                          IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.arrow_back_ios_new),
                            onPressed: () {
                              if (playerController.isFullScreen) {
                                // 检查是否是桌面环境，分别处理全屏逻辑
                                playerController.toggleFullScreen(context);
                              } else {
                                // 如果不是全屏，退出当前页面
                                Navigator.pop(context);
                              }
                            },
                          ),
                          //标题显示
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                final text =
                    providerContainer
                        .read(watcherControllerProvider)
                        .anime!
                        .title;
                                const style = TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                );

                                final textPainter = TextPainter(
                                  text: TextSpan(text: text, style: style),
                                  maxLines: 1,
                                  textDirection: TextDirection.ltr,
                                )..layout(maxWidth: constraints.maxWidth);

                                final shouldScroll =
                                    textPainter.width >=
                                    constraints.maxWidth - 30;

                                return SizedBox(
                                  height: 24,
                                  child: ClipRect(
                                    child: shouldScroll
                                        ? Marquee(
                                            text: text,
                                            style: style,
                                            scrollAxis: Axis.horizontal,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
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
                            ),
                          ),
                          if (playerController.isFullScreen) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Utils.buildTimeIcon(
                                    playerController.currentTime,
                                  ),
                                  const SizedBox(width: 6),
                                  //时间
                                  StreamBuilder<String>(
                                    stream: playerController.timeStream,
                                    initialData: playerController.formatNow(),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? '--:--:--',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: Theme.of(
                                            context,
                                          ).textTheme.titleMedium!.fontSize,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 1,
                                    height: 12,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(width: 8),
                                  //电池
                                  BatteryWidget(),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 1,
                                    height: 12,
                                    color: Colors.white24,
                                  ),
                                  const SizedBox(width: 8),
                                  NetworkStatusWidget(),
                                  const SizedBox(width: 6),
                                  //安卓流量速度显示
                                  (App.isAndroid)
                                      ? SizedBox(
                                          width: 32,
                                          child: SpeedMonitorWidget(),
                                        )
                                      : Container(),
                                  (App.isAndroid)
                                      ? const SizedBox(width: 8)
                                      : Container(),
                                ],
                              ),
                            ),
                          ],
                          //倍数状态条
                          TextButton(
                            style: ButtonStyle(
                              padding: WidgetStateProperty.all(EdgeInsets.zero),
                            ),
                            onPressed: () {
                              if (playerController.playbackSpeed < 2) {
                                playerController.setPlaybackSpeed(2);
                              } else {
                                playerController.setPlaybackSpeed(1);
                              }
                            },
                            child: Text(
                              '${playerController.playbackSpeed}X',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (!playerController.isFullScreen)
                            widget.buildMenuItems,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 自定义播放器底部组件
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: IgnorePointer(
                  ignoring: !playerController.showVideoController,
                  child: MouseRegion(
                    cursor:
                        (playerController.isFullScreen &&
                            widget.animationController.value == 0)
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onEnter: (_) {
                      widget.cancelHideTimer();
                    },
                    onExit: (_) {
                      widget.cancelHideTimer();
                      widget.startHideTimer();
                    },
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(width: 10),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: playerController.isFullScreen
                                    ? 16
                                    : 8,
                                vertical: playerController.isFullScreen ? 6 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: SizedBox(
                                height: playerController.isFullScreen ? 24 : 20,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    playerController
                                                .currentSetName
                                                .characters
                                                .length >
                                            12
                                        ? '${playerController.currentSetName.characters.take(12)}...'
                                        : playerController.currentSetName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: playerController.isFullScreen
                                          ? 16
                                          : 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            if (playerController.isFullScreen &&
                                widget.onChatToggle != null &&
                                !playerController.chatOverlayOpen)
                              Expanded(
                                child: _QuickChatInput(
                                  onFocusChanged: _onQuickChatFocusChanged,
                                ),
                              )
                            else
                              const Spacer(),
                            GestureDetector(
                              // 一起看房间：点击时长一键追上房主
                              onTap: playerController.ownerSyncPositionMs >= 0
                                  ? playerController.onSyncToOwner
                                  : null,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: playerController.isFullScreen
                                      ? 16
                                      : 8,
                                  vertical: playerController.isFullScreen
                                      ? 6
                                      : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 房主暂停提示图标
                                    if (playerController.ownerSyncPositionMs >=
                                            0 &&
                                        !playerController.ownerSyncPlaying)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: Icon(
                                          Icons.pause_circle_filled,
                                          size: playerController.isFullScreen
                                              ? 16
                                              : 13,
                                          color: const Color(0xFFFFB300),
                                        ),
                                      ),
                                    Text(
                                      "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: playerController.isFullScreen
                                            ? 16
                                            : 12,
                                      ),
                                    ),
                                    if (playerController.ownerSyncPositionMs >=
                                        0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          playerController.ownerSyncDiffText,
                                          style: TextStyle(
                                            color: playerController
                                                .ownerSyncDiffColor(context),
                                            fontWeight: FontWeight.w600,
                                            fontSize:
                                                playerController.isFullScreen
                                                ? 14
                                                : 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              color: Colors.white,
                              icon: AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  playerController.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  key: ValueKey<bool>(playerController.playing),
                                ),
                              ),
                              onPressed: () {
                                if (playerController.playing) {
                                  playerController.pause();
                                } else {
                                  playerController.play();
                                }
                              },
                            ),
                            // 更换选集
                            (playerController.isFullScreen)
                                ? IconButton(
                                    color: Colors.white,
                                    icon: const Icon(Icons.skip_next),
                                    onPressed: () async {
                                      playerController.pause();
                                      await playerController.playNextEpisode();
                                    },
                                  )
                                : Container(),
                            // 音量滑条（桌面端）
                            if (App.isDesktop)
                              Builder(
                                builder: (buttonContext) {
                                  return IconButton(
                                    color: Colors.white,
                                    icon: Icon(
                                      playerController.volume <= 0
                                          ? Icons.volume_off
                                          : playerController.volume <
                                                playerController
                                                        .volumeUpperBound /
                                                    2
                                          ? Icons.volume_down
                                          : Icons.volume_up,
                                    ),
                                    tooltip: t.volume,
                                    onPressed: () {
                                      final renderBox =
                                          buttonContext.findRenderObject()
                                              as RenderBox;
                                      final offset = renderBox.localToGlobal(
                                        Offset.zero,
                                      );
                                      showVolumeSliderPopup(
                                        buttonContext,
                                        offset,
                                        playerController,
                                      );
                                    },
                                  );
                                },
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
                                progress: playerController.currentPosition,
                                buffered: playerController.buffer,
                                total: playerController.duration,
                                onSeek: (duration) {
                                  playerController.seek(duration);
                                },
                                onDragStart: (details) {
                                  widget.handleProgressBarDragStart(details);
                                },
                                onDragUpdate: (details) => {
                                  playerController.currentPosition =
                                      details.timeStamp,
                                },
                                onDragEnd: () {
                                  widget.handleProgressBarDragEnd();
                                },
                              ),
                            ),
                            (playerController.isFullScreen &&
                                    playerController.inRoom)
                                ? IconButton(
                                    color: Colors.white,
                                    icon: const Icon(Icons.subtitles_outlined),
                                    tooltip: t.danmaku,
                                    onPressed: () {
                                      showDanmakuSettingsDialog(context);
                                    },
                                  )
                                : Container(),
                            (playerController.isFullScreen &&
                                    playerController.inRoom)
                                ? IconButton(
                                    color: Colors.white,
                                    icon: const Icon(Icons.chat_bubble_outline),
                                    onPressed: widget.onChatToggle,
                                  )
                                : Container(),
                            (playerController.isFullScreen)
                                ? IconButton(
                                    color: Colors.white,
                                    onPressed: () {
                                      playerController.showTabBody =
                                          !playerController.showTabBody;
                                      widget.openMenu();
                                    },
                                    icon: Icon(
                                      playerController.showTabBody
                                          ? Icons.menu_open
                                          : Icons.menu_open_outlined,
                                    ),
                                  )
                                : Container(),

                            // 音轨选择（源脚本提供媒体信息时显示）
                            if ((playerController
                                        .playResult
                                        ?.audioTracks
                                        .length ??
                                    0) >
                                1)
                              PopupMenuButton<int>(
                                color: Colors.white,
                                tooltip: t.audioTrack,
                                onSelected: (i) =>
                                    playerController.setAudioTrack(i),
                                itemBuilder: (_) => playerController
                                    .playResult!
                                    .audioTracks
                                    .map(
                                      (tr) => PopupMenuItem(
                                        value: tr.index,
                                        child: Text(tr.displayTitle),
                                      ),
                                    )
                                    .toList(),
                                child: Icon(
                                  Icons.audiotrack,
                                  color: Colors.white,
                                ),
                              ),
                            // 字幕选择
                            if ((playerController
                                        .playResult
                                        ?.subtitleTracks
                                        .isNotEmpty ??
                                    false))
                              PopupMenuButton<int>(
                                color: Colors.white,
                                tooltip: t.subtitle,
                                onSelected: (i) =>
                                    playerController.setSubtitleTrack(i),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: -1,
                                    child: Text(t.subtitleOff),
                                  ),
                                  ...playerController.playResult!.subtitleTracks
                                      .map(
                                        (tr) => PopupMenuItem(
                                          value: tr.index,
                                          child: Text(tr.displayTitle),
                                        ),
                                      ),
                                ],
                                child: Icon(
                                  Icons.subtitles,
                                  color: Colors.white,
                                ),
                              ),

                            if (App.isAndroid && !playerController.isFullScreen)
                              IconButton(
                                color: Colors.white,
                                icon: Icon(
                                  playerController.isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.crop_portrait,
                                ),
                                onPressed: () {
                                  playerController.toggleFullScreen(
                                    context,
                                    isPortraitFullScreen: true,
                                  );
                                },
                              ),

                            // 清晰度切换（源提供多清晰度时显示）
                            if ((playerController
                                        .playResult
                                        ?.videoStreams
                                        ?.length ??
                                    0) >
                                1)
                              PopupMenuButton<VideoStreamInfo>(
                                color: Colors.white,
                                tooltip: t.quality,
                                onSelected: (vs) {
                                  final u = vs.url;
                                  if (u != null && u.isNotEmpty) {
                                    playerController.switchQuality(u);
                                  }
                                },
                                itemBuilder: (_) => playerController
                                    .playResult!
                                    .videoStreams!
                                    .map(
                                      (vs) => PopupMenuItem(
                                        value: vs,
                                        child: Text(vs.label),
                                      ),
                                    )
                                    .toList(),
                                child: Icon(
                                  Icons.high_quality_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            IconButton(
                              color: Colors.white,
                              icon: Icon(
                                playerController.isFullScreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                              ),
                              onPressed: () {
                                playerController.toggleFullScreen(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 全屏一起看底部快捷输入框：发送消息到当前房间
class _QuickChatInput extends ConsumerStatefulWidget {
  final void Function(bool hasFocus) onFocusChanged;
  const _QuickChatInput({required this.onFocusChanged});

  @override
  ConsumerState<_QuickChatInput> createState() => _QuickChatInputState();
}

class _QuickChatInputState extends ConsumerState<_QuickChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    widget.onFocusChanged(_focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final hub = ref.read(hubProvider);
    final roomId = hub.currentRoomId;
    final inRoom =
        hub.isConnected && roomId != null && roomId != hub.lobbyRoomId;
    if (!inRoom) return;
    ref.read(hubClientProvider).broadcast([TextSegment(text)]);
    _controller.clear();
    // 保持焦点，便于连续发送弹幕
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 仅在已连接且位于非大厅房间时可用（发送到当前一起看房间）
    final hub = ref.watch(hubProvider);
    final roomId = hub.currentRoomId;
    final inRoom =
        hub.isConnected && roomId != null && roomId != hub.lobbyRoomId;
    if (!inRoom) return const SizedBox.shrink();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      // 跟随软键盘上移，避免输入法遮挡输入框
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 12, right: 2),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.toOpacity(0.4), width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                // 点击输入框外部时取消焦点，避免"没点输入框却在打字"
                onTapOutside: (_) => _focusNode.unfocus(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t.message,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.white.toOpacity(0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            IconButton(
              color: Colors.white,
              visualDensity: VisualDensity.compact,
              tooltip: t.sendMessage,
              icon: const Icon(Icons.send_rounded, size: 18),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}
