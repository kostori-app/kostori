import "package:flutter/material.dart";
import "package:kostori/foundation/app.dart";
import "package:kostori/utils/translations.dart";
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';

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
  late String sourceKey;

  void findData() {
    for (final source in AnimeSource.all()) {
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
        sourceKey = source.key;
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
    var topPadding = context.padding.top + 56.0;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Appbar(
        title: Text(widget.category),
      ),
      body: AnimeList(
        key: Key(widget.category + optionsValue.toString()),
        errorLeading: SizedBox(height: topPadding),
        leadingSliver: buildOptions().paddingTop(topPadding).toSliver(),
        loadPage: (i) => data.load(
          widget.category,
          widget.param,
          optionsValue,
          i,
        ),
      ),
    );
  }

  Widget buildOptionItem(
      String text, String value, int group, BuildContext context) {
    return OptionChip(
      text: text.ts(sourceKey),
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
              option.value.tl,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...children, const Divider()],
    ).paddingLeft(8).paddingRight(8);
  }
}
