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
import 'package:kostori/utils/utils.dart';
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
    await widget.playerController.setVolume(
      widget.playerController.volume + 10,
    );
  }

  Future<void> decreaseVolume() async {
    await widget.playerController.setVolume(
      widget.playerController.volume - 10,
    );
  }

  void displayVideoController() {
    animationController?.forward();
    hideTimer?.cancel();
    startHideTimer();
    widget.playerController.showVideoController = true;
  }

  void hideVideoController() {
    animationController?.reverse();
    hideTimer?.cancel();
    widget.playerController.showVideoController = false;
  }

  void _handleTap() {
    if (widget.playerController.showVideoController) {
      hideVideoController();
    } else {
      displayVideoController();
    }
  }

  void _handleDoubleTap() {
    widget.playerController.playOrPause();
  }

  void _handleHove() {
    if (!widget.playerController.showVideoController) {
      displayVideoController();
    }
    hideTimer?.cancel();
    startHideTimer();
  }

  void _handleMouseScroller() {
    widget.playerController.showVolume = true;
    mouseScrollerTimer?.cancel();
    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        widget.playerController.showVolume = false;
      }
      mouseScrollerTimer = null;
    });
  }

  void startHideTimer() {
    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.playerController.canHidePlayerPanel) {
        widget.playerController.showVideoController = false;
        animationController?.reverse();
      }
      hideTimer = null;
    });
  }

  void cancelHideTimer() {
    hideTimer?.cancel();
  }

  void handleProgressBarDragStart(ThumbDragDetails details) {
    widget.playerController.playerTimer?.cancel();
    widget.playerController.pause();
    hideTimer?.cancel();
    widget.playerController.showVideoController = true;
    // _showPreview(details.timeStamp);
  }

  void handleProgressBarDragEnd() {
    widget.playerController.play();
    startHideTimer();
    widget.playerController.playerTimer = widget.playerController
        .getPlayerTimer();
    // _hidePreview();
  }

  void _handleKeyChangingVolume() {
    widget.playerController.showVolume = true;
    hideVolumeUITimer?.cancel();
    hideVolumeUITimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        widget.playerController.showVolume = false;
      }
      hideVolumeUITimer = null;
    });
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
    widget.playerController.showVideoController = true;
    widget.playerController.showSeekTime = false;
    widget.playerController.showBrightness = false;
    widget.playerController.showVolume = false;
    widget.playerController.showPlaySpeed = false;
    widget.playerController.brightnessSeeking = false;
    widget.playerController.volumeSeeking = false;
    widget.playerController.canHidePlayerPanel = true;
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
                  (widget.playerController.isFullScreen &&
                      !widget.playerController.showVideoController)
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
                    if (!widget.playerController.showVideoController) {
                      animationController?.forward();
                      widget.playerController.showVideoController = true;
                    }
                  }
                }
              },
              child: Listener(
                onPointerSignal: (pointerSignal) {
                  //滚轮调节音量
                  if (widget.playerController.isFullScreen) {
                    if (pointerSignal is PointerScrollEvent) {
                      _handleMouseScroller();
                      final scrollDelta = pointerSignal.scrollDelta;
                      final double volume =
                          widget.playerController.volume - scrollDelta.dy / 60;
                      widget.playerController.setVolume(volume);
                    }
                  }
                },
                child: SizedBox(
                  height: widget.playerController.isFullScreen
                      ? (MediaQuery.of(context).size.height)
                      : (MediaQuery.of(context).size.width * 9.0 / (16.0)),
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Focus(
                          focusNode: Utils.isDesktop()
                              ? widget.keyboardFocus
                              : null,
                          autofocus: Utils.isDesktop(),
                          onKeyEvent: (focusNode, KeyEvent event) {
                            if (event is KeyDownEvent) {
                              // 空格键处理
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.space) {
                                try {
                                  widget.playerController.playOrPause();
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
                                  if (widget.playerController.playerTimer !=
                                      null) {
                                    widget.playerController.playerTimer!
                                        .cancel();
                                  }
                                  widget.playerController.currentPosition =
                                      Duration(
                                        seconds:
                                            widget
                                                .playerController
                                                .currentPosition
                                                .inSeconds +
                                            10,
                                      );
                                  widget.playerController.seek(
                                    widget.playerController.currentPosition,
                                  );
                                  widget.playerController.playerTimer = widget
                                      .playerController
                                      .getPlayerTimer();
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
                                    widget
                                        .playerController
                                        .currentPosition
                                        .inSeconds -
                                    10;
                                if (targetPosition < 0) {
                                  targetPosition = 0;
                                }
                                try {
                                  if (widget.playerController.playerTimer !=
                                      null) {
                                    widget.playerController.playerTimer!
                                        .cancel();
                                  }
                                  widget.playerController.currentPosition =
                                      Duration(seconds: targetPosition);
                                  widget.playerController.seek(
                                    widget.playerController.currentPosition,
                                  );
                                  widget.playerController.playerTimer = widget
                                      .playerController
                                      .getPlayerTimer();
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
                                if (widget.playerController.isFullScreen) {
                                  if (App.isDesktop) {
                                    widget.playerController.toggleFullscreen(
                                      context,
                                    );
                                  } else {
                                    widget.playerController.enterFullScreen(
                                      context,
                                    );
                                  }
                                  return KeyEventResult.handled;
                                }
                              }

                              // F键处理
                              if (event.logicalKey == LogicalKeyboardKey.keyF) {
                                if (App.isDesktop) {
                                  widget.playerController.toggleFullscreen(
                                    context,
                                  );
                                } else {
                                  widget.playerController.enterFullScreen(
                                    context,
                                  );
                                }
                                return KeyEventResult.handled;
                              }
                            } else if (event is KeyRepeatEvent) {
                              // 右方向键长按
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight) {
                                if (widget.playerController.playbackSpeed <
                                    widget.playerController.playbackSpeed * 2) {
                                  if (!widget.playerController.showPlaySpeed) {
                                    widget.playerController.showPlaySpeed =
                                        true;
                                    widget.playerController.setPlaybackSpeed(
                                      widget.playerController.playbackSpeed * 2,
                                    );
                                  }
                                }
                              }
                            } else if (event is KeyUpEvent) {
                              // 右方向键抬起
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowRight) {
                                if (widget.playerController.showPlaySpeed) {
                                  widget.playerController.showPlaySpeed = false;
                                  widget.playerController.setPlaybackSpeed(
                                    widget.playerController.playbackSpeed / 2,
                                  );
                                } else {
                                  try {
                                    widget.playerController.playerTimer
                                        ?.cancel();
                                    widget.playerController.seek(
                                      Duration(
                                        seconds:
                                            widget
                                                .playerController
                                                .currentPosition
                                                .inSeconds +
                                            10,
                                      ),
                                    );
                                    widget.playerController.playerTimer = widget
                                        .playerController
                                        .getPlayerTimer();
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
                            playerController: widget.playerController,
                          ),
                        ),
                      ),
                      // widget.playerController.player.state.buffering
                      //     ? const Positioned.fill(
                      //         child: Center(
                      //           child: CircularProgressIndicator(),
                      //         ),
                      //       )
                      //     : Container(),
                      GestureDetector(
                        onTap: () {
                          _handleTap();
                        },
                        onDoubleTap: () {
                          _handleDoubleTap();
                        },
                        onLongPressStart: (_) {
                          setState(() {
                            widget.playerController.showPlaySpeed = true;
                          });
                          widget.playerController.setPlaybackSpeed(
                            widget.playerController.playbackSpeed * 2,
                          );
                        },
                        onLongPressEnd: (_) {
                          setState(() {
                            widget.playerController.showPlaySpeed = false;
                          });
                          widget.playerController.setPlaybackSpeed(
                            widget.playerController.playbackSpeed / 2,
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
                        keyboardFocus: widget.keyboardFocus,
                        startHideTimer: startHideTimer,
                        cancelHideTimer: cancelHideTimer,
                        playerController: widget.playerController,
                      ),
                      // / 播放器手势控制
                      Positioned.fill(
                        left: 16,
                        top: 25,
                        right: 15,
                        bottom: 15,
                        child: GestureDetector(
                          onHorizontalDragStart: (_) {
                            if (!widget.playerController.showVideoController) {
                              animationController?.forward();
                            }
                            widget.playerController.canHidePlayerPanel = false;
                            // if (App.isAndroid) {
                            //   _showPreview(Duration(
                            //       seconds: widget
                            //           .playerController
                            //           .player
                            //           .state
                            //           .position
                            //           .inSeconds));
                            // }
                          },
                          onHorizontalDragUpdate: (DragUpdateDetails details) {
                            widget.playerController.showSeekTime = true;
                            widget.playerController.playerTimer?.cancel();
                            widget.playerController.pause();
                            final double scale =
                                180000 / MediaQuery.sizeOf(context).width;
                            int ms =
                                (widget
                                            .playerController
                                            .currentPosition
                                            .inMilliseconds +
                                        (details.delta.dx * scale).round())
                                    .clamp(
                                      0,
                                      widget
                                          .playerController
                                          .duration
                                          .inMilliseconds,
                                    );
                            // if (App.isAndroid) {
                            //   _updatePreview(
                            //       Duration(milliseconds: ms));
                            // }
                            widget.playerController.currentPosition = Duration(
                              milliseconds: ms,
                            );
                          },
                          onHorizontalDragEnd: (_) {
                            widget.playerController.play();
                            widget.playerController.seek(
                              widget.playerController.currentPosition,
                            );
                            widget.playerController.canHidePlayerPanel = true;
                            if (!widget.playerController.showVideoController) {
                              animationController?.reverse();
                            } else {
                              hideTimer?.cancel();
                              startHideTimer();
                            }
                            widget.playerController.playerTimer = widget
                                .playerController
                                .getPlayerTimer();
                            widget.playerController.showSeekTime = false;
                            // if (App.isAndroid) {
                            //   _hidePreview();
                            // }
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
                                  widget.playerController.brightnessSeeking =
                                      true;
                                  widget.playerController.showBrightness = true;
                                  final double level = (totalHeight) * 2;
                                  final double brightness =
                                      widget.playerController.brightness -
                                      delta / level;
                                  final double result = brightness.clamp(
                                    0.0,
                                    1.0,
                                  );
                                  setBrightness(result);
                                  widget.playerController.brightness = result;
                                } else {
                                  // 右边区域
                                  widget.playerController.volumeSeeking = true;
                                  widget.playerController.showVolume = true;
                                  final double level = (totalHeight) * 0.03;
                                  final double volume =
                                      widget.playerController.volume -
                                      delta / level;
                                  widget.playerController.setVolume(volume);
                                }
                              },
                          onVerticalDragEnd: (_) {
                            if (widget.playerController.volumeSeeking) {
                              widget.playerController.volumeSeeking = false;
                              Future.delayed(const Duration(seconds: 1), () {
                                FlutterVolumeController.updateShowSystemUI(
                                  true,
                                );
                              });
                            }
                            if (widget.playerController.brightnessSeeking) {
                              widget.playerController.brightnessSeeking = false;
                            }
                            widget.playerController.showVolume = false;
                            widget.playerController.showBrightness = false;
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
