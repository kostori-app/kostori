import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/character_card.dart';
import 'package:kostori/components/bean/card/comments_card.dart';
import 'package:kostori/components/bean/card/episode_comments_sheet.dart';
import 'package:kostori/components/bean/card/reviews_card.dart';
import 'package:kostori/components/bean/card/staff_card.dart';
import 'package:kostori/components/bean/card/topics_card.dart';
import 'package:kostori/components/error_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/translation_service.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart'
    show BangumiSearchPage;
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';

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
  late final TranslationController _translationController;
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
    _translationController = TranslationController();
    infoController = widget.infoController;
    // Riverpod 不允许在 initState 同步修改 provider，延迟到 microtask 后。
    // 全局单例在二次进入时残留上次的 isLoading=false，先强制为 true 触发骨架。
    Future(() => infoController.setIsLoading(true));
    // Riverpod 不允许在 initState 同步修改 provider，延迟到首帧后
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      infoController.clearBangumiLists();
      infoController.bangumiId = widget.bangumiId!;
      queryBangumiInfoByID(infoController.bangumiId);
      queryBangumiEpisodeByID(infoController.bangumiId);
    });
    infoTabController = TabController(
      length: infoController.tabs.length + 1,
      vsync: this,
    );
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
    infoTabController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  void updata() {
    setState(() {});
  }

  Future<void> _handleTranslation(String text) async {
    await _translationController.translate(text);
  }

  Future<void> queryBangumiInfoByID(int id) async {
    try {
      await infoController.queryBangumiInfoByID(id, defaultToDb: true);
      setState(() {});
    } catch (e) {
      Log.error('queryBangumiInfoByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeByID(int id) async {
    try {
      await infoController.queryBangumiEpisodeByID(id, defaultToDb: true);
      setState(() {});
    } catch (e) {
      Log.error('queryBangumiEpisodeByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeCommentsByID(
    int id,
    int episode, {
    int offset = 0,
  }) async {
    await infoController.queryBangumiEpisodeCommentsByID(
      id,
      episode,
      offset: offset,
    );
    if (mounted) {
      setState(() {});
    }
  }

  /// 通用加载：并发防重入 + 空结果超时标记。
  Future<void> _loadSection({
    required bool isLoading,
    required void Function(bool) setLoading,
    required void Function(bool) setTimeoutFlag,
    required bool Function() isListEmpty,
    required Future<void> Function() load,
  }) async {
    if (isLoading) return;
    setState(() {
      setLoading(true);
      setTimeoutFlag(false);
    });
    try {
      await load();
    } catch (e) {
      Log.error('loadSection', e.toString());
    }
    if (!mounted) return;
    setState(() {
      setLoading(false);
      if (isListEmpty()) setTimeoutFlag(true);
    });
  }

  Future<void> loadCharacters() => _loadSection(
    isLoading: charactersIsLoading,
    setLoading: (v) => charactersIsLoading = v,
    setTimeoutFlag: (v) => charactersQueryTimeout = v,
    isListEmpty: () => infoController.characterList.isEmpty,
    load: () =>
        infoController.queryBangumiCharactersByID(infoController.bangumiId),
  );

  Future<void> loadMoreComments({int offset = 0}) => _loadSection(
    isLoading: commentsIsLoading,
    setLoading: (v) => commentsIsLoading = v,
    setTimeoutFlag: (v) => commentsQueryTimeout = v,
    isListEmpty: () => infoController.commentsList.isEmpty,
    load: () => infoController.queryBangumiCommentsByID(
      infoController.bangumiId,
      offset: offset,
    ),
  );

  Future<void> loadMoreTopics({int offset = 0}) => _loadSection(
    isLoading: topicsIsLoading,
    setLoading: (v) => topicsIsLoading = v,
    setTimeoutFlag: (v) => topicsQueryTimeout = v,
    isListEmpty: () => infoController.topicsList.isEmpty,
    load: () => infoController.queryBangumiTopicsByID(
      infoController.bangumiItem.id,
      offset: offset,
    ),
  );

  Future<void> loadMoreReviews({int offset = 0}) => _loadSection(
    isLoading: reviewsIsLoading,
    setLoading: (v) => reviewsIsLoading = v,
    setTimeoutFlag: (v) => reviewsQueryTimeout = v,
    isListEmpty: () => infoController.reviewsList.isEmpty,
    load: () => infoController.queryBangumiReviewsByID(
      infoController.bangumiItem.id,
      offset: offset,
    ),
  );

  Future<void> loadStaff() => _loadSection(
    isLoading: staffIsLoading,
    setLoading: (v) => staffIsLoading = v,
    setTimeoutFlag: (v) => staffQueryTimeout = v,
    isListEmpty: () => infoController.staffList.isEmpty,
    load: () => infoController.queryBangumiStaffsByID(infoController.bangumiId),
  );

  Future<void> loadComments(int episode, {int offset = 0}) async {
    commentsQueryTimeout = false;
    await queryBangumiEpisodeCommentsByID(
      infoController.bangumiId,
      episode,
      offset: offset,
    ).then((_) {
      if (infoController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    });
  }

  Widget get infoBodyBone {
    return KostoriRefreshIndicator();
  }

  /// 区块分隔线（infoBody 中重复出现多次）
  Widget _sectionDivider() {
    return Center(
      child: Container(
        width: 120,
        height: 2,
        decoration: BoxDecoration(
          color: Colors.grey.toOpacity(0.4),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  /// 区块标题 + 计数徽章（infoBody 中多处重复）
  Widget _sectionTitle(BuildContext context, String title, num count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: ts.s12),
        ),
      ],
    );
  }

  Widget get infoBody {
    if (bangumiId == null) {
      return Center(child: infoBodyBone);
    }
    final loaded = infoController.bangumiItemOrNull;
    if (loaded == null) {
      return Center(child: infoBodyBone);
    }
    var bangumiItem = loaded;
    double standardDeviation = Utils.getDeviation(
      bangumiItem.total,
      bangumiItem.count?.values.toList() ?? const [],
      bangumiItem.score,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: LayoutBuilder(
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
                            context,
                            bangumiItem.images['large']!,
                            width: width,
                            height: height,
                          ),
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
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  bangumiItem.name,
                                  style: TextStyle(fontSize: width * 1 / 24),
                                ),
                                SizedBox(height: 12.0),
                                Container(
                                  padding: EdgeInsets.all(8.0),
                                  // 可选，设置内边距
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      16.0,
                                    ), // 设置圆角半径
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                          .toOpacity(0.72),
                                      width: 2.0, // 设置边框宽度
                                    ),
                                  ),
                                  child: Text(bangumiItem.airDate),
                                ),
                                SizedBox(height: 12.0),
                                () {
                                  final currentWeekEp =
                                      infoController.currentWeekEp;
                                  final type0Episodes = infoController
                                      .allEpisodes
                                      .where((ep) => ep.type == 0)
                                      .toList();
                                  final lastSort = type0Episodes.isNotEmpty
                                      ? type0Episodes.last.sort
                                      : null;
                                  final currentSort = currentWeekEp.isEmpty
                                      ? null
                                      : currentWeekEp.values.first?.sort;
                                  final isCompleted =
                                      currentSort != null &&
                                      lastSort != null &&
                                      currentSort.toDouble() ==
                                          lastSort.toDouble();
                                  return BangumiWidget.bangumiTimeText(
                                    bangumiItem,
                                    currentWeekEp,
                                    isCompleted,
                                  );
                                }(),
                                Spacer(),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${bangumiItem.score}',
                                        style: TextStyle(fontSize: 28.0),
                                      ),
                                      SizedBox(width: 5),
                                      Container(
                                        padding: EdgeInsets.all(2.0),
                                        // 可选，设置内边距
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ), // 设置圆角半径
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondaryContainer
                                                .toOpacity(0.72),
                                            width: 2.0, // 设置边框宽度
                                          ),
                                        ),
                                        child: Text(
                                          Utils.getRatingLabel(
                                            bangumiItem.score,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end, // 右对齐
                                        children: [
                                          RatingBarIndicator(
                                            itemCount: 5,
                                            rating:
                                                bangumiItem.score.toDouble() /
                                                2,
                                            itemBuilder: (context, index) =>
                                                const Icon(Icons.star_rounded),
                                            itemSize: 18.0,
                                          ),
                                          Text(
                                            t.tReviewsR(
                                              t: bangumiItem.total,
                                              r: bangumiItem.rank,
                                            ),
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                child: BangumiWidget.buildStatsRow(
                  context: context,
                  bangumiItem: infoController.bangumiItem,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _sectionDivider(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListenableBuilder(
                    listenable: _translationController,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: <Widget>[
                              Text(
                                t.introduction,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                onPressed: _translationController.isTranslating
                                    ? null
                                    : () => _handleTranslation(
                                        bangumiItem.summary,
                                      ),
                                icon: _translationController.isTranslating
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.translate,
                                        size: 24,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ExpandableText(
                              text: bangumiItem.summary,
                              translationController: _translationController,
                              isLoading: infoController.isLoading,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _sectionDivider(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, t.tags, bangumiItem.tags.length),
                  SizedBox(height: 12),
                  ExpandableTags(
                    tags: bangumiItem.tags,
                    fullTag: fullTag,
                    onToggle: () => setState(() => fullTag = !fullTag),
                    onTagTap: (index) {
                      context.to(
                        () => BangumiSearchPage(
                          tag: bangumiItem.tags[index].name,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (infoController.bangumiSRI.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionDivider(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                child: _sectionTitle(
                  context,
                  t.linkedItems,
                  infoController.bangumiSRI.length,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                child: SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: infoController.bangumiSRI.length,
                    itemBuilder: (context, index) {
                      final item = infoController.bangumiSRI[index];
                      final title = item.nameCn == '' ? item.name : item.nameCn;
                      const style = TextStyle(fontWeight: FontWeight.w500);
                      final textPainter = TextPainter(
                        text: TextSpan(text: title, style: style),
                        maxLines: 1,
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: 140);

                      final shouldScroll = textPainter.width >= 140;

                      return Container(
                        width: 140,
                        margin: const EdgeInsets.only(left: 0, right: 8),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              App.mainNavigatorKey?.currentContext?.to(
                                () => BangumiInfoPage(
                                  bangumiItem: BangumiItem(
                                    id: item.id,
                                    type: 2,
                                    name: item.name,
                                    nameCn: item.nameCn,
                                    summary: '',
                                    airDate: '',
                                    airWeekday: 1,
                                    rank: 0,
                                    total: 0,
                                    totalEpisodes: 0,
                                    score: 0,
                                    images: item.images,
                                    tags: [],
                                    alias: [],
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 封面图改成 Ink.image
                                Ink.image(
                                  image: CachedImageProvider(
                                    item.images['large']!,
                                    sourceKey: 'bangumi',
                                  ),
                                  width: 140,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Center(
                                    child: SizedBox(
                                      height: 20,
                                      child: shouldScroll
                                          ? Marquee(
                                              text: title,
                                              style: style,
                                              scrollAxis: Axis.horizontal,
                                              blankSpace: 10.0,
                                              velocity: 40.0,
                                              pauseAfterRound: Duration.zero,
                                              accelerationDuration:
                                                  Duration.zero,
                                              decelerationDuration:
                                                  Duration.zero,
                                            )
                                          : Text(
                                              title,
                                              style: style,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                  ),
                                ),

                                // 关联关系
                                Padding(
                                  padding: const EdgeInsets.all(2.0),
                                  child: Center(
                                    child: Text(
                                      item.relation,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _sectionDivider(),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: _sectionTitle(context, t.ratingChart, bangumiItem.score),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  Text(
                    t.standardDeviationS(
                      s: standardDeviation.toStringAsFixed(2),
                    ),
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Utils.getDispute(standardDeviation),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: BangumiBarChartPage(bangumiItem: bangumiItem),
            ),
            const SizedBox(height: 16),
            _sectionDivider(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 通用列表体：滚动加载更多 + 数据/超时/骨架屏三态。
  /// 由五个几乎相同的 listBody getter 合并而来。
  Widget _listBody<T>({
    required String storageKey,
    required List<T> list,
    required bool isLoading,
    required bool queryTimeout,
    required int boneCount,
    required Future<void> Function(int offset) loadMore,
    required Future<void> Function() retry,
    required Widget Function(int index) itemBuilder,
    required Widget Function() boneBuilder,
  }) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollEnd) {
        final metrics = scrollEnd.metrics;
        final isScrollingDown = metrics.pixels > _previousPixels;
        _previousPixels = metrics.pixels;
        if (isScrollingDown &&
            metrics.pixels >= metrics.maxScrollExtent - 200) {
          loadMore(list.length);
        }
        return true;
      },
      child: CustomScrollView(
        scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
        key: PageStorageKey<String>(storageKey),
        slivers: <Widget>[
          SliverLayoutBuilder(
            builder: (context, _) {
              if (list.isNotEmpty) {
                return SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) => _centeredWidthCard(
                    child: itemBuilder(index),
                    width: MediaQuery.sizeOf(context).width,
                  ),
                );
              }
              if (queryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: t.nobodysPostedAnythingYet,
                    actions: [
                      GeneralErrorButton(onPressed: retry, text: t.reload),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: boneCount,
                itemBuilder: (context, index) => _centeredWidthCard(
                  child: boneBuilder(),
                  width: MediaQuery.sizeOf(context).width,
                ),
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
  }

  /// 居中 + 限宽包裹卡片（桌面端限制内容宽度）
  Widget _centeredWidthCard({required Widget child, required double width}) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: width > maxWidth ? maxWidth : width - 32,
          child: child,
        ),
      ),
    );
  }

  Widget get commentsListBody => _listBody<dynamic>(
    storageKey: '吐槽',
    list: infoController.commentsList,
    isLoading: commentsIsLoading,
    queryTimeout: commentsQueryTimeout,
    boneCount: 4,
    loadMore: (o) => loadMoreComments(offset: o),
    retry: () => loadMoreComments(offset: infoController.commentsList.length),
    itemBuilder: (index) =>
        CommentsCard(commentItem: infoController.commentsList[index]),
    boneBuilder: () => CommentsCard.bone(),
  );

  Widget get topicsListBody => _listBody<dynamic>(
    storageKey: '讨论',
    list: infoController.topicsList,
    isLoading: topicsIsLoading,
    queryTimeout: topicsQueryTimeout,
    boneCount: 4,
    loadMore: (o) => loadMoreTopics(offset: o),
    retry: loadMoreTopics,
    itemBuilder: (index) => TopicsCard(
      topicsItem: infoController.topicsList[index],
      isBottom: true,
    ),
    boneBuilder: () => TopicsCard.bone(),
  );

  Widget get reviewsListBody => _listBody<dynamic>(
    storageKey: '日志',
    list: infoController.reviewsList,
    isLoading: reviewsIsLoading,
    queryTimeout: reviewsQueryTimeout,
    boneCount: 4,
    loadMore: (o) => loadMoreReviews(offset: o),
    retry: loadMoreReviews,
    itemBuilder: (index) => ReviewsCard(
      reviewsItem: infoController.reviewsList[index],
      isBottom: true,
    ),
    boneBuilder: () => ReviewsCard.bone(),
  );

  Widget get charactersListBody => _listBody<dynamic>(
    storageKey: '角色',
    list: infoController.characterList,
    isLoading: charactersIsLoading,
    queryTimeout: charactersQueryTimeout,
    boneCount: 4,
    loadMore: (o) => loadCharacters(),
    retry: loadCharacters,
    itemBuilder: (index) =>
        CharacterCard(characterItem: infoController.characterList[index]),
    boneBuilder: () => CharacterCard.bone(),
  );

  Widget get staffListBody => _listBody<dynamic>(
    storageKey: '制作人员',
    list: infoController.staffList,
    isLoading: staffIsLoading,
    queryTimeout: staffQueryTimeout,
    boneCount: 8,
    loadMore: (o) => loadStaff(),
    retry: loadStaff,
    itemBuilder: (index) =>
        StaffCard(staffFullItem: infoController.staffList[index]),
    boneBuilder: () => StaffCard.bone(),
  );

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
                    Tab(text: t.details),
                    Tab(text: t.comments),
                    Tab(text: t.comment),
                    Tab(text: t.topics),
                    Tab(text: t.reviews),
                    Tab(text: t.characters),
                    Tab(text: t.staffList),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: infoTabController,
                children: [
                  Builder(
                    builder: (BuildContext context) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child:
                            infoController.isLoading ||
                                infoController.bangumiId != widget.bangumiId ||
                                infoController.bangumiItemOrNull == null
                            ? infoBodyBone
                            : infoBody,
                      );
                    },
                  ),
                  commentsListBody,
                  EpisodeCommentsSheet(
                    episodeInfo: episodeInfo,
                    loadComments: loadComments,
                    episode: WatcherState.currentState!.epIndex,
                    infoController: infoController,
                  ),
                  topicsListBody,
                  reviewsListBody,
                  charactersListBody,
                  staffListBody,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
