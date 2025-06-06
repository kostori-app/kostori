import 'package:flutter/material.dart';
import 'package:kostori/utils/translations.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../components/bean/card/topics_card.dart';
import '../../components/error_widget.dart';
import '../../components/misc_components.dart';
import 'info_controller.dart';

class BangumiSubjectTabPage extends StatefulWidget {
  const BangumiSubjectTabPage({super.key});

  @override
  State<BangumiSubjectTabPage> createState() => _BangumiSubjectTabPageState();
}

class _BangumiSubjectTabPageState extends State<BangumiSubjectTabPage>
    with TickerProviderStateMixin {
  final InfoController infoController = InfoController();
  late TabController infoTabController;

  bool topicsLatestIsLoading = false;
  bool topicsTrendingIsLoading = false;
  bool topicsLatestQueryTimeout = false;
  bool topicsTrendingQueryTimeout = false;

  double _previousPixels = 0;

  Future<void> loadMoreTopicsLatest({int offset = 0}) async {
    if (topicsLatestIsLoading) return;
    setState(() {
      topicsLatestIsLoading = true;
      topicsLatestQueryTimeout = false;
    });
    infoController.queryBangumiTopicsLatestByID(offset: offset).then((_) {
      if (infoController.topicsLatestList.isEmpty && mounted) {
        setState(() {
          topicsLatestIsLoading = false;
          topicsLatestQueryTimeout = true;
        });
      }
      if (infoController.topicsLatestList.isNotEmpty && mounted) {
        setState(() {
          topicsLatestIsLoading = false;
        });
      }
    });
  }

  Future<void> loadMoreTopicsTrending({int offset = 0}) async {
    if (topicsTrendingIsLoading) return;
    setState(() {
      topicsTrendingIsLoading = true;
      topicsTrendingQueryTimeout = false;
    });
    infoController.queryBangumiTopicsTrendingByID(offset: offset).then((_) {
      if (infoController.topicsTrendingList.isEmpty && mounted) {
        setState(() {
          topicsTrendingIsLoading = false;
          topicsTrendingQueryTimeout = true;
        });
      }
      if (infoController.topicsTrendingList.isNotEmpty && mounted) {
        setState(() {
          topicsTrendingIsLoading = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    infoController.topicsLatestList.clear();
    infoController.topicsTrendingList.clear();
    infoTabController = TabController(length: 2, vsync: this);
    infoTabController.addListener(() {
      int index = infoTabController.index;
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
    if (infoTabController.index == 0 &&
        infoController.topicsLatestList.isEmpty &&
        !topicsLatestIsLoading) {
      loadMoreTopicsLatest();
    }
  }

  @override
  void dispose() {
    infoController.topicsLatestList.clear();
    infoController.topicsTrendingList.clear();
    infoTabController.dispose();
    super.dispose();
  }

  Widget get topicsLatestListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            final isScrollingDown = metrics.pixels > _previousPixels;
            _previousPixels = metrics.pixels;

            if (isScrollingDown &&
                metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMoreTopicsLatest(
                  offset: infoController.topicsLatestList.length);
            }
            return true;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('最新讨论'),
            slivers: <Widget>[
              SliverLayoutBuilder(builder: (context, _) {
                if (infoController.topicsLatestList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: infoController.topicsLatestList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > 950
                                ? 950
                                : MediaQuery.sizeOf(context).width - 32,
                            child: TopicsCard(
                                topicsInfoItem:
                                    infoController.topicsLatestList[index]),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (topicsLatestQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '好像没人发呢...',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadMoreTopicsLatest();
                          },
                          text: '重新加载',
                        ),
                      ],
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > 950
                            ? 950
                            : MediaQuery.sizeOf(context).width - 32,
                        child: Skeletonizer.zone(
                          child: ListTile(
                            leading: Bone.circle(size: 36),
                            title: Bone.text(width: 100),
                            subtitle: Bone.text(width: 80),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              if (topicsLatestIsLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: MiscComponents.placeholder(
                          context, 40, 40, Colors.transparent),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget get topicsTrendingListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            final isScrollingDown = metrics.pixels > _previousPixels;
            _previousPixels = metrics.pixels;

            if (isScrollingDown &&
                metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMoreTopicsTrending(
                  offset: infoController.topicsTrendingList.length);
            }
            return true;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('热门讨论'),
            slivers: <Widget>[
              SliverLayoutBuilder(builder: (context, _) {
                if (infoController.topicsTrendingList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: infoController.topicsTrendingList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > 950
                                ? 950
                                : MediaQuery.sizeOf(context).width - 32,
                            child: TopicsCard(
                                topicsInfoItem:
                                    infoController.topicsTrendingList[index]),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (topicsTrendingQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '好像没人发呢...',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadMoreTopicsLatest();
                          },
                          text: '重新加载',
                        ),
                      ],
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > 950
                            ? 950
                            : MediaQuery.sizeOf(context).width - 32,
                        child: Skeletonizer.zone(
                          child: ListTile(
                            leading: Bone.circle(size: 36),
                            title: Bone.text(width: 100),
                            subtitle: Bone.text(width: 80),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              if (topicsTrendingIsLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: MiscComponents.placeholder(
                          context, 40, 40, Colors.transparent),
                    ),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('热点'.tl),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 300), // 你想要的最大宽度
                    child: TabBar(
                      controller: infoTabController,
                      isScrollable: true,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                      tabs: [
                        Tab(text: 'TopicsLatest'.tl),
                        Tab(text: 'TopicsTrending'.tl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: infoTabController,
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      await loadMoreTopicsLatest();
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: true,
                          child: topicsLatestListBody,
                        ),
                      ],
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      await loadMoreTopicsTrending();
                    },
                    child: CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          hasScrollBody: true,
                          child: topicsTrendingListBody,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
