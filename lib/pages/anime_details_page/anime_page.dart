// ignore_for_file: unused_element_parameter, prefer_final_fields

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
import 'package:kostori/components/js_ui.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_play_result.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/audio_service/audio_service_manager.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/init.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/network/cloudflare.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/anime_details_page/watch_together_page.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/download/download_page.dart';
import 'package:kostori/pages/favorites/favorites_page.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/download/download_task.dart';
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
    this.heroTag,
  });

  final String id;

  final String sourceKey;

  final String? cover;

  final String? title;

  final int? heroID;

  /// 唯一 Hero tag（跨列表唯一，匹配点击来源的封面动画）
  final String? heroTag;

  @override
  ConsumerState<AnimePage> createState() => _AnimePageState();
}

class _AnimePageState extends LoadingState<AnimePage, AnimeDetails>
    with _AnimePageActions, TickerProviderStateMixin {
  bool showAppbarTitle = false;
  bool isDownloaded = false;
  bool isBangumi = false;

  /// 当前生效的源 key / 条目 id：支持页内切换播放源（聚合源）。
  /// 初始为进入时的源，切换后更新并重新加载详情
  late String _sourceKey = widget.sourceKey;
  late String _animeId = widget.id;

  /// 切换源后要继承播放的集（新源数据加载完成后播放该集）
  int? _pendingEpisode;

  /// 系列模式缓存：跨 episodes 重建保留，避免每次进入"全部剧集"重新加载
  List<Anime>? _seriesListCache;

  final stats = StatsManager();

  BangumiItem? get bangumiItem => bangumiBindInfo;
  late TabController tabController;

  /// 播放器 Watcher 的 GlobalKey：宽屏/窄屏布局切换时保持 State 不被重建，
  /// 避免播放器（media_kit Player）被 dispose 后仍被异步操作访问。
  final GlobalKey<State<Watcher>> watcherKey = GlobalKey<State<Watcher>>();

  // 各 Tab 的滚动控制器，供 AppScrollBar 使用
  final ScrollController infoScrollCtrl = ScrollController();
  final ScrollController episodesScrollCtrl = ScrollController();
  final ScrollController recommendScrollCtrl = ScrollController();

  // 封面图 provider 缓存：buildTitle 每次 build 都新建 CachedImageProvider，
  // 虽然 ImageCache 按 key 命中不重新下载，但避免每次都重复 resolve 的开销
  String? _coverCacheUrl;
  CachedImageProvider? _coverCacheProvider;

  CachedImageProvider _coverProvider(String url) {
    if (_coverCacheUrl != url || _coverCacheProvider == null) {
      _coverCacheProvider = CachedImageProvider(
        url,
        sourceKey: anime.sourceKey,
        aid: anime.id,
      );
      _coverCacheUrl = url;
    }
    return _coverCacheProvider!;
  }

  void updateHistory() {
    // 读缓存而非查库：避免每秒查库与后台写入锁冲突导致卡顿
    final cached = HistoryManager().cachedHistories[_animeId];
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
        _animeId,
        AnimeType(_sourceKey.hashCode),
      )) {
        try {
          await stats.addStats(
            stats.createStatsData(
              id: _animeId,
              title: widget.title,
              cover: widget.cover,
              type: _sourceKey.hashCode,
            ),
          );
        } catch (e) {
          StatsLog.error('addStats', e.toString());
        }
      }
      if (!mounted) return;

      final (statsDataImpl, todayClick, platformRecord) = await stats
          .getOrCreateTodayPlatformRecord(
            id: _animeId,
            type: _sourceKey.hashCode,
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
        id: _animeId,
        type: _sourceKey.hashCode,
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
      sourceKey: _sourceKey,
      aid: _animeId,
      heroTag: widget.heroTag,
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
    // 先更新播放器数据源：后续步骤即使失败，watcher 也能用新源刷新
    watcherController.anime = data;
    if (history == null) {
      history = History.fromModel(model: data!);
      // 详情接口未返回 cover 时，回退用入口 cover（来自列表卡片），
      // 避免历史记录里封面为空
      if (history!.cover.isEmpty &&
          widget.cover != null &&
          widget.cover!.isNotEmpty) {
        history!.cover = widget.cover!;
      }
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
      id: _animeId,
      type: _sourceKey.hashCode,
      bangumiId: history!.bangumiId,
    );
    await updateStats();
    watcherController.anime = data!;
    await initializeProgress();

    // 切换源：新源数据加载完成后，播放继承的集（原集数）。
    // retry 期间 watcher 会被卸载重建（currentState 为 null），
    // 需等 buildContent 构建完 watcher 后再播放
    if (_pendingEpisode != null) {
      final ep = _pendingEpisode!;
      _pendingEpisode = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          playerController.playEpisode(ep, 0);
        }
      });
    }

    // 查询下载状态（是否已下载，用于下载按钮显示）
    final records = await DownloadManager.recordsFor(
      _animeId,
      _sourceKey,
    );
    if (mounted && records.isNotEmpty != isDownloaded) {
      setState(() => isDownloaded = records.isNotEmpty);
    }
  }

  @override
  void dispose() {
    // 退出页面时清除媒体会话通知（clearController→stop 会移除通知栏常驻条）
    unawaited(() async {
      await Future<void>.delayed(Duration.zero);
      final handler = AudioServiceManager().handlerOrNull;
      if (handler != null) {
        try {
          await handler.clearController();
        } catch (_) {}
      }
    }());
    HistoryManager().removeListener(updateHistory);
    providerContainer
        .read(bangumiManagerProvider)
        .removeListener(updateBangumiBind);
    StatsManager().removeListener(updateStats);
    // 仅当详情加载完成（data != null）才触发数据同步：
    // 误点进入即退出 / 加载失败时未产生数据变化，不应上传。
    // 同步本身还有 5s 防抖 + 30s 最小间隔兜底，避免频繁进出反复上传。
    if (data != null) {
      Future.microtask(() {
        DataSync().onDataChanged();
      });
    }
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
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final isDesktop = screenWidth > 800;
    final playerHeight = isDesktop ? screenWidth * 0.35 : screenWidth * 0.6;
    // 宽屏（>2000 且为横向）改为左右布局：播放器在左，Tab 内容在右。
    // 需同时满足宽 > 高，避免竖向超高分辨率竖屏（宽超 2k 但高更高）、
    // 折叠屏展开成竖向/方形时误触发左右布局。
    final sideBySide = screenWidth > 2000 && screenWidth > screenHeight;

    final tabBar = Container(
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
    );

    if (sideBySide) {
      final playerWidth = screenWidth * 0.70;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: playerWidth,
            child: Column(
              children: [
                Container(
                  height: topPadding,
                  color: Theme.of(context).colorScheme.surface,
                ),
                // 播放器在左侧铺满剩余空间
                Expanded(
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(size: Size(playerWidth, screenHeight)),
                    child: Watcher(
                      key: watcherKey,
                      playerController: playerController,
                      watcherController: watcherController,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                // 右侧 Tab 留出安全顶部空间
                SizedBox(height: topPadding + 12),
                tabBar,
                Expanded(child: animeTab()),
              ],
            ),
          ),
        ],
      );
    }

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
                  key: watcherKey,
                  playerController: playerController,
                  watcherController: watcherController,
                ),
              ),
            ],
          ),
        ),
        tabBar,
        Expanded(child: animeTab()),
      ],
    );
  }

  @override
  Future<Res<AnimeDetails>> loadData() async {
    var animeSource = AnimeSource.find(_sourceKey);
    if (animeSource == null) {
      return const Res.error('Anime source not found');
    }
    isAddToLocalFav = LocalFavoritesManager().isExist(
      _animeId,
      AnimeType(_sourceKey.hashCode),
    );
    history = await HistoryManager().findAsync(
      _animeId,
      AnimeType(_sourceKey.hashCode),
    );

    return animeSource.loadAnimeInfo!(_animeId);
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
              buildMetaInfo(),
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
                    // 横向由外层 Padding(16) 控制，避免双倍左右留白
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              final coverUrl = (widget.cover != null &&
                                      widget.cover!.isNotEmpty)
                                  ? widget.cover!
                                  : anime.cover;
                              BangumiWidget.showImagePreview(
                                context: context,
                                url: coverUrl,
                                title: anime.title,
                                heroTag:
                                    widget.heroTag ?? "cover${widget.heroID}",
                                // 与封面显示的 provider 同 key，保证点击即命中缓存
                                imageProvider: coverUrl.isNotEmpty
                                    ? _coverProvider(coverUrl)
                                    : null,
                              );
                            },
                            child: Hero(
                              tag: widget.heroTag ?? "cover${widget.heroID}",
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
                                child: Builder(
                                  builder: (context) {
                                    // cover 为空（null 或空串）时回退到详情数据
                                    // anime.cover，避免空串不走 ?? 导致加载空 URL
                                    final coverUrl =
                                        (widget.cover != null &&
                                                widget.cover!.isNotEmpty)
                                        ? widget.cover!
                                        : anime.cover;
                                    return coverUrl.isNotEmpty
                                        ? AnimatedImage(
                                            image: _coverProvider(coverUrl),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : const SizedBox();
                                  },
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
                                    // bangumi 下方还有评分/收藏等占空间，标题限 2 行；
                                    // 非 bangumi 内容较空，放宽到 5 行完整展示标题
                                    maxLines: animeSource.isBangumi ? 2 : 5,
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
                                if (animeSource.isBangumi)
                                  // 源名称卡片：点击切换源
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: _switchSource,
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer
                                              .toOpacity(0.6),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.swap_horiz,
                                              size: 14,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              AnimeSource.find(
                                                anime.sourceKey,
                                              )?.name ??
                                              '',
                                              style: ts.s12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
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
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      height: 62,
                      child: _buildActionButtons(context, anime),
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

  Widget _buildActionButtons(BuildContext context, AnimeDetails anime) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        IconTileButton(
          icon: const Icon(Icons.star_border_rounded),
          activeIcon: const Icon(Icons.star_rounded),
          isActive: isFavorite || isAddToLocalFav,
          label: t.favorite,
          onTap: openFavPanel,
          onLongPress: quickFavorite,
          color: context.useTextColor(Colors.purple),
        ),
        IconTileButton(
          icon: const Icon(Icons.share),
          label: t.share,
          onTap: share,
          onLongPress: () => showKostoriShareSheet(
            context,
            ref,
            type: KostoriRouteType.anime,
            payload: '$_animeId|$_sourceKey',
            title: anime.title,
            subtitle: _sourceKey,
            backgroundImagePath: anime.cover,
          ),
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
        if (isBangumi) ...[
          IconTileButton(
            icon: const Icon(Icons.favorite_border),
            activeIcon: const Icon(Icons.favorite),
            isActive: isLiked,
            label: t.liked,
            onTap: () {
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
            color: Colors.redAccent,
          ),
          IconTileButton(
            icon: Icon((ratingValue != 0) ? Icons.star_rounded : Icons.comment),
            // 评分后 label 显示评分值（与其他按钮一致：单图标 + 文字）
            label: (ratingValue != 0)
                ? Utils.getRatingLabel(ratingValue ?? 0)
                : t.rating,
            onTap: () async {
              await showRatingDialog(statsDataImpl!).then((_) {
                setState(() {});
              });
            },
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
        if (isBangumi)
          IconTileButton(
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
            label: t.bangumi,
            onTap: () async {
              bangumiBottomInfo(context);
            },
          ),
        if (anime.url != null)
          IconTileButton(
            icon: const Icon(Icons.open_in_browser),
            label: t.openInBrowser,
            onTap: () => launchUrlString(anime.url!),
            color: Theme.of(context).colorScheme.secondary,
          ),
      ],
    ).fixHeight(60);
  }

  /// 切换播放源：搜索其他源的该条目，选中后页内热切换到该源
  /// （不迁移历史/收藏；重新加载新源详情，并继承当前播放的集）
  Future<void> _switchSource() async {
    final picked = await showModalBottomSheet<Anime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SourceSwitchSheet(
        initialKeyword: anime.title,
        currentSourceKey: _sourceKey,
        currentAnimeId: _animeId,
      ),
    );
    if (picked == null || !mounted) return;
    await _switchTo(picked.sourceKey, picked.id);
  }

  /// 独立条目源（independentSeries）：点击系列条目时同页切换详情信息为该条目
  /// （同源、不换源：更新 id → 重载详情 → 刷新历史/收藏/相关等）
  Future<void> _switchToSeriesEntry(Anime entry) async {
    if (entry.id.isEmpty || _animeId == entry.id) return;
    playerController.pause();
    // 重置旧条目历史与系列缓存：onDataLoaded 会用新条目 data 重新建立
    history = null;
    _seriesListCache = null;
    setState(() {
      _animeId = entry.id;
      isDownloaded = false;
    });
    final res = await loadDataWithRetry();
    if (!mounted) return;
    if (res.success) {
      data = res.data;
      try {
        await onDataLoaded();
      } catch (e, s) {
        Log.error('系列条目切换', '$e\n$s');
      }
      if (mounted) setState(() {});
    } else {
      setState(() {
        error = res.errorMessage ?? 'Load failed';
      });
    }
  }

  /// 页内热切换源：记录要继承的集，切源后重载详情并播放该集。
  /// 历史/收藏等逻辑按新源处理（像打开新源的详情页），不做迁移
  Future<void> _switchTo(String newSourceKey, String newId) async {
    if (_sourceKey == newSourceKey && _animeId == newId) return;
    // 继承当前播放的集（新源加载完成后播放同集）
    _pendingEpisode = playerController.currentEpisoded;
    playerController.pause();
    // 重置旧源历史：onDataLoaded 会用新源 data 重新建立观看记录
    history = null;
    setState(() {
      _sourceKey = newSourceKey;
      _animeId = newId;
      isDownloaded = false;
    });
    // 不切 loading（避免 watcher 卸载重建时 dispose playerController），
    // 直接加载新源数据并刷新
    final res = await loadDataWithRetry();
    if (!mounted) return;
    if (res.success) {
      data = res.data;
      try {
        await onDataLoaded();
      } catch (e, s) {
        // onDataLoaded 内部分步骤失败不能阻塞内容刷新
        Log.error('切换源加载后处理', '$e\n$s');
      }
      if (mounted) setState(() {});
    } else {
      setState(() {
        error = res.errorMessage ?? 'Load failed';
      });
    }
  }

  /// 下载按钮点击：弹卡片选集（每集可选分辨率）批量下载；
  /// 系列模式（无分集）则从 loadSeries 加载系列列表再下载
  Future<void> _onDownloadTap() async {
    final episode = data?.episode;
    if (episode == null || episode.isEmpty || episode.values.first.isEmpty) {
      await _onDownloadSeries();
      return;
    }
    final records = await DownloadManager.recordsFor(
      _animeId,
      _sourceKey,
    );
    if (!mounted) return;
    final eps = episode.values.first;
    final items = <_DownloadItem>[
      for (final e in eps.entries)
        () {
          final title = AnimeDetails.episodeTitleOf(e.value);
          final name = title.isEmpty ? t.episodeN(n: e.key) : title;
          final keyStr = e.key.toString();
          return _DownloadItem(
            key: keyStr,
            title: name,
            subtitle: '',
            episodeName: name,
            episodeNo: int.tryParse(keyStr) != null ? keyStr : null,
            sourceKey: _sourceKey,
          );
        }(),
    ];
    await _openDownloadPicker(
      items: items,
      downloaded: records.map((r) => r['episode'] as String? ?? '').toSet(),
    );
  }

  /// 系列模式下载：从 loadSeries 加载系列条目（每条一个视频，可单独选分辨率）
  Future<void> _onDownloadSeries() async {
    final source = AnimeSource.find(_sourceKey);
    if (source == null || source.loadSeries == null) {
      App.rootContext.showMessage(message: t.downloadNotYet);
      return;
    }
    final res = await source.loadSeries!(data!);
    if (!mounted) return;
    final series = res.dataOrNull ?? const <Anime>[];
    if (series.isEmpty) {
      App.rootContext.showMessage(message: t.downloadNotYet);
      return;
    }
    final records = await DownloadManager.recordsFor(
      _animeId,
      _sourceKey,
    );
    if (!mounted) return;
    final items = <_DownloadItem>[
      for (final a in series)
        _DownloadItem(
          key: a.id,
          title: a.title,
          subtitle: a.subtitle ?? '',
          episodeName: a.title,
          sourceKey: _sourceKey,
        ),
    ];
    await _openDownloadPicker(
      items: items,
      downloaded: records.map((r) => r['episode'] as String? ?? '').toSet(),
    );
  }

  /// 弹出卡片化下载选择框，确认后逐项加入下载队列
  Future<void> _openDownloadPicker({
    required List<_DownloadItem> items,
    required Set<String> downloaded,
  }) async {
    final result = await showModalBottomSheet<List<_DownloadPick>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EpisodeDownloadPicker(
        items: items,
        downloaded: downloaded,
        resolvePlay: _resolvePlayResult,
        animeTitle: data!.title,
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    for (final item in result) {
      await _downloadEpisode(
        item.key,
        item.episodeName,
        url: item.url,
        resolution: item.resolution,
        animeTitle: item.animeTitle,
        episodeNo: item.episodeNo,
      );
    }
  }

  /// 解析单集/系列条目的播放结果（String 或 AnimePlayResult）
  Future<AnimePlayResult?> _resolvePlayResult(String epKey) async {
    final source = AnimeSource.find(_sourceKey);
    if (source == null || source.loadAnimePages == null) return null;
    final res = await source.loadAnimePages!(data!.id, epKey);
    if (res is! Map) return null;
    try {
      return AnimePlayResult.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return null;
    }
  }

  /// 解析地址并加入下载队列；[url]/[resolution] 指定分辨率时使用该清晰度
  Future<void> _downloadEpisode(
    String epKey,
    String epName, {
    String? url,
    String? resolution,
    String? animeTitle,
    String? episodeNo,
  }) async {
    final source = AnimeSource.find(_sourceKey);
    if (source == null || source.loadAnimePages == null) {
      App.rootContext.showMessage(message: t.downloadFailed);
      return;
    }
    var targetUrl = url;
    if (targetUrl == null) {
      final res = await source.loadAnimePages!(data!.id, epKey);
      if (res is String) {
        targetUrl = res;
      } else if (res is Map) {
        targetUrl = _parsePlayResultUrl(res);
      }
    }
    if (!mounted) return;
    if (targetUrl == null ||
        targetUrl.isEmpty ||
        targetUrl.startsWith('blob:')) {
      App.rootContext.showMessage(message: t.downloadFailed);
      return;
    }
    final task = await DownloadManager.instance.enqueue(
      url: targetUrl,
      title: animeTitle ?? data!.title,
      subtitle: epName,
      cover: data!.cover,
      sourceKey: data!.sourceKey,
      animeId: _animeId,
      animeTitle: animeTitle ?? data!.title,
      episode: epName,
      episodeNo: episodeNo,
      author: data!.uploader,
      headers: source.httpHeaders ?? const {},
      resolution: resolution,
    );
    if (!mounted) return;
    // 并发未满时任务已立即开始（status 已切 downloading），
    // 排队中则提示等待，给用户明确反馈
    App.rootContext.showMessage(
      message: task != null && task.status == DownloadStatus.queued
          ? t.downloadQueued
          : t.downloadStarted,
    );
  }

  /// 从 AnimePlayResult Map 取默认播放地址
  String? _parsePlayResultUrl(Map res) {
    try {
      return AnimePlayResult.fromJson(Map<String, dynamic>.from(res)).url;
    } catch (_) {
      return null;
    }
  }

  Widget buildComment() {
    if (commentRecord == null || commentRecord!.comment!.isEmpty) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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

  /// 作者信息（描述上方，卡片样式）：
  /// 作者卡（头像+作者名+类型）+ 观看次数卡 + 上传时间卡
  Widget buildMetaInfo() {
    final uploader = anime.uploader;
    final avatar = anime.uploaderAvatar;
    final views = anime.viewsCount;
    final time = anime.uploadTime;
    // 类型：仅在源提供作者信息时取 tags 首个值（如"里番"/"2.5D"）
    String? genre;
    if (uploader != null && uploader.isNotEmpty) {
      for (final list in anime.tags.values) {
        if (list.isNotEmpty) {
          genre = list.first;
          break;
        }
      }
    }
    final hasAuthor =
        uploader?.isNotEmpty == true ||
        avatar?.isNotEmpty == true ||
        genre?.isNotEmpty == true;
    final hasStats = views?.isNotEmpty == true || time?.isNotEmpty == true;
    if (!hasAuthor && !hasStats) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    final colorScheme = Theme.of(context).colorScheme;

    Widget card({required Widget child}) => Material(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.6),
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 作者卡片：左头像 + 右作者名/类型
            if (hasAuthor)
              card(
                child: Row(
                  children: [
                    ClipOval(
                      child: avatar != null && avatar.isNotEmpty
                          ? AnimatedImage(
                              image: CachedImageProvider(
                                avatar,
                                headers: AnimeSource.find(
                                  anime.sourceKey,
                                )?.httpHeaders,
                              ),
                              width: 48,
                              height: 48,
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: colorScheme.secondaryContainer,
                              child: Icon(
                                Icons.person_outline,
                                color: colorScheme.outline,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (uploader != null && uploader.isNotEmpty)
                            Text(
                              uploader,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (genre != null && genre.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                genre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // 观看次数卡 + 上传时间卡（各自包裹内容宽度，不撑满整行）
            if (hasStats)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (views != null && views.isNotEmpty)
                      card(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_red_eye_outlined,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              views,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (time != null && time.isNotEmpty)
                      card(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
        // key 随条目变化：切换系列条目后重建，系列列表重新加载为该条目的系列
        children: [_AnimeEpisodes(key: ValueKey(anime.id), history: history)],
      ),
    );
  }

  Widget buildRecommend() {
    if (anime.recommend == null || anime.recommend!.isEmpty) {
      return const SizedBox.shrink();
    }
    // 过滤掉当前番剧自己，避免推荐列表与顶部封面产生重复 Hero tag
    final recommend = anime.recommend!
        .where((a) => !(a.id == _animeId && a.sourceKey == _sourceKey))
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.related),
                  ),
                  // 不指定固定列数，交给 SliverGridDelegateWithAnimes 按可用宽度自适应
                  SliverGridAnimes(
                    animes: recommend,
                    isRecommend: true,
                    asSliver: false,
                    shrinkWrap: true,
                    minCrossAxisCount: 3,
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

class _AnimePageLoadingPlaceHolder extends StatelessWidget {
  const _AnimePageLoadingPlaceHolder({
    this.cover,
    this.title,
    required this.sourceKey,
    required this.aid,
    this.heroTag,
    this.heroID,
  });

  final String? cover;

  final String? title;

  final String sourceKey;

  final String aid;

  /// 与正文封面 Hero 相同的 tag（转场期间占住目标，避免飞行丢失）
  final String? heroTag;

  final int? heroID;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    // 与正文一致的宽屏判定：>2000 且横向
    final sideBySide = screenWidth > 2000 && screenWidth > screenHeight;

    return Shimmer(
      color: context.isDarkMode ? Colors.grey.shade700 : Colors.white,
      child: sideBySide
          ? _buildSideBySide(context, screenWidth, screenHeight)
          : _buildStacked(context),
    );
  }

  Widget _buildStacked(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildVideoPlaceholder(context),
          const SizedBox(height: 16),
          _buildInfoArea(context),
        ],
      ),
    );
  }

  Widget _buildSideBySide(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
    final playerWidth = screenWidth * 0.70;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: playerWidth,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(size: Size(playerWidth, screenHeight)),
                    child: buildVideoPlaceholder(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const SizedBox(height: 24), _buildInfoArea(context)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 与正文一致的封面尺寸：宽 ≤ 30%，高 ≤ 300，宽/高比 0.72
          final maxImageWidth = constraints.maxWidth * 0.3;
          final calculatedHeight = maxImageWidth / 0.72;
          final imageHeight = math.min(calculatedHeight, 300.0);
          final imageWidth = imageHeight * 0.72;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildImage(context, width: imageWidth, height: imageHeight),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: imageHeight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleSkeleton(context),
                          const Spacer(),
                          _buildActionBarSkeleton(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTagChips(context),
              const SizedBox(height: 24),
              _buildDescriptionSkeleton(context),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _block(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildTitleSkeleton(BuildContext context) {
    final isBangumi = AnimeSource.find(sourceKey)?.isBangumi ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title!,
            style: ts.s18,
            // 与正文一致：非 bangumi 标题不因评分等占位而被限 2 行
            maxLines: isBangumi ? 2 : 5,
            overflow: TextOverflow.ellipsis,
          )
        else
          _block(context, width: double.infinity, height: 22),
        const SizedBox(height: 8),
        // 源名（bangumi 显示为可点击的切换卡占位）
        _block(
          context,
          width: isBangumi ? 70 : 56,
          height: isBangumi ? 26 : 12,
          radius: isBangumi ? 13 : 6,
        ),
      ],
    );
  }

  /// 底部操作栏（收藏/分享/喜欢/评分等）占位，与正文高度对齐避免加载后跳动
  Widget _buildActionBarSkeleton(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          _block(context, width: 22, height: 22, radius: 11),
          const SizedBox(width: 20),
        ],
      ],
    );
  }

  Widget _buildTagChips(BuildContext context) {
    const widths = [52.0, 76.0, 48.0, 64.0, 84.0, 56.0, 70.0, 60.0];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final w in widths)
          _block(context, width: w, height: 28, radius: 14),
      ],
    );
  }

  Widget _buildDescriptionSkeleton(BuildContext context) {
    const factors = [1.0, 0.95, 0.98, 0.62];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _block(context, width: 88, height: 16),
        const SizedBox(height: 14),
        for (final f in factors)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: f,
              child: _block(context, width: double.infinity, height: 12),
            ),
          ),
      ],
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

  Widget buildImage(BuildContext context, {required double width, required double height}) {
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

    // 占位封面参与 Hero 转场：数据异步加载期间先占住与正文封面相同的
    // tag，保证从列表飞入的目标在过渡帧已存在（否则数据晚到会丢失飞行）；
    // 数据就绪后同 tag 的正文封面原位接管（同一时刻页内只有一个同 tag Hero）
    Widget coverBox = Container(
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
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    final tag = heroTag ?? (heroID != null ? 'cover$heroID' : null);
    if (tag != null) {
      coverBox = Hero(tag: tag, child: coverBox);
    }
    return coverBox;
  }
}

/// 切换源的搜索选择弹窗：搜索其他源的该条目，选中后返回 Anime
class _SourceSwitchSheet extends StatefulWidget {
  const _SourceSwitchSheet({
    required this.initialKeyword,
    required this.currentSourceKey,
    required this.currentAnimeId,
  });

  final String initialKeyword;

  final String currentSourceKey;

  final String currentAnimeId;

  @override
  State<_SourceSwitchSheet> createState() => _SourceSwitchSheetState();
}

/// 单个源的切换搜索状态
class _SourceSearchState {
  bool loading = true;
  List<Anime> results = [];
  bool success = false;
  CloudflareException? cf;
  bool needsCaptcha = false;
}

class _SourceSwitchSheetState extends State<_SourceSwitchSheet> {
  /// sourceKey → 搜索状态（所有 bangumi 源）
  final Map<String, _SourceSearchState> _states = {};

  /// 已展开（查看结果）的源
  final Set<String> _expanded = {};

  /// 正在验证的源（CF）
  CloudflareException? _verifying;

  /// 源是否声明需要验证码（settings 里有 captcha 类配置）
  bool _sourceNeedsCaptcha(AnimeSource source) {
    final settings = source.settings;
    return settings != null &&
        settings.keys.any((k) => k.toLowerCase().contains('captcha'));
  }

  /// 参与聚合的 bangumi 源（排除当前源）
  List<AnimeSource> get _bangumiSources =>
      AnimeSource.allSources()
          .where(
            (x) => x.isBangumi && x.key != widget.currentSourceKey,
          )
          .toList();

  @override
  void initState() {
    super.initState();
    // 初始化所有 bangumi 源（除当前源），打开即自动搜索当前标题
    for (final s in _bangumiSources) {
      _states[s.key] = _SourceSearchState();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _searchAll());
  }

  Future<void> _searchAll() async {
    for (final source in _bangumiSources) {
      _searchSource(source);
    }
  }

  Future<void> _searchSource(
    AnimeSource source, {
    bool allowCaptchaDialog = false,
  }) async {
    final st = _states[source.key]!;
    st.loading = true;
    st.results = [];
    st.success = false;
    st.cf = null;
    if (!allowCaptchaDialog) st.needsCaptcha = false;
    setState(() {});
    final data = source.searchPageData;
    if (data == null || data.loadPage == null) {
      st.loading = false;
      setState(() {});
      return;
    }
    final beforeSuppressed = JsUiApi.suppressedCaptchaRequests;
    try {
      // 批量自动搜索：抑制源 JS 的验证码弹窗，验证码只在该源被主动触发时弹出
      if (!allowCaptchaDialog) JsUiApi.suppressCaptcha();
      final options = (data.searchOptions ?? const [])
          .map((e) => e.defaultValue)
          .toList();
      final res = await data.loadPage!(widget.initialKeyword, 1, options);
      if (!mounted) return;
      st.loading = false;
      st.success = res.success;
      st.results = res.dataOrNull ?? [];
    } catch (e) {
      if (!mounted) return;
      st.loading = false;
      final msg = e.toString();
      st.cf = CloudflareException.fromString(msg);
      st.needsCaptcha =
          !st.needsCaptcha &&
          (msg.toLowerCase().contains('captcha') || msg.contains('验证码'));
    } finally {
      if (!allowCaptchaDialog) JsUiApi.restoreCaptcha();
      // 搜索期间源 JS 请求过验证码弹窗（被抑制）→ 标记该源需要验证码
      if (JsUiApi.suppressedCaptchaRequests > beforeSuppressed) {
        st.needsCaptcha = true;
      }
    }
    setState(() {});
  }

  /// 点击需要验证的源：触发 Cloudflare 验证，通过后重搜该源
  Future<void> _verifySource(String sourceKey, CloudflareException cfe) async {
    if (_verifying != null) return;
    setState(() => _verifying = cfe);
    passCloudflare(cfe, () {
      if (mounted) {
        setState(() => _verifying = null);
        final s = AnimeSource.find(sourceKey);
        if (s != null) _searchSource(s, allowCaptchaDialog: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sources = _bangumiSources;
    return Sheet(
      title: t.switchSource,
      icon: Icons.swap_horiz,
      initialSize: 0.7,
      builder: (ctx, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.all(12),
        children: [
          for (final s in sources)
            _SourceCard(
              source: s,
              state: _states[s.key]!,
              needsCaptchaDeclared: _sourceNeedsCaptcha(s),
              expanded: _expanded.contains(s.key),
              verifying: _verifying?.url == s.key,
              isCurrent:
                  s.key == widget.currentSourceKey &&
                  _states[s.key]!.results.any((a) => a.id == widget.currentAnimeId),
              onToggle: () => setState(() {
                if (!_expanded.remove(s.key)) _expanded.add(s.key);
              }),
              onVerify: () {
                final cfe = _states[s.key]!.cf;
                if (cfe != null) _verifySource(s.key, cfe);
              },
              onRetry: () => _searchSource(s, allowCaptchaDialog: true),
              onCaptcha: () => _searchSource(s, allowCaptchaDialog: true),
              onPick: (a) => Navigator.pop(ctx, a),
            ),
        ],
      ),
    );
  }
}

/// 切换源列表里的单个源卡片：标题 + 状态（成功/数量/CF/验证码），点击展开结果
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.state,
    required this.needsCaptchaDeclared,
    required this.expanded,
    required this.verifying,
    required this.isCurrent,
    required this.onToggle,
    required this.onVerify,
    required this.onRetry,
    required this.onCaptcha,
    required this.onPick,
  });

  final AnimeSource source;

  final _SourceSearchState state;

  final bool needsCaptchaDeclared;

  final bool expanded;

  final bool verifying;

  final bool isCurrent;

  final VoidCallback onToggle;

  final VoidCallback onVerify;

  final VoidCallback onRetry;

  final VoidCallback onCaptcha;

  final void Function(Anime) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needsCf = state.cf != null;
    final needsCaptcha = needsCaptchaDeclared || state.needsCaptcha;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent) ...[
                      Icon(Icons.check_circle, size: 18, color: cs.primary),
                      const SizedBox(width: 6),
                    ],
                    _StatusBadge(
                      icon: Icons.verified_user_outlined,
                      label: 'CF',
                      color: cs.error,
                      show: needsCf,
                    ),
                    _StatusBadge(
                      icon: Icons.password_outlined,
                      label: t.needVerification,
                      color: Colors.orange,
                      show: needsCaptcha,
                    ),
                    if (state.loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: PolygonRefreshIndicator(),
                      )
                    else if (state.success)
                      _StatusBadge(
                        icon: Icons.check_circle_outline,
                        label: '${state.results.length}',
                        color: Colors.green,
                        show: true,
                      )
                    else if (!needsCf && !needsCaptcha)
                      _StatusBadge(
                        icon: Icons.error_outline,
                        label: '0',
                        color: cs.outline,
                        show: true,
                      ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (needsCf)
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.verified_user_outlined, color: cs.error),
                          title: Text(t.needVerification),
                          subtitle: Text(t.tapToVerify),
                          trailing: verifying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: PolygonRefreshIndicator(),
                                )
                              : Icon(Icons.chevron_right, color: cs.outline),
                          onTap: onVerify,
                        ),
                      if (needsCaptcha && !needsCf)
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.password_outlined, color: Colors.orange),
                          title: Text(t.needVerification),
                          subtitle: Text(t.tapToVerify),
                          trailing: state.loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: PolygonRefreshIndicator(),
                                )
                              : Icon(Icons.chevron_right, color: cs.outline),
                          onTap: onCaptcha,
                        ),
                      for (final a in state.results)
                        ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 36,
                              height: 48,
                              child: AnimatedImage(
                                image: CachedImageProvider(
                                  a.cover,
                                  sourceKey: a.sourceKey,
                                  aid: a.id,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          title: Text(
                            a.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing:
                              a.sourceKey == source.key
                              ? Icon(Icons.chevron_right, color: cs.outline)
                              : null,
                          onTap: () => onPick(a),
                        ),
                      if (state.results.isEmpty &&
                          !state.loading &&
                          !needsCf &&
                          !needsCaptcha)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: cs.outline,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                t.search,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh, size: 14),
                                label: Text(t.retry),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片上的小状态标记（图标 + 文案）
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.show,
  });

  final IconData icon;

  final String label;

  final Color color;

  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.toOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 下载选集选择弹窗：多选/全选，已下载的集排除，确认后批量下载
/// 下载项统一抽象（剧集 epKey 或系列条目 id）
class _DownloadItem {
  final String key;

  final String title;

  final String subtitle;

  /// 下载记录里的 episode 字段（用于已下载标记）
  final String episodeName;

  /// 纯集号（数字索引时才有），用于“不使用集标题”命名
  final String? episodeNo;

  /// 封面所属源 key
  final String sourceKey;

  const _DownloadItem({
    required this.key,
    required this.title,
    this.subtitle = '',
    required this.episodeName,
    this.episodeNo,
    required this.sourceKey,
  });
}

/// 下载选择结果
class _DownloadPick {
  final String key;

  final String episodeName;

  /// 选定的番剧主标题（用户可在弹窗顶部编辑，覆盖文件名的 {title} 部分）
  final String? animeTitle;

  /// 纯集号（“不使用集标题”命名用）
  final String? episodeNo;

  /// 选定分辨率的 url（null = 使用默认）
  final String? url;

  /// 分辨率标签（如 1080p）
  final String? resolution;

  const _DownloadPick({
    required this.key,
    required this.episodeName,
    this.animeTitle,
    this.episodeNo,
    this.url,
    this.resolution,
  });
}

/// 卡片化下载选择弹窗：每集一张卡片（封面 + 标题 + 分辨率选择）
class _EpisodeDownloadPicker extends StatefulWidget {
  const _EpisodeDownloadPicker({
    required this.items,
    required this.downloaded,
    required this.resolvePlay,
    required this.animeTitle,
  });

  final List<_DownloadItem> items;

  /// 已下载的 episodeName 集合
  final Set<String> downloaded;

  /// 解析单集/系列条目的播放结果（获取多分辨率）
  final Future<AnimePlayResult?> Function(String key) resolvePlay;

  /// 番剧主标题（用于文件名的 {title}，可在弹窗内修改）
  final String animeTitle;

  @override
  State<_EpisodeDownloadPicker> createState() => _EpisodeDownloadPickerState();
}

class _EpisodeDownloadPickerState extends State<_EpisodeDownloadPicker> {
  late final Set<String> selected;

  /// key → 选定分辨率（存 url + label）
  final Map<String, String?> _resolutionByKey = {};
  final Map<String, String?> _resolutionLabelByKey = {};

  /// key → 自定义标题（用于文件名；默认用 item.title）
  final Map<String, String> _nameOverrides = {};

  /// 番剧主标题（顶部输入框，可编辑，覆盖文件名的 {title} 部分）
  late String _animeTitle;
  late final TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    // 默认不选择任何集，避免误下载整部（尤其是大批量番剧）
    selected = <String>{};
    _animeTitle = widget.animeTitle;
    _titleCtrl = TextEditingController(text: widget.animeTitle);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _toggle(String key) {
    setState(() {
      if (!selected.add(key)) selected.remove(key);
    });
  }

  /// 编辑下载标题（用于生成文件名，避免超长标题导致无法创建文件）
  Future<void> _editItemName(_DownloadItem item) async {
    final ctrl = TextEditingController(
      text: _nameOverrides[item.key] ?? item.title,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.rename,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(labelText: t.fileName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              setState(() {
                if (name.isEmpty) {
                  _nameOverrides.remove(item.key);
                } else {
                  _nameOverrides[item.key] = name;
                }
              });
              Navigator.of(ctx).pop();
            },
            child: Text(t.apply),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  /// 默认清晰度对应的实际标签：解析首个可用视频流（仅用于显示，不改 url）
  Future<String?> _defaultResLabel(_DownloadItem item) async {
    try {
      final res = await widget.resolvePlay(item.key);
      final streams = res?.videoStreams ?? const <VideoStreamInfo>[];
      for (final s in streams) {
        if (s.url != null && s.url!.isNotEmpty) {
          return s.label.isNotEmpty ? s.label : null;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _confirm() async {
    final picks = <_DownloadPick>[];
    for (final item in widget.items) {
      if (!selected.contains(item.key)) continue;
      var resLabel = _resolutionLabelByKey[item.key];
      // 未手动选清晰度（默认清晰度）：回填实际流标签用于显示
      if (_resolutionByKey[item.key] == null && resLabel == null) {
        resLabel = await _defaultResLabel(item);
      }
      picks.add(
        _DownloadPick(
          key: item.key,
          // 用户编辑过标题时用它（用于文件名），否则用原始集名
          episodeName: _nameOverrides[item.key] ?? item.episodeName,
          animeTitle: _animeTitle.trim().isEmpty ? null : _animeTitle.trim(),
          episodeNo: item.episodeNo,
          url: _resolutionByKey[item.key],
          resolution: resLabel,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(picks);
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == widget.items.length;
    return Sheet(
      title: t.downloadEpisode,
      icon: Icons.download_outlined,
      initialSize: 0.7,
      headerTrailing: TextButton(
        onPressed: () => setState(() {
          if (allSelected) {
            selected.clear();
          } else {
            selected.addAll(widget.items.map((e) => e.key));
          }
        }),
        child: Text(allSelected ? t.selectNone : t.selectAll),
      ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selected.isEmpty ? null : _confirm,
              child: Text(t.downloadSelectedCount(n: selected.length)),
            ),
          ),
        ),
      ),
      builder: (context, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // 番剧主标题：可编辑，作为所有选中项文件名的 {title} 前缀
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextField(
              controller: _titleCtrl,
              onChanged: (v) => _animeTitle = v,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: t.downloadMainTitle,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title, size: 18),
              ),
            ),
          ),
          for (final item in widget.items)
            _DownloadItemCard(
              item: item,
              displayTitle: _nameOverrides[item.key] ?? item.title,
              isDownloaded: widget.downloaded.contains(item.episodeName),
              isSelected: selected.contains(item.key),
              resolutionLabel: _resolutionLabelByKey[item.key],
              onToggle: () => _toggle(item.key),
              onEditName: () => _editItemName(item),
              onResolution: (url, label) => setState(() {
                _resolutionByKey[item.key] = url;
                _resolutionLabelByKey[item.key] = label;
              }),
              resolvePlay: widget.resolvePlay,
            ),
        ],
      ),
    );
  }
}

/// 单个下载项卡片：封面 + 标题/副标题 + 分辨率选择
class _DownloadItemCard extends StatefulWidget {
  const _DownloadItemCard({
    required this.item,
    required this.displayTitle,
    required this.isDownloaded,
    required this.isSelected,
    required this.resolutionLabel,
    required this.onToggle,
    required this.onEditName,
    required this.onResolution,
    required this.resolvePlay,
  });

  final _DownloadItem item;

  /// 显示标题（用户编辑后为其自定义名）
  final String displayTitle;

  final bool isDownloaded;

  final bool isSelected;

  final String? resolutionLabel;

  final VoidCallback onToggle;

  /// 编辑标题（改文件名用）
  final VoidCallback onEditName;

  final void Function(String url, String label) onResolution;

  final Future<AnimePlayResult?> Function(String key) resolvePlay;

  @override
  State<_DownloadItemCard> createState() => _DownloadItemCardState();
}

class _DownloadItemCardState extends State<_DownloadItemCard> {
  bool _resolving = false;

  /// 解析多分辨率并弹出选择（只有一种分辨率时提示无更多可选）
  Future<void> _pickResolution() async {
    if (_resolving || widget.isDownloaded) return;
    setState(() => _resolving = true);
    final result = await widget.resolvePlay(widget.item.key);
    if (!mounted) return;
    setState(() => _resolving = false);
    final options = (result?.videoStreams ?? const <VideoStreamInfo>[])
        .where((s) => s.url != null && s.url!.isNotEmpty)
        .toList();
    if (options.length <= 1) {
      App.rootContext.showMessage(message: t.noResolutionAvailable);
      return;
    }
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.selectResolution,
        icon: Icons.high_quality_outlined,
        initialSize: 0.45,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (var i = 0; i < options.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.high_quality_outlined),
                title: Text(options[i].label),
                trailing: options[i].label == widget.resolutionLabel
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (index == null || !mounted) return;
    widget.onResolution(options[index].url!, options[index].label);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: widget.isDownloaded
            ? colorScheme.surfaceContainerHigh
            : (widget.isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : colorScheme.surfaceContainerLow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: widget.isSelected ? 1.5 : 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.isDownloaded ? null : widget.onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  widget.isSelected
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: widget.isDownloaded
                      ? colorScheme.outline
                      : (widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant),
                ),
                const SizedBox(width: 8),
                // 标题 + 副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 分辨率选择 / 已下载标记
                if (widget.isDownloaded)
                  Icon(Icons.download_done, size: 20, color: Colors.green)
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _pickResolution,
                    icon: _resolving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: PolygonRefreshIndicator(),
                          )
                        : const Icon(Icons.high_quality_outlined, size: 16),
                    label: Text(
                      widget.resolutionLabel ?? t.defaultResolution,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                // 编辑标题（超长标题影响建文件名时改短）
                if (!widget.isDownloaded)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: t.rename,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: widget.onEditName,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
