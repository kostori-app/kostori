import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/bangumi/topics/topics_info_item.dart';
import 'package:kostori/foundation/bangumi/topics/topics_item.dart';
import 'package:kostori/pages/bangumi/bangumi_topics_page.dart';
import 'package:kostori/utils/utils.dart';

class TopicsCard extends StatelessWidget {
  const TopicsCard({
    super.key,
    this.topicsItem,
    this.isBottom = false,
    this.topicsInfoItem,
  });

  final bool isBottom;
  final TopicsItem? topicsItem;
  final TopicsInfoItem? topicsInfoItem;

  get topics => topicsItem ?? topicsInfoItem;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final contentMaxWidth = isDesktop ? 600.0 : double.infinity;

    final avatarUrl = topics.creator.avatar.large.isEmpty
        ? 'https://bangumi.tv/img/info_only.png'
        : topics.creator.avatar.large;

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
            onTap: () => _handleTap(context),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(avatarUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topics.title,
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
                                topics.creator.nickname,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Text(' / '),
                            Text(Utils.dateFormat(topics.createdAt)),
                            if (topics.replyCount != 0) ...[
                              const Text(' / '),
                              Text('+${topics.replyCount}'),
                            ],
                          ],
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
    final page = BangumiTopicsPage(id: topics.id);

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
