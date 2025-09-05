import 'package:flutter/material.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/character_card.dart';
import 'package:kostori/components/bean/card/comments_card.dart';
import 'package:kostori/components/bean/card/reviews_card.dart';
import 'package:kostori/components/bean/card/staff_card.dart';
import 'package:kostori/components/bean/card/topics_card.dart';
import 'package:kostori/components/error_widget.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/bangumi_subject_relations_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/foundation/bangumi/staff/staff_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/pages/bangumi/bangumi_all_episode_page.dart';
import 'package:kostori/pages/bangumi/bangumi_episode_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/pages/bangumi/bangumi_search_page.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:marquee/marquee.dart';
import 'package:skeletonizer/skeletonizer.dart';

class InfoTabView extends StatefulWidget {
  const InfoTabView({
    super.key,
    required this.commentsQueryTimeout,
    required this.topicsQueryTimeout,
    required this.charactersQueryTimeout,
    required this.staffQueryTimeout,
    required this.tabController,
    required this.loadMoreComments,
    required this.loadMoreTopics,
    required this.loadCharacters,
    required this.loadStaff,
    required this.bangumiItem,
    required this.bangumiSRI,
    required this.allEpisodes,
    required this.commentsList,
    required this.characterList,
    required this.staffList,
    required this.isLoading,
    required this.infoController,
    required this.reviewsQueryTimeout,
    required this.loadMoreReviews,
    required this.commentsIsLoading,
    required this.topicsIsLoading,
    required this.reviewsIsLoading,
  });

  final bool commentsIsLoading;
  final bool topicsIsLoading;
  final bool reviewsIsLoading;
  final bool commentsQueryTimeout;
  final bool topicsQueryTimeout;
  final bool reviewsQueryTimeout;
  final bool charactersQueryTimeout;
  final bool staffQueryTimeout;
  final TabController tabController;
  final Future<void> Function({int offset}) loadMoreComments;
  final Future<void> Function({int offset}) loadMoreTopics;
  final Future<void> Function({int offset}) loadMoreReviews;
  final Future<void> Function() loadCharacters;
  final Future<void> Function() loadStaff;
  final BangumiItem bangumiItem;
  final List<BangumiSRI> bangumiSRI;
  final List<EpisodeInfo> allEpisodes;
  final List<CommentItem> commentsList;
  final List<CharacterItem> characterList;
  final List<StaffFullItem> staffList;
  final bool isLoading;
  final InfoController infoController;

  @override
  State<InfoTabView> createState() => _InfoTabViewState();
}

class _InfoTabViewState extends State<InfoTabView>
    with SingleTickerProviderStateMixin {
  final maxWidth = 950.0;
  bool fullIntro = false;
  bool fullTag = false;

  InfoController get infoController => widget.infoController;

  bool get count => areAllValuesZero(widget.bangumiItem.count!);

  List<TopicsItem> get topicsList => widget.infoController.topicsList;

  List<ReviewsItem> get reviewsList => widget.infoController.reviewsList;

  double _previousPixels = 0;

  bool areAllValuesZero(Map<String, int> countMap) {
    return countMap.values.every((value) => value == 0);
  }

  Widget get infoBody {
    double standardDeviation = Utils.getDeviation(
      widget.bangumiItem.total,
      widget.bangumiItem.count!.values.toList(),
      widget.bangumiItem.score,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                'Introduction'.tl,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ExpandableText(text: widget.bangumiItem.summary),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 120,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.toOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Tags'.tl,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.bangumiItem.tags.length}',
                      style: ts.s12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ExpandableTags(
                tags: widget.bangumiItem.tags,
                fullTag: fullTag,
                onToggle: () => setState(() => fullTag = !fullTag),
                onTagTap: (index) {
                  context.to(
                    () => BangumiSearchPage(
                      tag: widget.bangumiItem.tags[index].name,
                    ),
                  );
                },
              ),
              if (widget.allEpisodes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.toOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'All Episodes'.tl,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${widget.allEpisodes.length}',
                        style: ts.s12,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        context.to(
                          () => BangumiAllEpisodePage(
                            allEpisodes: widget.allEpisodes,
                            infoController: widget.infoController,
                          ),
                        );
                      },
                      child: Text('more'.tl),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    // 显示最多15个
                    ...widget.allEpisodes.take(15).map((episode) {
                      double intensity = (episode.comment / 300).clamp(
                        0.1,
                        1.0,
                      );
                      return SizedBox(
                        width: 50,
                        height: 50,
                        child: Column(
                          children: [
                            Expanded(
                              child: Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: context.colorScheme.onSurface
                                        .withAlpha(25),
                                    width: 2,
                                  ),
                                ),
                                color: Theme.of(context).colorScheme.surface,
                                shadowColor: Theme.of(context).shadowColor,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    context.to(
                                      () => BangumiEpisodeInfoPage(
                                        episode: episode,
                                        infoController: widget.infoController,
                                      ),
                                    );
                                  },
                                  onLongPress: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          content: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 420,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "${Utils.readType(episode.type)}${episode.sort}.${episode.nameCn.isNotEmpty ? episode.nameCn : episode.name}",
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (episode.nameCn.isNotEmpty)
                                                    Text(
                                                      "${Utils.readType(episode.type)}${episode.sort}.${episode.name}",
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "Broadcast Time: @a"
                                                            .tlParams({
                                                              'a': episode
                                                                  .airDate,
                                                            }),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        "Time: @s".tlParams({
                                                          's': episode.duration,
                                                        }),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(episode.desc),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Center(
                                    child: Text(episode.sort.toString()),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.toOpacity(intensity),
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // 如果超过15个，显示一个“...”的卡片
                    if (widget.allEpisodes.length > 15)
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: context.colorScheme.onSurface.withAlpha(
                                25,
                              ),
                              width: 2,
                            ),
                          ),
                          color: Theme.of(context).colorScheme.surface,
                          shadowColor: Theme.of(context).shadowColor,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              context.to(
                                () => BangumiAllEpisodePage(
                                  allEpisodes: widget.allEpisodes,
                                  infoController: widget.infoController,
                                ),
                              );
                            },
                            child: const Center(child: Text('...')),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (widget.bangumiSRI.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.toOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Linked Items'.tl,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${widget.bangumiSRI.length}', style: ts.s12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.bangumiSRI.length,
                    itemBuilder: (context, index) {
                      final item = widget.bangumiSRI[index];
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
                          clipBehavior: Clip.antiAlias, // 确保圆角裁剪对 Ink.image 生效
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

                                // 标题
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
              ],
              if (MediaQuery.sizeOf(context).width <= 1200 &&
                  !widget.isLoading &&
                  widget.bangumiItem.total > 20) ...[
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.toOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Rating Chart'.tl,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${widget.bangumiItem.score}', style: ts.s12),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          infoController.showLineChart =
                              !infoController.showLineChart;
                        });
                      },
                      icon: Icon(
                        infoController.showLineChart
                            ? Icons.show_chart
                            : Icons.bar_chart,
                      ),
                      label: Text(
                        infoController.showLineChart
                            ? 'Line Chart'.tl
                            : 'Bar Chart'.tl,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Standard Deviation: @s'.tlParams({
                          's': standardDeviation.toStringAsFixed(2),
                        }),
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Utils.getDispute(standardDeviation),
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 24),
                      Text('${widget.bangumiItem.total} votes'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                infoController.showLineChart
                    ? LineChatPage(bangumiItem: widget.bangumiItem)
                    : BangumiBarChartPage(bangumiItem: widget.bangumiItem),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bone for Skeleton Loader
  Widget get infoBodyBone {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 50)),
              const SizedBox(height: 8),
              Skeletonizer.zone(child: Bone.multiText(lines: 7)),
              const SizedBox(height: 16),
              Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 50)),
              const SizedBox(height: 8),
              if (widget.isLoading)
                Skeletonizer.zone(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(
                      4,
                      (_) => Bone.button(uniRadius: 8, height: 32),
                    ),
                  ),
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
              widget.loadMoreComments(offset: widget.commentsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            key: PageStorageKey<String>('Comments'.tl),
            slivers: <Widget>[
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
              SliverLayoutBuilder(
                builder: (context, _) {
                  if (widget.commentsList.isNotEmpty) {
                    return SliverList.separated(
                      addAutomaticKeepAlives: false,
                      itemCount: widget.commentsList.length,
                      itemBuilder: (context, index) {
                        return SafeArea(
                          top: false,
                          bottom: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: SizedBox(
                                width:
                                    MediaQuery.sizeOf(context).width > maxWidth
                                    ? maxWidth
                                    : MediaQuery.sizeOf(context).width - 32,
                                child: CommentsCard(
                                  commentItem: widget.commentsList[index],
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: SizedBox(
                                width:
                                    MediaQuery.sizeOf(context).width > maxWidth
                                    ? maxWidth
                                    : MediaQuery.sizeOf(context).width - 32,
                                child: Divider(
                                  thickness: 0.5,
                                  indent: 10,
                                  endIndent: 10,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  if (widget.commentsQueryTimeout) {
                    return SliverFillRemaining(
                      child: GeneralErrorWidget(
                        errMsg: "Nobody's posted anything yet...".tl,
                        actions: [
                          GeneralErrorButton(
                            onPressed: () {
                              widget.loadMoreComments(
                                offset: widget.commentsList.length,
                              );
                            },
                            text: 'Reload'.tl,
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
                },
              ),
              if (widget.commentsIsLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: MiscComponents.placeholder(
                        context,
                        40,
                        40,
                        Colors.transparent,
                      ),
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
              widget.loadMoreTopics(offset: infoController.topicsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            key: PageStorageKey<String>('Discussion'.tl),
            slivers: <Widget>[
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
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
                              child: TopicsCard(topicsItem: topicsList[index]),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  if (widget.topicsQueryTimeout) {
                    return SliverFillRemaining(
                      child: GeneralErrorWidget(
                        errMsg: "Nobody's posted anything yet...".tl,
                        actions: [
                          GeneralErrorButton(
                            onPressed: () {
                              widget.loadMoreTopics();
                            },
                            text: 'Reload'.tl,
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
                },
              ),
              if (widget.topicsIsLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: MiscComponents.placeholder(
                        context,
                        40,
                        40,
                        Colors.transparent,
                      ),
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
              widget.loadMoreReviews(offset: infoController.reviewsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            key: PageStorageKey<String>('Log'.tl),
            slivers: <Widget>[
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
              SliverLayoutBuilder(
                builder: (context, _) {
                  if (reviewsList.isNotEmpty) {
                    return SliverList.builder(
                      itemCount: reviewsList.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: ReviewsCard(
                                reviewsItem: reviewsList[index],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  if (widget.reviewsQueryTimeout) {
                    return SliverFillRemaining(
                      child: GeneralErrorWidget(
                        errMsg: "Nobody's posted anything yet...".tl,
                        actions: [
                          GeneralErrorButton(
                            onPressed: () {
                              widget.loadMoreReviews();
                            },
                            text: 'Reload'.tl,
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
                },
              ),
              if (widget.reviewsIsLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: MiscComponents.placeholder(
                        context,
                        40,
                        40,
                        Colors.transparent,
                      ),
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
          scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
          key: PageStorageKey<String>('Characters'.tl),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(
              builder: (context, _) {
                if (widget.characterList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: widget.characterList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CharacterCard(
                              characterItem: widget.characterList[index],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (widget.charactersQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: 'Failed to load, please try again.'.tl,
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            widget.loadCharacters();
                          },
                          text: 'Reload'.tl,
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
              },
            ),
          ],
        );
      },
    );
  }

  Widget get staffListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
          key: PageStorageKey<String>('StaffList'.tl),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(
              builder: (context, _) {
                if (widget.staffList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: widget.staffList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: StaffCard(
                              staffFullItem: widget.staffList[index],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (widget.staffQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: 'Failed to load, please try again.'.tl,
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            widget.loadStaff();
                          },
                          text: 'Reload'.tl,
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
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      controller: widget.tabController,
      children: [
        Builder(
          // This Builder is needed to provide a BuildContext that is
          // "inside" the NestedScrollView, so that
          // sliverOverlapAbsorberHandleFor() can find the
          // NestedScrollView.
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              // The PageStorageKey should be unique to this ScrollView;
              // it allows the list to remember its scroll position when
              // the tab view is not on the screen.
              key: PageStorageKey<String>('Overview'.tl),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: widget.isLoading ? infoBodyBone : infoBody,
                  ),
                ),
              ],
            );
          },
        ),
        commentsListBody,
        topicsListBody,
        reviewsListBody,
        charactersListBody,
        staffListBody,
      ],
    );
  }
}
