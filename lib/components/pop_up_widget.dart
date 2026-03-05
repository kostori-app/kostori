part of 'components.dart';

class PopUpWidget<T> extends PopupRoute<T> {
  PopUpWidget(this.widget);

  final Widget widget;

  late final CurvedAnimation _curvedAnimation;

  @override
  void install() {
    super.install();
    _curvedAnimation = CurvedAnimation(
      parent: animation!,
      curve: Curves.ease,
      reverseCurve: Curves.ease,
    );
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    super.dispose();
  }

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "exit";

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final height = MediaQuery.of(context).size.height * 0.9;
    final showPopUp = MediaQuery.of(context).size.width > 500;

    Widget body = PopupIndicatorWidget(
      child: Container(
        decoration: showPopUp
            ? BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        clipBehavior: showPopUp ? Clip.antiAlias : Clip.none,
        width: showPopUp ? 600 : double.infinity,
        height: showPopUp ? height : double.infinity,
        child: ClipRect(
          child: Navigator(
            onGenerateRoute: (settings) =>
                MaterialPageRoute(builder: (context) => widget),
          ),
        ),
      ),
    );

    if (App.isIOS) {
      body = IOSBackGestureDetector(
        enabledCallback: () => true,
        gestureWidth: 20.0,
        onStartPopGesture: () =>
            IOSBackGestureController(controller!, navigator!),
        child: body,
      );
    }

    if (showPopUp) {
      return MediaQuery.removePadding(
        removeTop: true,
        context: context,
        child: Center(child: body),
      );
    }

    return body;
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: _curvedAnimation,
      builder: (context, _) {
        return GestureDetector(
          onTap: () => navigator?.pop(), // ← 点击背景关闭
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: 0.001 + 6.0 * _curvedAnimation.value,
              sigmaY: 0.001 + 6.0 * _curvedAnimation.value,
            ),
            child: ColoredBox(
              color: Colors.black.withAlpha(
                (80 * _curvedAnimation.value).toInt(),
              ),
              child: GestureDetector(
                onTap: () {}, // ← 阻止点击内容区穿透到背景
                child: FadeTransition(opacity: _curvedAnimation, child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PopupIndicatorWidget extends InheritedWidget {
  const PopupIndicatorWidget({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;

  static PopupIndicatorWidget? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PopupIndicatorWidget>();
  }
}

Future<T> showPopUpWidget<T>(BuildContext context, Widget widget) async {
  return await Navigator.of(
    context,
    rootNavigator: true,
  ).push(PopUpWidget(widget));
}

class PopUpWidgetScaffold extends StatefulWidget {
  const PopUpWidgetScaffold({
    required this.title,
    required this.body,
    this.tailing,
    super.key,
  });

  final Widget body;
  final List<Widget>? tailing;
  final String title;

  @override
  State<PopUpWidgetScaffold> createState() => _PopUpWidgetScaffoldState();
}

class _PopUpWidgetScaffoldState extends State<PopUpWidgetScaffold> {
  bool top = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardOffset = (keyboardHeight - 0.05 * screenHeight).clamp(
      0.0,
      double.infinity,
    );

    return Material(
      color: colorScheme.surface,
      child: Column(
        children: [
          // 顶部栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 56 + context.padding.top,
            padding: EdgeInsets.only(top: context.padding.top),
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: top
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 0.6,
                      ),
                    ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Tooltip(
                  message: "Back".tl,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () =>
                        context.canPop() ? context.pop() : App.pop(),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (widget.tailing != null) ...widget.tailing!,
                const SizedBox(width: 8),
              ],
            ),
          ),

          // 内容区
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axisDirection != AxisDirection.down) {
                return false;
              }
              final atTop =
                  notification.metrics.pixels ==
                  notification.metrics.minScrollExtent;
              if (atTop != top) {
                setState(() => top = atTop);
              }
              return false;
            },
            child: MediaQuery.removePadding(
              removeTop: true,
              context: context,
              child: Expanded(child: widget.body),
            ),
          ),
          // 键盘偏移
          SizedBox(height: keyboardOffset),
        ],
      ),
    );
  }
}
