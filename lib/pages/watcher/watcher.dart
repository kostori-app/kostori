// ignore_for_file: prefer_typing_uninitialized_variables

library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/history_write_service.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_play_result.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/m3u8_proxy_server.dart';
import 'package:kostori/foundation/webview_resolver.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:media_kit/media_kit.dart';

/// 播放器对外操作接口：`_WatcherState` 私有化后，外部（播放页/详情页/局域网等）
/// 经此访问当前激活的播放器。没有打开的播放器时 [currentState] 为 null。
/// 读数据优先走 Riverpod（[watcherControllerProvider]），操作类接口兜底。
abstract class WatcherPlayer {
  static _WatcherState? _current;

  static _WatcherState? get _active => _current;

  /// 当前激活的播放器（无则 null）
  static WatcherPlayer? get currentState => _current;

  /// 当前是否有激活的播放器
  static bool get hasActivePlayer => _current != null;

  /// 播放器页面上下文（全屏/弹层等需要）
  BuildContext get context;

  /// 当前观看的番剧
  AnimeDetails get anime;

  /// 一起看/剧集控制器
  WatcherController get watcherController;

  /// 观看历史
  History get history;

  /// 播放器控制器
  PlayerController get playerController;

  /// 当前集 index
  int get epIndex;

  /// 绑定的 bangumi 条目 id
  int? get bangumiId;

  set bangumiId(int? id);

  /// 加载指定线路的某一集
  Future<void> loadInfo(int episodeIndex, int road);

  /// 重载当前集视频链接（绕过同集重复加载检查，重新解析地址）
  Future<void> reloadCurrent();

  /// 播放下一集
  Future<void> playNextEpisode();

  /// 系列模式下第 index 条系列条目
  Anime? seriesAt(int index);
}

class Watcher extends StatefulWidget {
  const Watcher({
    super.key,
    required this.playerController,
    required this.watcherController,
  });

  final PlayerController playerController;

  final WatcherController watcherController;

  @override
  State<Watcher> createState() => _WatcherState();
}

class _WatcherState extends State<Watcher>
    with SingleTickerProviderStateMixin, RouteAware
    implements WatcherPlayer {
  static _WatcherState? get current => WatcherPlayer._active;

  static set current(_WatcherState? value) => WatcherPlayer._current = value;

  @override
  PlayerController get playerController => widget.playerController;

  @override
  WatcherController get watcherController => widget.watcherController;

  @override
  History get history => widget.watcherController.history!;

  @override
  AnimeDetails get anime => widget.watcherController.anime!;

  AnimeSource get animeSource => AnimeSource.find(anime.sourceKey)!;

  AnimeType get type => anime.animeType;

  String get name => anime.title;

  /// 是否已加入一起看房间且为成员（此时进入播放页先跟房主同步，
  /// 而不是恢复本地历史进度）
  bool get _isWatchMember {
    final hub = ProviderScope.containerOf(context).read(hubProvider);
    final room = hub.currentRoom;
    final currentAnime = watcherController.anime;
    return hub.isConnected &&
        room != null &&
        room.roomId != hub.lobbyRoomId &&
        room.isWatchRoom &&
        room.ownerUserId != hub.myId &&
        currentAnime != null &&
        room.animeId == currentAnime.id &&
        room.animeSourceKey == currentAnime.sourceKey;
  }

  final stats = StatsManager();

  StreamSubscription<bool>? _completedSub;

  /// 当前播放线路
  late int currentRoad;

  Timer? updateHistoryTimer;

  Progress? progressFind;

  late StatsDataImpl statsDataImpl;

  Map<String, String>? headers = {};

  @override
  int? bangumiId;

  /// 当前集 index
  @override
  int epIndex = 1;

  /// 历史播放进度（毫秒）
  var time = 0;

  /// 已加载的集 index
  var loaded = 0;

  bool isLoading = false;

  /// 加载代次：切换集/线路时自增，用于丢弃过期异步结果（旧集还在解析时切走）
  int _loadGen = 0;

  /// 系列模式下的系列条目列表（源 loadSeries 返回，复用 Anime 结构）
  List<Anime>? _series;

  // ---- 播放进度上报（源实现，如 emby 同步历史到服务端）----
  Timer? _progressReportTimer;
  AnimeSource? _reportSource;
  String? _reportUrl;
  String? _reportPlaySessionId;

  /// 当前是否为系列模式：无分集（episode 为空）且源提供 loadSeries
  bool get _isSeries =>
      (anime.episode == null || anime.episode!.isEmpty) &&
      animeSource.loadSeries != null;

  /// 加载并缓存系列列表（仅系列模式）
  Future<List<Anime>> _ensureSeries() async {
    if (_series != null) return _series!;
    if (animeSource.loadSeries == null) return const [];
    final res = await animeSource.loadSeries!(anime);
    _series = res.dataOrNull ?? const [];
    return _series!;
  }

  // ---------------- 生命周期 ----------------

  @override
  void initState() {
    super.initState();
    current = this;
    playerController.changePlayerSettings();
    epIndex = 1;
    currentRoad = 0;
    updateStats(init: true);
    _completedSub = playerController.player.stream.completed.listen((
      completed,
    ) {
      if (completed) {
        playNextEpisode();
      }
    });
    Future.microtask(() async {
      headers = animeSource.httpHeaders;
      // 系列模式：先预加载系列列表，后续 _episodeKey/_episodeCount 依赖它
      if (_isSeries) {
        await _ensureSeries();
      }
      if (!_isWatchMember && history.lastWatchEpisode != 0) {
        loadInfo(history.lastWatchEpisode!, history.lastRoad!.toInt());
      } else if (_isWatchMember) {
        // 一起看成员：先加载默认集数（临时解锁，否则初始加载会被 syncLocked 拦截），
        // 之后房主 sync 到达再对齐集数与进度
        final prev = playerController.syncLocked;
        playerController.syncLocked = false;
        try {
          await loadInfo(1, 0);
        } finally {
          playerController.syncLocked = prev;
        }
      }
      await updateHistory();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playerController.initWindow();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      App.routeObserver.subscribe(this, route);
    }
  }

  /// 本页被其他页面覆盖时暂停播放，避免后台继续播放。
  @override
  void didPushNext() {
    // 全屏时播放器转到 FullscreenVideoPage（同一 controller），不能暂停
    if (!playerController.isFullScreen) {
      playerController.pause(showIndicator: false);
    }
  }

  /// 返回本页时恢复 currentState（多个详情页入栈后返回）
  @override
  void didPopNext() {
    current = this;
  }

  @override
  void dispose() {
    App.routeObserver.unsubscribe(this);
    // 仅当自己是当前激活的 Watcher 时才清空，避免多详情页时误清
    if (current == this) {
      current = null;
    }
    _completedSub?.cancel();
    updateHistoryTimer?.cancel();
    _stopPlaybackReporting();
    playerController.dispose();
    playerController.disposeWindow();
    super.dispose();
  }

  void update() {
    setState(() {});
  }

  // ---------------- 请求头 ----------------

  /// 动态添加或更新请求头
  void setHeader(String key, String value) {
    headers?[key] = value;
  }

  // ---------------- 集加载与播放 ----------------

  /// 播放下一集（已到最后一集时提示无更多剧集）
  @override
  Future<void> playNextEpisode({bool checkRemainingTime = true}) async {
    // 播放器组件的全局区域：提示信息居中显示在播放器上（宽屏 sideBySide 下播放器只占左侧）
    final playerRect = _playerRect();
    setState(() {
      if (epIndex < _episodeCount(playerController.currentRoad)) {
        try {
          epIndex++;
          loadNextEpisode(epIndex);
          _showCenterHint(
            icon: const AssetImage('assets/img/check.gif'),
            message: t.watcherPlayingNext,
            playerRect: playerRect,
          );
        } catch (e) {
          _showCenterHint(
            seconds: 3,
            icon: const AssetImage('assets/img/warning.gif'),
            message: t.watcherEpisodeLoadError(error: e.toString()),
            playerRect: playerRect,
          );
          PlayLog.info("playNextEpisode", "加载剧集时出错");
        }
      } else {
        _showCenterHint(
          seconds: 3,
          icon: const AssetImage('assets/img/warning.gif'),
          message: t.watcherNoMoreEpisodes,
          playerRect: playerRect,
        );
        PlayLog.info("下一集", "没有更多剧集可播放");
      }
    });
  }

  /// 加载指定线路的某一集（公开入口）
  @override
  Future<void> loadInfo(int episodeIndex, int road) async {
    await _loadEpisode(episodeIndex: episodeIndex, road: road);
  }

  /// 重载当前集：绕过「同集重复加载」检查，强制重新解析视频链接
  @override
  Future<void> reloadCurrent() async {
    loaded = -1;
    await _loadEpisode(episodeIndex: epIndex, road: currentRoad);
  }

  /// 加载当前线路的下一集
  Future<void> loadNextEpisode(int episodeIndex) async {
    await _loadEpisode(
      episodeIndex: episodeIndex,
      road: playerController.currentRoad,
    );
  }

  /// 核心加载流程：解析播放地址 → 初始化播放器 → 加载媒体 → 缓冲
  Future<void> _loadEpisode({
    required int episodeIndex,
    required int road,
  }) async {
    // 一起看成员：禁止手动切换集数，只能跟随房主（房主同步会临时解锁放行）
    if (playerController.syncLocked) return;
    // 切换集/线路：取消上一个还在进行的 WebView 解析，避免旧任务占用资源
    WebViewResolver.cancel();
    final gen = ++_loadGen;
    if (!_isSeries &&
        (anime.episode == null || road >= anime.episode!.length)) {
      App.rootContext.showMessage(message: t.watcherRouteNotFound);
      return;
    }
    if (episodeIndex == loaded && road == playerController.currentRoad) {
      App.rootContext.showMessage(message: t.watcherDuplicateEpisode);
      return;
    }
    epIndex = episodeIndex;
    PlayLog.info("加载剧集", "$episodeIndex");

    try {
      var progressFind = await HistoryManager().progressFindAsync(
        anime.id,
        AnimeType(anime.sourceKey.hashCode),
        epIndex - 1,
        road,
      );
      if (progressFind == null) {
        // 无历史进度（新条目/系列条目首次播放）：创建初始进度，避免被跳过
        await HistoryManager().addProgress(
          Progress.fromModel(
            model: anime,
            episode: epIndex - 1,
            road: road,
            progressInMilli: 0,
            startTime: DateTime.now(),
          ),
          anime.id,
        );
        progressFind = await HistoryManager().progressFindAsync(
          anime.id,
          AnimeType(anime.sourceKey.hashCode),
          epIndex - 1,
          road,
        );
        if (progressFind == null) {
          PlayLog.warning('progress create failed', '$episodeIndex-$road');
          return;
        }
      }
      this.progressFind = progressFind;

      if (progressFind.startTime == null) {
        HistoryManager().updateProgress(
          historyId: progressFind.historyId,
          type: progressFind.type,
          episode: progressFind.episode,
          road: progressFind.road,
          startTime: DateTime.now(),
        );
      }

      time = progressFind.progressInMilli;

      // 步骤0：解析视频地址
      playerController.loadingStep = 0;
      playerController.isParsing = true;

      final res = await type.animeSource!.loadAnimePages!(
        anime.id,
        _episodeKey(road, epIndex),
      );

      // 已切走或播放器已退出：丢弃过期结果，不再初始化播放器
      if (gen != _loadGen || !mounted) return;

      // 兼容：源可返回 String（纯 URL）或结构化对象（AnimePlayResult）
      final (playUrl, playResult) = _parsePlayResult(res);
      if (playUrl.isEmpty) {
        playerController.isParsing = false;
        PlayLog.error("加载剧集", "$res 不合法");
        App.rootContext.showMessage(
          message: t.fetchVideoUrlError(detail: res),
          level: LogLevel.error,
        );
        return;
      }

      // 步骤1：地址就绪，初始化播放器
      playerController.isParsing = false;
      playerController.loadingStep = 1;
      // 结构化结果优先提供播放请求头（如 emby 鉴权）
      final prHeaders = playResult?.headers;
      if (prHeaders != null && prHeaders.isNotEmpty) {
        headers = prHeaders;
      }
      playerController.playResult = playResult;

      await _play(playUrl, time);

      // 播放器已退出：后续状态写入无意义
      if (!mounted) return;

      // 源提供播放进度上报接口时开始同步（emby/jellyfin 历史）
      _startPlaybackReporting(playUrl, playResult);

      playerController.currentRoad = road;
      playerController.currentEpisoded = episodeIndex;
      playerController.videoUrl = playUrl;
      playerController.playing = true;
      playerController.updateCurrentSetName(epIndex);

      history.watchEpisode.add(epIndex);
      history.lastRoad = road;

      loaded = episodeIndex;
      await updateHistory();
    } catch (e, s) {
      PlayLog.error("_loadEpisode", "$e\n$s");
      // 已切走或播放器已退出：过期任务（被取消的 WebView 解析）的报错静默丢弃
      if (gen != _loadGen || !mounted) return;
      // 解析异常也要复位，否则覆盖层会一直显示"正在解析"
      playerController.isParsing = false;
    }
  }

  /// 打开媒体并等待缓冲就绪，然后启动历史/进度定时上报
  Future<void> _play(String res, int currentPlaybackTime) async {
    playerController.loadFailed = false;
    try {
      if (!mounted) return;
      final actualPlayUrl = await _resolvePlayUrl(res);

      playerController.playUrl = actualPlayUrl;
      playerController.videoHeaders = actualPlayUrl == res ? headers : null;
      PlayLog.info('_play', 'httpHraders: $headers');

      // 步骤2：加载媒体数据
      playerController.loadingStep = 2;

      await playerController.player.open(
        Media(actualPlayUrl, httpHeaders: actualPlayUrl == res ? headers : {}),
      );
    } catch (e, s) {
      PlayLog.error("openMedia", "$e\n$s");
      // 复位加载状态并标记失败，避免覆盖层一直显示"加载媒体数据"
      playerController.loadingStep = 0;
      playerController.isParsing = false;
      playerController.isBuffering = false;
      playerController.loadFailed = true;
      // 停止播放器，避免 mpv 对失效链接反复重试刷错误日志
      try {
        await playerController.player.stop();
      } catch (_) {}
      if (mounted) {
        playerController.toastPlayFailed(t.failedToLoadPleaseTryAgain);
      }
      return;
    }

    await _waitForBuffer(currentPlaybackTime);
    _startHistoryTimer();
  }

  /// m3u8 广告过滤开启时走本地代理
  Future<String> _resolvePlayUrl(String res) async {
    if (appdata.settings['m3u8AdFilterEnabled'] != true) return res;
    final isM3u8 =
        res.contains('.m3u8') || res.contains('mpegurl') || await _isM3u8(res);
    if (!isM3u8) return res;
    final proxyUrl = await M3u8ProxyServer.instance.proxyUrl(res, headers);
    PlayLog.info('M3u8Proxy', '代理地址: $proxyUrl');
    return proxyUrl;
  }

  /// 等待缓冲流有数据后 seek 到历史进度（media_kit 的 buffer.first
  /// 触发时媒体未完全加载，直接 seek 会不准确，故用首个缓冲事件兜底）
  Future<void> _waitForBuffer(int currentPlaybackTime) async {
    final completer = Completer<void>();
    final sub = playerController.player.stream.buffer.listen(null);
    sub.onData((event) async {
      if (event.inMicroseconds <= 0) return;
      // 步骤3：缓冲中
      playerController.loadingStep = 3;
      await sub.cancel();
      if (mounted) {
        try {
          var remainingPlaybackTime = currentPlaybackTime;
          if (progressFind!.isCompleted) {
            final duration =
                playerController.player.state.duration.inMilliseconds;
            if ((duration - remainingPlaybackTime).abs() <= 5000) {
              remainingPlaybackTime = 0;
            }
          }
          await playerController.player.seek(
            Duration(milliseconds: remainingPlaybackTime),
          );
        } catch (_) {}
      }
      completer.complete();
    });
    await completer.future;
  }

  /// 每秒同步历史/进度/时长统计
  void _startHistoryTimer() {
    updateHistoryTimer?.cancel();
    if (!mounted) return;
    updateHistoryTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!playerController.player.state.playing) return;
      history.lastWatchTime =
          playerController.player.state.position.inMilliseconds;
      if (bangumiId != null) {
        history.bangumiId = bangumiId;
      }

      // 数据库写入走后台 isolate，不阻塞主线程
      HistoryWriteService.addHistory(history);
      HistoryWriteService.updateProgress(
        historyId: anime.id,
        type: anime.animeType,
        episode: epIndex - 1,
        road: playerController.currentRoad,
        progressInMilli: playerController.player.state.position.inMilliseconds,
      );
      // 更新主 isolate 缓存（集数变化立即通知、时间每 30 秒通知，
      // 不每秒重建播放器）
      HistoryManager().cacheHistory(history);
      updateTotalWatchDurations();

      // 只在未完成时检查
      if (progressFind != null && !progressFind!.isCompleted) {
        final duration = playerController.player.state.duration.inMilliseconds;
        final position = playerController.player.state.position.inMilliseconds;
        final remainingMillis = duration - position;

        // 剩余不足3分钟时标记完成
        if (duration > 0 && remainingMillis < 3 * 60 * 1000) {
          progressFind!.isCompleted = true;
          HistoryManager().updateProgress(
            historyId: anime.id,
            type: anime.animeType,
            episode: epIndex - 1,
            road: playerController.currentRoad,
            isCompleted: true,
            endTime: DateTime.now(),
          );
        }
      }
    });
  }

  // ---------------- 历史与统计 ----------------

  Future<void> updateHistory() async {
    history.lastWatchEpisode = epIndex;
    // 系列条目互相独立（每条目一个独立视频）：历史按单集记录，不把系列当多集
    history.allEpisode =
        _isSeries ? 1 : _episodeCount(playerController.currentRoad);
    if (anime.cover.trim().isNotEmpty) {
      history.cover = anime.cover;
    }
    await HistoryManager().addHistory(history);
  }

  void updateTotalWatchDurations() {
    final now = DateTime.now();
    DailyEvent? todayRecord = statsDataImpl.totalWatchDurations
        .firstWhereOrNull(
          (c) =>
              c.date.year == now.year &&
              c.date.month == now.month &&
              c.date.day == now.day,
        );

    if (todayRecord != null) {
      PlatformEventRecord? platformRecord = todayRecord.platformEventRecords
          .firstWhereOrNull((p) => p.platform == AppPlatform.current);

      if (platformRecord != null) {
        platformRecord.value += 1;
        platformRecord.date = now;
      } else {
        todayRecord.platformEventRecords.add(
          PlatformEventRecord(
            value: 1,
            platform: AppPlatform.current,
            dateStr: now.yyyymmddHHmmss,
          ),
        );
      }
    } else {
      statsDataImpl.totalWatchDurations.add(
        DailyEvent(
          dateStr: now.yyyymmdd,
          platformEventRecords: [
            PlatformEventRecord(
              value: 1,
              platform: AppPlatform.current,
              dateStr: now.yyyymmddHHmmss,
            ),
          ],
        ),
      );
    }
    stats.updateStats(
      id: anime.id,
      type: anime.sourceKey.hashCode,
      totalWatchDurations: statsDataImpl.totalWatchDurations,
    );
  }

  void updateStats({bool init = false}) async {
    final (statsDataImpl, todayRecord, platformRecord) = await stats
        .getOrCreateTodayPlatformRecord(
          id: anime.id,
          type: anime.sourceKey.hashCode,
          targetType: DailyEventType.watch,
        );

    platformRecord.value = platformRecord.value;

    if (!statsDataImpl.totalWatchDurations.contains(todayRecord)) {
      statsDataImpl.totalWatchDurations.add(todayRecord);
    }
    this.statsDataImpl = statsDataImpl;
    if (init) {
      await stats.addStats(statsDataImpl);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: VideoPage(playerController: playerController),
        ),
      ),
    );
  }

  // ---------------- 工具方法 ----------------

  /// 解析 loadAnimePages 返回值：String（旧）或 Map（AnimePlayResult）
  (String, AnimePlayResult?) _parsePlayResult(dynamic res) {
    if (res is String) return (res, null);
    if (res is Map) {
      try {
        final result = AnimePlayResult.fromJson(Map<String, dynamic>.from(res));
        return (result.url, result);
      } catch (_) {
        return ('', null);
      }
    }
    return ('', null);
  }

  /// 第 index 集的 key：剧集模式为 episode[线路] 的键，系列模式为系列条目 id
  String _episodeKey(int road, int index) => _isSeries
      ? _series![index - 1].id
      : anime.episode!.values.elementAt(road).keys.elementAt(index - 1);

  /// 系列模式下第 index 条系列条目（供 playerController 等外部访问）
  @override
  Anime? seriesAt(int index) =>
      _series != null && index >= 0 && index < _series!.length
      ? _series![index]
      : null;

  /// 当前线路的集数：剧集模式为线路内集数，系列模式为系列条目数
  int _episodeCount(int road) => _isSeries
      ? _series?.length ?? 0
      : anime.episode?.values.elementAt(road).length ?? 0;

  /// 播放器区域矩形（用于提示居中）
  Rect? _playerRect() {
    if (!mounted) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }
    return null;
  }

  /// 播放器上的居中 Gif 提示
  void _showCenterHint({
    required ImageProvider icon,
    required String message,
    Rect? playerRect,
    int seconds = 1,
  }) {
    showCenter(
      seconds: seconds,
      icon: Gif(
        image: icon,
        height: 80,
        fps: 120,
        color: icon == const AssetImage('assets/img/check.gif')
            ? Theme.of(context).colorScheme.primary
            : null,
        autostart: Autostart.once,
      ),
      message: message,
      context: context,
      centerRect: playerRect,
    );
  }

  /// 源提供播放进度上报接口时开始同步。
  /// 上报逻辑放在表层（watcher），由源自定义 playbackProgress/playbackStopped
  /// 回调，app 侧仅在播放中每 10s 触发一次
  void _startPlaybackReporting(String playUrl, AnimePlayResult? playResult) {
    final src = type.animeSource;
    if (src?.playbackProgress == null) return;
    _reportSource = src;
    _reportUrl = playUrl;
    _reportPlaySessionId = playResult?.playSessionId;
    _progressReportTimer?.cancel();
    _progressReportTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reportPlaybackProgress();
    });
    _reportPlaybackProgress();
  }

  void _reportPlaybackProgress() {
    final source = _reportSource;
    final url = _reportUrl;
    if (source?.playbackProgress == null || url == null || url.isEmpty) return;
    source!.playbackProgress!(
      url,
      playerController.currentPosition.inMilliseconds,
      playerController.duration.inMilliseconds,
      playerController.playing,
      _reportPlaySessionId,
    );
  }

  /// 停止上报并在退出前同步一次播放位置
  void _stopPlaybackReporting() {
    _progressReportTimer?.cancel();
    _progressReportTimer = null;
    final source = _reportSource;
    final url = _reportUrl;
    if (source?.playbackStopped != null && url != null && url.isNotEmpty) {
      source!.playbackStopped!(
        url,
        playerController.currentPosition.inMilliseconds,
        _reportPlaySessionId,
      );
    }
    _reportSource = null;
    _reportUrl = null;
    _reportPlaySessionId = null;
  }

  Future<bool> _isM3u8(String url) async {
    try {
      final resp = await AppDio().head(url);
      final ct = resp.headers.value('content-type') ?? '';
      return ct.contains('mpegurl');
    } catch (_) {
      return false;
    }
  }
}
