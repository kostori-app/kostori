import 'package:flutter/material.dart';

class MiscComponents {
  MiscComponents._();

  static Widget placeholder(
    BuildContext context,
    double? width,
    double? height, [
    Color? color,
  ]) {
    final effectiveColor =
        color ??
        Theme.of(context).colorScheme.onInverseSurface.withValues(alpha: 0.4);

    return Container(
      width: width ?? 100.0,
      height: height ?? 100.0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: effectiveColor),
      child: Center(
        child: Image.asset(
          'assets/img/image_loading.gif',
          width: (width ?? 100.0) > 100 ? 100 : width,
          height: (height ?? 100.0) > 100 ? 100 : height,
          // cacheWidth: ((width > 100 ? 100 : width) / 2).cacheSize(context),
          // cacheHeight: ((height > 100 ? 100 : height) / 2).cacheSize(context),
        ),
      ),
    );
  }
}

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
          SizedBox(height: 40, width: 40, child: CircularProgressIndicator()),
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
