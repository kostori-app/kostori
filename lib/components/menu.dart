part of "components.dart";

void showMenuX(BuildContext context, Offset location, List<MenuEntry> entries) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(_MenuRoute(entries, location));
}

class _MenuRoute<T> extends PopupRoute<T> {
  final List<MenuEntry> entries;

  final Offset location;

  _MenuRoute(this.entries, this.location);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "menu";

  double get entryHeight => App.isMobile ? 46 : 40;

  static const double _entryGap = 2;

  static const double _menuPadding = 6;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final cs = context.colorScheme;
    var width = entries.first.icon == null ? 154.0 : 196.0;
    final size = MediaQuery.sizeOf(context);
    var left = location.dx;
    if (left < 10) {
      left = 10;
    }
    if (left + width > size.width - 10) {
      left = size.width - width - 10;
    }
    var top = location.dy;
    final height =
        _menuPadding * 2 +
        entryHeight * entries.length +
        _entryGap * (entries.length - 1);
    if (top + height > size.height - 15) {
      top = size.height - height - 15;
    }
    final radius = BorderRadius.circular(16);
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: context.brightness == Brightness.dark
                    ? cs.outlineVariant.toOpacity(0.7)
                    : cs.outlineVariant.toOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.toOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  blurStyle: BlurStyle.outer,
                ),
              ],
            ),
            child: BlurEffect(
              borderRadius: radius,
              child: Material(
                color: cs.surface.toOpacity(0.86),
                borderRadius: radius,
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: width,
                  padding: const EdgeInsets.all(_menuPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) const SizedBox(height: _entryGap),
                        buildEntry(entries[i], context),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildEntry(MenuEntry entry, BuildContext context) {
    final cs = context.colorScheme;
    final fg = entry.color ?? cs.onSurface;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          entry.onClick();
        },
        hoverColor: cs.onSurface.toOpacity(0.08),
        highlightColor: cs.onSurface.toOpacity(0.12),
        child: SizedBox(
          height: entryHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (entry.icon != null) ...[
                  Icon(entry.icon, size: 20, color: fg.toOpacity(0.85)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    entry.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, color: fg),
                  ),
                ),
                if (entry.trailing != null) ...[
                  const SizedBox(width: 10),
                  entry.trailing!,
                ] else if (entry.endIcon != null) ...[
                  const SizedBox(width: 10),
                  Icon(entry.endIcon, size: 20, color: fg.toOpacity(0.85)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation.drive(
        Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.ease)),
      ),
      child: child,
    );
  }
}

class MenuEntry {
  final String text;
  final IconData? icon;
  final IconData? endIcon;

  final Widget? trailing;
  final Color? color;
  final void Function() onClick;

  MenuEntry({
    required this.text,
    this.icon,
    this.endIcon,
    this.trailing,
    this.color,
    required this.onClick,
  });
}
