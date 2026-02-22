import 'dart:math';

import 'package:flutter/material.dart';
import 'package:markdown_widget/config/all.dart';

class AnimatedPlayIconWave extends StatefulWidget {
  final double size;
  final int count;

  const AnimatedPlayIconWave({super.key, this.size = 24, this.count = 2});

  @override
  State<AnimatedPlayIconWave> createState() => _AnimatedPlayIconWaveState();
}

class _AnimatedPlayIconWaveState extends State<AnimatedPlayIconWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;

        final iconCount = widget.count > 2 ? 3 : 2;

        final opacities = List.generate(iconCount, (index) {
          final phase = -index * 0.3;
          final adjustedProgress = (progress + phase) % 1.0;

          final waveValue = sin(adjustedProgress * 2 * pi) * 0.5 + 0.5;
          return 0.3 + 0.7 * waveValue;
        });

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < iconCount; i++)
              _buildCustomIcon(opacities[i], color),
          ],
        );
      },
    );
  }

  Widget _buildCustomIcon(double opacity, Color color) {
    return CustomPaint(
      size: Size(widget.size, widget.size),
      painter: _RoundedEquilateralTrianglePainter(
        color: color,
        opacity: opacity,
        cornerRadius: widget.size * 0.2,
      ),
    );
  }
}

class _RoundedEquilateralTrianglePainter extends CustomPainter {
  final Color color;
  final double opacity;
  final double cornerRadius;

  _RoundedEquilateralTrianglePainter({
    required this.color,
    this.opacity = 1.0,
    this.cornerRadius = 4.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.toOpacity(opacity)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final double sideLength = size.width;
    final double height = sideLength * sqrt(3) / 2;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    final p1 = Offset(centerX - height / 2, centerY - sideLength / 2);
    final p2 = Offset(centerX - height / 2, centerY + sideLength / 2);
    final p3 = Offset(centerX + height / 2 - size.width * 0.1, centerY);

    final path = Path();
    _addRoundedTriangle(path, p1, p2, p3, cornerRadius);
    canvas.drawPath(path, paint);
  }

  void _addRoundedTriangle(
    Path path,
    Offset p1,
    Offset p2,
    Offset p3,
    double radius,
  ) {
    final points = [p1, p2, p3];

    for (int i = 0; i < 3; i++) {
      final current = points[i];
      final next = points[(i + 1) % 3];
      final prev = points[(i + 2) % 3];

      final v1 = Offset(current.dx - prev.dx, current.dy - prev.dy);
      final v2 = Offset(next.dx - current.dx, next.dy - current.dy);

      final len1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
      final len2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy);

      final u1 = Offset(v1.dx / len1, v1.dy / len1);
      final u2 = Offset(v2.dx / len2, v2.dy / len2);

      final start = Offset(
        current.dx - u1.dx * radius,
        current.dy - u1.dy * radius,
      );
      final end = Offset(
        current.dx + u2.dx * radius,
        current.dy + u2.dy * radius,
      );

      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }

      path.quadraticBezierTo(current.dx, current.dy, end.dx, end.dy);
    }

    path.close();
  }

  @override
  bool shouldRepaint(
    covariant _RoundedEquilateralTrianglePainter oldDelegate,
  ) => oldDelegate.color != color || oldDelegate.opacity != opacity;
}

class PolygonRefreshIndicator extends StatefulWidget {
  final double? size;

  const PolygonRefreshIndicator({super.key, this.size});

  @override
  _PolygonRefreshIndicatorState createState() =>
      _PolygonRefreshIndicatorState();
}

class _PolygonRefreshIndicatorState extends State<PolygonRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<int> _shapeSides = [4, 2, 6, 5, 8, 4, 1, 5, 10, 6, 2];

  final Map<int, Path> _polygonCache = {};
  final Path _capsulePath = Path();
  final Path _footballPath = Path();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double effectiveSize =
            widget.size ?? min(constraints.maxWidth, constraints.maxHeight);
        if (effectiveSize == double.infinity) effectiveSize = 50.0;

        _prepareCapsulePath(effectiveSize);
        _prepareFootballPath(effectiveSize);

        return AnimatedBuilder(
          animation: _controller,
          builder: (_, _) {
            double v = _controller.value;
            int totalStages = _shapeSides.length - 1;
            double stageInterval = 1.0 / totalStages;

            int index = (v / stageInterval).floor().clamp(0, totalStages - 1);
            double stageProgress = (v % stageInterval) / stageInterval;

            double rotateT = (stageProgress / 0.7).clamp(0.0, 1.0);
            double rotateCurve = const _CustomBackOutCurve(
              0.8,
            ).transform(rotateT);
            double rotationStep = 1.5 * pi;
            double rotation =
                (index * rotationStep) + (rotateCurve * rotationStep);

            bool isNextShape = stageProgress > 0.2;
            double currentSides = isNextShape
                ? _shapeSides[index + 1].toDouble()
                : _shapeSides[index].toDouble();

            double scaleT = (stageProgress / 0.8).clamp(0.0, 1.0);
            double scaleCurve = Curves.easeOutBack.transform(scaleT);
            double scale = 0.95 + (0.05 * scaleCurve);

            return Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: rotation,
                child: SizedBox(
                  width: effectiveSize,
                  height: effectiveSize,
                  child: CustomPaint(
                    painter: _OptimizedShapePainter(
                      sides: currentSides,
                      color: Theme.of(context).colorScheme.primary,
                      polygonCache: _polygonCache,
                      capsulePath: _capsulePath,
                      footballPath: _footballPath,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _prepareCapsulePath(double size) {
    final w = size * 0.65;
    final h = size * 0.45;
    final center = Offset(size / 2, size / 2);
    _capsulePath.reset();
    final rect = Rect.fromCenter(center: center, width: w, height: h);
    _capsulePath.addRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(h / 2)),
    );
  }

  void _prepareFootballPath(double size) {
    final w = size * 0.68;
    final h = size * 0.52;
    final center = Offset(size / 2, size / 2);
    _footballPath.reset();
    _footballPath.moveTo(center.dx - w / 2, center.dy);
    _footballPath.cubicTo(
      center.dx - w / 2,
      center.dy - h * 0.62,
      center.dx + w / 2,
      center.dy - h * 0.62,
      center.dx + w / 2,
      center.dy,
    );
    _footballPath.cubicTo(
      center.dx + w / 2,
      center.dy + h * 0.62,
      center.dx - w / 2,
      center.dy + h * 0.62,
      center.dx - w / 2,
      center.dy,
    );
    _footballPath.close();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _OptimizedShapePainter extends CustomPainter {
  final double sides;
  final Color color;

  final Map<int, Path> polygonCache;
  final Path capsulePath;
  final Path footballPath;

  _OptimizedShapePainter({
    required this.sides,
    required this.color,
    required this.polygonCache,
    required this.capsulePath,
    required this.footballPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.save();
    if (sides == 2) {
      canvas.drawPath(capsulePath, paint);
    } else if (sides == 1) {
      canvas.drawPath(footballPath, paint);
    } else {
      final int intSides = sides.toInt();
      if (!polygonCache.containsKey(intSides)) {
        polygonCache[intSides] = _buildPolygonPath(intSides, size);
      }
      canvas.drawPath(polygonCache[intSides]!, paint);
    }
    canvas.restore();
  }

  Path _buildPolygonPath(int sides, Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 * 0.85;
    final innerRadius = outerRadius * 0.55;
    int vertexCount = (sides * 2).round();
    if (vertexCount < 6) vertexCount = 6;
    double angleStep = (2 * pi) / vertexCount;

    for (int i = 0; i < vertexCount; i++) {
      double angle = (angleStep * i) - pi / 2;
      double r = (i % 2 == 0) ? outerRadius : innerRadius;
      final pCurr = Offset(
        center.dx + r * cos(angle),
        center.dy + r * sin(angle),
      );

      double anglePrev = (angleStep * (i - 1)) - pi / 2;
      double rPrev = ((i - 1) % 2 == 0) ? outerRadius : innerRadius;
      final pPrev = Offset(
        center.dx + rPrev * cos(anglePrev),
        center.dy + rPrev * sin(anglePrev),
      );

      double angleNext = (angleStep * (i + 1)) - pi / 2;
      double rNext = ((i + 1) % 2 == 0) ? outerRadius : innerRadius;
      final pNext = Offset(
        center.dx + rNext * cos(angleNext),
        center.dy + rNext * sin(angleNext),
      );

      const double cornerSize = 0.7;
      final start = Offset.lerp(pCurr, pPrev, cornerSize)!;
      final end = Offset.lerp(pCurr, pNext, cornerSize)!;

      if (i == 0) {
        path.moveTo(start.dx, start.dy);
      } else {
        path.lineTo(start.dx, start.dy);
      }
      path.quadraticBezierTo(pCurr.dx, pCurr.dy, end.dx, end.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _OptimizedShapePainter oldDelegate) =>
      oldDelegate.sides != sides || oldDelegate.color != color;
}

class _CustomBackOutCurve extends Curve {
  final double s;

  const _CustomBackOutCurve(this.s);

  @override
  double transformInternal(double t) {
    t = t - 1.0;
    return t * t * ((s + 1) * t + s) + 1.0;
  }
}
