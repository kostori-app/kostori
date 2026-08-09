import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/database/bangumi.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_card.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/bangumi/info_tab_view.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:url_launcher/url_launcher.dart';

class BangumiInfoPage extends ConsumerStatefulWidget {
  const BangumiInfoPage({super.key, required this.bangumiItem, this.heroTag});

  final BangumiItem bangumiItem;
  final Object? heroTag;

  @override
  ConsumerState<BangumiInfoPage> createState() => _BangumiInfoPageState();
}

class _BangumiInfoPageState extends ConsumerState<BangumiInfoPage>
    with TickerProviderStateMixin {
  late TabController infoTabController;

  InfoController get infoController =>
      ref.read(infoControllerProvider.notifier);

  bool commentsIsLoading = false;
  bool topicsIsLoading = false;
  bool reviewsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool topicsQueryTimeout = false;
  bool reviewsQueryTimeout = false;
  bool charactersQueryTimeout = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;

  int get bangumiId => widget.bangumiItem.id;

  BangumiItem get bangumiItem => widget.bangumiItem;

  /// 综合加载态：provider 未初始化 / 残留其他条目 id 时也视为加载中，
  /// 避免全局单例在二次进入时直接展示上一页内容或跳过骨架。
  bool get isInfoLoading =>
      infoController.isLoading ||
      infoController.bangumiId != bangumiId ||
      infoController.bangumiItemOrNull == null;

  /// 当前加载的条目：优先用本页传入的 widget 数据（避免全局单例残留上一页），
  /// 仅当 provider 的条目与当前页同 id（异步回填完成）时才使用更新值。
  BangumiItem get loadedItem {
    final item = infoController.bangumiItemOrNull;
    if (item != null && item.id == widget.bangumiItem.id) {
      return item;
    }
    return widget.bangumiItem;
  }

  String get displayName {
    final nameCn = loadedItem.nameCn;
    return nameCn.isEmpty ? loadedItem.name : nameCn;
  }

  BangumiManager get manager => ref.watch(bangumiManagerProvider);

  /// 通用加载：并发防重入 + 空结果超时标记。
  /// 复用同一套 loading/timeout 状态机，消除五个重复的 load 方法。
  Future<void> _loadSection({
    required bool isLoading,
    required void Function(bool) setLoading,
    required void Function(bool) setTimeoutFlag,
    required bool Function() isListEmpty,
    required Future<void> Function() load,
  }) async {
    if (isLoading) return;
    setLoading(true);
    setTimeoutFlag(false);
    try {
      await load();
    } catch (e) {
      Log.error('loadSection', e.toString());
    }
    if (!mounted) return;
    setLoading(false);
    if (isListEmpty()) setTimeoutFlag(true);
  }

  Future<void> loadCharacters() => _loadSection(
    isLoading: charactersIsLoading,
    setLoading: (v) => setState(() => charactersIsLoading = v),
    setTimeoutFlag: (v) => setState(() => charactersQueryTimeout = v),
    isListEmpty: () => infoController.characterList.isEmpty,
    load: () => infoController.queryBangumiCharactersByID(loadedItem.id),
  );

  Future<void> loadStaff() => _loadSection(
    isLoading: staffIsLoading,
    setLoading: (v) => setState(() => staffIsLoading = v),
    setTimeoutFlag: (v) => setState(() => staffQueryTimeout = v),
    isListEmpty: () => infoController.staffList.isEmpty,
    load: () => infoController.queryBangumiStaffsByID(loadedItem.id),
  );

  Future<void> loadMoreComments({int offset = 0}) => _loadSection(
    isLoading: commentsIsLoading,
    setLoading: (v) => setState(() => commentsIsLoading = v),
    setTimeoutFlag: (v) => setState(() => commentsQueryTimeout = v),
    isListEmpty: () => infoController.commentsList.isEmpty,
    load: () =>
        infoController.queryBangumiCommentsByID(loadedItem.id, offset: offset),
  );

  Future<void> loadMoreTopics({int offset = 0}) => _loadSection(
    isLoading: topicsIsLoading,
    setLoading: (v) => setState(() => topicsIsLoading = v),
    setTimeoutFlag: (v) => setState(() => topicsQueryTimeout = v),
    isListEmpty: () => infoController.topicsList.isEmpty,
    load: () =>
        infoController.queryBangumiTopicsByID(loadedItem.id, offset: offset),
  );

  Future<void> loadMoreReviews({int offset = 0}) => _loadSection(
    isLoading: reviewsIsLoading,
    setLoading: (v) => setState(() => reviewsIsLoading = v),
    setTimeoutFlag: (v) => setState(() => reviewsQueryTimeout = v),
    isListEmpty: () => infoController.reviewsList.isEmpty,
    load: () =>
        infoController.queryBangumiReviewsByID(loadedItem.id, offset: offset),
  );

  Future<void> queryBangumiHistory(int id) async {
    infoController.bangumiHistory = await HistoryManager().bangumiByIDFind(id);
  }

  @override
  void initState() {
    super.initState();
    // Riverpod 不允许在 initState 同步修改 provider，统一延迟到 microtask 后。
    // 全局单例在二次进入时残留上次的 isLoading=false，必须先强制为 true 触发骨架。
    Future(() => infoController.setIsLoading(true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      infoController.clearBangumiLists();
      infoController.bangumiItem = bangumiItem;
      queryBangumiEpisodeByID(bangumiId);
      queryBangumiInfoByID(bangumiId);
      Bangumi.instance.getBangumiInfoBind(bangumiId);
      queryBangumiHistory(bangumiId);
    });
    infoTabController = TabController(
      length: infoController.tabs.length,
      vsync: this,
    );
    infoTabController.addListener(() {
      int index = infoTabController.index;
      if (index == 1 &&
          infoController.commentsList.isEmpty &&
          !commentsIsLoading) {
        loadMoreComments();
      }
      if (index == 2 && infoController.topicsList.isEmpty && !topicsIsLoading) {
        loadMoreTopics();
      }
      if (index == 3 &&
          infoController.reviewsList.isEmpty &&
          !reviewsIsLoading) {
        loadMoreReviews();
      }
      if (index == 4 &&
          infoController.characterList.isEmpty &&
          !charactersIsLoading) {
        loadCharacters();
      }
      if (index == 5 && infoController.staffList.isEmpty && !staffIsLoading) {
        loadStaff();
      }
    });
  }

  @override
  void dispose() {
    infoTabController.dispose();
    super.dispose();
  }

  Future<void> queryBangumiInfoByID(int id) async {
    try {
      await infoController.queryBangumiInfoByID(id);
      setState(() {});
    } catch (e) {
      Log.error('queryBangumiInfoByID', e.toString());
    }
  }

  Future<void> queryBangumiEpisodeByID(int id) async {
    try {
      await infoController.queryBangumiEpisodeByID(id);
      DebugLog.info(
        'queryBangumiEpisodeByID',
        infoController.allEpisodes.toString(),
      );
      setState(() {});
    } catch (e) {
      Log.error('queryBangumiEpisodeByID', e.toString());
    }
  }

  void shareImage() {
    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(
        builder: (context, setState) {
          return ShareWidget(id: bangumiId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: DefaultTabController(
        length: infoController.tabs.length,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                  sliver: SliverAppBar.medium(
                    title: Text(displayName),
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
                          shareImage();
                        },
                        onLongPress: () => showKostoriShareSheet(
                          context,
                          ref,
                          type: KostoriRouteType.bangumi,
                          payload: '${loadedItem.id}',
                          title: displayName,
                          subtitle: loadedItem.name,
                          backgroundImagePath: loadedItem.images['large'],
                        ),
                        icon: const Icon(Icons.share),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          launchUrl(
                            Uri.parse(
                              'https://bangumi.tv/subject/${loadedItem.id}',
                            ),
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
                    collapsedHeight:
                        kTextTabBarHeight +
                        kToolbarHeight +
                        MediaQuery.paddingOf(context).top,
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Consumer(
                        builder: (context, ref, _) {
                          return Stack(
                            children: [
                              // No background image when loading to make loading looks better
                              if (!isInfoLoading)
                                Positioned.fill(
                                  bottom: kTextTabBarHeight,
                                  child: IgnorePointer(
                                    child: Opacity(
                                      opacity: 0.4,
                                      child: LayoutBuilder(
                                        builder: (context, boxConstraints) {
                                          return ImageFiltered(
                                            imageFilter: ImageFilter.blur(
                                              sigmaX: 15.0,
                                              sigmaY: 15.0,
                                            ),
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
                                              child: BangumiWidget.kostoriImage(
                                                context,
                                                loadedItem.images['large'] ??
                                                    '',
                                                width: boxConstraints.maxWidth,
                                                height:
                                                    boxConstraints.maxHeight,
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
                                      16,
                                      kToolbarHeight,
                                      16,
                                      0,
                                    ),
                                    child: BangumiInfoCardV(
                                      bangumiItem: loadedItem,
                                      isLoading: isInfoLoading,
                                      heroTag: widget.heroTag,
                                      infoController: infoController,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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
            body: Consumer(
              builder: (context, ref, _) {
                return InfoTabView(
                  tabController: infoTabController,
                  bangumiItem: loadedItem,
                  bangumiSRI: infoController.bangumiSRI,
                  allEpisodes: infoController.allEpisodes,
                  commentsQueryTimeout: commentsQueryTimeout,
                  topicsQueryTimeout: topicsQueryTimeout,
                  reviewsQueryTimeout: reviewsQueryTimeout,
                  charactersQueryTimeout: charactersQueryTimeout,
                  staffQueryTimeout: staffQueryTimeout,
                  loadMoreComments: loadMoreComments,
                  loadMoreTopics: loadMoreTopics,
                  loadMoreReviews: loadMoreReviews,
                  loadCharacters: loadCharacters,
                  loadStaff: loadStaff,
                  commentsList: infoController.commentsList,
                  characterList: infoController.characterList,
                  staffList: infoController.staffList,
                  isLoading: isInfoLoading,
                  infoController: infoController,
                  commentsIsLoading: commentsIsLoading,
                  topicsIsLoading: topicsIsLoading,
                  reviewsIsLoading: reviewsIsLoading,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
