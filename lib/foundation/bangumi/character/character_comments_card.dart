import 'package:flutter/material.dart';
import 'package:kostori/bbcode/bbcode_widget.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../comment/comment_item.dart';

class CharacterCommentsCard extends StatelessWidget {
  CharacterCommentsCard({
    super.key,
    required this.commentItem,
  }) {
    isBone = false;
  }

  CharacterCommentsCard.bone({super.key}) {
    isBone = true;
    commentItem = null;
  }

  late final CharacterCommentItem? commentItem;
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
              children: [
                const Bone.circle(size: 36),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(width: 80),
                    SizedBox(height: 8),
                    Bone.text(width: 60),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            const Bone.multiText(lines: 2),
            Divider(thickness: 0.5, indent: 10, endIndent: 10),
          ],
        ),
      );
    }
    return SelectionArea(
      // color: Theme.of(context).colorScheme.secondaryContainer,
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
                    Text(Utils.dateFormat(commentItem!.comment.createdAt)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBCodeWidget(bbcode: commentItem!.comment.comment),
            if (commentItem!.replies.isNotEmpty)
              ListView.builder(
                // Don't know why but some device has bottom padding,
                // needs to set to 0 manually.
                padding: const EdgeInsets.only(bottom: 0),
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: commentItem!.replies.length,
                itemBuilder: (context, index) {
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
                              backgroundImage: NetworkImage(commentItem!
                                  .replies[index].user.avatar.large),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(commentItem!.replies[index].user.nickname),
                                Text(
                                  Utils.dateFormat(
                                      commentItem!.replies[index].createdAt),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        BBCodeWidget(
                            bbcode: commentItem!.replies[index].comment),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
