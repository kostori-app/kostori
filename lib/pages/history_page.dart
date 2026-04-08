import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/database/stats.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool multiSelectMode = false;
  Map<HistoryTimeGroup, bool> expandedStates = {};
  var animes = <History>[];
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
    super.initState();
    _loadHistory();
    ref.listenManual(historyAllProvider, (_, next) {
      final list = next.when(
        data: (d) => d,
        loading: () => animes,
        error: (_, _) => animes,
      );
      if (mounted) {
        setState(() {
          animes = list;
          if (multiSelectMode) {
            selectedAnimes.removeWhere((a, _) => !animes.contains(a));
            if (selectedAnimes.isEmpty) multiSelectMode = false;
          }
        });
      }
    });
    expandedStates = fromJsonMap(
      Map<String, dynamic>.from(appdata.implicitData['expandedStates'] ?? {}),
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final list = await HistoryManager().getAll();
    if (mounted) setState(() => animes = list);
  }

  void onUpdate() => _loadHistory();

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
    setState(() => selectedAnimes.clear());
  }

  void invertSelection() {
    setState(() {
      animes.asMap().forEach((k, v) {
        selectedAnimes[v] = !selectedAnimes.putIfAbsent(v, () => false);
      });
      selectedAnimes.removeWhere((k, v) => !v);
    });
  }

  void _removeHistory(History anime) async {
    if (mounted) {
      setState(() {
        animes.removeWhere((h) => h == anime);
        if (multiSelectMode) {
          selectedAnimes.remove(anime);
          if (selectedAnimes.isEmpty) multiSelectMode = false;
        }
      });
    }

    if (anime.sourceKey.startsWith("Unknown")) {
      await HistoryManager().remove(
        anime.id,
        AnimeType(int.parse(anime.sourceKey.split(':')[1])),
      );
    } else {
      await HistoryManager().remove(
        anime.id,
        AnimeType(anime.sourceKey.hashCode),
      );
    }
  }

  List<HistoryGroup> buildHistoryGroups(List<History> histories) {
    Map<HistoryTimeGroup, List<History>> map = {};
    for (var group in HistoryTimeGroup.values) {
      map[group] = [];
    }
    for (var h in histories) {
      map[groupByTime(h.time)]!.add(h);
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
        tooltip: t.selectAll,
        onPressed: selectAll,
      ),
      IconButton(
        icon: const Icon(Icons.deselect),
        tooltip: t.deselect,
        onPressed: deSelect,
      ),
      IconButton(
        icon: const Icon(Icons.flip),
        tooltip: t.invertSelection,
        onPressed: invertSelection,
      ),
      IconButton(
        icon: const Icon(Icons.delete),
        tooltip: t.delete,
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
        tooltip: multiSelectMode ? t.exitMultiSelect : t.multiSelect,
        onPressed: () => setState(() => multiSelectMode = !multiSelectMode),
      ),
      Tooltip(
        message: t.clearHistory,
        child: Flyout(
          controller: controller,
          flyoutBuilder: (context) {
            return FlyoutContent(
              title: t.clearHistory,
              content: Text(t.areYouSureYouWantToClearYourHistory),
              actions: [
                Button.outlined(
                  onPressed: () {
                    HistoryManager().clearUnfavoritedHistory();
                    context.pop();
                  },
                  child: Text(t.clearUnfavorited),
                ),
                const SizedBox(width: 4),
                Button.filled(
                  color: context.colorScheme.error,
                  onPressed: () {
                    HistoryManager().clearHistory();
                    context.pop();
                  },
                  child: Text(t.clear),
                ),
              ],
            );
          },
          child: IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => controller.show(),
          ),
        ),
      ),
    ];

    final groups = buildHistoryGroups(animes);

    List<Widget> buildGroupedSlivers(List<HistoryGroup> groups) {
      List<Widget> slivers = [];

      for (var groupData in groups) {
        slivers.add(
          SliverToBoxAdapter(
            child: InkWell(
              onTap: () => toggleGroupExpansion(groupData.group),
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
                          ? (c, heroID) {
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
                          : (a, heroID) async {
                              if (a.viewMore != null) {
                                final ctx =
                                    App.mainNavigatorKey!.currentContext!;
                                a.viewMore!.jump(ctx);
                              } else {
                                App.mainNavigatorKey?.currentContext?.to(
                                  () => AnimePage(
                                    id: a.id,
                                    sourceKey: a.sourceKey,
                                    cover: a.cover,
                                    title: a.title,
                                    heroID: heroID,
                                  ),
                                );
                                final stats = StatsManager();
                                if (!await stats.isExistAsync(
                                  a.id,
                                  AnimeType(a.sourceKey.hashCode),
                                )) {
                                  try {
                                    await stats.addStats(
                                      stats.createStatsData(
                                        id: a.id,
                                        title: a.title,
                                        cover: a.cover,
                                        type: a.sourceKey.hashCode,
                                      ),
                                    );
                                  } catch (e) {
                                    Log.error('addStats', e.toString());
                                  }
                                }
                              }
                              LocalFavoritesManager().updateRecentlyWatched(
                                a.id,
                                AnimeType(a.sourceKey.hashCode),
                              );
                            },
                      badgeBuilder: (c) => AnimeSource.find(c.sourceKey)?.name,
                      menuBuilder: (c) => [
                        MenuEntry(
                          icon: Icons.remove,
                          text: t.remove,
                          color: context.colorScheme.error,
                          onClick: () => _removeHistory(c as History),
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
                  message: t.cancel,
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
              : const Text(''),
          actions: multiSelectMode ? selectActions : normalActions,
        ),
        ...buildGroupedSlivers(groups),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 80),
          sliver: SliverToBoxAdapter(child: const SizedBox.shrink()),
        ),
      ],
    );

    body = Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          bottom: 10,
          right: 10,
          child: FloatingMenu(
            controller: scrollController,
            child: [
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
