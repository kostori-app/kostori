import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/character_comments_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/error_widget.dart';
import 'package:kostori/components/share_widget.dart';
import 'package:kostori/components/translation_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/character/character_casts_item.dart';
import 'package:kostori/foundation/bangumi/character/character_full_item.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/foundation/bangumi/person_work_item.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:skeletonizer/skeletonizer.dart';

class PersonPage extends ConsumerStatefulWidget {
  const PersonPage({super.key, required this.personID, this.fromStaff = false});

  final int personID;

  /// 从制作人员进入时，关联 tab 加载「参与作品」而非「出演角色」
  final bool fromStaff;

  @override
  ConsumerState<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends ConsumerState<PersonPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CharacterFullItem characterFullItem;
  bool loadingPerson = false;
  bool loadingPersonCasts = false;
  bool loadingComments = false;
  List<CharacterCommentItem> commentsList = [];
  List<CharacterPersonCastsItem> characterPersonCastsList = [];
  List<PersonWorkItem> personWorksList = [];
  bool commentsQueryTimeout = false;
  bool characterPersonCastsQueryTimeout = false;
  bool personWorksQueryTimeout = false;
  int currentType = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadPerson();
    _tabController.addListener(() {
      final index = _tabController.index;
      if (index == 1 &&
          commentsList.isEmpty &&
          !loadingComments &&
          !commentsQueryTimeout) {
        loadComments();
      }

      if (index == 2) {
        if (widget.fromStaff) {
          if (personWorksList.isEmpty &&
              !loadingPersonCasts &&
              !personWorksQueryTimeout) {
            loadPersonWorks();
          }
        } else {
          if (characterPersonCastsList.isEmpty &&
              !loadingPersonCasts &&
              !characterPersonCastsQueryTimeout) {
            loadPersonCasts();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadPerson() async {
    setState(() {
      loadingPerson = true;
    });
    await Bangumi.instance.getPersonByPersonID(widget.personID).then((
      character,
    ) {
      characterFullItem = character;
    });
    if (mounted) {
      setState(() {
        loadingPerson = false;
      });
    }
  }

  Future<void> loadComments() async {
    setState(() {
      loadingComments = true;
    });
    await Bangumi.instance.getPersonCommentsByPersonID(widget.personID).then((
      value,
    ) {
      commentsList = value.commentList;
      if (commentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    });
    if (mounted) {
      setState(() {
        loadingComments = false;
      });
    }
  }

  Future<void> loadPersonCasts({int offset = 0, int type = 0}) async {
    setState(() {
      loadingPersonCasts = true;
    });
    await Bangumi.instance
        .getCastsByPersonId(widget.personID, offset: offset, type: type)
        .then((value) {
          characterPersonCastsList.addAll(value);
          if (characterPersonCastsList.isEmpty && mounted) {
            setState(() {
              characterPersonCastsQueryTimeout = true;
            });
          }
        });
    if (mounted) {
      setState(() {
        loadingPersonCasts = false;
      });
    }
  }

  Future<void> loadPersonWorks({int offset = 0}) async {
    setState(() {
      loadingPersonCasts = true;
    });
    await Bangumi.instance.getPersonWorks(widget.personID, offset: offset).then(
      (value) {
        personWorksList.addAll(value);
        if (personWorksList.isEmpty && mounted) {
          setState(() {
            personWorksQueryTimeout = true;
          });
        }
      },
    );
    if (mounted) {
      setState(() {
        loadingPersonCasts = false;
      });
    }
  }

  Map<String, int> relationValue = {
    t.mainCharacter: 1,
    t.supportingCharacter: 2,
    t.cameo: 3,
    t.idleCorner: 4,
  };

  String getRelationName(int type) {
    return relationValue.entries
        .firstWhere(
          (entry) => entry.value == type,
          orElse: () => MapEntry(t.unknown, -1),
        )
        .key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Material(
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    text: widget.fromStaff
                        ? t.personTabStaffInfo
                        : t.personTabVoice,
                  ),
                  Tab(text: t.personTabChat),
                  Tab(
                    text: widget.fromStaff
                        ? t.personTabWorks
                        : t.personTabRelation,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                personInfoBody,
                KeepAliveWrapper(child: personCommentsBody),
                KeepAliveWrapper(
                  child: widget.fromStaff ? personWorksBody : personCastsBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget get personInfoBody {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Expanded(
                      child: loadingPerson
                          ? Center(child: KostoriRefreshIndicator())
                          : (characterFullItem.id == 0
                                ? GeneralErrorWidget(
                                    errMsg: t.nobodysPostedAnythingYet,
                                    actions: [
                                      GeneralErrorButton(
                                        onPressed: () {
                                          loadPerson();
                                        },
                                        text: t.reload,
                                      ),
                                    ],
                                  )
                                : ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(
                                      context,
                                    ).copyWith(scrollbars: false),
                                    child: SingleChildScrollView(
                                      child: SizedBox(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 50,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    width: 210 * 0.72,
                                                    height: 210,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        BangumiWidget.showImagePreview(
                                                          context: context,
                                                          url: characterFullItem
                                                              .image,
                                                          title:
                                                              characterFullItem
                                                                  .nameCN,
                                                          heroTag:
                                                              characterFullItem
                                                                  .image,
                                                        );
                                                      },
                                                      child: Hero(
                                                        tag: characterFullItem
                                                            .image,
                                                        child:
                                                            BangumiWidget.kostoriImage(
                                                              context,
                                                              characterFullItem
                                                                  .image,
                                                              enableDefaultSize:
                                                                  false,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          characterFullItem
                                                              .name,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .headlineSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.tertiary,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 2,
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 4.0,
                                                              ),
                                                          child: Text(
                                                            characterFullItem
                                                                .nameCN,
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .titleMedium
                                                                ?.copyWith(
                                                                  color: Colors
                                                                      .grey[700],
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Divider(),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8.0,
                                                    ),
                                                child: Text(
                                                  t.profileInformation,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              SelectableText(
                                                characterFullItem.infobox
                                                    .map(
                                                      (item) =>
                                                          '${item.key}: ${item.values.map((v) => v.value).join(", ")}',
                                                    )
                                                    .join("\n"),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                                textAlign: TextAlign.justify,
                                                scrollPhysics:
                                                    const NeverScrollableScrollPhysics(),
                                              ),
                                              const SizedBox(height: 16.0),
                                              TranslationWidget(
                                                data: characterFullItem.summary,
                                                title: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8.0,
                                                      ),
                                                  child: Text(
                                                    t.characterIntroduction,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 20.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showPopUpWidget(
                    App.rootContext,
                    StatefulBuilder(
                      builder: (context, setState) {
                        return ShareWidget(
                          characterFullItem: characterFullItem,
                          isCharacter: false,
                        );
                      },
                    ),
                  );
                },
                onLongPress: () {
                  final type = KostoriRouteType.person;
                  final id = '${characterFullItem.id}';
                  showKostoriShareSheet(
                    context,
                    ref,
                    type: type,
                    payload: id,
                    title: characterFullItem.nameCN,
                    backgroundImagePath: characterFullItem.image,
                    subtitle: t.personSubtitle,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.share,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget get personCommentsBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            // Scrollbars' movement is not linear so hide it.
            scrollbars: false,
            // Enable mouse drag to refresh
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.trackpad,
            },
          ),
          key: PageStorageKey<String>('吐槽箱'),
          slivers: [
            SliverLayoutBuilder(
              builder: (context, _) {
                if (commentsList.isNotEmpty) {
                  return SliverList.separated(
                    addAutomaticKeepAlives: false,
                    itemCount: commentsList.length,
                    itemBuilder: (context, index) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > 950
                                  ? 950
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: CharacterCommentsCard(
                                commentItem: commentsList[index],
                                replyIndex: index,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return SafeArea(
                        top: false,
                        bottom: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > 950
                                  ? 950
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (commentsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: t.failedToLoadPleaseTryAgain,
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadComments();
                          },
                          text: t.reload,
                        ),
                      ],
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > 950
                                ? 950
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CharacterCommentsCard.bone(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget get personCastsBody {
    return Stack(
      children: [
        Positioned.fill(
          child: Builder(
            builder: (BuildContext context) {
              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical) {
                    return false;
                  }

                  if (notification is ScrollUpdateNotification) {
                    final metrics = notification.metrics;

                    if (metrics.maxScrollExtent > 0 &&
                        metrics.pixels >= metrics.maxScrollExtent - 20 &&
                        !loadingPersonCasts &&
                        characterPersonCastsList.length >= 20) {
                      loadPersonCasts(offset: characterPersonCastsList.length);
                    }
                  }

                  return false;
                },
                child: CustomScrollView(
                  scrollBehavior: const ScrollBehavior().copyWith(
                    scrollbars: false,
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  key: PageStorageKey<String>('声优角色关联'),
                  slivers: [
                    if (characterPersonCastsList.isNotEmpty)
                      SliverList.separated(
                        addAutomaticKeepAlives: false,
                        itemCount: characterPersonCastsList.length,
                        itemBuilder: (context, index) {
                          return SafeArea(
                            top: false,
                            bottom: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: SizedBox(
                                  width: MediaQuery.sizeOf(context).width > 950
                                      ? 950
                                      : MediaQuery.sizeOf(context).width - 32,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  width: 120 * 0.68,
                                                  height: 120,
                                                  child: InkWell(
                                                    onTap: () {
                                                      final imageUrl =
                                                          characterPersonCastsList[index]
                                                              .character
                                                              .images
                                                              .large;
                                                      if (imageUrl.isNotEmpty) {
                                                        BangumiWidget.showImagePreview(
                                                          context: context,
                                                          url: imageUrl,
                                                          title:
                                                              characterFullItem
                                                                  .nameCN,
                                                          heroTag: imageUrl,
                                                        );
                                                      }
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Hero(
                                                      tag:
                                                          characterPersonCastsList[index]
                                                              .character
                                                              .images
                                                              .large,
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child:
                                                            characterPersonCastsList[index]
                                                                .character
                                                                .images
                                                                .large
                                                                .isNotEmpty
                                                            ? BangumiWidget.kostoriImage(
                                                                context,
                                                                characterPersonCastsList[index]
                                                                    .character
                                                                    .images
                                                                    .large,
                                                                width:
                                                                    210 * 0.68,
                                                                height: 210,
                                                              )
                                                            : SizedBox(
                                                                width:
                                                                    210 * 0.68,
                                                                height: 210,
                                                                child: const Icon(
                                                                  Icons.person,
                                                                  size: 48,
                                                                ),
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        characterPersonCastsList[index]
                                                            .character
                                                            .name
                                                            .trim(),
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        characterPersonCastsList[index]
                                                            .character
                                                            .nameCN
                                                            .trim()
                                                            .replaceAll(
                                                              RegExp(r'\s+'),
                                                              ' ',
                                                            ),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        characterPersonCastsList[index]
                                                            .character
                                                            .info
                                                            .trim()
                                                            .replaceAll(
                                                              RegExp(r'\s+'),
                                                              ' ',
                                                            ),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Divider(
                                              thickness: 0.5,
                                              indent: 10,
                                              endIndent: 10,
                                            ),
                                            SizedBox(
                                              height: 240,
                                              child: ListView.builder(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount:
                                                    characterPersonCastsList[index]
                                                        .relations
                                                        .length,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                itemBuilder: (context, i) {
                                                  final item =
                                                      characterPersonCastsList[index]
                                                          .relations[i]
                                                          .subject;
                                                  final type =
                                                      characterPersonCastsList[index]
                                                          .relations[i]
                                                          .type;

                                                  return SizedBox(
                                                    width: 240 * 0.68,
                                                    height: 240,
                                                    child: Stack(
                                                      children: [
                                                        Positioned.fill(
                                                          child: BangumiBriefCard(
                                                            bangumiItem: item,
                                                            heroTag:
                                                                'Reviews$index',
                                                          ),
                                                        ),
                                                        Positioned(
                                                          left: 8,
                                                          top: 8,
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context)
                                                                  .colorScheme
                                                                  .secondaryContainer,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            child: Text(
                                                              getRelationName(
                                                                type,
                                                              ),
                                                              style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (BuildContext context, int index) {
                          return SafeArea(
                            top: false,
                            bottom: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: SizedBox(
                                  width: MediaQuery.sizeOf(context).width > 950
                                      ? 950
                                      : MediaQuery.sizeOf(context).width - 32,
                                  child: Divider(
                                    thickness: 0.5,
                                    indent: 10,
                                    endIndent: 10,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else if (characterPersonCastsQueryTimeout)
                      SliverFillRemaining(
                        child: GeneralErrorWidget(
                          errMsg: t.failedToLoadPleaseTryAgain,
                          actions: [
                            GeneralErrorButton(
                              onPressed: () {
                                loadPersonCasts();
                              },
                              text: t.reload,
                            ),
                          ],
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: 4,
                        itemBuilder: (context, _) {
                          return SafeArea(
                            top: false,
                            bottom: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: MediaQuery.sizeOf(context).width > 950
                                      ? 950
                                      : MediaQuery.sizeOf(context).width - 32,
                                  child: _buildBone(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    if (loadingPersonCasts)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: PolygonRefreshIndicator(size: 40),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: PopupMenuButton<int>(
            onSelected: (value) async {
              setState(() {
                currentType = value;
                characterPersonCastsList.clear();
                characterPersonCastsQueryTimeout = false;
              });

              await loadPersonCasts(offset: 0, type: value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 0, child: Text(t.all)),
              PopupMenuItem(value: 1, child: Text(getRelationName(1))),
              PopupMenuItem(value: 2, child: Text(getRelationName(2))),
              PopupMenuItem(value: 3, child: Text(getRelationName(3))),
              PopupMenuItem(value: 4, child: Text(getRelationName(4))),
            ],
            child: FilledButton.icon(
              onPressed: null,
              label: Row(
                children: [
                  Text(currentType == 0 ? t.all : getRelationName(currentType)),
                  Text('(${characterPersonCastsList.length})'),
                ],
              ),
              icon: const Icon(Icons.filter_alt),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        child: Skeletonizer.zone(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Bone(
                        width: 120 * 0.68,
                        height: 120,
                        uniRadius: 12,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Bone.text(fontSize: 16, width: 100),
                          const SizedBox(height: 2),
                          const Bone.text(fontSize: 14, width: 80),
                          const SizedBox(height: 2),
                          const Bone.multiText(fontSize: 12, lines: 3),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 0.5, indent: 10, endIndent: 10),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: SizedBox(
                          width: 240 * 0.68,
                          height: 240,
                          child: Stack(
                            children: [
                              const Positioned.fill(child: Bone(uniRadius: 12)),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Bone(
                                  width: 50,
                                  height: 24,
                                  uniRadius: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 制作人员「参与作品」列表
  Widget get personWorksBody {
    return Stack(
      children: [
        Positioned.fill(
          child: Builder(
            builder: (BuildContext context) {
              return NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis != Axis.vertical) {
                    return false;
                  }
                  if (notification is ScrollUpdateNotification) {
                    final metrics = notification.metrics;
                    if (metrics.maxScrollExtent > 0 &&
                        metrics.pixels >= metrics.maxScrollExtent - 20 &&
                        !loadingPersonCasts &&
                        personWorksList.length >= 20) {
                      loadPersonWorks(offset: personWorksList.length);
                    }
                  }
                  return false;
                },
                child: CustomScrollView(
                  scrollBehavior: const ScrollBehavior().copyWith(
                    scrollbars: false,
                    dragDevices: {
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.touch,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  key: const PageStorageKey<String>('人物参与作品'),
                  slivers: [
                    if (personWorksList.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 240,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: personWorksList.length,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            itemBuilder: (context, index) {
                              final work = personWorksList[index];
                              return SizedBox(
                                width: 240 * 0.68,
                                height: 240,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: BangumiBriefCard(
                                        bangumiItem: work.subject,
                                        heroTag: 'PersonWork',
                                      ),
                                    ),
                                    if (work.positions.isNotEmpty)
                                      Positioned(
                                        left: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            work.positions.first.type.cn.isEmpty
                                                ? work.positions.first.type.jp
                                                : work.positions.first.type.cn,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    else if (personWorksQueryTimeout)
                      SliverFillRemaining(
                        child: GeneralErrorWidget(
                          errMsg: t.failedToLoadPleaseTryAgain,
                          actions: [
                            GeneralErrorButton(
                              onPressed: () {
                                loadPersonWorks();
                              },
                              text: t.reload,
                            ),
                          ],
                        ),
                      )
                    else
                      BangumiWidget.bangumiSkeletonSliverBrief(),
                    if (loadingPersonCasts)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: PolygonRefreshIndicator(size: 40),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
