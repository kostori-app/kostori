import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/player_hud.dart';

class PlayerItemBasePanel extends StatefulWidget {
  const PlayerItemBasePanel({
    super.key,
    required this.playerController,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.currentPosition,
    required this.buffer,
    required this.duration,
  });

  final PlayerController playerController;
  final AnimationController animationController;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;

  final Duration currentPosition;
  final Duration buffer;
  final Duration duration;

  @override
  State<PlayerItemBasePanel> createState() => _PlayerItemBasePanelState();
}

class _PlayerItemBasePanelState extends State<PlayerItemBasePanel> {
  PlayerController get playerController => widget.playerController;
  late final Animation<double> fadeAnimation;

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
            // 底部进度条
            AnimatedOpacity(
              opacity:
                  ((!playerController.isFullScreen &&
                          !playerController.showVideoController) ||
                      playerController.isSeek)
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 底部渐变层
                    _SeekGradientLayer(isSeek: playerController.isSeek),

                    _SeekProgressBar(
                      isSeek: playerController.isSeek,
                      currentPosition: widget.currentPosition,
                      buffer: widget.buffer,
                      duration: widget.duration,
                      onSeek: (duration) => playerController.seek(duration),
                      onDragStart: widget.handleProgressBarDragStart,
                      onDragUpdate: (details) =>
                          playerController.currentPosition = details.timeStamp,
                      onDragEnd: widget.handleProgressBarDragEnd,
                    ),
                  ],
                ),
              ),
            ),
            // 中央加载/缓冲覆盖层
            _PlayerCenterOverlay(playerController: playerController),
            // 截图进度提示（底部控制栏上方）
            _ScreenshotStatusOverlay(playerController: playerController),
            // 快进/快退 HUD（左右滑动时显示）
            Positioned(
              top: playerHudTop(
                isPortraitFullscreen: playerController.isPortraitFullscreen,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: playerController.showSeekTime
                    ? _SeekHUD(playerController: playerController)
                    : const SizedBox.shrink(key: ValueKey('emptySeek')),
              ),
            ),
            // 顶部播放速度条
            Positioned(
              top: playerHudTop(
                isPortraitFullscreen: playerController.isPortraitFullscreen,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerController.showPlaySpeed
                    ? Wrap(
                        key: const ValueKey('playSpeed'),
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
                                AnimatedPlayIconWave(
                                  size: 14,
                                  count: playerController.playbackSpeed.toInt(),
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
                    : const SizedBox.shrink(key: ValueKey('emptySpeed')),
              ),
            ),
            // 亮度/音量 HUD（共用一个组件，切换时进度平滑联动）
            Positioned(
              top: playerHudTop(
                isPortraitFullscreen: playerController.isPortraitFullscreen,
              ),
              child: _LevelSliderHUD(playerController: playerController),
            ),
          ],
        );
      },
    );
  }
}

// 新建两个小 Widget，分别对应渐变层和进度条

class _SeekGradientLayer extends StatefulWidget {
  const _SeekGradientLayer({required this.isSeek});
  final bool isSeek;

  @override
  State<_SeekGradientLayer> createState() => _SeekGradientLayerState();
}

class _SeekGradientLayerState extends State<_SeekGradientLayer> {
  late Tween<double> _tween;

  @override
  void initState() {
    super.initState();
    // 初始化时根据当前状态决定起点
    _tween = Tween<double>(
      begin: widget.isSeek ? 0.0 : 1.0,
      end: widget.isSeek ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_SeekGradientLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只在 isSeek 真正改变时才更新 tween
    if (oldWidget.isSeek != widget.isSeek) {
      _tween = Tween<double>(
        begin: widget.isSeek ? 0.0 : 1.0,
        end: widget.isSeek ? 1.0 : 0.0,
      );
    }
    // isSeek 没变 → _tween 对象引用不变 → TweenAnimationBuilder 不会重启动画
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      tween: _tween, // ← 引用稳定，只在 isSeek 变化时才是新对象
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.toOpacity(0.1),
                  Colors.black.toOpacity(0.25),
                  Colors.black.toOpacity(0.45),
                  Colors.black.toOpacity(0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.toOpacity(0.15),
                  blurRadius: 10.0,
                  spreadRadius: 2.0,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 播放器中央覆盖层：加载/缓冲信息与少量中央提示（如「没有更多剧集」）
/// 共用同一张卡片。自动连播下一集不再单独弹提示层，而是把加载主文案
/// 切为「正在加载下一集」，加载结束自动恢复「正在加载视频」。
class _PlayerCenterOverlay extends StatelessWidget {
  const _PlayerCenterOverlay({required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final controller = playerController;
        final hint = controller.centerHintMessage;
        final hasHint = hint != null && hint.isNotEmpty;
        // 真实缓冲状态：media_kit 的 buffering 流实时驱动 isBuffering，
        // state.buffering 是实时快照；二者同源。
        // loadFailed 时隐藏（失败后 buffering 快照可能仍为 true）
        final buffering = controller.isBuffering || controller.playerBuffering;
        final loading =
            !controller.loadFailed &&
            (buffering ||
                (controller.loadingStep == 0 && controller.isParsing));
        if (!hasHint && !loading) return const SizedBox.shrink();

        final success = controller.centerHintSuccess;
        // 有中央提示（无更多剧集/加载失败）时优先显示；
        // 否则显示加载文案：自动连播下一集时用「正在加载下一集」，
        // 加载结束后 loadingNextEpisode 复位，恢复「正在加载视频」
        final message = hasHint
            ? hint
            : (controller.loadingNextEpisode
                  ? t.loadingNextEpisode
                  : t.loadingVideo);
        final stepText = switch (controller.loadingStep) {
          0 => t.loadingStepParse,
          1 => t.loadingStepInit,
          2 => t.loadingStepLoad,
          _ => t.loadingStepBuffer,
        };
        // 缓冲/加载中优先用加载动效；仅提示（无缓冲）时用成功/警告动效
        final showLoadingVisual = buffering || !hasHint;

        return IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.toOpacity(0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showLoadingVisual)
                    const _LoadingImage()
                  else
                    Gif(
                      image: AssetImage(
                        success
                            ? 'assets/img/check.gif'
                            : 'assets/img/warning.gif',
                      ),
                      height: 80,
                      fps: 120,
                      color: success
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      autostart: Autostart.once,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // 缓冲步骤：仅在无提示文案时补充显示，合并进同一张卡片
                  if (loading && !hasHint) ...[
                    const SizedBox(height: 8),
                    Text(
                      stepText,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 截图进行中的提示：播放器内底部（控制栏上方），样式与 showMessage 一致。
class _ScreenshotStatusOverlay extends StatelessWidget {
  const _ScreenshotStatusOverlay({required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final message = playerController.screenshotStatusMessage;
        if (message == null || message.isEmpty) {
          return const SizedBox.shrink();
        }
        final cs = Theme.of(context).colorScheme;
        final ok = playerController.screenshotStatusOk;
        final accent = ok == false
            ? const Color(0xFFFF5449)
            : ok == true
            ? const Color(0xFF4CAF50)
            : cs.primary;
        final icon = ok == false
            ? Icons.error_outline_rounded
            : ok == true
            ? Icons.check_circle_outline_rounded
            : Icons.photo_camera_outlined;
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // 位于底部控制栏上方，避免与进度条/按钮重合
              padding: EdgeInsets.only(
                bottom: playerController.showVideoController ? 96 : 32,
              ),
              child: BlurEffect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer.toOpacity(0.62),
                    border: Border(left: BorderSide(color: accent, width: 4)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(icon, color: accent, size: 18),
                        ),
                        Flexible(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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

/// 亮度 / 音量 HUD：共用一个组件，切换（亮度↔音量）时进度平滑联动
class _LevelSliderHUD extends StatelessWidget {
  const _LevelSliderHUD({required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final showBrightness = playerController.showBrightness;
        final showVolume = playerController.showVolume;
        if (!showBrightness && !showVolume) {
          return const SizedBox.shrink();
        }
        final isBrightness = showBrightness;
        // 当前目标值（0-100）
        final targetValue = isBrightness
            ? (playerController.brightness * 100)
            : playerController.volume;
        return PlayerLevelHud(isBrightness: isBrightness, value: targetValue);
      },
    );
  }
}

/// 快进 / 快退 HUD（左右滑动时显示）——复用共享的 [PlayerSeekHud]
class _SeekHUD extends StatelessWidget {
  const _SeekHUD({required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return PlayerSeekHud(
          target: playerController.currentPosition,
          current: playerController.player.state.position,
          total: playerController.duration,
        );
      },
    );
  }
}

/// 加载动效：优先自定义 GIF/动图，无配置时用转圈兜底
class _LoadingImage extends StatelessWidget {
  const _LoadingImage();

  /// 用户自定义 loading 图片（data:/file:/http/asset gif 均可）
  String? get _customImage {
    final v = appdata.implicitData['playerLoadingImage'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final custom = _customImage;
    if (custom == null) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: PolygonRefreshIndicator(),
      );
    }

    // asset 路径（如 assets/img/loading.gif）
    if (custom.startsWith('assets/')) {
      return Gif(
        image: AssetImage(custom),
        height: 64,
        fps: 60,
        autostart: Autostart.loop,
      );
    }

    // data: base64
    if (custom.startsWith('data:')) {
      final raw = custom.split(',').last;
      final bytes = base64Decode(raw);
      final isGif = raw.startsWith('/9j') == false && _looksLikeGif(bytes);
      if (isGif) {
        return Gif(
          image: MemoryImage(bytes),
          height: 64,
          fps: 60,
          autostart: Autostart.loop,
        );
      }
      return Image.memory(bytes, width: 64, height: 64, fit: BoxFit.contain);
    }

    // file: 或 http(s) URL
    return _NetworkOrFileImage(path: custom, width: 64, height: 64);
  }

  static bool _looksLikeGif(Uint8List bytes) {
    if (bytes.length < 6) return false;
    return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
  }
}

/// 加载本地文件或网络图片（优先动图）
class _NetworkOrFileImage extends StatelessWidget {
  const _NetworkOrFileImage({
    required this.path,
    required this.width,
    required this.height,
  });

  final String path;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bytes = _resolvePath(path);
    if (bytes != null) {
      final isGif =
          bytes.length >= 6 &&
          bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46;
      if (isGif) {
        return Gif(
          image: MemoryImage(bytes),
          width: width,
          height: height,
          fps: 60,
          autostart: Autostart.loop,
        );
      }
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.contain,
      );
    }

    // 网络图片
    return Image.network(
      path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => const SizedBox(
        width: 48,
        height: 48,
        child: PolygonRefreshIndicator(),
      ),
    );
  }

  static Uint8List? _resolvePath(String path) {
    if (path.startsWith('file://')) {
      try {
        final f = File(path.substring(7));
        if (f.existsSync()) return f.readAsBytesSync();
      } catch (_) {}
    }
    return null;
  }
}

class _SeekProgressBar extends StatefulWidget {
  const _SeekProgressBar({
    required this.isSeek,
    required this.currentPosition,
    required this.buffer,
    required this.duration,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool isSeek;
  final Duration currentPosition;
  final Duration buffer;
  final Duration duration;
  final void Function(Duration) onSeek;
  final void Function(ThumbDragDetails) onDragStart;
  final void Function(ThumbDragDetails) onDragUpdate;
  final void Function() onDragEnd;

  @override
  State<_SeekProgressBar> createState() => _SeekProgressBarState();
}

class _SeekProgressBarState extends State<_SeekProgressBar> {
  late Tween<double> _tween;

  @override
  void initState() {
    super.initState();
    _tween = Tween<double>(
      begin: widget.isSeek ? 0.0 : 1.0,
      end: widget.isSeek ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_SeekProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSeek != widget.isSeek) {
      _tween = Tween<double>(
        begin: widget.isSeek ? 0.0 : 1.0,
        end: widget.isSeek ? 1.0 : 0.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      tween: _tween,
      builder: (context, value, child) {
        return ProgressBar(
          thumbRadius: 6 * value,
          thumbGlowRadius: 0,
          barHeight: 2 + 2 * value,
          progressBarColor: Theme.of(context).colorScheme.primary
              .toOpacity(0.72),
          bufferedBarColor: Theme.of(context).colorScheme.primary
              .toOpacity(0.36),
          baseBarColor: Theme.of(context).colorScheme.primary.toOpacity(0.2),
          timeLabelLocation: TimeLabelLocation.none,
          progress: widget.currentPosition,
          buffered: widget.buffer,
          total: widget.duration,
          onSeek: widget.onSeek,
          onDragStart: widget.onDragStart,
          onDragUpdate: widget.onDragUpdate,
          onDragEnd: widget.onDragEnd,
        );
      },
    );
  }
}
