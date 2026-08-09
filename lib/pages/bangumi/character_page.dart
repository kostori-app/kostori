import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/person_page.dart';
import 'package:kostori/utils/protocol_parser.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CharacterPage extends ConsumerStatefulWidget {
  const CharacterPage({super.key, required this.characterID});

  final int characterID;

  @override
  ConsumerState<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends ConsumerState<CharacterPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CharacterFullItem characterFullItem;
  bool loadingCharacter = false;
  bool loadingCharacterCasts = false;
  bool loadingComments = false;
  List<CharacterCommentItem> commentsList = [];
  List<CharacterCastsItem> characterCastsList = [];
  bool commentsQueryTimeout = false;
  bool characterCastsQueryTimeout = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadCharacter();
    _tabController.addListener(() {
      final index = _tabController.index;
      if (index == 1 &&
          commentsList.isEmpty &&
          !loadingComments &&
          !commentsQueryTimeout) {
        loadComments();
      }

      if (index == 2 &&
          characterCastsList.isEmpty &&
          !loadingCharacterCasts &&
          !characterCastsQueryTimeout) {
        loadCharacterCasts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadCharacter() async {
    setState(() {
      loadingCharacter = true;
    });
    await Bangumi.instance.getCharacterByCharacterID(widget.characterID).then((
      character,
    ) {
      characterFullItem = character;
    });
    if (mounted) {
      setState(() {
        loadingCharacter = false;
      });
    }
  }

  Future<void> loadComments() async {
    setState(() {
      loadingComments = true;
    });
    await Bangumi.instance
        .getCharacterCommentsByCharacterID(widget.characterID)
        .then((value) {
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

  Future<void> loadCharacterCasts() async {
    setState(() {
      loadingCharacterCasts = true;
    });
    await Bangumi.instance
        .getCharacterCastsByCharacterID(widget.characterID)
        .then((value) {
          characterCastsList = value;
          if (characterCastsList.isEmpty && mounted) {
            setState(() {
              characterCastsQueryTimeout = true;
            });
          }
        });
    if (mounted) {
      setState(() {
        loadingCharacterCasts = false;
      });
    }
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
                  Tab(text: t.personTabProfile),
                  Tab(text: t.personTabChat),
                  Tab(text: t.personTabRelation),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                characterInfoBody,
                KeepAliveWrapper(child: characterCommentsBody),
                KeepAliveWrapper(child: characterCastsBody),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget get characterInfoBody {
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
                      child: loadingCharacter
                          ? Center(child: KostoriRefreshIndicator())
                          : (characterFullItem.id == 0
                                ? GeneralErrorWidget(
                                    errMsg: t.nobodysPostedAnythingYet,
                                    actions: [
                                      GeneralErrorButton(
                                        onPressed: () {
                                          loadCharacter();
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
                                                        title: characterFullItem
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
                                                        characterFullItem.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .colorScheme
                                                                      .tertiary,
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
                          isCharacter: true,
                        );
                      },
                    ),
                  );
                },
                onLongPress: () {
                  final type = KostoriRouteType.character;
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

  Widget get characterCommentsBody {
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
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
                          padding: const EdgeInsets.all(16),
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

  Widget get characterCastsBody {
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
          key: PageStorageKey<String>('角色关联'),
          slivers: [
            SliverLayoutBuilder(
              builder: (context, _) {
                if (characterCastsList.isNotEmpty) {
                  Map<String, int> relationValue = {
                    t.mainCharacter: 1,
                    t.supportingCharacter: 2,
                    t.cameo: 3,
                  };
                  String? getRelationName(int type) {
                    return relationValue.entries
                        .firstWhere(
                          (entry) => entry.value == type,
                          orElse: () => MapEntry(t.unknown, -1),
                        )
                        .key;
                  }

                  return SliverList.separated(
                    addAutomaticKeepAlives: false,
                    itemCount: characterCastsList.length,
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
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        height: 160,
                                        child: BangumiDetailedCard(
                                          bangumiItem:
                                              characterCastsList[index].subject,
                                          heroTag: 'Casts$index',
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: characterCastsList[index].casts.map((
                                                cast,
                                              ) {
                                                final actor = cast.person;
                                                final relation = cast.relation;
                                                final name =
                                                    actor.nameCN.isNotEmpty
                                                    ? actor.nameCN
                                                    : actor.name;

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      onTap: () =>
                                                          BangumiWidget.showBottomPage(
                                                            context,
                                                            PersonPage(
                                                              personID:
                                                                  actor.id,
                                                            ),
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black12,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              t.voiceActorC(
                                                                c: name,
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Container(
                                                              width: 1,
                                                              height: 12,
                                                              color: Colors
                                                                  .white24,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              relation.nameStr,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                            Spacer(),
                                            Text(
                                              getRelationName(
                                                characterCastsList[index].type,
                                              ).toString(),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                  );
                }
                if (characterCastsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: t.failedToLoadPleaseTryAgain,
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadCharacterCasts();
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
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > 950
                                ? 950
                                : MediaQuery.sizeOf(context).width - 32,
                            child: _buildCastsBone(),
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

  Widget _buildCastsBone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        child: Skeletonizer.zone(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 160,
                  child: Bone(
                    width: double.infinity,
                    height: 160,
                    uniRadius: 12,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          2,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Bone(width: 180, height: 28, uniRadius: 8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Bone.text(fontSize: 16, width: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
