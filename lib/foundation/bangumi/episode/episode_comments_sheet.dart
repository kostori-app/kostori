import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/components/bean/card/episode_comments_card.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';

class EpisodeCommentsSheet extends StatefulWidget {
  const EpisodeCommentsSheet(
      {super.key,
      required this.episodeInfo,
      required this.loadComments,
      required this.episode,
      required this.infoController});

  final EpisodeInfo episodeInfo;

  final Future<void> Function(int episode, {int offset}) loadComments;

  final int episode;

  final InfoController infoController;

  @override
  State<EpisodeCommentsSheet> createState() => _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends State<EpisodeCommentsSheet> {
  bool commentsQueryTimeout = false;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  late InfoController infoController;

  /// episode input by [showEpisodeSelection]
  int ep = 0;

  @override
  void initState() {
    infoController = widget.infoController;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    ep = 0;
    // wait until currentState is not null
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (infoController.episodeCommentsList.isEmpty) {
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
    return Builder(builder: (BuildContext context) {
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
        key: PageStorageKey<String>('集评论'),
        slivers: [
          SliverLayoutBuilder(
            builder: (context, _) {
              if (infoController.episodeCommentsList.isNotEmpty) {
                return SliverList.separated(
                  addAutomaticKeepAlives: false,
                  itemCount: infoController.episodeCommentsList.length,
                  itemBuilder: (context, index) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > 950
                                ? 950
                                : MediaQuery.sizeOf(context).width - 32,
                            child: EpisodeCommentsCard(
                              commentItem:
                                  infoController.episodeCommentsList[index],
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
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                          child: EpisodeCommentsCard.bone(),
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
    });
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
                    '${infoController.episodeInfo.readType()}.${infoController.episodeInfo.sort} ${infoController.episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
                Text(
                    (infoController.episodeInfo.nameCn != '')
                        ? '${infoController.episodeInfo.readType()}.${infoController.episodeInfo.sort} ${infoController.episodeInfo.nameCn}'
                        : '${infoController.episodeInfo.readType()}.${infoController.episodeInfo.sort} ${infoController.episodeInfo.name}',
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
        onRefresh: () async {
          await widget.loadComments(ep == 0 ? episode : ep);
          if (mounted) setState(() {});
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: commentsInfo),
            SliverFillRemaining(
              hasScrollBody: true,
              child: episodeCommentsBody,
            ),
          ],
        ),
      ),
    );
  }
}
