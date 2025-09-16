import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bean/card/topics_info_comments_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BangumiTopicsPage extends StatefulWidget {
  const BangumiTopicsPage({super.key, required this.id});

  final int id;

  @override
  State<BangumiTopicsPage> createState() => _BangumiTopicsPageState();
}

class _BangumiTopicsPageState extends State<BangumiTopicsPage> {
  final ScrollController scrollController = ScrollController();

  int get id => widget.id;
  TopicsInfoItem? topicsInfoItem;
  bool isLoading = true;
  bool isHide = false;

  Future<void> queryBangumiTopicsInfoByID(int id) async {
    topicsInfoItem = await Bangumi.getTopicsInfoByID(id);
    if (topicsInfoItem != null) {
      isLoading = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    queryBangumiTopicsInfoByID(id);
    scrollController.addListener(scrollListener);
    super.initState();
  }

  @override
  void dispose() {
    scrollController.removeListener(scrollListener);
    super.dispose();
  }

  void scrollListener() {
    if (scrollController.position.pixels >= 60) {
      setState(() {
        isHide = true;
      });
    } else {
      setState(() {
        isHide = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDataReady = !isLoading && topicsInfoItem != null;

    Widget widget = Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverAppbar(
              style: AppbarStyle.blur,
              title: AnimatedCrossFade(
                firstChild: Container(), // 隐藏状态
                secondChild: Row(
                  children: [
                    if (topicsInfoItem != null)
                      CircleAvatar(
                        backgroundImage: NetworkImage(
                          topicsInfoItem!.creator.avatar.large,
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (topicsInfoItem != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topicsInfoItem!.title,
                              style: const TextStyle(fontSize: 18),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  topicsInfoItem!.creator.nickname,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (isDataReady) ...[
                                  const Text(
                                    ' • ',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  Text(
                                    topicsInfoItem!.subject.nameCN.isEmpty
                                        ? topicsInfoItem!.subject.name
                                        : topicsInfoItem!.subject.nameCN,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                crossFadeState: isHide
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ),

            // 正文内容区域
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: isDataReady
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topicsInfoItem!.title,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Material(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          context.to(
                                            () => BangumiInfoPage(
                                              bangumiItem: BangumiItem(
                                                id: topicsInfoItem!.subject.id,
                                                type: 2,
                                                name: '',
                                                nameCn: '',
                                                summary: '',
                                                airDate: '',
                                                airWeekday: 0,
                                                rank: 0,
                                                total: 0,
                                                totalEpisodes: 0,
                                                score: 0,
                                                images: {
                                                  'large': topicsInfoItem!
                                                      .subject
                                                      .images
                                                      .large,
                                                },
                                                tags: [],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  topicsInfoItem!
                                                      .subject
                                                      .images
                                                      .large,
                                                  width: 40,
                                                  height: 40,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                topicsInfoItem!
                                                        .subject
                                                        .nameCN
                                                        .isEmpty
                                                    ? topicsInfoItem!
                                                          .subject
                                                          .name
                                                    : topicsInfoItem!
                                                          .subject
                                                          .nameCN,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    Utils.dateFormat(topicsInfoItem!.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: BBCodeWidget(
                                  bbcode: topicsInfoItem!.replies[0].content,
                                ),
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
                                  const Text(
                                    '吐槽',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${topicsInfoItem!.replies.length - 1}',
                                      style: ts.s12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Skeletonizer.zone(
                                enabled: true,
                                child: const Bone.multiText(lines: 12),
                              ),
                              const SizedBox(height: 16),
                              // 替换 Expanded + Column 为 ListView
                              SizedBox(
                                height:
                                    400, // ❗给个固定高度，或者用 Expanded 包这个 SizedBox
                                child: ListView.builder(
                                  itemCount: 6,
                                  itemBuilder: (_, index) => Skeletonizer.zone(
                                    enabled: true,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Bone.circle(size: 36),
                                              SizedBox(width: 8),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Bone.text(width: 80),
                                                  SizedBox(height: 8),
                                                  Bone.text(width: 60),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          const Bone.multiText(lines: 2),
                                          const Divider(
                                            thickness: 0.5,
                                            indent: 10,
                                            endIndent: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // 评论列表（跳过第一条作为正文）
            if (isDataReady && topicsInfoItem!.replies.length > 1)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverList.separated(
                  itemCount: topicsInfoItem!.replies.length - 1,
                  separatorBuilder: (context, index) => _buildDivider(context),
                  itemBuilder: (context, index) =>
                      _buildReplyCard(context, index + 1),
                ),
              ),
          ],
        ),
      ),
    );

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

  Widget _buildReplyCard(BuildContext context, int replyIndex) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width > 900
                ? 900
                : MediaQuery.sizeOf(context).width - 32,
            child: TopicsInfoCommentsCard(
              topicsInfoItem: topicsInfoItem!,
              replyIndex: replyIndex,
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
