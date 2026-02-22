import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerItemSurface extends StatefulWidget {
  const PlayerItemSurface({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<PlayerItemSurface> createState() => _PlayerItemSurfaceState();
}

class _PlayerItemSurfaceState extends State<PlayerItemSurface> {
  PlayerController get playerController => widget.playerController;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return AspectRatio(
          aspectRatio: playerController.isPortraitFullscreen ? 9 / 16 : 16 / 9,
          child: Video(
            controller: playerController.playerController,
            fill: Colors.transparent,
          ),
        );
      },
    );
  }
}
