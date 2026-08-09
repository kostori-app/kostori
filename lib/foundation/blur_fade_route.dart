import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/config/all.dart';

class BlurFadeRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  BlurFadeRoute({required this.builder});

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  bool get maintainState => true;

  @override
  bool canTransitionTo(TransitionRoute nextRoute) => false;

  @override
  bool canTransitionFrom(TransitionRoute previousRoute) => false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    // 内容用 FadeTransition（不重建内容），背景模糊单独用 AnimatedBuilder 驱动
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: fade,
            builder: (context, _) {
              final v = fade.value;
              return Opacity(
                opacity: v,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 10.0 * v,
                    sigmaY: 10.0 * v,
                  ),
                  child: Container(color: Colors.black.toOpacity(0.3 * v)),
                ),
              );
            },
          ),
          // 内容淡入淡出（透明 Material 提供 Material 上下文）
          FadeTransition(
            opacity: fade,
            child: Material(type: MaterialType.transparency, child: child),
          ),
        ],
      ),
    );
  }
}
