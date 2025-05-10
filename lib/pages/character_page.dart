import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/foundation/bangumi/character/character_comments_card.dart';
import 'package:photo_view/photo_view.dart';

import '../components/misc_components.dart';
import '../foundation/bangumi/character/character_full_item.dart';
import '../foundation/bangumi/comment/comment_item.dart';
import '../components/error_widget.dart';
import '../foundation/image_loader/cached_image.dart';
import '../network/network_img_layer.dart';

class CharacterPage extends StatefulWidget {
  const CharacterPage({super.key, required this.characterID});

  final int characterID;

  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  late CharacterFullItem characterFullItem;
  bool loadingCharacter = true;
  List<CharacterCommentItem> commentsList = [];
  bool loadingComments = true;

  Future<void> loadCharacter() async {
    setState(() {
      loadingCharacter = true;
    });
    await Bangumi.getCharacterByCharacterID(widget.characterID)
        .then((character) {
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
    await Bangumi.getCharacterCommentsByCharacterID(widget.characterID)
        .then((value) {
      commentsList = value.commentList;
    });
    if (mounted) {
      setState(() {
        loadingComments = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadCharacter();
      loadComments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: [
                    Tab(text: '人物资料'),
                    Tab(text: '吐槽箱'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [characterInfoBody, characterCommentsBody],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(characterFullItem.nameCN)),
                  body: PhotoView(
                    imageProvider: CachedImageProvider(url),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                  ),
                )));
  }

  Widget get characterInfoBody {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: loadingCharacter
                  ? Center(
                      child: MiscComponents.placeholder(
                          context, constraints.maxWidth, constraints.maxHeight),
                    )
                  : (characterFullItem.id == 0
                      ? GeneralErrorWidget(
                          errMsg: '什么都没有找到 (´;ω;`)',
                          actions: [
                            GeneralErrorButton(
                              onPressed: () {
                                loadCharacter();
                              },
                              text: '点击重试',
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  _showImagePreview(
                                      context, characterFullItem.image);
                                },
                                child: SizedBox(
                                  width: constraints.maxWidth * 0.6,
                                  height: constraints.maxHeight,
                                  child: CachedNetworkImage(
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                    imageUrl: characterFullItem.image,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        MiscComponents.placeholder(
                                            context,
                                            constraints.maxWidth,
                                            constraints.maxHeight),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          characterFullItem.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .tertiary,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 4.0, bottom: 12.0),
                                          child: Text(
                                            characterFullItem.nameCN,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Colors.grey[700],
                                                ),
                                          ),
                                        ),
                                        const Divider(),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Text(
                                            '基本信息',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          characterFullItem.info,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          textAlign: TextAlign.justify,
                                        ),
                                        const SizedBox(height: 16.0),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8.0),
                                          child: Text(
                                            '角色简介',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          characterFullItem.summary,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          textAlign: TextAlign.justify,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
            ),
          ],
        );
      }),
    );
  }

  Widget get characterCommentsBody {
    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        // Scrollbars' movement is not linear so hide it.
        scrollbars: false,
        // Enable mouse drag to refresh
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          sliver: Builder(builder: (context) {
            if (loadingComments) {
              return SliverFillRemaining(
                child: Center(
                  child: MiscComponents.placeholder(context, 24, 24),
                ),
              );
            }
            if (commentsList.isEmpty) {
              return SliverFillRemaining(
                child: GeneralErrorWidget(
                  errMsg: '什么都没有找到 (´;ω;`)',
                  actions: [
                    GeneralErrorButton(
                      onPressed: () {
                        loadComments();
                      },
                      text: '点击重试',
                    ),
                  ],
                ),
              );
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Fix scroll issue caused by height change of network images
                  // by keeping loaded cards alive.
                  return KeepAlive(
                    keepAlive: true,
                    child: IndexedSemantics(
                      index: index,
                      child: SelectionArea(
                        child: CharacterCommentsCard(
                          commentItem: commentsList[index],
                        ),
                      ),
                    ),
                  );
                },
                childCount: commentsList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                addSemanticIndexes: false,
                separatorBuilder: (BuildContext context, int index) {
                  return SafeArea(
                    top: false,
                    bottom: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: Divider(
                              thickness: 0.5, indent: 10, endIndent: 10),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}
