import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/watcher/player_controller.dart';

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
            // 视频加载信息覆盖层
            _VideoLoadingOverlay(
              playerController: playerController,
              duration: widget.duration,
            ),
            // 快进/快退 HUD（左右滑动时显示）
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
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
              top: playerController.isPortraitFullscreen ? 140 : 50,
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
              top: playerController.isPortraitFullscreen ? 140 : 50,
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

/// 自定义加载覆盖层：替代 media_kit 默认缓冲转圈。
/// 居中显示自定义 loading 图片（GIF/动图，从配置读取）+ "正在加载"信息。
class _VideoLoadingOverlay extends StatelessWidget {
  const _VideoLoadingOverlay({
    required this.playerController,
    required this.duration,
  });

  final PlayerController playerController;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: _LoadingInfoCard(playerController: playerController),
    );
  }
}

/// 亮度 / 音量 HUD：共用一个组件，切换（亮度↔音量）时进度平滑联动
class _LevelSliderHUD extends StatelessWidget {
  const _LevelSliderHUD({required this.playerController});

  final PlayerController playerController;

  // 亮度用暖色、音量用冷色，作视觉区分
  static const _brightnessColor = Color(0xFFF5A623);
  static const _volumeColor = Color(0xFF4DB6FF);

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final showBrightness = playerController.showBrightness;
        final showVolume = playerController.showVolume;
        if (!showBrightness && !showVolume) {
          return const SizedBox.shrink();
        }

        // 当前目标值（0-100）
        final isBrightness = showBrightness;
        final targetValue = isBrightness
            ? (playerController.brightness * 100)
            : playerController.volume;
        final accent = isBrightness ? _brightnessColor : _volumeColor;

        // 图标按等级切换（动画在 _LevelIcon 内处理）
        final icon = isBrightness
            ? Icons.brightness_7_rounded
            : (targetValue <= 0
                  ? Icons.volume_off_rounded
                  : targetValue < 50
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded);

        return IgnorePointer(
          child: _FrostedGlass(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LevelIcon(icon: icon, color: accent),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  height: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(color: Colors.white.toOpacity(0.15)),
                        // 从当前宽度平滑过渡，不会从 0 弹起
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 110 * (targetValue.clamp(0, 100) / 100),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: accent.toOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${targetValue.round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 磨砂玻璃容器：模糊背景 + 深色半透明底 + 圆角边框
class _FrostedGlass extends StatelessWidget {
  const _FrostedGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.toOpacity(0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.toOpacity(0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.toOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 快进 / 快退 HUD（左右滑动时显示）
class _SeekHUD extends StatelessWidget {
  const _SeekHUD({required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final target = playerController.currentPosition;
        final current = playerController.player.state.position;
        final total = playerController.duration;
        final isForward = target > current;
        final diffSec = (target - current).inSeconds.abs().clamp(0, 999);
        final totalSec = total.inSeconds > 0 ? total.inSeconds : 1;
        final progress = (target.inMilliseconds / (totalSec * 1000)).clamp(
          0.0,
          1.0,
        );

        // 方向配色：快进青绿 / 快退橙红
        final accent = isForward
            ? const Color(0xFF2ED8A7)
            : const Color(0xFFFF7A6B);
        final icon = isForward
            ? Icons.fast_forward_rounded
            : Icons.fast_rewind_rounded;

        return IgnorePointer(
          child: _FrostedGlass(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isForward
                          ? t.seekForward(s: diffSec)
                          : t.seekBackward(s: diffSec),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 目标时间 + 总时长
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmt(target),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' / ${_fmt(total)}',
                          style: TextStyle(
                            color: Colors.white.toOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: Stack(
                          children: [
                            Container(color: Colors.white.toOpacity(0.15)),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(color: accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// 带切换动画的图标（切换时缩放 + 淡入，模拟"点亮"）
class _LevelIcon extends StatelessWidget {
  const _LevelIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Icon(icon, key: ValueKey(icon), color: color, size: 22),
    );
  }
}

/// 加载信息卡片：居中显示
class _LoadingInfoCard extends StatelessWidget {
  const _LoadingInfoCard({required this.playerController});

  final PlayerController playerController;

  /// 用户自定义 loading 图片（data:/file:/http/asset gif 均可）
  String? get _customImage {
    final v = appdata.implicitData['playerLoadingImage'];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        // 真实缓冲状态：media_kit 的 buffering 流实时驱动 isBuffering，
        // state.buffering 是实时快照；二者同源。loading 是历史遗留字段（恒 true）弃用。
        final buffering =
            playerController.isBuffering || playerController.playerBuffering;
        final step = playerController.loadingStep;
        // 只显示"正在加载"（不显示集名：部分集名过长影响观感）
        final loadingText = t.loadingVideo;

        // 当前加载步骤文案（只显示一条：正在进行的步骤）
        final stepText = switch (step) {
          0 => t.loadingStepParse,
          1 => t.loadingStepInit,
          2 => t.loadingStepLoad,
          _ => t.loadingStepBuffer,
        };

        // 显示条件：真正在缓冲，或正在解析视频地址。
        // 不用「未播放且步骤<3」——解析失败或暂停时 step 停留会导致误导。
        // loadFailed 时隐藏（失败后 buffering 快照可能仍为 true）
        final showOverlay = !playerController.loadFailed &&
            (buffering || (step == 0 && playerController.isParsing));
        if (!showOverlay) return const SizedBox.shrink();

        return Align(
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
                _buildLoadingImage(context),
                const SizedBox(height: 10),
                Text(
                  loadingText,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  stepText,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 加载图片：优先自定义 GIF/动图，无配置时用转圈兜底
  Widget _buildLoadingImage(BuildContext context) {
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
          progressBarColor: Theme.of(
            context,
          ).colorScheme.primary.toOpacity(0.72),
          bufferedBarColor: Theme.of(
            context,
          ).colorScheme.primary.toOpacity(0.36),
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
