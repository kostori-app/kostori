import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/character_page.dart';

import 'character_item.dart';

class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.characterItem,
  });

  final CharacterItem characterItem;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: characterItem.avator.grid.isEmpty
            ? NetworkImage('https://bangumi.tv/img/info_only.png')
            : NetworkImage(characterItem.avator.grid),
      ),
      title: Text(
        characterItem.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: characterItem.actorList.isNotEmpty
          ? Text(characterItem.actorList[0].name)
          : null,
      trailing: Text(characterItem.relation),
      onTap: () {
        showModalBottomSheet(
            isScrollControlled: true,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 3 / 4,
                maxWidth: App.isDesktop
                    ? MediaQuery.of(context).size.width * 9 / 16
                    : MediaQuery.of(context).size.width),
            clipBehavior: Clip.antiAlias,
            context: context,
            builder: (context) {
              return CharacterPage(characterID: characterItem.id);
            });
      },
    );
  }
}
