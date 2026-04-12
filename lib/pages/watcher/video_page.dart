import 'dart:ui';

import 'package:extended_tabs/extended_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/player_item.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/remote.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:window_manager/window_manager.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with TickerProviderStateMixin, WindowListener {
  PlayerController get playerController => widget.playerController;
  late AnimationController animation;
  late Animation<Offset> _rightOffsetAnimation;
  late Animation<Offset> _bottomOffsetAnimation;
  late Animation<double> panelFade;
  late Animation<double> backgroundFade;

  late GridObserverController observerController;
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();

  ScrollController scrollController = ScrollController();

  // 当前播放列表
  late int currentRoad;

  // Tab controller for the side panel
  late TabController _panelTabController;

  void menuJumpToCurrentEpisode() {
    Future.delayed(const Duration(milliseconds: 20), () {
      observerController.jumpTo(
        index: playerController.currentEpisoded > 1
            ? playerController.currentEpisoded - 1
            : playerController.currentEpisoded,
      );
    });
  }

  void openTabBodyAnimated() {
    playerController.showTabBody = true;
    setState(() {});
    animation.forward();
  }

  void closeTabBodyAnimated() {
    animation.reverse();
  }

  @override
  void initState() {
    super.initState();
    observerController = GridObserverController(controller: scrollController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      playerController.overlayKey = _overlayKey;
    });
    animation = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    panelFade = Tween<double>(begin: 0, end: 1).animate(curved);

    backgroundFade = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 20),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 80,
      ),
    ]).animate(animation);

    _rightOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(curved);

    _bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(curved);

    animation.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        playerController.showTabBody = false;
        setState(() {});
      }
    });

    playerController.showTabBody = false;
    playerController.currentRoad = 0;
    currentRoad = 0;

    // Initialize panel tab controller with 3 tabs
    _panelTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    if (playerController.overlayKey == _overlayKey) {
      playerController.overlayKey = null;
    }
    observerController.controller?.dispose();
    _panelTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          playerController.isFullScreen == false &&
          playerController.showTabBody == false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (didPop) return;
        if (playerController.showTabBody) {
          closeTabBodyAnimated();
        } else if (playerController.isFullScreen) {
          await playerController.toggleFullScreen(context);
        }
      },
      child: Observer(
        builder: (context) => SafeArea(
          bottom: playerController.isPortraitFullscreen,
          top: false,
          left: playerController.isPortraitFullscreen
              ? false
              : !playerController.isFullScreen,
          right: playerController.isPortraitFullscreen
              ? false
              : !playerController.isFullScreen,
          child: Stack(
            alignment: playerController.isPortraitFullscreen
                ? Alignment.bottomCenter
                : Alignment.topRight,
            children: [
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: playerBody,
                ),
              ),

              // 显示播放列表
              IgnorePointer(
                ignoring: animation.status == AnimationStatus.dismissed,
                child: Stack(
                  children: [
                    FadeTransition(
                      opacity: backgroundFade,
                      child: GestureDetector(
                        onTap: closeTabBodyAnimated,
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              color: Colors.black.toOpacity(0.2),
                            ),
                          ),
                        ),
                      ),
                    ),

                    FadeTransition(
                      opacity: panelFade,
                      child: SlideTransition(
                        position: playerController.isPortraitFullscreen
                            ? _bottomOffsetAnimation
                            : _rightOffsetAnimation,
                        child: Align(
                          alignment: playerController.isPortraitFullscreen
                              ? Alignment.bottomCenter
                              : Alignment.topRight,
                          child: _buildPanel(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Overlay(key: _overlayKey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final isPortrait = playerController.isPortraitFullscreen;

    final height = isPortrait
        ? MediaQuery.of(context).size.height / 3 + 80
        : MediaQuery.of(context).size.height;

    final width = isPortrait
        ? MediaQuery.of(context).size.width
        : MediaQuery.of(context).size.width / 3 > 420
        ? 420 + 160
        : MediaQuery.of(context).size.width / 3 + 160;

    return Container(
      height: height.toDouble(),
      width: width.toDouble(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isPortrait ? Alignment.topCenter : Alignment.centerLeft,
          end: isPortrait ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black.toOpacity(0.3),
            Colors.black.toOpacity(0.6),
            Colors.black.toOpacity(0.8),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.toOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: ExtendedTabBarView(
                controller: _panelTabController,
                children: [
                  _buildPlaylistTab(),
                  _buildVideoInfoAndSettingsTab(),
                  _buildPlayerDetailsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _panelTabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: Theme.of(context).colorScheme.primary,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      tabs: [
        Tab(text: t.playlist),
        Tab(text: t.videoDetails),
        Tab(text: t.playerDetails),
      ],
    );
  }

  Widget _buildPlaylistTab() {
    return GridViewObserver(
      controller: observerController,
      child: Column(children: [_buildPlaylistHeader(), _buildPlaylistBody()]),
    );
  }

  Widget _buildPlaylistHeader() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              WatcherState.currentState!.anime.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          MenuAnchor(
            consumeOutsideTap: true,
            builder: (_, MenuController controller, _) {
              return TextButton(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () {
                  controller.isOpen ? controller.close() : controller.open();
                },
                child: Text(
                  WatcherState.currentState!.anime.episode!.keys.elementAt(
                    currentRoad,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              );
            },
            menuChildren: List<MenuItemButton>.generate(
              WatcherState.currentState!.anime.episode!.keys.length,
              (i) {
                final title = WatcherState.currentState!.anime.episode!.keys
                    .elementAt(i);
                final isCurrent = i == currentRoad;
                return MenuItemButton(
                  onPressed: () {
                    setState(() {
                      currentRoad = i;
                    });
                  },
                  child: Container(
                    height: 48,
                    constraints: const BoxConstraints(minWidth: 112),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistBody() {
    var cardList = <Widget>[];
    var roadList = WatcherState.currentState!.anime.episode ?? {};
    var selectedRoad = roadList.values.elementAt(currentRoad);
    final watcher = WatcherState.currentState!;

    int count = 1;

    for (var epKey in selectedRoad.keys) {
      int count0 = count;
      bool visited = (watcher.history.watchEpisode).contains(count0);
      cardList.add(
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: !visited
                ? context.colorScheme.surfaceContainer
                : Theme.of(context).colorScheme.primary.toOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: () async {
                closeTabBodyAnimated();
                playerController.currentRoad = currentRoad;
                await playerController.pause();
                playerController.playEpisode(count0, currentRoad);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        if (count0 == playerController.currentEpisoded &&
                            currentRoad ==
                                playerController.currentRoad) ...<Widget>[
                          Image.asset(
                            'assets/img/playing.gif',
                            color: Theme.of(context).colorScheme.primary,
                            height: 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            selectedRoad[epKey] ?? "",
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  (count0 == playerController.currentEpisoded &&
                                      currentRoad ==
                                          playerController.currentRoad)
                                  ? Color.lerp(
                                      Theme.of(context).colorScheme.primary,
                                      Colors.white,
                                      0.3,
                                    )
                                  : visited
                                  ? context.colorScheme.outline
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ),
                    const SizedBox(height: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      count++;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 0, right: 8, left: 8),
        child: GridView.builder(
          scrollDirection: Axis.vertical,
          controller: scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 5,
            childAspectRatio: 1.7,
          ),
          itemCount: cardList.length,
          itemBuilder: (context, index) {
            return cardList[index];
          },
        ),
      ),
    );
  }

  Widget _buildVideoInfoAndSettingsTab() {
    final anime = WatcherState.currentState!.anime;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video info section
          Text(
            anime.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (anime.subTitle != null && anime.subTitle!.isNotEmpty) ...[
            Text(
              anime.subTitle!,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          if (anime.description != null && anime.description!.isNotEmpty) ...[
            Text(
              t.synopsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              anime.description!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
          ],
          _buildInfoItem(
            t.currentEpisode,
            playerController.currentEpisoded.toString(),
          ),
          _buildInfoItem(t.playbackRoute, playerController.currentSetName),
          _buildInfoItem(
            t.progress,
            '${playerController.currentPosition.inSeconds}${t.secondsUnit} / ${playerController.duration.inSeconds}${t.secondsUnit}',
          ),
          const Divider(color: Colors.white24, height: 32),
          // Settings section
          // Playback speed slider
          Text(
            t.playbackSpeed,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                '0.5x',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: playerController.playbackSpeed,
                  min: 0.5,
                  max: 4.0,
                  divisions: 7,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.white24,
                  onChanged: (value) {
                    playerController.setPlaybackSpeed(value);
                    setState(() {});
                  },
                ),
              ),
              const Text(
                '4.0x',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Center(
            child: Text(
              '${playerController.playbackSpeed.toStringAsFixed(2)}x',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Super resolution section
          Text(
            t.superResolution,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              ButtonSegment<int>(value: 1, label: Text(t.superResolutionOff)),
              ButtonSegment<int>(
                value: 2,
                label: Text(t.superResolutionEfficiency),
              ),
              ButtonSegment<int>(
                value: 3,
                label: Text(t.superResolutionQuality),
              ),
            ],
            selected: {playerController.superResolutionType},
            onSelectionChanged: (Set<int> selected) {
              if (selected.isNotEmpty) {
                final type = selected.first;
                playerController.setShader(type);
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 24),
          // Other settings
          Text(
            t.otherSettings,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Audio option (Android only)
          if (App.isAndroid)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                title: Text(
                  (appdata.settings['audioOutType'] ?? true)
                      ? t.audioLowLatency
                      : t.audioCompatibility,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: CustomSwitch(
                  value: appdata.settings['audioOutType'] ?? true,
                  onChanged: (value) async {
                    try {
                      await playerController.changeAudioOutType();
                      App.rootContext.showMessage(message: t.switchSuccessful);
                      setState(() {});
                    } catch (e) {
                      App.rootContext.showMessage(message: t.switchFailed);
                    }
                  },
                ),
              ),
            ),
          // Light mode toggle
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                '${t.glimmerMode}: ${playerController.glimmerEffect ? t.glimmerModeOn : t.glimmerModeOff}',
                style: const TextStyle(color: Colors.white),
              ),
              trailing: CustomSwitch(
                value: playerController.glimmerEffect,
                onChanged: (value) {
                  playerController.glimmerEffect = value;
                  appdata.implicitData['glimmerEffect'] = value;
                  appdata.writeImplicitData();
                  setState(() {});
                },
              ),
            ),
          ),
          // Remote cast button
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(Icons.cast, color: Colors.white70),
              title: Text(
                t.remoteCast,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                bool needRestart = playerController.playing;
                playerController.pause();
                RemotePlay().castVideo(playerController.videoUrl).whenComplete(
                  () {
                    if (needRestart) {
                      playerController.play();
                    }
                  },
                );
              },
            ),
          ),
          // Logs button (only when not fullscreen)
          if (!playerController.isFullScreen)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.bug_report, color: Colors.white70),
                title: Text(
                  t.logs,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  context.to(() => const LogsPage());
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerDetailsTab() {
    return VideoInfoSheet.fromController(playerController);
  }

  Widget get playerBody {
    return PlayerItem(
      openMenu: openTabBodyAnimated,
      locateEpisode: menuJumpToCurrentEpisode,
      keyboardFocus: playerController.keyboardFocus,
      playerController: playerController,
    );
  }
}
