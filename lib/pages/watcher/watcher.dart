// ignore_for_file: prefer_typing_uninitialized_variables

library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/m3u8_proxy_server.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:media_kit/media_kit.dart';

extension WatcherContext on BuildContext {
  WatcherState get watcher => findAncestorStateOfType<WatcherState>()!;
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
  State<Watcher> createState() => WatcherState();
}

class WatcherState extends State<Watcher>
    with _WatcherLocation, SingleTickerProviderStateMixin {
  static WatcherState? currentState;

  PlayerController get playerController => widget.playerController;

  WatcherController get watcherController => widget.watcherController;

  History get history => widget.watcherController.history!;

  AnimeDetails get anime => widget.watcherController.anime!;

  AnimeSource get animeSource => AnimeSource.find(anime.sourceKey)!;

  final stats = StatsManager();

  // 当前播放列表
  late int currentRoad;

  Timer? updateHistoryTimer;

  AnimeType get type => anime.animeType;

  String get name => anime.title;

  Progress? progressFind;

  late StatsDataImpl statsDataImpl;

  Map<String, String>? headers = {};

  @override
  void update() {
    setState(() {});
  }

  @override
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentState = this;
    playerController.changePlayerSettings();
    epIndex = 1;
    currentRoad = 0;
    updateStats(init: true);
    playerController.player.stream.completed.listen((completed) {
      if (completed) {
        playNextEpisode();
      }
    });
    Future.microtask(() async {
      headers = animeSource.httpHeaders;
      if (history.lastWatchEpisode != 0) {
        loadInfo(history.lastWatchEpisode!, history.lastRoad!.toInt());
      }
      await updateHistory();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playerController.initWindow();
  }

  int? bangumiId;

  @override
  void dispose() {
    currentState = null;
    updateHistoryTimer?.cancel();
    playerController.dispose();
    playerController.disposeWindow();
    super.dispose();
  }

  // 动态添加或更新请求头
  void setHeader(String key, String value) {
    headers?[key] = value;
  }

  // 播放下一集的逻辑
  Future<void> playNextEpisode({bool checkRemainingTime = true}) async {
    setState(() {
      // 如果已经是最后一集，避免超出范围
      if (epIndex <
          (anime.episode!.values
              .elementAt(playerController.currentRoad)
              .length)) {
        try {
          epIndex++;
          loadNextlVideo(epIndex);
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
          PlayLog.info("playNextEpisode", "加载剧集时出错");
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
        PlayLog.info("下一集", "没有更多剧集可播放");
      }
    });
  }

  Future<void> loadInfo(int episodeIndex, int road) async {
    await _loadEpisode(episodeIndex: episodeIndex, road: road);
  }

  Future<void> loadNextlVideo(int episodeIndex) async {
    await _loadEpisode(
      episodeIndex: episodeIndex,
      road: playerController.currentRoad,
    );
  }

  Future<void> _loadEpisode({
    required int episodeIndex,
    required int road,
  }) async {
    if (anime.episode == null || road >= anime.episode!.length) {
      App.rootContext.showMessage(message: '线路不存在');
      return;
    }

    if (episodeIndex == loaded && road == playerController.currentRoad) {
      App.rootContext.showMessage(message: '加载重复集数');
      return;
    }
    epIndex = episodeIndex;
    PlayLog.info("加载剧集", "$episodeIndex");

    try {
      final progressFind = await HistoryManager().progressFindAsync(
        anime.id,
        AnimeType(anime.sourceKey.hashCode),
        epIndex - 1,
        road,
      );
      if (progressFind == null) {
        PlayLog.warning('progress not found', '$episodeIndex-$road');
        return;
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

      var res = await type.animeSource!.loadAnimePages!(
        anime.id,
        anime.episode!.values.elementAt(road).keys.elementAt(epIndex - 1),
      );

      if (res is! String || res.isEmpty) {
        PlayLog.error("加载剧集", "$res 不合法");
        App.rootContext.showMessage(
          message: '获取视频链接异常: $res',
          level: LogLevel.error,
        );
        return;
      }

      await _play(res, time);

      playerController.currentRoad = road;
      playerController.currentEpisoded = episodeIndex;
      playerController.videoUrl = res;
      playerController.playing = true;
      playerController.updateCurrentSetName(epIndex);

      history.watchEpisode.add(epIndex);
      history.lastRoad = road;

      loaded = episodeIndex;
      await updateHistory();
    } catch (e, s) {
      PlayLog.error("_loadEpisode", "$e\n$s");
    }
  }

  Future<void> _play(String res, int currentPlaybackTime) async {
    try {
      if (mounted) {
        String actualPlayUrl = res;

        if (appdata.settings['m3u8AdFilterEnabled'] == true) {
          final isM3u8 =
              res.contains('.m3u8') ||
              res.contains('mpegurl') ||
              await _isM3u8(res);

          if (isM3u8) {
            actualPlayUrl = await M3u8ProxyServer.instance.proxyUrl(
              res,
              headers,
            );
            PlayLog.info('M3u8Proxy', '代理地址: $actualPlayUrl');
          }
        }

        playerController.playUrl = actualPlayUrl;
        playerController.videoHeaders = actualPlayUrl == res ? headers : null;
        PlayLog.info('_play', 'httpHraders: $headers');

        await playerController.player.open(
          Media(
            actualPlayUrl,
            httpHeaders: actualPlayUrl == res ? headers : {},
          ),
        );
      }
    } catch (e, s) {
      PlayLog.error("openMedia", "$e\n$s");
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
        completer.complete(0);
      }
    });
    // 等待 Completer 完成
    await completer.future;
    updateHistoryTimer?.cancel();
    if (!mounted) return;
    updateHistoryTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (playerController.player.state.playing) {
        history.lastWatchTime =
            playerController.player.state.position.inMilliseconds;
        if (bangumiId != null) {
          history.bangumiId = bangumiId;
        }

        await HistoryManager().addHistory(history);
        HistoryManager().updateProgress(
          historyId: anime.id,
          type: anime.animeType,
          episode: epIndex - 1,
          road: playerController.currentRoad,
          progressInMilli:
              playerController.player.state.position.inMilliseconds,
        );
        updateTotalWatchDurations();

        // 只在未完成时检查
        if (progressFind != null && !progressFind!.isCompleted) {
          final duration =
              playerController.player.state.duration.inMilliseconds;
          final position =
              playerController.player.state.position.inMilliseconds;
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
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: App.isDesktop
          ? Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.width * 0.45,
                    maxWidth: MediaQuery.of(context).size.width,
                  ),
                  child: VideoPage(playerController: playerController),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.width * 0.6,
                    maxWidth: MediaQuery.of(context).size.width,
                  ),
                  child: VideoPage(playerController: playerController),
                ),
              ),
            ),
    );
  }

  Future<void> updateHistory() async {
    history.lastWatchEpisode = epIndex;
    history.allEpisode =
        anime.episode?.values.elementAt(playerController.currentRoad).length ??
        0;
    if (anime.cover.trim().isNotEmpty) {
      history.cover = anime.cover;
    }
    await HistoryManager().addHistory(history);
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

abstract mixin class _WatcherLocation {
  int epIndex = 1;

  bool get isLoading;

  var time = 0;

  var loaded = 0;

  void update();
}
