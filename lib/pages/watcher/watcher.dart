// ignore_for_file: prefer_typing_uninitialized_variables

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:media_kit/media_kit.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

extension WatcherContext on BuildContext {
  WatcherState get watcher => findAncestorStateOfType<WatcherState>()!;
}

class Watcher extends StatefulWidget {
  const Watcher({
    super.key,
    required this.type,
    required this.wid,
    required this.name,
    required this.episode,
    required this.anime,
    required this.history,
    this.initialWatchEpisode,
    this.initialEpisode,
    required this.playerController,
  });

  final AnimeType type;

  final String wid;

  final String name;

  final AnimeDetails anime;

  /// null if the comic is a gallery
  final Map<String, Map<String, String>>? episode;

  /// Starts from 1, invalid values equal to 1
  final int? initialWatchEpisode;

  /// Starts from 1, invalid values equal to 1
  final int? initialEpisode;

  final History history;

  final PlayerController playerController;

  @override
  State<Watcher> createState() => WatcherState();
}

class WatcherState extends State<Watcher>
    with _WatcherLocation, SingleTickerProviderStateMixin {
  static WatcherState? currentState; // 静态变量

  late final PlayerController playerController;

  late GridObserverController observerController;

  final stats = StatsManager();

  // 当前播放列表
  late int currentRoad;

  ScrollController scrollController = ScrollController();

  Timer? updateHistoryTimer;

  @override
  void update() {
    setState(() {});
  }

  AnimeType get type => widget.type;

  String get name => widget.name;

  History? history;

  Progress? progress;

  late StatsDataImpl statsDataImpl;

  dynamic ep;

  var time = 0;

  var loaded = 0;

  @override
  bool isLoading = false;

  @override
  int get maxEpisode => widget.episode?.length ?? 1;

  @override
  void onPageChanged() {
    updateHistory();
  }

  @override
  void initState() {
    super.initState();
    observerController = GridObserverController(controller: scrollController);
    playerController = widget.playerController;
    currentState = this;
    lastWatchTime = widget.initialWatchEpisode ?? 1;
    episode = widget.initialEpisode ?? 1;
    updateStats();
    playerController.player.stream.completed.listen((completed) {
      if (completed) {
        playNextEpisode();
      }
    });
    history = widget.history;
    progress = Progress.fromModel(
      model: widget.anime,
      episode: 0,
      road: 0,
      progressInMilli: 0,
    );
    Future.microtask(() {
      updateHistory();
    });
    if (history != null && history!.lastWatchEpisode != 0) {
      loadInfo(history!.lastWatchEpisode, history!.lastRoad.toInt());
    }
    currentRoad = 0;
    _initializeProgress();
    playerController.changePlayerSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playerController.initWindow();
  }

  int? bangumiId;

  @override
  void dispose() {
    observerController.controller?.dispose();
    playerController.dispose();
    updateHistoryTimer?.cancel();
    playerController.disposeWindow();
    super.dispose();
  }

  // 播放下一集的逻辑
  Future<void> playNextEpisode() async {
    setState(() {
      // 如果已经是最后一集，避免超出范围
      if (episode <
          (widget.anime.episode!.values
              .elementAt(playerController.currentRoad)
              .length)) {
        try {
          episode++;
          loadNextlVideo(episode);
          history?.watchEpisode.add(episode);
          showCenter(
            seconds: 1,
            icon: Gif(
              image: const AssetImage('assets/img/check.gif'),
              height: 80,
              fps: 120,
              color: Theme.of(context).colorScheme.primary,
              autostart: Autostart.once,
            ),
            message: '正在播放下一集',
            context: context,
          );
        } catch (e) {
          showCenter(
            seconds: 3,
            icon: Gif(
              image: AssetImage('assets/img/warning.gif'),
              height: 64,
              fps: 120,
              autostart: Autostart.once,
            ),
            message: '加载剧集时出错 ${e.toString()}',
            context: context,
          );
          Log.addLog(LogLevel.info, "playNextEpisode", "加载剧集时出错");
        }
      } else {
        showCenter(
          seconds: 3,
          icon: Gif(
            image: AssetImage('assets/img/warning.gif'),
            height: 64,
            fps: 120,
            autostart: Autostart.once,
          ),
          message: '没有更多剧集可播放',
          context: context,
        );
        Log.addLog(LogLevel.info, "下一集", "没有更多剧集可播放");
      }
    });
  }

  Future<void> loadInfo(int episodeIndex, int road) async {
    if (episodeIndex == loaded) {
      return;
    }

    ep = widget.anime.episode?.values.elementAt(road);

    Log.addLog(LogLevel.info, "加载剧集", "$episodeIndex");
    episode = episodeIndex;
    try {
      var progressFind = await HistoryManager().progressFind(
        widget.anime.id,
        AnimeType(widget.anime.sourceKey.hashCode),
        episode - 1,
        road,
      );
      playerController.currentRoad = road;

      history?.watchEpisode.add(episode);
      history?.lastRoad = road;
      progress?.road = road;
      progress?.episode = episode - 1;

      if (episodeIndex == history?.lastWatchEpisode) {
        time = history!.lastWatchTime;
      } else {
        time = progressFind!.progressInMilli;
      }
      var res = await type.animeSource!.loadAnimePages!(
        widget.wid,
        ep?.keys.elementAt(episode - 1),
      );
      if (res is! String || res.isEmpty) {
        Log.addLog(LogLevel.error, "加载剧集", "$res 不合法");
        throw Exception("$res 不合法");
      }
      playerController.currentEpisoded = episodeIndex;
      playerController.videoUrl = res;
      await _play(res, episode, time);
      loaded = episodeIndex;
      playerController.playing = true;
      playerController.updateCurrentSetName(episode);
      updateHistory();
    } catch (e, s) {
      Log.addLog(LogLevel.error, "loadInfo", "$e\n$s");
    }
  }

  Future<void> loadNextlVideo(int episodeIndex) async {
    ep = widget.anime.episode?.values.elementAt(playerController.currentRoad);
    episode = episodeIndex;
    Log.addLog(LogLevel.info, "加载剧集", "$episodeIndex");
    try {
      var progressFind = await HistoryManager().progressFind(
        widget.anime.id,
        AnimeType(widget.anime.sourceKey.hashCode),
        episode - 1,
        playerController.currentRoad,
      );

      history?.watchEpisode.add(episode);
      progress?.episode = episode - 1;

      if (progressFind!.progressInMilli != 0) {
        time = progressFind.progressInMilli;
      } else {
        time = 0;
      }
      var res = await type.animeSource!.loadAnimePages!(
        widget.wid,
        ep?.keys.elementAt(episode - 1),
      );
      if (res is! String || res.isEmpty) {
        Log.addLog(LogLevel.error, "加载剧集", "$res 不合法");
        throw Exception("$res 不合法");
      }
      playerController.currentEpisoded = episodeIndex;
      playerController.videoUrl = res;
      await _play(res, episode, time);
      loaded = episodeIndex;

      playerController.playing = true;
      playerController.updateCurrentSetName(episode);
      updateHistory();
    } catch (e, s) {
      Log.addLog(LogLevel.error, "loadNextlVideo", "$e\n$s");
      rethrow;
    }
  }

  Future<void> _play(String res, int order, int currentPlaybackTime) async {
    try {
      if (mounted) {
        await playerController.player.open(Media(res));
      }
    } catch (e, s) {
      Log.addLog(LogLevel.error, "openMedia", "$e\n$s");
    }
    // 监听缓冲流
    var sub = playerController.player.stream.buffer.listen(null);
    var completer = Completer();

    sub.onData((event) async {
      if (event.inMicroseconds > 0) {
        // This is a workaround for unable to await for `mediaPlayer.stream.buffer.first`
        // It seems that when the `buffer.first` is fired, the media is not fully loaded
        // and the player will not seek properlly.
        await sub.cancel();
        if (mounted) {
          try {
            await playerController.player.seek(
              Duration(milliseconds: currentPlaybackTime),
            );
          } catch (_) {}
        }
        completer.complete(0);
      }
    });
    // 等待 Completer 完成
    await completer.future;
    if (!mounted) return;
    updateHistoryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (playerController.player.state.playing) {
        history?.lastWatchTime =
            playerController.player.state.position.inMilliseconds;
        progress?.progressInMilli =
            playerController.player.state.position.inMilliseconds;
        if (bangumiId != null) {
          history?.bangumiId = bangumiId;
        }
        final todayRecord = statsDataImpl.totalWatchDurations.firstWhere(
          (c) =>
              c.date.year == DateTime.now().year &&
              c.date.month == DateTime.now().month &&
              c.date.day == DateTime.now().day,
        );
        final platformRecord = todayRecord.platformEventRecords.firstWhere(
          (p) => p.platform == AppPlatform.current,
        );
        platformRecord.value += 1;
        HistoryManager().addHistoryAsync(history!);
        HistoryManager().addProgress(progress!, widget.anime.animeId);
        stats.addStats(statsDataImpl);
      }
    });
  }

  void updateStats() async {
    final (statsDataImpl, todayRecord, platformRecord) = await stats
        .getOrCreateTodayPlatformRecord(
          id: widget.anime.id,
          type: widget.anime.sourceKey.hashCode,
          targetType: DailyEventType.watch,
        );

    platformRecord.value = platformRecord.value;

    if (!statsDataImpl.totalWatchDurations.contains(todayRecord)) {
      statsDataImpl.totalWatchDurations.add(todayRecord);
    }
    this.statsDataImpl = statsDataImpl;
    await stats.addStats(statsDataImpl);
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: App.isDesktop
          ? Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: Hero(
                  tag: widget.anime.id,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.45,
                      maxWidth: MediaQuery.of(context).size.width,
                    ),
                    child: VideoPage(playerController: playerController),
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Hero(
                  tag: widget.anime.id,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.6,
                      maxWidth: MediaQuery.of(context).size.width,
                    ),
                    child: VideoPage(playerController: playerController),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _initializeProgress() async {
    // 获取所有需要处理的 episodes，并将每种类型的 road 设置为对应的数字
    final allEpisodes = widget.anime.episode ?? {};

    // 遍历 episodes
    int roadCounter = 0; // 用于区分 episode, episode2, episode3 的 road 值
    for (var entry in allEpisodes.entries) {
      final episodes = entry
          .value; // Map<String, String> { '1': '/path/to/episode1.mp4', ... }

      // 使用 entries.asMap() 来获取索引和键值对
      for (var index = 0; index < episodes.length; index++) {
        final road = roadCounter; // 这里 road 值不随着 index 递增，而是随着 episodeType 递增

        // 检查是否已经存在
        final exists = await HistoryManager().checkIfProgressExists(
          widget.anime.animeId, // historyId
          AnimeType(widget.anime.sourceKey.hashCode), // type
          index, // episode
          road, // road
        );
        if (!exists) {
          // 不存在时插入数据
          final newProgress = Progress.fromModel(
            model: widget.anime,
            episode: index,
            road: road,
            progressInMilli: 0,
          );
          await HistoryManager().addProgress(newProgress, widget.anime.animeId);
        }
      }
      roadCounter++; // 每处理一个类型的 episode 后，road 值递增
    }
  }

  void updateHistory() {
    if (history != null) {
      history!.lastWatchEpisode = episode;
      history!.allEpisode = widget.episode!.values
          .elementAt(playerController.currentRoad)
          .length;
      HistoryManager().addHistoryAsync(history!);
    }
  }
}

abstract mixin class _WatcherLocation {
  int _lastWatchTime = 0;

  int get lastWatchTime => _lastWatchTime;

  set lastWatchTime(int value) {
    _lastWatchTime = value;
    onPageChanged();
  }

  int episode = 1;

  int get maxEpisode;

  bool get isLoading;

  void update();

  bool get enablePageAnimation => appdata.settings['enablePageAnimation'];

  void onPageChanged();
}
