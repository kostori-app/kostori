import 'package:flutter/material.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/bangumi/character/actor_item.dart';
import 'package:kostori/foundation/bangumi/character/character_item.dart';
import 'package:kostori/pages/bangumi/character_page.dart';
import 'package:kostori/pages/bangumi/person_page.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.characterItem,
    this.isBone = false,
  });

  const CharacterCard.bone({super.key}) : characterItem = null, isBone = true;

  final CharacterItem? characterItem;
  final bool isBone;

  @override
  Widget build(BuildContext context) {
    if (isBone) return _buildBone(context);
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final contentMaxWidth = isDesktop ? 600.0 : double.infinity;

    final avatarUrl = characterItem!.avator.grid.isEmpty
        ? 'https://bangumi.tv/img/info_only.png'
        : characterItem!.avator.grid;

    final actors = characterItem!.actorList;

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
            onTap: () => BangumiWidget.showBottomPage(
              context,
              CharacterPage(characterID: characterItem!.id),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BangumiAvatar(url: avatarUrl, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                characterItem!.name,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              characterItem!.relation,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (actors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: actors
                                  .map((actor) => _ActorChip(actor: actor))
                                  .toList(),
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
                        Bone.text(width: 100),
                        const SizedBox(height: 8),
                        Bone.text(width: 120),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Bone.text(width: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单个声优小卡片，点击跳转声优（人物）详情页
class _ActorChip extends StatelessWidget {
  const _ActorChip({required this.actor});

  final ActorItem actor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => BangumiWidget.showBottomPage(
          context,
          PersonPage(personID: actor.id),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actor.avator.grid.isNotEmpty)
                BangumiAvatar(url: actor.avator.grid, radius: 10),
              if (actor.avator.grid.isNotEmpty) const SizedBox(width: 6),
              Text(
                actor.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
