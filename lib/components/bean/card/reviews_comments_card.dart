import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_comments_item.dart';
import 'package:kostori/foundation/bangumi/reviews/reviews_info_item.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

class ReviewsCommentsCard extends StatelessWidget {
  const ReviewsCommentsCard({
    super.key,
    required this.reviewsCommentsItem,
    required this.replyIndex,
    required this.reviewsInfoItem,
    this.onQuoteTap,
  });

  final ReviewsCommentsItem reviewsCommentsItem;
  final ReviewsInfoItem reviewsInfoItem;
  final int replyIndex;
  final void Function(String authorName)? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reviewsCommentsItem.state == 0) ...[
            Row(
              children: [
                BangumiAvatar(url: reviewsCommentsItem.user.avatar.large),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewsCommentsItem.user.nickname),
                    Row(
                      children: [
                        Text(Utils.dateFormat(reviewsCommentsItem.createdAt)),
                        const SizedBox(width: 4),
                        Text('#$replyIndex'),
                        if (reviewsCommentsItem.user.id ==
                            reviewsInfoItem.user.id)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
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
                            child: const Text('作者'),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBCodeWidget(
              bbcode: reviewsCommentsItem.content,
              onQuoteTap: onQuoteTap,
            ),
            _ChildRepliesList(
              replies: reviewsCommentsItem.replies,
              masterId: reviewsInfoItem.user.id,
              id: reviewsCommentsItem.user.id,
              onQuoteTap: onQuoteTap,
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
                    BangumiAvatar(
                      url: reviewsCommentsItem.user.avatar.large,
                      radius: 20,
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
                          Text(
                            t.deletedReply,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChildRepliesList extends StatefulWidget {
  const _ChildRepliesList({
    required this.replies,
    required this.masterId,
    required this.id,
    this.onQuoteTap,
  });

  final List<ReviewsCommentsItem> replies;
  final int masterId;
  final int id;
  final void Function(String authorName)? onQuoteTap;

  @override
  State<_ChildRepliesList> createState() => _ChildRepliesListState();
}

class _ChildRepliesListState extends State<_ChildRepliesList> {
  bool _showAll = false;
  final Map<int, GlobalKey> _childKeys = {};

  @override
  void initState() {
    super.initState();
    for (final reply in widget.replies) {
      _childKeys[reply.id] = GlobalKey();
    }
  }

  void _scrollToAuthor(String authorName) {
    for (final reply in widget.replies) {
      if (reply.user.nickname == authorName) {
        final key = _childKeys[reply.id];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
          return;
        }
      }
    }
    widget.onQuoteTap?.call(authorName);
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.replies.length;
    const int maxDisplay = 3;
    final int displayCount = _showAll
        ? total
        : (total > maxDisplay ? maxDisplay : total);

    if (total < 1) return const SizedBox();

    return Column(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(bottom: 0),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final reply = widget.replies[index];
            return KeyedSubtree(
              key: _childKeys[reply.id],
              child: Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Divider(
                      color: Theme.of(context).dividerColor.withAlpha(60),
                    ),
                    Row(
                      children: [
                        BangumiAvatar(url: reply.user.avatar.large),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reply.user.nickname),
                            Row(
                              children: [
                                Text(Utils.dateFormat(reply.createdAt)),
                                const SizedBox(width: 4),
                                Text('#${index + 1}'),
                                if (reply.creatorID == widget.masterId)
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
child: Text(t.author),
                                  ),
                                if (reply.creatorID == widget.id)
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
                                    child: Text(t.floorOwner),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BBCodeWidget(
                      bbcode: reply.content,
                      onQuoteTap: _scrollToAuthor,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (total - 1 > maxDisplay)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? t.collapse : t.expandCount(total: total)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
