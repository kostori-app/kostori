import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BangumiInfoCardV extends ConsumerStatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
    this.heroTag,
    required this.infoController,
  });

  final BangumiItem bangumiItem;
  final bool isLoading;
  final Object? heroTag;
  final InfoController infoController;

  @override
  ConsumerState<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends ConsumerState<BangumiInfoCardV> {
  BangumiItem get bangumiItem => widget.bangumiItem;

  InfoController get infoController => widget.infoController;

  List<EpisodeInfo> get allEpisodes => infoController.allEpisodes;

  Widget get voteBarChart =>
      BangumiBarChartPage(bangumiItem: widget.bangumiItem);

  void showBangumiHistoryPagePickerDialog(BuildContext context) {
    final scrollController = ScrollController();

    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: t.historySource,
          displayButton: false,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.transparent,
                      child: ListView.builder(
                        controller: scrollController,
                        shrinkWrap: true,
                        itemCount: infoController.bangumiHistory.length,
                        itemBuilder: (context, index) {
                          final history = infoController.bangumiHistory[index];

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              App.mainNavigatorKey?.currentContext?.to(
                                () => AnimePage(
                                  id: history.id,
                                  sourceKey: history.sourceKey,
                                ),
                              );
                              LocalFavoritesManager().updateRecentlyWatched(
                                history.id,
                                AnimeType(history.sourceKey.hashCode),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BangumiWidget.kostoriImage(
                                      context,
                                      history.cover,
                                      width: 200 * 0.72,
                                      height: 200,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Text(history.title),
                                        const SizedBox(height: 4),
                                        Text(history.sourceKey),
                                        const SizedBox(height: 4),
                                        Text(
                                          t.bangumiLastSeen(
                                            episode:
                                                history.lastWatchEpisode ?? 0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  final manager = StatsManager();
  late StatsDataImpl stats;
  bool isLiked = false;

  int? latestRating;

  Future<void> setStats() async {
    stats = (await manager.getStatsByIdAndType(
      id: bangumiItem.id.toString(),
      type: 'bangumi'.hashCode,
    ))!;
  }

  void liked() {
    StatsManager().updateGroupLiked(
      id: bangumiItem.id.toString(),
      type: 'bangumi'.hashCode,
      targetLiked: !isLiked,
    );
  }

  @override
  void initState() {
    super.initState();
    _init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(statsAllProvider, (_, next) {
        final updated = next
            .when(
              data: (data) => data,
              loading: () => <StatsDataImpl>[],
              error: (_, _) => <StatsDataImpl>[],
            )
            .firstWhereOrNull(
              (s) =>
                  s.id == bangumiItem.id.toString() &&
                  s.type == 'bangumi'.hashCode,
            );
        if (mounted) {
          setState(() {
            latestRating = updated
                ?.rating
                .lastOrNull
                ?.platformEventRecords
                .lastOrNull
                ?.rating;
          });
        }
      });
    });
  }

  Future<void> _init() async {
    if (!await manager.isExistAsync(
      bangumiItem.id.toString(),
      AnimeType('bangumi'.hashCode),
    )) {
      try {
        await manager.addStats(
          manager.createStatsData(
            id: bangumiItem.id.toString(),
            title: bangumiItem.nameCn.isNotEmpty
                ? bangumiItem.nameCn
                : bangumiItem.name,
            cover: bangumiItem.images['large']!,
            type: 'bangumi'.hashCode,
            bangumiId: bangumiItem.id,
            isBangumi: true,
          ),
        );
      } catch (e) {
        StatsLog.error('addStats', e.toString());
      }
    }
    await setStats();
    isLiked = await manager.getGroupLikedStatus(
      id: bangumiItem.id.toString(),
      type: 'bangumi'.hashCode,
    );
    latestRating =
        stats.rating.lastOrNull?.platformEventRecords.lastOrNull?.rating;
    if (mounted) setState(() {});
  }

  Widget _button() {
    return Row(
      children: [
        FilledButton.tonal(
          onPressed: () {
            final context = App.mainNavigatorKey!.currentContext!;
            context.to(
              () => AggregatedSearchPage(
                keyword: bangumiItem.nameCn.isEmpty
                    ? bangumiItem.name
                    : bangumiItem.nameCn,
                bangumiPage: true,
                keywords: bangumiItem.alias,
              ),
            );
          },
          style: FilledButton.styleFrom(
            minimumSize: const Size(80, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          ),
          child: Text(t.search),
        ),

        const SizedBox(width: 8),

        // 开始观看按钮（仅在历史记录存在时显示）
        if (infoController.bangumiHistory.isNotEmpty)
          FilledButton(
            onPressed: () async {
              showBangumiHistoryPagePickerDialog(context);
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(t.bangumiStartWatch),
          ),
      ],
    );
  }

  Future<void> showRatingDialog(StatsDataImpl statsDataImpl) async {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return RatingDialog(statsDataImpl: statsDataImpl);
      },
    );
  }

  final count = [];

  @override
  Widget build(BuildContext context) {
    final bool showRightButton = MediaQuery.of(context).size.width >= 626;
    final bool showBottomButton = !showRightButton;
    double standardDeviation = Utils.getDeviation(
      widget.bangumiItem.total,
      (widget.bangumiItem.count != null)
          ? widget.bangumiItem.count!.values.toList()
          : count,
      widget.bangumiItem.score,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 950, maxHeight: 300),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width <= 550 ? 450 : 475,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    double height =
                        MediaQuery.of(context).size.width <=
                            constraints.maxWidth + 150
                        ? 210
                        : 260;
                    double width = height * 0.72;
                    return Container(
                      width: constraints.maxWidth,
                      height: height,
                      padding: EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              BangumiWidget.showImagePreview(
                                context: context,
                                url: widget.bangumiItem.images['large']!,
                                title: widget.bangumiItem.nameCn,
                                heroTag: (widget.heroTag == null)
                                    ? '${widget.bangumiItem.id}'
                                    : '${widget.heroTag}-${widget.bangumiItem.id}',
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Hero(
                                tag: (widget.heroTag == null)
                                    ? '${widget.bangumiItem.id}'
                                    : '${widget.heroTag}-${widget.bangumiItem.id}',
                                flightShuttleBuilder:
                                    (
                                      flightContext,
                                      animation,
                                      direction,
                                      fromContext,
                                      toContext,
                                    ) {
                                      return direction ==
                                              HeroFlightDirection.pop
                                          ? (fromContext.widget as Hero).child
                                          : (toContext.widget as Hero).child;
                                    },
                                child: SizedBox(
                                  width: width,
                                  height: height,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: BangumiWidget.kostoriImage(
                                          context,
                                          widget.bangumiItem.images['large']!,
                                          width: width,
                                          height: height,
                                        ),
                                      ),
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              liked();
                                              setState(() {
                                                isLiked = !isLiked;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              child: AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
                                                child: Icon(
                                                  isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color: isLiked
                                                      ? Colors.redAccent
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.0),
                          Container(
                            height: height,
                            constraints: BoxConstraints(maxWidth: 235),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onLongPress: () {
                                    Clipboard.setData(
                                      ClipboardData(text: bangumiItem.nameCn),
                                    );
                                    App.rootContext.showMessage(
                                      message: t.copiedToClipboard,
                                    );
                                  },
                                  child: Text(
                                    bangumiItem.nameCn,
                                    style: TextStyle(
                                      fontSize: width * 1 / 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onLongPress: () {
                                    Clipboard.setData(
                                      ClipboardData(text: bangumiItem.name),
                                    );
                                    App.rootContext.showMessage(
                                      message: t.copiedToClipboard,
                                    );
                                  },
                                  child: Text(
                                    bangumiItem.name,
                                    style: TextStyle(fontSize: width * 1 / 24),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(height: 12.0),
                                (!widget.isLoading)
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,

                                        children: [
                                          if (bangumiItem.airDate.isNotEmpty)
                                            Container(
                                              padding: EdgeInsets.fromLTRB(
                                                8,
                                                5,
                                                8,
                                                5,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                color: Colors.transparent,
                                                border: Border.all(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .toOpacity(0.72),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Text(
                                                bangumiItem.airDate,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          SizedBox(width: 4.0),
                                          () {
                                            final currentWeekEp =
                                                infoController.currentWeekEp;
                                            final type0Episodes = infoController
                                                .allEpisodes
                                                .where((ep) => ep.type == 0)
                                                .toList();
                                            final lastSort =
                                                type0Episodes.isNotEmpty
                                                ? type0Episodes.last.sort
                                                : null;
                                            final currentSort =
                                                currentWeekEp.isEmpty
                                                ? null
                                                : currentWeekEp
                                                      .values
                                                      .first
                                                      ?.sort;
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
                                        ],
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: SizedBox(
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 12,
                                                  width: 60,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 12,
                                                  width: 60,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                Spacer(),
                                (!widget.isLoading)
                                    ? Align(
                                        alignment: Alignment.bottomRight,
                                        child: InkWell(
                                          onTap: () async {
                                            await showRatingDialog(stats);
                                          },
                                          customBorder: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12.0,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                if (latestRating != null)
                                                  Text(
                                                    t.bangumiMyRating(
                                                      score: latestRating ?? 0,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12.0,
                                                    ),
                                                  ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (bangumiItem.total >=
                                                        20) ...[
                                                      Text(
                                                        '${bangumiItem.score}',
                                                        style: TextStyle(
                                                          fontSize: 24.0,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      SizedBox(width: 5),
                                                      Container(
                                                        padding:
                                                            EdgeInsets.fromLTRB(
                                                              8,
                                                              5,
                                                              8,
                                                              5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary
                                                                    .toOpacity(
                                                                      0.72,
                                                                    ),
                                                            width: 1.0,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          Utils.getRatingLabel(
                                                            bangumiItem.score,
                                                          ),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 4),
                                                    ],
                                                    Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        RatingBarIndicator(
                                                          itemCount: 5,
                                                          rating:
                                                              bangumiItem.score
                                                                  .toDouble() /
                                                              2,
                                                          itemBuilder:
                                                              (
                                                                context,
                                                                index,
                                                              ) => const Icon(
                                                                Icons
                                                                    .star_rounded,
                                                              ),
                                                          itemSize: 20.0,
                                                        ),
                                                        Text(
                                                          Translations.of(
                                                            context,
                                                          ).tReviewsR(
                                                            t: bangumiItem
                                                                .total,
                                                            r: bangumiItem.rank,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                    : Align(
                                        alignment: Alignment.bottomRight,
                                        child: Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 10,
                                                  width: 120,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Skeletonizer.zone(
                                                child: Bone.text(
                                                  fontSize: 10,
                                                  width: 120,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                if (showRightButton) ...[
                                  // Spacer(),
                                  SizedBox(height: 4),
                                  (!widget.isLoading)
                                      ? _button()
                                      : Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: SizedBox(
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Skeletonizer.zone(
                                                  child: Bone.text(
                                                    fontSize: 24,
                                                    width: 60,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Skeletonizer.zone(
                                                  child: Bone.text(
                                                    fontSize: 24,
                                                    width: 120,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ), // 底部按钮
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      (bangumiItem.collection != null && !widget.isLoading)
                          ? Align(
                              child: BangumiWidget.buildStatsRow(
                                context: context,
                                bangumiItem: bangumiItem,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Skeletonizer.zone(
                                      child: Bone.text(
                                        fontSize: 10,
                                        width: 240,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      if (showBottomButton) ...[
                        Spacer(),
                        (!widget.isLoading)
                            ? _button()
                            : Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: SizedBox(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Skeletonizer.zone(
                                        child: Bone.text(
                                          fontSize: 24,
                                          width: 60,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Skeletonizer.zone(
                                        child: Bone.text(
                                          fontSize: 24,
                                          width: 120,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ), // 底部按钮
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (MediaQuery.sizeOf(context).width >= 1200 &&
                      !widget.isLoading &&
                      widget.bangumiItem.total > 20)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 450,
                        maxHeight: 300,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.ratingChart,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${bangumiItem.score}',
                                  style: ts.s12,
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
                                const SizedBox(width: 24),
                                Text('${widget.bangumiItem.total} votes'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Spacer(),
                          Expanded(
                            child: BangumiBarChartPage(
                              bangumiItem: widget.bangumiItem,
                            ),
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
  }
}
