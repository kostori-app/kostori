import "package:flutter/material.dart";
import "package:kostori/foundation/app.dart";

import "../anime_source/anime_source.dart";
import "../components/components.dart";
import "../components/select.dart";
import "../network/base_anime.dart";
import "../network/res.dart";

class CategoryAnimesPage extends StatefulWidget {
  const CategoryAnimesPage({
    required this.category,
    this.param,
    required this.categoryKey,
    super.key,
  });

  final String category;

  final String? param;

  final String categoryKey;

  @override
  State<CategoryAnimesPage> createState() => _CategoryAnimesPageState();
}

class _CategoryAnimesPageState extends State<CategoryAnimesPage> {
  late final CategoryAnimesData data;
  late final List<CategoryAnimesOptions> options;
  late List<String> optionsValue;

  void findData() {
    for (final source in AnimeSource.sources) {
      if (source.categoryData?.key == widget.categoryKey) {
        data = source.categoryAnimesData!;
        options = data.options.where((element) {
          if (element.notShowWhen.contains(widget.category)) {
            return false;
          } else if (element.showWhen != null) {
            return element.showWhen!.contains(widget.category);
          }
          return true;
        }).toList();
        optionsValue = options.map((e) => e.options.keys.first).toList();
        return;
      }
    }
    throw "${widget.categoryKey} Not found";
  }

  @override
  void initState() {
    findData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(widget.category),
      ),
      body: Column(
        children: [
          Expanded(
            child: _CategoryAnimesList(
              key: ValueKey(
                  "${widget.category} with ${widget.param} and $optionsValue"),
              loader: data.load,
              category: widget.category,
              options: optionsValue,
              param: widget.param,
              header: buildOptions(),
              sourceKey: AnimeSource.sources
                  .firstWhere((e) => e.categoryData?.key == widget.categoryKey)
                  .key,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOptionItem(
      String text, String value, int group, BuildContext context) {
    return OptionChip(
      text: text,
      isSelected: value == optionsValue[group],
      onTap: () {
        if (value == optionsValue[group]) return;
        setState(() {
          optionsValue[group] = value;
        });
      },
    );
  }

  Widget buildOptions() {
    List<Widget> children = [];
    for (var optionList in options) {
      children.add(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var option in optionList.options.entries)
            buildOptionItem(
              option.value,
              option.key,
              options.indexOf(optionList),
              context,
            )
        ],
      ));
      if (options.last != optionList) {
        children.add(const SizedBox(height: 8));
      }
    }
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...children, const Divider()],
      ).paddingLeft(8).paddingRight(8),
    );
  }
}

class _CategoryAnimesList extends AnimesPage<BaseAnime> {
  const _CategoryAnimesList({
    super.key,
    required this.loader,
    required this.category,
    required this.options,
    this.param,
    required this.header,
    required this.sourceKey,
  });

  final CategoryAnimesLoader loader;

  final String category;

  final List<String> options;

  final String? param;

  @override
  final String sourceKey;

  @override
  final Widget header;

  @override
  Future<Res<List<BaseAnime>>> getAnimes(int i) async {
    return await loader(category, param, options, i);
  }

  @override
  String? get tag => "$category with $param and $options";

  @override
  String? get title => null;
}
