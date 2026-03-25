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
  double location = 0;

  late List<String> sources;
  late Map<String, List<String>> sourcePages;

  void onSettingsChanged() {
    var explorePages = List<String>.from(appdata.settings["explore_pages"]);
    var savedOrder = List<String>.from(
      appdata.settings["explore_sources_order"] ?? [],
    );
    var allSources = AnimeSource.all();
    var newSourcePages = <String, List<String>>{};
    var newSources = <String>[];

    // 按保存的顺序加载
    for (var key in savedOrder) {
      var source = AnimeSource.find(key);
      if (source == null) continue;
      var pagesForSource = source.explorePages
          .map((e) => e.title)
          .where((e) => explorePages.contains(e))
          .toList();
      if (pagesForSource.isNotEmpty) {
        newSources.add(key);
        newSourcePages[key] = pagesForSource;
      }
    }

    // 添加新出现的源
    for (var source in allSources) {
      if (!newSources.contains(source.key)) {
        var pagesForSource = source.explorePages
            .map((e) => e.title)
            .where((e) => explorePages.contains(e))
            .toList();
        if (pagesForSource.isNotEmpty) {
          newSources.add(source.key);
          newSourcePages[source.key] = pagesForSource;
        }
      }
    }

    setState(() {
      sources = newSources;
      sourcePages = newSourcePages;
      _rebuildPageControllers();
      sourceController = TabController(length: sources.length, vsync: this);
    });
  }

  void _rebuildPageControllers() {
    for (var source in sourcePages.keys) {
      var pages = sourcePages[source] ?? [];
      if (!pageControllers.containsKey(source) ||
          pageControllers[source]?.length != pages.length) {
        pageControllers[source]?.dispose();
        pageControllers[source] = TabController(
          length: pages.length,
          vsync: this,
        );
      }
    }
  }

  void onNaviItemTapped(int index) {
    if (index == 4) {
      String currentSource = sources[sourceController.index];
      int pageIndex = pageControllers[currentSource]?.index ?? 0;
      String currentPageId = sourcePages[currentSource]![pageIndex];
      GlobalState.find<_SingleExplorePageState>(currentPageId).toTop();
    }
  }

  void addPage() {
    showPopUpWidget(App.rootContext, setExplorePagesWidget());
  }

  NaviPaneState? naviPane;

  @override
  void initState() {
    exploreController = ExploreController();
    _initSourcesAndPages();
    sourceController = TabController(length: sources.length, vsync: this);
    _rebuildPageControllers();
    appdata.settings.addListener(onSettingsChanged);
    NaviPane.of(context).addNaviItemTapListener(onNaviItemTapped);
    exploreController.initController(this);
    super.initState();
  }

  void _initSourcesAndPages() {
    var explorePages = List<String>.from(appdata.settings["explore_pages"]);
    var savedOrder = List<String>.from(
      appdata.settings["explore_sources_order"] ?? [],
    );
    var allSources = AnimeSource.all();
    sourcePages = {};
    sources = [];

    // 按保存的顺序加载
    for (var key in savedOrder) {
      var source = AnimeSource.find(key);
      if (source == null) continue;
      var pagesForSource = source.explorePages
          .map((e) => e.title)
          .where((e) => explorePages.contains(e))
          .toList();
      if (pagesForSource.isNotEmpty) {
        sources.add(key);
        sourcePages[key] = pagesForSource;
      }
    }

    // 添加新出现的源
    for (var source in allSources) {
      if (!sources.contains(source.key)) {
        var pagesForSource = source.explorePages
            .map((e) => e.title)
            .where((e) => explorePages.contains(e))
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
    sourceController.dispose();
    for (var c in pageControllers.values) {
      c.dispose();
    }
    appdata.settings.removeListener(onSettingsChanged);
    naviPane?.removeNaviItemTapListener(onNaviItemTapped);
    exploreController.dispose();
    super.dispose();
  }

  void refresh() {
    String currentSource = sources[sourceController.index];
    int pageIndex = pageControllers[currentSource]?.index ?? 0;
    String currentPageId = sourcePages[currentSource]![pageIndex];
    GlobalState.find<_SingleExplorePageState>(currentPageId).refresh();
  }

  Tab buildSourceTab(String sourceKey) {
    var source = AnimeSource.find(sourceKey);
    return Tab(text: source?.name ?? sourceKey, key: Key(sourceKey));
  }

  Tab buildPageTab(String title, String sourceKey) {
    return Tab(text: title.ts(sourceKey), key: Key(title));
  }

  Widget buildBody(String i) => Material(
    child: _SingleExplorePage(
      i,
      key: PageStorageKey(i),
      exploreController: exploreController,
    ),
  );

  Widget buildEmpty() {
    var msg = "No Explore Pages".tl;
    msg += '\n';
    VoidCallback onTap;
    if (AnimeSource.isEmpty) {
      msg += "Please add some sources".tl;
      onTap = () {
        context.to(() => AnimeSourceSettings());
      };
    } else {
      msg += "Please check your settings".tl;
      onTap = addPage;
    }
    return NetworkError(
      message: msg,
      retry: onTap,
      withAppbar: false,
      buttonText: "Manage".tl,
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
          text: "Add".tl,
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
                            sourceKey: sourceKey,
                            pages: sourcePages[sourceKey] ?? [],
                            pageController: pageControllers[sourceKey]!,
                            exploreController: exploreController,
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
                            GlobalState.find<_SingleExplorePageState>(
                              currentPageId,
                            ).toTop();
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
    required this.exploreController,
  });

  final String title;

  final ExploreController exploreController;

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
    var explorePages = appdata.settings["explore_pages"];
    if (!explorePages.contains(widget.title)) {
      _wantKeepAlive = false;
      updateKeepAlive();
    }
  }

  void onScroll() {
    if (scrollController.offset > 50) {
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
    for (var source in AnimeSource.all()) {
      for (var d in source.explorePages) {
        if (d.title == widget.title) {
          data = d;
          animeSourceKey = source.key;
          return;
        }
      }
    }
    appdata.settings.addListener(onSettingsChanged);
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
    if (data.loadMultiPart != null) {
      return _MultiPartExplorePage(
        key: const PageStorageKey("anime_list"),
        data: data,
        controller: scrollController,
        animeSourceKey: animeSourceKey,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
      );
    } else if (data.loadPage != null || data.loadNext != null) {
      return AnimeList(
        enablePageStorage: true,
        loadPage: data.loadPage,
        loadNext: data.loadNext,
        key: const PageStorageKey("anime_list"),
        controller: scrollController,
        refreshHandlerCallback: (c) {
          refreshHandler = c;
        },
      );
    } else if (data.loadMixed != null) {
      return AppScrollBar(
        // topPadding: 10,
        controller: scrollController,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: _MixedExplorePage(
            data,
            animeSourceKey,
            key: const PageStorageKey("anime_list"),
            controller: scrollController,
            refreshHandlerCallback: (c) {
              refreshHandler = c;
            },
          ),
        ),
      );
    } else {
      return const Center(child: Text("Empty Page"));
    }
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
  });

  final ExplorePageData data;

  final String sourceKey;

  final ScrollController? controller;

  final void Function(VoidCallback c) refreshHandlerCallback;

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
    return SmoothCustomScrollView(
      controller: widget.controller,
      slivers: [
        ...buildSlivers(context, data),
        const SliverListLoadingIndicator(),
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
  String sourceKey,
) sync* {
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
                  child: Text("View more".tl),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAnimes(ExplorePagePart part) {
    return SliverGridAnimes(animes: part.animes);
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
  });

  final ExplorePageData data;

  final ScrollController controller;

  final String animeSourceKey;

  final void Function(VoidCallback c) refreshHandlerCallback;

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
      slivers: _buildPage().toList(),
    );
  }

  Iterable<Widget> _buildPage() sync* {
    for (var part in parts!) {
      yield* _buildExplorePagePart(part, widget.animeSourceKey);
    }
  }
}

class _SourceExplorePage extends StatefulWidget {
  const _SourceExplorePage({
    required this.sourceKey,
    required this.pages,
    required this.pageController,
    required this.exploreController,
  });

  final String sourceKey;
  final List<String> pages;
  final TabController pageController;
  final ExploreController exploreController;

  @override
  State<_SourceExplorePage> createState() => _SourceExplorePageState();
}

class _SourceExplorePageState extends State<_SourceExplorePage>
    with AutomaticKeepAliveClientMixin<_SourceExplorePage> {
  Tab buildPageTab(String title) {
    return Tab(text: title.ts(widget.sourceKey), key: Key(title));
  }

  Widget buildBody(String pageTitle) => Material(
    child: _SingleExplorePage(
      pageTitle,
      key: PageStorageKey("${widget.sourceKey}_$pageTitle"),
      exploreController: widget.exploreController,
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
