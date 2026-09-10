import 'package:flutter/material.dart';

/// 底部弹层式 [PageRoute]。
///
/// 视觉与 `showModalBottomSheet` 类似（底部对齐、圆角、限高、上滑进入、
/// 点击遮罩关闭），但本质是 [PageRoute]，因此可以与目标页做 Hero 转场
/// （Flutter 的 `HeroController` 只处理 PageRoute 之间的转场，PopupRoute 不行）。
class SheetPageRoute<T> extends PageRoute<T> {
  SheetPageRoute({
    required this.builder,
    this.maxHeightFactor = 0.75,
    this.maxWidthFactor = 1.0,
    this.radius = 16,
  });

  final WidgetBuilder builder;
  final double maxHeightFactor;
  final double maxWidthFactor;
  final double radius;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final size = MediaQuery.sizeOf(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: size.height * maxHeightFactor,
          maxWidth: size.width * maxWidthFactor,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          // 底部弹层不需要状态栏顶部内边距
          child: MediaQuery.removePadding(
            removeTop: true,
            context: context,
            child: builder(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
