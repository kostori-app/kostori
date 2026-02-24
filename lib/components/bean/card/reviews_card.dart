// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';
import 'package:kostori/pages/bangumi/bangumi_reviews_page.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ReviewsCard extends StatelessWidget {
  const ReviewsCard({
    super.key,
    required this.reviewsItem,
    this.isBottom = false,
    this.isBone = false,
  });

  const ReviewsCard.bone({super.key})
    : reviewsItem = null,
      isBottom = false,
      isBone = true;

  final bool isBottom;
  final ReviewsItem? reviewsItem;
  final bool isBone;

  @override
  Widget build(BuildContext context) {
    if (isBone) {
      return _buildBone(context);
    }

    return _buildNormal(context);
  }

  Widget _buildBone(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final contentMaxWidth = isDesktop ? 600.0 : double.infinity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Skeletonizer.zone(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone.circle(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone.text(width: 180),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Bone.text(width: 80),
                            const SizedBox(width: 4),
                            const Text(' / '),
                            Bone.text(width: 60),
                            const SizedBox(width: 4),
                            const Text(' / '),
                            Bone.text(width: 30),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Bone.text(width: double.infinity),
                        const SizedBox(height: 4),
                        Bone.text(width: double.infinity),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNormal(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final contentMaxWidth = isDesktop ? 600.0 : double.infinity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _handleTap(context),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(
                      reviewsItem!.entry.icon ==
                              'https://lain.bgm.tv/pic/photo/g/no_photo.png'
                          ? reviewsItem!.user.avatar.large
                          : reviewsItem!.entry.icon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewsItem!.entry.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                reviewsItem!.user.nickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(' / '),
                            Text(
                              Utils.dateFormat(reviewsItem!.entry.createdAt),
                            ),
                            if (reviewsItem!.entry.replies != 0) ...[
                              const Text(' / '),
                              Text('+${reviewsItem!.entry.replies}'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _handleTap(context),
                          child: IgnorePointer(
                            child: BBCodeWidget(
                              bbcode: reviewsItem!.entry.summary,
                              showImg: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final page = BangumiReviewsPage(reviewsItem: reviewsItem!);

    if (!isBottom) {
      context.to(() => page);
    } else {
      showModalBottomSheet(
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 3 / 4,
          maxWidth: MediaQuery.of(context).size.width < 600
              ? MediaQuery.of(context).size.width
              : App.isDesktop
              ? MediaQuery.of(context).size.width * 9 / 16
              : MediaQuery.of(context).size.width,
        ),
        clipBehavior: Clip.antiAlias,
        context: context,
        builder: (context) => page,
      );
    }
  }
}
