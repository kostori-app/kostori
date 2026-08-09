part of 'video_clip_editor.dart';

class _RangePickerWidget extends StatelessWidget {
  final Duration totalDuration;
  final Duration startTime;
  final Duration endTime;
  final RangeChangedCallback onRangeChanged;
  final Widget timelineThumbnails;

  const _RangePickerWidget({
    required this.totalDuration,
    required this.startTime,
    required this.endTime,
    required this.onRangeChanged,
    required this.timelineThumbnails,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final sz = Size(c.maxWidth, 60.0);
        return Stack(
          children: [
            Positioned.fill(child: timelineThumbnails),

            _RangeOverlay(
              totalDuration: totalDuration,
              startTime: startTime,
              endTime: endTime,
              onRangeChanged: onRangeChanged,
              size: sz,
            ),
          ],
        );
      },
    );
  }
}

typedef RangeChangedCallback = void Function(Duration start, Duration end);

class _RangeOverlay extends StatefulWidget {
  final Duration totalDuration;
  final Duration startTime;
  final Duration endTime;
  final RangeChangedCallback onRangeChanged;
  final Size size;

  const _RangeOverlay({
    required this.totalDuration,
    required this.startTime,
    required this.endTime,
    required this.onRangeChanged,
    required this.size,
  });

  @override
  State<_RangeOverlay> createState() => _RangeOverlayState();
}

class _RangeOverlayState extends State<_RangeOverlay> {
  late Duration _localStart;
  late Duration _localEnd;

  @override
  void initState() {
    super.initState();
    _localStart = widget.startTime;
    _localEnd = widget.endTime;
  }

  @override
  void didUpdateWidget(_RangeOverlay old) {
    super.didUpdateWidget(old);
    if (old.startTime != widget.startTime || old.endTime != widget.endTime) {
      _localStart = widget.startTime;
      _localEnd = widget.endTime;
    }
  }

  void _update() {
    widget.onRangeChanged(_localStart, _localEnd);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalDuration == Duration.zero) return const SizedBox.shrink();

    final totalDurMs = widget.totalDuration.inMilliseconds.toDouble();
    final pxPerMs = widget.size.width / totalDurMs;

    final startPx = _localStart.inMilliseconds.toDouble() * pxPerMs;
    final endPx = _localEnd.inMilliseconds.toDouble() * pxPerMs;

    final handleRadius = 12.0;

    return Stack(
      children: [
        CustomPaint(
          size: widget.size,
          painter: _RangeMaskPainter(
            startPx,
            endPx,
            widget.size,
            Theme.of(context).colorScheme.primary,
          ),
        ),

        Positioned(
          left: startPx,
          width: (endPx - startPx).abs(),
          top: 0.0,
          bottom: 0.0,
          child: GestureDetector(
            onPanUpdate: (d) {
              final dxTimeMs = (d.delta.dx / pxPerMs).round();
              setState(() {
                final currentDurMs =
                    _localEnd.inMilliseconds - _localStart.inMilliseconds;

                int newStartMs = _localStart.inMilliseconds + dxTimeMs;
                int newEndMs = newStartMs + currentDurMs;

                if (newStartMs < 0) {
                  newStartMs = 0;
                  newEndMs = currentDurMs;
                } else if (newEndMs > widget.totalDuration.inMilliseconds) {
                  newEndMs = widget.totalDuration.inMilliseconds;
                  newStartMs = newEndMs - currentDurMs;
                }

                _localStart = Duration(milliseconds: newStartMs);
                _localEnd = Duration(milliseconds: newEndMs);
              });
              _update();
            },
            child: Container(color: Colors.transparent),
          ),
        ),

        Positioned(
          left: startPx - handleRadius,
          top: 0.0,
          bottom: 0.0,
          child: GestureDetector(
            onPanUpdate: (d) {
              final dxTimeMs = (d.delta.dx / pxPerMs).round();
              setState(() {
                final newStart = Duration(
                  milliseconds: max(
                    0,
                    min(
                      (_localStart.inMilliseconds + dxTimeMs).toDouble(),
                      (_localEnd.inMilliseconds - 100).toDouble(),
                    ),
                  ).round(),
                );

                final newDurMs =
                    _localEnd.inMilliseconds - newStart.inMilliseconds;
                if (newDurMs > _VideoClipEditorPageState.maxExportDurationMs) {
                  _localStart = newStart;
                  _localEnd =
                      newStart +
                      const Duration(
                        milliseconds:
                            _VideoClipEditorPageState.maxExportDurationMs,
                      );
                  if (_localEnd > widget.totalDuration) {
                    _localEnd = widget.totalDuration;
                    _localStart =
                        _localEnd -
                        const Duration(
                          milliseconds:
                              _VideoClipEditorPageState.maxExportDurationMs,
                        );
                    if (_localStart < Duration.zero) {
                      _localStart = Duration.zero;
                    }
                  }
                } else {
                  _localStart = newStart;
                }
              });
              _update();
            },
            child: Align(
              alignment: Alignment.center,
              child: _RangeHandle(radius: handleRadius),
            ),
          ),
        ),

        Positioned(
          left: endPx - handleRadius,
          top: 0.0,
          bottom: 0.0,
          child: GestureDetector(
            onPanUpdate: (d) {
              final dxTimeMs = (d.delta.dx / pxPerMs).round();
              setState(() {
                final newEnd = Duration(
                  milliseconds: min(
                    widget.totalDuration.inMilliseconds.toDouble(),
                    max(
                      (_localEnd.inMilliseconds + dxTimeMs).toDouble(),
                      (_localStart.inMilliseconds + 100).toDouble(),
                    ),
                  ).round(),
                );

                final newDurMs =
                    newEnd.inMilliseconds - _localStart.inMilliseconds;
                if (newDurMs > _VideoClipEditorPageState.maxExportDurationMs) {
                  _localEnd = newEnd;
                  _localStart =
                      newEnd -
                      const Duration(
                        milliseconds:
                            _VideoClipEditorPageState.maxExportDurationMs,
                      );
                  if (_localStart < Duration.zero) {
                    _localStart = Duration.zero;
                    _localEnd =
                        _localStart +
                        const Duration(
                          milliseconds:
                              _VideoClipEditorPageState.maxExportDurationMs,
                        );
                    if (_localEnd > widget.totalDuration) {
                      _localEnd = widget.totalDuration;
                    }
                  }
                } else {
                  _localEnd = newEnd;
                }
              });
              _update();
            },
            child: Align(
              alignment: Alignment.center,
              child: _RangeHandle(radius: handleRadius),
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeHandle extends StatelessWidget {
  final double radius;

  const _RangeHandle({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: t.rangePickerDragHint,
      child: Container(
        width: radius * 2,
        height: 66.0,
        alignment: Alignment.center,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
            ],
          ),
          child: SizedBox(width: radius * 2, height: radius * 2),
        ),
      ),
    );
  }
}

class _RangeMaskPainter extends CustomPainter {
  final double startPx;
  final double endPx;
  final Size size;
  final Color color;

  _RangeMaskPainter(this.startPx, this.endPx, this.size, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maskPaint = Paint()..color = Colors.black.withAlpha(140);
    canvas.drawRect(Rect.fromLTWH(0, 0, startPx, size.height), maskPaint);
    canvas.drawRect(
      Rect.fromLTWH(endPx, 0, size.width - endPx, size.height),
      maskPaint,
    );

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(Rect.fromLTRB(startPx, 0, endPx, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(_RangeMaskPainter old) =>
      old.startPx != startPx ||
      old.endPx != endPx ||
      old.size != size ||
      old.color != color;
}
