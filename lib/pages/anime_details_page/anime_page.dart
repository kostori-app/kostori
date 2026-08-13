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
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/anime_details_page/watch_together_page.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
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
  bool isDownloaded = false;
  bool isBangumi = false;

  final stats = StatsManager();

  BangumiItem? get bangumiItem => bangumiBindInfo;
  late TabController tabController;

  // 各 Tab 的滚动控制器，供 AppScrollBar 使用
  final ScrollController infoScrollCtrl = ScrollController();
  final ScrollController episodesScrollCtrl = ScrollController();
  final ScrollController recommendScrollCtrl = ScrollController();

  void updateHistory() {
    // 读缓存而非查库：避免每秒查库与后台写入锁冲突导致卡顿
    final cached = HistoryManager().cachedHistories[widget.id];
    if (cached == null) return;
    // 只在集数变化时刷新 UI（lastWatchTime 每秒变，无需每秒 rebuild）
    if (cached.lastWatchEpisode != history?.lastWatchEpisode) {
      history = cached;
      if (mounted) update();
    } else {
      history = cached;
    }
  }

  Future<void> updateStatsClicks() async {
    if (!mounted) return;
    try {
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
      if (!mounted) return;

      final (statsDataImpl, todayClick, platformRecord) = await stats
          .getOrCreateTodayPlatformRecord(
            id: widget.id,
            type: widget.sourceKey.hashCode,
            targetType: DailyEventType.click,
          );
      if (!mounted) return;
      final now = DateTime.now();
      platformRecord.value += 1;
      platformRecord.date = now;
      statsDataImpl.lastClickTime = now;
      await stats.addStats(statsDataImpl);
    } catch (e) {
      // 数据库可能已关闭（应用退出等），忽略该次统计
      StatsLog.error('updateStatsClicks', e.toString());
    }
  }

  Future<void> updateStats() async {
    if (!mounted) return;
    try {
      final s = await stats.getStatsByIdAndType(
        id: widget.id,
        type: widget.sourceKey.hashCode,
      );
      if (!mounted) return;
      if (s == null) return;
      final bundle = stats.getOrCreateTodayEvents(statsData: s);
      final bangumiBundle = await stats.getOrCreateBangumiStats(
        statsDataImpl: s,
      );
      if (!mounted) return;
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
    } catch (e) {
      // 数据库可能已关闭（应用退出等），忽略该次刷新
      StatsLog.error('updateStats', e.toString());
    }
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
    HistoryManager().addListener(updateHistory);
    providerContainer
        .read(bangumiManagerProvider)
        .addListener(updateBangumiBind);
    StatsManager().addListener(updateStats);
    tabController = TabController(length: 5, vsync: this);
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
      DebugLog.info('onDataLoaded', 'isBangumi: $isBangumi');
      if (isBangumi) {
        updateBangumiId();
      }
    }
    isLiked = await stats.getGroupLikedStatus(
      id: data!.id,
      type: data!.sourceKey.hashCode,
    );
    if (history!.bangumiId != null) {
      // 拉取绑定番剧信息并刷新（updateBangumiBind 内含 bindFind → 本地库/网络）
      await updateBangumiBind();
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
    HistoryManager().removeListener(updateHistory);
    providerContainer
        .read(bangumiManagerProvider)
        .removeListener(updateBangumiBind);
    StatsManager().removeListener(updateStats);
    Future.microtask(() {
      DataSync().onDataChanged();
    });
    tabController.dispose();
    infoScrollCtrl.dispose();
    episodesScrollCtrl.dispose();
    recommendScrollCtrl.dispose();
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
    // 绑定后立即刷新当前页的番剧信息，否则要重新点开详情页才显示
    if (mounted) {
      await updateBangumiBind();
    }
  }

  var isFirst = true;

  /// 桌面端用 Clamping（不允许拖出过长空白），移动端保留弹性
  ScrollPhysics get _tabPhysics => App.isDesktop
      ? const ClampingScrollPhysics()
      : const BouncingScrollPhysics();

  @override
  Widget buildContent(BuildContext context, AnimeDetails data) {
    // 一起看成员锁定：强制 1 倍速 / 禁拖动进度 / 禁切集。
    // 放在始终激活的 AnimePage 层，避免依赖"一起看"tab 是否被构建。
    ref.listen(hubProvider, (prev, next) {
      final room = next.currentRoom;
      final anime = watcherController.anime;
      final roomMatchesAnime =
          room == null ||
          room.animeId == null ||
          room.animeSourceKey == null ||
          (anime != null &&
              room.animeId == anime.id &&
              room.animeSourceKey == anime.sourceKey);
      final isWatchMember =
          next.isConnected &&
          room != null &&
          room.roomId != next.lobbyRoomId &&
          room.isWatchRoom &&
          room.ownerUserId != next.myId &&
          roomMatchesAnime;
      // 在房间（含房主）都锁定倍速；成员再额外锁定进度/切集
      final inWatchRoom =
          next.isConnected &&
          room != null &&
          room.roomId != next.lobbyRoomId &&
          room.isWatchRoom &&
          roomMatchesAnime;
      DebugLog.info(
        'AnimePage',
        'watchLock: member=$isWatchMember inRoom=$inWatchRoom '
            'connected=${next.isConnected} roomId=${room?.roomId} '
            'type=${room?.roomType} owner=${room?.ownerUserId} '
            'myId=${next.myId} '
            'roomAnime=${room?.animeId}/${room?.animeSourceKey} '
            'cur=${anime?.id}/${anime?.sourceKey}',
      );
      playerController.speedLocked = inWatchRoom;
      playerController.syncLocked = isWatchMember;
      playerController.inRoom = inWatchRoom;
      if (inWatchRoom) {
        playerController.setPlaybackSpeed(1);
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = screenWidth > 800;
    final playerHeight = isDesktop ? screenWidth * 0.35 : screenWidth * 0.6;

    // 固定布局：视频头 + TabBar 固定在上方，剩余空间交给 Tab 内容。
    // 不再用 NestedScrollView（视频头固定不折叠），避免 Tab 内容重叠在
    // SliverPersistentHeader 下方、以及"内容很少却还能滚动很远"的问题。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: topPadding + playerHeight,
          child: Column(
            children: [
              Container(
                height: topPadding,
                color: Theme.of(context).colorScheme.surface,
              ),
              Expanded(
                child: Watcher(
                  playerController: playerController,
                  watcherController: watcherController,
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: t.basicInfo),
              Tab(text: t.allEpisodes),
              Tab(text: t.relatedEntries),
              Tab(text: t.imageOperations),
              Tab(text: t.watchTogether),
            ],
          ),
        ),
        Expanded(child: animeTab()),
      ],
    );
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
    history = await HistoryManager().findAsync(
      widget.id,
      AnimeType(widget.sourceKey.hashCode),
    );

    return animeSource.loadAnimeInfo!(widget.id);
  }

  Widget animeTab() {
    return TabBarView(
      controller: tabController,
      physics: _tabPhysics,
      children: [
        AppScrollBar(
          controller: infoScrollCtrl,
          child: CustomScrollView(
            controller: infoScrollCtrl,
            physics: _tabPhysics,
            slivers: [
              ...buildTitle(),
              buildComment(),
              buildDescription(),
              buildInfo(),
            ],
          ),
        ),
        buildEpisodes(),
        buildRecommend(),
        buildImageOps(),
        buildWatchTogether(),
      ],
    );
  }

  /// 图片操作 Tab：仅图片操作内容（嵌入模式，无返回按钮）
  Widget buildImageOps() {
    return ImageManipulationBody(embedded: true);
  }

  /// 一起看 Tab：嵌入 hub 房间模块（内嵌聊天 + 房主进度同步）
  Widget buildWatchTogether() {
    return WatchTogetherPage(
      animeTitle: anime.title,
      playerController: playerController,
      watcherController: watcherController,
      onOpenBangumiInfo: () => bangumiBottomInfo(context),
    );
  }

  Iterable<Widget> buildTitle() sync* {
    yield SliverLazyToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                child:
                                    widget.cover != null ||
                                        anime.cover.isNotEmpty
                                    ? AnimatedImage(
                                        image: CachedImageProvider(
                                          widget.cover ?? anime.cover,
                                          sourceKey: anime.sourceKey,
                                          aid: anime.id,
                                        ),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      )
                                    : SizedBox(),
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
                                          t.animeWatchingCount(
                                            n:
                                                bangumiItem
                                                    .collection?['doing'] ??
                                                0,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                        const Text(' / '),
                                        Text(
                                          t.animeCompletedCount(
                                            n:
                                                bangumiItem
                                                    .collection?['collect'] ??
                                                0,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                        const Text(' / '),
                                        Text(
                                          t.animeDroppedCount(
                                            n:
                                                bangumiItem
                                                    .collection?['dropped'] ??
                                                0,
                                          ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
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
        final colors = standardColorMap.keys.toList();
        color = context.useBackgroundColor(colors[(i++) % (colors.length)]);
      } else {
        color = context.colorScheme.surfaceContainerHighest;
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(title: Text(t.information)),
            for (var e in anime.tags.entries)
              buildWrap(
                children: [
                  if (e.value.isNotEmpty)
                    buildTag(text: e.key.ts(animeSource.key), isTitle: true),
                  for (var tag in e.value)
                    buildTag(text: tag, onTap: () => onTapTag(tag, e.key)),
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
    return AppScrollBar(
      controller: episodesScrollCtrl,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: _tabPhysics,
        controller: episodesScrollCtrl,
        children: [_AnimeEpisodes(history: history)],
      ),
    );
  }

  Widget buildRecommend() {
    if (anime.recommend == null || anime.recommend!.isEmpty) {
      return const SizedBox.shrink();
    }
    // 过滤掉当前番剧自己，避免推荐列表与顶部封面产生重复 Hero tag
    final recommend = anime.recommend!
        .where((a) => !(a.id == widget.id && a.sourceKey == widget.sourceKey))
        .toList();
    if (recommend.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppScrollBar(
      controller: recommendScrollCtrl,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: _tabPhysics,
        controller: recommendScrollCtrl,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text(t.related)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final crossAxisCount = screenWidth < 800 ? 3 : 8;
                        return SliverGridAnimes(
                          animes: recommend,
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
      ),
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

    // 骨架屏不参与 Hero 转场（避免与真实内容的 Hero tag 冲突导致
    // "multiple heroes share the same tag"），加载完成后由真实 Hero 接管
    return Container(
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
    );
  }
}
