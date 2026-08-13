import 'dart:async';
import 'dart:ui';

import 'package:extended_tabs/extended_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/hub/hub_chat_page.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/watcher/danmaku_settings.dart';
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

  // 聊天面板动画（与 _buildPanel 同款 Fade + Slide）
  late AnimationController _chatAnimation;
  late Animation<double> _chatFade;
  late Animation<Offset> _chatSlide;

  late GridObserverController observerController;
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();

  // 全屏时一起看聊天浮层开关
  bool _showChatOverlay = false;

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

    // 聊天面板动画：从右侧滑入 + 淡入
    _chatAnimation = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _chatSlide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _chatAnimation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _chatFade = CurvedAnimation(
      parent: _chatAnimation,
      curve: Curves.easeInOut,
    );

    // Initialize panel tab controller with 3 tabs
    _panelTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    if (playerController.overlayKey == _overlayKey) {
      playerController.overlayKey = null;
    }
    observerController.controller?.dispose();
    _chatAnimation.dispose();
    _panelTabController.dispose();
    super.dispose();
  }

  /// 关闭聊天面板（触发滑出动画）
  void _closeChatOverlay() {
    if (!_showChatOverlay) return;
    setState(() => _showChatOverlay = false);
    _chatAnimation.reverse();
    // 恢复控制栏自动隐藏
    playerController.chatOverlayOpen = false;
    playerController.canHidePlayerPanel = true;
  }

  /// 全屏时一起看聊天浮层（在房间时显示）
  Widget _buildChatOverlay(BuildContext context) {
    // 用当前 ProviderScope 容器读取，与 ref/ConsumerState 一致
    final hub = ProviderScope.containerOf(context).read(hubProvider);
    final roomId = hub.currentRoomId;
    final inRoom =
        hub.isConnected && roomId != null && roomId != hub.lobbyRoomId;
    DebugLog.info(
      'VideoPage',
      'chatOverlay: fs=${playerController.isFullScreen} '
          'inRoom=$inRoom connected=${hub.isConnected} '
          'roomId=$roomId lobby=${hub.lobbyRoomId}',
    );
    if (!inRoom) return const SizedBox.shrink();
    return Stack(
      children: [
        // 点击面板外区域关闭聊天面板（类似 _buildPanel 点击外部消失）
        if (_showChatOverlay)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _closeChatOverlay(),
              child: Container(color: Colors.transparent),
            ),
          ),
        // 聊天面板：与 _buildPanel 同款 Fade + Slide 动画，约四分之一屏宽半透明
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            // 键盘弹出时面板底部上移，输入框不被遮挡
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: FadeTransition(
              opacity: _chatFade,
              child: SlideTransition(
                position: _chatSlide,
                child: GestureDetector(
                  // 手机边缘右滑退出窗口
                  onHorizontalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) > 300) {
                      _closeChatOverlay();
                    }
                  },
                  child: IgnorePointer(
                    ignoring: !_showChatOverlay,
                    child: Container(
                      width: (MediaQuery.sizeOf(context).width / 4).clamp(
                        260,
                        420,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        child: HubChatPage(
                          roomId: roomId,
                          roomName: hub.currentRoomName ?? '',
                          embedded: true,
                          showWatchCard: false,
                          // 播放器全屏聊天面板是 Stack 覆盖层（无 Scaffold 调整），需手动补偿键盘
                          manualKeyboardPadding: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
              // 全屏时一起看聊天浮层（Positioned.fill 覆盖全屏，供点击层/面板定位）
              if (playerController.isFullScreen)
                Positioned.fill(child: _buildChatOverlay(context)),
              // 全屏弹幕层（独立 State，父级 rebuild 不影响弹幕动画）
              if (playerController.isFullScreen)
                const Positioned.fill(child: _DanmakuOverlay()),
            ],
          ),
        ),
      ),
    );
  }

  /// 当前观看的番剧（替代重复的 WatcherState.currentState!.anime）
  AnimeDetails get _panelAnime => WatcherState.currentState!.anime;

  /// 面板内统一的分区标题
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// 面板内统一的说明行（标签 + 值）
  Widget _infoItem(String label, String value) {
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

  /// 秒数 → mm:ss / h:mm:ss
  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _buildPanel(BuildContext context) {
    final isPortrait = playerController.isPortraitFullscreen;

    // 面板尺寸：竖屏底部约 1/3 屏高，横屏右侧约 1/3 屏宽（限宽 420+160）
    final height = isPortrait
        ? MediaQuery.of(context).size.height / 3 + 80
        : MediaQuery.of(context).size.height;

    final width = isPortrait
        ? MediaQuery.of(context).size.width
        : (MediaQuery.of(context).size.width / 3).clamp(0, 420) + 160;

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
              _panelAnime.title,
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
                  _panelAnime.episode!.keys.elementAt(currentRoad),
                  style: const TextStyle(fontSize: 13),
                ),
              );
            },
            menuChildren: List<MenuItemButton>.generate(
              _panelAnime.episode!.keys.length,
              (i) {
                final title = _panelAnime.episode!.keys.elementAt(i);
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
    var roadList = _panelAnime.episode ?? {};
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
    final anime = _panelAnime;
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
              if (anime.description != null &&
                  anime.description!.isNotEmpty) ...[
                _sectionTitle(t.synopsis),
                const SizedBox(height: 8),
                Text(
                  anime.description!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
              _infoItem(
                t.currentEpisode,
                playerController.currentEpisoded.toString(),
              ),
              _infoItem(t.playbackRoute, playerController.currentSetName),
              _infoItem(
                t.progress,
                '${_fmtDuration(playerController.currentPosition)} / ${_fmtDuration(playerController.duration)}',
              ),
              const Divider(color: Colors.white24, height: 32),
              // Playback speed
              _sectionTitle(t.playbackSpeed),
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
              // Super resolution
              _sectionTitle(t.superResolution),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(t.superResolutionOff),
                  ),
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
                    playerController.setShader(selected.first);
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 24),
              // Other settings
              _sectionTitle(t.otherSettings),
              const SizedBox(height: 8),
              if (App.isAndroid)
                _settingsTile(
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
                          App.rootContext.showMessage(
                            message: t.switchSuccessful,
                          );
                          setState(() {});
                        } catch (e) {
                          App.rootContext.showMessage(message: t.switchFailed);
                        }
                      },
                    ),
                  ),
                ),
              _settingsTile(
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
              if (!playerController.isFullScreen)
                _settingsTile(
                  child: ListTile(
                    leading: const Icon(
                      Icons.bug_report,
                      color: Colors.white70,
                    ),
                    title: Text(
                      t.logs,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => context.to(() => const LogsPage()),
                  ),
                ),
            ],
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Row(
              children: [
                // Cast 按钮
                _bottomAction(
                  icon: Icons.cast,
                  label: t.remoteCast,
                  onTap: () {
                    bool needRestart = playerController.playing;
                    playerController.pause();
                    RemotePlay()
                        .castVideo(playerController.videoUrl)
                        .whenComplete(() {
                          if (needRestart) playerController.play();
                        });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerDetailsTab() {
    return VideoInfoSheet.fromController(playerController);
  }

  Widget get playerBody {
    return PlayerItem(
      openMenu: openTabBodyAnimated,
      onChatToggle: () {
        setState(() => _showChatOverlay = !_showChatOverlay);
        if (_showChatOverlay) {
          _chatAnimation.forward();
          // 聊天面板打开时禁用控制栏自动隐藏，避免打字过程中面板收起/失焦
          playerController.chatOverlayOpen = true;
          playerController.canHidePlayerPanel = false;
          playerController.showVideoController = true;
        } else {
          _chatAnimation.reverse();
          playerController.chatOverlayOpen = false;
          playerController.canHidePlayerPanel = true;
        }
      },
      locateEpisode: menuJumpToCurrentEpisode,
      keyboardFocus: playerController.keyboardFocus,
      playerController: playerController,
    );
  }
}

/// 全屏弹幕层：独立 State 管理弹幕列表与消息监听，
/// 父级（VideoPage）rebuild 不影响弹幕动画
class _DanmakuOverlay extends StatefulWidget {
  const _DanmakuOverlay();

  @override
  State<_DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<_DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  final List<_DanmakuData> _danmaku = [];
  HubClient? _chatClient;
  ProviderContainer? _container;
  late final AnimationController _ticker;
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    // 统一 vsync 时钟驱动弹幕每帧重绘，与视频帧调度同步
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(minutes: 5),
    );
    _ticker.addListener(_checkExpired);
    // 低频清理超时弹幕（避免频繁 setState 导致动画卡顿）
    _cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _cleanup();
    });
    // 弹幕样式配置变化时刷新（字号/行高/区域/时长）
    appdata.implicitVersion.addListener(_onStyleChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_container == null) {
      _container = ProviderScope.containerOf(context);
      _chatClient = _container!.read(hubClientProvider);
      _chatClient?.addMessageListener(_onChatMessage);
    }
  }

  @override
  void dispose() {
    appdata.implicitVersion.removeListener(_onStyleChanged);
    _cleanupTimer?.cancel();
    _ticker.dispose();
    _chatClient?.removeMessageListener(_onChatMessage);
    for (final d in _danmaku) {
      d.dispose();
    }
    super.dispose();
  }

  void _onStyleChanged() {
    if (!mounted) return;
    // 样式变更后旧弹幕仍按旧参数绘制会错位，直接清空重来
    for (final d in _danmaku) {
      d.dispose();
    }
    setState(_danmaku.clear);
  }

  /// 依据「显示区域 + 行高」计算可用的弹幕轨道数
  int _trackCount(double screenHeight) {
    final usable = screenHeight * DanmakuSettings.area - 44;
    final count = (usable / DanmakuSettings.lineHeight).floor();
    return count.clamp(1, 60);
  }

  void _checkExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    for (final d in List.of(_danmaku)) {
      if (now - d.spawnMs >= d.durationMs) {
        _danmaku.remove(d);
        d.dispose();
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
    // 弹幕清空后停止时钟
    if (_danmaku.isEmpty && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  void _cleanup() {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    for (final d in List.of(_danmaku)) {
      if (now - d.spawnMs >= d.durationMs) {
        _danmaku.remove(d);
        d.dispose();
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
    if (_danmaku.isEmpty && _ticker.isAnimating) {
      _ticker.stop();
    }
  }

  void _onChatMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = HubEvent.fromJson(data);
    if (event is! HubEventMessage) return;
    if (event.isUnicast) return;
    final msg = event.message;
    if (isHubSyncMessage(msg)) return;
    // 自己的消息也显示弹幕，便于确认发送成功
    final text = msg.plainText.trim();
    if (text.isEmpty) return;
    if (!_ticker.isAnimating) _ticker.repeat();
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _danmaku.add(
        _DanmakuData.create(
          name: msg.sender.displayName,
          text: text,
          nameColor: _nameColor(msg.sender.userId),
          track: _danmaku.length % _trackCount(size.height),
          screenWidth: size.width,
          fontSize: DanmakuSettings.fontSize,
          textColor: DanmakuSettings.color,
          opacity: DanmakuSettings.opacity,
          durationSec: DanmakuSettings.duration,
        ),
      );
      if (_danmaku.length > 30) _danmaku.removeAt(0);
    });
  }

  /// 依据 userId 生成稳定的发言人颜色（按色相分散，便于区分）
  Color _nameColor(String userId) {
    final hue = (userId.hashCode % 360).abs().toDouble();
    return HSVColor.fromAHSV(1, hue, 0.55, 1.0).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      // RepaintBoundary 隔离弹幕重绘，不影响上层视频画面
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size(size.width, size.height),
          painter: _DanmakuPainter(
            danmaku: _danmaku,
            screenWidth: size.width,
            lineHeight: DanmakuSettings.lineHeight,
            trackCount: _trackCount(size.height),
            repaint: _ticker,
          ),
        ),
      ),
    );
  }
}

/// 弹幕数据（含绘制缓存：描边层 + 填充层合成一张 ui.Picture，每帧仅 drawPicture）
class _DanmakuData {
  final int id;
  final String text;
  final int track;
  final int spawnMs;
  final int durationMs;
  final Picture picture;
  final double width;

  _DanmakuData._({
    required this.id,
    required this.text,
    required this.track,
    required this.spawnMs,
    required this.durationMs,
    required this.picture,
    required this.width,
  });

  factory _DanmakuData.create({
    required String name,
    required String text,
    required Color nameColor,
    required Color textColor,
    required int track,
    required double screenWidth,
    required double fontSize,
    required double opacity,
    required double durationSec,
  }) {
    const strokeColor = Colors.black;
    final strokeWidth = (fontSize / 12).clamp(1.5, 3.5);
    final baseStyle = TextStyle(
      fontSize: fontSize,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );

    // 外层描边：文本 + 名字分别描边，再叠加填充
    final strokeStyle = baseStyle.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = strokeColor.withValues(alpha: opacity),
    );
    final nameStroke = strokeStyle.copyWith(fontWeight: FontWeight.w800);
    final fillStyle = baseStyle.copyWith(
      color: textColor.withValues(alpha: opacity),
      shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
    );
    final nameFill = baseStyle.copyWith(
      color: nameColor.withValues(alpha: opacity),
      fontWeight: FontWeight.w800,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
    );

    final tp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: '$name: ', style: nameFill),
          TextSpan(text: text, style: fillStyle),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: screenWidth * 0.6);
    final strokeTp = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: '$name: ', style: nameStroke),
          TextSpan(text: text, style: strokeStyle),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: screenWidth * 0.6);

    // 一次合成：先画描边层，再画填充层，整张缓存为 Picture
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    strokeTp.paint(canvas, Offset.zero);
    tp.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();

    return _DanmakuData._(
      id: DateTime.now().microsecondsSinceEpoch,
      text: '$name: $text',
      track: track,
      spawnMs: DateTime.now().millisecondsSinceEpoch,
      durationMs: (durationSec * 1000).round(),
      picture: picture,
      width: tp.width,
    );
  }

  void dispose() => picture.dispose();
}

/// 弹幕绘制器：一次绘制所有弹幕，由统一 vsync ticker 每帧重绘
class _DanmakuPainter extends CustomPainter {
  final List<_DanmakuData> danmaku;
  final double screenWidth;
  final double lineHeight;
  final int trackCount;

  _DanmakuPainter({
    required this.danmaku,
    required this.screenWidth,
    required this.lineHeight,
    required this.trackCount,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final d in danmaku) {
      final t = ((now - d.spawnMs) / d.durationMs).clamp(0.0, 1.0);
      final x = screenWidth - (screenWidth + d.width) * t;
      if (x + d.width < 0) continue;
      canvas.save();
      canvas.translate(x, 44.0 + (d.track % trackCount) * lineHeight);
      canvas.drawPicture(d.picture);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) =>
      oldDelegate.danmaku != danmaku ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.trackCount != trackCount;
}
