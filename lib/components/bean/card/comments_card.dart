import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/bangumi/comment/comment_item.dart';
import 'package:kostori/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CommentsCard extends StatelessWidget {
  CommentsCard({super.key, required this.commentItem}) {
    isBone = false;
  }

  CommentsCard.bone({super.key}) {
    isBone = true;
    commentItem = null;
  }

  late final CommentItem? commentItem;
  late final bool isBone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: isBone ? _buildBone(context) : _buildContent(context),
      ),
    );
  }

  Widget _buildBone(BuildContext context) {
    return Skeletonizer.zone(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BangumiAvatar(url: commentItem!.user.avatar.large),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commentItem!.user.nickname),
                    Text(Utils.dateFormat(commentItem!.comment.updatedAt)),
                  ],
                ),
                Expanded(child: Container(height: 10)),
                RatingBarIndicator(
                  itemCount: 5,
                  rating: commentItem!.comment.rate.toDouble() / 2,
                  itemBuilder: (context, index) =>
                      const Icon(Icons.star_rounded),
                  itemSize: 20.0,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(commentItem!.comment.comment),
          ],
        ),
      ),
    );
  }
}
