import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/foundation/bangumi/episode/episode_item.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/components/bean/card/episode_comments_card.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bbcode/bbcode_widget.dart';
import '../../components/components.dart';
import '../../foundation/widget_utils.dart';

class BangumiEpisodeInfoPage extends StatefulWidget {
  const BangumiEpisodeInfoPage(
      {super.key, required this.episode, required this.infoController});

  final EpisodeInfo episode;
  final InfoController infoController;

  @override
  State<BangumiEpisodeInfoPage> createState() => _BangumiEpisodeInfoPageState();
}

class _BangumiEpisodeInfoPageState extends State<BangumiEpisodeInfoPage> {
  final ScrollController scrollController = ScrollController();

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
    Widget widget = Scaffold(
        body: SafeArea(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverAppbar(
            style: AppbarStyle.blur,
            title:
                Text(episode.nameCn.isNotEmpty ? episode.nameCn : episode.name),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: BBCodeWidget(bbcode: episode.desc),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 120,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.grey.toOpacity(0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            '评论',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${episode.comment}', style: ts.s12),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
          (infoController.episodeCommentsList.isNotEmpty)
              ? SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: Observer(builder: (context) {
                    return SliverList.separated(
                      itemCount: infoController.episodeCommentsList.length,
                      separatorBuilder: (context, index) =>
                          _buildDivider(context),
                      itemBuilder: (context, index) => _buildReplyCard(
                        context,
                        index,
                      ),
                    );
                  }))
              : SliverList.builder(
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
                ),
        ],
      ),
    ));
    widget = AppScrollBar(
      topPadding: 82,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );
    return widget;
  }

  Widget _buildReplyCard(BuildContext context, int index) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width > 900
                ? 900
                : MediaQuery.sizeOf(context).width - 32,
            child: EpisodeCommentsCard(
              commentItem: infoController.episodeCommentsList[index],
              replyIndex: index,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
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
            child: const Divider(thickness: 0.5, indent: 10, endIndent: 10),
          ),
        ),
      ),
    );
  }
}
