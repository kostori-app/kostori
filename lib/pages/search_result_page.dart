import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/pages/search_page.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({
    super.key,
    required this.text,
    required this.sourceKey,
    this.options,
  });

  final String text;

  final String sourceKey;

  final List<String>? options;

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
      appdata.addSearchHistory(text);
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
    sourceKey = widget.sourceKey;
    text = widget.text;
    controller = SearchBarController(currentText: text, onSearch: search);
    options = widget.options ?? const [];
    validateOptions();
    appdata.addSearchHistory(text);
    appdata.saveData();
    super.initState();
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
    return AnimeList(
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
    );
  }

  Widget buildAction() {
    return Tooltip(
      message: "Settings".tl,
      child: IconButton(
        icon: const Icon(Icons.tune),
        onPressed: () async {
          var previousOptions = List<String>.from(options);
          var previousSourceKey = sourceKey;
          await showDialog(
            context: context,
            useRootNavigator: true,
            builder: (context) {
              return _SearchSettingsDialog(state: this);
            },
          );
          if (!previousOptions.isEqualTo(options) ||
              previousSourceKey != sourceKey) {
            text = controller.text;
            controller.currentText = text;
            setState(() {});
          }
        },
      ),
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
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "Settings".tl,
      content: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text("Search in".tl),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AnimeSource.all().map((e) {
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
                        )!.searchPageData!.searchOptions ??
                        <SearchOptions>[];
                    options = searchOptions.map((e) => e.defaultValue).toList();
                    onChanged();
                  });
                },
              );
            }).toList(),
          ).fixWidth(double.infinity).paddingHorizontal(16),
          buildSearchOptions(),
          const SizedBox(height: 24),
          FilledButton(
            child: Text("Confirm".tl),
            onPressed: () {
              context.pop();
            },
          ),
        ],
      ).fixWidth(double.infinity),
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
