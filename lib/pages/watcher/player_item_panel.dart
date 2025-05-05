import 'dart:async';
import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path_provider/path_provider.dart';

import '../../foundation/log.dart';
import '../../utils/bean/appbar/drag_to_move_bar.dart' as dtb;
import '../../utils/utils.dart';
import 'BatteryWidget.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.playerController,
    required this.openMenu,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.keyboardFocus,
    required this.startHideTimer,
    required this.cancelHideTimer,
  });

  final PlayerController playerController;
  final void Function() openMenu;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final AnimationController animationController;
  final FocusNode keyboardFocus;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  late bool haEnable;
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  late Animation<Offset> leftOffsetAnimation;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();

  Timer? timer;
  String formattedTime = '';

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

  @override
  void initState() {
    super.initState();
    topOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
      curve: Curves.easeInOut,
    ));
    leftOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: widget.animationController,
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
  }

  @override
  void dispose() {
    super.dispose();
    timer!.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return Stack(alignment: Alignment.center, children: [
        // 顶部渐变半透明区域
        AnimatedPositioned(
          duration: Duration(seconds: 1),
          top: 0,
          left: 0,
          right: 0,
          child: Visibility(
            child: SlideTransition(
              position: topOffsetAnimation,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.toOpacity(0.9),
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
            child: SlideTransition(
              position: bottomOffsetAnimation,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.toOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // 顶部进度条
        Positioned(
            top: 25,
            child: widget.playerController.showSeekTime
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.black.toOpacity(0.5),
                          borderRadius: BorderRadius.circular(8.0), // 圆角
                        ),
                        child: Text(
                          widget.playerController.currentPosition.compareTo(
                                      widget.playerController.player.state
                                          .position) >
                                  0
                              ? '快进 ${widget.playerController.currentPosition.inSeconds - widget.playerController.player.state.position.inSeconds} 秒'
                              : '快退 ${widget.playerController.player.state.position.inSeconds - widget.playerController.currentPosition.inSeconds} 秒',
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Container()),
        // 顶部播放速度条
        Positioned(
            top: 25,
            child: widget.playerController.showPlaySpeed
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.black.toOpacity(0.5),
                          borderRadius: BorderRadius.circular(8.0), // 圆角
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.fast_forward, color: Colors.white),
                            Text(
                              ' 倍速播放',
                              style: TextStyle(
                                color: Colors.white,
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
            child: widget.playerController.showBrightness
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.toOpacity(0.5),
                            borderRadius: BorderRadius.circular(8.0), // 圆角
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.brightness_7,
                                  color: Colors.white),
                              Text(
                                ' ${(widget.playerController.brightness * 100).toInt()} %',
                                style: const TextStyle(
                                  color: Colors.white,
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
            child: widget.playerController.showVolume
                ? Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.toOpacity(0.5),
                            borderRadius: BorderRadius.circular(8.0), // 圆角
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.volume_down,
                                  color: Colors.white),
                              Text(
                                ' ${(widget.playerController.volume).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
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
            position: leftOffsetAnimation,
            child: IconButton(
              icon: Icon(
                Icons.fit_screen,
                color: Colors.white,
              ),
              onPressed: () async {
                if (App.isAndroid) {
                  try {
                    Uint8List? screenData =
                        await widget.playerController.player.screenshot();
                    _saveImageToGallery(screenData!);
                    SmartDialog.showNotify(
                        msg: '截图成功', notifyType: NotifyType.success);
                  } catch (e) {
                    Log.addLog(LogLevel.error, '截图失败', '$e');
                  }
                } else {
                  try {
                    Uint8List? screenData =
                        await widget.playerController.player.screenshot();
                    // 获取桌面平台的文档目录
                    final directory = await getApplicationDocumentsDirectory();
                    // 目标文件夹路径
                    final folderPath = '${directory.path}/Screenshots';
                    // 检查文件夹是否存在，如果不存在则创建它
                    final folder = Directory(folderPath);
                    if (!await folder.exists()) {
                      await folder.create(recursive: true);
                      Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
                    } else {
                      Log.addLog(LogLevel.info, '文件夹已存在', folderPath);
                    }

                    final timestamp = DateTime.now().millisecondsSinceEpoch;
                    final filePath = '$folderPath/anime_image_$timestamp.png';
                    // 将图像保存为文件
                    final file = File(filePath);
                    await file.writeAsBytes(screenData!);
                    SmartDialog.showNotify(
                        msg: '截图成功', notifyType: NotifyType.success);
                  } catch (e) {
                    Log.addLog(LogLevel.error, '截图失败', '$e');
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
            child: SlideTransition(
              position: topOffsetAnimation,
              child: MouseRegion(
                cursor: (widget.playerController.isFullScreen &&
                        !widget.playerController.showVideoController)
                    ? SystemMouseCursors.none
                    : SystemMouseCursors.basic,
                onEnter: (_) {
                  widget.cancelHideTimer();
                },
                onExit: (_) {
                  widget.cancelHideTimer();
                  widget.startHideTimer();
                },
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () {
                        if (widget.playerController.isFullScreen) {
                          // 检查是否是桌面环境，分别处理全屏逻辑
                          if (!App.isDesktop) {
                            widget.playerController.enterFullScreen(context);
                          } else {
                            widget.playerController.toggleFullscreen(context);
                          }
                        } else {
                          // 如果不是全屏，退出当前页面
                          Navigator.pop(context);
                        }
                      },
                    ),
                    //标题集数显示
                    (widget.playerController.isFullScreen)
                        ? Text(
                            '${WatcherState.currentState!.widget.anime.title} ${widget.playerController.currentSetName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.right,
                          )
                        : Container(),
                    // 拖动条
                    Expanded(
                      child: dtb.DragToMoveArea(child: SizedBox(height: 40)),
                    ),
                    //时间
                    (widget.playerController.isFullScreen)
                        ? Text(
                            formattedTime,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .fontSize),
                          )
                        : Container(),
                    const SizedBox(width: 8),
                    //电池
                    (widget.playerController.isFullScreen)
                        ? BatteryWidget()
                        : Container(),
                    //倍数状态条
                    TextButton(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                      ),
                      onPressed: () {
                        if (widget.playerController.playbackSpeed < 2) {
                          widget.playerController.setPlaybackSpeed(2);
                        } else {
                          widget.playerController.setPlaybackSpeed(1);
                        }
                      },
                      child: Text(
                        '${widget.playerController.playbackSpeed}X',
                        style: const TextStyle(
                          color: Colors.white,
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
                      itemBuilder: (context) {
                        return [
                          PopupMenuItem(
                            value: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Copy Title".tl),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 1,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Copy ID".tl),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Text("Copy URL".tl)],
                            ),
                          ),
                        ];
                      },
                      onSelected: (value) {
                        if (value == 0) {
                          Clipboard.setData(ClipboardData(
                              text: WatcherState
                                  .currentState!.widget.anime.title));
                          context.showMessage(message: "Copied".tl);
                        }
                        if (value == 1) {
                          Clipboard.setData(ClipboardData(
                              text:
                                  WatcherState.currentState!.widget.anime.id));
                          context.showMessage(message: "Copied".tl);
                        }
                        if (value == 2) {
                          Clipboard.setData(ClipboardData(
                              text: WatcherState
                                  .currentState!.widget.anime.url!));
                          context.showMessage(message: "Copied".tl);
                        }
                      },
                    )
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
          child: Visibility(
            child: SlideTransition(
              position: bottomOffsetAnimation,
              child: MouseRegion(
                cursor: (widget.playerController.isFullScreen &&
                        !widget.playerController.showVideoController)
                    ? SystemMouseCursors.none
                    : SystemMouseCursors.basic,
                onEnter: (_) {
                  widget.cancelHideTimer();
                },
                onExit: (_) {
                  widget.cancelHideTimer();
                  widget.startHideTimer();
                },
                child: Row(
                  children: [
                    IconButton(
                      color: Colors.white,
                      icon: Icon(widget.playerController.playing
                          ? Icons.pause
                          : Icons.play_arrow),
                      onPressed: () {
                        if (widget.playerController.playing) {
                          widget.playerController.pause();
                        } else {
                          widget.playerController.play();
                        }
                      },
                    ),
                    // 更换选集
                    (widget.playerController.isFullScreen)
                        ? IconButton(
                            color: Colors.white,
                            icon: const Icon(Icons.skip_next),
                            onPressed: () {
                              // if (widget.playerController.loading) {
                              //   return;
                              // }
                              widget.playerController.pause();
                              widget.playerController.playNextEpisode(context);
                            },
                          )
                        : Container(),
                    Expanded(
                      child: ProgressBar(
                        thumbRadius: 8,
                        thumbGlowRadius: 18,
                        timeLabelLocation: TimeLabelLocation.none,
                        timeLabelTextStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontFeatures: [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                        progress: widget.playerController.currentPosition,
                        buffered: widget.playerController.buffer,
                        total: widget.playerController.duration,
                        onSeek: (duration) {
                          widget.playerController.seek(duration);
                        },
                        onDragStart: (details) {
                          widget.handleProgressBarDragStart(details);
                        },
                        onDragUpdate: (details) => {
                          widget.playerController.currentPosition =
                              details.timeStamp
                        },
                        onDragEnd: () {
                          widget.handleProgressBarDragEnd();
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "${Utils.durationToString(widget.playerController.currentPosition)} / ${Utils.durationToString(widget.playerController.duration)}",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.0,
                        ),
                      ),
                    ),
                    (widget.playerController.isFullScreen)
                        ? IconButton(
                            color: Colors.white,
                            onPressed: () {
                              _showPlaybackSpeedDialog(context);
                            },
                            icon: const Icon(Icons.speed))
                        : Container(),
                    (widget.playerController.isFullScreen)
                        ? IconButton(
                            color: Colors.white,
                            onPressed: () {
                              widget.playerController.showTabBody =
                                  !widget.playerController.showTabBody;
                              widget.openMenu();
                            },
                            icon: Icon(widget.playerController.showTabBody
                                ? Icons.menu_open
                                : Icons.menu_open_outlined),
                          )
                        : Container(),
                    IconButton(
                      color: Colors.white,
                      icon: Icon(widget.playerController.isFullScreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen),
                      onPressed: () {
                        ((!App.isDesktop)
                            ? widget.playerController.enterFullScreen(context)
                            : widget.playerController
                                .toggleFullscreen(context));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }
}
