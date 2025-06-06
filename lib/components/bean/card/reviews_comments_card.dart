import 'package:flutter/material.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_comments_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_info_item.dart';

import '../../../bbcode/bbcode_widget.dart';
import '../../../utils/utils.dart';

class ReviewsCommentsCard extends StatelessWidget {
  const ReviewsCommentsCard({
    super.key,
    required this.reviewsCommentsItem,
    required this.replyIndex,
    required this.reviewsInfoItem,
  });

  final ReviewsCommentsItem reviewsCommentsItem;
  final ReviewsInfoItem reviewsInfoItem;
  final int replyIndex;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reviewsCommentsItem.state == 0) ...[
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        NetworkImage(reviewsCommentsItem.user.avatar.large),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reviewsCommentsItem.user.nickname),
                      Row(
                        children: [
                          Text(Utils.dateFormat(reviewsCommentsItem.createdAt)),
                          const SizedBox(
                            width: 4,
                          ),
                          Text('#$replyIndex'),
                          if (reviewsCommentsItem.user.id ==
                              reviewsInfoItem.user.id)
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
                              child: Text('作者'),
                            ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              BBCodeWidget(bbcode: reviewsCommentsItem.content),
              _ChildRepliesList(
                replies: reviewsCommentsItem.replies,
                masterId: reviewsInfoItem.user.id,
                id: reviewsCommentsItem.user.id,
              ),
            ],
            if (reviewsCommentsItem.state == 6)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage:
                            NetworkImage(reviewsCommentsItem.user.avatar.large),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reviewsCommentsItem.user.nickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '删除了回复',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _ChildRepliesList extends StatefulWidget {
  const _ChildRepliesList(
      {required this.replies, required this.masterId, required this.id});

  final List<ReviewsCommentsItem> replies;
  final int masterId;
  final int id;

  @override
  State<_ChildRepliesList> createState() => _ChildRepliesListState();
}

class _ChildRepliesListState extends State<_ChildRepliesList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final int total = widget.replies.length;
    final int maxDisplay = 3;
    final int displayCount =
        _showAll ? total : (total > maxDisplay ? maxDisplay : total);

    // 如果没有子楼层，不渲染
    if (total < 1) return const SizedBox();

    // 注意：跳过第 0 条，子楼层从第 1 项开始
    return Column(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 0),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final reply = widget.replies[index];
            return Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Divider(
                    color: Theme.of(context).dividerColor.withAlpha(60),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(reply.user.avatar.large),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reply.user.nickname),
                          Row(
                            children: [
                              Text(Utils.dateFormat(reply.createdAt)),
                              const SizedBox(
                                width: 4,
                              ),
                              Text('#${index + 1}'),
                              if (reply.creatorID == widget.masterId)
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('作者'),
                                ),
                              if (reply.creatorID == widget.id)
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('层主'),
                                ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BBCodeWidget(bbcode: reply.content),
                ],
              ),
            );
          },
        ),

        // 展开 / 收起按钮
        if (total - 1 > maxDisplay)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAll = !_showAll;
                    });
                  },
                  child: Text(_showAll ? '收起' : '展开 ($total)'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
