import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/topics_info_comments_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/pages/bangumi/bangumi_info_page.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class BangumiTopicsPage extends ConsumerStatefulWidget {
  const BangumiTopicsPage({super.key, required this.id});

  final int id;

  @override
  ConsumerState<BangumiTopicsPage> createState() => _BangumiTopicsPageState();
}

class _BangumiTopicsPageState extends ConsumerState<BangumiTopicsPage> {
  final ScrollController scrollController = ScrollController();
  final Map<int, GlobalKey> _replyKeys = {};

  int get id => widget.id;
  TopicsInfoItem? topicsInfoItem;
  bool isLoading = true;
  bool isHide = false;

  void _buildReplyKeys() {
    if (topicsInfoItem == null) return;
    _replyKeys.clear();
    final replies = topicsInfoItem!.replies;
    for (int i = 1; i < replies.length; i++) {
      _replyKeys[replies[i].id] = GlobalKey();
    }
  }

  void _scrollToAuthor(String authorName) {
    if (topicsInfoItem == null) return;
    final replies = topicsInfoItem!.replies;
    for (int i = 1; i < replies.length; i++) {
      if (replies[i].creator.nickname == authorName) {
        final key = _replyKeys[replies[i].id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
        return;
      }
    }
  }

  Future<void> queryBangumiTopicsInfoByID(int id) async {
    topicsInfoItem = await Bangumi.instance.getTopicsInfoByID(id);
    if (topicsInfoItem != null) {
      isLoading = false;
      _buildReplyKeys();
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
      setState(() => isHide = true);
    } else {
      setState(() => isHide = false);
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
                firstChild: Container(),
                secondChild: Row(
                  children: [
                    if (topicsInfoItem != null) ...[
                      BangumiAvatar(url: topicsInfoItem!.creator.avatar.large),
                      const SizedBox(width: 8),
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
                  ],
                ),
                crossFadeState: isHide
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),
            ),

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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(6),
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
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .toOpacity(0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Image.network(
                                                  topicsInfoItem!
                                                      .subject
                                                      .images
                                                      .large,
                                                  width: 22,
                                                  height: 22,
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
                                  const SizedBox(width: 4),
                                  Text(
                                    Utils.dateFormat(topicsInfoItem!.createdAt),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              if (topicsInfoItem != null) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    BangumiAvatar(
                                      url: topicsInfoItem!.creator.avatar.large,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            topicsInfoItem!.creator.nickname,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '@${topicsInfoItem!.creator.username}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              BBCodeWidget(
                                bbcode: topicsInfoItem!.replies[0].content,
                                onQuoteTap: _scrollToAuthor,
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
                                    t.bangumiCommentsTitle,
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
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Skeletonizer.zone(
                                  enabled: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Bone.multiText(lines: 1),
                                      SizedBox(height: 12),
                                      Bone.text(width: 100),
                                      SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Bone.circle(size: 40),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Bone.text(width: 140),
                                                SizedBox(height: 8),
                                                Bone.text(width: 90),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      Bone.multiText(lines: 10),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 420,
                                  child: ListView.separated(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: 6,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 20),
                                    itemBuilder: (_, index) {
                                      return Skeletonizer.zone(
                                        enabled: true,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: const [
                                                  Bone.circle(size: 40),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Bone.text(width: 140),
                                                        SizedBox(height: 8),
                                                        Bone.text(width: 90),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              const Bone.multiText(lines: 2),
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
              ),
            ),

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
    final reply = topicsInfoItem!.replies[replyIndex];
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
              key: _replyKeys[reply.id],
              topicsInfoItem: topicsInfoItem!,
              replyIndex: replyIndex,
              onQuoteTap: _scrollToAuthor,
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
