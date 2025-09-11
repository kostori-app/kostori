// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/battery_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/remote.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';
import 'package:path_provider/path_provider.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.playerController,
    required this.openMenu,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.startHideTimer,
    required this.cancelHideTimer,
    required this.showVideoInfo,
  });

  final PlayerController playerController;
  final void Function() openMenu;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;
  final AnimationController animationController;
  final void Function() startHideTimer;
  final void Function() cancelHideTimer;
  final void Function() showVideoInfo;

  @override
  State<PlayerItemPanel> createState() => _PlayerItemPanelState();
}

class _PlayerItemPanelState extends State<PlayerItemPanel> {
  PlayerController get playerController => widget.playerController;
  late bool haEnable;
  late Animation<Offset> topOffsetAnimation;
  late Animation<Offset> bottomOffsetAnimation;
  late Animation<Offset> rightOffsetAnimation;
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();

  String saveAddress = '';

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
                20.0,
              ])
                ListTile(
                  title: Text('${speed}x'),
                  onTap: () {
                    playerController.setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> captureAndSaveScreenshot({required BuildContext context}) async {
    saveAddress = '';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    App.rootContext.showMessage(message: '正在截图中...'.tl);
    if (App.isAndroid) {
      Uint8List? screenData = await playerController.player.screenshot();
      try {
        final folder = await KostoriFolder.checkPermissionAndPrepareFolder();
        if (folder != null) {
          final file = File(
            '${folder.path}/${WatcherState.currentState!.anime.title}_$timestamp.png',
          );
          await file.writeAsBytes(screenData!);
          setState(() {
            saveAddress =
                '${folder.path}/${WatcherState.currentState!.anime.title}_$timestamp.png';
          });
          playerController.showScreenshotPopup(
            context,
            saveAddress,
            '${WatcherState.currentState!.anime.title}_$timestamp.png',
          );
          showCenter(
            seconds: 1,
            icon: Gif(
              image: AssetImage('assets/img/check.gif'),
              height: 80,
              fps: 120,
              color: Theme.of(context).colorScheme.primary,
              autostart: Autostart.once,
            ),
            message: '截图成功',
            context: App.rootContext,
          );
          const platform = MethodChannel('kostori/media');
          await platform.invokeMethod('scanFolder', {'path': folder.path});
          Log.addLog(LogLevel.info, '保存文件成功', '');
        } else {
          Log.addLog(LogLevel.error, '保存失败：权限或目录异常', '');
        }
      } catch (e) {
        Log.addLog(LogLevel.error, '截图失败', '$e');
      }
    } else {
      try {
        Uint8List? screenData = await playerController.player.screenshot();
        // 获取桌面平台的文档目录
        final directory = await getApplicationDocumentsDirectory();
        // 目标文件夹路径
        final folderPath = '${directory.path}/Kostori';
        // 检查文件夹是否存在，如果不存在则创建它
        final folder = Directory(folderPath);
        if (!await folder.exists()) {
          await folder.create(recursive: true);
          Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
        } else {
          Log.addLog(LogLevel.info, '文件夹已存在', folderPath);
        }

        final filePath =
            '$folderPath/${WatcherState.currentState!.anime.title}_$timestamp.png';
        // 将图像保存为文件
        final file = File(filePath);
        await file.writeAsBytes(screenData!);
        saveAddress =
            '$folderPath/${WatcherState.currentState!.anime.title}_$timestamp.png';
        playerController.showScreenshotPopup(
          context,
          saveAddress,
          '${WatcherState.currentState!.anime.title}_$timestamp.png',
        );
        showCenter(
          seconds: 1,
          icon: Gif(
            image: AssetImage('assets/img/check.gif'),
            height: 80,
            fps: 120,
            color: Theme.of(context).colorScheme.primary,
            autostart: Autostart.once,
          ),
          message: '截图成功',
          context: App.rootContext,
        );
      } catch (e) {
        Log.addLog(LogLevel.error, '截图失败', '$e');
      }
    }
  }

  // 单独提取菜单项构建方法
  List<MenuItemButton> _buildShaderMenuItems(BuildContext context) {
    return List.generate(3, (index) {
      final type = index + 1;
      final isSelected = playerController.superResolutionType == type;

      return MenuItemButton(
        onPressed: () => playerController.setShader(type),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Text(
            _getShaderTypeName(type),
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ),
      );
    });
  }

  // 获取超分辨率类型名称
  String _getShaderTypeName(int type) {
    switch (type) {
      case 1:
        return '关闭';
      case 2:
        return '效率档';
      case 3:
        return '质量档';
      default:
        return '未知';
    }
  }

  @override
  void initState() {
    super.initState();
    topOffsetAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, -1.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: widget.animationController,
            curve: Curves.easeInOut,
          ),
        );
    bottomOffsetAnimation =
        Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: widget.animationController,
            curve: Curves.easeInOut,
          ),
        );
    rightOffsetAnimation =
        Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: const Offset(0.0, 0.0),
        ).animate(
          CurvedAnimation(
            parent: widget.animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    super.dispose();
  }

  MenuButton _buildMenuItems() {
    return MenuButton(
      message: "More".tl,
      entries: [
        if (App.isAndroid)
          MenuEntry(
            text: (appdata.settings['audioOutType'] ?? true)
                ? "Audio Option: \nLow Latency".tl
                : "Audio Option: \nCompatibility".tl,
            onClick: () async {
              try {
                await playerController.changeAudioOutType();
                App.rootContext.showMessage(message: "Switch Successful".tl);
              } catch (e) {
                App.rootContext.showMessage(message: "Switch Failed".tl);
              }
            },
          ),
        MenuEntry(
          text: "Remote Cast".tl,
          onClick: () {
            bool needRestart = playerController.playing;
            playerController.pause();
            RemotePlay().castVideo(playerController.videoUrl).whenComplete(() {
              if (needRestart) {
                playerController.play();
              }
            });
          },
        ),
        if (!playerController.isFullScreen)
          MenuEntry(
            text: "Logs".tl,
            onClick: () {
              context.to(() => const LogsPage());
            },
          ),
        MenuEntry(
          text: "Player Details".tl,
          onClick: () {
            widget.showVideoInfo();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            //底部进度条
            AnimatedOpacity(
              opacity:
                  ((!playerController.isFullScreen &&
                          !playerController.showVideoController) ||
                      playerController.isSeek)
                  ? 1.0
                  : 0.0,
              duration: Duration(seconds: 1),
              curve: Curves.easeInOut,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(
                        begin: playerController.isSeek ? 0.0 : 1.0,
                        end: playerController.isSeek ? 1.0 : 0.0,
                      ),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            height: 25,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.3, 0.6, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.black.toOpacity(0.3),
                                  Colors.black.toOpacity(0.6),
                                  Colors.black,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.toOpacity(0.2),
                                  blurRadius: 20.0,
                                  spreadRadius: 5.0,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      tween: Tween<double>(
                        begin: playerController.isSeek ? 0 : 1,
                        end: playerController.isSeek ? 1 : 0,
                      ),
                      builder: (context, value, child) {
                        return ProgressBar(
                          thumbRadius: 6 * value,
                          thumbGlowRadius: 0,
                          barHeight: 2 + 2 * value,
                          progressBarColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.72),
                          bufferedBarColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.36),
                          baseBarColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.2),
                          timeLabelLocation: TimeLabelLocation.none,
                          progress: playerController.currentPosition,
                          buffered: playerController.buffer,
                          total: playerController.duration,
                          onSeek: (duration) {
                            playerController.seek(duration);
                          },
                          onDragStart: (details) {
                            widget.handleProgressBarDragStart(details);
                          },
                          onDragUpdate: (details) {
                            playerController.currentPosition =
                                details.timeStamp;
                          },
                          onDragEnd: () {
                            widget.handleProgressBarDragEnd();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

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
                    height: playerController.isPortraitFullscreen
                        ? MediaQuery.of(context).padding.top + 120
                        : 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.toOpacity(0.8), // 起始透明度提高
                          Colors.black.toOpacity(0.6), // 中间过渡点
                          Colors.black.toOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.toOpacity(0.2),
                          blurRadius: 20.0, // 边缘模糊
                          spreadRadius: 5.0,
                        ),
                      ],
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
              child: SlideTransition(
                position: bottomOffsetAnimation,
                child: Container(
                  height: playerController.isPortraitFullscreen ? 140 : 50,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.3, 0.6, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.toOpacity(0.3),
                        Colors.black.toOpacity(0.6),
                        Colors.black,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.toOpacity(0.2),
                        blurRadius: 20.0,
                        spreadRadius: 5.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 右侧渐变半透明区域
            AnimatedPositioned(
              duration: Duration(seconds: 1),
              top: 0,
              bottom: 0,
              right: 0,
              child: Visibility(
                child: SlideTransition(
                  position: rightOffsetAnimation,
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.toOpacity(0.8),
                          Colors.black.toOpacity(0.6),
                          Colors.black.toOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.toOpacity(0.2),
                          blurRadius: 20.0, // 边缘模糊
                          spreadRadius: 5.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 顶部进度条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: playerController.showSeekTime
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
                            playerController.currentPosition.compareTo(
                                      playerController.player.state.position,
                                    ) >
                                    0
                                ? '快进 ${playerController.currentPosition.inSeconds - playerController.player.state.position.inSeconds} 秒'
                                : '快退 ${playerController.player.state.position.inSeconds - playerController.currentPosition.inSeconds} 秒',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : Container(),
            ),
            // 顶部播放速度条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: playerController.showPlaySpeed
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
                              Gif(
                                image: AssetImage('assets/img/speeding.gif'),
                                height: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.toOpacity(0.52),
                                autostart: Autostart.loop,
                                fps: 40,
                              ),
                              Text(
                                '${playerController.playbackSpeed.toInt()}X',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(),
            ),
            // 亮度条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: playerController.showBrightness
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
                              const Icon(
                                Icons.brightness_7,
                                color: Colors.white,
                              ),
                              Text(
                                ' ${(playerController.brightness * 100).toInt()} %',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(),
            ),
            // 音量条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: playerController.showVolume
                  ? Wrap(
                      alignment: WrapAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.black.toOpacity(0.5),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.volume_down,
                                color: Colors.white,
                              ),
                              Text(
                                ' ${(playerController.volume).toInt()}%',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Container(),
            ),
            // 侧边栏:截图,快进
            if (!playerController.isPortraitFullscreen)
              Positioned(
                right: 10,
                top: 60,
                child: Visibility(
                  child: SlideTransition(
                    position: rightOffsetAnimation,
                    child: MouseRegion(
                      cursor:
                          (playerController.isFullScreen &&
                              !playerController.showVideoController)
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
                              await captureAndSaveScreenshot(context: context);
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
                  ),
                ),
              ),
            // 自定义顶部组件
            if (!playerController.isPortraitFullscreen)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Visibility(
                  child: SlideTransition(
                    position: topOffsetAnimation,
                    child: MouseRegion(
                      cursor:
                          (playerController.isFullScreen &&
                              !playerController.showVideoController)
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
                                              textDirection: TextDirection.ltr,
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
                                                    scrollAxis: Axis.horizontal,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                              textDirection: TextDirection.ltr,
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
                                                    scrollAxis: Axis.horizontal,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                            //超分
                            MenuAnchor(
                              consumeOutsideTap: true,
                              onOpen: () {
                                widget.cancelHideTimer();
                                playerController.canHidePlayerPanel = false;
                              },
                              onClose: () {
                                widget.cancelHideTimer();
                                widget.startHideTimer();
                                playerController.canHidePlayerPanel = true;
                              },
                              builder:
                                  (
                                    BuildContext context,
                                    MenuController controller,
                                    Widget? child,
                                  ) {
                                    return TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      onPressed: () => controller.isOpen
                                          ? controller.close()
                                          : controller.open(),
                                      child: const Text('超分辨率'),
                                    );
                                  },
                              menuChildren: _buildShaderMenuItems(context),
                            ),

                            if (playerController.isFullScreen) ...[
                              const SizedBox(width: 4),
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
                              //安卓流量速度显示
                              (App.isAndroid)
                                  ? SizedBox(
                                      width: 64,
                                      child: SpeedMonitorWidget(),
                                    )
                                  : Container(),
                              (App.isAndroid)
                                  ? const SizedBox(width: 8)
                                  : Container(),
                              //电池
                              BatteryWidget(),
                              const SizedBox(width: 4),
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
                            _buildMenuItems(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Visibility(
                  child: SlideTransition(
                    position: topOffsetAnimation,
                    child: MouseRegion(
                      cursor:
                          (playerController.isFullScreen &&
                              !playerController.showVideoController)
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
                                      playerController.toggleFullScreen(
                                        context,
                                      );
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
                                                  maxWidth:
                                                      constraints.maxWidth,
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
                                                        alignment: Alignment
                                                            .centerLeft,
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
                                                  maxWidth:
                                                      constraints.maxWidth,
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
                                                        alignment: Alignment
                                                            .centerLeft,
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
                                _buildMenuItems(),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                //超分
                                MenuAnchor(
                                  consumeOutsideTap: true,
                                  onOpen: () {
                                    widget.cancelHideTimer();
                                    playerController.canHidePlayerPanel = false;
                                  },
                                  onClose: () {
                                    widget.cancelHideTimer();
                                    widget.startHideTimer();
                                    playerController.canHidePlayerPanel = true;
                                  },
                                  builder:
                                      (
                                        BuildContext context,
                                        MenuController controller,
                                        Widget? child,
                                      ) {
                                        return TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                          ),
                                          onPressed: () => controller.isOpen
                                              ? controller.close()
                                              : controller.open(),
                                          child: const Text('超分辨率'),
                                        );
                                      },
                                  menuChildren: _buildShaderMenuItems(context),
                                ),

                                if (playerController.isFullScreen) ...[
                                  const SizedBox(width: 4),
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
                                  //安卓流量速度显示
                                  (App.isAndroid)
                                      ? SizedBox(
                                          width: 64,
                                          child: SpeedMonitorWidget(),
                                        )
                                      : Container(),
                                  (App.isAndroid)
                                      ? const SizedBox(width: 8)
                                      : Container(),
                                  //电池
                                  BatteryWidget(),
                                  const SizedBox(width: 4),
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
            if (!playerController.isPortraitFullscreen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Visibility(
                  child: SlideTransition(
                    position: bottomOffsetAnimation,
                    child: MouseRegion(
                      cursor:
                          (playerController.isFullScreen &&
                              !playerController.showVideoController)
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
                                    // if (playerController.loading) {
                                    //   return;
                                    // }
                                    playerController.pause();
                                    await playerController.playNextEpisode();
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
                          (playerController.isFullScreen)
                              ? IconButton(
                                  color: Colors.white,
                                  onPressed: () {
                                    _showPlaybackSpeedDialog(context);
                                  },
                                  icon: const Icon(Icons.speed),
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
                          (!playerController.isFullScreen && App.isAndroid)
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.picture_in_picture_alt,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {
                                    final floating = Floating();
                                    if (await floating.isPipAvailable) {
                                      final status = await floating.pipStatus;
                                      if (status == PiPStatus.disabled ||
                                          status == PiPStatus.automatic) {
                                        playerController.enterPiPMode();
                                      } else if (status == PiPStatus.enabled) {
                                        playerController.exitPiPMode();
                                      }
                                    }
                                  },
                                )
                              : Container(),
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
                  ),
                ),
              )
            else
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Visibility(
                  child: SlideTransition(
                    position: bottomOffsetAnimation,
                    child: MouseRegion(
                      cursor:
                          (playerController.isFullScreen &&
                              !playerController.showVideoController)
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
                                    await captureAndSaveScreenshot(
                                      context: context,
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                  ),
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
                                    _showPlaybackSpeedDialog(context);
                                  },
                                  icon: const Icon(Icons.speed),
                                ),
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
