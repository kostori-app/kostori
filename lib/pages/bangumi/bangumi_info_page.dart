import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kostori/components/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kostori/network/network_img_layer.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/bangumi/info_tab_view.dart';

import 'package:kostori/components/bean/card/bangumi_info_card.dart';

import 'package:kostori/foundation/log.dart';

class BangumiInfoPage extends StatefulWidget {
  const BangumiInfoPage({
    super.key,
    required this.bangumiItem,
  });

  final BangumiItem bangumiItem;

  @override
  State<BangumiInfoPage> createState() => _BangumiInfoPageState();
}

class _BangumiInfoPageState extends State<BangumiInfoPage>
    with TickerProviderStateMixin {
  late TabController infoTabController;

  final InfoController infoController = InfoController();

  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool charactersQueryTimeout = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;

  int get bangumiId => widget.bangumiItem.id;

  BangumiItem get bangumiItem => widget.bangumiItem;

  Future<void> loadCharacters() async {
    if (charactersIsLoading) return;
    setState(() {
      charactersIsLoading = true;
      charactersQueryTimeout = false;
    });
    infoController
        .queryBangumiCharactersByID(infoController.bangumiItem.id)
        .then((_) {
      if (infoController.characterList.isEmpty && mounted) {
        setState(() {
          charactersIsLoading = false;
          charactersQueryTimeout = true;
        });
      }
      if (infoController.characterList.isNotEmpty && mounted) {
        setState(() {
          charactersIsLoading = false;
        });
      }
    });
  }

  Future<void> loadStaff() async {
    if (staffIsLoading) return;
    setState(() {
      staffIsLoading = true;
      staffQueryTimeout = false;
    });
    infoController
        .queryBangumiStaffsByID(infoController.bangumiItem.id)
        .then((_) {
      if (infoController.staffList.isEmpty && mounted) {
        setState(() {
          staffIsLoading = false;
          staffQueryTimeout = true;
        });
      }
      if (infoController.staffList.isNotEmpty && mounted) {
        setState(() {
          staffIsLoading = false;
        });
      }
    });
  }

  Future<void> loadMoreComments({int offset = 0}) async {
    if (commentsIsLoading) return;
    setState(() {
      commentsIsLoading = true;
      commentsQueryTimeout = false;
    });
    infoController
        .queryBangumiCommentsByID(infoController.bangumiItem.id, offset: offset)
        .then((_) {
      if (infoController.commentsList.isEmpty && mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsQueryTimeout = true;
        });
      }
      if (infoController.commentsList.isNotEmpty && mounted) {
        setState(() {
          commentsIsLoading = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    infoController.bangumiItem = bangumiItem;
    infoController.allEpisodes = [];
    queryBangumiInfoByID(bangumiId);
    queryBangumiEpisodeByID(bangumiId);
    infoController.characterList.clear();
    infoController.commentsList.clear();
    infoController.staffList.clear();
    infoTabController = TabController(length: 4, vsync: this);
    infoTabController.addListener(() {
      int index = infoTabController.index;
      if (index == 1 &&
          infoController.commentsList.isEmpty &&
          !commentsIsLoading) {
        loadMoreComments();
      }
      if (index == 2 &&
          infoController.characterList.isEmpty &&
          !charactersIsLoading) {
        loadCharacters();
      }
      if (index == 3 && infoController.staffList.isEmpty && !staffIsLoading) {
        loadStaff();
      }
    });
  }

  @override
  void dispose() {
    infoController.characterList.clear();
    infoController.commentsList.clear();
    infoController.staffList.clear();
    infoTabController.dispose();
    super.dispose();
  }

  Future<void> queryBangumiInfoByID(int id) async {
    try {
      await infoController.queryBangumiInfoByID(id);
      setState(() {});
    } catch (e) {
      Log.addLog(LogLevel.error, 'queryBangumiInfoByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeByID(int id) async {
    try {
      await infoController.queryBangumiEpisodeByID(id);
      setState(() {});
    } catch (e) {
      Log.addLog(LogLevel.error, 'queryBangumiEpisodeByID', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: true,
        child: DefaultTabController(
          length: infoController.tabs.length,
          child: Scaffold(
            body: NestedScrollView(
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context),
                    sliver: SliverAppBar.medium(
                      title: dtb.DragToMoveArea(
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            infoController.bangumiItem.nameCn == ''
                                ? infoController.bangumiItem.name
                                : infoController.bangumiItem.nameCn,
                          ),
                        ),
                      ),
                      automaticallyImplyLeading: false,
                      scrolledUnderElevation: 0.0,
                      leading: IconButton(
                        onPressed: () {
                          Navigator.maybePop(context);
                        },
                        icon: Icon(Icons.arrow_back_ios_new),
                      ),
                      actions: [
                        IconButton(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(
                                  'https://bangumi.tv/subject/${infoController.bangumiItem.id}'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.open_in_browser_rounded),
                        ),
                        SizedBox(width: 8),
                      ],
                      toolbarHeight: kToolbarHeight,
                      stretch: true,
                      centerTitle: false,
                      expandedHeight: 308 + kTextTabBarHeight + kToolbarHeight,
                      collapsedHeight: kTextTabBarHeight +
                          kToolbarHeight +
                          MediaQuery.paddingOf(context).top,
                      flexibleSpace: FlexibleSpaceBar(
                        collapseMode: CollapseMode.pin,
                        background: Observer(builder: (context) {
                          return Stack(
                            children: [
                              // No background image when loading to make loading looks better
                              if (!infoController.isLoading)
                                Positioned.fill(
                                  bottom: kTextTabBarHeight,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: 0.4,
                                      child: LayoutBuilder(
                                        builder: (context, boxConstraints) {
                                          return ImageFiltered(
                                            imageFilter: ImageFilter.blur(
                                                sigmaX: 15.0, sigmaY: 15.0),
                                            child: ShaderMask(
                                              shaderCallback: (Rect bounds) {
                                                return const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.white,
                                                    Colors.transparent,
                                                  ],
                                                  stops: [0.8, 1],
                                                ).createShader(bounds);
                                              },
                                              child: NetworkImgLayer(
                                                src: infoController.bangumiItem
                                                        .images['large'] ??
                                                    '',
                                                width: boxConstraints.maxWidth,
                                                height:
                                                    boxConstraints.maxHeight,
                                                fadeInDuration: const Duration(
                                                    milliseconds: 0),
                                                fadeOutDuration: const Duration(
                                                    milliseconds: 0),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              SafeArea(
                                bottom: false,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, kToolbarHeight, 16, 0),
                                    child: BangumiInfoCardV(
                                      bangumiItem: infoController.bangumiItem,
                                      allEpisodes: infoController.allEpisodes,
                                      isLoading: infoController.isLoading,
                                    ),
                                  ),
                                ),
                              )
                            ],
                          );
                        }),
                      ),
                      forceElevated: innerBoxIsScrolled,
                      bottom: TabBar(
                        controller: infoTabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.center,
                        dividerHeight: 0,
                        tabs: infoController.tabs
                            .map((name) => Tab(text: name))
                            .toList(),
                      ),
                    ),
                  ),
                ];
              },
              body: Observer(builder: (context) {
                return InfoTabView(
                  tabController: infoTabController,
                  bangumiItem: infoController.bangumiItem,
                  allEpisodes: infoController.allEpisodes,
                  commentsQueryTimeout: commentsQueryTimeout,
                  charactersQueryTimeout: charactersQueryTimeout,
                  staffQueryTimeout: staffQueryTimeout,
                  loadMoreComments: loadMoreComments,
                  loadCharacters: loadCharacters,
                  loadStaff: loadStaff,
                  commentsList: infoController.commentsList,
                  characterList: infoController.characterList,
                  staffList: infoController.staffList,
                  isLoading: infoController.isLoading,
                );
              }),
            ),
          ),
        ));
  }
}
