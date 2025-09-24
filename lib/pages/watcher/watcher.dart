// ignore_for_file: prefer_typing_uninitialized_variables

library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/stats.dart';
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

  final stats = StatsManager();

  // 当前播放列表
  late int currentRoad;

  Timer? updateHistoryTimer;

  AnimeType get type => anime.animeType;

  String get name => anime.title;

  Progress? progressFind;

  late StatsDataImpl statsDataImpl;

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
    updateStats(int: true);
    playerController.player.stream.completed.listen((completed) {
      if (completed) {
        if (progressFind != null) {
          try {
            if (!progressFind!.isCompleted) {
              HistoryManager().updateProgress(
                historyId: anime.id,
                type: anime.animeType,
                episode: epIndex - 1,
                road: playerController.currentRoad,
                isCompleted: true,
                endTime: DateTime.now(),
              );
              Log.addLog(
                LogLevel.info,
                "updateProgress",
                "update progress successful",
              );
            }
          } catch (e) {
            Log.addLog(LogLevel.error, "updateProgress", e.toString());
          }
        }

        playNextEpisode();
      }
    });
    Future.microtask(() async {
      if (history.lastWatchEpisode != 0) {
        loadInfo(history.lastWatchEpisode!, history.lastRoad!.toInt());
      }
      updateHistory();
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
    updateHistoryTimer?.cancel();
    playerController.dispose();
    playerController.disposeWindow();
    super.dispose();
  }

  // 播放下一集的逻辑
  Future<void> playNextEpisode() async {
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
    await _loadEpisode(episodeIndex: episodeIndex, road: road);
  }

  Future<void> loadNextlVideo(int episodeIndex) async {
    await _loadEpisode(
      episodeIndex: episodeIndex,
      road: playerController.currentRoad,
      checkRemainingTime: true,
    );
  }

  Future<void> _loadEpisode({
    required int episodeIndex,
    required int road,
    bool checkRemainingTime = false,
  }) async {
    if (anime.episode == null || road >= anime.episode!.length) {
      App.rootContext.showMessage(message: '线路不存在');
      return;
    }

    if (!checkRemainingTime &&
        episodeIndex == loaded &&
        road == playerController.currentRoad) {
      App.rootContext.showMessage(message: '加载重复集数');
      return;
    }
    epIndex = episodeIndex;
    Log.addLog(LogLevel.info, "加载剧集", "$episodeIndex");

    try {
      final progressFind = HistoryManager().progressFind(
        anime.id,
        AnimeType(anime.sourceKey.hashCode),
        epIndex - 1,
        road,
      );
      if (progressFind == null) {
        Log.addLog(
          LogLevel.warning,
          'progress not found',
          '$episodeIndex-$road',
        );
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

      if (checkRemainingTime) {
        final remainingMillis =
            playerController.player.state.duration.inMilliseconds -
            playerController.player.state.position.inMilliseconds;
        if (remainingMillis < 3 * 60 * 1000 && !progressFind.isCompleted) {
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

      time = progressFind.progressInMilli;

      var res = await type.animeSource!.loadAnimePages!(
        anime.id,
        anime.episode!.values.elementAt(road).keys.elementAt(epIndex - 1),
      );

      if (res is! String || res.isEmpty) {
        Log.addLog(LogLevel.error, "加载剧集", "$res 不合法");
        App.rootContext.showMessage(message: '获取视频链接异常');
        throw Exception("$res 不合法");
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
      updateHistory();
    } catch (e, s) {
      Log.addLog(LogLevel.error, "_loadEpisode", "$e\n$s");
      if (checkRemainingTime) rethrow;
    }
  }

  Future<void> _play(String res, int currentPlaybackTime) async {
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
    updateHistoryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (playerController.player.state.playing) {
        history.lastWatchTime =
            playerController.player.state.position.inMilliseconds;
        if (bangumiId != null) {
          history.bangumiId = bangumiId;
        }

        HistoryManager().addHistoryAsync(history);
        HistoryManager().updateProgress(
          historyId: anime.id,
          type: anime.animeType,
          episode: epIndex - 1,
          road: playerController.currentRoad,
          progressInMilli:
              playerController.player.state.position.inMilliseconds,
        );
        updateTotalWatchDurations();
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

  void updateStats({bool int = false}) async {
    final (statsDataImpl, todayRecord, platformRecord) = stats
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
    if (int) {
      await stats.addStats(statsDataImpl);
    }
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
                  tag: anime.id,
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
                  tag: anime.id,
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

  void updateHistory() {
    history.lastWatchEpisode = epIndex;
    history.allEpisode =
        anime.episode?.values.elementAt(playerController.currentRoad).length ??
        0;
    HistoryManager().addHistoryAsync(history);
  }
}

abstract mixin class _WatcherLocation {
  int epIndex = 1;

  bool get isLoading;

  var time = 0;

  var loaded = 0;

  void update();
}
