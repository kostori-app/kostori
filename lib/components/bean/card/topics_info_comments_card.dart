import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';

class TopicsInfoCommentsCard extends StatelessWidget {
  const TopicsInfoCommentsCard({
    super.key,
    required this.topicsInfoItem,
    required this.replyIndex,
    this.onQuoteTap,
  });

  final TopicsInfoItem topicsInfoItem;
  final int replyIndex;
  final void Function(String authorName)? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topicsInfoItem.replies[replyIndex].state == 0) ...[
            Row(
              children: [
                BangumiAvatar(
                  url: topicsInfoItem.replies[replyIndex].creator.avatar.large,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topicsInfoItem.replies[replyIndex].creator.nickname),
                    Row(
                      children: [
                        Text(
                          Utils.dateFormat(
                            topicsInfoItem.replies[replyIndex].createdAt,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('#${replyIndex + 1}'),
                        if (topicsInfoItem.replies[replyIndex].creatorID ==
                            topicsInfoItem.creatorID)
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
                            child: Text(t.topicsPoster),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBCodeWidget(
              bbcode: topicsInfoItem.replies[replyIndex].content,
              onQuoteTap: onQuoteTap,
            ),
            _ChildRepliesList(
              replies: topicsInfoItem.replies[replyIndex].replies,
              masterId: topicsInfoItem.creatorID,
              id: topicsInfoItem.replies[replyIndex].creatorID,
              onQuoteTap: onQuoteTap,
            ),
          ],
          if (topicsInfoItem.replies[replyIndex].state == 6)
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
                      url: topicsInfoItem
                          .replies[replyIndex]
                          .creator
                          .avatar
                          .large,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topicsInfoItem.replies[replyIndex].creator.nickname,
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

  final List<TopicReply> replies;
  final int masterId;
  final int id;
  final void Function(String authorName)? onQuoteTap;

  @override
  State<_ChildRepliesList> createState() => _ChildRepliesListState();
}

class _ChildRepliesListState extends State<_ChildRepliesList> {
  bool _showAll = false;

  // 用 replyId 存每条子楼层的 key
  final Map<int, GlobalKey> _childKeys = {};

  void _scrollToAuthorInChildren(String authorName) {
    // 先在子楼层里找
    for (final reply in widget.replies) {
      if (reply.creator.nickname == authorName) {
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
    // 子楼层里找不到，冒泡给主楼层
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

    // 预先建好所有子楼层的 key
    for (final reply in widget.replies) {
      _childKeys.putIfAbsent(reply.id, GlobalKey.new);
    }

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
                        BangumiAvatar(url: reply.creator.avatar.large),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reply.creator.nickname),
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
child: Text(t.postOwner),
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
                      onQuoteTap: _scrollToAuthorInChildren,
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
