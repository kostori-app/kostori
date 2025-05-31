import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';

import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';

import 'package:kostori/components/bean/card/episode_comments_card.dart';
import 'package:kostori/utils/translations.dart';
import 'package:url_launcher/url_launcher.dart';

class BangumiEpisodeInfoPage extends StatefulWidget {
  const BangumiEpisodeInfoPage(
      {super.key, required this.episode, required this.infoController});

  final EpisodeInfo episode;
  final InfoController infoController;

  @override
  State<BangumiEpisodeInfoPage> createState() => _BangumiEpisodeInfoPageState();
}

class _BangumiEpisodeInfoPageState extends State<BangumiEpisodeInfoPage> {
  EpisodeInfo get episode => widget.episode;

  InfoController get infoController => widget.infoController;
  bool commentsQueryTimeout = false;

  Future<void> loadComments(int episode, {int offset = 0}) async {
    commentsQueryTimeout = false;
    await queryBangumiEpisodeCommentsByID(episode, offset: offset).then((_) {
      if (infoController.episodeCommentsList.isEmpty && mounted) {
        setState(() {
          commentsQueryTimeout = true;
        });
      }
    });
  }

  Future<void> queryBangumiEpisodeCommentsByID(int id, {int offset = 0}) async {
    await infoController.queryBangumiEpisodeCommentsByEpID(id, offset: offset);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    loadComments(episode.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad,
        },
      ),
      slivers: [
        SliverAppBar(
          title: Text('剧集详情'.tl),
          backgroundColor: Colors.transparent,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Theme.of(context).colorScheme.surface.toOpacity(0.22),
              ),
            ),
          ),
          pinned: true,
          floating: true,
          snap: true,
          elevation: 0,
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
                  Uri.parse('https://bangumi.tv/ep/${episode.id}'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(Icons.open_in_browser_rounded),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ep${episode.sort}.${episode.nameCn.isNotEmpty ? episode.nameCn : episode.name}",
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (episode.nameCn.isNotEmpty)
                        Text("ep${episode.sort}.${episode.name}"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text("放送时间：${episode.airDate}"),
                          const SizedBox(width: 8),
                          Text("时长：${episode.duration}"),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(episode.desc),
                      const SizedBox(height: 16),
                      Text(
                        '评论 (${episode.comment})',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        /// 👇 评论部分直接插入原来的 SliverList 内容
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
                separatorBuilder: (context, index) {
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
                          child: const Divider(
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

            // 骨架加载态
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
    ));
  }
}
