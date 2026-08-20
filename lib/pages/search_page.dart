import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/aggregated_search_page.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/pages/search_source_select_page.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/search_source_groups.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
import 'package:sliver_tools/sliver_tools.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchBarController controller;

  late List<String> searchSources;
  final scrollController = ScrollController();
  String searchTarget = "";

  SearchPageData get currentSearchPageData =>
      AnimeSource.find(searchTarget)!.searchPageData!;

  /// 聚合搜索开关（由搜索源旁的图标切换）
  bool aggregatedSearch = false;

  /// 当前选中的搜索源分组（'all' 表示全部）
  String selectedGroup = 'all';

  /// 聚合搜索时手动勾选的源子集（空表示使用分组内全部源）
  Set<String> aggregatedSources = {};

  var focusNode = FocusNode();

  var options = <String>[];

  /// 当前分组下的启用搜索源
  List<AnimeSource> get groupSources => enabledSearchSources(selectedGroup);

  void update() {
    setState(() {});
  }

  void search([String? text]) {
    if (aggregatedSearch) {
      final keys = aggregatedSources.isNotEmpty
          ? aggregatedSources.toList()
          : groupSources.map((e) => e.key).toList();
      if (keys.isEmpty) {
        App.rootContext.showMessage(message: t.noSearchSources);
        return;
      }
      context
          .to(
            () => AggregatedSearchPage(
              keyword: text ?? controller.text,
              sourceKeys: keys,
              group: selectedGroup,
            ),
          )
          .then((_) => update());
    } else {
      if (searchTarget.isEmpty) {
        App.rootContext.showMessage(message: t.noSearchSources);
        return;
      }
      context
          .to(
            () => SearchResultPage(
              text: text ?? controller.text,
              sourceKey: searchTarget,
              options: options,
            ),
          )
          .then((_) => update());
    }
  }

  /// 持久化搜索目标（聚合开关 + 单源目标）到 defaultSearchTarget，
  /// 与设置页"默认搜索目标"保持一致
  void _persistTarget() {
    appdata.settings['defaultSearchTarget'] = aggregatedSearch
        ? '_aggregated_'
        : searchTarget;
    appdata.saveData();
  }

  /// 打开"选择搜索源"底部弹层（分组筛选 + 单源/聚合切换 + 源列表）
  Future<void> _openSourceSelect() async {
    final result = await showSearchSourceSheet(
      context,
      group: selectedGroup,
      singleKey: aggregatedSearch ? null : searchTarget,
      aggregatedKeys: aggregatedSearch ? aggregatedSources : null,
      aggregated: aggregatedSearch,
    );
    if (result == null || !mounted) return;
    setState(() {
      selectedGroup = result.group;
      saveSelectedSearchGroup(result.group);
      aggregatedSearch = result.aggregated;
      if (aggregatedSearch) {
        aggregatedSources = result.aggregatedKeys ?? {};
      } else if (result.singleKey != null && result.singleKey!.isNotEmpty) {
        searchTarget = result.singleKey!;
        useDefaultOptions();
      }
      _persistTarget();
    });
  }

  bool canHandleUrl(String text) {
    if (!text.isURL) return false;
    for (var source in AnimeSource.all()) {
      if (source.linkHandler != null) {
        var uri = Uri.parse(text);
        if (source.linkHandler!.domains.contains(uri.host)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void initState() {
    findSearchSources();
    selectedGroup = selectedSearchGroup();
    var defaultSearchTarget = appdata.settings['defaultSearchTarget'];
    if (defaultSearchTarget == "_aggregated_") {
      aggregatedSearch = true;
    } else if (defaultSearchTarget != null &&
        AnimeSource.find(defaultSearchTarget) != null) {
      searchTarget = defaultSearchTarget;
    } else {
      searchTarget = AnimeSource.all().first.key;
    }
    controller = SearchBarController(onSearch: search);
    appdata.settings.addListener(updateSearchSourcesIfNeeded);
    super.initState();
  }

  @override
  void dispose() {
    focusNode.dispose();
    appdata.settings.removeListener(updateSearchSourcesIfNeeded);
    super.dispose();
  }

  void findSearchSources() {
    var all = AnimeSource.all()
        .where((e) => e.searchPageData != null)
        .map((e) => e.key)
        .toList();
    var settings = appdata.settings['searchSources'] as List;
    var sources = <String>[];
    for (var source in settings) {
      if (all.contains(source)) {
        sources.add(source);
      }
    }
    searchSources = sources;
    if (!searchSources.contains(searchTarget)) {
      searchTarget = searchSources.firstOrNull ?? "";
    }
  }

  void updateSearchSourcesIfNeeded() {
    var old = searchSources;
    findSearchSources();
    if (old.isEqualTo(searchSources)) {
      return;
    }
    setState(() {});
  }

  void manageSearchSources() {
    showPopUpWidget(App.rootContext, setSearchSourcesWidget());
  }

  Widget buildEmpty() {
    var msg = t.noSearchSources;
    msg += '\n';
    VoidCallback onTap;
    if (AnimeSource.isEmpty) {
      msg += t.pleaseAddSomeSources;
      onTap = () {
        context.to(() => AnimeSourceSettings());
      };
    } else {
      msg += t.pleaseCheckYourSettings;
      onTap = manageSearchSources;
    }
    return NetworkError(
      message: msg,
      retry: onTap,
      withAppbar: true,
      buttonText: t.manage,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (searchSources.isEmpty) {
      return buildEmpty();
    }
    Widget widget = Scaffold(
      body: SmoothCustomScrollView(
        controller: scrollController,
        slivers: buildSlivers().toList(),
      ),
    );
    widget = AppScrollBar(
      topPadding: 52 + MediaQuery.of(context).padding.top,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );
    return widget;
  }

  Iterable<Widget> buildSlivers() sync* {
    yield SliverSearchBar(
      controller: controller,
      onChanged: (s) {},
      focusNode: focusNode,
    );
    yield buildSearchTarget();
    yield SliverAnimatedPaintExtent(
      duration: const Duration(milliseconds: 200),
      child: buildSearchOptions(),
    );
    yield SearchHistory(search);
  }

  Widget buildSearchTarget() {
    final cs = Theme.of(context).colorScheme;
    final sources = groupSources;
    final currentSource = searchTarget.isNotEmpty
        ? AnimeSource.find(searchTarget)
        : null;
    final countText = aggregatedSources.isNotEmpty
        ? '${aggregatedSources.length} ${t.sources}'
        : '${sources.length} ${t.sources}';

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text(
                aggregatedSearch
                    ? '${t.aggregatedSearch} · ${searchGroupLabel(selectedGroup)}'
                    : (currentSource?.name ?? t.noSearchSources),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                aggregatedSearch
                    ? countText
                    : '${searchGroupLabel(selectedGroup)} · ${sources.length} ${t.sources}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.toOpacity(0.55),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: t.aggregatedSearch,
                    icon: Icon(
                      aggregatedSearch
                          ? Icons.auto_awesome
                          : Icons.auto_awesome_outlined,
                      color: aggregatedSearch
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() {
                        aggregatedSearch = !aggregatedSearch;
                        _persistTarget();
                      });
                    },
                  ),
                  IconButton(
                    tooltip: t.searchSources,
                    icon: Icon(Icons.settings, color: cs.primary),
                    onPressed: manageSearchSources,
                  ),
                ],
              ),
              onTap: _openSourceSelect,
            ),
          ],
        ),
      ),
    );
  }

  void useDefaultOptions() {
    final searchOptions = currentSearchPageData.searchOptions ?? [];
    options = searchOptions.map((e) => e.defaultValue).toList();
  }

  Widget buildSearchOptions() {
    if (aggregatedSearch || searchTarget.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    final searchOptions = currentSearchPageData.searchOptions ?? [];
    if (searchOptions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.tune),
            label: Text(t.searchOptions),
            onPressed: () => _showSearchOptionsDialog(searchOptions),
          ),
        ),
      ),
    );
  }

  void _showSearchOptionsDialog(List searchOptions) {
    if (searchOptions.length != options.length) {
      useDefaultOptions();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStates) {
            return Sheet(
              title: t.searchOptions,
              icon: Icons.tune,
              builder: (context, sc) {
                return SingleChildScrollView(
                  controller: sc,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < searchOptions.length; i++)
                        SearchOptionWidget(
                          option: searchOptions[i],
                          value: options[i],
                          onChanged: (value) {
                            options[i] = value;
                            setStates(() {});
                            update();
                          },
                          sourceKey: searchTarget,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class SearchOptionWidget extends StatelessWidget {
  const SearchOptionWidget({
    super.key,
    required this.option,
    required this.value,
    required this.onChanged,
    required this.sourceKey,
  });

  final SearchOptions option;

  final String value;

  final void Function(String) onChanged;

  final String sourceKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(option.label.ts(sourceKey)),
        ),
        if (option.type == 'select')
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: option.options.entries.map((e) {
              return OptionChip(
                text: e.value.ts(sourceKey),
                isSelected: value == e.key,
                onTap: () {
                  onChanged(e.key);
                },
              );
            }).toList(),
          ),
        if (option.type == 'multi-select')
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: option.options.entries.map((e) {
              return OptionChip(
                text: e.value.ts(sourceKey),
                isSelected: (jsonDecode(value) as List).contains(e.key),
                onTap: () {
                  var list = jsonDecode(value) as List;
                  if (list.contains(e.key)) {
                    list.remove(e.key);
                  } else {
                    list.add(e.key);
                  }
                  onChanged(jsonEncode(list));
                },
              );
            }).toList(),
          ),
        if (option.type == 'dropdown')
          Select(
            current: option.options[value],
            values: option.options.values.toList(),
            onTap: (index) {
              onChanged(option.options.keys.elementAt(index));
            },
            minWidth: 96,
          ),
      ],
    );
  }
}

class SearchHistory extends ConsumerWidget {
  const SearchHistory(this.search, {super.key});

  final void Function(String) search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(searchHistoryProvider);
    final history = asyncValue.when(
      data: (data) => data,
      loading: () => <SearchHistoryItem>[],
      error: (_, _) => <SearchHistoryItem>[],
    );

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) return const SizedBox(height: 16);
        if (index == 1) return _buildHeader(context, ref);
        return _buildItem(context, ref, history[index - 2]);
      }, childCount: 2 + history.length),
    ).sliverPaddingHorizontal(16);
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.history),
      contentPadding: EdgeInsets.zero,
      title: Text(t.searchHistory),
      trailing: Flyout(
        flyoutBuilder: (context) {
          return FlyoutContent(
            title: t.clearSearchHistory,
            actions: [
              FilledButton(
                child: Text(t.clear),
                onPressed: () {
                  ref.read(searchHistoryProvider.notifier).clear();
                  context.pop();
                },
              ),
            ],
          );
        },
        child: Builder(
          builder: (context) {
            return Tooltip(
              message: t.clear,
              child: IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  context.findAncestorStateOfType<FlyoutState>()!.show();
                },
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    WidgetRef ref,
    SearchHistoryItem item,
  ) {
    void showMenu(Offset offset) {
      showMenuX(context, offset, [
        MenuEntry(
          icon: Icons.copy,
          text: t.copy,
          onClick: () => Clipboard.setData(ClipboardData(text: item.keyword)),
        ),
        MenuEntry(
          icon: Icons.delete,
          text: t.delete,
          onClick: () =>
              ref.read(searchHistoryProvider.notifier).delete(item.keyword),
        ),
      ]);
    }

    return Builder(
      builder: (context) {
        return InkWell(
          onTap: () => search(item.keyword),
          onLongPress: () {
            var renderBox = context.findRenderObject() as RenderBox;
            var offset = renderBox.localToGlobal(Offset.zero);
            showMenu(
              Offset(
                offset.dx + renderBox.size.width / 2 - 121,
                offset.dy + renderBox.size.height - 8,
              ),
            );
          },
          onSecondaryTapUp: (details) => showMenu(details.globalPosition),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.keyword,
                  style: ts.s14.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.searchUseCount(n: item.useCount),
                      style: ts.s12.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Utils.formatTime(item.lastUsedAt),
                      style: ts.s12.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).paddingBottom(8).paddingHorizontal(4);
      },
    );
  }
}
