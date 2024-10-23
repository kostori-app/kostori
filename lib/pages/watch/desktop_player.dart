part of kostori_watcher;

class DesktopPlayer extends StatefulWidget {
  final PlayerController playerController;

  const DesktopPlayer({required this.playerController, super.key});

  @override
  State<DesktopPlayer> createState() => _DesktopPlayerState();
}

class _DesktopPlayerState extends State<DesktopPlayer> {
  @override
  Widget build(BuildContext context) {
    return MaterialDesktopVideoControlsTheme(
      normal: MaterialDesktopVideoControlsThemeData(
        topButtonBar: [
          if (widget.playerController.isFullScreen)
            MaterialCustomButton(
              onPressed: () =>
                  widget.playerController.toggleFullscreen(context),
              icon: const Icon(Icons.arrow_back),
            ),
        ],
        bottomButtonBar: [
          const MaterialDesktopPlayOrPauseButton(),
          MaterialCustomButton(
            onPressed: widget.playerController.playNextEpisode,
            icon: const Icon(Icons.skip_next),
          ),
          const MaterialDesktopVolumeButton(),
          const MaterialDesktopPositionIndicator(),
          const Spacer(),
          MaterialCustomButton(
              icon: const Icon(Icons.speed),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('选择播放速度'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('0.5x'),
                          onTap: () {
                            widget.playerController.setPlaybackSpeed(0.5);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('0.75x'),
                          onTap: () {
                            widget.playerController.setPlaybackSpeed(0.75);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('1.0x'),
                          onTap: () {
                            widget.playerController.setPlaybackSpeed(1);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('1.5x'),
                          onTap: () {
                            widget.playerController.setPlaybackSpeed(1.5);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('2.0x'),
                          onTap: () {
                            widget.playerController.setPlaybackSpeed(2);
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text('3.0x'),
                          onTap: () {
                            widget.playerController.setPlaybackSpeed(3);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          MaterialCustomButton(
              icon: const Icon(Icons.list), onPressed: () => null),
          // Observer(
          //     builder: (_) => MaterialDesktopCustomButton(
          //           icon: widget.playerController.isFullScreen
          //               ? const Icon(Icons.fullscreen_exit)
          //               : const Icon(Icons.fullscreen),
          //           onPressed: () =>
          //               widget.playerController.toggleFullscreen(context),
          //         )),
          const MaterialDesktopFullscreenButton()
        ],
      ),
      fullscreen: const MaterialDesktopVideoControlsThemeData(),
      child: Scaffold(
        body: Video(
          controller: widget.playerController.playerController,
          subtitleViewConfiguration:
              const SubtitleViewConfiguration(visible: false),
        ),
      ),
    );
  }
}
