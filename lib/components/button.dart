part of 'components.dart';

class HoverBox extends StatefulWidget {
  const HoverBox({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;

  final BorderRadius borderRadius;

  @override
  State<HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<HoverBox> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isHover
              ? Theme.of(context).colorScheme.surfaceContainerLow
              : null,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

enum ButtonType { filled, outlined, text, normal }

class Button extends StatefulWidget {
  const Button({
    super.key,
    required this.type,
    required this.child,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
    this.color,
    this.onPressedAt,
    required this.onPressed,
  });

  const Button.filled({
    super.key,
    required this.child,
    required this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.color,
    this.onPressedAt,
    this.isLoading = false,
  }) : type = ButtonType.filled;

  const Button.outlined({
    super.key,
    required this.child,
    required this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.color,
    this.onPressedAt,
    this.isLoading = false,
  }) : type = ButtonType.outlined;

  const Button.text({
    super.key,
    required this.child,
    required this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.color,
    this.onPressedAt,
    this.isLoading = false,
  }) : type = ButtonType.text;

  const Button.normal({
    super.key,
    required this.child,
    required this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.color,
    this.onPressedAt,
    this.isLoading = false,
  }) : type = ButtonType.normal;

  static Widget icon({
    Key? key,
    required Widget icon,
    required VoidCallback onPressed,
    double? size,
    Color? color,
    String? tooltip,
    bool isLoading = false,
    HitTestBehavior behavior = HitTestBehavior.deferToChild,
  }) {
    return _IconButton(
      key: key,
      icon: icon,
      onPressed: onPressed,
      size: size,
      color: color,
      tooltip: tooltip,
      behavior: behavior,
      isLoading: isLoading,
    );
  }

  final ButtonType type;

  final Widget child;

  final bool isLoading;

  final void Function() onPressed;

  final void Function(Offset location)? onPressedAt;

  final double? width;

  final double? height;

  final EdgeInsets? padding;

  final Color? color;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool isHover = false;

  bool isLoading = false;

  @override
  void didUpdateWidget(covariant Button oldWidget) {
    if (oldWidget.isLoading != widget.isLoading) {
      setState(() => isLoading = widget.isLoading);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    var padding =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    var width = widget.width;
    if (width != null) {
      width = width - padding.horizontal;
    }
    var height = widget.height;
    if (height != null) {
      height = height - padding.vertical;
    }
    Widget child = IconTheme(
      data: IconThemeData(color: textColor),
      child: DefaultTextStyle(
        style: TextStyle(color: textColor, fontSize: 14),
        child: isLoading
            ? PolygonRefreshIndicator().fixWidth(16).fixHeight(16)
            : widget.child,
      ),
    );
    if (width != null || height != null) {
      child = child.toCenter();
    }
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (isLoading) return;
          widget.onPressed();
          if (widget.onPressedAt != null) {
            var renderBox = context.findRenderObject() as RenderBox;
            var offset = renderBox.localToGlobal(Offset.zero);
            widget.onPressedAt!(offset);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: padding,
          constraints: const BoxConstraints(minWidth: 76),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow:
                (isHover &&
                    !isLoading &&
                    (widget.type == ButtonType.filled ||
                        widget.type == ButtonType.normal))
                ? [
                    BoxShadow(
                      color: Colors.black.toOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
            border: widget.type == ButtonType.outlined
                ? Border.all(
                    color:
                        widget.color ??
                        Theme.of(context).colorScheme.outlineVariant,
                    width: 0.6,
                  )
                : null,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 160),
            child: SizedBox(
              width: width,
              height: height,
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }

  Color get buttonColor {
    if (widget.type == ButtonType.filled) {
      var color = widget.color ?? context.colorScheme.primary;
      if (isHover) {
        return color.toOpacity(0.9);
      } else {
        return color;
      }
    }
    if (widget.type == ButtonType.normal) {
      var color = widget.color ?? context.colorScheme.surfaceContainer;
      if (isHover) {
        return color.toOpacity(0.9);
      } else {
        return color;
      }
    }
    if (isHover) {
      return context.colorScheme.outline.toOpacity(0.2);
    }
    return Colors.transparent;
  }

  Color get textColor {
    if (widget.type == ButtonType.outlined) {
      return widget.color ?? context.colorScheme.primary;
    }
    return widget.type == ButtonType.filled
        ? context.colorScheme.onPrimary
        : (widget.type == ButtonType.text
              ? widget.color ?? context.colorScheme.primary
              : context.colorScheme.onSurface);
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size,
    this.color,
    this.tooltip,
    this.isLoading = false,
    this.behavior = HitTestBehavior.deferToChild,
  });

  final Widget icon;

  final VoidCallback onPressed;

  final double? size;

  final String? tooltip;

  final Color? color;

  final HitTestBehavior behavior;

  final bool isLoading;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    var iconSize = widget.size ?? 24;
    Widget icon = IconTheme(
      data: IconThemeData(
        size: iconSize,
        color: widget.color ?? context.colorScheme.primary,
      ),
      child: widget.icon,
    );
    if (widget.isLoading) {
      icon = const PolygonRefreshIndicator()
          .paddingAll(2)
          .fixWidth(iconSize)
          .fixHeight(iconSize);
    }
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: () {
          if (widget.isLoading) return;
          widget.onPressed();
        },
        child: Tooltip(
          message: widget.tooltip ?? "",
          child: Container(
            decoration: BoxDecoration(
              color: isHover
                  ? Theme.of(context).colorScheme.outlineVariant.toOpacity(0.4)
                  : null,
              borderRadius: BorderRadius.circular((iconSize + 12) / 2),
            ),
            padding: const EdgeInsets.all(6),
            child: icon,
          ),
        ),
      ),
    );
  }
}

class MenuButton extends StatefulWidget {
  const MenuButton({super.key, required this.entries, this.icon, this.message});

  final List<MenuEntry> entries;

  final IconData? icon;

  final String? message;

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: (widget.message == null) ? t.more : '${widget.message}',
      child: Button.icon(
        icon: (widget.icon == null)
            ? Icon(Icons.more_horiz)
            : Icon(widget.icon),
        onPressed: () {
          var renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          showMenuX(context, offset, widget.entries);
        },
      ),
    );
  }
}

/// 竖向图标按钮：上面图标，下面文字。
/// 用于详情页操作栏、番源设置页操作按钮等（统一复用）。
class IconTileButton extends StatelessWidget {
  const IconTileButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.activeIcon,
    this.isActive,
    this.isLoading,
    this.color,
    this.activeColor,
  });

  /// 图标（可为 Icon / Row / SvgPicture 等任意 Widget）
  final Widget icon;

  /// 激活态图标（配合 [isActive]）
  final Widget? activeIcon;

  /// 是否激活（激活时用主题色高亮）
  final bool? isActive;

  final String label;

  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// 是否显示加载中指示（替换图标）
  final bool? isLoading;

  /// 图标颜色
  final Color? color;

  /// 激活态颜色（默认主题色）
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final active = isActive ?? false;
    final loading = isLoading ?? false;
    final iconColor =
        color ??
        (active
            ? (activeColor ?? cs.primary)
            : (enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.3)));
    final textColor = active
        ? (activeColor ?? cs.primary)
        : (enabled
              ? (color ?? cs.onSurface.withValues(alpha: 0.75))
              : cs.onSurface.withValues(alpha: 0.3));
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 56, maxWidth: 96),
      child: InkWell(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 24,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: PolygonRefreshIndicator(),
                      )
                    : IconTheme.merge(
                        data: IconThemeData(color: iconColor, size: 22),
                        child: active ? (activeIcon ?? icon) : icon,
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分段胶囊风格的独立按钮（与 CapsuleOptions 同一视觉语言，但彼此分开、不连成一段）。
/// 用来统一项目里零散的按钮画风，避免每处各写一份。
class CapsuleButton extends StatefulWidget {
  const CapsuleButton({
    super.key,
    this.text,
    this.child,
    required this.onTap,
    this.primary = false,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.isLoading = false,
    this.flat = false,
    this.color,
    this.fgColor,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  }) : assert(text != null || child != null || leading != null);

  final String? text;
  final Widget? child;
  final VoidCallback onTap;

  /// 主要动作：主题色填充；否则为浅色胶囊
  final bool primary;

  /// 透明底（用于 [CapsuleButtonBar]：整条轨道连贯，按钮各自独立）
  final bool flat;

  /// 自定义底色（优先级高于 [primary]）
  final Color? color;

  /// 自定义前景色（图标与文字）
  final Color? fgColor;

  /// 固定宽度（如 `double.infinity` 做整行按钮，内容居中）
  final double? width;

  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final bool isLoading;
  final EdgeInsetsGeometry padding;

  @override
  State<CapsuleButton> createState() => _CapsuleButtonState();
}

class _CapsuleButtonState extends State<CapsuleButton> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.flat
        ? Colors.transparent
        : widget.color ??
              (widget.primary
                  ? cs.primary
                  : cs.surfaceContainerHighest.withValues(alpha: 0.6));
    final fg =
        widget.fgColor ?? (widget.primary ? cs.onPrimary : cs.onSurfaceVariant);
    final enabled = widget.enabled && !widget.isLoading;
    return Material(
      color: enabled ? bg : bg.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? widget.onTap : null,
        child: Padding(
          padding: widget.padding,
          child: DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: 16, color: fg),
              child: SizedBox(
                width: widget.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isLoading) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: PolygonRefreshIndicator(),
                      ),
                      const SizedBox(width: 6),
                    ] else if (widget.leading != null) ...[
                      widget.leading!,
                      if (widget.child != null || widget.text != null)
                        const SizedBox(width: 6),
                    ],
                    if (widget.child != null)
                      widget.child!
                    else if (widget.text != null)
                      Text(widget.text!),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 6),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 连贯轨道 + 独立按钮：外观像分段胶囊（同一条背景轨道），
/// 但每一段都是可以单独点击的按钮（不是单选）。
/// 用法：children 传 `CapsuleButton(flat: true, ...)`。
class CapsuleButtonBar extends StatelessWidget {
  const CapsuleButtonBar({
    super.key,
    required this.children,
    this.alignment = WrapAlignment.start,
    this.padding = const EdgeInsets.all(3),
    this.spacing = 2,
    this.runSpacing = 2,
  });

  final List<Widget> children;
  final WrapAlignment alignment;
  final EdgeInsets padding;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        alignment: alignment,
        spacing: spacing,
        runSpacing: runSpacing,
        children: children,
      ),
    );
  }
}

class FlyoutTextButton extends StatefulWidget {
  const FlyoutTextButton({
    super.key,
    required this.child,
    required this.flyoutBuilder,
    this.navigator,
  });

  final Widget child;

  final WidgetBuilder flyoutBuilder;

  final NavigatorState? navigator;

  @override
  State<FlyoutTextButton> createState() => _FlyoutTextButtonState();
}

class _FlyoutTextButtonState extends State<FlyoutTextButton> {
  final FlyoutController _controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Flyout(
      controller: _controller,
      flyoutBuilder: widget.flyoutBuilder,
      navigator: widget.navigator,
      child: TextButton(
        onPressed: () {
          _controller.show();
        },
        child: widget.child,
      ),
    );
  }
}

class FlyoutIconButton extends StatefulWidget {
  const FlyoutIconButton({
    super.key,
    required this.icon,
    required this.flyoutBuilder,
    this.navigator,
  });

  final Widget icon;

  final WidgetBuilder flyoutBuilder;

  final NavigatorState? navigator;

  @override
  State<FlyoutIconButton> createState() => _FlyoutIconButtonState();
}

class _FlyoutIconButtonState extends State<FlyoutIconButton> {
  final FlyoutController _controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Flyout(
      controller: _controller,
      flyoutBuilder: widget.flyoutBuilder,
      navigator: widget.navigator,
      child: IconButton(
        onPressed: () {
          _controller.show();
        },
        icon: widget.icon,
      ),
    );
  }
}

class FlyoutFilledButton extends StatefulWidget {
  const FlyoutFilledButton({
    super.key,
    required this.child,
    required this.flyoutBuilder,
    this.navigator,
  });

  final Widget child;

  final WidgetBuilder flyoutBuilder;

  final NavigatorState? navigator;

  @override
  State<FlyoutFilledButton> createState() => _FlyoutFilledButtonState();
}

class _FlyoutFilledButtonState extends State<FlyoutFilledButton> {
  final FlyoutController _controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Flyout(
      controller: _controller,
      flyoutBuilder: widget.flyoutBuilder,
      navigator: widget.navigator,
      child: ElevatedButton(
        onPressed: () {
          _controller.show();
        },
        child: widget.child,
      ),
    );
  }
}
