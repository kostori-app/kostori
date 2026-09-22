part of 'components.dart';

class PaneItemEntry {
  String label;

  IconData icon;

  IconData activeIcon;

  PaneItemEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class PaneActionEntry {
  String label;

  IconData icon;

  VoidCallback onTap;

  PaneActionEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class NaviPane extends StatefulWidget {
  const NaviPane({
    required this.paneItems,
    required this.paneActions,
    required this.pageBuilder,
    this.initialPage = 0,
    this.onPageChanged,
    required this.observer,
    required this.navigatorKey,
    super.key,
  });

  final List<PaneItemEntry> paneItems;

  final List<PaneActionEntry> paneActions;

  final Widget Function(int page) pageBuilder;

  final void Function(int index)? onPageChanged;

  final int initialPage;

  final NaviObserver observer;

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<NaviPane> createState() => NaviPaneState();

  static NaviPaneState of(BuildContext context) {
    return context.findAncestorStateOfType<NaviPaneState>()!;
  }
}

typedef NaviItemTapListener = void Function(int);

class NaviPaneState extends State<NaviPane>
    with SingleTickerProviderStateMixin {
  late int _currentPage = widget.initialPage;

  bool _canPop = true;

  /// 宽屏时侧边栏是否展开（可完全收起，只留一个展开图标）
  bool _sidebarOpen = true;

  static const _kSidebarCollapsedKey = 'sidebarCollapsed';

  void toggleSidebar() {
    setState(() {
      _sidebarOpen = !_sidebarOpen;
    });
    appdata.implicitData[_kSidebarCollapsedKey] = !_sidebarOpen;
    appdata.writeImplicitData();
  }

  int get currentPage => _currentPage;

  /// 切换前的页面 index（用于决定新页从哪侧滑入）
  int? _lastPage;

  set currentPage(int value) {
    if (value == _currentPage) return;
    _currentPage = value;
    widget.onPageChanged?.call(value);
  }

  void Function()? mainViewUpdateHandler;

  late AnimationController controller;

  final _naviItemTapListeners = <NaviItemTapListener>[];

  void addNaviItemTapListener(NaviItemTapListener listener) {
    _naviItemTapListeners.add(listener);
  }

  void removeNaviItemTapListener(NaviItemTapListener listener) {
    _naviItemTapListeners.remove(listener);
  }

  static const _kBottomBarHeight = 58.0;

  static const _kFoldedSideBarWidth = 72.0;

  static const _kSideBarWidth = 150.0;

  static const _kTopBarHeight = 48.0;

  double get bottomBarHeight =>
      _kBottomBarHeight + MediaQuery.paddingOf(context).bottom;

  /// 翻页选择条（AnimeList paging 模式）的高度
  static const double pageSelectorHeight = 46.0;

  /// 当前探索子页是否是「翻页式 AnimeList」（ExplorePage 同步）。
  /// mixed / multipart 子页没有选择条，不能跟着 paging 设置一起抬高。
  bool _explorePagingSelector = false;

  /// 当前探索子页是否显示右下角信息圆片（ExplorePage 同步，覆盖 mixed）。
  bool _exploreShowChip = false;

  /// 各 AnimeList 注册的底部悬浮形态：owner -> (所属主导航页, 翻页, 圆片)。
  /// 用主导航页下标做标签：非当前页的列表（如 keep-alive 的探索 tab、
  /// 切换到别的导航页后仍挂载的页）不参与，避免误抬升导航栏。
  final Map<Object, (int, bool, bool)> _overlayOwners = {};

  /// 底部悬浮形态变化后安全地请求重建。
  ///
  /// AnimeList.dispose 会在元素 unmount（树锁定）期间调用 unregisterOverlay，
  /// 此时直接 setState 会抛 “widget tree was locked”。统一延后到帧后执行。
  bool _overlayRebuildScheduled = false;

  void _scheduleOverlayRebuild() {
    if (!mounted || _overlayRebuildScheduled) return;
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (mounted) setState(() {});
    });
  }

  /// 由 ExplorePage 在源/子页切换、显示模式变化时同步（mixed 等无 AnimeList）。
  void setExploreOverlay({
    required bool pagingSelector,
    required bool showChip,
  }) {
    if (_explorePagingSelector == pagingSelector &&
        _exploreShowChip == showChip) {
      return;
    }
    _explorePagingSelector = pagingSelector;
    _exploreShowChip = showChip;
    _scheduleOverlayRebuild();
  }

  /// 由 AnimeList 上报自己当前的底部悬浮形态。
  void registerOverlay(
    Object owner, {
    required int navPage,
    required bool paging,
    required bool showChip,
  }) {
    final next = (navPage, paging, showChip);
    if (_overlayOwners[owner] == next) return;
    _overlayOwners[owner] = next;
    _scheduleOverlayRebuild();
  }

  void unregisterOverlay(Object owner) {
    if (_overlayOwners.remove(owner) == null) return;
    _scheduleOverlayRebuild();
  }

  /// 当前导航页是否存在翻页选择条（探索页或任意 AnimeList）。
  bool get _pagingSelectorActive =>
      (currentPage == 4 && _explorePagingSelector) ||
      _overlayOwners.values.any((r) => r.$1 == currentPage && r.$2);

  /// 当前导航页是否显示右下角信息圆片。
  bool get overlayShowChip =>
      (currentPage == 4 && _exploreShowChip) ||
      _overlayOwners.values.any((r) => r.$1 == currentPage && r.$3);

  /// 翻页选择条出现时，悬浮主导航需要抬高的距离，避免与页面底部选择条重叠。
  ///
  /// 翻页选择条贴屏幕底（不走安全区），所以这里把安全区减掉，让导航栏底边
  /// 始终落在选择条上方约 8：导航栏底距 = 安全区 + 12 + lift。
  double get navBottomLift {
    if (!_pagingSelectorActive) return 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return math.max(0.0, pageSelectorHeight + 8 - 12 - safeBottom);
  }

  void onNavigatorStateChange() {
    onRebuild(context);
  }

  void updatePage(int index) {
    for (var listener in _naviItemTapListeners) {
      listener(index);
    }
    if (widget.observer.routes.length > 1) {
      widget.navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
    if (currentPage == index) {
      return;
    }
    // 记录切换前的页面，决定滑入方向
    _lastPage = currentPage;
    // 懒加载：访问过的 tab 才构建（IndexedStack 保持 alive）
    if (!_loadedPages.contains(index)) {
      _loadedPages.add(index);
    }
    setState(() {
      currentPage = index;
    });
    mainViewUpdateHandler?.call();
  }

  /// 已加载（访问过）的 tab 索引，用于懒加载
  final List<int> _loadedPages = [];

  @override
  void initState() {
    _sidebarOpen = appdata.implicitData[_kSidebarCollapsedKey] != true;
    _loadedPages.add(_currentPage);
    controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      lowerBound: 0,
      upperBound: 3,
      vsync: this,
    );
    widget.observer.addListener(onNavigatorStateChange);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    widget.observer.removeListener(onNavigatorStateChange);
    super.dispose();
  }

  double targetFormContext(BuildContext context) {
    var width = MediaQuery.sizeOf(context).width;
    double target = 0;
    if (width > changePoint) {
      // 桌面端：展开显示侧边栏；收起则完全隐藏（value=1）
      target = _sidebarOpen ? 2 : 1;
    }
    if (width > changePoint2) {
      // 宽屏：侧边栏完整展开(3)；收起同样完全隐藏
      target = _sidebarOpen ? 3 : 1;
    }
    return target;
  }

  double? animationTarget;

  void onRebuild(BuildContext context) {
    double target = targetFormContext(context);
    if (controller.value != target || animationTarget != target) {
      if (controller.isAnimating) {
        if (animationTarget == target) {
          return;
        } else {
          controller.stop();
        }
      }
      controller.animateTo(target);
      animationTarget = target;
    }
  }

  @override
  Widget build(BuildContext context) {
    onRebuild(context);
    final mq = MediaQuery.of(context);
    final sideInsets = (App.isMobile && mq.orientation == Orientation.landscape)
        ? EdgeInsets.only(
            left: math.max(mq.viewPadding.left, mq.systemGestureInsets.left),
            right: math.max(mq.viewPadding.right, mq.systemGestureInsets.right),
          )
        : EdgeInsets.zero;
    return _NaviPopScope(
      action: () {
        if (App.mainNavigatorKey!.currentState!.canPop()) {
          App.mainNavigatorKey!.currentState!.maybePop();
        } else {
          SystemNavigator.pop();
        }
      },
      popGesture: App.isIOS && context.width >= changePoint,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final value = controller.value;
          final mainViewLeft =
              _kFoldedSideBarWidth * ((value - 1).clamp(0, 1)) +
              (_kSideBarWidth - _kFoldedSideBarWidth) *
                  ((value - 2).clamp(0, 1));
          Widget content = Stack(
            children: [
              Positioned(
                left: _kFoldedSideBarWidth * ((value - 2.0).clamp(-1.0, 0.0)),
                top: 0,
                bottom: 0,
                child: buildLeft(),
              ),
              Positioned.fill(left: mainViewLeft, child: buildMainView()),
              // 桌面端：侧边栏边缘的收缩/展开手柄（细线 + 中间圆点）
              if (mq.size.width > changePoint)
                Positioned(
                  left: math.max(0.0, mainViewLeft - 7),
                  width: 14,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.center,
                    child: _SidebarHandle(
                      isOpen: _sidebarOpen,
                      onTap: toggleSidebar,
                    ),
                  ),
                ),
            ],
          );
          if (sideInsets != EdgeInsets.zero) {
            content = Padding(padding: sideInsets, child: content);
          }
          return content;
        },
      ),
    );
  }

  Widget buildMainView() {
    return HeroControllerScope(
      controller: MaterialApp.createMaterialHeroController(),
      child: PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          widget.navigatorKey.currentState?.maybePop(result);
        },
        child: NotificationListener<NavigationNotification>(
          onNotification: (NavigationNotification notification) {
            final bool nextCanPop = !notification.canHandlePop;
            if (nextCanPop != _canPop) {
              setState(() {
                _canPop = nextCanPop;
              });
            }
            return false;
          },
          child: Navigator(
            observers: [widget.observer, App.routeObserver],
            key: widget.navigatorKey,
            onGenerateRoute: (settings) => AppPageRoute(
              preventRebuild: false,
              builder: (context) {
                return _NaviMainView(state: this);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildMainViewContent([int? index]) {
    return widget.pageBuilder(index ?? currentPage);
  }

  /// 所有已访问 tab 叠放（IndexedStack），懒加载：切换才构建该页，
  /// 避免启动时 5 个主页面全部加载；非当前页用 HeroMode 禁用 Hero 动画。
  /// 页面切换滑入：新页按导航方向从侧边滑入（IndexedStack 单树实现，
  /// 不能做双树交叉滑动——页面内 TabBarView 在双树并存时会崩
  /// "_DragAnimation.parent is null"）。
  /// 仅窄屏（移动布局）滑入；桌面宽布局直接切换，避免整体平移动画的开销
  Widget buildPageStack() {
    final loaded = [..._loadedPages]..sort();
    Widget stack = IndexedStack(
      index: loaded.indexOf(currentPage),
      children: [
        for (final i in loaded)
          // RepaintBoundary：把每个页面缓存成独立图层，
          // 切换动画期间只做图层位移，避免每帧重绘整棵页面树导致卡顿
          RepaintBoundary(
            child: HeroMode(
              enabled: i == currentPage,
              child: buildMainViewContent(i),
            ),
          ),
      ],
    );
    final isMobileLayout = MediaQuery.sizeOf(context).width <= changePoint;
    if (!isMobileLayout) {
      return stack;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(currentPage),
      tween: Tween(begin: _slideInOffset, end: 0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          FractionalTranslation(translation: Offset(value, 0), child: child),
      child: stack,
    );
  }

  /// 新页滑入的起始偏移：向左导航从左侧（-1），其余从右侧（1）
  double get _slideInOffset {
    if (_lastPage != null && currentPage < _lastPage!) {
      return -1;
    }
    return 1;
  }

  Widget buildTop() {
    return Material(
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16),
        height: _kTopBarHeight,
        width: double.infinity,
        child: Row(
          children: [
            Text(
              widget.paneItems[currentPage].label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            for (var action in widget.paneActions)
              Tooltip(
                message: action.label,
                child: IconButton(
                  icon: Icon(action.icon),
                  onPressed: action.onTap,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 与窄屏底部导航完全一致的磨砂圆角胶囊容器
  Widget _frostedPill({required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    // 关闭模糊时用不透明底色，避免导航栏透出下方内容
    final bgAlpha = BlurEffect.globalEnabled ? 0.82 : 1.0;
    return BlurEffect(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: bgAlpha),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      ),
    );
  }

  Widget buildBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: _kBottomBarHeight,
        child: _frostedPill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (
                  var index = 0;
                  index < widget.paneItems.length;
                  index++
                ) ...[
                  if (index > 0) const SizedBox(width: 8),
                  _SingleBottomNaviWidget(
                    enabled: currentPage == index,
                    entry: widget.paneItems[index],
                    onTap: () {
                      updatePage(index);
                    },
                    key: ValueKey(index),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 桌面侧边栏是否处于展开态（供悬浮栏判断）
  bool get sidebarExpanded => _sidebarOpen;

  /// 悬浮主导航（含两端内边距）的估算宽度
  double get floatingNavWidth =>
      16 + widget.paneItems.length * 44 + (widget.paneItems.length - 1) * 4;

  /// 动作坞估算宽度
  double get floatingActionWidth =>
      widget.paneActions.length * 44 + (widget.paneActions.length - 1) * 2;

  /// 搜索/分类/设置等动作的悬浮操作坞（与窄屏悬浮导航同风格，
  /// 通常紧挨在主悬浮导航右侧一起出现）
  Widget buildActionDock() {
    return _frostedPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.paneActions.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Tooltip(
              message: widget.paneActions[i].label,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: widget.paneActions[i].onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(widget.paneActions[i].icon, size: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 悬浮导航左侧的“更多”按钮：点击向上展开 设置/分类/搜索（与导航栏分离）
  Widget buildFloatingActions({
    required bool open,
    required VoidCallback onToggle,
  }) {
    const size = 40.0;
    Widget circle({required Widget child}) => _frostedPill(
      child: SizedBox(width: size, height: size, child: child),
    );
    Widget item(PaneActionEntry a) => Tooltip(
      message: a.label,
      child: circle(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            onToggle();
            a.onTap();
          },
          child: Icon(a.icon, size: 18),
        ),
      ),
    );
    // 展开内容：向上生长（SizeTransition 从底部对齐）+ 淡入
    final menu = Column(
      key: const ValueKey('actions-menu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in widget.paneActions.reversed) ...[
          item(a),
          const SizedBox(height: 8),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.bottomLeft,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.bottomCenter,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: open
              ? menu
              : const SizedBox(
                  key: ValueKey('actions-menu-empty'),
                  width: size,
                ),
        ),
        Tooltip(
          message: t.more,
          child: circle(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onToggle,
              child: AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Icon(
                  open ? Icons.close_rounded : Icons.grid_view_rounded,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLeft() {
    final value = controller.value;
    const paddingHorizontal = 12.0;
    return Material(
      child: Container(
        width:
            _kFoldedSideBarWidth +
            (_kSideBarWidth - _kFoldedSideBarWidth) * ((value - 2).clamp(0, 1)),
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: paddingHorizontal),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(height: MediaQuery.paddingOf(context).top),
            ...List<Widget>.generate(
              widget.paneItems.length,
              (index) => _SideNaviWidget(
                enabled: currentPage == index,
                entry: widget.paneItems[index],
                showTitle: value == 3,
                onTap: () {
                  updatePage(index);
                },
                key: ValueKey(index),
              ),
            ),
            const Spacer(),
            ...List<Widget>.generate(
              widget.paneActions.length,
              (index) => _PaneActionWidget(
                entry: widget.paneActions[index],
                showTitle: value == 3,
                key: ValueKey(index + widget.paneItems.length),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SideNaviWidget extends StatelessWidget {
  const _SideNaviWidget({
    required this.enabled,
    required this.entry,
    required this.onTap,
    required this.showTitle,
    super.key,
  });

  final bool enabled;

  final PaneItemEntry entry;

  final VoidCallback onTap;

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = Icon(enabled ? entry.activeIcon : entry.icon);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: showTitle
            ? Row(
                children: [icon, const SizedBox(width: 12), Text(entry.label)],
              )
            : Align(alignment: Alignment.centerLeft, child: icon),
      ),
    ).paddingVertical(4);
  }
}

class _PaneActionWidget extends StatelessWidget {
  const _PaneActionWidget({
    required this.entry,
    required this.showTitle,
    super.key,
  });

  final PaneActionEntry entry;

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(entry.icon);
    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: 38,
        child: showTitle
            ? Row(
                children: [icon, const SizedBox(width: 12), Text(entry.label)],
              )
            : Align(alignment: Alignment.centerLeft, child: icon),
      ),
    ).paddingVertical(4);
  }
}

/// 侧边栏边缘的收缩/展开手柄：收起时短线，展开时长线，垂直居中
class _SidebarHandle extends StatelessWidget {
  const _SidebarHandle({required this.onTap, required this.isOpen});

  final VoidCallback onTap;

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: isOpen ? t.collapseSidebar : t.expandSidebar,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          width: 4,
          height: isOpen ? 108 : 40,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SingleBottomNaviWidget extends StatefulWidget {
  const _SingleBottomNaviWidget({
    required this.enabled,
    required this.entry,
    required this.onTap,
    super.key,
  });

  final bool enabled;

  final PaneItemEntry entry;

  final VoidCallback onTap;

  @override
  State<_SingleBottomNaviWidget> createState() =>
      _SingleBottomNaviWidgetState();
}

class _SingleBottomNaviWidgetState extends State<_SingleBottomNaviWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  /// 只建一次：build 里新建 CurvedAnimation 会不断往 controller 挂监听且不释放，
  /// 导航栏重建次数一多就堆积成掉帧源。
  late final CurvedAnimation _curve;

  bool isHovering = false;

  @override
  void dispose() {
    _curve.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SingleBottomNaviWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      value: widget.enabled ? 1 : 0,
      vsync: this,
      duration: _fastAnimationDuration,
    );
    _curve = CurvedAnimation(parent: controller, curve: Curves.ease);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (details) => setState(() => isHovering = true),
          onExit: (details) => setState(() => isHovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTap,
            child: buildContent(),
          ),
        );
      },
    );
  }

  Widget buildContent() {
    final value = controller.value;
    final colorScheme = Theme.of(context).colorScheme;
    final icon = Icon(
      widget.enabled ? widget.entry.activeIcon : widget.entry.icon,
      size: 20,
    );
    final label = Text(
      widget.entry.label,
      style: Theme.of(context).textTheme.labelSmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    Color bgColor = value != 0
        ? colorScheme.secondaryContainer
        : (isHovering ? colorScheme.surfaceContainer : Colors.transparent);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(32)),
              color: bgColor,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 2),
          label,
        ],
      ),
    );
  }
}

class NaviObserver extends NavigatorObserver implements Listenable {
  var routes = Queue<Route>();

  int get pageCount {
    int count = 0;
    for (var route in routes) {
      if (route is AppPageRoute) {
        count++;
      }
    }
    return count;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    routes.removeLast();
    notifyListeners();
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    routes.addLast(route);
    notifyListeners();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    routes.remove(oldRoute);
    if (newRoute != null) {
      routes.add(newRoute);
    }
    notifyListeners();
  }

  List<VoidCallback> listeners = [];

  @override
  void addListener(VoidCallback listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners.remove(listener);
  }

  void notifyListeners() {
    for (var listener in listeners) {
      listener();
    }
  }
}

class _NaviPopScope extends StatelessWidget {
  const _NaviPopScope({
    required this.child,
    this.popGesture = false,
    required this.action,
  });

  final Widget child;
  final bool popGesture;
  final VoidCallback action;

  static bool panStartAtEdge = false;

  @override
  Widget build(BuildContext context) {
    Widget res = child;
    if (popGesture) {
      res = GestureDetector(
        onPanStart: (details) {
          if (details.globalPosition.dx < 64) {
            panStartAtEdge = true;
          }
        },
        onPanEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0 ||
              details.velocity.pixelsPerSecond.dx > 0) {
            if (panStartAtEdge) {
              action();
            }
          }
          panStartAtEdge = false;
        },
        child: res,
      );
    }
    return res;
  }
}

class _NaviMainView extends StatefulWidget {
  const _NaviMainView({required this.state});

  final NaviPaneState state;

  @override
  State<_NaviMainView> createState() => _NaviMainViewState();
}

class _NaviMainViewState extends State<_NaviMainView> {
  NaviPaneState get state => widget.state;

  /// 底部导航栏是否收缩成一条粗短横线（滚动浏览时）。
  /// 用 ValueNotifier + ValueListenableBuilder 驱动，只重建悬浮栏本身，
  /// 不再让滚动收起/展开去 setState 整棵主视图（会连带重建页面栈）。
  final ValueNotifier<bool> _minimized = ValueNotifier<bool>(false);

  /// 悬浮导航左侧的“更多”动作菜单是否展开
  final ValueNotifier<bool> _actionsOpen = ValueNotifier<bool>(false);

  /// 滚动收放的方向累积量（滞回），避免嵌套滚动/回弹的符号抖动反复切换。
  double _scrollAccum = 0;

  static const double _kToggleThreshold = 12.0;

  @override
  void initState() {
    state.mainViewUpdateHandler = () {
      setState(() {});
    };
    // 显示模式/抬升开关变化时，导航栏位置要跟着更新
    appdata.settings.addListener(_onSettingsChanged);
    super.initState();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_onSettingsChanged);
    _minimized.dispose();
    _actionsOpen.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _NaviMainView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换 tab 时恢复完整导航栏
    if (oldWidget.state.currentPage != widget.state.currentPage) {
      _minimized.value = false;
      _actionsOpen.value = false;
      _scrollAccum = 0;
    }
  }

  /// 滚动监听：浏览（手指上滑）收缩为横线；回滚或到顶恢复；不可滚动不收缩
  ///
  /// 注意用“全类型 + metrics”判断：短内容根本发不出 ScrollUpdateNotification
  ///（也没有滚动增量），只靠 update 分支里的 `maxScrollExtent<=0` 永远执行不到，
  /// 切源/刷新后变短就会脏留收缩态。这里 Metrics/Overscroll/End 通知同样
  /// 做强制展开校正。
  bool _onScrollNotification(ScrollNotification notification) {
    // 处理所有层级的滚动通知（嵌套滚动：探索页等内部列表也会触发）
    // 忽略横向滚动（日历、横向列表等），仅垂直滚动控制导航栏收起
    if (notification.metrics.axis != Axis.vertical) return false;
    final metrics = notification.metrics;
    // 内容不可滚动或已滚到顶部 → 强制显示完整栏
    if (metrics.maxScrollExtent <= 0 || metrics.pixels <= 0) {
      _scrollAccum = 0;
      if (_minimized.value) {
        _minimized.value = false;
      }
      return false;
    }
    if (notification is! ScrollUpdateNotification) return false;
    // 已滚动到底部附近：保持收缩，避免触底回弹/加载下一页的微小回退触发展开
    if (metrics.pixels >= metrics.maxScrollExtent - 10) return false;
    final delta = notification.scrollDelta ?? 0;
    // 方向变化时清零，只在同一方向上累积够阈值才切换
    if ((delta > 0) != (_scrollAccum > 0)) _scrollAccum = 0;
    _scrollAccum += delta;
    if (_scrollAccum >= _kToggleThreshold && !_minimized.value) {
      _minimized.value = true;
      _actionsOpen.value = false;
      _scrollAccum = 0;
    } else if (_scrollAccum <= -_kToggleThreshold && _minimized.value) {
      _minimized.value = false;
      _scrollAccum = 0;
    }
    return false;
  }

  /// 只订阅收放状态重建悬浮栏；主视图/页面栈不受影响。
  Widget _minimizedState(
    Widget Function(bool minimized, bool actionsOpen) builder,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: _minimized,
      builder: (context, minimized, _) => ValueListenableBuilder<bool>(
        valueListenable: _actionsOpen,
        builder: (context, open, _) => builder(minimized, open),
      ),
    );
  }

  /// 悬浮栏完整态 ↔ 收缩横线的共用切换动画：上浮淡入（300ms easeOutCubic），
  /// 下沉淡出；旧的 scale 0.6 缩放观感偏“弹”，改为位移后更跟手。
  static const _kNavSwitchDuration = Duration(milliseconds: 300);

  static Widget _navSwitchTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  /// 顶部状态栏的磨砂玻璃（内容从下方滚过时被模糊）
  Widget _frostedStatusBar() {
    final cs = Theme.of(context).colorScheme;
    return BlurEffect(
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.45),
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mqSize = MediaQuery.sizeOf(context);
    final isWide = mqSize.width > changePoint;
    // 仅移动端（窄屏）显示顶部/底部导航栏；桌面端即使侧边栏收起也不显示
    var shouldShowAppBar =
        state.controller.value < 2 &&
        MediaQuery.sizeOf(context).width <= changePoint;

    // 宽屏下侧边栏被完全收起：显示窄屏风格悬浮导航 + 紧邻其右侧的动作坞；
    // 与窄屏一致，跟随滚动收缩成横线（点一下展开）
    final wideCollapsed =
        isWide && !state.sidebarExpanded && state.controller.value < 1.02;
    if (wideCollapsed) {
      Widget page = Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: false,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: state.buildPageStack(),
              ),
            ),
          ),
        ],
      );
      final bottomPad =
          MediaQuery.paddingOf(context).bottom + 12 + state.navBottomLift;
      // 完整态：主悬浮导航居中 + 动作坞紧贴其右侧（不合并成整行居中）
      final Widget fullBars = SizedBox(
        height: NaviPaneState._kBottomBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final navW = state.floatingNavWidth;
            final dockW = state.floatingActionWidth;
            double dockLeft = (constraints.maxWidth - navW) / 2 + navW + 12;
            final maxLeft = constraints.maxWidth - dockW - 8;
            dockLeft = math.min(dockLeft, math.max(0.0, maxLeft));
            return Stack(
              children: [
                Align(alignment: Alignment.center, child: state.buildBottom()),
                Positioned(
                  left: dockLeft,
                  top: (constraints.maxHeight - 44) / 2,
                  child: state.buildActionDock(),
                ),
              ],
            );
          },
        ),
      );
      // 完整态 ↔ 收缩横线 走与窄屏一致的动画，且整体底部对齐（横条不会悬高）
      final Widget floating = _minimizedState(
        (minimized, _) => AnimatedSwitcher(
          duration: _kNavSwitchDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: _navSwitchTransition,
          child: minimized
              ? _MiniBar(
                  key: const ValueKey('mini'),
                  onTap: () => _minimized.value = false,
                )
              : KeyedSubtree(key: const ValueKey('full'), child: fullBars),
        ),
      );
      return Stack(
        children: [
          Positioned.fill(child: page),
          // 只约束左右到边并锚定底部，子内容（含 mini 横线）自然贴底
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad,
            child: Center(child: floating),
          ),
        ],
      );
    }

    if (!shouldShowAppBar) {
      return Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: false,
              child: state.buildPageStack(),
            ),
          ),
        ],
      );
    }
    final bottomPad =
        MediaQuery.paddingOf(context).bottom + 12 + state.navBottomLift;
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              // 顶部不做实心留白：让页面背景延伸到状态栏下方（状态栏透明），
              // 页面内部各自用 MediaQuery.padding.top 让出安全距离
              child: MediaQuery.removePadding(
                context: context,
                removeTop: false,
                removeBottom: true,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  // 内容直接延伸到窗口底部（悬浮栏后），页面背景覆盖到底，
                  // 避免 Padding 间隙露出父容器背景形成黑条
                  child: state.buildPageStack(),
                ),
              ),
            ),
          ],
        ),
        // 顶部状态栏区域：磨砂玻璃（内容从下方滚过时被模糊）
        if (topInset > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset,
            child: _frostedStatusBar(),
          ),
        // 底部：动作按钮（分离，位于悬浮导航左侧，可向上展开）+ 悬浮导航
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPad,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const btnW = 40.0;
              const navH = NaviPaneState._kBottomBarHeight;
              final navW = state.floatingNavWidth;
              // 始终按完整展开高度预留（让展开/收起的动画不被裁切）
              final fullColH =
                  state.widget.paneActions.length * (btnW + 8) + btnW;
              final stackH = math.max(navH, (navH - btnW) / 2 + fullColH + 12);
              final btnLeft = math.max(
                8.0,
                (constraints.maxWidth - navW) / 2 - btnW - 14,
              );
              return _minimizedState(
                (minimized, open) => SizedBox(
                  height: stackH,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: _kNavSwitchDuration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            transitionBuilder: _navSwitchTransition,
                            child: minimized
                                ? _MiniBar(
                                    key: const ValueKey('mini'),
                                    onTap: () => _minimized.value = false,
                                  )
                                : KeyedSubtree(
                                    key: const ValueKey('full'),
                                    child: state.buildBottom(),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: btnLeft,
                        bottom: (navH - btnW) / 2,
                        child: IgnorePointer(
                          ignoring: minimized,
                          // 与主切换同节奏（300ms easeOutCubic），避免动作坞先走完
                          child: AnimatedOpacity(
                            opacity: minimized ? 0 : 1,
                            duration: _kNavSwitchDuration,
                            curve: Curves.easeOutCubic,
                            child: AnimatedScale(
                              scale: minimized ? 0.6 : 1,
                              duration: _kNavSwitchDuration,
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.bottomCenter,
                              child: state.buildFloatingActions(
                                open: open,
                                onToggle: () =>
                                    _actionsOpen.value = !_actionsOpen.value,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 收缩后的底部导航栏：一条磨砂透明的粗短横线
class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 8,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}

/// 信息圆片（含 1.2 倍缩放后）的视觉高度估算。
const double _kOverlayChipHeight = 27.0;

/// 圆片与悬浮按钮之间的间距。
const double _kOverlayFabGap = 8.0;

/// 信息圆片与屏幕底边的间距（个位数，避免完全贴边）。
const double _kOverlayChipMargin = 4.0;

/// 底部悬浮控件的基准底距：真实安全区 + 翻页抬升（不含导航栏的 12 边距）。
///
/// 注意：页面内容被 `MediaQuery.removePadding(removeBottom: true)` 处理过，
/// 这里的 `MediaQuery.padding.bottom` 读到的是 0；必须从 NaviPane 的栏高反推
/// 真实安全区，否则控件会被系统手势条盖住。
double _overlaySafeBottom(BuildContext context) {
  final navi = context.findAncestorStateOfType<NaviPaneState>();
  final safeBottom = navi != null
      ? navi.bottomBarHeight - NaviPaneState._kBottomBarHeight
      : MediaQuery.paddingOf(context).bottom;
  return safeBottom + (navi?.navBottomLift ?? 0);
}

/// 信息圆片的底距：左右贴屏幕边，底部留 [_kOverlayChipMargin]。
double navOverlayChipBottom(BuildContext context) =>
    _overlaySafeBottom(context) + _kOverlayChipMargin;

/// 悬浮按钮的底距：
/// - 有信息圆片时垫在圆片上方，留出 [_kOverlayFabGap] 间距；
/// - 翻页模式没有圆片，与主导航栏垂直居中对齐。
double navOverlayFabBottom(BuildContext context) {
  final navi = context.findAncestorStateOfType<NaviPaneState>();
  if (navi != null && !navi.overlayShowChip) {
    // 导航栏底距屏幕 12，按钮在 58 高的导航栏内垂直居中
    return _overlaySafeBottom(context) +
        12 +
        (NaviPaneState._kBottomBarHeight - 40) / 2;
  }
  return navOverlayChipBottom(context) + _kOverlayChipHeight + _kOverlayFabGap;
}
