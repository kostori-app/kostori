import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';

import 'package:kostori/foundation/context.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/history.dart';

import '../foundation/consts.dart';

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
      if (multiSelectMode) {
        selectedAnimes.removeWhere((anime, _) => !animes.contains(anime));
        if (selectedAnimes.isEmpty) {
          multiSelectMode = false;
        }
      }
    });
  }

  var animes = HistoryManager().getAll();

  var controller = FlyoutController();

  bool multiSelectMode = false;
  Map<History, bool> selectedAnimes = {};

  var scrollController = ScrollController();

  void selectAll() {
    setState(() {
      selectedAnimes = animes.asMap().map((k, v) => MapEntry(v, true));
    });
  }

  void deSelect() {
    setState(() {
      selectedAnimes.clear();
    });
  }

  void invertSelection() {
    setState(() {
      animes.asMap().forEach((k, v) {
        selectedAnimes[v] = !selectedAnimes.putIfAbsent(v, () => false);
      });
      selectedAnimes.removeWhere((k, v) => !v);
    });
  }

  void _removeHistory(History anime) {
    if (anime.sourceKey.startsWith("Unknown")) {
      HistoryManager().remove(
        anime.id,
        AnimeType(int.parse(anime.sourceKey.split(':')[1])),
      );
    } else {
      HistoryManager().remove(
        anime.id,
        AnimeType(anime.sourceKey.hashCode),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> selectActions = [
      IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: "Select All".tl,
          onPressed: selectAll),
      IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: "Deselect".tl,
          onPressed: deSelect),
      IconButton(
          icon: const Icon(Icons.flip),
          tooltip: "Invert Selection".tl,
          onPressed: invertSelection),
      IconButton(
        icon: const Icon(Icons.delete),
        tooltip: "Delete".tl,
        onPressed: selectedAnimes.isEmpty
            ? null
            : () {
                final animesToDelete = List<History>.from(selectedAnimes.keys);
                setState(() {
                  multiSelectMode = false;
                  selectedAnimes.clear();
                });

                for (final anime in animesToDelete) {
                  _removeHistory(anime);
                }
              },
      ),
    ];

    List<Widget> normalActions = [
      IconButton(
        icon: const Icon(Icons.checklist),
        tooltip: multiSelectMode ? "Exit Multi-Select".tl : "Multi-Select".tl,
        onPressed: () {
          setState(() {
            multiSelectMode = !multiSelectMode;
          });
        },
      ),
      Tooltip(
        message: 'Clear History'.tl,
        child: Flyout(
          controller: controller,
          flyoutBuilder: (context) {
            return FlyoutContent(
              title: 'Clear History'.tl,
              content: Text('Are you sure you want to clear your history?'.tl),
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
    ];

    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppbar(
          style: context.width < changePoint
              ? AppbarStyle.shadow
              : AppbarStyle.blur,
          leading: multiSelectMode
              ? Tooltip(
                  message: "Cancel".tl,
                  child: IconButton(
                    onPressed: () {
                      if (multiSelectMode) {
                        setState(() {
                          multiSelectMode = false;
                          selectedAnimes.clear();
                        });
                      }
                    },
                    icon: const Icon(Icons.close),
                  ),
                )
              : null,
          title: multiSelectMode
              ? Text(selectedAnimes.length.toString())
              : Text(''),
          actions: multiSelectMode ? selectActions : normalActions,
        ),
        SliverGridAnimes(
          animes: animes,
          selections: selectedAnimes,
          onLongPressed: null,
          onTap: multiSelectMode
              ? (c) {
                  setState(() {
                    if (selectedAnimes.containsKey(c as History)) {
                      selectedAnimes.remove(c);
                    } else {
                      selectedAnimes[c] = true;
                    }
                    if (selectedAnimes.isEmpty) {
                      multiSelectMode = false;
                    }
                  });
                }
              : null,
          badgeBuilder: (c) {
            return AnimeSource.find(c.sourceKey)?.name;
          },
          menuBuilder: (c) {
            return [
              MenuEntry(
                icon: Icons.remove,
                text: 'Remove'.tl,
                color: context.colorScheme.error,
                onClick: () {
                  _removeHistory(c as History);
                },
              ),
            ];
          },
        ),
      ],
    );

    body = AppScrollBar(
      topPadding: 48,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );

    return PopScope(
      canPop: !multiSelectMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedAnimes.clear();
          });
        }
      },
      child: body,
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
