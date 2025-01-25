import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';

import 'package:kostori/foundation/context.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/local.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  void initState() {
    HistoryManager().addListener(onUpdate);
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(onUpdate);
    super.dispose();
  }

  void onUpdate() {
    setState(() {
      animes = HistoryManager().getAll();
    });
  }

  var animes = HistoryManager().getAll();

  var controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            title: Text('History'.tl),
            actions: [
              Tooltip(
                message: 'Clear History'.tl,
                child: Flyout(
                  controller: controller,
                  flyoutBuilder: (context) {
                    return FlyoutContent(
                      title: 'Clear History'.tl,
                      content: Text(
                          'Are you sure you want to clear your history?'.tl),
                      actions: [
                        Button.filled(
                          color: context.colorScheme.error,
                          onPressed: () {
                            HistoryManager().clearHistory();
                            context.pop();
                          },
                          child: Text('Clear'.tl),
                        ),
                      ],
                    );
                  },
                  child: IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () {
                      controller.show();
                    },
                  ),
                ),
              )
            ],
          ),
          SliverGridAnimes(
            animes: animes.map(
              (e) {
                var cover = e.cover;
                if (!cover.isURL) {
                  var localAnime = LocalManager().find(
                    e.id,
                    e.type,
                  );
                  if (localAnime != null) {
                    cover = "file://${localAnime.coverFile.path}";
                  }
                }
                return Anime(
                  e.title,
                  cover,
                  e.id,
                  e.subtitle,
                  null,
                  getDescription(e),
                  e.type.animeSource?.key ?? "Invalid:${e.type.value}",
                  null,
                );
              },
            ).toList(),
            badgeBuilder: (c) {
              return AnimeSource.find(c.sourceKey)?.name;
            },
            enableHistory: true,
            menuBuilder: (c) {
              return [
                MenuEntry(
                  icon: Icons.remove,
                  text: 'Remove'.tl,
                  color: context.colorScheme.error,
                  onClick: () {
                    if (c.sourceKey.startsWith("Invalid")) {
                      HistoryManager().remove(
                        c.id,
                        AnimeType(int.parse(c.sourceKey.split(':')[1])),
                      );
                    } else {
                      HistoryManager().remove(
                        c.id,
                        AnimeType(c.sourceKey.hashCode),
                      );
                    }
                  },
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  String getDescription(History h) {
    var res = "";
    if (h.lastWatchEpisode >= 1) {
      res += "Currently seen @ep".tlParams({
        "ep": h.lastWatchEpisode,
      });
    }
    if (h.lastWatchTime >= 1) {
      if (h.lastWatchEpisode >= 1) {
        res += " - ";
      }
      res += "lastWatchTime @time".tlParams({
        "time": formatMilliseconds(h.lastWatchTime),
      });
    }
    return res;
  }

  String formatMilliseconds(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
