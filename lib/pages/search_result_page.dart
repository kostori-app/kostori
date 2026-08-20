import 'package:flutter/material.dart';
import 'package:kostori/components/anime_list.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/search_history.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/search_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({
    super.key,
    required this.text,
    required this.sourceKey,
    this.options,
    this.webUrl,
  });

  final String text;

  final String sourceKey;

  final List<String>? options;

  /// 源附带的网页地址，右上角提供"打开网页"入口
  final String? webUrl;

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  late SearchBarController controller;

  late String sourceKey;

  late List<String> options;

  late String text;

  void search([String? text]) {
    if (text != null) {
      text = text;
      setState(() {
        this.text = text!;
      });
      SearchHistoryManager().addSearch(text);
      controller.currentText = text;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String checkAutoLanguage(String text) {
    var setting = appdata.settings["autoAddLanguageFilter"] ?? 'none';
    if (setting == 'none') {
      return text;
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    sourceKey = widget.sourceKey;
    text = widget.text;
    controller = SearchBarController(currentText: text, onSearch: search);
    options = widget.options ?? const [];
    validateOptions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SearchHistoryManager().addSearch(text);
    });
  }

  void validateOptions() {
    var source = AnimeSource.find(sourceKey);
    if (source == null) {
      return;
    }
    var searchOptions = source.searchPageData!.searchOptions;
    if (searchOptions == null) {
      return;
    }
    if (options.length != searchOptions.length) {
      options = searchOptions.map((e) => e.defaultValue).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    var source = AnimeSource.find(sourceKey);
    // 应用该源自定义的显示模式（搜索页独立覆盖 > 源覆盖 > 全局默认）
    return AnimeDisplayModeScope(
      mode: sourceDisplayModeOf(widget.sourceKey, 'search'),
      child: AnimeList(
        key: Key(text + options.toString() + sourceKey),
        errorLeading: AppSearchBar(controller: controller, action: buildAction()),
        leadingSliver: SliverSearchBar(
          controller: controller,
          action: buildAction(),
        ),
        loadPage: source!.searchPageData!.loadPage == null
            ? null
            : (i) {
          return source.searchPageData!.loadPage!(text, i, options);
        },
        loadNext: source.searchPageData!.loadNext == null
            ? null
            : (i) {
          return source.searchPageData!.loadNext!(text, i, options);
        },
      ),
    );
  }

  Widget buildAction() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimeSourceLayoutMenu(sourceKey: widget.sourceKey, subKey: 'search'),
        if (widget.webUrl != null && widget.webUrl!.isNotEmpty)
          Tooltip(
            message: t.openInBrowser,
            child: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrlString(widget.webUrl!),
            ),
          ),
        Tooltip(
          message: t.settings,
          child: IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                builder: (context) {
                  return _SearchSettingsDialog(state: this);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchSettingsDialog extends StatefulWidget {
  const _SearchSettingsDialog({required this.state});

  final _SearchResultPageState state;

  @override
  State<_SearchSettingsDialog> createState() => _SearchSettingsDialogState();
}

class _SearchSettingsDialogState extends State<_SearchSettingsDialog> {
  late String searchTarget;

  late List<String> options;

  @override
  void initState() {
    searchTarget = widget.state.sourceKey;
    options = widget.state.options;
    super.initState();
  }

  void onChanged() {
    widget.state.sourceKey = searchTarget;
    widget.state.options = options;
    widget.state.text = widget.state.controller.text;
    widget.state.controller.currentText = widget.state.controller.text;
    widget.state.setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var sources = AnimeSource.all();
    var enabled = appdata.settings['searchSources'] as List;
    sources.removeWhere((e) {
      return !enabled.contains(e.key);
    });
    return Sheet(
      title: t.settings,
      icon: Icons.tune,
      builder: (context, sc) {
        return SingleChildScrollView(
          controller: sc,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(t.searchIn),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sources.map((e) {
                    return OptionChip(
                      text: e.name.tl,
                      isSelected: searchTarget == e.key,
                      onTap: () {
                        setState(() {
                          searchTarget = e.key;
                          options.clear();
                          final searchOptions =
                              AnimeSource.find(
                                searchTarget,
                              )!
                                  .searchPageData!
                                  .searchOptions ??
                                  <SearchOptions>[];
                          options = searchOptions
                              .map((e) => e.defaultValue)
                              .toList();
                          onChanged();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              buildSearchOptions(),
            ],
          ),
        );
      },
    );
  }

  Widget buildSearchOptions() {
    var children = <Widget>[];

    final searchOptions =
        AnimeSource.find(searchTarget)!.searchPageData!.searchOptions ??
            <SearchOptions>[];
    if (searchOptions.length != options.length) {
      options = searchOptions.map((e) => e.defaultValue).toList();
    }
    if (searchOptions.isEmpty) {
      return const SizedBox();
    }
    for (int i = 0; i < searchOptions.length; i++) {
      final option = searchOptions[i];
      children.add(
        SearchOptionWidget(
          option: option,
          value: options[i],
          onChanged: (value) {
            setState(() {
              options[i] = value;
              onChanged();
            });
          },
          sourceKey: searchTarget,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
