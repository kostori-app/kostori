import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/topics_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/empty_state.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/i18n/strings.g.dart';

class BangumiSubjectTabPage extends ConsumerStatefulWidget {
  const BangumiSubjectTabPage({super.key});

  @override
  ConsumerState<BangumiSubjectTabPage> createState() =>
      _BangumiSubjectTabPageState();
}

class _BangumiSubjectTabPageState extends ConsumerState<BangumiSubjectTabPage>
    with TickerProviderStateMixin {
  final ScrollController scrollControllerLatest = ScrollController();
  final ScrollController scrollControllerTrending = ScrollController();

  ScrollController get activeScrollController => infoTabController.index == 0
      ? scrollControllerLatest
      : scrollControllerTrending;

  InfoController get infoController =>
      ref.read(infoControllerProvider.notifier);
  late TabController infoTabController;

  bool topicsLatestIsLoading = false;
  bool topicsTrendingIsLoading = false;
  bool topicsLatestQueryTimeout = false;
  bool topicsTrendingQueryTimeout = false;

  double _previousPixels = 0;

  static const double maxWidth = 950;

  Future<void> loadMoreTopicsLatest({int offset = 0}) async {
    if (topicsLatestIsLoading) return;
    setState(() {
      topicsLatestIsLoading = true;
      topicsLatestQueryTimeout = false;
    });
    infoController.queryBangumiTopicsLatestByID(offset: offset).then((_) {
      if (!mounted) return;
      setState(() {
        topicsLatestIsLoading = false;
        if (infoController.topicsLatestList.isEmpty) {
          topicsLatestQueryTimeout = true;
        }
      });
    });
  }

  Future<void> loadMoreTopicsTrending({int offset = 0}) async {
    if (topicsTrendingIsLoading) return;
    setState(() {
      topicsTrendingIsLoading = true;
      topicsTrendingQueryTimeout = false;
    });
    infoController.queryBangumiTopicsTrendingByID(offset: offset).then((_) {
      if (!mounted) return;
      setState(() {
        topicsTrendingIsLoading = false;
        if (infoController.topicsTrendingList.isEmpty) {
          topicsTrendingQueryTimeout = true;
        }
      });
    });
  }

  Future<void> resetBangumiTrend() async {
    if (infoTabController.index == 0) {
      setState(() => topicsLatestQueryTimeout = false);
      await loadMoreTopicsLatest();
    } else {
      setState(() => topicsTrendingQueryTimeout = false);
      await loadMoreTopicsTrending();
    }
  }

  void scrollToTop() {
    if (activeScrollController.hasClients) {
      activeScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    infoTabController = TabController(length: 2, vsync: this);
    infoTabController.addListener(() {
      setState(() {});
      final index = infoTabController.index;
      if (index == 0 &&
          infoController.topicsLatestList.isEmpty &&
          !topicsLatestIsLoading) {
        loadMoreTopicsLatest();
      }
      if (index == 1 &&
          infoController.topicsTrendingList.isEmpty &&
          !topicsTrendingIsLoading) {
        loadMoreTopicsTrending();
      }
    });
    if (infoController.topicsLatestList.isEmpty && !topicsLatestIsLoading) {
      loadMoreTopicsLatest();
    }
  }

  @override
  void dispose() {
    infoTabController.dispose();
    scrollControllerLatest.dispose();
    scrollControllerTrending.dispose();
    super.dispose();
  }

  Widget _buildTopicsBody({
    required List topicsList,
    required ScrollController scrollController,
    required bool isLoading,
    required bool queryTimeout,
    required VoidCallback onReload,
    required Future<void> Function({int offset}) loadMore,
    required String storageKey,
  }) {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            final isScrollingDown = metrics.pixels > _previousPixels;
            _previousPixels = metrics.pixels;
            if (isScrollingDown &&
                metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMore(offset: topicsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            controller: scrollController,
            key: PageStorageKey<String>(storageKey),
            slivers: <Widget>[
              SliverLayoutBuilder(
                builder: (context, _) {
                  if (topicsList.isNotEmpty) {
                    return SliverList.builder(
                      itemCount: topicsList.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: TopicsCard(
                                topicsInfoItem: topicsList[index],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  if (queryTimeout) {
                    return SliverFillRemaining(
        child: EmptyState(
          message: t.nobodysPostedAnythingYet,
          retry: onReload,
          retryText: t.reload,
        ),
                    );
                  }
                  return SliverList.builder(
                    itemCount: 4,
                    itemBuilder: (context, _) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: TopicsCard.bone(),
                        ),
                      );
                    },
                  );
                },
              ),
              if (isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: PolygonRefreshIndicator(size: 40)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: Appbar(
          title: Text(t.hotspot),
          bottom: TabBar(
            controller: infoTabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: t.topicsLatest),
              Tab(text: t.topicsTrending),
            ],
          ),
        ),
        body: TabBarView(
          controller: infoTabController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            KeepAliveWrapper(
              child: _buildTopicsBody(
                topicsList: infoController.topicsLatestList,
                scrollController: scrollControllerLatest,
                isLoading: topicsLatestIsLoading,
                queryTimeout: topicsLatestQueryTimeout,
                onReload: () => loadMoreTopicsLatest(),
                loadMore: loadMoreTopicsLatest,
                storageKey: '最新讨论',
              ),
            ),
            KeepAliveWrapper(
              child: _buildTopicsBody(
                topicsList: infoController.topicsTrendingList,
                scrollController: scrollControllerTrending,
                isLoading: topicsTrendingIsLoading,
                queryTimeout: topicsTrendingQueryTimeout,
                onReload: () => loadMoreTopicsTrending(),
                loadMore: loadMoreTopicsTrending,
                storageKey: '热门讨论',
              ),
            ),
          ],
        ),
      ),
    );

    widget = Stack(
      children: [
        Positioned.fill(child: widget),
        Positioned(
          bottom: 15,
          right: 10,
          child: AnimatedBuilder(
            animation: infoTabController,
            builder: (context, _) {
              return FloatingMenu(
                key: ValueKey(infoTabController.index),
                controller: activeScrollController,
                child: [
                  [
                    SpeedDialChild(
                      child: const Icon(Icons.refresh),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      onTap: () async => await resetBangumiTrend(),
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
                      onTap: () => scrollToTop(),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );

    widget = AppScrollBar(
      key: ValueKey(infoTabController.index),
      topPadding: 82 + context.padding.top,
      controller: activeScrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );

    return widget;
  }
}
