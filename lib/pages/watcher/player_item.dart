import 'dart:async';
import 'dart:ui';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:floating/floating.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/player_item_base_panel.dart';
import 'package:kostori/pages/watcher/player_item_panel.dart';
import 'package:kostori/pages/watcher/player_item_portrait_panel.dart';
import 'package:kostori/pages/watcher/player_item_surface.dart';
import 'package:kostori/utils/remote.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:window_manager/window_manager.dart';

class PlayerItem extends StatefulWidget {
  final PlayerController playerController;

  final VoidCallback openMenu;

  /// 全屏时切换一起看聊天面板
  final VoidCallback? onChatToggle;

  final VoidCallback locateEpisode;
  final FocusNode keyboardFocus;

  const PlayerItem({
    super.key,
    required this.playerController,
    required this.openMenu,
    this.onChatToggle,
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

  /// 音量滑动节流：连续滑动时按固定间隔应用 media_kit 音量，
  /// 避免每帧高频调用 player.setVolume 造成播放卡顿
  DateTime? _lastVolumeApply;

  void _applyVolumeThrottled(double value) {
    final now = DateTime.now();
    if (_lastVolumeApply == null ||
        now.difference(_lastVolumeApply!) >= const Duration(milliseconds: 30)) {
      _lastVolumeApply = now;
      // 不 await，避免连续触发时 Future 堆积
      playerController.setVolume(value);
    }
  }

  void glimmerEffectMode() {
    appdata.implicitData['glimmerEffect'] = !playerController.glimmerEffect;
    appdata.writeImplicitData();
    playerController.glimmerEffect = !playerController.glimmerEffect;
    setState(() {});
  }

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
    // 收起面板时顺带取消输入框焦点，避免按键被隐藏的快捷输入框截获打字
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _handleTap() {
    // 点击视频区域：先取消当前输入框焦点，防止"没点输入框却还在打字"
    if (FocusManager.instance.primaryFocus?.hasFocus == true) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
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
    // playerController.playerTimer?.cancel();
    playerController.stopPlayerStreams();
    // 拖动进度条时静默暂停，不显示播放/暂停覆盖层
    playerController.pause(showIndicator: false);
    hideTimer?.cancel();
    playerController.showVideoController = true;
    // _showPreview(details.timeStamp);
  }

  void handleProgressBarDragEnd() {
    playerController.play(showIndicator: false);
    startHideTimer();
    // playerController.playerTimer = playerController.getPlayerTimer();
    playerController.startPlayerStreams();
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
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: MediaQuery.of(context).size.width <= 600
            ? MediaQuery.of(context).size.width
            : (App.isDesktop)
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (_) => Sheet(
        title: t.watcherDetailsLogs,
        icon: Icons.info_outline_rounded,
        builder: (_, _) => VideoInfoSheet.fromController(playerController),
      ),
    );
  }

  /// 更多面板里"点击型"操作项（小窗 / 投屏 / 日志 / 播放器详情 / 音频设备）
  List<MenuEntry> _actionEntries() {
    return [
      if (App.isDesktop)
        MenuEntry(
          icon: Icons.speaker_outlined,
          text: t.audioOutputDevice,
          onClick: () => _showAudioDevicePicker(),
        ),
      if (!playerController.isFullScreen && App.isAndroid)
        MenuEntry(
          icon: Icons.picture_in_picture_alt,
          text: t.watcherMiniWindow,
          onClick: () async {
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
        ),
      MenuEntry(
        icon: Icons.cast_outlined,
        text: t.remoteCast,
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
          icon: Icons.article_outlined,
          text: t.log,
          onClick: () {
            showModalBottomSheet(
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
                maxWidth: MediaQuery.of(context).size.width <= 600
                    ? MediaQuery.of(context).size.width
                    : (App.isDesktop)
                    ? MediaQuery.of(context).size.width * 9 / 16
                    : MediaQuery.of(context).size.width,
              ),
              clipBehavior: Clip.antiAlias,
              context: context,
              builder: (_) => Sheet(
                title: t.logs,
                icon: Icons.article_outlined,
                initialSize: 0.85,
                builder: (_, _) => const LogsPage(inSheet: true),
              ),
            );
          },
        ),
      MenuEntry(
        icon: Icons.info_outline,
        text: t.playerDetails,
        onClick: () {
          showVideoInfo();
        },
      ),
    ];
  }

  /// 播放器面板右上角"更多"按钮：点击弹出底部 sheet
  Widget _buildMenuItems() {
    return IconButton(
      tooltip: t.more,
      icon: const Icon(Icons.more_vert),
      color: Colors.white,
      onPressed: _showMoreSheet,
    );
  }

  /// 更多选项底部 sheet：上方是"图标在上文字在下"的操作项，下方是卡片式开关
  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      builder: (_) => Sheet(
        title: t.more,
        icon: Icons.more_horiz,
        initialSize: 0.6,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            // 操作项：图标在上文字在下，放置最上方
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (final e in _actionEntries())
                    IconTileButton(
                      icon: Icon(e.icon),
                      label: e.text,
                      onTap: () {
                        Navigator.pop(ctx);
                        e.onClick();
                      },
                    ),
                ],
              ),
            ),
            // 开关类：卡片风格（图标 + 标题 + 开关）
            if (App.isAndroid)
              _MoreSwitchCard(
                icon: Icons.speaker_outlined,
                title: t.audioOption, // 低延迟音频
                value: appdata.settings['audioOutType'] ?? true,
                onChanged: (v) async {
                  appdata.settings['audioOutType'] = v;
                  appdata.saveData();
                  await playerController.changeAudioOutType();
                  App.rootContext.showMessage(message: t.switchSuccessful);
                },
              ),
            if (App.isDesktop)
              _MoreSwitchCard(
                icon: Icons.graphic_eq_outlined,
                title: t.volumeBoost,
                value: playerController.volumeBoost,
                onChanged: (v) async {
                  await playerController.toggleVolumeBoost();
                  App.rootContext.showMessage(message: t.switchSuccessful);
                },
              ),
            _MoreSwitchCard(
              icon: Icons.auto_awesome_outlined,
              title: t.glimmerMode,
              value: playerController.glimmerEffect,
              onChanged: (v) => glimmerEffectMode(),
            ),
            // 播放倍率（与全屏视频信息一致，Observer 驱动实时刷新）
            _MoreSettingCard(
              icon: Icons.speed_outlined,
              title: t.playbackSpeed,
              child: Observer(
                builder: (context) => Column(
                  children: [
                    Slider(
                      value: playerController.playbackSpeed,
                      min: 0.5,
                      max: 4.0,
                      divisions: 7,
                      onChanged: (v) => playerController.setPlaybackSpeed(v),
                    ),
                    Text(
                      '${playerController.playbackSpeed.toStringAsFixed(2)}x',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            // 超分辨率（与全屏视频信息一致）
            _MoreSettingCard(
              icon: Icons.high_quality_outlined,
              title: t.superResolution,
              child: Observer(
                builder: (context) => SegmentedButton<int>(
                  segments: [
                    ButtonSegment<int>(
                      value: 1,
                      label: Text(t.superResolutionOff),
                    ),
                    ButtonSegment<int>(
                      value: 2,
                      label: Text(t.superResolutionEfficiency),
                    ),
                    ButtonSegment<int>(
                      value: 3,
                      label: Text(t.superResolutionQuality),
                    ),
                  ],
                  selected: {playerController.superResolutionType},
                  onSelectionChanged: (Set<int> selected) {
                    if (selected.isNotEmpty) {
                      playerController.setShader(selected.first);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 音频输出设备选择弹窗（桌面端）
  Future<void> _showAudioDevicePicker() async {
    final devices = await playerController.getAudioDevices();
    final current = playerController.currentAudioDevice;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.audioOutputDevice,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.autorenew, size: 18),
              title: Text(t.autoDetect),
              trailing: current.isEmpty
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () async {
                await playerController.setAudioDevice('');
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            for (final d in devices)
              ListTile(
                dense: true,
                leading: const Icon(Icons.speaker_outlined, size: 18),
                title: Text(
                  d.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: current == d.name
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () async {
                  await playerController.setAudioDevice(d.name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(t.noAudioDevice),
              ),
          ],
        ),
      ),
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
              onEnter: (_) {
                // 非全屏时键盘焦点常被 Tab/其他控件抢走，鼠标进入播放器时重新抢回，
                // 保证空格/F/方向键等快捷键可用。
                if (App.isDesktop && !widget.keyboardFocus.hasFocus) {
                  widget.keyboardFocus.requestFocus();
                }
              },
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
                      : double.infinity,
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (playerController.glimmerEffect)
                        Positioned.fill(
                          child: AmbientShaderVideo(
                            controller: playerController,
                          ),
                        ),
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
                                    return KeyEventResult.handled;
                                  } catch (e) {
                                    PlayLog.error('播放器内部错误', e.toString());
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
                                    // playerController.playerTimer =
                                    //     playerController.getPlayerTimer();
                                    playerController.startPlayerStreams();
                                    return KeyEventResult.handled;
                                  } catch (e) {
                                    PlayLog.error('播放器内部错误', e.toString());
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
                                    // playerController.playerTimer =
                                    //     playerController.getPlayerTimer();
                                    playerController.startPlayerStreams();
                                    return KeyEventResult.handled;
                                  } catch (e) {
                                    PlayLog.error('左方向键被按下', e.toString());
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
                                      // playerController.playerTimer?.cancel();
                                      playerController.stopPlayerStreams();
                                      playerController.seek(
                                        Duration(
                                          seconds:
                                              playerController
                                                  .currentPosition
                                                  .inSeconds +
                                              10,
                                        ),
                                      );
                                      // playerController.playerTimer =
                                      //     playerController.getPlayerTimer();
                                      playerController.startPlayerStreams();
                                    } catch (e) {
                                      PlayLog.error('播放器内部错误', e.toString());
                                    }
                                  }
                                }
                              }
                              return KeyEventResult.handled;
                            },
                            child: RepaintBoundary(
                              child: PlayerItemSurface(
                                playerController: playerController,
                              ),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: RepaintBoundary(
                            child: PlayerItemSurface(
                              playerController: playerController,
                            ),
                          ),
                        ),
                      PlayerItemBasePanel(
                        playerController: playerController,
                        handleProgressBarDragStart: handleProgressBarDragStart,
                        handleProgressBarDragEnd: handleProgressBarDragEnd,
                        animationController: animationController!,
                        currentPosition: playerController.currentPosition,
                        buffer: playerController.buffer,
                        duration: playerController.duration,
                      ),
                      GestureDetector(
                        onTap: () {
                          _handleTap();
                        },
                        onDoubleTap: () {
                          _handleDoubleTap();
                        },
                        onLongPressStart: (_) {
                          // 一起看房间锁倍速：长按 2x 直接无效，也不显示 HUD
                          if (playerController.speedLocked) return;
                          setState(() {
                            playerController.showPlaySpeed = true;
                          });
                          playerController.setPlaybackSpeed(
                            playerController.playbackSpeed * 2,
                          );
                        },
                        onLongPressEnd: (_) {
                          if (playerController.speedLocked) return;
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
                      if (!playerController.isPortraitFullscreen)
                        PlayerItemPanel(
                          openMenu: widget.openMenu,
                          onChatToggle: widget.onChatToggle,
                          handleProgressBarDragStart:
                              handleProgressBarDragStart,
                          handleProgressBarDragEnd: handleProgressBarDragEnd,
                          animationController: animationController!,
                          startHideTimer: startHideTimer,
                          cancelHideTimer: cancelHideTimer,
                          showVideoInfo: showVideoInfo,
                          playerController: playerController,
                          buildMenuItems: _buildMenuItems(),
                        )
                      else
                        PlayerItemPortraitPanel(
                          playerController: playerController,
                          openMenu: widget.openMenu,
                          onChatToggle: widget.onChatToggle,
                          handleProgressBarDragStart:
                              handleProgressBarDragStart,
                          handleProgressBarDragEnd: handleProgressBarDragEnd,
                          animationController: animationController!,
                          startHideTimer: startHideTimer,
                          cancelHideTimer: cancelHideTimer,
                          showVideoInfo: showVideoInfo,
                          buildMenuItems: _buildMenuItems(),
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
                            // playerController.playerTimer?.cancel();
                            playerController.stopPlayerStreams();
                            // 左右滑动 seek：静默暂停，不显示覆盖层
                            playerController.pause(showIndicator: false);
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
                            // 左右滑动 seek 结束：静默播放，不显示覆盖层
                            playerController.play(showIndicator: false);
                            playerController.seek(
                              playerController.currentPosition,
                            );
                            playerController.isSeek = false;
                            // playerController.playerTimer?.cancel();
                            playerController.stopPlayerStreams();
                            // playerController.playerTimer = playerController
                            //     .getPlayerTimer();
                            playerController.startPlayerStreams();
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
                                  // HUD 即时反馈：先更新 observable，播放器实际
                                  // 音量节流应用，避免连续滑动时每帧高频调用
                                  // media_kit setVolume 造成视频播放卡顿
                                  playerController.volume = volume.clamp(
                                    0.0,
                                    playerController.volumeUpperBound,
                                  );
                                  _applyVolumeThrottled(
                                    playerController.volume,
                                  );
                                }
                              },
                          onVerticalDragEnd: (_) {
                            if (playerController.volumeSeeking) {
                              playerController.volumeSeeking = false;
                              // 节流窗口内被跳过的最后一次音量变化在此补上，
                              // 确保实际音量与 HUD 显示一致
                              playerController.setVolume(
                                playerController.volume,
                              );
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

class AmbientShaderVideo extends StatefulWidget {
  final PlayerController controller;

  const AmbientShaderVideo({super.key, required this.controller});

  @override
  State<AmbientShaderVideo> createState() => _AmbientShaderVideoState();
}

class _AmbientShaderVideoState extends State<AmbientShaderVideo> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1.1,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 40,
          sigmaY: 40,
          tileMode: TileMode.mirror,
        ),
        child: ShaderMask(
          shaderCallback: (bounds) {
            return RadialGradient(
              center: Alignment.center,
              radius: 0.6,
              colors: [Colors.transparent, Colors.black.toOpacity(0.15)],
              stops: [0.0, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.multiply,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              1.05,
              0,
              0,
              0,
              0,
              0,
              1.05,
              0,
              0,
              0,
              0,
              0,
              1.05,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Stack(
              children: [
                Video(
                  controller: widget.controller.playerController,
                  fit: BoxFit.cover,
                  controls: null,
                ),
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.2),
                        Color.fromRGBO(0, 0, 0, 0.5),
                        Color.fromRGBO(0, 0, 0, 0.7),
                      ],
                      stops: [0.0, 0.6, 0.85, 1.0],
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
}

/// 更多面板里的设置卡片：图标 + 标题 + 自定义内容（卡片风格）
class _MoreSettingCard extends StatelessWidget {
  const _MoreSettingCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;

  final String title;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 更多面板里的开关卡片：图标 + 标题 + 开关（卡片风格）
class _MoreSwitchCard extends StatefulWidget {
  const _MoreSwitchCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;

  final String title;

  final bool value;

  final ValueChanged<bool> onChanged;

  @override
  State<_MoreSwitchCard> createState() => _MoreSwitchCardState();
}

class _MoreSwitchCardState extends State<_MoreSwitchCard> {
  late bool _value = widget.value;

  @override
  void didUpdateWidget(covariant _MoreSwitchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              CustomSwitch(
                value: _value,
                onChanged: (v) {
                  setState(() => _value = v);
                  widget.onChanged(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
