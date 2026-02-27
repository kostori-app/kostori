import 'package:flutter/material.dart';
import 'package:kostori/components/bangumi_widget.dart';
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
            onLongPress: () => BangumiWidget.showBottomPage(
              context,
              PersonPage(personID: characterItem!.actorList.first.id),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
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
                          characterItem!.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (characterItem!.actorList.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              characterItem!.actorList.first.name,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    characterItem!.relation,
                    style: Theme.of(context).textTheme.bodySmall,
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
                children: [
                  Bone.circle(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone.text(width: 100),
                        const SizedBox(height: 4),
                        Bone.text(width: 80),
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
