import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/system_status_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';

class PlayerItemPortraitPanel extends StatefulWidget {
  const PlayerItemPortraitPanel({
    super.key,
    required this.playerController,
    required this.openMenu,
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
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final AnimationController animationController;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() showVideoInfo;
  final MenuButton buildMenuItems;

  @override
  State<PlayerItemPortraitPanel> createState() =>
      _PlayerItemPortraitPanelState();
}

class _PlayerItemPortraitPanelState extends State<PlayerItemPortraitPanel> {
  PlayerController get playerController => widget.playerController;
  late final Animation<double> fadeAnimation;
  final TextEditingController textController = TextEditingController();

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
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 0,
                            right: 10,
                            top: MediaQuery.of(context).padding.top,
                          ),
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
                              //标题集数显示
                              (playerController.isFullScreen)
                                  ? Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final text =
                                              '${WatcherState.currentState!.anime.title} ${playerController.currentSetName}';
                                          const style = TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          );

                                          final textPainter =
                                              TextPainter(
                                                text: TextSpan(
                                                  text: text,
                                                  style: style,
                                                ),
                                                maxLines: 1,
                                                textDirection:
                                                    TextDirection.ltr,
                                              )..layout(
                                                maxWidth: constraints.maxWidth,
                                              );

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
                                                      scrollAxis:
                                                          Axis.horizontal,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      blankSpace: 10.0,
                                                      velocity: 40.0,
                                                      pauseAfterRound:
                                                          Duration.zero,
                                                      startPadding: 10.0,
                                                      accelerationDuration:
                                                          Duration.zero,
                                                      decelerationDuration:
                                                          Duration.zero,
                                                    )
                                                  : Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        text,
                                                        style: style,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final text =
                                              playerController.currentSetName;
                                          const style = TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          );

                                          final textPainter =
                                              TextPainter(
                                                text: TextSpan(
                                                  text: text,
                                                  style: style,
                                                ),
                                                maxLines: 1,
                                                textDirection:
                                                    TextDirection.ltr,
                                              )..layout(
                                                maxWidth: constraints.maxWidth,
                                              );

                                          final shouldScroll =
                                              textPainter.width >=
                                              constraints.maxWidth - 20;

                                          return SizedBox(
                                            height: 24,
                                            child: ClipRect(
                                              child: shouldScroll
                                                  ? Marquee(
                                                      text: text,
                                                      style: style,
                                                      scrollAxis:
                                                          Axis.horizontal,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      blankSpace: 10.0,
                                                      velocity: 40.0,
                                                      pauseAfterRound:
                                                          Duration.zero,
                                                      startPadding: 10.0,
                                                      accelerationDuration:
                                                          Duration.zero,
                                                      decelerationDuration:
                                                          Duration.zero,
                                                    )
                                                  : Align(
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        text,
                                                        style: style,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
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
                                        initialData: playerController
                                            .formatNow(),
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
                                  padding: WidgetStateProperty.all(
                                    EdgeInsets.zero,
                                  ),
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
                            ],
                          ),
                        ),
                      ],
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        Padding(
                          padding: const EdgeInsetsGeometry.symmetric(
                            horizontal: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.only(left: 10.0),
                                child: Text(
                                  "${Utils.durationToString(playerController.currentPosition)} / ${Utils.durationToString(playerController.duration)}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.0,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.fit_screen,
                                  color: Colors.white,
                                ),
                                onPressed: () async {
                                  await playerController
                                      .captureAndSaveScreenshot(
                                        context: context,
                                      );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh, color: Colors.white),
                                onPressed: () {
                                  playerController.seek(
                                    playerController.currentPosition +
                                        Duration(seconds: 80),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsGeometry.symmetric(
                            horizontal: 10,
                          ),
                          child: Row(
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
                                    key: ValueKey<bool>(
                                      playerController.playing,
                                    ),
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
                              IconButton(
                                color: Colors.white,
                                icon: const Icon(Icons.skip_next),
                                onPressed: () {
                                  // if (playerController.loading) {
                                  //   return;
                                  // }
                                  playerController.pause();
                                  playerController.playNextEpisode();
                                },
                              ),
                              const Spacer(),
                              IconButton(
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
                              ),
                              if (App.isAndroid &&
                                  !playerController.isFullScreen)
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
