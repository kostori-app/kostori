part of 'components.dart';

class Select extends StatelessWidget {
  const Select({
    super.key,
    required this.current,
    required this.values,
    this.onTap,
    this.minWidth,
  });

  final String? current;

  final List<String> values;

  final void Function(int index)? onTap;

  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () {
          var renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          var size = renderBox.size;
          showMenu(
            elevation: 3,
            color: context.brightness == Brightness.light
                ? const Color(0xFFF6F6F6)
                : const Color(0xFF1E1E1E),
            context: context,
            useRootNavigator: true,
            constraints: BoxConstraints(
              minWidth: size.width,
              maxWidth: size.width,
            ),
            position: RelativeRect.fromLTRB(
              offset.dx,
              offset.dy + size.height + 2,
              offset.dx + size.height + 2,
              offset.dy,
            ),
            items: values
                .map(
                  (e) => PopupMenuItem(
                    height: App.isMobile ? 46 : 40,
                    value: e,
                    child: Text(e),
                  ),
                )
                .toList(),
          ).then((value) {
            if (value != null) {
              onTap?.call(values.indexOf(value));
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth != null ? (minWidth! - 32) : 0,
              ),
              child: Text(current ?? ' ', style: ts.s14),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: context.colorScheme.primary),
          ],
        ).padding(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      ),
    );
  }
}

class FilterChipFixedWidth extends StatefulWidget {
  const FilterChipFixedWidth({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final Widget label;

  final bool selected;

  final void Function(bool) onSelected;

  @override
  State<FilterChipFixedWidth> createState() => _FilterChipFixedWidthState();
}

class _FilterChipFixedWidthState extends State<FilterChipFixedWidth> {
  bool get selected => widget.selected;

  double? labelWidth;

  double? labelHeight;

  var key = GlobalKey();

  @override
  void initState() {
    Future.microtask(measureSize);
    super.initState();
  }

  void measureSize() {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    labelWidth = renderBox.size.width;
    labelHeight = renderBox.size.height;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      textStyle: Theme.of(context).textTheme.labelLarge,
      child: InkWell(
        onTap: () => widget.onSelected(true),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: labelWidth == null ? firstBuild() : buildContent(),
        ),
      ),
    );
  }

  Widget firstBuild() {
    return Center(
      child: SizedBox(key: key, child: widget.label),
    );
  }

  Widget buildContent() {
    const iconSize = 18.0;
    const gap = 4.0;
    return SizedBox(
      width: iconSize + labelWidth! + gap,
      height: math.max(iconSize, labelHeight!),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _fastAnimationDuration,
            left: selected ? (iconSize + gap) : (iconSize + gap) / 2,
            child: widget.label,
          ),
          if (selected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: labelWidth! + gap,
              child: const AnimatedCheckIcon(size: iconSize).toCenter(),
            ),
        ],
      ),
    );
  }
}

class AnimatedCheckWidget extends AnimatedWidget {
  const AnimatedCheckWidget({
    super.key,
    required Animation<double> animation,
    this.size,
  }) : super(listenable: animation);

  final double? size;

  @override
  Widget build(BuildContext context) {
    var iconSize = size ?? IconTheme.of(context).size ?? 25;
    final animation = listenable as Animation<double>;
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: animation.value,
          child: ClipRRect(
            child: Icon(
              Icons.check,
              size: iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedCheckIcon extends StatefulWidget {
  const AnimatedCheckIcon({this.size, super.key});

  final double? size;

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: _fastAnimationDuration,
    );
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {});
      });
    controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCheckWidget(animation: animation, size: widget.size);
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;

  final bool isSelected;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _fastAnimationDuration,
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.secondaryContainer
            : context.colorScheme.surface,
        border: isSelected
            ? Border.all(color: context.colorScheme.secondaryContainer)
            : Border.all(color: context.colorScheme.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}

/// 通用“滑动指示块”分段容器：外层一条轨道，选中项的指示块像 TabBar 指示器
/// 一样在选项之间滑动跟随。children 依次排列（Wrap，可换行）。
/// 需要单行横向滚动时传 [scrollable] = true（轨道宽度受父级约束，内容横向滚动）。
///
/// 跟随 TabBarView：传 [progress]（一般是 `TabController.animation`，值域
/// 0..children.length-1），指示块会随切换动画/拖拽连续插值移动。
class SlidingSegmentedBar extends StatefulWidget {
  final List<Widget> children;

  /// 选中项下标（-1 表示不显示指示块）；[progress] 非空时忽略
  final int selectedIndex;

  /// 可选：外部动画驱动指示块（如 TabController.animation）
  final Animation<double>? progress;

  /// 追加在选项之后的操作按钮（如「+」添加），不参与指示块定位
  final Widget? actionButton;

  final EdgeInsets padding;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final Decoration? trackDecoration;
  final Decoration indicatorDecoration;
  final Duration duration;
  final bool scrollable;

  /// 选中项变化时自动滚动到可视区（仅 [scrollable] 生效）
  final bool autoScroll;

  const SlidingSegmentedBar({
    super.key,
    required this.children,
    required this.selectedIndex,
    required this.indicatorDecoration,
    this.progress,
    this.actionButton,
    this.trackDecoration,
    this.padding = const EdgeInsets.all(3),
    this.spacing = 2,
    this.runSpacing = 2,
    this.alignment = WrapAlignment.start,
    this.duration = _fastAnimationDuration,
    this.scrollable = false,
    this.autoScroll = true,
  });

  @override
  State<SlidingSegmentedBar> createState() => _SlidingSegmentedBarState();
}

class _SlidingSegmentedBarState extends State<SlidingSegmentedBar>
    with SingleTickerProviderStateMixin {
  final GlobalKey _stackKey = GlobalKey();
  final List<GlobalKey> _childKeys = [];

  /// 各选项相对轨道（Stack）的位置与大小（布局后测量）
  List<Rect> _rects = const [];

  /// 无外部 [SlidingSegmentedBar.progress] 时的内部滑动动画（值 = 选项下标浮点）
  late final AnimationController _slide;

  /// 横向滚动控制器（[SlidingSegmentedBar.scrollable] 时用于自动滚到选中项）
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _slide = AnimationController.unbounded(
      vsync: this,
      value: widget.selectedIndex < 0 ? 0 : widget.selectedIndex.toDouble(),
    );
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant SlidingSegmentedBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncKeys();
    if (widget.progress == null &&
        widget.selectedIndex >= 0 &&
        widget.selectedIndex != oldWidget.selectedIndex) {
      _slide.animateTo(
        widget.selectedIndex.toDouble(),
        duration: widget.duration,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncKeys() {
    while (_childKeys.length < widget.children.length) {
      _childKeys.add(GlobalKey());
    }
    if (_childKeys.length > widget.children.length) {
      _childKeys.removeRange(widget.children.length, _childKeys.length);
    }
  }

  /// 布局后测量所有选项，供指示块定位/插值（换行、滚动时也能跟随），
  /// 并在需要时把选中项滚入可视区
  void _syncLayout(double value) {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    final rects = <Rect>[];
    for (var i = 0; i < _childKeys.length; i++) {
      final childBox =
          _childKeys[i].currentContext?.findRenderObject() as RenderBox?;
      if (childBox == null || !childBox.attached) return;
      rects.add(
        childBox.localToGlobal(Offset.zero, ancestor: stackBox) & childBox.size,
      );
    }
    if (!_rectsEquals(rects, _rects)) {
      setState(() => _rects = rects);
    }
    _scrollSelectedIntoView(value, rects);
  }

  /// 选中项不在可视区时滚动过去（对齐 TabBar 的自动滚动行为）
  void _scrollSelectedIntoView(double value, List<Rect> rects) {
    if (!widget.scrollable || !widget.autoScroll) return;
    if (rects.isEmpty || !_scrollController.hasClients) return;
    final index = value.round().clamp(0, rects.length - 1);
    final rect = rects[index];
    final position = _scrollController.position;
    final offset = position.pixels;
    final viewport = position.viewportDimension;
    double? target;
    if (rect.left < offset) {
      target = rect.left;
    } else if (rect.right > offset + viewport) {
      target = rect.right - viewport;
    }
    if (target == null) return;
    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - offset).abs() < 0.5) return;
    _scrollController.animateTo(
      target,
      duration: widget.duration,
      curve: Curves.easeInOut,
    );
  }

  bool _rectsEquals(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// 值为“第几个选项”的浮点 → 指示块矩形（在相邻两项之间插值）
  Rect? _indicatorRect(double value) {
    if (_rects.isEmpty) return null;
    if (value <= 0) return _rects.first;
    if (value >= _rects.length - 1) return _rects.last;
    final i = value.floor();
    return Rect.lerp(_rects[i], _rects[i + 1], value - i);
  }

  Widget _buildIndicator(Rect? rect) {
    return Positioned(
      key: const ValueKey('segmented-indicator'),
      left: rect?.left ?? 0,
      top: rect?.top ?? 0,
      width: rect?.width ?? 0,
      height: rect?.height ?? 0,
      child: Opacity(
        opacity: rect == null ? 0 : 1,
        child: DecoratedBox(decoration: widget.indicatorDecoration),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final animation = widget.progress ?? _slide.view;
    final content = AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncLayout(value));
        return Stack(
          key: _stackKey,
          children: [
            _buildIndicator(_indicatorRect(value)),
            Wrap(
              key: const ValueKey('segmented-children'),
              spacing: widget.spacing,
              runSpacing: widget.runSpacing,
              alignment: widget.alignment,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  KeyedSubtree(
                    key: _childKeys[i],
                    child: _SegmentedItemScope(
                      index: i,
                      value: value,
                      child: widget.children[i],
                    ),
                  ),
                if (widget.actionButton != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: widget.actionButton,
                  ),
              ],
            ),
          ],
        );
      },
    );
    return Container(
      padding: widget.padding,
      decoration: widget.trackDecoration,
      child: widget.scrollable
          ? SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: content,
            )
          : content,
    );
  }
}

/// 向单个选项暴露它的下标与当前滑动进度（供文字高亮跟随）
class _SegmentedItemScope extends InheritedWidget {
  const _SegmentedItemScope({
    required this.index,
    required this.value,
    required super.child,
  });

  final int index;
  final double value;

  static _SegmentedItemScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SegmentedItemScope>();

  @override
  bool updateShouldNotify(_SegmentedItemScope oldWidget) =>
      oldWidget.index != index || oldWidget.value != value;
}

/// 胶囊分段条：外层一条轨道，选中项为浮起的胶囊。
/// 浮起的胶囊像 TabBar 指示器一样在选项之间滑动跟随（支持换行）。
/// 与探索页“简洁/详细/瀑布流/海报”布局切换同款样式，可复用。
class CapsuleOptions extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final WrapAlignment alignment;

  /// 可选：外部动画驱动指示块（如 TabController.animation），传入时忽略 isSelected
  final Animation<double>? progress;

  /// 追加在选项之后的操作按钮（如「+」添加）
  final Widget? actionButton;

  /// 单行横向滚动（选项过多时）
  final bool scrollable;

  const CapsuleOptions({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(3),
    this.alignment = WrapAlignment.start,
    this.progress,
    this.actionButton,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    var index = -1;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is CapsuleOption && child.isSelected) {
        index = i;
        break;
      }
    }
    return SlidingSegmentedBar(
      selectedIndex: index,
      progress: progress,
      actionButton: actionButton,
      scrollable: scrollable,
      padding: padding,
      alignment: alignment,
      trackDecoration: BoxDecoration(
        color: cs.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      indicatorDecoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      children: children,
    );
  }
}

/// CapsuleOptions 内的单个选项（浮起胶囊由 CapsuleOptions 统一绘制并滑动）
class CapsuleOption extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback? onTap;

  const CapsuleOption({
    super.key,
    required this.text,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 在 SlidingSegmentedBar 内：按滑动进度插值高亮，与浮起胶囊同步；
    // 独立使用时退回 isSelected 的硬切换。
    final scope = _SegmentedItemScope.maybeOf(context);
    final t = scope != null
        ? (1 - (scope.value - scope.index).abs()).clamp(0.0, 1.0)
        : (isSelected ? 1.0 : 0.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: t >= 0.5 ? FontWeight.w600 : FontWeight.w400,
            color: Color.lerp(cs.onSurface.toOpacity(0.45), cs.onSurface, t),
          ),
        ),
      ),
    );
  }
}
