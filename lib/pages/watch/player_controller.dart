import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'anime_watch_page.dart';

class PlayerController {
  late final AnimeWatchingLogic logic;
  late final AnimeWatchPageState animeWatchPageState;
  late final player = Player();
  late final playerController = VideoController(player);

  bool isFullScreen = false; // 变为普通变量

  double playbackSpeed = 1;

  PlayerController(this.logic, this.animeWatchPageState);

  void playNextEpisode() {
    // 播放下一集的逻辑
    logic.order++;
    animeWatchPageState.loadInfo(logic.order); // 这里传递当前集数
  }

  void toggleFullscreen(BuildContext context) {
    isFullScreen = !isFullScreen; // 切换全屏状态
    // 这里可以添加全屏逻辑
  }

  void setPlaybackSpeed(double rate) {
    playbackSpeed = rate;
    player.setRate(rate);
  }

  void dispose() {
    // exitFullscreen();
    player.dispose(); // 释放播放器资源
    // focusNode.dispose(); // 释放焦点节点
  }
}
