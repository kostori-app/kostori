import "package:flutter/material.dart";
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import "package:kostori/foundation/app.dart";
import "package:kostori/utils/translations.dart";

class CategoryAnimesPage extends StatefulWidget {
  const CategoryAnimesPage({
    required this.category,
    this.param,
    required this.categoryKey,
    this.options,
    super.key,
  });

  final String category;

  final String? param;

  final String categoryKey;

  final List<String>? options;

  @override
  State<CategoryAnimesPage> createState() => _CategoryAnimesPageState();
}

class _CategoryAnimesPageState extends State<CategoryAnimesPage> {
  late final CategoryAnimesData data;
  late final List<CategoryAnimesOptions>? options;
  late final CategoryOptionsLoader? optionsLoader;
  late List<String> optionsValue;
  late String sourceKey;
  String? error;

  void findData() {
    for (final source in AnimeSource.all()) {
      if (source.categoryData?.key == widget.categoryKey) {
        if (source.categoryAnimesData == null) {
          throw "The comic source ${source.name} does not support category comics";
        }
        data = source.categoryAnimesData!;
        if (data.options != null) {
          options = data.options!.where((element) {
            if (element.notShowWhen.contains(widget.category)) {
              return false;
            } else if (element.showWhen != null) {
              return element.showWhen!.contains(widget.category);
            }
            return true;
          }).toList();
        } else {
          options = null;
        }
        if (data.optionsLoader != null) {
          optionsLoader = data.optionsLoader;
          loadOptions();
        }
        resetOptionsValue();
        sourceKey = source.key;
        return;
      }
    }
    throw "${widget.categoryKey} Not found";
  }

  void resetOptionsValue() {
    if (options == null) return;
    var defaultOptionsValue = options!
        .map((e) => e.options.keys.first)
        .toList();
    if (optionsValue.length != options!.length) {
      var newOptionsValue = List<String>.filled(options!.length, "");
      for (var i = 0; i < options!.length; i++) {
        newOptionsValue[i] =
            optionsValue.elementAtOrNull(i) ?? defaultOptionsValue[i];
      }
      optionsValue = newOptionsValue;
    }
  }

  void loadOptions() async {
    final res = await optionsLoader!(widget.category, widget.param);
    if (res.error) {
      setState(() {
        error = res.errorMessage;
      });
    } else {
      setState(() {
        options = res.data;
        resetOptionsValue();
        error = null;
      });
    }
  }

  @override
  void initState() {
    if (widget.options != null) {
      optionsValue = widget.options!;
    } else {
      optionsValue = [];
    }
    findData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var topPadding = context.padding.top + 56.0;
    Widget body;

    if (options == null) {
      body = Center(child: CircularProgressIndicator());
    } else if (error != null) {
      body = NetworkError(
        message: error!,
        retry: () {
          setState(() {
            error = null;
          });
          loadOptions();
        },
      );
    } else {
      body = AnimeList(
        key: Key(widget.category + optionsValue.toString()),
        errorLeading: buildOptions().paddingTop(topPadding),
        leadingSliver: buildOptions().paddingTop(topPadding).toSliver(),
        loadPage: (i) =>
            data.load(widget.category, widget.param, optionsValue, i),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: Appbar(title: Text(widget.category)),
      body: body,
    );
  }

  Widget buildOptionItem(
    String text,
    String value,
    int group,
    BuildContext context,
  ) {
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
    var group = 0;
    for (var optionList in options!) {
      if (optionList.label.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
            child: Text(
              optionList.label.ts(sourceKey),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      if (optionList.options.length <= 8) {
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var option in optionList.options.entries)
                buildOptionItem(option.value.tl, option.key, group, context),
            ],
          ),
        );
      } else {
        var g = group;
        children.add(
          Select(
            current: optionList.options[optionsValue[g]],
            values: optionList.options.values.toList(),
            onTap: (i) {
              var key = optionList.options.keys.elementAt(i);
              if (key == optionsValue[g]) return;
              setState(() {
                optionsValue[g] = key;
              });
            },
          ),
        );
      }
      if (options!.last != optionList) {
        children.add(const SizedBox(height: 8));
      }
      group++;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [...children, const Divider()],
    ).paddingLeft(8).paddingRight(8);
  }
}
