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
    appdata.settings[_kSidebarCollapsedKey] = !_sidebarOpen;
    appdata.saveData();
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
      _kBottomBarHeight + MediaQuery.of(context).padding.bottom;

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
    _sidebarOpen =
        appdata.settings[_kSidebarCollapsedKey] != true;
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
    var width = MediaQuery.of(context).size.width;
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
    final isMobileLayout = MediaQuery.of(context).size.width <= changePoint;
    if (!isMobileLayout) {
      return stack;
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(currentPage),
      tween: Tween(begin: _slideInOffset, end: 0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => FractionalTranslation(
        translation: Offset(value, 0),
        child: child,
      ),
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
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.82),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget buildBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: _kBottomBarHeight,
        child: _frostedPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (
              var index = 0;
              index < widget.paneItems.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(width: 4),
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
    );
  }

  /// 桌面侧边栏是否处于展开态（供悬浮栏判断）
  bool get sidebarExpanded => _sidebarOpen;

  /// 悬浮主导航（含两端内边距）的估算宽度
  double get floatingNavWidth =>
      16 +
      widget.paneItems.length * 56 +
      (widget.paneItems.length - 1) * 4;

  /// 动作坞估算宽度
  double get floatingActionWidth =>
      widget.paneActions.length * 44 +
      (widget.paneActions.length - 1) * 2;

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
            SizedBox(height: MediaQuery.of(context).padding.top),
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

  bool isHovering = false;

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: controller, curve: Curves.ease),
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
            width: 56,
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

  /// 底部导航栏是否收缩成一条粗短横线（滚动浏览时）
  bool _minimized = false;

  @override
  void initState() {
    state.mainViewUpdateHandler = () {
      setState(() {});
    };
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _NaviMainView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换 tab 时恢复完整导航栏
    if (oldWidget.state.currentPage != widget.state.currentPage) {
      if (_minimized) {
        setState(() => _minimized = false);
      }
    }
  }

  /// 滚动监听：浏览（手指上滑）收缩为横线；回滚或到顶恢复；不可滚动不收缩
  bool _onScrollNotification(ScrollNotification notification) {
    // 处理所有层级的滚动通知（嵌套滚动：探索页等内部列表也会触发）
    if (notification is ScrollUpdateNotification) {
      // 忽略横向滚动（日历、横向列表等），仅垂直滚动控制导航栏收起
      if (notification.metrics.axis != Axis.vertical) return false;
      final metrics = notification.metrics;
      final delta = notification.scrollDelta ?? 0;
      // 内容不可滚动或已滚到顶部 → 强制显示完整栏
      if (metrics.maxScrollExtent <= 0 || metrics.pixels <= 0) {
        if (_minimized) {
          setState(() => _minimized = false);
        }
        return false;
      }
      // 已滚动到底部附近：保持收缩，避免触底回弹/加载下一页的微小回退触发展开
      if (metrics.pixels >= metrics.maxScrollExtent - 10) {
        return false;
      }
      if (delta > 0 && !_minimized) {
        setState(() => _minimized = true);
      } else if (delta < 0 && _minimized) {
        setState(() => _minimized = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final mqSize = MediaQuery.of(context).size;
    final isWide = mqSize.width > changePoint;
    // 仅移动端（窄屏）显示顶部/底部导航栏；桌面端即使侧边栏收起也不显示
    var shouldShowAppBar =
        state.controller.value < 2 &&
        MediaQuery.of(context).size.width <= changePoint;

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
      final bottomPad = MediaQuery.of(context).padding.bottom + 12;
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
                Align(
                  alignment: Alignment.center,
                  child: state.buildBottom(),
                ),
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
      final Widget floating = AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        child: _minimized
            ? _MiniBar(
                key: const ValueKey('mini'),
                onTap: () => setState(() => _minimized = false),
              )
            : KeyedSubtree(key: const ValueKey('full'), child: fullBars),
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
    return Stack(
      children: [
        Column(
          children: [
            state.buildTop().paddingTop(context.padding.top),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
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
        // 底部：完整导航栏 ↔ 磨砂粗短横线，过渡动画（底部对齐，避免动画结束下坠）
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                );
              },
              child: _minimized
                  ? _MiniBar(
                      key: const ValueKey('mini'),
                      onTap: () => setState(() => _minimized = false),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('full'),
                      child: state.buildBottom(),
                    ),
            ),
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
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.78),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
