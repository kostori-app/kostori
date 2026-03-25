import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/bean/card/reviews_comments_card.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_comments_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_info_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/bangumi.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

// 日志页
class BangumiReviewsPage extends ConsumerStatefulWidget {
  const BangumiReviewsPage({super.key, required this.reviewsItem});

  final ReviewsItem reviewsItem;

  @override
  ConsumerState<BangumiReviewsPage> createState() => _BangumiReviewsPageState();
}

class _BangumiReviewsPageState extends ConsumerState<BangumiReviewsPage> {
  final ScrollController scrollController = ScrollController();
  final Map<int, GlobalKey> _replyKeys = {};

  ReviewsItem get reviewsItem => widget.reviewsItem;
  ReviewsInfoItem? reviewsInfoItem;
  List<ReviewsCommentsItem> reviewsCommentsItem = [];
  List<BangumiItem> bangumiReviewsSubjects = [];
  bool isLoading = true;
  bool isHide = false;

  Future<void> queryBangumiReviewsByID(int id) async {
    reviewsInfoItem = await Bangumi.instance.getReviewsInfoByID(id);
    reviewsCommentsItem = await Bangumi.instance.getReviewsCommentsByID(id);
    bangumiReviewsSubjects = await Bangumi.instance.getReviewsSubjectsByID(id);
    isLoading = false;
    // ← 加这段
    _replyKeys.clear();
    for (final item in reviewsCommentsItem) {
      _replyKeys[item.id] = GlobalKey();
    }
    if (mounted) setState(() {});
  }

  void _scrollToAuthor(String authorName) {
    for (final item in reviewsCommentsItem) {
      if (item.user.nickname == authorName) {
        final key = _replyKeys[item.id];
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

  @override
  void initState() {
    queryBangumiReviewsByID(reviewsItem.entry.id);
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
    final bool isDataReady = !isLoading && reviewsInfoItem != null;

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
                    CircleAvatar(
                      backgroundImage: NetworkImage(
                        reviewsItem.user.avatar.large,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reviewsItem.entry.title,
                            style: const TextStyle(fontSize: 18),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                reviewsItem.user.nickname,
                                style: const TextStyle(fontSize: 14),
                              ),
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
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: isDataReady
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reviewsItem.entry.title,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Utils.dateFormat(reviewsItem.entry.createdAt),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      reviewsItem.user.avatar.large,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              reviewsItem.user.nickname,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '@${reviewsItem.user.username}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              BBCodeWidget(bbcode: reviewsInfoItem!.content),
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
                              if (bangumiReviewsSubjects.isNotEmpty) ...[
                                Text(
                                  t.linkedItems,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 240,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: bangumiReviewsSubjects.length,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: SizedBox(
                                          width: 160,
                                          height: 240,
                                          child: BangumiBriefCard(
                                            bangumiItem:
                                                bangumiReviewsSubjects[index],
                                            heroTag: 'Reviews$index',
                                          ),
                                        ),
                                      );
                                    },
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
                              ],
                              if (reviewsInfoItem!.replies > 0)
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
                                        '${reviewsInfoItem!.replies}',
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
                                /// 顶部标题区域骨架
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

                                /// 列表骨架
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

                                              /// 内容骨架
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

            // 评论区
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.separated(
                itemCount: reviewsCommentsItem.length,
                separatorBuilder: (context, index) => _buildDivider(context),
                itemBuilder: (context, index) => _buildReplyCard(
                  context,
                  index + 1,
                  reviewsCommentsItem[index],
                ),
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

  Widget _buildReplyCard(
    BuildContext context,
    int replyIndex,
    ReviewsCommentsItem item,
  ) {
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
            child: ReviewsCommentsCard(
              key: _replyKeys[item.id],
              replyIndex: replyIndex,
              reviewsCommentsItem: item,
              reviewsInfoItem: reviewsInfoItem!,
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
