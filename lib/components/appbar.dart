part of 'components.dart';

class Appbar extends StatefulWidget implements PreferredSizeWidget {
  const Appbar({
    required this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.style = AppbarStyle.blur,
    super.key,
  });

  final Widget title;

  final Widget? leading;

  final List<Widget>? actions;

  final Color? backgroundColor;

  final AppbarStyle style;

  @override
  State<Appbar> createState() => _AppbarState();

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _AppbarState extends State<Appbar> {
  ScrollNotificationObserverState? _scrollNotificationObserver;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollNotificationObserver?.removeListener(_handleScrollNotification);
    _scrollNotificationObserver = ScrollNotificationObserver.maybeOf(context);
    _scrollNotificationObserver?.addListener(_handleScrollNotification);
  }

  @override
  void dispose() {
    if (_scrollNotificationObserver != null) {
      _scrollNotificationObserver!.removeListener(_handleScrollNotification);
      _scrollNotificationObserver = null;
    }
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        defaultScrollNotificationPredicate(notification)) {
      final bool oldScrolledUnder = _scrolledUnder;
      final ScrollMetrics metrics = notification.metrics;
      switch (metrics.axisDirection) {
        case AxisDirection.up:
          // Scroll view is reversed
          _scrolledUnder = metrics.extentAfter > 0;
        case AxisDirection.down:
          _scrolledUnder = metrics.extentBefore > 0;
        case AxisDirection.right:
        case AxisDirection.left:
          // Scrolled under is only supported in the vertical axis, and should
          // not be altered based on horizontal notifications of the same
          // predicate since it could be a 2D scroller.
          break;
      }

      if (_scrolledUnder != oldScrolledUnder) {
        setState(() {
          // React to a change in MaterialState.scrolledUnder
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var content = Container(
      decoration: BoxDecoration(
        color:
            widget.backgroundColor ??
            context.colorScheme.surface.toOpacity(0.72),
      ),
      height: _kAppBarHeight + context.padding.top,
      child: Row(
        children: [
          const SizedBox(width: 8),
          widget.leading ??
              Tooltip(
                message: "Back".tl,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
          const SizedBox(width: 16),
          Expanded(
            child: DefaultTextStyle(
              style: DefaultTextStyle.of(context).style.copyWith(fontSize: 20),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: widget.title,
            ),
          ),
          ...?widget.actions,
          const SizedBox(width: 8),
        ],
      ).paddingTop(context.padding.top),
    );
    if (widget.style == AppbarStyle.shadow) {
      return Material(
        color: context.colorScheme.surface,
        elevation: _scrolledUnder ? 2 : 0,
        child: content,
      );
    } else {
      return BlurEffect(blur: _scrolledUnder ? 15 : 0, child: content);
    }
  }
}

enum AppbarStyle { blur, shadow }

class SliverAppbar extends StatelessWidget {
  const SliverAppbar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.radius = 0,
    this.style = AppbarStyle.blur,
    this.bottom,
  });

  final Widget? leading;

  final Widget title;

  final List<Widget>? actions;

  final double radius;

  final AppbarStyle style;

  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _MySliverAppBarDelegate(
        leading: leading,
        title: title,
        actions: actions,
        topPadding: MediaQuery.of(context).padding.top,
        radius: radius,
        style: style,
        bottom: bottom,
      ),
    );
  }
}

const _kAppBarHeight = 52.0;

class _MySliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget? leading;

  final Widget title;

  final List<Widget>? actions;

  final double topPadding;

  final double radius;

  final AppbarStyle style;

  final PreferredSizeWidget? bottom;

  _MySliverAppBarDelegate({
    this.leading,
    required this.title,
    this.actions,
    required this.topPadding,
    this.radius = 0,
    this.style = AppbarStyle.blur,
    this.bottom,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    var body = Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            leading ??
                (Navigator.of(context).canPop()
                    ? Tooltip(
                        message: "Back".tl,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      )
                    : const SizedBox()),
            const SizedBox(width: 8),
            Expanded(
              child: DefaultTextStyle(
                style: DefaultTextStyle.of(
                  context,
                ).style.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title,
              ),
            ),
            ...?actions,
            const SizedBox(width: 8),
          ],
        ).paddingTop(topPadding),
        if (bottom != null) bottom!,
      ],
    );

    if (style == AppbarStyle.blur) {
      return SizedBox.expand(
        child: BlurEffect(
          blur: 15,
          child: Material(
            color: context.colorScheme.surface.toOpacity(0.72),
            elevation: 0,
            borderRadius: BorderRadius.circular(radius),
            child: body,
          ),
        ),
      );
    } else {
      return SizedBox.expand(
        child: Material(
          color: context.colorScheme.surface,
          elevation: shrinkOffset == 0 ? 0 : 2,
          borderRadius: BorderRadius.circular(radius),
          child: body,
        ),
      );
    }
  }

  @override
  double get maxExtent =>
      _kAppBarHeight + topPadding + (bottom?.preferredSize.height ?? 0);

  @override
  double get minExtent =>
      _kAppBarHeight + topPadding + (bottom?.preferredSize.height ?? 0);

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _MySliverAppBarDelegate ||
        leading != oldDelegate.leading ||
        title != oldDelegate.title ||
        actions != oldDelegate.actions ||
        topPadding != oldDelegate.topPadding ||
        radius != oldDelegate.radius ||
        style != oldDelegate.style ||
        bottom != oldDelegate.bottom;
  }
}

class AppTabBar extends StatefulWidget {
  const AppTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.actionButton,
    this.withUnderLine = true,
  });

  final TabController? controller;

  final List<Tab> tabs;

  final Widget? actionButton;

  final bool withUnderLine;

  @override
  State<AppTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<AppTabBar> {
  late TabController _controller;

  late List<GlobalKey> keys;

  static const _kTabHeight = 48.0;

  static const tabPadding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);

  static const tabRadius = 8.0;

  _IndicatorPainter? painter;

  var scrollController = ScrollController();

  var tabBarKey = GlobalKey();

  var offsets = <double>[];

  @override
  void initState() {
    keys = widget.tabs.map((e) => GlobalKey()).toList();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  PageStorageBucket get bucket => PageStorage.of(context);

  @override
  void didChangeDependencies() {
    _controller = widget.controller ?? DefaultTabController.of(context);
    initPainter();
    super.didChangeDependencies();
    var prevIndex = bucket.readState(context) as int?;
    if (prevIndex != null &&
        prevIndex != _controller.index &&
        prevIndex >= 0 &&
        prevIndex < widget.tabs.length) {
      _controller.index = prevIndex;
    }
    _controller.animation!.addListener(onTabChanged);
  }

  @override
  void didUpdateWidget(covariant AppTabBar oldWidget) {
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? DefaultTabController.of(context);
      _controller.animation!.addListener(onTabChanged);
      initPainter();
    }
    super.didUpdateWidget(oldWidget);
  }

  void initPainter() {
    var old = painter;
    painter = _IndicatorPainter(
      controller: _controller,
      color: context.colorScheme.primary,
      padding: tabPadding,
      radius: tabRadius,
    );
    if (old != null && old.offsets != null && old.itemHeight != null) {
      painter!.update(old.offsets!, old.itemHeight!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller.animation ?? _controller,
      builder: buildTabBar,
    );
  }

  void _tabLayoutCallback(List<double> offsets, double itemHeight) {
    painter!.update(offsets, itemHeight);
    this.offsets = offsets;
  }

  Widget buildTabBar(BuildContext context, Widget? _) {
    var child = SmoothScrollProvider(
      controller: scrollController,
      builder: (context, controller, physics) {
        return SingleChildScrollView(
          key: const PageStorageKey('scroll'),
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          controller: controller,
          physics: physics is BouncingScrollPhysics
              ? const ClampingScrollPhysics()
              : physics,
          child: CustomPaint(
            painter: painter,
            child: _TabRow(
              callback: _tabLayoutCallback,
              children: List.generate(widget.tabs.length, buildTab)
                ..addIfNotNull(widget.actionButton?.padding(tabPadding)),
            ),
          ).paddingHorizontal(4),
        );
      },
    );
    return Container(
      key: tabBarKey,
      height: _kTabHeight,
      width: double.infinity,
      decoration: widget.withUnderLine
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            )
          : null,
      child: widget.tabs.isEmpty ? const SizedBox() : child,
    );
  }

  int? previousIndex;

  void onTabChanged() {
    final int i = _controller.index;
    if (i == previousIndex) {
      return;
    }
    updateScrollOffset(i);
    previousIndex = i;
    bucket.writeState(context, i);
  }

  void updateScrollOffset(int i) {
    // try to scroll to center the tab
    final RenderBox tabBarBox =
        tabBarKey.currentContext!.findRenderObject() as RenderBox;
    final double tabLeft = offsets[i];
    final double tabRight = offsets[i + 1];
    final double tabWidth = tabRight - tabLeft;
    final double tabCenter = tabLeft + tabWidth / 2;
    final double tabBarWidth = tabBarBox.size.width;
    double scrollOffset = tabCenter - tabBarWidth / 2;
    if (scrollOffset == scrollController.offset) {
      return;
    }
    scrollOffset = scrollOffset.clamp(
      0.0,
      scrollController.position.maxScrollExtent,
    );
    scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void onTabClicked(int i) {
    _controller.animateTo(i);
  }

  Widget buildTab(int i) {
    return InkWell(
      onTap: () => onTabClicked(i),
      borderRadius: BorderRadius.circular(tabRadius),
      child: KeyedSubtree(
        key: keys[i],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
              color: i == _controller.animation?.value.round()
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            child: widget.tabs[i],
          ),
        ),
      ),
    ).padding(tabPadding);
  }
}

typedef _TabRenderCallback =
    void Function(List<double> offsets, double itemHeight);

class _TabRow extends Row {
  const _TabRow({required this.callback, required super.children});

  final _TabRenderCallback callback;

  @override
  RenderFlex createRenderObject(BuildContext context) {
    return _RenderTabFlex(
      direction: Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      textDirection: Directionality.of(context),
      verticalDirection: VerticalDirection.down,
      callback: callback,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderTabFlex renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.callback = callback;
  }
}

class _RenderTabFlex extends RenderFlex {
  _RenderTabFlex({
    required super.direction,
    required super.mainAxisSize,
    required super.mainAxisAlignment,
    required super.crossAxisAlignment,
    required TextDirection super.textDirection,
    required super.verticalDirection,
    required this.callback,
  });

  _TabRenderCallback callback;

  @override
  void performLayout() {
    super.performLayout();
    RenderBox? child = firstChild;
    final List<double> xOffsets = <double>[];
    while (child != null) {
      final FlexParentData childParentData =
          child.parentData! as FlexParentData;
      xOffsets.add(childParentData.offset.dx);
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    xOffsets.add(size.width);
    callback(xOffsets, firstChild!.size.height);
  }
}

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter({
    required this.controller,
    required this.color,
    required this.padding,
    this.radius = 4.0,
  }) : super(repaint: controller.animation);

  final TabController controller;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  List<double>? offsets;
  double? itemHeight;
  Rect? _currentRect;

  void update(List<double> offsets, double itemHeight) {
    this.offsets = offsets;
    this.itemHeight = itemHeight;
  }

  int get maxTabIndex => offsets!.length - 2;

  Rect indicatorRect(Size tabBarSize, int tabIndex) {
    assert(offsets != null);
    assert(offsets!.isNotEmpty);
    assert(tabIndex >= 0);
    assert(tabIndex <= maxTabIndex);
    var (tabLeft, tabRight) = (offsets![tabIndex], offsets![tabIndex + 1]);

    const horizontalPadding = 12.0;

    var rect = Rect.fromLTWH(
      tabLeft + padding.left + horizontalPadding,
      _AppTabBarState._kTabHeight - 3.6,
      tabRight - tabLeft - padding.horizontal - horizontalPadding * 2,
      3,
    );

    return rect;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (offsets == null || itemHeight == null) {
      return;
    }
    final double index = controller.index.toDouble();
    final double value = controller.animation!.value;
    final bool ltr = index > value;
    final int from = (ltr ? value.floor() : value.ceil()).clamp(0, maxTabIndex);
    final int to = (ltr ? from + 1 : from - 1).clamp(0, maxTabIndex);
    final Rect fromRect = indicatorRect(size, from);
    final Rect toRect = indicatorRect(size, to);
    _currentRect = Rect.lerp(fromRect, toRect, (value - from).abs());
    final Paint paint = Paint()..color = color;
    final RRect rrect = RRect.fromRectAndCorners(
      _currentRect!,
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class TabViewBody extends StatefulWidget {
  /// Create a tab view body, which will show the child at the current tab index.
  const TabViewBody({super.key, required this.children, this.controller});

  final List<Widget> children;

  final TabController? controller;

  @override
  State<TabViewBody> createState() => _TabViewBodyState();
}

class _TabViewBodyState extends State<TabViewBody> {
  late TabController _controller;

  int _currentIndex = 0;

  void updateIndex() {
    if (_controller.index != _currentIndex) {
      setState(() {
        _currentIndex = _controller.index;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = widget.controller ?? DefaultTabController.of(context);
    _currentIndex = _controller.index;
    _controller.addListener(updateIndex);
  }

  @override
  void dispose() {
    super.dispose();
    _controller.removeListener(updateIndex);
  }

  @override
  Widget build(BuildContext context) {
    return widget.children[_currentIndex];
  }
}

class SearchBarController {
  _SearchBarMixin? _state;

  final void Function(String text)? onSearch;

  String currentText;

  void setText(String text) {
    _state?.setText(text);
  }

  String get text => _state?.getText() ?? '';

  set text(String text) {
    setText(text);
  }

  SearchBarController({this.onSearch, this.currentText = ''});
}

abstract mixin class _SearchBarMixin {
  void setText(String text);

  String getText();
}

class SliverSearchBar extends StatefulWidget {
  const SliverSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.action,
    this.focusNode,
    this.bangumiPage = false,
    this.keywords,
  });

  final SearchBarController controller;

  final void Function(String)? onChanged;

  final Widget? action;

  final FocusNode? focusNode;

  final bool bangumiPage;

  final List<String>? keywords;

  @override
  State<SliverSearchBar> createState() => _SliverSearchBarState();
}

class _SliverSearchBarState extends State<SliverSearchBar>
    with _SearchBarMixin {
  late TextEditingController _editingController;

  late SearchBarController _controller;

  @override
  void initState() {
    _controller = widget.controller;
    _controller._state = this;
    _editingController = TextEditingController(text: _controller.currentText);
    super.initState();
  }

  @override
  void setText(String text) {
    _editingController.text = text;
  }

  @override
  String getText() {
    return _editingController.text;
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverSearchBarDelegate(
        editingController: _editingController,
        controller: _controller,
        topPadding: MediaQuery.of(context).padding.top,
        onChanged: widget.onChanged,
        action: widget.action,
        focusNode: widget.focusNode,
        bangumiPage: widget.bangumiPage,
        keywords: widget.keywords,
      ),
    );
  }
}

class _SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController editingController;

  final SearchBarController controller;

  final double topPadding;

  final void Function(String)? onChanged;

  final Widget? action;

  final FocusNode? focusNode;

  final bool bangumiPage;

  final List<String>? keywords;

  const _SliverSearchBarDelegate({
    required this.editingController,
    required this.controller,
    required this.topPadding,
    this.onChanged,
    this.action,
    this.focusNode,
    this.bangumiPage = false,
    this.keywords,
  });

  static const _kAppBarHeight = 52.0;

  Future<String?> showKeywordsDialog(
    BuildContext context,
    List<String> keywords,
  ) {
    final scrollController = ScrollController();

    return showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 320,
              maxHeight: 500, // 根据需求调整
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '选择别名 (${keywords.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Material(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.transparent,
                    child: ListView.builder(
                      controller: scrollController,
                      shrinkWrap: true,
                      itemCount: keywords.length,
                      itemBuilder: (context, index) {
                        return InkWell(
                          onTap: () => Navigator.pop(context, keywords[index]),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Text(
                              keywords[index],
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: _kAppBarHeight + topPadding,
      width: double.infinity,
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          if (bangumiPage)
            IconButton(
              onPressed: () async {
                final selectedKeyword = await showKeywordsDialog(
                  context,
                  keywords ?? [],
                );
                if (selectedKeyword != null) {
                  controller.onSearch?.call(selectedKeyword);
                  editingController.text = selectedKeyword;
                  appdata.addSearchHistory(selectedKeyword);
                  appdata.saveData();
                }
              },
              icon: const Icon(Icons.change_history),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                focusNode: focusNode,
                controller: editingController,
                decoration: InputDecoration(
                  hintText: "Search".tl,
                  border: InputBorder.none,
                ),
                onSubmitted: (text) {
                  controller.onSearch?.call(text);
                },
                onChanged: onChanged,
              ),
            ),
          ),
          ListenableBuilder(
            listenable: editingController,
            builder: (context, child) {
              return editingController.text.isEmpty
                  ? const SizedBox()
                  : IconButton(
                      iconSize: 20,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        editingController.clear();
                        onChanged?.call("");
                      },
                    );
            },
          ),
          if (action != null) action!,
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  @override
  double get maxExtent => _kAppBarHeight + topPadding;

  @override
  double get minExtent => _kAppBarHeight + topPadding;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return oldDelegate is! _SliverSearchBarDelegate ||
        editingController != oldDelegate.editingController ||
        controller != oldDelegate.controller ||
        topPadding != oldDelegate.topPadding;
  }
}

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({super.key, required this.controller, this.action});

  final SearchBarController controller;

  final Widget? action;

  @override
  State<AppSearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<AppSearchBar> with _SearchBarMixin {
  late TextEditingController _editingController;

  late SearchBarController _controller;

  @override
  void setText(String text) {
    _editingController.text = text;
  }

  @override
  String getText() {
    return _editingController.text;
  }

  @override
  void initState() {
    _controller = widget.controller;
    _controller._state = this;
    _editingController = TextEditingController(text: _controller.currentText);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      height: _kAppBarHeight + topPadding,
      width: double.infinity,
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: _editingController,
                decoration: InputDecoration(
                  hintText: "Search".tl,
                  border: InputBorder.none,
                ),
                onSubmitted: (text) {
                  _controller.onSearch?.call(text);
                },
              ),
            ),
          ),
          ListenableBuilder(
            listenable: _editingController,
            builder: (context, child) {
              return _editingController.text.isEmpty
                  ? const SizedBox()
                  : IconButton(
                      iconSize: 20,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _editingController.clear();
                      },
                    );
            },
          ),
          if (widget.action != null) widget.action!,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class TabActionButton extends StatelessWidget {
  const TabActionButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onPressed,
  });

  final Icon icon;

  final String text;

  final void Function() onPressed;

  static const _kTabHeight = 46.0;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: _kTabHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IconTheme(
          data: IconThemeData(size: 20, color: context.colorScheme.primary),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Text(text, style: ts.withColor(context.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
