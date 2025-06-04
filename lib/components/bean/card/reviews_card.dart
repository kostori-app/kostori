import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';

import '../../../bbcode/bbcode_widget.dart';
import '../../../foundation/bangumi/reviews/reviews_item.dart';
import '../../../pages/bangumi/bangumi_reviews_page.dart';
import '../../../utils/utils.dart';

class ReviewsCard extends StatelessWidget {
  const ReviewsCard({
    super.key,
    required this.reviewsItem,
    this.isBottom = false,
  });

  final bool isBottom;
  final ReviewsItem reviewsItem;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final contentMaxWidth = isDesktop ? 600.0 : double.infinity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              _handleTap(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(
                      reviewsItem.entry.icon ==
                              'https://lain.bgm.tv/pic/photo/g/no_photo.png'
                          ? reviewsItem.user.avatar.large
                          : reviewsItem.entry.icon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewsItem.entry.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                reviewsItem.user.nickname,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(' / '),
                            Text(Utils.dateFormat(reviewsItem.entry.createdAt)),
                            if (reviewsItem.entry.replies != 0) ...[
                              const Text(' / '),
                              Text('+${reviewsItem.entry.replies}'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.translucent, // 让透明区域也能响应
                          onTap: () {
                            _handleTap(context);
                          },
                          child: IgnorePointer(
                            child: BBCodeWidget(
                              bbcode: reviewsItem.entry.summary,
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
    final page = BangumiReviewsPage(
      reviewsItem: reviewsItem,
    );

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
