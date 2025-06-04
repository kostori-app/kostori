import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../foundation/bangumi/comment/comment_item.dart';

class EpisodeCommentsCard extends StatelessWidget {
  EpisodeCommentsCard(
      {super.key, required this.commentItem, required this.replyIndex}) {
    isBone = false;
  }

  EpisodeCommentsCard.bone({super.key}) {
    isBone = true;
    commentItem = null;
  }

  late final int replyIndex;
  late final EpisodeCommentItem? commentItem;
  late final bool isBone;

  @override
  Widget build(BuildContext context) {
    if (isBone) {
      return Skeletonizer.zone(
        enabled: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Bone.circle(size: 36),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
            const Divider(thickness: 0.5, indent: 10, endIndent: 10),
          ],
        ),
      );
    }

    final id = commentItem!.comment.user.id;

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage(commentItem!.comment.user.avatar.large),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentItem!.comment.user.nickname),
                    Row(
                      children: [
                        Text(Utils.dateFormat(commentItem!.comment.createdAt)),
                        const SizedBox(
                          width: 4,
                        ),
                        Text('#${replyIndex + 1}')
                      ],
                    )
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBCodeWidget(bbcode: commentItem!.comment.comment),

            /// 子评论（楼中楼）
            if (commentItem!.replies.isNotEmpty)
              _ChildRepliesList(
                replies: commentItem!.replies,
                id: id,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChildRepliesList extends StatefulWidget {
  const _ChildRepliesList({
    required this.replies,
    required this.id,
  });

  final List<EpisodeComment> replies;
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

    if (total < 1) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(displayCount, (index) {
          final reply = widget.replies[index];
          return Padding(
            padding: const EdgeInsets.only(left: 48.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            const SizedBox(width: 4),
                            Text('#${index + 1}'),
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
                                child: const Text('层主'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                BBCodeWidget(bbcode: reply.comment),
              ],
            ),
          );
        }),

        /// 展开 / 收起按钮
        if (total > maxDisplay)
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? '收起' : '展开 ($total)'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
