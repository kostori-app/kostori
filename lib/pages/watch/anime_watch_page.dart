library kostori_watcher;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kostori/network/girigirilove_network/ggl_models.dart';
import 'package:kostori/pages/watch/player_controller.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../anime_source/anime_source.dart';
import '../../base.dart';
import '../../components/window_frame.dart';
import '../../foundation/def.dart';
import '../../foundation/history.dart';
import '../../foundation/local_favorites.dart';
import '../../foundation/state_controller.dart';
import '../../network/girigirilove_network/ggl_network.dart';

part 'watching_data.dart';
part 'watching_logic.dart';
part 'desktop_player.dart';

class AnimeWatchPage extends StatefulWidget {
  static AnimeWatchPageState? currentState; // 静态变量
  final WatchingData watchingData;
  final int initialPlaying;
  final int initialEp;

  const AnimeWatchPage(this.watchingData, this.initialPlaying, this.initialEp,
      {super.key});

  AnimeWatchPage.gglAnime(GglAnimeInfo anime, this.initialEp,
      {super.key, this.initialPlaying = 1})
      : watchingData = GglWatchingData(
          anime.name,
          anime.id,
          anime.series.values.toList(),
          anime.epNames,
        );

  @override
  AnimeWatchPageState createState() {
    currentState = AnimeWatchPageState(); // 初始化静态变量
    return currentState!;
  }
}

class AnimeWatchPageState extends State<AnimeWatchPage> {
  late final History? history;
  late final Player player;
  late final VideoController controller;
  late final AnimeWatchingLogic logic;
  // late final PlayerController playerController;
  late final playerController = PlayerController(logic, this);

  @override
  void initState() {
    super.initState();

    // 初始化 History
    history = HistoryManager().findSync(widget.watchingData.id);

    // controller = VideoController(player);

    // 初始化 AnimeWatchingLogic 并存入状态管理
    logic = AnimeWatchingLogic(
      widget.initialEp,
      widget.watchingData,
      widget.initialPlaying,
      () => _updateHistory(logic, false),
    );
    // desktopPlayer = DesktopPlayer();
    // playerController = PlayerController(logic, this);
    // 初始化 Player 和 VideoController
    // 监听视频播放结束事件
    playerController.player.stream.completed.listen((completed) {
      if (completed) {
        playNextEpisode(); // 自动播放下一集
      }
    });
    StateController.put(logic);
    // 加载初始视频
    loadInitialVideo(logic);
    // 加载点击集数
    loadInfo(widget.initialEp); // 这里传入初始集数
  }

  @override
  void dispose() {
    // 释放 Player 和 Controller 资源
    // player.dispose();
    super.dispose();
    playerController.dispose();
  }

  void playNextEpisode() {
    // 播放下一集的逻辑
    setState(() {
      logic.order++;
      loadInfo(logic.order); // 这里传递当前集数
    });
  }

  void loadInfo(int episodeIndex) async {
    logic.order = episodeIndex; // 更新逻辑中的当前集数
    try {
      var res =
          await widget.watchingData.loadEp(episodeIndex); // 使用 episodeIndex
      await playerController.player.open(Media(res));
    } catch (e) {
      print("Error loading episode: $e");
    } finally {
      logic.isLoading = false;
      logic.update();
    }
  }

  void loadInitialVideo(AnimeWatchingLogic logic) async {
    try {
      var res = await widget.watchingData.loadEp(logic.order);
      await playerController.player.open(Media(res));
    } catch (e) {
      print("Error loading episode: $e");
    } finally {
      logic.isLoading = false;
      logic.update();
    }
  }

  void _updateHistory(AnimeWatchingLogic? logic, bool updateMePage) {
    if (widget.watchingData.hasEp) {
      if (logic!.order == 1 && logic.index == 1) {
        history?.ep = 0;
        history?.nowPlaying = 0;
      } else {
        if (logic.order == widget.watchingData.eps?.length) {
          history?.ep = 0;
          history?.nowPlaying = 0;
        } else {
          history?.ep = logic.order;
          history?.nowPlaying = logic.index;
        }
      }
    } else {
      if (logic!.index == 1) {
        history?.ep = 0;
        history?.nowPlaying = 0;
      } else {
        history?.ep = 1;
        history?.nowPlaying = logic.index;
      }
    }
    HistoryManager().saveReadHistory(history!, updateMePage);
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width,
            maxHeight: MediaQuery.of(context).size.width * 0.45,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DesktopPlayer(playerController: playerController),
          ),
        ),
      ),
    );
  }
}
