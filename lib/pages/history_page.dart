import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/favorites.dart';
import 'package:kostori/foundation/history.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/stats.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool showFB = false;
  bool multiSelectMode = false;

  Map<HistoryTimeGroup, bool> expandedStates = {};

  var animes = HistoryManager().getAll();
  Map<History, bool> selectedAnimes = {};
  final scrollController = ScrollController();
  var controller = FlyoutController();

  Map<String, bool> toJsonMap(Map<HistoryTimeGroup, bool> map) {
    return map.map((key, value) => MapEntry(key.name, value));
  }

  Map<HistoryTimeGroup, bool> fromJsonMap(Map<String, dynamic> json) {
    return json.map((key, value) {
      final enumKey = historyTimeGroupMap[key] ?? HistoryTimeGroup.older;
      return MapEntry(enumKey, value.toString() == 'true');
    });
  }

  final Map<String, HistoryTimeGroup> historyTimeGroupMap = {
    "today": HistoryTimeGroup.today,
    "yesterday": HistoryTimeGroup.yesterday,
    "last3Days": HistoryTimeGroup.last3Days,
    "last7Days": HistoryTimeGroup.last7Days,
    "last30Days": HistoryTimeGroup.last30Days,
    "last3Months": HistoryTimeGroup.last3Months,
    "last6Months": HistoryTimeGroup.last6Months,
    "thisYear": HistoryTimeGroup.thisYear,
    "older": HistoryTimeGroup.older,
  };

  @override
  void initState() {
    HistoryManager().addListener(onUpdate);
    scrollController.addListener(onScroll);
    expandedStates = fromJsonMap(
      Map<String, dynamic>.from(appdata.implicitData['expandedStates'] ?? {}),
    );
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(onUpdate);
    scrollController.removeListener(onScroll);
    scrollController.dispose();
    super.dispose();
  }

  void onUpdate() {
    setState(() {
      animes = HistoryManager().getAll();
      if (multiSelectMode) {
        selectedAnimes.removeWhere((anime, _) => !animes.contains(anime));
        if (selectedAnimes.isEmpty) multiSelectMode = false;
      }
    });
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

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
      HistoryManager().remove(anime.id, AnimeType(anime.sourceKey.hashCode));
    }
  }

  void onScroll() {
    if (scrollController.offset > 50) {
      if (!showFB) setState(() => showFB = true);
    } else {
      if (showFB) setState(() => showFB = false);
    }
  }

  List<HistoryGroup> buildHistoryGroups(List<History> histories) {
    Map<HistoryTimeGroup, List<History>> map = {};

    for (var group in HistoryTimeGroup.values) {
      map[group] = [];
    }

    for (var h in histories) {
      final group = groupByTime(h.time);
      map[group]!.add(h);
    }

    for (var entry in map.entries) {
      entry.value.sort((a, b) => b.time.compareTo(a.time));
    }

    List<HistoryGroup> groups = map.entries
        .where((entry) => entry.value.isNotEmpty)
        .map(
          (e) => HistoryGroup(
            group: e.key,
            items: e.value,
            isExpanded: expandedStates[e.key] ?? true,
          ),
        )
        .toList();

    groups.sort((a, b) => a.group.order.compareTo(b.group.order));
    return groups;
  }

  void toggleGroupExpansion(HistoryTimeGroup group) {
    setState(() {
      expandedStates[group] = !(expandedStates[group] ?? true);
      appdata.implicitData['expandedStates'] = toJsonMap(expandedStates);
      appdata.writeImplicitData();
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> selectActions = [
      IconButton(
        icon: const Icon(Icons.select_all),
        tooltip: "Select All".tl,
        onPressed: selectAll,
      ),
      IconButton(
        icon: const Icon(Icons.deselect),
        tooltip: "Deselect".tl,
        onPressed: deSelect,
      ),
      IconButton(
        icon: const Icon(Icons.flip),
        tooltip: "Invert Selection".tl,
        onPressed: invertSelection,
      ),
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
        onPressed: () => setState(() => multiSelectMode = !multiSelectMode),
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
                Button.outlined(
                  onPressed: () {
                    HistoryManager().clearUnfavoritedHistory();
                    context.pop();
                  },
                  child: Text('Clear Unfavorited'.tl),
                ),
                const SizedBox(width: 4),
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
      ),
      Tooltip(
        message: 'Clear Progress'.tl,
        child: Flyout(
          controller: controller,
          flyoutBuilder: (context) {
            return FlyoutContent(
              title: 'Clear Progress'.tl,
              content: Text('Are you sure you want to clear your progress?'.tl),
              actions: [
                Button.filled(
                  color: context.colorScheme.error,
                  onPressed: () {
                    HistoryManager().clearProgress();
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
      ),
    ];

    final groups = buildHistoryGroups(animes);

    List<Widget> buildGroupedSlivers(List<HistoryGroup> groups) {
      List<Widget> slivers = [];

      for (var groupData in groups) {
        // Header
        slivers.add(
          SliverToBoxAdapter(
            child: InkWell(
              onTap: () {
                toggleGroupExpansion(groupData.group);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      groupData.group.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 300),
                      turns: groupData.isExpanded ? 0.5 : 0,
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Grid with animation
        slivers.add(
          SliverAnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: groupData.isExpanded && groupData.items.isNotEmpty
                ? SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverGridAnimes(
                      animes: groupData.items,
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
                          : (a) {
                              if (a.viewMore != null) {
                                var context =
                                    App.mainNavigatorKey!.currentContext!;
                                a.viewMore!.jump(context);
                              } else {
                                App.mainNavigatorKey?.currentContext?.to(
                                  () => AnimePage(
                                    id: a.id,
                                    sourceKey: a.sourceKey,
                                  ),
                                );
                                final stats = StatsManager();
                                if (!stats.isExist(
                                  a.id,
                                  AnimeType(a.sourceKey.hashCode),
                                )) {
                                  try {
                                    stats.addStats(
                                      stats.createStatsData(
                                        id: a.id,
                                        title: a.title,
                                        cover: a.cover,
                                        type: a.sourceKey.hashCode,
                                      ),
                                    );
                                  } catch (e) {
                                    Log.addLog(
                                      LogLevel.error,
                                      'addStats',
                                      e.toString(),
                                    );
                                  }
                                }
                                LocalFavoritesManager().updateRecentlyWatched(
                                  a.id,
                                  AnimeType(a.sourceKey.hashCode),
                                );
                              }
                            },
                      badgeBuilder: (c) => AnimeSource.find(c.sourceKey)?.name,
                      menuBuilder: (c) => [
                        MenuEntry(
                          icon: Icons.remove,
                          text: 'Remove'.tl,
                          color: context.colorScheme.error,
                          onClick: () {
                            _removeHistory(c as History);
                          },
                        ),
                      ],
                    ),
                  )
                : SliverToBoxAdapter(
                    key: ValueKey(groupData.group),
                    child: const SizedBox.shrink(),
                  ),
          ),
        );
      }

      return slivers;
    }

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
                    onPressed: () => setState(() {
                      multiSelectMode = false;
                      selectedAnimes.clear();
                    }),
                    icon: const Icon(Icons.close),
                  ),
                )
              : Container(),
          title: multiSelectMode
              ? Text(selectedAnimes.length.toString())
              : Text(''),
          actions: multiSelectMode ? selectActions : normalActions,
        ),
        ...buildGroupedSlivers(groups),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 80),
          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );

    body = Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          bottom: 10,
          right: 10,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            opacity: showFB ? 1 : 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 0),
              child: GridSpeedDial(
                icon: Icons.menu,
                activeIcon: Icons.close,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                spacing: 6,
                spaceBetweenChildren: 4,
                direction: SpeedDialDirection.up,
                childPadding: const EdgeInsets.all(6),
                childrens: [
                  [
                    SpeedDialChild(
                      child: const Icon(Icons.refresh),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      onTap: onUpdate,
                    ),
                  ],
                  [
                    SpeedDialChild(
                      child: const Icon(Icons.vertical_align_top),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      onTap: scrollToTop,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );

    body = AppScrollBar(
      topPadding: 52 + MediaQuery.of(context).padding.top,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );

    return PopScope(
      canPop: multiSelectMode == false,
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
}
