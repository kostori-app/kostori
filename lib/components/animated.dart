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
