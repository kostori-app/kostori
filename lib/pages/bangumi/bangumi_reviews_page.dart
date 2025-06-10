import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_comments_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/utils/translations.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../bbcode/bbcode_widget.dart';
import '../../components/bangumi_widget.dart';
import '../../components/bean/card/reviews_comments_card.dart';
import '../../components/components.dart';
import '../../foundation/bangumi/bangumi_item.dart';
import '../../foundation/bangumi/reviews/reviews_info_item.dart';
import '../../network/bangumi.dart';
import '../../utils/utils.dart';

class BangumiReviewsPage extends StatefulWidget {
  const BangumiReviewsPage({super.key, required this.reviewsItem});

  final ReviewsItem reviewsItem;

  @override
  State<BangumiReviewsPage> createState() => _BangumiReviewsPageState();
}

class _BangumiReviewsPageState extends State<BangumiReviewsPage> {
  final ScrollController scrollController = ScrollController();

  ReviewsItem get reviewsItem => widget.reviewsItem;
  ReviewsInfoItem? reviewsInfoItem;
  List<ReviewsCommentsItem> reviewsCommentsItem = [];
  List<BangumiItem> bangumiReviewsSubjects = [];
  bool isLoading = true;
  bool isHide = false;

  Future<void> queryBangumiReviewsByID(int id) async {
    reviewsInfoItem = await Bangumi.getReviewsInfoByID(id);
    reviewsCommentsItem = await Bangumi.getReviewsCommentsByID(id);
    bangumiReviewsSubjects = await Bangumi.getReviewsSubjectsByID(id);
    isLoading = false;
    if (mounted) setState(() {});
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
                  firstChild: Container(), // 隐藏状态
                  secondChild: Row(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            NetworkImage(reviewsItem.user.avatar.large),
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
                )),

            // 正文内容区域
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: isDataReady
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reviewsItem.entry.title,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(Utils.dateFormat(
                                    reviewsItem.entry.createdAt)),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: BBCodeWidget(
                                      bbcode: reviewsInfoItem!.content),
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
                                if (bangumiReviewsSubjects.isNotEmpty) ...[
                                  Text(
                                    'Linked Items'.tl,
                                    style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 240, // 控制网格卡片的高度
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: bangumiReviewsSubjects.length,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: SizedBox(
                                            width: 160, // 给定一个确定的宽度（你可以根据需要调整）
                                            height: 240, // 确保和外层一致，避免 Stack 报错
                                            child: BangumiWidget.buildBriefMode(
                                              context,
                                              bangumiReviewsSubjects[index],
                                              'Reviews$index',
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
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                            '${reviewsInfoItem!.replies}',
                                            style: ts.s12),
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
                                    itemBuilder: (_, index) =>
                                        Skeletonizer.zone(
                                      enabled: true,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0),
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
                                                endIndent: 10),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )),
                ),
              ),
            ),
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

  Widget _buildReplyCard(BuildContext context, int replyIndex,
      ReviewsCommentsItem reviewsCommentsItem) {
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
              replyIndex: replyIndex,
              reviewsCommentsItem: reviewsCommentsItem,
              reviewsInfoItem: reviewsInfoItem!,
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
