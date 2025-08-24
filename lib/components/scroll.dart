part of 'components.dart';

class SmoothCustomScrollView extends StatelessWidget {
  const SmoothCustomScrollView({
    super.key,
    required this.slivers,
    this.controller,
  });

  final ScrollController? controller;

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return SmoothScrollProvider(
      controller: controller,
      builder: (context, controller, physics) {
        return CustomScrollView(
          controller: controller,
          physics: physics,
          slivers: [
            ...slivers,
            SliverPadding(
              padding: EdgeInsets.only(bottom: context.padding.bottom),
            ),
          ],
        );
      },
    );
  }
}

class SmoothScrollProvider extends StatefulWidget {
  const SmoothScrollProvider({
    super.key,
    this.controller,
    required this.builder,
  });

  final ScrollController? controller;

  final Widget Function(BuildContext, ScrollController, ScrollPhysics) builder;

  static bool get isMouseScroll => _SmoothScrollProviderState._isMouseScroll;

  @override
  State<SmoothScrollProvider> createState() => _SmoothScrollProviderState();
}

class _SmoothScrollProviderState extends State<SmoothScrollProvider> {
  late final ScrollController _controller;

  double? _futurePosition;

  static bool _isMouseScroll = App.isDesktop;

  late int id;

  static int _id = 0;

  var activeChildren = <int>{};

  ScrollState? parent;

  @override
  void initState() {
    _controller = widget.controller ?? ScrollController();
    super.initState();
    id = _id;
    _id++;
  }

  @override
  void didChangeDependencies() {
    parent = ScrollState.maybeOf(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    parent?.onChildInactive(id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (App.isMacOS) {
      return widget.builder(
        context,
        _controller,
        const BouncingScrollPhysics(),
      );
    }
    var child = Listener(
      onPointerDown: (event) {
        _futurePosition = null;
        if (_isMouseScroll) {
          setState(() {
            _isMouseScroll = false;
          });
        }
      },
      onPointerSignal: (pointerSignal) {
        if (activeChildren.isNotEmpty) {
          return;
        }
        if (pointerSignal is PointerScrollEvent) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            return;
          }
          if (pointerSignal.kind == PointerDeviceKind.mouse &&
              !_isMouseScroll) {
            setState(() {
              _isMouseScroll = true;
            });
          }
          if (!_isMouseScroll) return;
          var currentLocation = _controller.position.pixels;
          var old = _futurePosition;
          _futurePosition ??= currentLocation;
          double k = (_futurePosition! - currentLocation).abs() / 1600 + 1;
          _futurePosition = _futurePosition! + pointerSignal.scrollDelta.dy * k;
          _futurePosition = _futurePosition!.clamp(
            _controller.position.minScrollExtent,
            _controller.position.maxScrollExtent,
          );
          if (_futurePosition == old) return;
          var target = _futurePosition!;
          _controller
              .animateTo(
                _futurePosition!,
                duration: _fastAnimationDuration,
                curve: Curves.linear,
              )
              .then((_) {
                var current = _controller.position.pixels;
                if (current == target && current == _futurePosition) {
                  _futurePosition = null;
                }
              });
        }
      },
      child: ScrollState._(
        controller: _controller,
        onChildActive: (id) {
          activeChildren.add(id);
        },
        onChildInactive: (id) {
          activeChildren.remove(id);
        },
        child: widget.builder(
          context,
          _controller,
          _isMouseScroll
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
        ),
      ),
    );

    if (parent != null) {
      return MouseRegion(
        onEnter: (_) {
          parent!.onChildActive(id);
        },
        onExit: (_) {
          parent!.onChildInactive(id);
        },
        child: child,
      );
    }

    return child;
  }
}

class ScrollState extends InheritedWidget {
  const ScrollState._({
    required this.controller,
    required super.child,
    required this.onChildActive,
    required this.onChildInactive,
  });

  final ScrollController controller;

  final void Function(int id) onChildActive;

  final void Function(int id) onChildInactive;

  static ScrollState of(BuildContext context) {
    final ScrollState? provider = context
        .dependOnInheritedWidgetOfExactType<ScrollState>();
    return provider!;
  }

  static ScrollState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScrollState>();
  }

  @override
  bool updateShouldNotify(ScrollState oldWidget) {
    return oldWidget.controller != controller;
  }
}

class AppScrollBar extends StatefulWidget {
  const AppScrollBar({
    super.key,
    required this.controller,
    required this.child,
    this.topPadding = 0,
    this.isNested = false,
  });

  final ScrollController controller;
  final Widget child;
  final double topPadding;
  final bool isNested;

  @override
  State<AppScrollBar> createState() => _AppScrollBarState();
}

class _AppScrollBarState extends State<AppScrollBar> {
  bool showScrollbar = true;
  Timer? _hideTimer;

  double minExtent = 0;
  double maxExtent = 0;
  double position = 0;
  double viewHeight = 0;

  double _startDragDy = 0;
  double _startScrollOffset = 0;

  final _scrollbarHeight = App.isDesktop ? 42.0 : 64.0;

  late final VerticalDragGestureRecognizer _dragGestureRecognizer;

  ScrollPosition? _outerPosition;
  ScrollPosition? _innerPosition;

  @override
  void initState() {
    super.initState();
    _dragGestureRecognizer = VerticalDragGestureRecognizer()
      ..onStart = _onDragStart
      ..onUpdate = _onDragUpdate;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _dragGestureRecognizer.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _startDragDy = details.localPosition.dy;
    _startScrollOffset = position;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (maxExtent - minExtent <= 0 || viewHeight <= 0) return;

    final dyDelta = details.localPosition.dy - _startDragDy;
    final scrollRange = maxExtent - minExtent;
    final viewRange = viewHeight - _scrollbarHeight;
    if (viewRange <= 0) return;

    final scrollDelta = dyDelta / viewRange * scrollRange;
    double newPosition = (_startScrollOffset + scrollDelta).clamp(
      minExtent,
      maxExtent,
    );

    if (widget.isNested && _outerPosition != null && _innerPosition != null) {
      // 外层滚动范围
      double outerMax = _outerPosition!.maxScrollExtent;
      if (newPosition <= outerMax) {
        _outerPosition!.jumpTo(newPosition);
      } else {
        _outerPosition!.jumpTo(outerMax);
        _innerPosition!.jumpTo(newPosition - outerMax);
      }
    } else if (_outerPosition != null) {
      _outerPosition!.jumpTo(newPosition);
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => showScrollbar = false);
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (widget.isNested) {
      final pos = Scrollable.of(notification.context!);
      if (_outerPosition == null) {
        _outerPosition = pos.position;
      } else if (_outerPosition != pos.position) {
        _innerPosition = pos.position;
      }
    } else {
      _outerPosition = widget.controller.position;
    }

    double outerOffset = _outerPosition?.pixels ?? 0.0;
    double outerMax = _outerPosition?.maxScrollExtent ?? 0.0;
    double innerOffset = _innerPosition?.pixels ?? 0.0;
    double innerMax = _innerPosition?.maxScrollExtent ?? 0.0;

    minExtent = 0;
    maxExtent = outerMax + innerMax;
    position = outerOffset + innerOffset;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        showScrollbar = true;
      });
      _restartHideTimer();
    });

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: LayoutBuilder(
        builder: (context, constraints) {
          viewHeight = constraints.maxHeight - widget.topPadding;

          final scrollExtent = maxExtent - minExtent;
          final top = scrollExtent == 0
              ? 0.0
              : ((position - minExtent) / scrollExtent) *
                    (viewHeight - _scrollbarHeight);

          return Stack(
            children: [
              Positioned.fill(child: widget.child),
              if (scrollExtent > 0)
                Positioned(
                  top: top + widget.topPadding,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: showScrollbar ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          _dragGestureRecognizer.addPointer(event);
                          _restartHideTimer();
                        },
                        child: SizedBox(
                          width: _scrollbarHeight / 2,
                          height: _scrollbarHeight,
                          child: CustomPaint(
                            painter: _ScrollIndicatorPainter(
                              backgroundColor: context.colorScheme.surface,
                              shadowColor: context.colorScheme.shadow,
                            ),
                            child: Column(
                              children: const [
                                Spacer(),
                                Icon(Icons.arrow_drop_up, size: 18),
                                Icon(Icons.arrow_drop_down, size: 18),
                                Spacer(),
                              ],
                            ).paddingLeft(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScrollIndicatorPainter extends CustomPainter {
  final Color backgroundColor;

  final Color shadowColor;

  const _ScrollIndicatorPainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(Offset(size.width, 0), radius: Radius.circular(size.width));
    canvas.drawShadow(path, shadowColor, 4, true);
    var backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(Offset(size.width, 0), radius: Radius.circular(size.width));
    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ScrollIndicatorPainter ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}
