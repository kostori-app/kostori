// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/global_state.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/pages/settings/anime_source_settings.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin<ExplorePage> {
  late TabController controller;

  bool showFB = true;

  double location = 0;

  late List<String> pages;

  void onSettingsChanged() {
    var explorePages = List<String>.from(appdata.settings["explore_pages"]);
    var all = AnimeSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();
    explorePages = explorePages.where((e) => all.contains(e)).toList();
    if (!pages.isEqualTo(explorePages)) {
      setState(() {
        pages = explorePages;
        controller = TabController(length: pages.length, vsync: this);
      });
    }
  }

  void onNaviItemTapped(int index) {
    if (index == 4) {
      int page = controller.index;
      String currentPageId = pages[page];
      GlobalState.find<_SingleExplorePageState>(currentPageId).toTop();
    }
  }

  void addPage() {
    showPopUpWidget(App.rootContext, setExplorePagesWidget());
  }

  NaviPaneState? naviPane;

  @override
  void initState() {
    pages = List<String>.from(appdata.settings["explore_pages"]);
    var all = AnimeSource.all()
        .map((e) => e.explorePages)
        .expand((e) => e.map((e) => e.title))
        .toList();
    pages = pages.where((e) => all.contains(e)).toList();
    controller = TabController(length: pages.length, vsync: this);
    appdata.settings.addListener(onSettingsChanged);
    NaviPane.of(context).addNaviItemTapListener(onNaviItemTapped);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    naviPane = NaviPane.of(context);
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    controller.dispose();
    appdata.settings.removeListener(onSettingsChanged);
    naviPane?.removeNaviItemTapListener(onNaviItemTapped);
    super.dispose();
  }

  void refresh() {
    int page = controller.index;
    String currentPageId = pages[page];
    GlobalState.find<_SingleExplorePageState>(currentPageId).refresh();
  }

  Widget buildFAB() => Material(
    color: Colors.transparent,
    child: FloatingActionButton(
      key: const Key("FAB"),
      onPressed: refresh,
      child: const Icon(Icons.refresh),
    ),
  );

  Tab buildTab(String i) {
    var animeSource = AnimeSource.all().firstWhere(
      (e) => e.explorePages.any((e) => e.title == i),
    );
    return Tab(text: i.ts(animeSource.key), key: Key(i));
  }

  Widget buildBody(String i) =>
      Material(child: _SingleExplorePage(i, key: PageStorageKey(i)));

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
    if (pages.isEmpty) {
      return buildEmpty();
    }

    Widget tabBar = Material(
      child: AppTabBar(
        key: PageStorageKey(pages.toString()),
        tabs: pages.map((e) => buildTab(e)).toList(),
        controller: controller,
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
              tabBar,
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notifications) {
                    // if (notifications.metrics.axis == Axis.horizontal) {
                    //   if (!showFB) {
                    //     setState(() {
                    //       showFB = true;
                    //     });
                    //   }
                    //   return true;
                    // }

                    var current = notifications.metrics.pixels;
                    var overflow = notifications.metrics.outOfRange;
                    // if (current > location && current != 0 && showFB) {
                    //   setState(() {
                    //     showFB = false;
                    //   });
                    // } else if ((current < location - 50 || current == 0) &&
                    //     !showFB) {
                    //   setState(() {
                    //     showFB = true;
                    //   });
                    // }
                    if ((current > location || current < location - 50) &&
                        !overflow) {
                      location = current;
                    }
                    return false;
                  },
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: TabBarView(
                      controller: controller,
                      children: pages.map((e) => buildBody(e)).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Positioned(
        //   right: 16,
        //   bottom: 16,
        //   child: AnimatedSwitcher(
        //     duration: const Duration(milliseconds: 150),
        //     reverseDuration: const Duration(milliseconds: 150),
        //     child: showFB ? buildFAB() : const SizedBox(),
        //     transitionBuilder: (widget, animation) {
        //       var tween = Tween<Offset>(
        //           begin: const Offset(0, 1), end: const Offset(0, 0));
        //       return SlideTransition(
        //         position: tween.animate(animation),
        //         child: widget,
        //       );
        //     },
        //   ),
        // )
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SingleExplorePage extends StatefulWidget {
  const _SingleExplorePage(this.title, {super.key});

  final String title;

  @override
  State<_SingleExplorePage> createState() => _SingleExplorePageState();
}

class _SingleExplorePageState extends AutomaticGlobalState<_SingleExplorePage>
    with AutomaticKeepAliveClientMixin<_SingleExplorePage> {
  late final ExplorePageData data;

  late final String animeSourceKey;

  bool _wantKeepAlive = true;

  var scrollController = ScrollController();

  VoidCallback? refreshHandler;

  void onSettingsChanged() {
    var explorePages = appdata.settings["explore_pages"];
    if (!explorePages.contains(widget.title)) {
      _wantKeepAlive = false;
      updateKeepAlive();
    }
  }

  @override
  void initState() {
    super.initState();
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
      if (element is! ExplorePagePart && element is! List<Anime>) {
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
      return const Center(child: CircularProgressIndicator());
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
