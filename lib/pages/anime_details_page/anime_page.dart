// ignore_for_file: unused_element_parameter

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/misc_components.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:url_launcher/url_launcher_string.dart';

part 'actions.dart';

part 'episodes.dart';

part 'favorite.dart';

class AnimePage extends StatefulWidget {
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
  State<AnimePage> createState() => _AnimePageState();
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
    var newHistory = HistoryManager().find(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );
    if (newHistory?.lastWatchEpisode != history?.lastWatchEpisode ||
        newHistory?.lastWatchTime != history?.lastWatchTime) {
      history = newHistory;

      update();
    }
  }

  void updateBangumiBind() async {
    if (history?.bangumiId != null) {
      bangumiBindInfo = await BangumiManager().bindFind(
        history!.bangumiId as int,
      );
      update();
    }
  }

  Future<void> updateStatsClicks() async {
    if (!stats.isExist(widget.id, AnimeType(widget.sourceKey.hashCode))) {
      try {
        stats.addStats(
          stats.createStatsData(
            id: widget.id,
            title: widget.title,
            cover: widget.cover,
            type: widget.sourceKey.hashCode,
          ),
        );
      } catch (e) {
        Log.addLog(LogLevel.error, 'addStats', e.toString());
      }
    }

    final (statsDataImpl, todayClick, platformRecord) = stats
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
    final s = stats.getOrCreateTodayEvents(
      id: widget.id,
      type: widget.sourceKey.hashCode,
    );
    final bangumiStats = stats.getOrCreateBangumiStats(
      statsDataImpl: s.statsData,
    );
    final TodayEventBundle targetStats = bangumiStats ?? s;

    statsDataImpl = s.statsData;
    todayComment = s.todayComment;
    commentRecord = targetStats.commentRecord;

    todayClick = s.todayClick;
    clickRecord = s.clickRecord;

    todayWatch = s.todayWatch;
    watchRecord = s.watchRecord;

    todayRating = s.todayRating;
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
    updateStatsClicks();
    scrollController.addListener(onScroll);
    HistoryManager().addListener(updateHistory);
    BangumiManager().addListener(updateBangumiBind);
    StatsManager().addListener(updateStats);
    tabController = TabController(length: 3, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });
    super.initState();
  }

  @override
  Future<void> onDataLoaded() async {
    if (history == null) {
      history = History.fromModel(model: data!);
      HistoryManager().addHistory(history!);
    }
    history!.time = DateTime.now();
    HistoryManager().addHistoryAsync(history!);
    watcherController.history = history;

    isBangumi = animeSource.isBangumi;
    if (history?.bangumiId == null) {
      debugPrint('isBangumi是: $isBangumi');
      if (isBangumi) {
        updateBangumiId();
      }
    }
    isLiked = stats.getGroupLikedStatus(
      id: data!.id,
      type: data!.sourceKey.hashCode,
    );
    if (history!.bangumiId != null) {
      Bangumi.getBangumiInfoBind(history!.bangumiId as int);
    }
    stats.updateStats(
      id: widget.id,
      type: widget.sourceKey.hashCode,
      bangumiId: history!.bangumiId,
    );
    watcherController.anime = data!;
  }

  @override
  void dispose() {
    scrollController.removeListener(onScroll);
    HistoryManager().removeListener(updateHistory);
    BangumiManager().removeListener(updateBangumiBind);
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
      Log.addLog(LogLevel.warning, 'updateBangumiId', '名称不合法: ${anime.title}');
      return;
    }
    var res = await Bangumi.combinedBangumiSearch(anime.title);
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
      Log.addLog(
        LogLevel.warning,
        'updateBangumiId',
        '名称不匹配: ${anime.title} - ${res.first.nameCn} - ${res.first.name}',
      );
      return;
    }

    history?.bangumiId = res.first.id;
    HistoryManager().addHistoryAsync(history!);
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
    Widget widget = Stack(
      children: [
        Positioned.fill(
          child: NestedScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverPadding(padding: EdgeInsets.only(top: 28)),
                Watcher(
                  playerController: playerController,
                  watcherController: watcherController,
                ),
                TabBar(
                  controller: tabController,
                  isScrollable: true,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: '基本信息'.tl),
                    Tab(text: '全部剧集'.tl),
                    Tab(text: '关联条目'.tl),
                  ],
                ).toSliver(),
              ];
            },
            body: animeTab(),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          top: showAppbarTitle ? 0 : -(40 + context.padding.top),
          left: 0,
          right: 0,
          height: 40 + context.padding.top,
          child: buildTop(),
        ),
      ],
    );
    widget = AppScrollBar(
      topPadding: MediaQuery.of(context).padding.top,
      controller: scrollController,
      isNested: true,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
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
        CustomScrollView(slivers: [buildEpisodes()]),
        CustomScrollView(slivers: [buildRecommend()]),
      ],
    );
  }

  Widget buildTop() {
    return BlurEffect(
      child: Container(
        padding: EdgeInsets.only(top: context.padding.top),
        decoration: BoxDecoration(
          color: context.colorScheme.surface.toOpacity(0.82),
          border: Border(
            bottom: BorderSide(color: Colors.grey.toOpacity(0.5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Tooltip(
              message: "Back".tl,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                anime.title,
                style: ts.s18,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> buildTitle() sync* {
    yield const SliverPadding(padding: EdgeInsets.only(top: 8));

    yield SliverLazyToBoxAdapter(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 345 + 16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxImageWidth = constraints.maxWidth * 0.3;
            final calculatedHeight = maxImageWidth / 0.72;
            final imageHeight = math.min(calculatedHeight, 300.0);
            final imageWidth = imageHeight * 0.72;

            return SizedBox(
              width: constraints.maxWidth,
              height: imageHeight + 45 + 16,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 16),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            (history?.bangumiId == null || bangumiItem == null)
                                ? BangumiWidget.showImagePreview(
                                    context,
                                    anime.cover,
                                    anime.title,
                                    "cover${widget.heroID}",
                                  )
                                : BangumiWidget.showImagePreview(
                                    context,
                                    bangumiItem!.images['large']!,
                                    bangumiItem!.nameCn,
                                    "cover${widget.heroID}",
                                  );
                          },
                          child: Hero(
                            tag: "cover${widget.heroID}",
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
                                    message: '已复制到剪贴板.',
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
                                        '${bangumiItem?.collection?['doing']} 在看',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      Text(' / '),
                                      Text(
                                        '${bangumiItem?.collection?['collect']} 看过',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                        ),
                                      ),
                                      Text(' / '),
                                      Text(
                                        '${bangumiItem?.collection?['dropped']} 抛弃',
                                        style: TextStyle(
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
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${bangumiItem?.score}',
                                        style: ts.s24,
                                      ),
                                      SizedBox(width: 5),
                                      Container(
                                        padding: EdgeInsets.all(
                                          2.0,
                                        ), // 可选，设置内边距
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
                                            bangumiItem!.score,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start, // 右对齐
                                        children: [
                                          RatingBarIndicator(
                                            itemCount: 5,
                                            rating:
                                                bangumiItem!.score.toDouble() /
                                                2,
                                            itemBuilder: (context, index) =>
                                                const Icon(Icons.star_rounded),
                                            itemSize: 20.0,
                                          ),
                                          Text(
                                            '@t reviews | #@r'.tlParams({
                                              'r': bangumiItem!.rank,
                                              't': bangumiItem!.total,
                                            }),
                                            style: TextStyle(fontSize: 12),
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
            text: 'Favorite'.tl,
            onPressed: openFavPanel,
            onLongPressed: quickFavorite,
            iconColor: context.useTextColor(Colors.purple),
          ),
        if (isZero)
          _ActionButton(
            icon: const Icon(Icons.share),
            text: 'Share'.tl,
            onPressed: share,
            iconColor: Theme.of(context).colorScheme.inversePrimary,
          ),
        if (!isZero)
          _ActionButton(
            icon: const Icon(Icons.favorite_border),
            activeIcon: const Icon(Icons.favorite),
            isActive: isLiked,
            text: 'Liked'.tl,
            onPressed: () {
              liked();
              setState(() {
                isLiked = !isLiked;
              });
              if (isLiked) {
                App.rootContext.showMessage(message: '点赞成功');
              } else {
                App.rootContext.showMessage(message: '取消点赞');
              }
            },
            iconColor: Colors.redAccent,
          ),
        if (!isZero)
          _ActionButton(
            icon: (ratingValue != 0)
                ? Row(
                    children: [
                      Text(Utils.getRatingLabel(ratingValue as int)),
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
            text: (ratingValue == 0) ? 'Rating'.tl : '',
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
            text: 'Bangumi'.tl,
            onPressed: () async {
              bangumiBottomInfo(context);
            },
            // iconColor: context.useTextColor(Colors.blue),
          ),
        if (anime.url != null && !isZero)
          _ActionButton(
            icon: const Icon(Icons.open_in_browser),
            text: 'Open in Browser'.tl,
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
      child: Column(
        children: [
          const SizedBox(height: 16),
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
          ListTile(title: Text("我的评价".tl)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(
              commentRecord!.comment!,
            ).fixWidth(double.infinity),
          ),
        ],
      ),
    );
  }

  Widget buildDescription() {
    if (anime.description == null || anime.description!.trim().isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const SizedBox(height: 16),
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
          ListTile(title: Text("Description".tl)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SelectableText(anime.description!),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget buildInfo() {
    if (anime.tags.isEmpty &&
        anime.uploader == null &&
        anime.uploadTime == null &&
        anime.uploadTime == null) {
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
              context.showMessage(message: "Copied".tl);
            },
            onSecondaryTapDown: (details) {
              showMenuX(context, details.globalPosition, [
                MenuEntry(
                  icon: Icons.remove_red_eye,
                  text: "View".tl,
                  onClick: onTap,
                ),
                MenuEntry(
                  icon: Icons.copy,
                  text: "Copy".tl,
                  onClick: () {
                    Clipboard.setData(ClipboardData(text: text));
                    context.showMessage(message: "Copied".tl);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(title: Text("Information".tl)),
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
                buildTag(text: 'Uploader'.tl, isTitle: true),
                buildTag(text: anime.uploader!),
              ],
            ),
          if (anime.uploadTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Upload Time'.tl, isTitle: true),
                buildTag(text: anime.uploadTime!),
              ],
            ),
          if (anime.updateTime != null)
            buildWrap(
              children: [
                buildTag(text: 'Update Time'.tl, isTitle: true),
                buildTag(text: anime.updateTime!),
              ],
            ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget buildEpisodes() {
    if (anime.episode == null) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return _AnimeEpisodes(history: history);
  }

  Widget buildRecommend() {
    if (anime.recommend == null || anime.recommend!.isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: ListTile(title: Text("Related".tl))),
        SliverGridAnimes(animes: anime.recommend!, isRecommend: true),
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
              const SizedBox(width: 8),
              Text(text),
            ],
          ).paddingHorizontal(16),
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
                child: MiscComponents.placeholder(
                  context,
                  50,
                  50,
                  Colors.transparent,
                ),
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
