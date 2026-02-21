import 'package:flutter/material.dart';
import 'package:kostori/components/animated.dart';

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
