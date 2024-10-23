import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../foundation/history.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({Key? key}) : super(key: key);

  @override
  VideoPlayerWidgetState createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final Player player;
  late final VideoController controller;
  HistoryManager historyManager = HistoryManager();

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    // 监听视频播放结束事件
    player.stream.completed.listen((completed) {
      if (completed) {
        // playNextEpisode(); // 自动播放下一集
      }
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  // 更新视频链接的方法
  void updateVideo(String newUrl) {
    player.open(Media(newUrl));
  }

  Widget buildVideoPlayer() {
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
            child: Video(controller: controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildVideoPlayer();
  }
}
