import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/pages/bangumi/comment_item.dart';
import 'package:kostori/pages/bangumi/comments_card.dart';
import 'package:kostori/pages/bangumi/staff_card.dart';
import 'package:kostori/pages/bangumi/staff_item.dart';
import 'package:kostori/pages/line_chart_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'bangumi.dart';
import 'character_card.dart';
import 'character_item.dart';
import 'episode_comments_sheet.dart';
import 'episode_item.dart';
import 'error_widget.dart';

class BottomInfo extends StatefulWidget {
  const BottomInfo({
    super.key,
    required this.bangumiId,
  });

  final int? bangumiId;

  @override
  State<BottomInfo> createState() => BottomInfoState();
}

class BottomInfoState extends State<BottomInfo> {
  static BottomInfoState? currentState; // 静态变量
  late ScrollController scrollController;
  EpisodeInfo episodeInfo = EpisodeInfo.fromTemplate();

  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool charactersQueryTimeout = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;

  List<CommentItem> commentsList = []; // 评论列表
  List<CharacterItem> characterList = [];
  List<StaffFullItem> staffList = [];
  List<EpisodeCommentItem> episodeCommentsList = [];

  final maxWidth = 950.0;

  var bangumiId;

  @override
  void initState() {
    currentState = this;
    bangumiId = widget.bangumiId;
    super.initState();
    if (commentsList.isEmpty) {
      loadMoreComments();
    }
    if (characterList.isEmpty) {
      loadCharacters();
    }
    if (staffList.isEmpty) {
      loadStaff();
    }
    scrollController = ScrollController();
    scrollController.addListener(scrollListener);
  }

  void scrollListener() {
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !commentsIsLoading &&
        mounted) {
      setState(() {
        commentsIsLoading = true;
      });
      loadMoreComments(offset: commentsList.length);
    }
  }

  void upDate(int) {
    setState(() {
      bangumiId = int;
      loadMoreComments();
      loadCharacters();
      loadStaff();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> queryBangumiCommentsByID(int id, {int offset = 0}) async {
    if (offset == 0) {
      commentsList.clear();
    }
    await Bangumi.getBangumiCommentsByID(id, offset: offset).then((value) {
      commentsList.addAll(value.commentList);
    });
  }

  Future<void> queryBangumiCharactersByID(int id) async {
    characterList.clear();
    await Bangumi.getCharatersByID(id).then((value) {
      characterList.addAll(value.characterList);
    });
    Map<String, int> relationValue = {
      '主角': 1,
      '配角': 2,
      '客串': 3,
      '未知': 4,
    };
    try {
      characterList.sort((a, b) =>
          relationValue[a.relation]!.compareTo(relationValue[b.relation]!));
    } catch (e, s) {
      Log.addLog(LogLevel.error, 'bangumi', '$e\n$s');
    }
  }

  Future<void> queryBangumiStaffsByID(int id) async {
    staffList.clear();
    await Bangumi.getBangumiStaffByID(id).then((value) {
      staffList.addAll(value.data);
    });
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, int episode) async {
    episodeCommentsList.clear();
    episodeInfo = await Bangumi.getBangumiEpisodeByID(id, episode);
    setState(() {});
    await Bangumi.getBangumiCommentsByEpisodeID(episodeInfo.id).then((value) {
      episodeCommentsList.addAll(value.commentList);
    });
  }

  Future<void> loadCharacters() async {
    if (bangumiId != null) {
      queryBangumiCharactersByID(bangumiId as int).then((_) {
        if (characterList.isEmpty && mounted) {
          setState(() {
            charactersQueryTimeout = true;
          });
        }
        if (characterList.isNotEmpty && mounted) {
          setState(() {
            charactersIsLoading = false;
          });
        }
      });
    } else {
      return;
    }
  }

  Future<void> loadMoreComments({int offset = 0}) async {
    if (bangumiId != null) {
      // 调用异步方法并使用 .then() 来处理结果
      queryBangumiCommentsByID(bangumiId as int, offset: offset).then((_) {
        // 在获取评论数据后处理
        if (commentsList.isEmpty && mounted) {
          setState(() {
            commentsQueryTimeout = true;
          });
        }
        if (commentsList.isNotEmpty && mounted) {
          setState(() {
            commentsIsLoading = false;
          });
        }
      });
    } else {
      // 如果没有有效的 bangumiId，直接返回
      return;
    }
  }

  Future<void> loadComments(int episode) async {
    commentsQueryTimeout = false;
    await queryBangumiEpisodeCommentsByID(bangumiId, episode).then((_) {
      if (episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    });
  }

  Future<void> loadStaff() async {
    if (bangumiId != null) {
      if (staffIsLoading) return;
      setState(() {
        staffIsLoading = true;
        staffQueryTimeout = false;
      });
      queryBangumiStaffsByID(bangumiId).then((_) {
        if (staffList.isEmpty && mounted) {
          setState(() {
            staffIsLoading = false;
            staffQueryTimeout = true;
          });
        }
        if (staffList.isNotEmpty && mounted) {
          setState(() {
            staffIsLoading = false;
          });
        }
      });
    } else {
      // 如果没有有效的 bangumiId，直接返回
      return;
    }
  }

  Widget get infoBody {
    if (bangumiId == null) {
      return SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Center(
            child: InkWell(),
          ),
        ),
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        BangumiManager().bindFind(bangumiId as int), // Future 1
        Bangumi.getBangumiEpisodeAllByID(bangumiId), // Future 2, // Future 3
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          return Center(child: Text('No data available'));
        }

        final bangumiItem = snapshot.data?[0];
        final allEpisodes = snapshot.data?[1] as List<EpisodeInfo>;

        // 获取当前周的剧集
        final currentWeekEp = Utils.findCurrentWeekEpisode(allEpisodes);

        // 判断是否已全部播出（检查是否是最后一项）
        final isCompleted = currentWeekEp != null &&
            allEpisodes.isNotEmpty &&
            currentWeekEp == allEpisodes.last;

        if (bangumiItem == null) {
          return SelectionArea(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Center(
                child: Text('空'),
              ),
            ),
          );
        }

        return SelectionArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double height = constraints.maxWidth *
                          (App.isDesktop ? 9 / 16 : 9 / 16);
                      double width = height * 0.72;

                      return Container(
                        width: constraints.maxWidth,
                        height: height,
                        padding: EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                bangumiItem!.images['large']!,
                                width: width,
                                height: height,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // SizedBox(width: 12.0),
                            Expanded(
                                child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bangumiItem.nameCn,
                                    style: TextStyle(
                                        fontSize: width * 1 / 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(bangumiItem.name,
                                      style: TextStyle(
                                        fontSize: width * 1 / 24,
                                      )),
                                  SizedBox(height: 12.0),
                                  Container(
                                    padding: EdgeInsets.all(8.0),
                                    // 可选，设置内边距
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(16.0), // 设置圆角半径
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .toOpacity(0.72),
                                        width: 2.0, // 设置边框宽度
                                      ),
                                    ),
                                    child: Text(
                                      bangumiItem.airDate,
                                    ),
                                  ),
                                  SizedBox(height: 12.0),
                                  Text(
                                    isCompleted
                                        ? '全 ${bangumiItem.totalEpisodes} 话'
                                        : '连载至 ${currentWeekEp?.episode} • 预定全 ${bangumiItem.totalEpisodes} 话',
                                    style: TextStyle(fontSize: 14.0),
                                  ),
                                  Spacer(),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${bangumiItem.score}',
                                          style: TextStyle(
                                            fontSize: 32.0,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 5,
                                        ),
                                        Container(
                                          padding:
                                              EdgeInsets.all(2.0), // 可选，设置内边距
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                8), // 设置圆角半径
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer
                                                  .toOpacity(0.72),
                                              width: 2.0, // 设置边框宽度
                                            ),
                                          ),
                                          child: Text(
                                            Utils.getRatingLabel(
                                                bangumiItem.score),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 4,
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end, // 右对齐
                                          children: [
                                            RatingBarIndicator(
                                              itemCount: 5,
                                              rating:
                                                  bangumiItem.score.toDouble() /
                                                      2,
                                              itemBuilder: (context, index) =>
                                                  const Icon(
                                                Icons.star_rounded,
                                              ),
                                              itemSize: 20.0,
                                            ),
                                            Text(
                                              '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                                              style: TextStyle(fontSize: 12),
                                            )
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      );
                    },
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Align(
                    child: Row(
                      children: [
                        Text('${bangumiItem?.collection?['doing']} 在看',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            )),
                        Text(' / '),
                        Text('${bangumiItem?.collection?['collect']} 看过',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error)),
                        Text(' / '),
                        Text('${bangumiItem?.collection?['wish']} 想看',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blueAccent)),
                        Text(' / '),
                        Text('${bangumiItem?.collection?['on_hold']} 搁置',
                            style: TextStyle(fontSize: 12)),
                        Text(' / '),
                        Text('${bangumiItem?.collection?['dropped']} 抛弃',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            )),
                        Text(' / '),
                        Text(
                            '${bangumiItem?.collection!['doing']! + bangumiItem.collection!['collect']! + bangumiItem.collection!['wish']! + bangumiItem.collection!['on_hold']! + bangumiItem.collection!['dropped']!} 总计数',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Divider(),
                  Text(
                    '简介',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Text(bangumiItem.summary),
                  SizedBox(
                    height: 12,
                  ),
                  Divider(),
                  Text(
                    '标签',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Wrap(
                      spacing: 8.0,
                      runSpacing: App.isDesktop ? 8 : 0,
                      children: List<Widget>.generate(bangumiItem.tags.length,
                          (int index) {
                        return Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${bangumiItem.tags[index].name} '),
                              Text(
                                '${bangumiItem.tags[index].count}',
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                        );
                      }).toList()),
                  SizedBox(height: 12),
                  Divider(),
                  Text(
                    '评分统计图',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  LineChatPage(
                    bangumiItem: bangumiItem,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget get commentsListBody {
    return Builder(
      builder: (BuildContext context) {
        return NotificationListener<ScrollEndNotification>(
          onNotification: (scrollEnd) {
            final metrics = scrollEnd.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 200) {
              loadMoreComments(offset: commentsList.length);
            }
            return true;
          },
          child: CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            key: PageStorageKey<String>('吐槽'),
            slivers: <Widget>[
              // 已移除 SliverOverlapInjector
              SliverLayoutBuilder(builder: (context, _) {
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: CommentsCard(
                                commentItem: commentsList[index],
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
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
                  );
                }
                if (commentsQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      errMsg: '获取失败，请重试',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            loadMoreComments(offset: commentsList.length);
                          },
                          text: '重试',
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
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CommentsCard.bone(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              })
            ],
          ),
        );
      },
    );
  }

  Widget get charactersListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: PageStorageKey<String>('角色'),
          slivers: <Widget>[
            SliverLayoutBuilder(builder: (context, _) {
              if (characterList.isNotEmpty) {
                return SliverList.builder(
                  itemCount: characterList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: CharacterCard(
                            characterItem: characterList[index],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (charactersQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          loadCharacters();
                        },
                        text: '重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: 4,
                itemBuilder: (context, _) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width > maxWidth
                          ? maxWidth
                          : MediaQuery.sizeOf(context).width - 32,
                      child: Skeletonizer.zone(
                        child: ListTile(
                          leading: Bone.circle(size: 36),
                          title: Bone.text(width: 100),
                          subtitle: Bone.text(width: 80),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget get staffListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: PageStorageKey<String>('制作人员'),
          slivers: <Widget>[
            SliverLayoutBuilder(builder: (context, _) {
              if (staffList.isNotEmpty) {
                return SliverList.builder(
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: StaffCard(
                            staffFullItem: staffList[index],
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (staffQueryTimeout) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '获取失败，请重试',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          loadStaff();
                        },
                        text: '重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList.builder(
                itemCount: 8,
                itemBuilder: (context, _) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width > maxWidth
                          ? maxWidth
                          : MediaQuery.sizeOf(context).width - 32,
                      child: Skeletonizer.zone(
                        child: ListTile(
                          leading: Bone.circle(size: 36),
                          title: Bone.text(width: 100),
                          subtitle: Bone.text(width: 80),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        body: Column(
          children: [
            PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: [
                    Tab(text: 'Details'.tl),
                    Tab(text: 'Comments'.tl),
                    Tab(text: 'Comment'.tl),
                    Tab(text: 'Characters'.tl),
                    Tab(text: 'staffList'.tl),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  infoBody,
                  commentsListBody,
                  EpisodeCommentsSheet(
                    episodeCommentsList: episodeCommentsList,
                    episodeInfo: episodeInfo,
                    loadComments: loadComments,
                    episode: WatcherState.currentState!.episode,
                  ),
                  charactersListBody,
                  staffListBody
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
