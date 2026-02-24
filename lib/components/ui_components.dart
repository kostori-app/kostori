import 'package:flutter/material.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/grid_speed_dial.dart';

class KostoriRefreshIndicator extends StatefulWidget {
  const KostoriRefreshIndicator({super.key});

  @override
  State<KostoriRefreshIndicator> createState() =>
      _KostoriRefreshIndicatorState();
}

class _KostoriRefreshIndicatorState extends State<KostoriRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<double> _letterSpacing;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _opacity = Tween(begin: 0.5, end: 1.0).animate(curve);
    _scale = Tween(begin: 0.96, end: 1.04).animate(curve);
    _letterSpacing = Tween(begin: 0.8, end: 1.6).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 80,
            width: 80,
            child: PolygonRefreshIndicator(size: 80),
          ),
          const SizedBox(height: 18),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Text(
                    'Kostori',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: _letterSpacing.value,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FloatingMenu extends StatefulWidget {
  final ScrollController controller;

  final List<List<SpeedDialChild>> child;

  const FloatingMenu({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<FloatingMenu> createState() => FloatingMenuState();
}

class FloatingMenuState extends State<FloatingMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool show = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    final shouldShow = widget.controller.offset > 50;

    if (shouldShow != show) {
      setState(() => show = shouldShow);
      shouldShow ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: IgnorePointer(
        ignoring: !show,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, right: 0),
          child: RepaintBoundary(
            child: GridSpeedDial(
              icon: Icons.menu,
              activeIcon: Icons.close,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              spacing: 6,
              spaceBetweenChildren: 4,
              direction: SpeedDialDirection.up,
              childPadding: const EdgeInsets.all(6),
              childrens: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
