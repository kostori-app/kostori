import 'package:flutter/material.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlayerItemSurface extends StatefulWidget {
  const PlayerItemSurface({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<PlayerItemSurface> createState() => _PlayerItemSurfaceState();
}

class _PlayerItemSurfaceState extends State<PlayerItemSurface> {
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: Video(
          controller: widget.playerController.playerController,
          // controls: NoVideoControls,
        ));
  }
}
