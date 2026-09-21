// ignore_for_file: file_names

import 'package:extended_tabs/extended_tabs.dart';
import 'package:flutter/material.dart';
import 'package:kostori/components/anime_list.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/global_state.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/cache.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/translations.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<ExplorePage> {
  late TabController sourceController;
  late Map<String, TabController> pageControllers = {};

  /// 上次已持久化的源下标（避免拖动时逐帧写盘）
  int? _lastSourceIndex;

  /// 悬浮头当前展示的源下标（变化时重建头部，切换分类胶囊）
  int? _headerSourceIndex;

  /// 悬浮源导航条：测量高度供内容顶部让位
  final GlobalKey _sourceBarKey = GlobalKey();
  double _sourceBarH = 0;

  void _syncSourceBarH() {
    final rb = _sourceBarKey.currentContext?.findRenderObject();
    if (rb is! RenderBox) return;
    final h = rb.size.height;
    if (mounted && (h - _sourceBarH).abs() > 0.5) {
      setState(() => _sourceBarH = h);
    }
  }

  // 原 ExploreController 逻辑直接并入本页（无全局共享需求，去掉 mobx）
  bool _showFB = false;
  late AnimationController _fbController;
  late Animation<double> _fbFade;

  void _showFloating() {
    if (_showFB) return;
    setState(() => _showFB = true);
    _fbController.forward();
  }

  void _hideFloating() {
    if (!_showFB) return;
    setState(() => _showFB = false);
    _fbController.reverse();
  }

  bool get horizontalLayout => appdata.settings.s.exploreHorizontalLayout;

  double location = 0;

  late List<String> sources;
  late Map<String, List<String>> sourcePages;

  void onSettingsChanged() {
    final pagesMap = _readPagesMap();
    var savedOrder = List<String>.from(appdata.settings.s.exploreSourcesOrder);
    var allSources = AnimeSource.all();
    var newSourcePages = <String, List<String>>{};
    var newSources = <String>[];

    for (var key in savedOrder) {
      var source = AnimeSource.find(key);
      if (source == null) continue;
      // 源已关闭时不在探索页显示（AnimeSource.find 不过滤禁用）
      if (!AnimeSourceManager().isEnabled(key)) continue;
      var allPagesForSource = source.explorePages.map((e) => e.title).toList();
      var pagesForSource = (pagesMap[key] ?? [])
          .where((p) => allPagesForSource.contains(p))
          .toList();
      if (pagesForSource.isNotEmpty) {
        newSources.add(key);
        newSourcePages[key] = pagesForSource;
      }
    }

    for (var source in allSources) {
      if (!newSources.contains(source.key)) {
        var allPagesForSource = source.explorePages
            .map((e) => e.title)
            .toList();
        var pagesForSource = (pagesMap[source.key] ?? [])
            .where((p) => allPagesForSource.contains(p))
            .toList();
        if (pagesForSource.isNotEmpty) {
          newSources.add(source.key);
          newSourcePages[source.key] = pagesForSource;
        }
      }
    }

    // 探索页的源/页配置没变化（如从详情页返回时的无关设置写入）：
    // 不重建 TabController，避免选中 Tab 被重置
    if (_sameSources(newSources, sources) &&
        _samePages(newSourcePages, sourcePages)) {
      return;
    }

    setState(() {
      // 重建前记录当前选中的源与各源的页索引，按 key 恢复
      final prevSourceKey =
          sources.isNotEmpty && sourceController.index < sources.length
          ? sources[sourceController.index]
          : null;
      final prevPageIndices = <String, int>{
        for (var s in pageControllers.keys) s: pageControllers[s]?.index ?? 0,
      };

      sources = newSources;
      sourcePages = newSourcePages;
      _rebuildPageControllers(prevPageIndices);

      final old = sourceController;
      sourceController = TabController(length: sources.length, vsync: this);
      old.removeListener(_onSourceChanged);
      old.dispose();
      if (prevSourceKey != null) {
        final idx = sources.indexOf(prevSourceKey);
        if (idx != -1) sourceController.index = idx;
      }
      sourceController.addListener(_onSourceChanged);
    });
  }

  bool _sameSources(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _samePages(Map<String, List<String>> a, Map<String, List<String>> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || !_sameSources(entry.value, other)) return false;
    }
    return true;
  }

  void _rebuildPageControllers([Map<String, int>? prevIndices]) {
    final persisted = _loadPageIndices();
    for (final source in sources) {
      var pages = sourcePages[source] ?? [];
      // 恢复顺序：内存中的上次索引 > 持久化索引 > 0
      var prevIndex =
          prevIndices?[source] ??
          pageControllers[source]?.index ??
          (persisted[source] as num?)?.toInt() ??
          0;
      pageControllers[source]?.dispose();
      pageControllers[source] = TabController(
        length: pages.length,
        vsync: this,
      );
      if (pages.isNotEmpty && prevIndex < pages.length) {
        pageControllers[source]!.index = prevIndex;
      }
    }
  }

  void onNaviItemTapped(int index) {
    if (index == 4) {
      String currentSource = sources[sourceController.index];
      int pageIndex = pageControllers[currentSource]?.index ?? 0;
      String currentPageId = sourcePages[currentSource]![pageIndex];
      // 页面可能尚未构建或已销毁，找不到时静默跳过
      GlobalState.findOrNull<_SingleExplorePageState>(
        _explorePageStateKey(currentSource, currentPageId),
      )?.toTop();
    }
  }

  void addPage() {
    showPopUpWidget(App.rootContext, setExplorePagesWidget());
  }

  Map<String, List<String>> _readPagesMap() {
    final rawMap = appdata.settings.s.explorePagesV2;
    return rawMap.map((k, v) => MapEntry(k, List<String>.from(v as List)));
  }

  NaviPaneState? naviPane;

  @override
  void initState() {
    super.initState();
    _initSourcesAndPages();
    sourceController = TabController(length: sources.length, vsync: this);
    _restoreSourceIndex();
    sourceController.addListener(_onSourceChanged);
    _rebuildPageControllers();
    appdata.settings.addListener(onSettingsChanged);
    // 源被启用/禁用（设置页开关）时也要刷新：探索页的源列表与 TabController
    // 必须一起重建，否则会停留/错位在旧的源上
    AnimeSourceManager().addListener(onSettingsChanged);
    NaviPane.of(context).addNaviItemTapListener(onNaviItemTapped);
    _fbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fbFade = CurvedAnimation(parent: _fbController, curve: Curves.easeInOut);
  }

  void _initSourcesAndPages() {
    final pagesMap = _readPagesMap();
    var savedOrder = List<String>.from(appdata.settings.s.exploreSourcesOrder);
    sourcePages = {};
    sources = [];

    for (var key in savedOrder) {
      var source = AnimeSource.find(key);
      if (source == null) continue;
      // 源已关闭时不在探索页显示（AnimeSource.find 不过滤禁用）
      if (!AnimeSourceManager().isEnabled(key)) continue;
      var allPagesForSource = source.explorePages.map((e) => e.title).toList();
      var pagesForSource = (pagesMap[key] ?? [])
          .where((p) => allPagesForSource.contains(p))
          .toList();
      if (pagesForSource.isNotEmpty) {
        sources.add(key);
        sourcePages[key] = pagesForSource;
      }
    }

    for (var source in AnimeSource.all()) {
      if (!sources.contains(source.key)) {
        var allPagesForSource = source.explorePages
            .map((e) => e.title)
            .toList();
        var pagesForSource = (pagesMap[source.key] ?? [])
            .where((p) => allPagesForSource.contains(p))
            .toList();
        if (pagesForSource.isNotEmpty) {
          sources.add(source.key);
          sourcePages[source.key] = pagesForSource;
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    naviPane = NaviPane.of(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // 写盘延到下一帧：writeImplicitData 会 notifyListeners，dispose 期调用会崩
    final savedIndices = <String, dynamic>{
      for (final s in pageControllers.keys) s: pageControllers[s]?.index ?? 0,
    };
    final savedSourceKey =
        sourceController.index >= 0 && sourceController.index < sources.length
        ? sources[sourceController.index]
        : null;
    sourceController.removeListener(_onSourceChanged);
    sourceController.dispose();
    for (var c in pageControllers.values) {
      c.dispose();
    }
    appdata.settings.removeListener(onSettingsChanged);
    AnimeSourceManager().removeListener(onSettingsChanged);
    naviPane?.removeNaviItemTapListener(onNaviItemTapped);
    _fbController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appdata.implicitData['explorePageIndices'] = savedIndices;
      if (savedSourceKey != null) {
        appdata.implicitData['exploreSourceKey'] = savedSourceKey;
      }
      appdata.writeImplicitData();
    });
    super.dispose();
  }

  /// 读取持久化的二级 tab 索引
  Map<String, dynamic> _loadPageIndices() {
    final v = appdata.implicitData['explorePageIndices'];
    if (v is Map) {
      return Map<String, dynamic>.from(v);
    }
    return <String, dynamic>{};
  }

  /// 恢复上次选中的源（按 key，源顺序变化也能对上）
  void _restoreSourceIndex() {
    final key = appdata.implicitData['exploreSourceKey']?.toString();
    if (key == null || key.isEmpty) return;
    final idx = sources.indexOf(key);
    if (idx <= 0 || idx >= sources.length) return;
    // 在首帧之后再切换：ExtendedTabBarView 尚未构建时直接设 index 会丢失，
    // 导致停在默认（第一个）或异常跳到末尾
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || idx >= sourceController.length) return;
      sourceController.animateTo(idx, duration: Duration.zero);
    });
  }

  /// 源切换：刷新悬浮头（分类胶囊随源变化）+ 持久化
  void _onSourceChanged() {
    final i = sourceController.index;
    if (i < 0 || i >= sources.length) return;
    if (i != _headerSourceIndex) {
      _headerSourceIndex = i;
      if (mounted) setState(() {});
    }
    if (sourceController.indexIsChanging) return;
    if (i == _lastSourceIndex) return;
    _lastSourceIndex = i;
    appdata.implicitData['exploreSourceKey'] = sources[i];
    appdata.writeImplicitData();
  }

  void refresh() {
    String currentSource = sources[sourceController.index];
    int pageIndex = pageControllers[currentSource]?.index ?? 0;
    String currentPageId = sourcePages[currentSource]![pageIndex];
    GlobalState.findOrNull<_SingleExplorePageState>(
      _explorePageStateKey(currentSource, currentPageId),
    )?.refresh();
  }

  Widget buildEmpty() {
    var msg = t.noExplorePages;
    msg += '\n';
    VoidCallback onTap;
    if (AnimeSource.isEmpty) {
      msg += t.pleaseAddSomeSources;
      onTap = () {
        context.to(() => AnimeSourceSettings());
      };
    } else {
      msg += t.pleaseCheckYourSettings;
      onTap = addPage;
    }
    return NetworkError(
      message: msg,
      retry: onTap,
      withAppbar: false,
      buttonText: t.manage,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (sources.isEmpty) {
      return buildEmpty();
    }

    final cs = Theme.of(context).colorScheme;
    final headerSource =
        sourceController.index >= 0 && sourceController.index < sources.length
        ? sources[sourceController.index]
        : null;
    final headerPages = headerSource == null
        ? const <String>[]
        : (sourcePages[headerSource] ?? const <String>[]);
    final headerCtrl = headerSource == null
        ? null
        : pageControllers[headerSource];
    Widget sourceTabBar = BlurEffect(
      key: _sourceBarKey,
      child: Container(
        width: double.infinity,
        color: cs.surface.toOpacity(0.72),
        padding: EdgeInsets.fromLTRB(12, 6 + context.padding.top, 12, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SlidingSegmentedBar(
                scrollable: true,
                selectedIndex: sourceController.index,
                progress: sourceController.animation,
                actionButton: TabActionButton(
                  icon: const Icon(Icons.add),
                  text: t.add,
                  dense: true,
                  onPressed: addPage,
                ),
                trackDecoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.toOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorDecoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.toOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                children: [
                  for (var i = 0; i < sources.length; i++)
                    CapsuleOption(
                      text: AnimeSource.find(sources[i])?.name ?? sources[i],
                      isSelected: sourceController.index == i,
                      onTap: () => sourceController.animateTo(i),
                    ),
                ],
              ),
            ),
            if (headerCtrl != null && headerPages.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: SlidingSegmentedBar(
                  scrollable: true,
                  selectedIndex: headerCtrl.index,
                  progress: headerCtrl.animation,
                  trackDecoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.toOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorDecoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.toOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  children: [
                    for (var i = 0; i < headerPages.length; i++)
                      CapsuleOption(
                        text: headerPages[i].ts(headerSource!),
                        isSelected: headerCtrl.index == i,
                        onTap: () => headerCtrl.animateTo(i),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncSourceBarH());
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ExtendedTabBarView(
              controller: sourceController,
              // 桌面端不用滚轮/拖动翻源，避免误切
              physics: tabPagePhysics,
              children: sources
                  .map(
                    (sourceKey) => _SourceExplorePage(
                      key: ValueKey(sourceKey),
                      sourceKey: sourceKey,
                      pages: sourcePages[sourceKey] ?? [],
                      pageController: pageControllers[sourceKey]!,
                      onFloatingShow: _showFloating,
                      onFloatingHide: _hideFloating,
                      horizontalLayout: horizontalLayout,
                      topInset: _sourceBarH,
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, child: sourceTabBar),
        // 注意：Positioned 必须是 Stack 的直接子节点，包在 AnimatedBuilder
        // 里会失效（按钮被当普通 child 排到左上角）——所以 Positioned 在外、
        // 动画在内。bottom 用主导航高度对齐，紧贴悬浮导航栏上方
        Positioned(
          bottom: _fbBottom(context),
          right: 10,
          child: AnimatedBuilder(
            animation: _fbController,
            builder: (_, _) => FadeTransition(
              opacity: _fbFade,
              child: IgnorePointer(
                ignoring: !_showFB,
                child: GridSpeedDial(
                  icon: Icons.menu,
                  activeIcon: Icons.close,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  // 与 FloatingMenu 一致的紧凑圆形 + 磨砂玻璃
                  frosted: true,
                  mini: true,
                  elevation: 0,
                  buttonSize: const Size(40, 40),
                  childrenButtonSize: const Size(40, 40),
                  shape: const CircleBorder(),
                  iconTheme: const IconThemeData(size: 20),
                  animatedIconTheme: const IconThemeData(size: 20),
                  spacing: 6,
                  spaceBetweenChildren: 4,
                  direction: SpeedDialDirection.up,
                  childPadding: const EdgeInsets.all(2),
                  childrens: [
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.refresh),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: refresh,
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child: const Icon(Icons.vertical_align_top),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: () {
                          String currentSource =
                              sources[sourceController.index];
                          int pageIndex =
                              pageControllers[currentSource]?.index ?? 0;
                          String currentPageId =
                              sourcePages[currentSource]![pageIndex];
                          GlobalState.findOrNull<_SingleExplorePageState>(
                            _explorePageStateKey(
                              currentSource,
                              currentPageId,
                            ),
                          )?.toTop();
                        },
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child:
                            appdata.settings['animeListDisplayMode'] == 'paging'
                            ? Icon(Icons.view_cozy_outlined)
                            : Icon(Icons.menu),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: () {
                          appdata.settings['animeListDisplayMode'] =
                              appdata.settings['animeListDisplayMode'] ==
                                  'paging'
                              ? 'continuous'
                              : 'paging';
                          appdata.saveData();
                          refresh();
                          setState(() {});
                        },
                      ),
                    ],
                    [
                      SpeedDialChild(
                        child:
                            appdata.settings.s.exploreHorizontalLayout == true
                            ? Icon(Icons.view_week)
                            : Icon(Icons.view_module),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        onTap: () {
                          appdata.settings.update(
                            (s) => s.copyWith(
                              exploreHorizontalLayout:
                                  !appdata.settings.s.exploreHorizontalLayout,
                            ),
                          );
                          appdata.saveData();
                          setState(() {});
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 悬浮按钮底距：主导航高度（含安全区）+ 间距，紧贴导航栏上方
  double _fbBottom(BuildContext context) {
    final navi = context.findAncestorStateOfType<NaviPaneState>();
    final inset =
        navi?.bottomBarHeight ?? MediaQuery.paddingOf(context).bottom;
    return inset + 15;
  }

  @override
  bool get wantKeepAlive => true;
}

/// 探索页子页面的全局状态 key。
///
/// 必须带上源 key：不同源常有同名子页（如都叫「最新」「热门」），只按标题
/// 查找会命中别的源的页面，导致刷新 / 回顶作用到了错误的页面上。
String _explorePageStateKey(String sourceKey, String pageTitle) =>
    'explore|$sourceKey|$pageTitle';

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(
    this.title, {
    super.key,
    required this.sourceKey,
    required this.onFloatingShow,
    required this.onFloatingHide,
    this.horizontalLayout = false,
    this.topInset = 0,
  });

  final String title;
  final String sourceKey;
  final VoidCallback onFloatingShow;
  final VoidCallback onFloatingHide;

  final bool horizontalLayout;

  /// 悬浮头高度：作为列表首个 sliver 的顶部留白，滚动时内容从其下方穿过
  final double topInset;

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends AutomaticGlobalState<_SingleExplorePage>
    with AutomaticKeepAliveClientMixin<_SingleExplorePage> {
  late final ExplorePageData data;

  late final String animeSourceKey;

  var scrollController = ScrollController();

  bool _wantKeepAlive = true;

  VoidCallback? refreshHandler;

  void onSettingsChanged() {
    final rawMap = appdata.settings.s.explorePagesV2;

    final pages = List<String>.from(rawMap[animeSourceKey] ?? []);
    if (!pages.contains(widget.title)) {
      _wantKeepAlive = false;
      updateKeepAlive();
    }
  }

  void onScroll() {
    final canScroll = scrollController.hasClients &&
        scrollController.position.maxScrollExtent > 0;
    // 内容不可滚动时也显示浮动按钮
    final shouldShow = !canScroll || scrollController.offset > 50;
    if (shouldShow) {
      widget.onFloatingShow();
    } else {
      widget.onFloatingHide();
    }
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(onScroll);
    // 内容不可滚动时（无滚动监听触发）也显示浮动按钮
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) onScroll();
    });
    var source = AnimeSource.find(widget.sourceKey);
    if (source != null) {
      for (var d in source.explorePages) {
        if (d.title == widget.title) {
          data = d;
          animeSourceKey = source.key;
          appdata.settings.addListener(onSettingsChanged);
          return;
        }
      }
    }
    throw "Explore Page ${widget.title} Not Found!";
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    scrollController.dispose();
    appdata.settings.removeListener(onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 布局覆盖：本页 > 该源 > 探索设置里的全局默认（null 表示跟随下一级）
    // 用页面标题作为子 key：重命名页面会丢掉该页覆盖，但顺序调整不受影响
    final pageModeKey = 'page:${widget.title}';
    final pageMode = ExploreSourceDisplayMode.of(animeSourceKey, pageModeKey);
    final modeBar = SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: widget.topInset),
          AnimeSourceLayoutBar(
            sourceKey: animeSourceKey,
            subKey: pageModeKey,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ],
      ),
    );

    Widget child;
    if (data.loadMultiPart != null) {
      child = _MultiPartExplorePage(
        key: PageStorageKey("anime_list_${widget.title}"),
        data: data,
        controller: scrollController,
        animeSourceKey: animeSourceKey,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
        horizontalLayout: widget.horizontalLayout,
        leadingSliver: modeBar,
      );
    } else if (data.loadPage != null || data.loadNext != null) {
      child = AnimeList(
        enablePageStorage: true,
        loadPage: data.loadPage,
        loadNext: data.loadNext,
        key: PageStorageKey("anime_list_${widget.title}"),
        controller: scrollController,
        // 探索页用页面级 GridSpeedDial，避免多 tab 浮动按钮叠加
        enableFloatingMenu: false,
        leadingSliver: modeBar,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
      );
    } else if (data.loadMixed != null) {
      child = AppScrollBar(
        // topPadding: 10,
        controller: scrollController,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: _MixedExplorePage(
            data,
            animeSourceKey,
            key: PageStorageKey("anime_list_${widget.title}"),
            controller: scrollController,
            refreshHandlerCallback: (c) {
              refreshHandler = c;
            },
            leadingSliver: modeBar,
          ),
        ),
      );
    } else {
      child = Center(child: Text(t.emptyPage));
    }
    return AnimeDisplayModeScope(mode: pageMode, child: child);
  }

  @override
  Object? get key => _explorePageStateKey(widget.sourceKey, widget.title);

  @override
  void refresh() {
    // 用户主动刷新：清掉内存响应缓存（同一个 URL 否则会命中 5 秒~2 小时
    // 的缓存，表现为「没有重新请求、内容也不刷新」）
    NetworkCacheManager().clear();
    refreshHandler?.call();
  }

  @override
  bool get wantKeepAlive => _wantKeepAlive;

  void toTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }
}

class _MixedExplorePage extends StatefulWidget {
  const _MixedExplorePage(
    this.data,
    this.sourceKey, {
    super.key,
    this.controller,
    required this.refreshHandlerCallback,
    this.leadingSliver,
  });

  final ExplorePageData data;

  final String sourceKey;

  final ScrollController? controller;

  final void Function(VoidCallback c) refreshHandlerCallback;

  final Widget? leadingSliver;

  @override
  State<_MixedExplorePage> createState() => _MixedExplorePageState();
}

class _MixedExplorePageState
    extends MultiPageLoadingState<_MixedExplorePage, Object> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.refreshHandlerCallback(refresh);
  }

  void refresh() {
    reset();
  }

  Iterable<Widget> buildSlivers(BuildContext context, List<Object> data) sync* {
    List<Anime> cache = [];
    for (var part in data) {
      if (part is ExplorePagePart) {
        if (cache.isNotEmpty) {
          yield SliverGridAnimes(animes: (cache));
          yield const SliverToBoxAdapter(child: Divider());
          cache.clear();
        }
        yield* _buildExplorePagePart(part, widget.sourceKey);
        yield const SliverToBoxAdapter(child: Divider());
      } else if (part is ExploreGridPart) {
        cache.addAll(part.animes);
      } else {
        cache.addAll(part as List<Anime>);
      }
    }
    if (cache.isNotEmpty) {
      yield SliverGridAnimes(animes: (cache));
    }
  }

  @override
  Widget buildContent(BuildContext context, List<Object> data) {
    final scroll = SmoothCustomScrollView(
      controller: widget.controller,
      slivers: [
        if (widget.leadingSliver != null) widget.leadingSliver!,
        ...buildSlivers(context, data),
      ],
    );
    // 结构保持稳定（始终同一 Stack），避免加载指示器出现时重建 scroll
    // 导致滚动位置被重置跳回顶部；加载下一页时才显示底部悬浮转圈
    final showLoader = isLoading && !isFirstLoading;
    // 与 AnimeList 一致：悬浮按钮底距 = 主导航高度 + 15
    final navi = context.findAncestorStateOfType<NaviPaneState>();
    final navInset =
        navi?.bottomBarHeight ?? MediaQuery.paddingOf(context).bottom;
    // 条目总数 + 分区数（单行紧凑小圆片，图二风格）
    var items = 0;
    for (final part in data) {
      if (part is ExplorePagePart) {
        items += part.animes.length;
      } else if (part is ExploreGridPart) {
        items += part.animes.length;
      } else if (part is List<Anime>) {
        items += part.length;
      }
    }
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        scroll,
        if (showLoader)
          Positioned(
            left: 0,
            right: 0,
            bottom: navInset + 15,
            child: IgnorePointer(
              child: SizedBox(
                height: 64,
                child: Center(child: const PolygonRefreshIndicator(size: 44)),
              ),
            ),
          ),
        Positioned(
          right: 62,
          bottom: navInset + 15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.toOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.toOpacity(0.6),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  t.exploreOverlayItemsSections(
                    items: items.toString(),
                    sections: data.length.toString(),
                  ),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Future<Res<List<Object>>> loadData(int page) async {
    var res = await widget.data.loadMixed!(page);
    if (res.error) {
      return res;
    }
    for (var element in res.data) {
      if (element is! ExplorePagePart &&
          element is! List<Anime> &&
          element is! ExploreGridPart) {
        return const Res.error("function loadMixed return invalid data");
      }
    }
    return res;
  }
}

Iterable<Widget> _buildExplorePagePart(
  ExplorePagePart part,
  String sourceKey, {
  bool horizontal = false,
}) sync* {
  Widget buildTitle(ExplorePagePart part) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 5, 10),
          child: Row(
            children: [
              Text(
                part.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (part.viewMore != null)
                TextButton(
                  onPressed: () {
                    var context = App.mainNavigatorKey!.currentContext!;
                    part.viewMore!.jump(context);
                  },
                  child: Text(t.viewMore),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAnimes(ExplorePagePart part) {
    return SliverGridAnimes(animes: part.animes, horizontal: horizontal);
  }

  yield buildTitle(part);
  yield buildAnimes(part);
}

class _MultiPartExplorePage extends StatefulWidget {
  const _MultiPartExplorePage({
    super.key,
    required this.data,
    required this.controller,
    required this.animeSourceKey,
    required this.refreshHandlerCallback,
    this.horizontalLayout = false,
    this.leadingSliver,
  });

  final ExplorePageData data;

  final ScrollController controller;

  final String animeSourceKey;

  final void Function(VoidCallback c) refreshHandlerCallback;

  final bool horizontalLayout;

  final Widget? leadingSliver;

  @override
  State<_MultiPartExplorePage> createState() => _MultiPartExplorePageState();
}

class _MultiPartExplorePageState extends State<_MultiPartExplorePage> {
  late final ExplorePageData data;

  List<ExplorePagePart>? parts;

  bool loading = true;

  String? message;

  Map<String, dynamic> get state => {
    "loading": loading,
    "message": message,
    "parts": parts,
  };

  void restoreState(dynamic state) {
    if (state == null) return;
    loading = state["loading"];
    message = state["message"];
    parts = state["parts"];
  }

  void storeState() {
    PageStorage.of(context).writeState(context, state);
  }

  void refresh() {
    setState(() {
      loading = true;
      message = null;
      parts = null;
    });
    storeState();
  }

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    restoreState(PageStorage.of(context).readState(context));
    widget.refreshHandlerCallback(refresh);
  }

  void load() async {
    var res = await data.loadMultiPart!();
    loading = false;
    if (mounted) {
      setState(() {
        if (res.error) {
          message = res.errorMessage;
        } else {
          parts = res.data;
        }
      });
      storeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      load();
      return const Center(child: KostoriRefreshIndicator());
    } else if (message != null) {
      return NetworkError(
        message: message!,
        retry: () {
          setState(() {
            loading = true;
            message = null;
          });
        },
        withAppbar: false,
      );
    } else {
      return buildPage();
    }
  }

  Widget buildPage() {
    return SmoothCustomScrollView(
      key: const PageStorageKey('scroll'),
      controller: widget.controller,
      slivers: [
        if (widget.leadingSliver != null) widget.leadingSliver!,
        ..._buildPage(),
      ],
    );
  }

  Iterable<Widget> _buildPage() sync* {
    for (var part in parts!) {
      yield* _buildExplorePagePart(
        part,
        widget.animeSourceKey,
        horizontal: widget.horizontalLayout,
      );
    }
  }
}

class _SourceExplorePage extends StatefulWidget {
  const _SourceExplorePage({
    super.key,
    required this.sourceKey,
    required this.pages,
    required this.pageController,
    required this.onFloatingShow,
    required this.onFloatingHide,
    this.horizontalLayout = false,
    this.topInset = 0,
  });

  final String sourceKey;
  final List<String> pages;
  final TabController pageController;
  final VoidCallback onFloatingShow;
  final VoidCallback onFloatingHide;
  final bool horizontalLayout;

  /// 悬浮源导航条的高度：内容顶部让出，滚动时从其下方穿过
  final double topInset;

  @override
  State<_SourceExplorePage> createState() => _SourceExplorePageState();
}

class _SourceExplorePageState extends State<_SourceExplorePage>
    with AutomaticKeepAliveClientMixin<_SourceExplorePage> {
  Widget buildBody(String pageTitle) => Material(
    color: Colors.transparent,
    child: _SingleExplorePage(
      pageTitle,
      key: PageStorageKey("${widget.sourceKey}_$pageTitle"),
      sourceKey: widget.sourceKey,
      onFloatingShow: widget.onFloatingShow,
      onFloatingHide: widget.onFloatingHide,
      horizontalLayout: widget.horizontalLayout,
      topInset: widget.topInset,
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ExtendedTabBarView(
      key: PageStorageKey('tab_view_${widget.sourceKey}'),
      controller: widget.pageController,
      // 桌面端不用滚轮/拖动翻页，避免误切子导航
      physics: tabPagePhysics,
      children: widget.pages.map((e) => buildBody(e)).toList(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// 每源显示模式覆盖的持久化（存 implicitData['animeSourceDisplayModes']）。
class ExploreSourceDisplayMode {
  /// 返回该源（或某子页）的覆盖模式；无覆盖时返回 null（跟随上一级/全局默认）。
  ///
  /// 解析顺序：`子页 > 源级 > 探索设置里的全局默认`，见 [sourceDisplayModeOf]。
  static String? of(String sourceKey, [String? subKey]) =>
      sourceDisplayModeOf(sourceKey, subKey);

  /// 设置覆盖模式；传 null 清除覆盖（恢复全局默认）。
  static void set(String sourceKey, String? mode) =>
      setSourceDisplayMode(sourceKey, mode);
}


