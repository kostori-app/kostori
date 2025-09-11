import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/player_item_panel.dart';
import 'package:kostori/pages/watcher/player_item_surface.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

class PlayerItem extends StatefulWidget {
  final PlayerController playerController;

  final VoidCallback openMenu;

  final VoidCallback locateEpisode;
  final FocusNode keyboardFocus;

  const PlayerItem({
    super.key,
    required this.playerController,
    required this.openMenu,
    required this.locateEpisode,
    required this.keyboardFocus,
  });

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with
        WindowListener,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  // 过渡动画
  late AnimationController? animationController;

  PlayerController get playerController => widget.playerController;

  Timer? hideTimer;
  Timer? mouseScrollerTimer;
  Timer? hideVolumeUITimer;
  Timer? timer;

  String formattedTime = '';

  int? hoveredIndex;

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(
        value,
      );
    } catch (_) {}
  }

  Future<void> increaseVolume() async {
    await playerController.setVolume(playerController.volume + 10);
  }

  Future<void> decreaseVolume() async {
    await playerController.setVolume(playerController.volume - 10);
  }

  void displayVideoController() {
    animationController?.forward();
    hideTimer?.cancel();
    startHideTimer();
    playerController.showVideoController = true;
  }

  void hideVideoController() {
    animationController?.reverse();
    hideTimer?.cancel();
    playerController.showVideoController = false;
  }

  void _handleTap() {
    if (playerController.showVideoController) {
      hideVideoController();
    } else {
      displayVideoController();
    }
  }

  void _handleDoubleTap() {
    playerController.playOrPause();
  }

  void _handleHove() {
    if (!playerController.showVideoController) {
      displayVideoController();
    }
    hideTimer?.cancel();
    startHideTimer();
  }

  void _handleMouseScroller() {
    playerController.showVolume = true;
    mouseScrollerTimer?.cancel();
    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.showVolume = false;
      }
      mouseScrollerTimer = null;
    });
  }

  void startHideTimer() {
    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && playerController.canHidePlayerPanel) {
        playerController.showVideoController = false;
        animationController?.reverse();
      }
      hideTimer = null;
    });
  }

  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  void handleProgressBarDragStart(ThumbDragDetails details) {
    playerController.playerTimer?.cancel();
    playerController.pause();
    hideTimer?.cancel();
    playerController.showVideoController = true;
    // _showPreview(details.timeStamp);
  }

  void handleProgressBarDragEnd() {
    playerController.play();
    startHideTimer();
    playerController.playerTimer = playerController.getPlayerTimer();
    // _hidePreview();
  }

  void _handleKeyChangingVolume() {
    playerController.showVolume = true;
    hideVolumeUITimer?.cancel();
    hideVolumeUITimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        playerController.showVolume = false;
      }
      hideVolumeUITimer = null;
    });
  }

  void showVideoInfo() {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4, // 设置最大高度
        maxWidth: MediaQuery.of(context).size.width <= 600
            ? MediaQuery.of(context).size.width
            : (App.isDesktop)
            ? MediaQuery.of(context).size.width *
                  9 /
                  16 // 设置最大宽度
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (_) => VideoInfoSheet(playerController: playerController),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    windowManager.addListener(this);
    displayVideoController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    hideTimer?.cancel();
    mouseScrollerTimer?.cancel();
    hideVolumeUITimer?.cancel();
    animationController?.dispose();
    animationController = null;
    playerController.showVideoController = true;
    playerController.showSeekTime = false;
    playerController.showBrightness = false;
    playerController.showVolume = false;
    playerController.showPlaySpeed = false;
    playerController.brightnessSeeking = false;
    playerController.volumeSeeking = false;
    playerController.canHidePlayerPanel = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return ClipRect(
          child: Container(
            color: Colors.black,
            child: MouseRegion(
              cursor:
                  (playerController.isFullScreen &&
                      !playerController.showVideoController)
                  ? SystemMouseCursors.none
                  : SystemMouseCursors.basic,
              onHover: (PointerEvent pointerEvent) {
                // workaround for android.
                // I don't know why, but android tap event will trigger onHover event.
                if (App.isDesktop) {
                  if (pointerEvent.position.dy > 50 &&
                      pointerEvent.position.dy <
                          MediaQuery.of(context).size.height - 70) {
                    _handleHove();
                  } else {
                    if (!playerController.showVideoController) {
                      animationController?.forward();
                      playerController.showVideoController = true;
                    }
                  }
                }
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  //滚轮调节音量
                  if (playerController.isFullScreen) {
                    if (pointerSignal is PointerScrollEvent) {
                      _handleMouseScroller();
                      final scrollDelta = pointerSignal.scrollDelta;
                      final double volume =
                          playerController.volume - scrollDelta.dy / 60;
                      playerController.setVolume(volume);
                    }
                  }
                },
                child: SizedBox(
                  height: playerController.isFullScreen
                      ? (MediaQuery.of(context).size.height)
                      : (MediaQuery.of(context).size.width * 9.0 / 16.0),
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (App.isDesktop)
                        Center(
                          child: Focus(
                            focusNode: widget.keyboardFocus,
                            autofocus: App.isDesktop,
                            onKeyEvent: (focusNode, KeyEvent event) {
                              if (event is KeyDownEvent) {
                                // 空格键处理
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.space) {
                                  try {
                                    playerController.playOrPause();
                                    return KeyEventResult.handled; // 明确返回值
                                  } catch (e) {
                                    Log.addLog(
                                      LogLevel.error,
                                      '播放器内部错误',
                                      e.toString(),
                                    );
                                    return KeyEventResult.ignored;
                                  }
                                }
                                // 右方向键处理
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  try {
                                    if (playerController.playerTimer != null) {
                                      playerController.playerTimer!.cancel();
                                    }
                                    playerController.currentPosition = Duration(
                                      seconds:
                                          playerController
                                              .currentPosition
                                              .inSeconds +
                                          10,
                                    );
                                    playerController.seek(
                                      playerController.currentPosition,
                                    );
                                    playerController.playerTimer =
                                        playerController.getPlayerTimer();
                                    return KeyEventResult.handled;
                                  } catch (e) {
                                    Log.addLog(
                                      LogLevel.error,
                                      '播放器内部错误',
                                      e.toString(),
                                    );
                                    return KeyEventResult.ignored;
                                  }
                                }

                                // 左方向键处理
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowLeft) {
                                  int targetPosition =
                                      playerController
                                          .currentPosition
                                          .inSeconds -
                                      10;
                                  if (targetPosition < 0) {
                                    targetPosition = 0;
                                  }
                                  try {
                                    if (playerController.playerTimer != null) {
                                      playerController.playerTimer!.cancel();
                                    }
                                    playerController.currentPosition = Duration(
                                      seconds: targetPosition,
                                    );
                                    playerController.seek(
                                      playerController.currentPosition,
                                    );
                                    playerController.playerTimer =
                                        playerController.getPlayerTimer();
                                    return KeyEventResult.handled;
                                  } catch (e) {
                                    Log.addLog(
                                      LogLevel.error,
                                      '左方向键被按下',
                                      e.toString(),
                                    );
                                    return KeyEventResult.ignored;
                                  }
                                }
                                // 上方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  increaseVolume();
                                  _handleKeyChangingVolume();
                                }
                                // 下方向键被按下
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  decreaseVolume();
                                  _handleKeyChangingVolume();
                                }
                                // Esc键处理
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                                  if (playerController.isFullScreen) {
                                    playerController.toggleFullScreen(context);
                                    return KeyEventResult.handled;
                                  }
                                }

                                // F键处理
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.keyF) {
                                  playerController.toggleFullScreen(context);
                                  return KeyEventResult.handled;
                                }
                              } else if (event is KeyRepeatEvent) {
                                // 右方向键长按
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  if (playerController.playbackSpeed <
                                      playerController.playbackSpeed * 2) {
                                    if (!playerController.showPlaySpeed) {
                                      playerController.showPlaySpeed = true;
                                      playerController.setPlaybackSpeed(
                                        playerController.playbackSpeed * 2,
                                      );
                                    }
                                  }
                                }
                              } else if (event is KeyUpEvent) {
                                // 右方向键抬起
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowRight) {
                                  if (playerController.showPlaySpeed) {
                                    playerController.showPlaySpeed = false;
                                    playerController.setPlaybackSpeed(
                                      playerController.playbackSpeed / 2,
                                    );
                                  } else {
                                    try {
                                      playerController.playerTimer?.cancel();
                                      playerController.seek(
                                        Duration(
                                          seconds:
                                              playerController
                                                  .currentPosition
                                                  .inSeconds +
                                              10,
                                        ),
                                      );
                                      playerController.playerTimer =
                                          playerController.getPlayerTimer();
                                    } catch (e) {
                                      Log.addLog(
                                        LogLevel.error,
                                        '播放器内部错误',
                                        e.toString(),
                                      );
                                    }
                                  }
                                }
                              }
                              return KeyEventResult.handled;
                            },
                            child: PlayerItemSurface(
                              playerController: playerController,
                            ),
                          ),
                        )
                      else
                        Center(
                          child: PlayerItemSurface(
                            playerController: playerController,
                          ),
                        ),
                      GestureDetector(
                        onTap: () {
                          _handleTap();
                        },
                        onDoubleTap: () {
                          _handleDoubleTap();
                        },
                        onLongPressStart: (_) {
                          setState(() {
                            playerController.showPlaySpeed = true;
                          });
                          playerController.setPlaybackSpeed(
                            playerController.playbackSpeed * 2,
                          );
                        },
                        onLongPressEnd: (_) {
                          setState(() {
                            playerController.showPlaySpeed = false;
                          });
                          playerController.setPlaybackSpeed(
                            playerController.playbackSpeed / 2,
                          );
                        },
                        child: Container(
                          color: Colors.transparent,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      PlayerItemPanel(
                        openMenu: widget.openMenu,
                        handleProgressBarDragStart: handleProgressBarDragStart,
                        handleProgressBarDragEnd: handleProgressBarDragEnd,
                        animationController: animationController!,
                        startHideTimer: startHideTimer,
                        cancelHideTimer: cancelHideTimer,
                        showVideoInfo: showVideoInfo,
                        playerController: playerController,
                      ),
                      // / 播放器手势控制
                      Positioned.fill(
                        left: 16,
                        top: 25,
                        right: 15,
                        bottom: 15,
                        child: GestureDetector(
                          onHorizontalDragStart: (_) {
                            if (playerController.showVideoController) {
                              animationController?.reverse();
                            }

                            playerController.isSeek = true;
                          },
                          onHorizontalDragUpdate: (DragUpdateDetails details) {
                            playerController.showSeekTime = true;
                            playerController.playerTimer?.cancel();
                            playerController.pause();
                            final double scale =
                                180000 / MediaQuery.sizeOf(context).width;
                            int ms =
                                (playerController
                                            .currentPosition
                                            .inMilliseconds +
                                        (details.delta.dx * scale).round())
                                    .clamp(
                                      0,
                                      playerController.duration.inMilliseconds,
                                    );
                            playerController.currentPosition = Duration(
                              milliseconds: ms,
                            );
                          },
                          onHorizontalDragEnd: (_) {
                            playerController.play();
                            playerController.seek(
                              playerController.currentPosition,
                            );
                            playerController.isSeek = false;
                            playerController.playerTimer?.cancel();
                            playerController.playerTimer = playerController
                                .getPlayerTimer();
                            playerController.showSeekTime = false;
                          },
                          onVerticalDragUpdate:
                              (DragUpdateDetails details) async {
                                final double totalWidth = MediaQuery.sizeOf(
                                  context,
                                ).width;
                                final double totalHeight = MediaQuery.sizeOf(
                                  context,
                                ).height;
                                final double tapPosition =
                                    details.localPosition.dx;
                                final double sectionWidth = totalWidth / 2;
                                final double delta = details.delta.dy;

                                if (tapPosition < sectionWidth) {
                                  // 左边区域
                                  playerController.brightnessSeeking = true;
                                  playerController.showBrightness = true;
                                  final double level = (totalHeight) * 2;
                                  final double brightness =
                                      playerController.brightness -
                                      delta / level;
                                  final double result = brightness.clamp(
                                    0.0,
                                    1.0,
                                  );
                                  setBrightness(result);
                                  playerController.brightness = result;
                                } else {
                                  // 右边区域
                                  playerController.volumeSeeking = true;
                                  playerController.showVolume = true;
                                  final double level = (totalHeight) * 0.03;
                                  final double volume =
                                      playerController.volume - delta / level;
                                  playerController.setVolume(volume);
                                }
                              },
                          onVerticalDragEnd: (_) {
                            if (playerController.volumeSeeking) {
                              playerController.volumeSeeking = false;
                              Future.delayed(const Duration(seconds: 1), () {
                                FlutterVolumeController.updateShowSystemUI(
                                  true,
                                );
                              });
                            }
                            if (playerController.brightnessSeeking) {
                              playerController.brightnessSeeking = false;
                            }
                            playerController.showVolume = false;
                            playerController.showBrightness = false;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
