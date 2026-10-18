import 'dart:math' as math;

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';

/// Progress bar shared by the two video players.
///
/// The package widget keeps its hit testing and thumb behaviour. A custom
/// painter draws the base, buffered and played tracks, then animates a short
/// highlight across the tail immediately before the playhead.
class PlayerProgressBar extends StatefulWidget {
  const PlayerProgressBar({
    super.key,
    required this.progress,
    required this.total,
    this.buffered,
    this.onSeek,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.barHeight = 5,
    this.thumbRadius = 10,
    this.thumbGlowRadius = 30,
    this.showThumb = true,
    this.baseBarColor,
    this.bufferedBarColor,
    this.progressBarColor,
    this.thumbColor,
    this.thumbGlowColor,
    this.gradient,
    this.gradientTailFraction = 0.36,
    this.timeLabelLocation,
    this.timeLabelTextStyle,
  });

  final Duration progress;
  final Duration total;
  final Duration? buffered;
  final ValueChanged<Duration>? onSeek;
  final ThumbDragStartCallback? onDragStart;
  final ThumbDragUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;
  final double barHeight;
  final double thumbRadius;
  final double thumbGlowRadius;
  final bool showThumb;
  final Color? baseBarColor;
  final Color? bufferedBarColor;
  final Color? progressBarColor;
  final Color? thumbColor;
  final Color? thumbGlowColor;
  final Gradient? gradient;
  final double gradientTailFraction;
  final TimeLabelLocation? timeLabelLocation;
  final TextStyle? timeLabelTextStyle;

  @override
  State<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends State<PlayerProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progressColor = widget.progressBarColor ?? colors.primary;
    final baseColor =
        widget.baseBarColor ?? colors.onSurface.withValues(alpha: 0.2);
    final bufferedColor =
        widget.bufferedBarColor ?? colors.primary.withValues(alpha: 0.32);

    return AnimatedBuilder(
      animation: _flowController,
      builder: (context, child) {
        // Use a periodic sine phase instead of the raw repeating controller
        // value. The endpoints have the same visual state, so the stream does
        // not flash when the animation controller starts its next cycle.
        final cycle = _flowController.value * math.pi * 2;
        final phase = (math.sin(cycle) + 1) / 2;
        final bufferedPhase = (math.sin(cycle + 0.9) + 1) / 2;
        // The package progress bar can only paint the thumb with one solid
        // colour. Keep its thumb transparent and paint our own animated
        // gradient thumb above it, so the playhead uses the same moving
        // colour treatment as the track.
        final playheadColor = widget.thumbColor ?? const Color(0xFF42C9D0);
        final playheadGlow =
            widget.thumbGlowColor ?? playheadColor.withValues(alpha: 0.42);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PlayerProgressTrackPainter(
                  progress: widget.progress,
                  buffered: widget.buffered ?? Duration.zero,
                  total: widget.total,
                  barHeight: widget.barHeight,
                  baseColor: baseColor,
                  bufferedColor: bufferedColor,
                  progressColor: progressColor,
                  progressGradient: widget.gradient,
                  gradientTailFraction: widget.gradientTailFraction,
                  flowProgress: phase,
                  bufferedFlowProgress: bufferedPhase,
                ),
              ),
            ),
            ProgressBar(
              progress: widget.progress,
              buffered: widget.buffered,
              total: widget.total,
              progressBarColor: Colors.transparent,
              baseBarColor: Colors.transparent,
              bufferedBarColor: Colors.transparent,
              thumbColor: Colors.transparent,
              thumbGlowColor: Colors.transparent,
              barHeight: widget.barHeight,
              thumbRadius: widget.thumbRadius,
              thumbGlowRadius: widget.thumbGlowRadius,
              timeLabelLocation: widget.timeLabelLocation,
              timeLabelTextStyle: widget.timeLabelTextStyle,
              onSeek: widget.onSeek,
              onDragStart: widget.onDragStart,
              onDragUpdate: widget.onDragUpdate,
              onDragEnd: widget.onDragEnd,
            ),
            if (widget.showThumb)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PlayerProgressThumbPainter(
                      progress: widget.progress,
                      total: widget.total,
                      barHeight: widget.barHeight,
                      thumbRadius: widget.thumbRadius,
                      thumbGlowRadius: widget.thumbGlowRadius,
                      thumbColor: playheadColor,
                      thumbGlowColor: playheadGlow,
                      flowProgress: _flowController.value,
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

/// Paints the playhead because [ProgressBar] only accepts a solid thumb color.
/// The shader repeats exactly once across the circle, so the animation can
/// wrap without a visible flash at the end of a cycle.
class _PlayerProgressThumbPainter extends CustomPainter {
  const _PlayerProgressThumbPainter({
    required this.progress,
    required this.total,
    required this.barHeight,
    required this.thumbRadius,
    required this.thumbGlowRadius,
    required this.thumbColor,
    required this.thumbGlowColor,
    required this.flowProgress,
  });

  final Duration progress;
  final Duration total;
  final double barHeight;
  final double thumbRadius;
  final double thumbGlowRadius;
  final Color thumbColor;
  final Color thumbGlowColor;
  final double flowProgress;

  double _ratio() => total.inMilliseconds <= 0
      ? 0
      : (progress.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final trackWidth = (size.width - barHeight).clamp(0.0, size.width);
    final center = Offset(
      barHeight / 2 + trackWidth * _ratio(),
      size.height / 2,
    );

    if (thumbGlowRadius > 0) {
      final glowRect = Rect.fromCircle(center: center, radius: thumbGlowRadius);
      final glowColor = Color.lerp(
        thumbGlowColor,
        const Color(0xFF4E8FEA).withValues(alpha: thumbGlowColor.a),
        0.35,
      )!;
      canvas.drawCircle(
        center,
        thumbGlowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glowColor.withValues(alpha: glowColor.a * 0.48),
              glowColor.withValues(alpha: glowColor.a * 0.12),
              Colors.transparent,
            ],
            stops: const [0, 0.45, 1],
          ).createShader(glowRect),
      );
    }

    final radius = thumbRadius.clamp(0.0, size.height / 2);
    if (radius <= 0) return;
    final diameter = radius * 2;
    final period = math.max(diameter, 12.0);
    final offset = flowProgress * period;
    final shaderRect = Rect.fromLTWH(
      center.dx - radius - period + offset,
      center.dy - radius,
      period,
      diameter,
    );
    final colors = <Color>[
      Color.lerp(thumbColor, const Color(0xFF3F7FF0), 0.72)!,
      Color.lerp(thumbColor, const Color(0xFF25C6E4), 0.58)!,
      Color.lerp(thumbColor, const Color(0xFF3AD1B5), 0.68)!,
      Color.lerp(thumbColor, const Color(0xFF756DE8), 0.62)!,
      Color.lerp(thumbColor, const Color(0xFF3F7FF0), 0.72)!,
    ];
    final shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: colors,
      stops: const [0, 0.24, 0.5, 0.76, 1],
      tileMode: TileMode.repeated,
    ).createShader(shaderRect);
    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _PlayerProgressThumbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.total != total ||
      oldDelegate.barHeight != barHeight ||
      oldDelegate.thumbRadius != thumbRadius ||
      oldDelegate.thumbGlowRadius != thumbGlowRadius ||
      oldDelegate.thumbColor != thumbColor ||
      oldDelegate.thumbGlowColor != thumbGlowColor ||
      oldDelegate.flowProgress != flowProgress;
}

class _PlayerProgressTrackPainter extends CustomPainter {
  const _PlayerProgressTrackPainter({
    required this.progress,
    required this.buffered,
    required this.total,
    required this.barHeight,
    required this.baseColor,
    required this.bufferedColor,
    required this.progressColor,
    required this.progressGradient,
    required this.gradientTailFraction,
    required this.flowProgress,
    required this.bufferedFlowProgress,
  });

  final Duration progress;
  final Duration buffered;
  final Duration total;
  final double barHeight;
  final Color baseColor;
  final Color bufferedColor;
  final Color progressColor;
  final Gradient? progressGradient;
  final double gradientTailFraction;
  final double flowProgress;
  final double bufferedFlowProgress;

  double _ratio(Duration value) => total.inMilliseconds <= 0
      ? 0
      : (value.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = barHeight / 2;
    final trackWidth = (size.width - barHeight).clamp(0.0, size.width);
    final left = radius;
    final top = (size.height - barHeight) / 2;
    final track = Rect.fromLTWH(left, top, trackWidth, barHeight);
    final corner = Radius.circular(radius);

    canvas.drawRRect(
      RRect.fromRectAndRadius(track, corner),
      Paint()..color = baseColor,
    );

    final bufferedWidth = trackWidth * _ratio(buffered);
    final progressWidth = trackWidth * _ratio(progress);
    if (bufferedWidth > 0) {
      final bufferedEnd = left + bufferedWidth;
      final bufferedTrack = Rect.fromLTRB(
        left,
        top,
        bufferedEnd,
        top + barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bufferedTrack, corner),
        Paint()..color = bufferedColor,
      );

      // 缓存段使用更慢、更低饱和的蓝青流光，并且只覆盖播放点之后的
      // 未播放缓存区，和已播放段的彩色流光保持清晰区分。
      final bufferedFlowStart = math.max(left, left + progressWidth);
      final bufferedFlowWidth = bufferedEnd - bufferedFlowStart;
      if (bufferedFlowWidth > 0.5) {
        final patternWidth = math.max(32.0, bufferedFlowWidth * 0.8);
        final flowOffset = bufferedFlowProgress * patternWidth;
        final flowRect = Rect.fromLTRB(
          bufferedFlowStart - patternWidth + flowOffset,
          top,
          bufferedFlowStart + flowOffset,
          top + barHeight,
        );
        final mutedBlue = Color.lerp(
          bufferedColor,
          const Color(0xFF4E83D8),
          0.55,
        )!;
        final mutedTeal = Color.lerp(
          bufferedColor,
          const Color(0xFF39B9B0),
          0.5,
        )!;
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(bufferedTrack, corner));
        canvas.drawRect(
          Rect.fromLTRB(bufferedFlowStart, top, bufferedEnd, top + barHeight),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                mutedBlue.withValues(alpha: 0.2),
                mutedTeal.withValues(alpha: 0.56),
                mutedBlue.withValues(alpha: 0.2),
              ],
              stops: const [0, 0.5, 1],
              tileMode: TileMode.repeated,
            ).createShader(flowRect),
        );
        canvas.restore();
      }
    }

    if (progressWidth > 0) {
      final playedEnd = left + progressWidth;
      final tailWidth =
          trackWidth * gradientTailFraction.clamp(0.0, 1.0).toDouble();
      final tailStart = (playedEnd - tailWidth)
          .clamp(left, playedEnd)
          .toDouble();
      // Paint the entire played track first. The animated highlight is then
      // blended over this continuous shape, rather than being joined to a
      // second rounded rectangle at tailStart.
      final played = Rect.fromLTRB(left, top, playedEnd, top + barHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(played, corner),
        Paint()..color = progressColor,
      );
      final gradientTail = Rect.fromLTRB(
        tailStart,
        top,
        playedEnd,
        top + barHeight,
      );
      if (progressGradient != null) {
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(played, corner));
        canvas.drawRect(
          gradientTail,
          Paint()..shader = progressGradient!.createShader(gradientTail),
        );
        canvas.restore();
      } else {
        // Fade a moving colour stream into the played track. Keep the effect
        // inside the thin bar so it never grows into a set of vertical bars.
        canvas.save();
        canvas.clipRRect(RRect.fromRectAndRadius(played, corner));
        canvas.saveLayer(gradientTail, Paint());
        final opacityFade = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 1),
          ],
          stops: const [0, 0.18, 0.62, 1],
        );
        canvas.drawRect(
          gradientTail,
          Paint()..shader = opacityFade.createShader(gradientTail),
        );

        // Several quiet blue/cyan/teal/violet tones give the same colourful
        // stream as the earlier version. Moving the shader horizontally makes
        // the colours flow instead of leaving a fixed rainbow in place.
        final colorBlue = Color.lerp(
          progressColor,
          const Color(0xFF3F7FF0),
          0.9,
        )!;
        final colorCyan = Color.lerp(
          progressColor,
          const Color(0xFF25C6E4),
          0.9,
        )!;
        final colorTeal = Color.lerp(
          progressColor,
          const Color(0xFF3AD1B5),
          0.88,
        )!;
        final colorViolet = Color.lerp(
          progressColor,
          const Color(0xFF6E66E8),
          0.84,
        )!;
        // The shader repeats at exactly this width. Moving it by one whole
        // period during one controller cycle makes the reset frame identical
        // to the first frame, so the stream never jumps or refreshes halfway.
        final patternWidth = math.max(28.0, tailWidth * 0.64);
        final flowOffset = flowProgress * patternWidth;
        final colorRect = Rect.fromLTRB(
          tailStart - patternWidth + flowOffset,
          top,
          tailStart + flowOffset,
          top + barHeight,
        );
        final colorFlow = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [colorBlue, colorCyan, colorTeal, colorViolet, colorBlue],
          stops: const [0, 0.25, 0.5, 0.76, 1],
          tileMode: TileMode.repeated,
        );
        canvas.drawRect(
          gradientTail,
          Paint()
            ..shader = colorFlow.createShader(colorRect)
            ..blendMode = BlendMode.srcIn,
        );
        canvas.restore();
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerProgressTrackPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.buffered != buffered ||
      oldDelegate.total != total ||
      oldDelegate.barHeight != barHeight ||
      oldDelegate.baseColor != baseColor ||
      oldDelegate.bufferedColor != bufferedColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.progressGradient != progressGradient ||
      oldDelegate.gradientTailFraction != gradientTailFraction ||
      oldDelegate.flowProgress != flowProgress ||
      oldDelegate.bufferedFlowProgress != bufferedFlowProgress;
}
