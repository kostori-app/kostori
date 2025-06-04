import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/components/bean/card/comments_card.dart';
import 'package:kostori/components/bean/card/staff_card.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:kostori/components/bean/card/character_card.dart';
import 'package:kostori/components/bean/card/episode_comments_sheet.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/components/error_widget.dart';

import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';

import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart'
    show BangumiSearchPage;

import '../../components/bean/card/reviews_card.dart';
import '../../components/bean/card/topics_card.dart';
import '../../foundation/bangumi/topics/topics_item.dart';

class _StatItem {
  final String key;
  final String label;
  final Color? color;

  _StatItem(this.key, this.label, this.color);
}

class BottomInfo extends StatefulWidget {
  const BottomInfo({
    super.key,
    required this.bangumiId,
    required this.infoController,
  });

  final int? bangumiId;
  final InfoController infoController;

  @override
  State<BottomInfo> createState() => BottomInfoState();
}

class BottomInfoState extends State<BottomInfo>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static BottomInfoState? currentState;
  late TabController infoTabController;
  late InfoController infoController;
  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  bool commentsIsLoading = false;
  bool topicsIsLoading = false;
  bool reviewsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool topicsQueryTimeout = false;
  bool reviewsQueryTimeout = false;
  bool charactersQueryTimeout = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;

  double _previousPixels = 0;

  final maxWidth = 950.0;
  bool fullIntro = false;
  bool fullTag = false;

  int? get bangumiId => widget.bangumiId;

  List<TopicsItem> get topicsList => widget.infoController.topicsList;

  List<ReviewsItem> get reviewsList => widget.infoController.reviewsList;

  @override
  void initState() {
    super.initState();
    currentState = this;
    infoController = widget.infoController;
    infoController.bangumiId = widget.bangumiId!;
    infoController.allEpisodes = [];
    queryBangumiInfoByID(infoController.bangumiId);
    queryBangumiEpisodeByID(infoController.bangumiId);
    infoController.characterList.clear();
    infoController.commentsList.clear();
    infoController.staffList.clear();
    infoController.episodeCommentsList.clear();
    infoTabController =
        TabController(length: infoController.tabs.length + 1, vsync: this);
    infoTabController.addListener(() {
      int index = infoTabController.index;
      if (index == 1 &&
          infoController.commentsList.isEmpty &&
          !commentsIsLoading) {
        loadMoreComments();
      }
      if (index == 3 && infoController.topicsList.isEmpty && !topicsIsLoading) {
        loadMoreTopics();
      }
      if (index == 4 &&
          infoController.reviewsList.isEmpty &&
          !reviewsIsLoading) {
        loadMoreReviews();
      }
      if (index == 5 &&
          infoController.characterList.isEmpty &&
          !charactersIsLoading) {
        loadCharacters();
      }
      if (index == 6 && infoController.staffList.isEmpty && !staffIsLoading) {
        loadStaff();
      }
    });
  }

  @override
  void dispose() {
    infoController.characterList.clear();
    infoController.commentsList.clear();
    infoController.staffList.clear();
    infoController.episodeCommentsList.clear();
    infoTabController.dispose();
    super.dispose();
  }

  void updata() {
    setState(() {});
  }

  Future<void> queryBangumiInfoByID(int id) async {
    try {
      await infoController.queryBangumiInfoByID(id);
      setState(() {});
    } catch (e) {
      Log.addLog(LogLevel.error, 'queryBangumiInfoByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeByID(int id) async {
    try {
      await infoController.queryBangumiEpisodeByID(id);
      setState(() {});
    } catch (e) {
      Log.addLog(LogLevel.error, 'queryBangumiEpisodeByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode,
      {int offset = 0}) async {
    await infoController.queryBangumiEpisodeCommentsByID(id, episode,
        offset: offset);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> loadCharacters() async {
    if (charactersIsLoading) return;
    setState(() {
      charactersIsLoading = true;
      charactersQueryTimeout = false;
    });
    infoController
        .queryBangumiCharactersByID(infoController.bangumiId)
        .then((_) {
      if (infoController.characterList.isEmpty && mounted) {
        setState(() {
          charactersIsLoading = false;
          charactersQueryTimeout = true;
        });
      }
      if (infoController.characterList.isNotEmpty && mounted) {
        setState(() {
          charactersIsLoading = false;
        });
      }
    });
  }

  Future<void> loadMoreComments({int offset = 0}) async {
    if (commentsIsLoading) return;
    setState(() {
      commentsIsLoading = true;
      commentsQueryTimeout = false;
    });
    infoController
        .queryBangumiCommentsByID(infoController.bangumiId, offset: offset)
        .then((_) {
      if (infoController.commentsList.isEmpty && mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsQueryTimeout = true;
        });
      }
      if (infoController.commentsList.isNotEmpty && mounted) {
        setState(() {
          commentsIsLoading = false;
        });
      }
    });
  }

  Future<void> loadMoreTopics({int offset = 0}) async {
    if (topicsIsLoading) return;
    setState(() {
      topicsIsLoading = true;
      topicsQueryTimeout = false;
    });
    infoController
        .queryBangumiTopicsByID(infoController.bangumiItem.id, offset: offset)
        .then((_) {
      if (infoController.topicsList.isEmpty && mounted) {
        setState(() {
          topicsIsLoading = false;
          topicsQueryTimeout = true;
        });
      }
      if (infoController.topicsList.isNotEmpty && mounted) {
        setState(() {
          topicsIsLoading = false;
        });
      }
    });
  }

  Future<void> loadMoreReviews({int offset = 0}) async {
    if (reviewsIsLoading) return;
    setState(() {
      reviewsIsLoading = true;
      reviewsQueryTimeout = false;
    });
    infoController
        .queryBangumiReviewsByID(infoController.bangumiItem.id, offset: offset)
        .then((_) {
      if (infoController.reviewsList.isEmpty && mounted) {
        setState(() {
          reviewsIsLoading = false;
          reviewsQueryTimeout = true;
        });
      }
      if (infoController.reviewsList.isNotEmpty && mounted) {
        setState(() {
          reviewsIsLoading = false;
        });
      }
    });
  }

  Future<void> loadComments(int episode, {int offset = 0}) async {
    commentsQueryTimeout = false;
    await queryBangumiEpisodeCommentsByID(infoController.bangumiId, episode,
            offset: offset)
        .then((_) {
      if (infoController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    });
  }

  Future<void> loadStaff() async {
    if (staffIsLoading) return;
    setState(() {
      staffIsLoading = true;
      staffQueryTimeout = false;
    });
    infoController.queryBangumiStaffsByID(infoController.bangumiId).then((_) {
      if (infoController.staffList.isEmpty && mounted) {
        setState(() {
          staffIsLoading = false;
          staffQueryTimeout = true;
        });
      }
      if (infoController.staffList.isNotEmpty && mounted) {
        setState(() {
          staffIsLoading = false;
        });
      }
    });
  }

  Widget _buildStatsRow(BuildContext context) {
    final collection = infoController.bangumiItem.collection!; // 提前解构，避免重复访问
    final total =
        collection.values.fold<int>(0, (sum, val) => sum + (val)); // 计算总数

    // 定义统计数据项（类型 + 显示文本 + 颜色）
    final stats = [
      _StatItem('doing', '在看', Theme.of(context).colorScheme.primary),
      _StatItem('collect', '看过', Theme.of(context).colorScheme.error),
      _StatItem('wish', '想看', Colors.blueAccent),
      _StatItem('on_hold', '搁置', null), // 默认文本颜色
      _StatItem('dropped', '抛弃', Colors.grey),
    ];

    return Row(
      children: [
        ...stats.expand((stat) => [
              Text('${collection[stat.key]} ${stat.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: stat.color,
                  )),
              const Text(' / '),
            ]),
        Text('$total 总计数', style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget get infoBodyBone {
    return LayoutBuilder(builder: (context, constraints) {
      double height = constraints.maxHeight;
      double width = constraints.maxWidth;
      return MiscComponents.placeholder(context, width, height);
    });
  }

  Widget get infoBody {
    if (bangumiId == null) {
      return Center(child: infoBodyBone);
    }

    var bangumiItem = infoController.bangumiItem;
    var allEpisodes = infoController.allEpisodes;

    // 获取当前周的剧集
    final currentWeekEp =
        Utils.findCurrentWeekEpisode(allEpisodes, bangumiItem);

    final type0Episodes = allEpisodes.where((ep) => ep.type == 0).toList();

    final isCompleted = currentWeekEp != null &&
        type0Episodes.isNotEmpty &&
        currentWeekEp == type0Episodes.last;

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  double height =
                      constraints.maxWidth * (App.isDesktop ? 9 / 16 : 9 / 16);
                  double width = height * 0.72;

                  return Container(
                    width: constraints.maxWidth,
                    height: height,
                    padding: EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BangumiWidget.kostoriImage(
                              context, bangumiItem.images['large']!,
                              width: width, height: height),
                        ),
                        // SizedBox(width: 12.0),
                        Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bangumiItem.nameCn,
                                style: TextStyle(
                                    fontSize: width * 1 / 10,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(bangumiItem.name,
                                  style: TextStyle(
                                    fontSize: width * 1 / 24,
                                  )),
                              SizedBox(height: 12.0),
                              Container(
                                padding: EdgeInsets.all(8.0),
                                // 可选，设置内边距
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(16.0), // 设置圆角半径
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                        .toOpacity(0.72),
                                    width: 2.0, // 设置边框宽度
                                  ),
                                ),
                                child: Text(
                                  bangumiItem.airDate,
                                ),
                              ),
                              SizedBox(height: 12.0),
                              Text(
                                isCompleted
                                    ? '全 ${bangumiItem.totalEpisodes} 话'
                                    : '连载至 ${currentWeekEp?.sort} • 预定全 ${bangumiItem.totalEpisodes} 话',
                                style: TextStyle(fontSize: 14.0),
                              ),
                              Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${bangumiItem.score}',
                                      style: TextStyle(
                                        fontSize: 32.0,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 5,
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(2.0),
                                      // 可选，设置内边距
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(8), // 设置圆角半径
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer
                                              .toOpacity(0.72),
                                          width: 2.0, // 设置边框宽度
                                        ),
                                      ),
                                      child: Text(
                                        Utils.getRatingLabel(bangumiItem.score),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 4,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end, // 右对齐
                                      children: [
                                        RatingBarIndicator(
                                          itemCount: 5,
                                          rating:
                                              bangumiItem.score.toDouble() / 2,
                                          itemBuilder: (context, index) =>
                                              const Icon(
                                            Icons.star_rounded,
                                          ),
                                          itemSize: 20.0,
                                        ),
                                        Text(
                                          '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                                          style: TextStyle(fontSize: 12),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(
                height: 20,
              ),
              Align(
                child: _buildStatsRow(context),
              ),
              SizedBox(
                height: 20,
              ),
              Divider(),
              Text(
                '简介',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 12,
              ),
              LayoutBuilder(builder: (context, constraints) {
                final span = TextSpan(text: bangumiItem.summary);
                final tp =
                    TextPainter(text: span, textDirection: TextDirection.ltr);
                tp.layout(maxWidth: constraints.maxWidth);
                final numLines = tp.computeLineMetrics().length;
                if (numLines > 7) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        // make intro expandable
                        height: fullIntro ? null : 120,
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
                            : MediaQuery.sizeOf(context).width - 32,
                        child: SelectableText(
                          bangumiItem.summary,
                          textAlign: TextAlign.start,
                          scrollBehavior: const ScrollBehavior().copyWith(
                            scrollbars: false,
                          ),
                          scrollPhysics: NeverScrollableScrollPhysics(),
                          selectionHeightStyle: ui.BoxHeightStyle.max,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            fullIntro = !fullIntro;
                          });
                        },
                        child: Text(fullIntro ? '加载更少' : '加载更多'),
                      ),
                    ],
                  );
                } else {
                  return SelectableText(
                    bangumiItem.summary,
                    textAlign: TextAlign.start,
                    scrollPhysics: NeverScrollableScrollPhysics(),
                    selectionHeightStyle: ui.BoxHeightStyle.max,
                  );
                }
              }),
              SizedBox(
                height: 12,
              ),
              Divider(),
              Text(
                '标签',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 12,
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: Utils.isDesktop() ? 8 : 0,
                children: [
                  // 显示标签列表
                  ...List<Widget>.generate(
                    fullTag
                        ? bangumiItem.tags.length
                        : min(12, bangumiItem.tags.length), // 根据状态决定显示数量
                    (int index) => ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${bangumiItem.tags[index].name} '),
                          Text(
                            '${bangumiItem.tags[index].count}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        // 标签点击逻辑
                        context.to(() => BangumiSearchPage(
                            tag: bangumiItem.tags[index].name));
                      },
                    ),
                  ),

                  // 添加展开/收起按钮
                  if (bangumiItem.tags.length > 12) // 只有标签数量超过12时才显示按钮
                    ActionChip(
                      label: Text(
                        fullTag ? '收起 -' : '更多 +', // 根据状态显示不同文本
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          fullTag = !fullTag; // 切换状态
                        });
                      },
                    ),
                ],
              ),
              SizedBox(height: 12),
              Divider(),
              Text(
                '评分统计图',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 12,
              ),
              LineChatPage(
                bangumiItem: bangumiItem,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get commentsListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMoreComments(offset: infoController.commentsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('吐槽'),
            slivers: <Widget>[
              SliverLayoutBuilder(builder: (context, _) {
                if (infoController.commentsList.isNotEmpty) {
                  return SliverList.separated(
                    addAutomaticKeepAlives: false,
                    itemCount: infoController.commentsList.length,
                    itemBuilder: (context, index) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: CommentsCard(
                                commentItem: infoController.commentsList[index],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: Divider(
                                  thickness: 0.5, indent: 10, endIndent: 10),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (commentsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '好像没人发呢...',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadMoreComments(
                                offset: infoController.commentsList.length);
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
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CommentsCard.bone(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              if (commentsIsLoading)
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

  Widget get topicsListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            final isScrollingDown = metrics.pixels > _previousPixels;
            _previousPixels = metrics.pixels;

            if (isScrollingDown &&
                metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMoreTopics(offset: infoController.topicsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('讨论'),
            slivers: <Widget>[
              SliverLayoutBuilder(builder: (context, _) {
                if (topicsList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: topicsList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: TopicsCard(
                              topicsItem: topicsList[index],
                              isBottom: true,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (topicsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '好像没人发呢...',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadMoreTopics();
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
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
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
              if (topicsIsLoading)
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

  Widget get reviewsListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            final isScrollingDown = metrics.pixels > _previousPixels;
            _previousPixels = metrics.pixels;

            if (isScrollingDown &&
                metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMoreReviews(offset: infoController.reviewsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('日志'),
            slivers: <Widget>[
              SliverLayoutBuilder(builder: (context, _) {
                if (reviewsList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: reviewsList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: ReviewsCard(
                              reviewsItem: reviewsList[index],
                              isBottom: true,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (reviewsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '好像没人发呢...',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadMoreReviews();
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
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
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
              if (reviewsIsLoading)
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

  Widget get charactersListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: PageStorageKey<String>('角色'),
          slivers: <Widget>[
            SliverLayoutBuilder(builder: (context, _) {
              if (infoController.characterList.isNotEmpty) {
                return SliverList.builder(
                  itemCount: infoController.characterList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: CharacterCard(
                            characterItem: infoController.characterList[index],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (charactersQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          loadCharacters();
                        },
                        text: '重试',
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
                      width: MediaQuery.sizeOf(context).width > maxWidth
                          ? maxWidth
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
          ],
        );
      },
    );
  }

  Widget get staffListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: PageStorageKey<String>('制作人员'),
          slivers: <Widget>[
            SliverLayoutBuilder(builder: (context, _) {
              if (infoController.staffList.isNotEmpty) {
                return SliverList.builder(
                  itemCount: infoController.staffList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: StaffCard(
                            staffFullItem: infoController.staffList[index],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (staffQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          loadStaff();
                        },
                        text: '重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: 8,
                itemBuilder: (context, _) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width > maxWidth
                          ? maxWidth
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        body: Column(
          children: [
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  controller: infoTabController,
                  tabs: [
                    Tab(text: 'Details'.tl),
                    Tab(text: 'Comments'.tl),
                    Tab(text: 'Comment'.tl),
                    Tab(text: 'Topics'.tl),
                    Tab(text: 'Reviews'.tl),
                    Tab(text: 'Characters'.tl),
                    Tab(text: 'StaffList'.tl),
                  ],
                ),
              ),
            ),
            Expanded(child: Observer(builder: (context) {
              return TabBarView(
                controller: infoTabController,
                children: [
                  Builder(builder: (BuildContext context) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: infoController.isLoading ? infoBodyBone : infoBody,
                    );
                  }),
                  commentsListBody,
                  EpisodeCommentsSheet(
                    episodeInfo: episodeInfo,
                    loadComments: loadComments,
                    episode: WatcherState.currentState!.episode,
                    infoController: infoController,
                  ),
                  topicsListBody,
                  reviewsListBody,
                  charactersListBody,
                  staffListBody
                ],
              );
            })),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
