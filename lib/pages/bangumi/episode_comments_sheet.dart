import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import 'bottom_info.dart';
import 'comment_item.dart';
import 'episode_comments_card.dart';
import 'episode_item.dart';

// class EpisodeInfo extends InheritedWidget {
//   /// This widget receives changes of episode and notify it's child,
//   /// trigger [didChangeDependencies] of it's child.
//   const EpisodeInfo({super.key, required this.episode, required super.child});
//
//   final int episode;
//
//   @override
//   bool updateShouldNotify(covariant InheritedWidget oldWidget) => true;
//
//   static EpisodeInfo? of(BuildContext context) {
//     return context.dependOnInheritedWidgetOfExactType<EpisodeInfo>();
//   }
// }

class EpisodeCommentsSheet extends StatefulWidget {
  const EpisodeCommentsSheet(
      {super.key,
      required this.episodeCommentsList,
      required this.episodeInfo,
      required this.loadComments,
      required this.episode});

  final List<EpisodeCommentItem> episodeCommentsList;

  final EpisodeInfo episodeInfo;

  final Future<void> Function(int episode) loadComments;

  final int episode;

  @override
  State<EpisodeCommentsSheet> createState() => _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet> {
  bool commentsQueryTimeout = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  /// episode input by [showEpisodeSelection]
  int ep = 0;

  @override
  void initState() {
    // EpisodeInfo episodeInfo = BottomInfoState.currentState?.loadComments();
    // EpisodeInfo newepisodeInfo = widget.episodeInfo.episode == 0 ? BottomInfoState.currentState?.loadComments() : widget.episodeInfo;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    ep = 0;
    // wait until currentState is not null
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.episodeCommentsList.isEmpty) {
        // trigger RefreshIndicator onRefresh and show animation
        _refreshIndicatorKey.currentState?.show();
      }
    });
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget get episodeCommentsBody {
    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        // Scrollbars' movement is not linear so hide it.
        scrollbars: false,
        // Enable mouse drag to refresh
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          sliver: Observer(builder: (context) {
            if (commentsQueryTimeout) {
              return const SliverFillRemaining(
                child: Center(
                  child: Text('空空如也'),
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
                        child: EpisodeCommentsCard(
                          commentItem: widget.episodeCommentsList[index],
                        ),
                      ),
                    ),
                  );
                },
                childCount: widget.episodeCommentsList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                addSemanticIndexes: false,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget get commentsInfo {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(' 本集标题  '),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${widget.episodeInfo.readType()}.${widget.episodeInfo.episode} ${widget.episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
                Text(
                    (widget.episodeInfo.nameCn != '')
                        ? '${widget.episodeInfo.readType()}.${widget.episodeInfo.episode} ${widget.episodeInfo.nameCn}'
                        : '${widget.episodeInfo.readType()}.${widget.episodeInfo.episode} ${widget.episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.only(left: 4.0, right: 4.0)),
              ),
              onPressed: () {
                showEpisodeSelection();
              },
              child: const Text(
                '手动切换',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 选择要查看评论的集数
  void showEpisodeSelection() {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context, // 必须传入 BuildContext
      barrierDismissible: false, // 禁止点击遮罩关闭
      builder: (context) {
        return AlertDialog(
          title: const Text('输入集数'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return TextField(
                controller: textController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  hintText: '请输入1-999之间的集数',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 使用 Navigator 关闭对话框
              child: Text(
                '取消',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final inputText = textController.text.trim();

                if (inputText.isEmpty) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('请输入集数')));
                  return;
                }

                final episode = int.tryParse(inputText) ?? 0;
                if (episode <= 0 || episode > 999) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('请输入1-999之间的有效集数')));
                  return;
                }

                setState(() => ep = episode);
                _refreshIndicatorKey.currentState?.show();
                Navigator.pop(context); // 关闭对话框
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int episode = widget.episode;
    return Scaffold(
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [commentsInfo, Expanded(child: episodeCommentsBody)],
        ),
        onRefresh: () async {
          await widget.loadComments(ep == 0 ? episode : ep);
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }
}
