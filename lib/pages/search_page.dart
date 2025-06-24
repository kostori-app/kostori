import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/pages/search_result_page.dart';
import 'package:kostori/pages/settings/anime_source_settings.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'aggregated_search_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchBarController controller;

  late List<String> searchSources;

  String searchTarget = "";

  SearchPageData get currentSearchPageData =>
      AnimeSource.find(searchTarget)!.searchPageData!;

  bool aggregatedSearch = false;

  var focusNode = FocusNode();

  var options = <String>[];

  void update() {
    setState(() {});
  }

  void search([String? text]) {
    if (aggregatedSearch) {
      context
          .to(() => AggregatedSearchPage(keyword: text ?? controller.text))
          .then((_) => update());
    } else {
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
    var defaultSearchTarget = appdata.settings['defaultSearchTarget'];
    if (defaultSearchTarget == "_aggregated_") {
      aggregatedSearch = true;
    } else if (defaultSearchTarget != null &&
        AnimeSource.find(defaultSearchTarget) != null) {
      searchTarget = defaultSearchTarget;
    } else {
      searchTarget = AnimeSource.all().first.key;
    }
    controller = SearchBarController(
      onSearch: search,
    );
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
    var msg = "No Search Sources".tl;
    msg += '\n';
    VoidCallback onTap;
    if (AnimeSource.isEmpty) {
      msg += "Please add some sources".tl;
      onTap = () {
        context.to(() => AnimeSourceSettings());
      };
    } else {
      msg += "Please check your settings".tl;
      onTap = manageSearchSources;
    }
    return NetworkError(
      message: msg,
      retry: onTap,
      withAppbar: true,
      buttonText: "Manage".tl,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (searchSources.isEmpty) {
      return buildEmpty();
    }
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: buildSlivers().toList(),
      ),
    );
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
    var sources = searchSources.map((e) => AnimeSource.find(e)!).toList();
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
              title: Text("Search in".tl),
              trailing: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: manageSearchSources,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sources.map((e) {
                return OptionChip(
                  text: e.name,
                  isSelected: searchTarget == e.key || aggregatedSearch,
                  onTap: () {
                    if (aggregatedSearch) return;
                    setState(() {
                      searchTarget = e.key;
                      useDefaultOptions();
                    });
                  },
                );
              }).toList(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Aggregated Search".tl),
              leading: Checkbox(
                value: aggregatedSearch,
                onChanged: (value) {
                  setState(() {
                    aggregatedSearch = value ?? false;
                  });
                },
              ),
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
    if (aggregatedSearch) {
      return const SliverToBoxAdapter(child: SizedBox());
    }

    var children = <Widget>[];

    final searchOptions = currentSearchPageData.searchOptions ?? [];
    if (searchOptions.length != options.length) {
      useDefaultOptions();
    }
    if (searchOptions.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    for (int i = 0; i < searchOptions.length; i++) {
      final option = searchOptions[i];
      children.add(SearchOptionWidget(
        option: option,
        value: options[i],
        onChanged: (value) {
          options[i] = value;
          update();
        },
        sourceKey: searchTarget,
      ));
    }

    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
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
          )
      ],
    );
  }
}

class SearchHistory extends StatefulWidget {
  const SearchHistory(this.search, {super.key});

  final void Function(String) search;

  @override
  State<SearchHistory> createState() => SearchHistoryState();
}

class SearchHistoryState extends State<SearchHistory> {
  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return const SizedBox(
              height: 16,
            );
          }
          if (index == 1) {
            return ListTile(
              leading: const Icon(Icons.history),
              contentPadding: EdgeInsets.zero,
              title: Text("Search History".tl),
              trailing: Flyout(
                flyoutBuilder: (context) {
                  return FlyoutContent(
                    title: "Clear Search History".tl,
                    actions: [
                      FilledButton(
                        child: Text("Clear".tl),
                        onPressed: () {
                          appdata.clearSearchHistory();
                          context.pop();
                          setState(() {});
                        },
                      )
                    ],
                  );
                },
                child: Builder(
                  builder: (context) {
                    return Tooltip(
                      message: "Clear".tl,
                      child: IconButton(
                        icon: const Icon(Icons.clear_all),
                        onPressed: () {
                          context
                              .findAncestorStateOfType<FlyoutState>()!
                              .show();
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          }
          return buildItem(index - 2);
        },
        childCount: 2 + appdata.searchHistory.length,
      ),
    ).sliverPaddingHorizontal(16);
  }

  Widget buildItem(int index) {
    void showMenu(Offset offset) {
      showMenuX(
        context,
        offset,
        [
          MenuEntry(
            icon: Icons.copy,
            text: 'Copy'.tl,
            onClick: () {
              Clipboard.setData(
                  ClipboardData(text: appdata.searchHistory[index]));
            },
          ),
          MenuEntry(
            icon: Icons.delete,
            text: 'Delete'.tl,
            onClick: () {
              appdata.removeSearchHistory(appdata.searchHistory[index]);
              appdata.saveData();
              setState(() {});
            },
          ),
        ],
      );
    }

    return Builder(builder: (context) {
      return InkWell(
        onTap: () {
          widget.search(appdata.searchHistory[index]);
        },
        onLongPress: () {
          var renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          showMenu(Offset(
            offset.dx + renderBox.size.width / 2 - 121,
            offset.dy + renderBox.size.height - 8,
          ));
        },
        onSecondaryTapUp: (details) {
          showMenu(details.globalPosition);
        },
        child: Container(
          decoration: BoxDecoration(
            // color: context.colorScheme.surfaceContainer,
            border: Border(
              left: BorderSide(
                color: context.colorScheme.outlineVariant,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(appdata.searchHistory[index], style: ts.s14),
        ),
      ).paddingBottom(8).paddingHorizontal(4);
    });
  }
}
