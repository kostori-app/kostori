part of 'video_clip_editor.dart';

class _CropOverlay extends StatefulWidget {
  final Rect cropRect;
  final ValueChanged<Rect> onChanged;

  const _CropOverlay({required this.cropRect, required this.onChanged});

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  late Rect _rect;

  @override
  void initState() {
    super.initState();
    _rect = widget.cropRect;
  }

  @override
  void didUpdateWidget(_CropOverlay old) {
    super.didUpdateWidget(old);
    if (old.cropRect != widget.cropRect) {
      setState(() => _rect = widget.cropRect);
    }
  }

  void _update(Rect r) {
    final clamped = Rect.fromLTRB(
      r.left.clamp(0.0, 1.0),
      r.top.clamp(0.0, 1.0),
      r.right.clamp(0.0, 1.0),
      r.bottom.clamp(0.0, 1.0),
    );
    setState(() => _rect = clamped);
    widget.onChanged(_rect);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final sz = Size(c.maxWidth, c.maxHeight);
        final dr = Rect.fromLTWH(
          _rect.left * sz.width,
          _rect.top * sz.height,
          _rect.width * sz.width,
          _rect.height * sz.height,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(size: sz, painter: _CropMaskPainter(dr)),

            Positioned(
              left: dr.left,
              top: dr.top,
              width: dr.width,
              height: dr.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (d) => _handleMove(d, sz),
                onHorizontalDragUpdate: (d) => _handleMove(d, sz),
                onPanUpdate: (d) => _handleMove(d, sz),
                child: Container(color: Colors.transparent),
              ),
            ),

            _handle(dr.topLeft, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  (_rect.left + dx).clamp(0.0, _rect.right - 0.05),
                  (_rect.top + dy).clamp(0.0, _rect.bottom - 0.05),
                  _rect.right,
                  _rect.bottom,
                ),
              );
            }, corner: true),
            _handle(dr.topCenter, sz, (d) {
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  (_rect.top + dy).clamp(0.0, _rect.bottom - 0.05),
                  _rect.right,
                  _rect.bottom,
                ),
              );
            }),
            _handle(dr.topRight, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  (_rect.top + dy).clamp(0.0, _rect.bottom - 0.05),
                  (_rect.right + dx).clamp(_rect.left + 0.05, 1.0),
                  _rect.bottom,
                ),
              );
            }, corner: true),
            _handle(dr.centerLeft, sz, (d) {
              final dx = d.delta.dx / sz.width;
              _update(
                Rect.fromLTRB(
                  (_rect.left + dx).clamp(0.0, _rect.right - 0.05),
                  _rect.top,
                  _rect.right,
                  _rect.bottom,
                ),
              );
            }),
            _handle(dr.centerRight, sz, (d) {
              final dx = d.delta.dx / sz.width;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  _rect.top,
                  (_rect.right + dx).clamp(_rect.left + 0.05, 1.0),
                  _rect.bottom,
                ),
              );
            }),
            _handle(dr.bottomLeft, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  (_rect.left + dx).clamp(0.0, _rect.right - 0.05),
                  _rect.top,
                  _rect.right,
                  (_rect.bottom + dy).clamp(_rect.top + 0.05, 1.0),
                ),
              );
            }, corner: true),
            _handle(dr.bottomCenter, sz, (d) {
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  _rect.top,
                  _rect.right,
                  (_rect.bottom + dy).clamp(_rect.top + 0.05, 1.0),
                ),
              );
            }),
            _handle(dr.bottomRight, sz, (d) {
              final dx = d.delta.dx / sz.width;
              final dy = d.delta.dy / sz.height;
              _update(
                Rect.fromLTRB(
                  _rect.left,
                  _rect.top,
                  (_rect.right + dx).clamp(_rect.left + 0.05, 1.0),
                  (_rect.bottom + dy).clamp(_rect.top + 0.05, 1.0),
                ),
              );
            }, corner: true),
          ],
        );
      },
    );
  }

  void _handleMove(DragUpdateDetails d, Size sz) {
    final dx = d.delta.dx / sz.width;
    final dy = d.delta.dy / sz.height;
    _update(
      Rect.fromLTWH(
        (_rect.left + dx).clamp(0, 1.0 - _rect.width),
        (_rect.top + dy).clamp(0, 1.0 - _rect.height),
        _rect.width,
        _rect.height,
      ),
    );
  }

  Widget _handle(
    Offset pos,
    Size sz,
    void Function(DragUpdateDetails) onUpdate, {
    bool corner = false,
  }) {
    final hs = corner ? 36.0 : 28.0;
    final innerSz = corner ? 20.0 : 16.0;
    return Positioned(
      left: pos.dx - hs / 2,
      top: pos.dy - hs / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onUpdate,
        onVerticalDragUpdate: onUpdate,
        onHorizontalDragUpdate: onUpdate,
        child: SizedBox(
          width: hs,
          height: hs,
          child: Center(
            child: Container(
              width: innerSz,
              height: innerSz,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: corner ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: corner ? null : BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.blue.shade400,
                  width: corner ? 2.5 : 2.0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 3,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  final Rect rect;

  _CropMaskPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Paint()..color = Colors.black.withAlpha(140);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, rect.top), mask);
    canvas.drawRect(
      Rect.fromLTRB(0, rect.bottom, size.width, size.height),
      mask,
    );
    canvas.drawRect(Rect.fromLTRB(0, rect.top, rect.left, rect.bottom), mask);
    canvas.drawRect(
      Rect.fromLTRB(rect.right, rect.top, size.width, rect.bottom),
      mask,
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, border);

    final accent = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;
    const cl = 14.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final sx = corner.dx == rect.left ? 1 : -1;
      final sy = corner.dy == rect.top ? 1 : -1;
      canvas.drawLine(corner, Offset(corner.dx + sx * cl, corner.dy), accent);
      canvas.drawLine(corner, Offset(corner.dx, corner.dy + sy * cl), accent);
    }

    final grid = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (int i = 1; i <= 2; i++) {
      final x = rect.left + rect.width * i / 3;
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(_CropMaskPainter old) => old.rect != rect;
}
