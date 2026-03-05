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

    return AnimatedBuilder(
      animation: fade,
      builder: (context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Opacity(
                    opacity: fade.value,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: 10.0 * fade.value,
                        sigmaY: 10.0 * fade.value,
                      ),
                      child: Container(
                        color: Colors.black.toOpacity(0.3 * fade.value),
                      ),
                    ),
                  ),
                ),
                // 内容淡入淡出
                FadeTransition(opacity: fade, child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}
