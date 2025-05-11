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
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/video_page.dart';
import 'package:kostori/utils/data_sync.dart';
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

  @override
  State<Watcher> createState() => WatcherState();
}

class WatcherState extends State<Watcher>
    with _WatcherLocation, SingleTickerProviderStateMixin {
  static WatcherState? currentState; // 静态变量

  late final PlayerController playerController;

  late GridObserverController observerController;

  // 当前播放列表
  late int currentRoad;

  ScrollController scrollController = ScrollController();

  Timer updateHistoryTimer = Timer.periodic(Duration(days: 1), (timer) {});

  @override
  void update() {
    setState(() {});
  }

  AnimeType get type => widget.type;

  String get name => widget.name;

  History? history;

  Progress? progress;

  var ep;

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
    playerController = PlayerController();
    currentState = this;
    lastWatchTime = widget.initialWatchEpisode ?? 1;
    episode = widget.initialEpisode ?? 1;

    playerController.player.stream.completed.listen((completed) {
      if (completed) {
        playNextEpisode();
      }
    });
    history = widget.history;
    progress = Progress.fromModel(
        model: widget.anime, episode: 0, road: 0, progressInMilli: 0);

    Log.addLog(LogLevel.info, "历史", "$history");
    Future.microtask(() {
      updateHistory();
    });
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (history != null && history!.lastWatchEpisode != 0) {
      loadInfo(
          history!.lastWatchEpisode, history!.lastRoad.toInt()); // 这里传入初始集数
    }
    currentRoad = 0;
    _initializeProgress();
    playerController.changePlayerSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    playerController.initReaderWindow();
  }

  int? bangumiId;

  @override
  void dispose() {
    observerController.controller?.dispose();
    playerController.dispose();
    updateHistoryTimer.cancel();
    Future.microtask(() {
      DataSync().onDataChanged();
    });
    playerController.disposeReaderWindow();
    super.dispose();
  }

  void playNextEpisode() {
    // 播放下一集的逻辑
    setState(() {
      // 如果已经是最后一集，避免超出范围
      if (episode <
          (widget.anime.episode!.values
              .elementAt(playerController.currentRoad)
              .length)) {
        episode++; // 递增到下一集
        loadNextlVideo(episode); // 直接调用 loadInfo 加载下一集
        history?.watchEpisode.add(episode); // 记录观看的集数
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
            context: context);
        Log.addLog(LogLevel.info, "下一集", "没有更多剧集可播放");
      }
    });
  }

  void loadInfo(int episodeIndex, int road) async {
    if (episodeIndex == loaded) {
      return;
    }

    ep = widget.anime.episode?.values.elementAt(road);

    Log.addLog(LogLevel.info, "加载集数", "$episodeIndex");
    episode = episodeIndex; // 更新逻辑中的当前集数
    try {
      var progressFind = await HistoryManager().progressFind(widget.anime.id,
          AnimeType(widget.anime.sourceKey.hashCode), episode - 1, road);
      Log.addLog(LogLevel.info, "加载找寻参数",
          "${widget.anime.id}\n${AnimeType(widget.anime.sourceKey.hashCode).value}\n${episode - 1}\n$road");
      playerController.currentRoad = road;
      playerController.currentEpisoded = episodeIndex;
      history?.watchEpisode.add(episode); // 记录观看的集数
      history?.lastRoad = road;
      progress?.road = road;
      progress?.episode = episode - 1;

      if (episodeIndex == history?.lastWatchEpisode) {
        time = history!.lastWatchTime;
      } else {
        time = progressFind!.progressInMilli;
      }
      Log.addLog(LogLevel.info, "本集时间", "$progressFind!.progressInMilli");
      var res = await type.animeSource!.loadAnimePages!(
          widget.wid, ep?.keys.elementAt(episode - 1));
      Log.addLog(LogLevel.info, "载入上次观看时间", "$time");
      Log.addLog(LogLevel.info, "视频链接", res);
      await _play(res, episode, time);
      loaded = episodeIndex;
      playerController.playing = true;
      playerController.updateCurrentSetName(episode);
      updateHistory();
    } catch (e, s) {
      Log.addLog(LogLevel.error, "加载剧集", "$e\n$s");
    } finally {}
  }

  void loadNextlVideo(int episodeIndex) async {
    ep = widget.anime.episode?.values.elementAt(playerController.currentRoad);
    episode = episodeIndex; // 更新逻辑中的当前集数
    Log.addLog(LogLevel.error, "加载集数", "$episodeIndex");
    try {
      var progressFind = await HistoryManager().progressFind(
          widget.anime.id,
          AnimeType(widget.anime.sourceKey.hashCode),
          episode - 1,
          playerController.currentRoad);
      playerController.currentEpisoded = episodeIndex;
      history?.watchEpisode.add(episode); // 记录观看的集数
      progress?.episode = episode - 1;

      if (progressFind!.progressInMilli != 0) {
        time = progressFind.progressInMilli;
      } else {
        time = 0;
      }
      var res = await type.animeSource!.loadAnimePages!(
          widget.wid, ep?.keys.elementAt(episode - 1));
      Log.addLog(LogLevel.info, "视频链接", res);
      await _play(res, episode, time);
      loaded = episodeIndex;

      playerController.playing = true;
      playerController.updateCurrentSetName(episode);
      updateHistory();
    } catch (e, s) {
      Log.addLog(LogLevel.error, "加载剧集", "$e\n$s");
    } finally {}
  }

  void retry() {
    setState(() {});
  }

  Future<void> _play(String res, int order, int currentPlaybackTime) async {
    try {
      // 打开媒体
      await playerController.player.open(Media(res));
    } catch (e, s) {
      Log.addLog(LogLevel.error, "打开媒体", "$e\n$s");
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

        await playerController.player
            .seek(Duration(milliseconds: currentPlaybackTime));
        completer.complete(0);
      }
    });
    // 等待 Completer 完成
    await completer.future;
    updateHistoryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (playerController.player.state.playing) {
        history?.lastWatchTime =
            playerController.player.state.position.inMilliseconds;
        progress?.progressInMilli =
            playerController.player.state.position.inMilliseconds;
        if (bangumiId != null) {
          history?.bangumiId = bangumiId;
        }
        HistoryManager().addHistoryAsync(history!);
        HistoryManager().addProgress(progress!, widget.anime.animeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: App.isDesktop
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.45,
                      maxWidth: MediaQuery.of(context).size.width,
                    ),
                    child: VideoPage(
                      playerController: playerController,
                    ),
                  )),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.width * 0.6,
                      maxWidth: MediaQuery.of(context).size.width,
                    ),
                    child: VideoPage(
                      playerController: playerController,
                    ),
                  )),
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
            model: widget.anime, // 使用 AnimeDetails 对象实现 HistoryMixin
            episode: index, // 假设 episodeId 可解析为集数
            road: road, // 当前 episode 类型对应的 road
            progressInMilli: 0, // 默认初始进度为 0
          );
          await HistoryManager().addProgress(newProgress, widget.anime.animeId);
        }
      }
      roadCounter++; // 每处理一个类型的 episode 后，road 值递增
    }
  }

  Timer? _updateHistoryTimer;

  void updateHistory() {
    if (history != null) {
      history!.lastWatchEpisode = episode;
      history!.allEpisode =
          widget.episode!.values.elementAt(playerController.currentRoad).length;
      _updateHistoryTimer?.cancel();
      _updateHistoryTimer = Timer(const Duration(seconds: 1), () {
        HistoryManager().addHistoryAsync(history!);
        _updateHistoryTimer = null;
      });
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
