import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/utils/translations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../foundation/bangumi/episode/episode_item.dart';
import '../../components/network_img_layer.dart';
import 'bangumi_episode_info_page.dart';
import 'info_controller.dart';

class BangumiAllEpisodePage extends StatefulWidget {
  final List<EpisodeInfo> allEpisodes;
  final InfoController infoController;

  const BangumiAllEpisodePage(
      {super.key, required this.allEpisodes, required this.infoController});

  @override
  State<BangumiAllEpisodePage> createState() => _BangumiAllEpisodePageState();
}

class _BangumiAllEpisodePageState extends State<BangumiAllEpisodePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(
      children: [
        Positioned.fill(
          bottom: kTextTabBarHeight,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.4,
              child: LayoutBuilder(
                builder: (context, boxConstraints) {
                  return ImageFiltered(
                    imageFilter:
                        ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
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
                        src:
                            widget.infoController.bangumiItem.images['large'] ??
                                '',
                        width: boxConstraints.maxWidth,
                        height: boxConstraints.maxHeight,
                        fadeInDuration: const Duration(milliseconds: 0),
                        fadeOutDuration: const Duration(milliseconds: 0),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        CustomScrollView(
          slivers: [
            // SliverAppBar 全宽显示，不受 maxWidth 限制
            SliverAppBar(
              title: Text('All Episodes'.tl),
              backgroundColor: Colors.transparent,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color:
                        Theme.of(context).colorScheme.surface.toOpacity(0.22),
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
                      Uri.parse(
                          'https://bangumi.tv/subject/${widget.infoController.bangumiItem.id}/ep'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.open_in_browser_rounded),
                ),
              ],
            ),

            // 使用 SliverToBoxAdapter 包裹 Center + ConstrainedBox 限制内容宽度
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Column(
                    children: widget.allEpisodes.map((episode) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(20),
                            right: Radius.circular(20),
                          ),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .toOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.toOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(20),
                              right: Radius.circular(20),
                            ),
                          ),
                          child: InkWell(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(20),
                              right: Radius.circular(20),
                            ),
                            onTap: () {
                              context.to(() => BangumiEpisodeInfoPage(
                                    episode: episode,
                                    infoController: widget.infoController,
                                  ));
                            },
                            onLongPress: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    content: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 320),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "ep${episode.sort}.${episode.nameCn.isNotEmpty ? episode.nameCn : episode.name}",
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          if (episode.nameCn.isNotEmpty)
                                            Text(
                                                "ep${episode.sort}.${episode.name}"),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text("放送时间：${episode.airDate}"),
                                              const SizedBox(width: 8),
                                              Text("时长：${episode.duration}"),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(episode.desc),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Text(
                                "ep${episode.sort}.${episode.nameCn.isNotEmpty ? episode.nameCn : episode.name}",
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ));
  }
}
