// ignore_for_file: file_names

import 'package:extended_tabs/extended_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
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
import 'package:kostori/pages/explore_controller.dart';
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

  late final ExploreController exploreController;

  bool get showFB => exploreController.showFB;

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
      old.dispose();
      if (prevSourceKey != null) {
        final idx = sources.indexOf(prevSourceKey);
        if (idx != -1) sourceController.index = idx;
      }
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
        currentPageId,
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
    exploreController = ExploreController();
    _initSourcesAndPages();
    sourceController = TabController(length: sources.length, vsync: this);
    _rebuildPageControllers();
    appdata.settings.addListener(onSettingsChanged);
    NaviPane.of(context).addNaviItemTapListener(onNaviItemTapped);
    exploreController.initController(this);
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
    sourceController.dispose();
    for (var c in pageControllers.values) {
      c.dispose();
    }
    appdata.settings.removeListener(onSettingsChanged);
    naviPane?.removeNaviItemTapListener(onNaviItemTapped);
    exploreController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appdata.implicitData['explorePageIndices'] = savedIndices;
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

  void refresh() {
    String currentSource = sources[sourceController.index];
    int pageIndex = pageControllers[currentSource]?.index ?? 0;
    String currentPageId = sourcePages[currentSource]![pageIndex];
    GlobalState.findOrNull<_SingleExplorePageState>(currentPageId)?.refresh();
  }

  Tab buildSourceTab(String sourceKey) {
    var source = AnimeSource.find(sourceKey);
    return Tab(text: source?.name ?? sourceKey, key: Key(sourceKey));
  }

  Tab buildPageTab(String title, String sourceKey) {
    return Tab(text: title.ts(sourceKey), key: Key("${sourceKey}_$title"));
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

    Widget sourceTabBar = Material(
      child: AppTabBar(
        key: PageStorageKey(sources.toString()),
        tabs: sources.map((e) => buildSourceTab(e)).toList(),
        controller: sourceController,
        actionButton: TabActionButton(
          icon: const Icon(Icons.add),
          text: t.add,
          onPressed: addPage,
        ),
      ),
    ).paddingTop(context.padding.top);

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              sourceTabBar,
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: ExtendedTabBarView(
                    controller: sourceController,
                    children: sources
                        .map(
                          (sourceKey) => _SourceExplorePage(
                            key: ValueKey(sourceKey),
                            sourceKey: sourceKey,
                            pages: sourcePages[sourceKey] ?? [],
                            pageController: pageControllers[sourceKey]!,
                            exploreController: exploreController,
                            horizontalLayout: horizontalLayout,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Observer(
          builder: (_) => Positioned(
            bottom: 30,
            right: 10,
            child: FadeTransition(
              opacity: exploreController.fadeAnimation,
              child: IgnorePointer(
                ignoring: !showFB,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20, right: 0),
                  child: GridSpeedDial(
                    icon: Icons.menu,
                    activeIcon: Icons.close,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    spacing: 6,
                    spaceBetweenChildren: 4,
                    direction: SpeedDialDirection.up,
                    childPadding: const EdgeInsets.all(6),
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
                              currentPageId,
                            )?.toTop();
                          },
                        ),
                      ],
                      [
                        SpeedDialChild(
                          child:
                              appdata.settings['animeListDisplayMode'] ==
                                  'paging'
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
                            refresh;
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
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(
    this.title, {
    super.key,
    required this.sourceKey,
    required this.exploreController,
    this.horizontalLayout = false,
  });

  final String title;
  final String sourceKey;
  final ExploreController exploreController;

  final bool horizontalLayout;

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends AutomaticGlobalState<_SingleExplorePage>
    with AutomaticKeepAliveClientMixin<_SingleExplorePage> {
  late final ExplorePageData data;

  late final String animeSourceKey;

  late final ExploreController exploreController;

  var scrollController = ScrollController();

  bool _wantKeepAlive = true;

  VoidCallback? refreshHandler;

  bool get showFB => exploreController.showFB;

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
      if (!exploreController.showFB) {
        exploreController.show();
      }
    } else {
      if (exploreController.showFB) {
        exploreController.hide();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    exploreController = widget.exploreController;
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
    // 每源布局覆盖（null = 用探索设置里的全局默认）
    final sourceMode = ExploreSourceDisplayMode.of(animeSourceKey);
    final modeBar = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Center(child: _SourceDisplayModeBar(sourceKey: animeSourceKey)),
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
    return AnimeDisplayModeScope(mode: sourceMode, child: child);
  }

  @override
  Object? get key => widget.title;

  @override
  void refresh() {
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
    // 加载下一页时在视口底部悬浮转圈（不占内容流，避免触发时被截半；
    // 加载完成/无更多页时自动消失）
    final showLoader = isLoading && !isFirstLoading;
    if (!showLoader) return scroll;
    return Stack(
      children: [
        scroll,
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: IgnorePointer(
            child: SizedBox(
              height: 64,
              child: Center(child: const PolygonRefreshIndicator(size: 44)),
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
    required this.exploreController,
    this.horizontalLayout = false,
  });

  final String sourceKey;
  final List<String> pages;
  final TabController pageController;
  final ExploreController exploreController;
  final bool horizontalLayout;

  @override
  State<_SourceExplorePage> createState() => _SourceExplorePageState();
}

class _SourceExplorePageState extends State<_SourceExplorePage>
    with AutomaticKeepAliveClientMixin<_SourceExplorePage> {
  Tab buildPageTab(String title) {
    return Tab(
      text: title.ts(widget.sourceKey),
      key: Key("${widget.sourceKey}_$title"),
    );
  }

  Widget buildBody(String pageTitle) => Material(
    child: _SingleExplorePage(
      pageTitle,
      key: PageStorageKey("${widget.sourceKey}_$pageTitle"),
      sourceKey: widget.sourceKey,
      exploreController: widget.exploreController,
      horizontalLayout: widget.horizontalLayout,
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Material(
          child: TabBar(
            tabs: widget.pages.map((e) => buildPageTab(e)).toList(),
            controller: widget.pageController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            dividerColor: Colors.transparent,
          ),
        ),
        Expanded(
          child: ExtendedTabBarView(
            key: PageStorageKey('tab_view_${widget.sourceKey}'),
            controller: widget.pageController,
            children: widget.pages.map((e) => buildBody(e)).toList(),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// 每源显示模式覆盖的持久化（存 implicitData['animeSourceDisplayModes']）。
class ExploreSourceDisplayMode {
  /// 返回该源的覆盖模式；无覆盖时返回 null（跟随探索设置里的全局默认）。
  static String? of(String sourceKey) => sourceDisplayModeOf(sourceKey);

  /// 设置覆盖模式；传 null 清除覆盖（恢复全局默认）。
  static void set(String sourceKey, String? mode) =>
      setSourceDisplayMode(sourceKey, mode);
}

/// 探索页每源布局切换条：简洁 / 详细 / 瀑布流。
/// 已自定义该源时显示覆盖模式并附「跟随全局」重置按钮；
/// 未自定义时高亮全局默认模式。
class _SourceDisplayModeBar extends StatelessWidget {
  const _SourceDisplayModeBar({required this.sourceKey});

  final String sourceKey;

  @override
  Widget build(BuildContext context) {
    final override = ExploreSourceDisplayMode.of(sourceKey);
    final value = override ?? appdata.settings['animeDisplayMode'];
    final colorScheme = Theme.of(context).colorScheme;
    final modes = [
      ('brief', t.brief),
      ('detailed', t.detailed),
      ('masonry', t.masonry),
      ('poster', t.poster),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.toOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: modes.map((mode) {
              final (key, label) = mode;
              final selected = value == key;
              return GestureDetector(
                onTap: () => ExploreSourceDisplayMode.set(sourceKey, key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? colorScheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: Colors.black.toOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.toOpacity(0.45),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (override != null) ...[
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            tooltip: t.sourceDisplayModeReset,
            icon: Icon(Icons.restore, color: colorScheme.outline),
            onPressed: () => ExploreSourceDisplayMode.set(sourceKey, null),
          ),
        ],
      ],
    );
  }
}
