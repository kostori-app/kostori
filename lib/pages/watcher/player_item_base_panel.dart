import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/watcher/player_controller.dart';

class PlayerItemBasePanel extends StatefulWidget {
  const PlayerItemBasePanel({
    super.key,
    required this.playerController,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarDragEnd,
    required this.animationController,
    required this.currentPosition,
    required this.buffer,
    required this.duration,
  });

  final PlayerController playerController;
  final AnimationController animationController;
  final void Function(ThumbDragDetails details) handleProgressBarDragStart;
  final void Function() handleProgressBarDragEnd;

  final Duration currentPosition;
  final Duration buffer;
  final Duration duration;

  @override
  State<PlayerItemBasePanel> createState() => _PlayerItemBasePanelState();
}

class _PlayerItemBasePanelState extends State<PlayerItemBasePanel> {
  PlayerController get playerController => widget.playerController;
  late final Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            //底部进度条
            AnimatedOpacity(
              opacity:
                  ((!playerController.isFullScreen &&
                          !playerController.showVideoController) ||
                      playerController.isSeek)
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 底部渐变层
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      tween: Tween<double>(
                        begin: playerController.isSeek ? 0.0 : 1.0,
                        end: playerController.isSeek ? 1.0 : 0.0,
                      ),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.black.toOpacity(0.1),
                                  Colors.black.toOpacity(0.25),
                                  Colors.black.toOpacity(0.45),
                                  Colors.black.toOpacity(0.6),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.toOpacity(0.15),
                                  blurRadius: 10.0,
                                  spreadRadius: 2.0,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      tween: Tween<double>(
                        begin: playerController.isSeek ? 0.0 : 1.0,
                        end: playerController.isSeek ? 1.0 : 0.0,
                      ),
                      builder: (context, value, child) {
                        return ProgressBar(
                          thumbRadius: 6 * value,
                          thumbGlowRadius: 0,
                          barHeight: 2 + 2 * value,
                          progressBarColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.72),
                          bufferedBarColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.36),
                          baseBarColor: Theme.of(
                            context,
                          ).colorScheme.primary.toOpacity(0.2),
                          timeLabelLocation: TimeLabelLocation.none,
                          progress: widget.currentPosition,
                          buffered: widget.buffer,
                          total: widget.duration,
                          onSeek: (duration) {
                            playerController.seek(duration);
                          },
                          onDragStart: (details) {
                            widget.handleProgressBarDragStart(details);
                          },
                          onDragUpdate: (details) {
                            playerController.currentPosition =
                                details.timeStamp;
                          },
                          onDragEnd: () {
                            widget.handleProgressBarDragEnd();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            FadeTransition(
              opacity: fadeAnimation,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      Colors.transparent,
                      Colors.black.toOpacity(0.2),
                      Colors.black.toOpacity(0.5),
                      Colors.black.toOpacity(0.7),
                    ],
                    stops: const [0.0, 0.6, 0.85, 1.0],
                  ),
                ),
              ),
            ),
            // 顶部进度条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerController.showSeekTime
                    ? Wrap(
                        key: ValueKey<bool>(playerController.showSeekTime),
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.toOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              playerController.currentPosition.compareTo(
                                        playerController.player.state.position,
                                      ) >
                                      0
                                  ? '快进 ${playerController.currentPosition.inSeconds - playerController.player.state.position.inSeconds} 秒'
                                  : '快退 ${playerController.player.state.position.inSeconds - playerController.currentPosition.inSeconds} 秒',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : Container(key: UniqueKey()),
              ),
            ),
            // 顶部播放速度条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerController.showPlaySpeed
                    ? Wrap(
                        key: UniqueKey(),
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.toOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: <Widget>[
                                AnimatedPlayIconWave(
                                  size: 14,
                                  count: playerController.playbackSpeed.toInt(),
                                ),
                                Text(
                                  '${playerController.playbackSpeed.toInt()}X',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(key: UniqueKey()),
              ),
            ),
            // 亮度条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerController.showBrightness
                    ? Wrap(
                        key: ValueKey<bool>(playerController.showBrightness),
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.toOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.brightness_7_rounded,
                                  color: Colors.white,
                                ),
                                Text(
                                  ' ${(playerController.brightness * 100).toInt()} %',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(key: UniqueKey()),
              ),
            ),
            // 音量条
            Positioned(
              top: playerController.isPortraitFullscreen ? 140 : 50,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: playerController.showVolume
                    ? Wrap(
                        key: ValueKey<bool>(playerController.showVolume),
                        alignment: WrapAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.toOpacity(0.5),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.volume_down_rounded,
                                  color: Colors.white,
                                ),
                                Text(
                                  ' ${(playerController.volume).toInt()}%',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(key: UniqueKey()),
              ),
            ),
          ],
        );
      },
    );
  }
}
