import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/player_item.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/translations.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage>
    with SingleTickerProviderStateMixin {
  late AnimationController animation;
  late Animation<Offset> _rightOffsetAnimation;
  late Animation<Offset> _bottomOffsetAnimation;

  final FocusNode keyboardFocus = FocusNode();

  late GridObserverController observerController;

  ScrollController scrollController = ScrollController();

  // 当前播放列表
  late int currentRoad;

  void closeTabBodyAnimated() {
    animation.reverse();
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.playerController.showTabBody = false;
    });
  }

  void menuJumpToCurrentEpisode() {
    Future.delayed(const Duration(milliseconds: 20), () {
      observerController.jumpTo(
        index: widget.playerController.currentEpisoded > 1
            ? widget.playerController.currentEpisoded - 1
            : widget.playerController.currentEpisoded,
      );
    });
  }

  void openTabBodyAnimated() {
    if (widget.playerController.showTabBody) {
      animation.forward();
      menuJumpToCurrentEpisode();
    }
  }

  @override
  void initState() {
    super.initState();
    observerController = GridObserverController(controller: scrollController);
    animation = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rightOffsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

    _bottomOffsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

    widget.playerController.showTabBody = false;
    widget.playerController.currentRoad = 0;
    currentRoad = 0;
  }

  @override
  void dispose() {
    observerController.controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          widget.playerController.isFullScreen == false &&
          widget.playerController.showTabBody == false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (widget.playerController.showTabBody) {
          closeTabBodyAnimated();
        } else if (widget.playerController.isFullScreen) {
          widget.playerController.toggleFullScreen(context);
        }
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          return Observer(
            builder: (context) => Scaffold(
              body: SafeArea(
                bottom: widget.playerController.isPortraitFullscreen,
                top: false,
                left: widget.playerController.isPortraitFullscreen
                    ? false
                    : !widget.playerController.isFullScreen,
                right: widget.playerController.isPortraitFullscreen
                    ? false
                    : !widget.playerController.isFullScreen,
                child: Stack(
                  alignment: widget.playerController.isPortraitFullscreen
                      ? Alignment.bottomCenter
                      : Alignment.topRight,
                  children: [
                    Container(
                      color: Colors.black,
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width,
                      child: playerBody,
                    ),

                    // 显示播放列表
                    IgnorePointer(
                      ignoring:
                          !widget.playerController.showTabBody, // 隐藏时不拦截事件
                      child: AnimatedOpacity(
                        opacity: widget.playerController.showTabBody
                            ? 1.0
                            : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: Stack(
                          alignment:
                              widget.playerController.isPortraitFullscreen
                              ? Alignment.bottomCenter
                              : Alignment.topRight,
                          children: [
                            AnimatedPositioned(
                              duration: Duration(seconds: 1),
                              top: widget.playerController.isPortraitFullscreen
                                  ? null
                                  : 0,
                              bottom:
                                  widget.playerController.isPortraitFullscreen
                                  ? 0
                                  : null,
                              right: 0,
                              left: widget.playerController.isPortraitFullscreen
                                  ? 0
                                  : null,
                              child: Visibility(
                                child: SlideTransition(
                                  position:
                                      widget
                                          .playerController
                                          .isPortraitFullscreen
                                      ? _bottomOffsetAnimation
                                      : _rightOffsetAnimation,
                                  child: Container(
                                    height:
                                        widget
                                            .playerController
                                            .isPortraitFullscreen
                                        ? MediaQuery.of(context).size.height *
                                                  1 /
                                                  3 +
                                              80
                                        : MediaQuery.of(context).size.height,
                                    width:
                                        widget
                                            .playerController
                                            .isPortraitFullscreen
                                        ? MediaQuery.of(context).size.width
                                        : MediaQuery.of(context).size.width *
                                                  1 /
                                                  3 >
                                              420
                                        ? 420 + 80
                                        : MediaQuery.of(context).size.width *
                                                  1 /
                                                  3 +
                                              80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin:
                                            widget
                                                .playerController
                                                .isPortraitFullscreen
                                            ? Alignment.topCenter
                                            : Alignment.centerLeft,
                                        end:
                                            widget
                                                .playerController
                                                .isPortraitFullscreen
                                            ? Alignment.bottomCenter
                                            : Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.toOpacity(0.3),
                                          Colors.black.toOpacity(0.6),
                                          Colors.black.toOpacity(0.8),
                                        ],
                                        stops: [0.0, 0.3, 0.7, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.toOpacity(0.2),
                                          blurRadius: 20.0,
                                          spreadRadius: 5.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 毛玻璃背景
                            GestureDetector(
                              onTap: closeTabBodyAnimated,
                              child: SizedBox(
                                width: double.infinity,
                                height: double.infinity,
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Container(
                                    color: Colors.black.toOpacity(0.2),
                                  ),
                                ),
                              ),
                            ),

                            // 底部或右侧面板
                            SlideTransition(
                              position:
                                  widget.playerController.isPortraitFullscreen
                                  ? _bottomOffsetAnimation
                                  : _rightOffsetAnimation,
                              child: SizedBox(
                                height:
                                    widget.playerController.isPortraitFullscreen
                                    ? MediaQuery.of(context).size.height / 3 +
                                          80
                                    : MediaQuery.of(context).size.height,
                                width:
                                    widget.playerController.isPortraitFullscreen
                                    ? MediaQuery.of(context).size.width
                                    : MediaQuery.of(context).size.width / 3 >
                                          420
                                    ? 420 + 160
                                    : MediaQuery.of(context).size.width / 3 +
                                          160,
                                child: Container(
                                  color: Colors.black.toOpacity(0.42),
                                  child: GridViewObserver(
                                    controller: observerController,
                                    child: Column(children: [tabBar, tabBody]),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget get playerBody {
    return PlayerItem(
      openMenu: openTabBodyAnimated,
      locateEpisode: menuJumpToCurrentEpisode,
      playerController: widget.playerController,
      keyboardFocus: keyboardFocus,
    );
  }

  Widget get tabBar {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(' 合集 '),
          Expanded(
            child: Text(
              WatcherState.currentState!.widget.anime.title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
              onPressed: () {
                showDialog(
                  builder: (context) {
                    return AlertDialog(
                      title: Text('Playlist'.tl),
                      content: StatefulBuilder(
                        builder:
                            (BuildContext context, StateSetter innerSetState) {
                              return Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  for (
                                    int i = 0;
                                    i <
                                        WatcherState
                                            .currentState!
                                            .widget
                                            .anime
                                            .episode!
                                            .keys
                                            .length;
                                    i++
                                  ) ...<Widget>[
                                    if (i == currentRoad) ...<Widget>[
                                      FilledButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          setState(() {
                                            currentRoad = i;
                                          });
                                        },
                                        child: Text(
                                          WatcherState
                                              .currentState!
                                              .widget
                                              .anime
                                              .episode!
                                              .keys
                                              .elementAt(i),
                                        ),
                                      ),
                                    ] else ...[
                                      FilledButton.tonal(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          setState(() {
                                            currentRoad = i;
                                          });
                                        },
                                        child: Text(
                                          WatcherState
                                              .currentState!
                                              .widget
                                              .anime
                                              .episode!
                                              .keys
                                              .elementAt(i),
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              );
                            },
                      ),
                    );
                  },
                  context: context,
                );
              },
              child: Text(
                WatcherState.currentState!.widget.anime.episode!.keys.elementAt(
                  currentRoad,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget get tabBody {
    var cardList = <Widget>[];
    var roadList = WatcherState.currentState!.widget.anime.episode ?? {};
    var selectedRoad = roadList.values.elementAt(
      currentRoad,
    ); // 用 currentRoad 直接获取对应的 road
    final watcher = WatcherState.currentState!;

    int count = 1;

    for (var epKey in selectedRoad.keys) {
      int count0 = count;
      bool visited = (watcher.history!.watchEpisode).contains(count0);
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
                widget.playerController.currentRoad = currentRoad;
                widget.playerController.playEpisode(count0, currentRoad);
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
                        if (count0 == widget.playerController.currentEpisoded &&
                            currentRoad ==
                                widget
                                    .playerController
                                    .currentRoad) ...<Widget>[
                          Image.asset(
                            'assets/img/playing.gif',
                            color: Theme.of(context).colorScheme.primary,
                            height: 16,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            selectedRoad[epKey] ?? "", // 显示每一集的标题
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  (count0 ==
                                          widget
                                              .playerController
                                              .currentEpisoded &&
                                      currentRoad ==
                                          widget.playerController.currentRoad)
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
}
