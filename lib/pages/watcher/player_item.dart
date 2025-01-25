import 'dart:async';
import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:kostori/utils/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:window_manager/window_manager.dart';

class PlayerItem extends StatefulWidget {
  final PlayerController playerController;

  final AnimeDetails anime;

  final VoidCallback openMenu;

  final VoidCallback locateEpisode;

  const PlayerItem(
      {super.key,
      required this.playerController,
      required this.anime,
      required this.openMenu,
      required this.locateEpisode});

  @override
  State<PlayerItem> createState() => _PlayerItemState();
}

class _PlayerItemState extends State<PlayerItem>
    with
        WindowListener,
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin {
  // 界面管理
  bool showPositioned = false;
  bool showPosition = false;
  bool showBrightness = false;
  bool showVolume = false;
  bool showPlaySpeed = false;
  bool showTabBody = true;
  bool brightnessSeeking = false;
  bool volumeSeeking = false;
  bool lockPanel = false;

  // 过渡动画
  late AnimationController _animationController;
  late Animation<Offset> _bottomOffsetAnimation;
  late Animation<Offset> _topOffsetAnimation;
  late Animation<Offset> _leftOffsetAnimation;

  Timer? hideTimer;
  Timer? playerTimer;
  Timer? mouseScrollerTimer;
  Timer? timer;

  String formattedTime = '';

  int? hoveredIndex;
  final FocusNode _focusNode = FocusNode();

  Future<void> setVolume(double value) async {
    try {
      FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(value);
    } catch (_) {}
  }

  Future<void> setBrightness(double value) async {
    try {
      await ScreenBrightness().setScreenBrightness(value);
    } catch (_) {}
  }

  void _handleTap() {
    if (!showPositioned) {
      _animationController.forward(); // 开始动画
      if (hideTimer != null) {
        hideTimer!.cancel(); // 如果有定时器，则取消
      }
      hideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            showPositioned = false; // 隐藏渐变区域
          });
          _animationController.reverse(); // 反转动画
        }
        hideTimer = null;
      });
    } else {
      _animationController.reverse(); // 反转动画
      if (hideTimer != null) {
        hideTimer!.cancel(); // 取消隐藏定时器
      }
    }
    setState(() {
      showPositioned = !showPositioned; // 切换状态
    });
  }

  void _handleHove() {
    if (!showPositioned) {
      _animationController.forward();
    }
    setState(() {
      showPositioned = true;
    });
    if (hideTimer != null) {
      hideTimer!.cancel();
    }

    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          showPositioned = false;
        });
        _animationController.reverse();
      }
      hideTimer = null;
    });
  }

  void _handleMouseScroller() {
    setState(() {
      showVolume = true;
    });
    if (mouseScrollerTimer != null) {
      mouseScrollerTimer!.cancel();
    }

    mouseScrollerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          showVolume = false;
        });
      }
      mouseScrollerTimer = null;
    });
  }

  Timer getPlayerTimer() {
    return Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.playerController.playing =
          widget.playerController.player.state.playing;
      widget.playerController.isBuffering =
          widget.playerController.player.state.buffering;
      widget.playerController.currentPosition =
          widget.playerController.player.state.position;
      widget.playerController.buffer =
          widget.playerController.player.state.buffering
              ? Duration.zero
              : widget.playerController.player.state.buffer;
      widget.playerController.duration =
          widget.playerController.player.state.duration;
      widget.playerController.completed =
          widget.playerController.player.state.completed;
      // 音量相关
      if (!volumeSeeking) {
        FlutterVolumeController.getVolume().then((value) {
          widget.playerController.volume = value ?? 0.0;
        });
      }
      // 亮度相关
      if (!App.isWindows &&
          !App.isMacOS &&
          !App.isLinux &&
          !brightnessSeeking) {
        ScreenBrightness().current.then((value) {
          widget.playerController.brightness = value;
        });
      }
    });
  }

  void _handleFullScreen(context) {
    if (widget.playerController.isFullScreen) {
      // 取消已有的定时器
      if (playerTimer != null) {
        playerTimer!.cancel();
      }

      // 统一的退出全屏后重新启动定时器的逻辑
      void onExit() {
        setState(() {
          // playerTimer ??= getPlayerTimer();
        });
      }

      widget.playerController.enterFullScreen(context, onExit: onExit);
    }
  }

  // 将图片保存到相册
  Future<void> _saveImageToGallery(Uint8List imageData) async {
    try {
      // 使用 image_gallery_saver 插件保存图片
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final result = await ImageGallerySaverPlus.saveImage(imageData,
          name: '$widget.playerController.anime.title_$timestamp');
      Log.addLog(LogLevel.info, '图片路径', '$result');
    } on PlatformException catch (e) {
      Log.addLog(LogLevel.error, '图片路径', '$e');
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _leftOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        DateTime now = DateTime.now();
        formattedTime = '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}';
      });
    });
    playerTimer = getPlayerTimer();
    windowManager.addListener(this);
    _handleTap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    if (playerTimer != null) {
      playerTimer!.cancel();
    }
    timer!.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.playerController.isFullScreen,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (playerTimer != null) {
          playerTimer!.cancel();
        }
        _handleFullScreen(context);
      },
      child: Observer(builder: (context) {
        return ClipRect(
            child: Container(
                color: Colors.black,
                child: MouseRegion(
                    cursor: (widget.playerController.isFullScreen &&
                            !showPositioned)
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onHover: (_) {
                      // workaround for android.
                      // I don't know why, but android tap event will trigger onHover event.
                      if (App.isDesktop) {
                        _handleHove();
                      }
                    },
                    child: FocusTraversalGroup(
                        child: FocusScope(
                            node: FocusScopeNode(),
                            child: Listener(
                                onPointerSignal: (pointerSignal) {
                                  //滚轮调节音量
                                  if (widget.playerController.isFullScreen) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      _handleMouseScroller();
                                      final scrollDelta =
                                          pointerSignal.scrollDelta;
                                      final double volume =
                                          widget.playerController.volume -
                                              scrollDelta.dy / 6000;
                                      final double result =
                                          volume.clamp(0.0, 1.0);
                                      setVolume(result);
                                      widget.playerController.volume = result;
                                    }
                                  }
                                },
                                child: KeyboardListener(
                                    autofocus: true,
                                    focusNode: _focusNode,
                                    onKeyEvent: (KeyEvent event) {
                                      if (event is KeyDownEvent) {
                                        _handleHove();
                                        // 当空格键被按下时
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.space) {
                                          try {
                                            widget.playerController
                                                .playOrPause();
                                          } catch (e) {
                                            Log.addLog(LogLevel.error,
                                                '播放器内部错误', e.toString());
                                          }
                                        }
                                        // 右方向键被按下
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.arrowRight) {
                                          try {
                                            if (playerTimer != null) {
                                              playerTimer!.cancel();
                                            }
                                            widget.playerController
                                                    .currentPosition =
                                                Duration(
                                                    seconds: widget
                                                            .playerController
                                                            .currentPosition
                                                            .inSeconds +
                                                        10);
                                            widget.playerController.seek(widget
                                                .playerController
                                                .currentPosition);
                                            playerTimer = getPlayerTimer();
                                          } catch (e) {
                                            Log.addLog(LogLevel.error,
                                                '播放器内部错误', e.toString());
                                          }
                                        }
                                        // 左方向键被按下
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.arrowLeft) {
                                          int targetPosition = widget
                                                  .playerController
                                                  .currentPosition
                                                  .inSeconds -
                                              10;
                                          if (targetPosition < 0) {
                                            targetPosition = 0;
                                          }
                                          try {
                                            if (playerTimer != null) {
                                              playerTimer!.cancel();
                                            }
                                            widget.playerController
                                                    .currentPosition =
                                                Duration(
                                                    seconds: targetPosition);
                                            widget.playerController.seek(widget
                                                .playerController
                                                .currentPosition);
                                            playerTimer = getPlayerTimer();
                                          } catch (e) {
                                            Log.addLog(LogLevel.error,
                                                '左方向键被按下', e.toString());
                                          }
                                        }
                                        // Esc键被按下
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.escape) {
                                          if (widget
                                              .playerController.isFullScreen) {
                                            if (App.isDesktop) {
                                              widget.playerController
                                                  .toggleFullscreen(context);
                                            } else {
                                              widget.playerController
                                                  .enterFullScreen(context);
                                            }
                                          } else {
                                            return;
                                          }
                                        }
                                        // F键被按下
                                        if (event.logicalKey ==
                                            LogicalKeyboardKey.keyF) {
                                          if (App.isDesktop) {
                                            widget.playerController
                                                .toggleFullscreen(context);
                                          } else {
                                            widget.playerController
                                                .enterFullScreen(context);
                                          }
                                        }
                                        // D键盘被按下
                                        // if (event.logicalKey == LogicalKeyboardKey.keyD) {
                                        //   _handleDanmaku();
                                        // }
                                      }
                                    },
                                    child: SizedBox(
                                        height:
                                            widget.playerController.isFullScreen
                                                ? (MediaQuery.of(context)
                                                    .size
                                                    .height)
                                                : (MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    9.0 /
                                                    (16.0)),
                                        width:
                                            MediaQuery.of(context).size.width,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Center(child: playerSurface),
                                              // (widget.playerController.isBuffering || widget.playerController.loading)
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
                                                  if (!showPositioned) {
                                                    _handleTap();
                                                  }
                                                  if (lockPanel) {
                                                    return;
                                                  }
                                                  if (widget.playerController
                                                      .playing) {
                                                    widget.playerController
                                                        .pause();
                                                  } else {
                                                    widget.playerController
                                                        .play();
                                                  }
                                                },
                                                onLongPressStart: (_) {
                                                  if (lockPanel) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    showPlaySpeed = true;
                                                  });
                                                  widget.playerController
                                                      .setPlaybackSpeed(widget
                                                              .playerController
                                                              .playbackSpeed *
                                                          2);
                                                },
                                                onLongPressEnd: (_) {
                                                  if (lockPanel) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    showPlaySpeed = false;
                                                  });
                                                  widget.playerController
                                                      .setPlaybackSpeed(widget
                                                              .playerController
                                                              .playbackSpeed /
                                                          2);
                                                },
                                                child: Container(
                                                  color: Colors.transparent,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
                                              ),

                                              // 顶部渐变半透明区域
                                              AnimatedPositioned(
                                                duration: Duration(seconds: 1),
                                                top: 0,
                                                left: 0,
                                                right: 0,
                                                child: Visibility(
                                                  visible: !lockPanel,
                                                  child: SlideTransition(
                                                    position:
                                                        _topOffsetAnimation,
                                                    child: Container(
                                                      height: 50,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            Colors.black
                                                                .toOpacity(0.9),
                                                            Colors.transparent,
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // 底部渐变半透明区域
                                              AnimatedPositioned(
                                                duration: Duration(seconds: 1),
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Visibility(
                                                  visible: !lockPanel,
                                                  child: SlideTransition(
                                                    position:
                                                        _bottomOffsetAnimation,
                                                    child: Container(
                                                      height: 50,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                          begin: Alignment
                                                              .topCenter,
                                                          end: Alignment
                                                              .bottomCenter,
                                                          colors: [
                                                            Colors.transparent,
                                                            Colors.black
                                                                .toOpacity(0.9),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // / 播放器手势控制
                                              Positioned.fill(
                                                  left: 16,
                                                  top: 25,
                                                  right: 15,
                                                  bottom: 15,
                                                  child: GestureDetector(
                                                      onHorizontalDragUpdate:
                                                          (DragUpdateDetails
                                                              details) {
                                                    setState(() {
                                                      showPosition = true;
                                                      if (playerTimer != null) {
                                                        playerTimer!.cancel();
                                                      }
                                                      widget.playerController
                                                          .pause();
                                                      final double scale =
                                                          180000 /
                                                              MediaQuery.sizeOf(
                                                                      context)
                                                                  .width;
                                                      widget.playerController
                                                              .currentPosition =
                                                          Duration(
                                                              milliseconds: widget
                                                                      .playerController
                                                                      .currentPosition
                                                                      .inMilliseconds +
                                                                  (details.delta
                                                                              .dx *
                                                                          scale)
                                                                      .round());
                                                    });
                                                  }, onHorizontalDragEnd:
                                                          (DragEndDetails
                                                              details) {
                                                    setState(() {
                                                      widget.playerController
                                                          .play();
                                                      widget.playerController
                                                          .seek(widget
                                                              .playerController
                                                              .currentPosition);
                                                      playerTimer =
                                                          getPlayerTimer();
                                                      showPosition = false;
                                                    });
                                                  }, onVerticalDragUpdate:
                                                          (DragUpdateDetails
                                                              details) async {
                                                    final double totalWidth =
                                                        MediaQuery.sizeOf(
                                                                context)
                                                            .width;
                                                    final double totalHeight =
                                                        MediaQuery.sizeOf(
                                                                context)
                                                            .height;
                                                    final double tapPosition =
                                                        details
                                                            .localPosition.dx;
                                                    final double sectionWidth =
                                                        totalWidth / 2;
                                                    final double delta =
                                                        details.delta.dy;

                                                    /// 非全屏时禁用
                                                    if (!widget.playerController
                                                        .isFullScreen) {
                                                      return;
                                                    }
                                                    if (tapPosition <
                                                        sectionWidth) {
                                                      // 左边区域
                                                      brightnessSeeking = true;
                                                      setState(() {
                                                        showBrightness = true;
                                                      });
                                                      final double level =
                                                          (totalHeight) * 2;
                                                      final double brightness =
                                                          widget.playerController
                                                                  .brightness -
                                                              delta / level;
                                                      final double result =
                                                          brightness.clamp(
                                                              0.0, 1.0);
                                                      setBrightness(result);
                                                      widget.playerController
                                                          .brightness = result;
                                                    } else {
                                                      // 右边区域
                                                      volumeSeeking = true;
                                                      setState(() {
                                                        showVolume = true;
                                                      });
                                                      final double level =
                                                          (totalHeight) * 3;
                                                      final double volume =
                                                          widget.playerController
                                                                  .volume -
                                                              delta / level;
                                                      final double result =
                                                          volume.clamp(
                                                              0.0, 1.0);
                                                      setVolume(result);
                                                      widget.playerController
                                                          .volume = result;
                                                    }
                                                  }, onVerticalDragEnd:
                                                          (DragEndDetails
                                                              details) {
                                                    if (volumeSeeking) {
                                                      volumeSeeking = false;
                                                    }
                                                    if (brightnessSeeking) {
                                                      brightnessSeeking = false;
                                                    }
                                                    setState(() {
                                                      showVolume = false;
                                                      showBrightness = false;
                                                    });
                                                  })),
                                              // 顶部进度条
                                              Positioned(
                                                  top: 25,
                                                  child: showPosition
                                                      ? Wrap(
                                                          alignment:
                                                              WrapAlignment
                                                                  .center,
                                                          children: <Widget>[
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .toOpacity(
                                                                        0.5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0), // 圆角
                                                              ),
                                                              child: Text(
                                                                widget.playerController.currentPosition.compareTo(widget
                                                                            .playerController
                                                                            .player
                                                                            .state
                                                                            .position) >
                                                                        0
                                                                    ? '快进 ${widget.playerController.currentPosition.inSeconds - widget.playerController.player.state.position.inSeconds} 秒'
                                                                    : '快退 ${widget.playerController.player.state.position.inSeconds - widget.playerController.currentPosition.inSeconds} 秒',
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : Container()),
                                              // 顶部播放速度条
                                              Positioned(
                                                  top: 25,
                                                  child: showPlaySpeed
                                                      ? Wrap(
                                                          alignment:
                                                              WrapAlignment
                                                                  .center,
                                                          children: <Widget>[
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8.0),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .black
                                                                    .toOpacity(
                                                                        0.5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0), // 圆角
                                                              ),
                                                              child: const Row(
                                                                children: <Widget>[
                                                                  Icon(
                                                                      Icons
                                                                          .fast_forward,
                                                                      color: Colors
                                                                          .white),
                                                                  Text(
                                                                    ' 倍速播放',
                                                                    style:
                                                                        TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : Container()),
                                              // 亮度条
                                              Positioned(
                                                  top: 25,
                                                  child: showBrightness
                                                      ? Wrap(
                                                          alignment:
                                                              WrapAlignment
                                                                  .center,
                                                          children: <Widget>[
                                                            Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        8.0),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .toOpacity(
                                                                          0.5),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8.0), // 圆角
                                                                ),
                                                                child: Row(
                                                                  children: <Widget>[
                                                                    const Icon(
                                                                        Icons
                                                                            .brightness_7,
                                                                        color: Colors
                                                                            .white),
                                                                    Text(
                                                                      ' ${(widget.playerController.brightness * 100).toInt()} %',
                                                                      style:
                                                                          const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : Container()),
                                              // 音量条
                                              Positioned(
                                                  top: 25,
                                                  child: showVolume
                                                      ? Wrap(
                                                          alignment:
                                                              WrapAlignment
                                                                  .center,
                                                          children: <Widget>[
                                                            Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        8.0),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .toOpacity(
                                                                          0.5),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8.0), // 圆角
                                                                ),
                                                                child: Row(
                                                                  children: <Widget>[
                                                                    const Icon(
                                                                        Icons
                                                                            .volume_down,
                                                                        color: Colors
                                                                            .white),
                                                                    Text(
                                                                      ' ${(widget.playerController.volume * 100).toInt()}%',
                                                                      style:
                                                                          const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                )),
                                                          ],
                                                        )
                                                      : Container()),
                                              // 截图
                                              Positioned(
                                                right: 10,
                                                top: 60,
                                                child: SlideTransition(
                                                  position:
                                                      _leftOffsetAnimation,
                                                  child: IconButton(
                                                    icon: Icon(
                                                      Icons.fit_screen,
                                                      color: Colors.white,
                                                    ),
                                                    onPressed: () async {
                                                      if (App.isAndroid) {
                                                        try {
                                                          Uint8List?
                                                              screenData =
                                                              await widget
                                                                  .playerController
                                                                  .player
                                                                  .screenshot();
                                                          _saveImageToGallery(
                                                              screenData!);
                                                          SmartDialog.showNotify(
                                                              msg: '截图成功',
                                                              notifyType:
                                                                  NotifyType
                                                                      .success);
                                                        } catch (e) {
                                                          Log.addLog(
                                                              LogLevel.error,
                                                              '截图失败',
                                                              '$e');
                                                        }
                                                      } else {
                                                        try {
                                                          Uint8List?
                                                              screenData =
                                                              await widget
                                                                  .playerController
                                                                  .player
                                                                  .screenshot();
                                                          // 获取桌面平台的文档目录
                                                          final directory =
                                                              await getApplicationDocumentsDirectory();
                                                          // 目标文件夹路径
                                                          final folderPath =
                                                              '${directory.path}/Screenshots';
                                                          // 检查文件夹是否存在，如果不存在则创建它
                                                          final folder =
                                                              Directory(
                                                                  folderPath);
                                                          if (!await folder
                                                              .exists()) {
                                                            await folder.create(
                                                                recursive:
                                                                    true);
                                                            Log.addLog(
                                                                LogLevel.info,
                                                                '创建截图文件夹成功',
                                                                folderPath);
                                                          } else {
                                                            Log.addLog(
                                                                LogLevel.info,
                                                                '文件夹已存在',
                                                                folderPath);
                                                          }

                                                          final timestamp =
                                                              DateTime.now()
                                                                  .millisecondsSinceEpoch;
                                                          final filePath =
                                                              '$folderPath/anime_image_$timestamp.png';
                                                          // 将图像保存为文件
                                                          final file =
                                                              File(filePath);
                                                          await file
                                                              .writeAsBytes(
                                                                  screenData!);
                                                          SmartDialog.showNotify(
                                                              msg: '截图成功',
                                                              notifyType:
                                                                  NotifyType
                                                                      .success);
                                                        } catch (e) {
                                                          Log.addLog(
                                                              LogLevel.error,
                                                              '截图失败',
                                                              '$e');
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),

                                              // 自定义顶部组件
                                              Positioned(
                                                top: 0,
                                                left: 0,
                                                right: 0,
                                                child: Visibility(
                                                  visible: !lockPanel,
                                                  child: SlideTransition(
                                                    position:
                                                        _topOffsetAnimation,
                                                    child: Row(
                                                      children: [
                                                        IconButton(
                                                          color: Colors.white,
                                                          icon: const Icon(Icons
                                                              .arrow_back_ios_new),
                                                          onPressed: () {
                                                            if (widget
                                                                .playerController
                                                                .isFullScreen) {
                                                              // 如果存在 playerTimer，取消它
                                                              if (playerTimer !=
                                                                  null) {
                                                                playerTimer!
                                                                    .cancel();
                                                              }

                                                              // 检查是否是桌面环境，分别处理全屏逻辑
                                                              if (!App
                                                                  .isDesktop) {
                                                                widget
                                                                    .playerController
                                                                    .enterFullScreen(
                                                                  context,
                                                                  onExit: () {
                                                                    // 在退出全屏后重新启动定时器
                                                                    playerTimer =
                                                                        getPlayerTimer();
                                                                  },
                                                                );
                                                              } else {
                                                                widget
                                                                    .playerController
                                                                    .toggleFullscreen(
                                                                  context,
                                                                  onExit: () {
                                                                    // 在退出全屏后重新启动定时器
                                                                    playerTimer =
                                                                        getPlayerTimer();
                                                                  },
                                                                );
                                                              }
                                                            } else {
                                                              // 如果不是全屏，退出当前页面
                                                              Navigator.pop(
                                                                  context);
                                                            }
                                                          },
                                                        ),
                                                        //标题集数显示
                                                        (widget.playerController
                                                                .isFullScreen)
                                                            ? ValueListenableBuilder<
                                                                String>(
                                                                valueListenable: widget
                                                                    .playerController
                                                                    .currentEpisodeNotifier,
                                                                builder: (context,
                                                                    currentEpisode,
                                                                    child) {
                                                                  return Text(
                                                                    "    $currentEpisode",
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          16,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .right,
                                                                  );
                                                                },
                                                              )
                                                            : Container(),
                                                        // 拖动条
                                                        const Expanded(
                                                          child: dtb
                                                              .DragToMoveArea(
                                                                  child: SizedBox(
                                                                      height:
                                                                          40)),
                                                        ),
                                                        //时间
                                                        (widget.playerController
                                                                .isFullScreen)
                                                            ? Text(
                                                                formattedTime,
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .titleMedium!
                                                                        .fontSize),
                                                              )
                                                            : Container(),
                                                        const SizedBox(
                                                            width: 8),
                                                        //电池
                                                        (widget.playerController
                                                                .isFullScreen)
                                                            ? _BatteryWidget()
                                                            : Container(),
                                                        //倍数状态条
                                                        TextButton(
                                                          style: ButtonStyle(
                                                            padding:
                                                                WidgetStateProperty
                                                                    .all(EdgeInsets
                                                                        .zero),
                                                          ),
                                                          onPressed: () {
                                                            if (widget
                                                                    .playerController
                                                                    .playbackSpeed <
                                                                2) {
                                                              widget
                                                                  .playerController
                                                                  .setPlaybackSpeed(
                                                                      2);
                                                            } else {
                                                              widget
                                                                  .playerController
                                                                  .setPlaybackSpeed(
                                                                      1);
                                                            }
                                                          },
                                                          child: Text(
                                                            '${widget.playerController.playbackSpeed}X',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                        PopupMenuButton(
                                                          tooltip: '',
                                                          icon: const Icon(
                                                            Icons.more_vert,
                                                            color: Colors.white,
                                                          ),
                                                          itemBuilder:
                                                              (context) {
                                                            return [
                                                              PopupMenuItem(
                                                                value: 0,
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text("Copy Title"
                                                                        .tl),
                                                                  ],
                                                                ),
                                                              ),
                                                              PopupMenuItem(
                                                                value: 1,
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text("Copy ID"
                                                                        .tl),
                                                                  ],
                                                                ),
                                                              ),
                                                              PopupMenuItem(
                                                                value: 2,
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                        "Copy URL"
                                                                            .tl)
                                                                  ],
                                                                ),
                                                              ),
                                                            ];
                                                          },
                                                          onSelected: (value) {
                                                            if (value == 0) {
                                                              Clipboard.setData(
                                                                  ClipboardData(
                                                                      text: widget
                                                                          .anime
                                                                          .title));
                                                              context.showMessage(
                                                                  message:
                                                                      "Copied"
                                                                          .tl);
                                                            }
                                                            if (value == 1) {
                                                              Clipboard.setData(
                                                                  ClipboardData(
                                                                      text: widget
                                                                          .anime
                                                                          .id));
                                                              context.showMessage(
                                                                  message:
                                                                      "Copied"
                                                                          .tl);
                                                            }
                                                            if (value == 2) {
                                                              Clipboard.setData(
                                                                  ClipboardData(
                                                                      text: widget
                                                                          .anime
                                                                          .url!));
                                                              context.showMessage(
                                                                  message:
                                                                      "Copied"
                                                                          .tl);
                                                            }
                                                          },
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // 自定义播放器底部组件
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Visibility(
                                                  visible: !lockPanel,
                                                  child: SlideTransition(
                                                    position:
                                                        _bottomOffsetAnimation,
                                                    child: Row(
                                                      children: [
                                                        IconButton(
                                                          color: Colors.white,
                                                          icon: Icon(widget
                                                                  .playerController
                                                                  .playing
                                                              ? Icons.pause
                                                              : Icons
                                                                  .play_arrow),
                                                          onPressed: () {
                                                            if (widget
                                                                .playerController
                                                                .playing) {
                                                              widget
                                                                  .playerController
                                                                  .pause();
                                                            } else {
                                                              widget
                                                                  .playerController
                                                                  .play();
                                                            }
                                                          },
                                                        ),
                                                        // 更换选集
                                                        (widget.playerController
                                                                .isFullScreen)
                                                            ? IconButton(
                                                                color: Colors
                                                                    .white,
                                                                icon: const Icon(
                                                                    Icons
                                                                        .skip_next),
                                                                onPressed: () {
                                                                  // if (widget.playerController.loading) {
                                                                  //   return;
                                                                  // }
                                                                  widget
                                                                      .playerController
                                                                      .pause();
                                                                  widget
                                                                      .playerController
                                                                      .playNextEpisode(
                                                                          context);
                                                                },
                                                              )
                                                            : Container(),
                                                        Expanded(
                                                          child: ProgressBar(
                                                            timeLabelLocation:
                                                                TimeLabelLocation
                                                                    .none,
                                                            progress: widget
                                                                .playerController
                                                                .currentPosition,
                                                            buffered: widget
                                                                .playerController
                                                                .buffer,
                                                            total: widget
                                                                .playerController
                                                                .duration,
                                                            onSeek: (duration) {
                                                              if (playerTimer !=
                                                                  null) {
                                                                playerTimer!
                                                                    .cancel();
                                                              }
                                                              widget.playerController
                                                                      .currentPosition =
                                                                  duration;
                                                              widget
                                                                  .playerController
                                                                  .seek(
                                                                      duration);
                                                              playerTimer =
                                                                  getPlayerTimer(); //Bug_time
                                                            },
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 10.0),
                                                          child: Text(
                                                            "${Utils.durationToString(widget.playerController.currentPosition)} / ${Utils.durationToString(widget.playerController.duration)}",
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 16.0,
                                                            ),
                                                          ),
                                                        ),
                                                        (widget.playerController
                                                                .isFullScreen)
                                                            ? IconButton(
                                                                color: Colors
                                                                    .white,
                                                                onPressed: () {
                                                                  _showPlaybackSpeedDialog(
                                                                      context);
                                                                },
                                                                icon: const Icon(
                                                                    Icons
                                                                        .speed))
                                                            : Container(),
                                                        (widget.playerController
                                                                .isFullScreen)
                                                            ? IconButton(
                                                                color: Colors
                                                                    .white,
                                                                onPressed: () {
                                                                  // _showEpisodeList();
                                                                  widget.playerController
                                                                          .showTabBody =
                                                                      !widget
                                                                          .playerController
                                                                          .showTabBody;
                                                                  widget
                                                                      .openMenu();
                                                                },
                                                                icon: Icon(widget
                                                                        .playerController
                                                                        .showTabBody
                                                                    ? Icons
                                                                        .menu_open
                                                                    : Icons
                                                                        .menu_open_outlined),
                                                              )
                                                            : Container(),
                                                        IconButton(
                                                          color: Colors.white,
                                                          icon: Icon(widget
                                                                  .playerController
                                                                  .isFullScreen
                                                              ? Icons
                                                                  .fullscreen_exit
                                                              : Icons
                                                                  .fullscreen),
                                                          onPressed: () {
                                                            if (playerTimer !=
                                                                null) {
                                                              playerTimer!
                                                                  .cancel();
                                                            }
                                                            ((!App.isDesktop)
                                                                ? widget
                                                                    .playerController
                                                                    .enterFullScreen(
                                                                    context,
                                                                    onExit: () {
                                                                      // 在退出全屏后重新启动定时器
                                                                      playerTimer ??=
                                                                          getPlayerTimer();
                                                                    },
                                                                  )
                                                                : widget
                                                                    .playerController
                                                                    .toggleFullscreen(
                                                                    context,
                                                                    onExit: () {
                                                                      // 在退出全屏后重新启动定时器
                                                                      playerTimer ??=
                                                                          getPlayerTimer();
                                                                    },
                                                                  ));
                                                            // playerTimer =
                                                            //     getPlayerTimer();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ])))))))));
      }),
    );
  }

  Widget get playerSurface {
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(
          controller: widget.playerController.playerController,
        ));
  }

  void _showPlaybackSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择播放速度'),
        content: SingleChildScrollView(
          // 添加 SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (double speed in [
                0.5,
                0.75,
                1.0,
                1.5,
                2.0,
                3.0,
                4.0,
                5.0,
                6.0,
                7.0,
                8.0,
                10.0,
                20.0
              ])
                ListTile(
                  title: Text('${speed}x'),
                  onTap: () {
                    widget.playerController.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatteryWidget extends StatefulWidget {
  @override
  _BatteryWidgetState createState() => _BatteryWidgetState();
}

class _BatteryWidgetState extends State<_BatteryWidget> {
  late Battery _battery;
  late int _batteryLevel = 100;
  Timer? _timer;
  bool _hasBattery = false;

  @override
  void initState() {
    super.initState();
    _battery = Battery();
    _checkBatteryAvailability();
  }

  void _checkBatteryAvailability() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      if (_batteryLevel != -1) {
        setState(() {
          _hasBattery = true;
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            _battery.batteryLevel.then((level) => {
                  if (_batteryLevel != level)
                    {
                      setState(() {
                        _batteryLevel = level;
                      })
                    }
                });
          });
        });
      } else {
        setState(() {
          _hasBattery = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasBattery = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBattery) {
      return const SizedBox.shrink(); //Empty Widget
    }
    return _batteryInfo(_batteryLevel);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _batteryInfo(int batteryLevel) {
    IconData batteryIcon;
    Color batteryColor = context.colorScheme.onSurface;

    if (batteryLevel >= 96) {
      batteryIcon = Icons.battery_full_sharp;
    } else if (batteryLevel >= 84) {
      batteryIcon = Icons.battery_6_bar_sharp;
    } else if (batteryLevel >= 72) {
      batteryIcon = Icons.battery_5_bar_sharp;
    } else if (batteryLevel >= 60) {
      batteryIcon = Icons.battery_4_bar_sharp;
    } else if (batteryLevel >= 48) {
      batteryIcon = Icons.battery_3_bar_sharp;
    } else if (batteryLevel >= 36) {
      batteryIcon = Icons.battery_2_bar_sharp;
    } else if (batteryLevel >= 24) {
      batteryIcon = Icons.battery_1_bar_sharp;
    } else if (batteryLevel >= 12) {
      batteryIcon = Icons.battery_0_bar_sharp;
    } else {
      batteryIcon = Icons.battery_alert_sharp;
      batteryColor = Colors.red;
    }

    return Row(
      children: [
        Icon(
          batteryIcon,
          size: 16,
          color: batteryColor,
          // Stroke
          shadows: List.generate(
            9,
            (index) {
              if (index == 4) {
                return null;
              }
              double offsetX = (index % 3 - 1) * 0.8;
              double offsetY = ((index / 3).floor() - 1) * 0.8;
              return Shadow(
                color: context.colorScheme.onInverseSurface,
                offset: Offset(offsetX, offsetY),
              );
            },
          ).whereType<Shadow>().toList(),
        ),
        Stack(
          children: [
            Text(
              '$batteryLevel%',
              style: TextStyle(
                fontSize: 14,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4
                  ..color = context.colorScheme.onInverseSurface,
              ),
            ),
            Text('$batteryLevel%'),
          ],
        ),
      ],
    );
  }
}
