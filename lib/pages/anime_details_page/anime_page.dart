// ignore_for_file: unused_element_parameter

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'actions.dart';

part 'episodes.dart';

part 'favorite.dart';

class AnimePage extends ConsumerStatefulWidget {
  const AnimePage({
    super.key,
    required this.id,
    required this.sourceKey,
    this.cover,
    this.title,
    this.heroID,
  });

  final String id;

  final String sourceKey;

  final String? cover;

  final String? title;

  final int? heroID;

  @override
  ConsumerState<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends LoadingState<AnimePage, AnimeDetails>
    with _AnimePageActions, TickerProviderStateMixin {
  bool showAppbarTitle = false;

  var scrollController = ScrollController();
  bool isDownloaded = false;
  bool isBangumi = false;

  final stats = StatsManager();

  BangumiItem? get bangumiItem => bangumiBindInfo;
  late TabController tabController;

  void updateHistory() async {
    var newHistory = await HistoryManager().findAsync(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    if (newHistory?.lastWatchEpisode != history?.lastWatchEpisode ||
        newHistory?.lastWatchTime != history?.lastWatchTime) {
      history = newHistory;
      if (mounted) update();
    }
  }

  void updateBangumiBind() async {
    if (history?.bangumiId != null) {
      bangumiBindInfo = await Bangumi.instance.bindFind(
        history!.bangumiId as int,
      );
      update();
    }
  }

  Future<void> updateStatsClicks() async {
    if (!await stats.isExistAsync(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    )) {
      try {
        await stats.addStats(
          stats.createStatsData(
            id: widget.id,
            title: widget.title,
            cover: widget.cover,
            type: widget.sourceKey.hashCode,
          ),
        );
      } catch (e) {
        StatsLog.error('addStats', e.toString());
      }
    }

    final (statsDataImpl, todayClick, platformRecord) = await stats
        .getOrCreateTodayPlatformRecord(
          id: widget.id,
          type: widget.sourceKey.hashCode,
          targetType: DailyEventType.click,
        );
    final now = DateTime.now();
    platformRecord.value += 1;
    platformRecord.date = now;
    statsDataImpl.lastClickTime = now;
    await stats.addStats(statsDataImpl);
  }

  Future<void> updateStats() async {
    final s = await stats.getStatsByIdAndType(
      id: widget.id,
      type: widget.sourceKey.hashCode,
    );
    if (s == null) return;
    final bundle = stats.getOrCreateTodayEvents(statsData: s);
    final bangumiBundle = await stats.getOrCreateBangumiStats(statsDataImpl: s);
    final TodayEventBundle targetStats = bangumiBundle ?? bundle;

    statsDataImpl = bundle.statsData;
    todayComment = bundle.todayComment;
    commentRecord = targetStats.commentRecord;
    todayClick = bundle.todayClick;
    clickRecord = bundle.clickRecord;
    todayWatch = bundle.todayWatch;
    watchRecord = bundle.watchRecord;
    todayRating = bundle.todayRating;
    ratingRecord = targetStats.ratingRecord;
    ratingValue = ratingRecord?.rating ?? 0;
  }

  @override
  Widget buildLoading() {
    return _AnimePageLoadingPlaceHolder(
      cover: widget.cover,
      title: widget.title,
      sourceKey: widget.sourceKey,
      aid: widget.id,
      heroID: widget.heroID,
    );
  }

  @override
  void initState() {
    super.initState();
    updateStatsClicks();
    scrollController.addListener(onScroll);
    HistoryManager().addListener(updateHistory);
    providerContainer
        .read(bangumiManagerProvider)
        .addListener(updateBangumiBind);
    StatsManager().addListener(updateStats);
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  Future<void> onDataLoaded() async {
    if (history == null) {
      history = History.fromModel(model: data!);
      await HistoryManager().addHistory(history!);
    }
    if (history?.bangumiId != null) {
      updateBangumiBind();
    }
    history!.time = DateTime.now();
    await HistoryManager().addHistory(history!);
    watcherController.history = history;

    isBangumi = animeSource.isBangumi;
    if (history?.bangumiId == null) {
      debugPrint('isBangumi: $isBangumi');
      if (isBangumi) {
        updateBangumiId();
      }
    }
    isLiked = await stats.getGroupLikedStatus(
      id: data!.id,
      type: data!.sourceKey.hashCode,
    );
    if (history!.bangumiId != null) {
      Bangumi.instance.getBangumiInfoBind(history!.bangumiId as int);
    }
    await stats.updateStats(
      id: widget.id,
      type: widget.sourceKey.hashCode,
      bangumiId: history!.bangumiId,
    );
    await updateStats();
    watcherController.anime = data!;
    await initializeProgress();
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    HistoryManager().removeListener(updateHistory);
    providerContainer
        .read(bangumiManagerProvider)
        .removeListener(updateBangumiBind);
    StatsManager().removeListener(updateStats);
    Future.microtask(() {
      DataSync().onDataChanged();
    });
    scrollController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  void update() {
    setState(() {});
  }

  @override
  AnimeDetails get anime => data!;

  Future<void> updateBangumiId() async {
    if (Utils.containsIllegalCharacters(anime.title)) {
      Log.warning('updateBangumiId', '名称不合法: ${anime.title}');
      return;
    }
    var res = await Bangumi.instance.combinedBangumiSearch(anime.title);
    if (res.isEmpty) {
      debugPrint('res isEmpty');
      return;
    }

    bool matched =
        Utils.isHalfOverlap(anime.title, res.first.name) ||
        Utils.isHalfOverlap(anime.title, res.first.nameCn);

    if (!matched) {
      debugPrint(Utils.isHalfOverlap(anime.title, res.first.name).toString());
      debugPrint(Utils.isHalfOverlap(anime.title, res.first.nameCn).toString());
      Log.warning(
        'updateBangumiId',
        '名称不匹配: ${anime.title} - ${res.first.nameCn} - ${res.first.name}',
      );
      return;
    }

    history?.bangumiId = res.first.id;
    await HistoryManager().addHistory(history!);
  }

  void onScroll() {
    if (scrollController.offset > 250) {
      if (!showAppbarTitle) {
        setState(() {
          showAppbarTitle = true;
        });
      }
    } else {
      if (showAppbarTitle) {
        setState(() {
          showAppbarTitle = false;
        });
      }
    }
  }

  var isFirst = true;

  @override
  Widget buildContent(BuildContext context, AnimeDetails data) {
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = screenWidth > 800;
    final playerHeight = isDesktop ? screenWidth * 0.45 : screenWidth * 0.6;

    Widget widget = NestedScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverPersistentHeader(
            pinned: true,
            delegate: _VideoPlayerDelegate(
              playerHeight: playerHeight,
              topPadding: topPadding,
              watcher: Watcher(
                playerController: playerController,
                watcherController: watcherController,
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: tabController,
                isScrollable: true,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabAlignment: TabAlignment.center,
                tabs: [
                  Tab(text: t.basicInfo),
                  Tab(text: t.allEpisodes),
                  Tab(text: t.relatedEntries),
                ],
              ),
              Theme.of(context).colorScheme.surface,
            ),
          ),
        ];
      },
      body: animeTab(),
    );

    return widget;
  }

  @override
  Future<Res<AnimeDetails>> loadData() async {
    var animeSource = AnimeSource.find(widget.sourceKey);
    if (animeSource == null) {
      return const Res.error('Anime source not found');
    }
    isAddToLocalFav = LocalFavoritesManager().isExist(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    history = HistoryManager().find(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );

    return animeSource.loadAnimeInfo!(widget.id);
  }

  Widget animeTab() {
    return TabBarView(
      controller: tabController,
      physics: const BouncingScrollPhysics(),
      children: [
        CustomScrollView(
          slivers: [
            ...buildTitle(),
            buildComment(),
            buildDescription(),
            buildInfo(),
          ],
        ),
        buildEpisodes(),
        buildRecommend(),
      ],
    );
  }

  Iterable<Widget> buildTitle() sync* {
    yield const SliverPadding(padding: EdgeInsets.only(top: 8));

    yield SliverLazyToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bindAll = ref
                .watch(bangumiBindAllProvider)
                .when(
                  data: (data) => data,
                  loading: () => <BangumiItem>[],
                  error: (_, _) => <BangumiItem>[],
                );
            final bangumiItem = history?.bangumiId != null
                ? bindAll.firstWhereOrNull((e) => e.id == history!.bangumiId)
                : null;

            final maxImageWidth = constraints.maxWidth * 0.3;
            final calculatedHeight = maxImageWidth / 0.72;
            final imageHeight = math.min(calculatedHeight, 300.0);
            final imageWidth = imageHeight * 0.72;

            return SizedBox(
              width: constraints.maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.grey.toOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 16,
                      right: 16,
                      left: 16,
                      bottom: 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              (history?.bangumiId == null ||
                                      bangumiItem == null)
                                  ? BangumiWidget.showImagePreview(
                                      context: context,
                                      url: widget.cover ?? anime.cover,
                                      title: anime.title,
                                      heroTag: "cover${widget.heroID}",
                                    )
                                  : BangumiWidget.showImagePreview(
                                      context: context,
                                      url: bangumiItem.images['large']!,
                                      title: bangumiItem.nameCn,
                                      heroTag: "cover${widget.heroID}",
                                    );
                            },
                            child: Hero(
                              tag: "cover${widget.heroID}",
                              flightShuttleBuilder:
                                  (
                                    flightContext,
                                    animation,
                                    direction,
                                    fromContext,
                                    toContext,
                                  ) {
                                    return direction == HeroFlightDirection.pop
                                        ? (fromContext.widget as Hero).child
                                        : (toContext.widget as Hero).child;
                                  },
                              child: Container(
                                width: imageWidth,
                                height: imageHeight,
                                decoration: BoxDecoration(
                                  color: context.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colorScheme.outlineVariant,
                                      blurRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AnimatedImage(
                                  image: CachedImageProvider(
                                    widget.cover ?? anime.cover,
                                    sourceKey: anime.sourceKey,
                                    aid: anime.id,
                                  ),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: imageHeight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    var context =
                                        App.mainNavigatorKey!.currentContext!;
                                    context.to(
                                      () => AggregatedSearchPage(
                                        keyword: anime.title,
                                      ),
                                    );
                                  },
                                  onLongPress: () {
                                    Clipboard.setData(
                                      ClipboardData(text: anime.title),
                                    );
                                    App.rootContext.showMessage(
                                      message: t.copiedToClipboard,
                                    );
                                  },
                                  child: Text(
                                    anime.title,
                                    style: ts.s18,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (anime.subTitle != null)
                                  SelectableText(
                                    anime.subTitle!,
                                    style: ts.s14,
                                    maxLines: 2,
                                    scrollPhysics:
                                        const NeverScrollableScrollPhysics(),
                                  ).paddingVertical(4),
                                Text(
                                  AnimeSource.find(anime.sourceKey)?.name ?? '',
                                  style: ts.s12,
                                ),
                                const Spacer(),
                                if (bangumiItem != null)
                                  Align(
                                    child: Row(
                                      children: [
                                        Text(
                                          '${bangumiItem.collection?['doing']} 在看',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const Text(' / '),
                                        Text(
                                          '${bangumiItem.collection?['collect']} 看过',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                        const Text(' / '),
                                        Text(
                                          '${bangumiItem.collection?['dropped']} 抛弃',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (bangumiItem != null)
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${bangumiItem.score}',
                                          style: ts.s24,
                                        ),
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.all(2.0),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer
                                                  .toOpacity(0.72),
                                              width: 2.0,
                                            ),
                                          ),
                                          child: Text(
                                            Utils.getRatingLabel(
                                              bangumiItem.score,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            RatingBarIndicator(
                                              itemCount: 5,
                                              rating:
                                                  bangumiItem.score.toDouble() /
                                                  2,
                                              itemBuilder: (context, index) =>
                                                  const Icon(
                                                    Icons.star_rounded,
                                                  ),
                                              itemSize: 20.0,
                                            ),
                                            Text(
                                              t.tReviewsR(
                                                t: bangumiItem.total,
                                                r: bangumiItem.rank,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                SizedBox(
                                  height: 45,
                                  child: _buildActionButtons(
                                    context,
                                    anime,
                                    true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      height: 45,
                      child: _buildActionButtons(context, anime, false),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    AnimeDetails anime,
    bool isZero,
  ) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        if (isZero)
          _ActionButton(
            icon: const Icon(Icons.star_border_rounded),
            activeIcon: const Icon(Icons.star_rounded),
            isActive: isFavorite || isAddToLocalFav,
            text: t.favorite,
            onPressed: openFavPanel,
            onLongPressed: quickFavorite,
            iconColor: context.useTextColor(Colors.purple),
          ),
        if (isZero)
          _ActionButton(
            icon: const Icon(Icons.share),
            text: t.share,
            onPressed: share,
            onLongPressed: () => showKostoriShareSheet(
              context,
              ref,
              type: KostoriRouteType.anime,
              payload: '${widget.id}|${widget.sourceKey}',
              title: anime.title,
              subtitle: widget.sourceKey,
              backgroundImagePath: anime.cover,
            ),
            iconColor: Theme.of(context).colorScheme.inversePrimary,
          ),
        if (!isZero)
          _ActionButton(
            icon: const Icon(Icons.favorite_border),
            activeIcon: const Icon(Icons.favorite),
            isActive: isLiked,
            text: t.liked,
            onPressed: () {
              liked();
              setState(() {
                isLiked = !isLiked;
              });
              if (isLiked) {
                App.rootContext.showMessage(message: t.likeSuccess);
              } else {
                App.rootContext.showMessage(message: t.unlikeSuccess);
              }
            },
            iconColor: Colors.redAccent,
          ),
        if (!isZero)
          _ActionButton(
            icon: (ratingValue != 0)
                ? Row(
                    children: [
                      Text(Utils.getRatingLabel(ratingValue ?? 0)),
                      SizedBox(width: 4),
                      RatingBarIndicator(
                        itemCount: 5,
                        rating: ratingValue!.toDouble() / 2,
                        itemBuilder: (context, index) =>
                            const Icon(Icons.star_rounded),
                        itemSize: 20.0,
                      ),
                    ],
                  )
                : const Icon(Icons.comment),
            text: (ratingValue == 0) ? t.rating : '',
            onPressed: () async {
              await showRatingDialog(statsDataImpl!).then((_) {
                setState(() {});
              });
            },
            iconColor: Theme.of(context).colorScheme.primary,
          ),
        if (!isZero)
          _ActionButton(
            icon: ClipOval(
              child: SizedBox(
                width: 24,
                height: 24,
                child: SvgPicture.asset(
                  'assets/img/bangumi_icon.svg',
                  fit: BoxFit.fill,
                ),
              ),
            ),
            text: t.bangumi,
            onPressed: () async {
              bangumiBottomInfo(context);
            },
            // iconColor: context.useTextColor(Colors.blue),
          ),
        if (anime.url != null && !isZero)
          _ActionButton(
            icon: const Icon(Icons.open_in_browser),
            text: t.openInBrowser,
            onPressed: () => launchUrlString(anime.url!),
            iconColor: Theme.of(context).colorScheme.secondary,
          ),
      ],
    ).fixHeight(48);
  }

  Widget buildComment() {
    if (commentRecord == null || commentRecord!.comment!.isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Container(
                  width: 120,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.toOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(title: Text(t.myRating)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                commentRecord!.comment!,
              ).fixWidth(double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDescription() {
    if (anime.description == null || anime.description!.trim().isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Container(
                  width: 120,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.toOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            TranslationWidget(
              data: anime.description!,
              title: ListTile(title: Text(t.description)),
            ),
          ],
        ),
      ),
    );
  }

  bool isTagsEmpty() {
    if (anime.tags.isEmpty) return true;
    return anime.tags.values.every((list) => list.isEmpty);
  }

  Widget buildInfo() {
    if (isTagsEmpty()) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }

    int i = 0;

    Widget buildTag({
      required String text,
      VoidCallback? onTap,
      bool isTitle = false,
    }) {
      Color color;
      if (isTitle) {
        const colors = [
          Colors.blue,
          Colors.cyan,
          Colors.red,
          Colors.pink,
          Colors.purple,
          Colors.indigo,
          Colors.teal,
          Colors.green,
          Colors.lime,
          Colors.yellow,
        ];
        color = context.useBackgroundColor(colors[(i++) % (colors.length)]);
      } else {
        color = context.colorScheme.surfaceContainerLow;
      }

      final borderRadius = BorderRadius.circular(12);

      const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 6);

      if (onTap != null) {
        return Material(
          color: color,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: text));
              context.showMessage(message: t.copied);
            },
            onSecondaryTapDown: (details) {
              showMenuX(context, details.globalPosition, [
                MenuEntry(
                  icon: Icons.remove_red_eye,
                  text: t.view,
                  onClick: onTap,
                ),
                MenuEntry(
                  icon: Icons.copy,
                  text: t.copy,
                  onClick: () {
                    Clipboard.setData(ClipboardData(text: text));
                    context.showMessage(message: t.copied);
                  },
                ),
              ]);
            },
            child: Text(text).padding(padding),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(color: color, borderRadius: borderRadius),
          child: Text(text).padding(padding),
        );
      }
    }

    Widget buildWrap({required List<Widget> children}) {
      return Wrap(
        runSpacing: 8,
        spacing: 8,
        children: children,
      ).paddingHorizontal(16).paddingBottom(8);
    }

    return SliverToBoxAdapter(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Container(
                  width: 120,
                  height: 2,
                  decoration: BoxDecoration(
                    color: Colors.grey.toOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(title: Text(t.information)),
            if (anime.stars != null)
              Row(
                children: [
                  StarRating(
                    value: anime.stars!,
                    size: 24,
                    // onTap: starRating,
                  ),
                  const SizedBox(width: 8),
                  Text(anime.stars!.toStringAsFixed(2)),
                ],
              ).paddingLeft(16).paddingVertical(8),
            for (var e in anime.tags.entries)
              buildWrap(
                children: [
                  if (e.value.isNotEmpty)
                    buildTag(text: e.key.ts(animeSource.key), isTitle: true),
                  for (var tag in e.value)
                    buildTag(text: tag, onTap: () => onTapTag(tag, e.key)),
                ],
              ),
            if (anime.uploader != null)
              buildWrap(
                children: [
                  buildTag(text: t.uploader, isTitle: true),
                  buildTag(text: anime.uploader!),
                ],
              ),
            if (anime.uploadTime != null)
              buildWrap(
                children: [
                  buildTag(text: t.uploadTime, isTitle: true),
                  buildTag(text: anime.uploadTime!),
                ],
              ),
            if (anime.updateTime != null)
              buildWrap(
                children: [
                  buildTag(text: t.updateTime, isTitle: true),
                  buildTag(text: anime.updateTime!),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget buildEpisodes() {
    if (anime.episode == null) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [_AnimeEpisodes(history: history)],
    );
  }

  Widget buildRecommend() {
    if (anime.recommend == null || anime.recommend!.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.grey.toOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(title: Text(t.related)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final crossAxisCount = screenWidth < 800 ? 3 : 4;
                      return SliverGridAnimes(
                        animes: anime.recommend!,
                        isRecommend: true,
                        asSliver: false,
                        shrinkWrap: true,
                        crossAxisCount: crossAxisCount,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.onLongPressed,
    this.activeIcon,
    this.isActive,
    this.iconColor,
    this.isLoading,
  });

  final Widget icon;

  final Widget? activeIcon;

  final bool? isActive;

  final String text;

  final void Function() onPressed;

  final bool? isLoading;

  final Color? iconColor;

  final void Function()? onLongPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colorScheme.outlineVariant,
          width: 0.6,
        ),
      ),
      child: Tooltip(
        message: text,
        child: InkWell(
          onTap: () {
            if (!(isLoading ?? false)) {
              onPressed();
            }
          },
          onLongPress: onLongPressed,
          borderRadius: BorderRadius.circular(18),
          child: IconTheme.merge(
            data: IconThemeData(size: 20, color: iconColor),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading ?? false)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                else
                  (isActive ?? false) ? (activeIcon ?? icon) : icon,
              ],
            ).paddingHorizontal(16),
          ),
        ),
      ),
    );
  }
}

class _AnimePageLoadingPlaceHolder extends StatelessWidget {
  const _AnimePageLoadingPlaceHolder({
    this.cover,
    this.title,
    required this.sourceKey,
    required this.aid,
    this.heroID,
  });

  final String? cover;

  final String? title;

  final String sourceKey;

  final String aid;

  final int? heroID;

  @override
  Widget build(BuildContext context) {
    Widget buildContainer(
      double? width,
      double? height, {
      Color? color,
      double? radius,
    }) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color ?? context.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius ?? 4),
        ),
      );
    }

    return Shimmer(
      color: context.isDarkMode ? Colors.grey.shade700 : Colors.white,
      child: Column(
        children: [
          buildVideoPlaceholder(context),
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              buildImage(context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(title ?? "", style: ts.s18)
                    else
                      buildContainer(200, 25),
                    const SizedBox(height: 8),
                    buildContainer(80, 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildVideoPlaceholder(BuildContext context) {
    final double aspectRatioMultiplier = App.isDesktop ? 0.45 : 0.6;
    final double maxWidth = MediaQuery.of(context).size.width;
    final double maxHeight = maxWidth * aspectRatioMultiplier;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(App.isDesktop ? 16.0 : 8.0),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
          color: Colors.black,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: KostoriRefreshIndicator(),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildImage(BuildContext context) {
    Widget child;
    if (cover != null) {
      child = AnimatedImage(
        image: CachedImageProvider(cover!, sourceKey: sourceKey, aid: aid),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      child = const SizedBox();
    }

    return Hero(
      tag: "cover$heroID",
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.outlineVariant,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        height: 144,
        width: 144 * 0.72,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar, this._backgroundColor);

  final TabBar _tabBar;
  final Color _backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: _backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class _VideoPlayerDelegate extends SliverPersistentHeaderDelegate {
  _VideoPlayerDelegate({
    required this.playerHeight,
    required this.topPadding,
    required this.watcher,
  });

  final double playerHeight;
  final double topPadding;
  final Widget watcher;

  @override
  double get minExtent => topPadding + playerHeight;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: topPadding + playerHeight,
      child: Column(
        children: [
          Container(
            height: topPadding,
            color: Theme.of(context).colorScheme.surface,
          ),
          Expanded(child: watcher),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_VideoPlayerDelegate oldDelegate) {
    return playerHeight != oldDelegate.playerHeight ||
        topPadding != oldDelegate.topPadding ||
        watcher != oldDelegate.watcher;
  }
}
