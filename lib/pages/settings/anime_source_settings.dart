import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AnimeSourceSettings extends StatefulWidget {
  const AnimeSourceSettings({super.key});

  static Future<int> checkAnimeSourceUpdate() async {
    if (AnimeSource.all().isEmpty) {
      return 0;
    }
    var dio = AppDio();
    var res = await dio.get<String>(appdata.settings['animeSourceListUrl']);
    if (res.statusCode != 200) {
      return -1;
    }
    var list = jsonDecode(res.data!) as List;
    var versions = <String, String>{};
    for (var source in list) {
      versions[source['key']] = source['version'];
    }
    var shouldUpdate = <String>[];
    for (var source in AnimeSource.all()) {
      if (versions.containsKey(source.key) &&
          compareSemVer(versions[source.key]!, source.version)) {
        shouldUpdate.add(source.key);
      }
    }
    if (shouldUpdate.isNotEmpty) {
      for (var key in shouldUpdate) {
        AnimeSource.availableUpdates[key] = versions[key]!;
      }
      AnimeSource.notifyListeners();
    }
    return shouldUpdate.length;
  }

  @override
  State<AnimeSourceSettings> createState() => _AnimeSourcePageState();
}

class _AnimeSourcePageState extends State<AnimeSourceSettings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const _Body(),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  var url = "";

  void updateUI() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AnimeSource.addListener(updateUI);
  }

  @override
  void dispose() {
    super.dispose();
    AnimeSource.removeListener(updateUI);
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text('Anime Source'.tl),
          style: AppbarStyle.shadow,
        ),
        buildCard(context),
        for (var source in AnimeSource.all()) buildSource(context, source),
        SliverPadding(padding: EdgeInsets.only(bottom: context.padding.bottom)),
      ],
    );
  }

  Widget buildSource(BuildContext context, AnimeSource source) {
    var newVersion = AnimeSource.availableUpdates[source.key];
    bool hasUpdate =
        newVersion != null && compareSemVer(newVersion, source.version);
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const Divider(),
          ListTile(
            title: Row(
              children: [
                Text(source.name),
                const SizedBox(width: 6),
                if (hasUpdate)
                  Tooltip(
                    message: newVersion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "New Version".tl,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: "Edit".tl,
                  child: IconButton(
                      onPressed: () => edit(source),
                      icon: const Icon(Icons.edit_note)),
                ),
                Tooltip(
                  message: "Update".tl,
                  child: IconButton(
                      onPressed: () => update(source),
                      icon: const Icon(Icons.update)),
                ),
                Tooltip(
                  message: "Delete".tl,
                  child: IconButton(
                      onPressed: () => delete(source),
                      icon: const Icon(Icons.delete)),
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text("Version"),
            subtitle: Text(source.version),
          ),
          ...buildSourceSettings(source),
        ],
      ),
    );
  }

  Iterable<Widget> buildSourceSettings(AnimeSource source) sync* {
    if (source.settings == null) {
      return;
    } else if (source.data['settings'] == null) {
      source.data['settings'] = {};
    }
    for (var item in source.settings!.entries) {
      var key = item.key;
      String type = item.value['type'];
      try {
        if (type == "select") {
          var current = source.data['settings'][key];
          if (current == null) {
            var d = item.value['default'];
            for (var option in item.value['options']) {
              if (option['value'] == d) {
                current = option['text'] ?? option['value'];
                break;
              }
            }
          } else {
            current = item.value['options']
                    .firstWhere((e) => e['value'] == current)['text'] ??
                current;
          }
          yield ListTile(
            title: Text((item.value['title'] as String).ts(source.key)),
            trailing: Select(
              current: (current as String).ts(source.key),
              values: (item.value['options'] as List)
                  .map<String>((e) =>
                      ((e['text'] ?? e['value']) as String).ts(source.key))
                  .toList(),
              onTap: (i) {
                source.data['settings'][key] =
                    item.value['options'][i]['value'];
                source.saveData();
                setState(() {});
              },
            ),
          );
        } else if (type == "switch") {
          var current = source.data['settings'][key] ?? item.value['default'];
          yield ListTile(
            title: Text((item.value['title'] as String).ts(source.key)),
            trailing: Switch(
              value: current,
              onChanged: (v) {
                source.data['settings'][key] = v;
                source.saveData();
                setState(() {});
              },
            ),
          );
        } else if (type == "input") {
          var current =
              source.data['settings'][key] ?? item.value['default'] ?? '';
          yield ListTile(
            title: Text((item.value['title'] as String).ts(source.key)),
            subtitle:
                Text(current, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                showInputDialog(
                  context: context,
                  title: (item.value['title'] as String).ts(source.key),
                  initialValue: current,
                  inputValidator: item.value['validator'] == null
                      ? null
                      : RegExp(item.value['validator']),
                  onConfirm: (value) {
                    source.data['settings'][key] = value;
                    source.saveData();
                    setState(() {});
                    return null;
                  },
                );
              },
            ),
          );
        } else if (type == "callback") {
          yield _CallbackSetting(setting: item, sourceKey: source.key);
        }
      } catch (e, s) {
        Log.error("AnimeSourcePage", "Failed to build a setting\n$e\n$s");
      }
    }
  }

  void delete(AnimeSource source) {
    showConfirmDialog(
      context: App.rootContext,
      title: "Delete".tl,
      content: "Delete anime source '@n' ?".tlParams({
        "n": source.name,
      }),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        var file = File(source.filePath);
        file.delete();
        AnimeSource.remove(source.key);
        _validatePages();
        App.forceRebuild();
      },
    );
  }

  void edit(AnimeSource source) async {
    if (App.isDesktop) {
      try {
        await Process.run("code", [source.filePath], runInShell: true);
        await showDialog(
          context: App.rootContext,
          builder: (context) => AlertDialog(
            title: const Text("Reload Configs"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("cancel")),
              TextButton(
                  onPressed: () async {
                    await AnimeSource.reload();
                    App.forceRebuild();
                  },
                  child: const Text("continue")),
            ],
          ),
        );
        return;
      } catch (e) {
        //
      }
    }
    context.to(() => _EditFilePage(source.filePath, () async {
          await AnimeSource.reload();
          setState(() {});
        }));
  }

  static Future<void> update(AnimeSource source) async {
    if (!source.url.isURL) {
      App.rootContext.showMessage(message: "Invalid url config");
      return;
    }
    AnimeSource.remove(source.key);
    bool cancel = false;
    var controller = showLoadingDialog(
      App.rootContext,
      onCancel: () => cancel = true,
      barrierDismissible: false,
    );
    try {
      var res = await AppDio().get<String>(source.url,
          options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await AnimeSourceParser().parse(res.data!, source.filePath);
      await File(source.filePath).writeAsString(res.data!);
      if (AnimeSource.availableUpdates.containsKey(source.key)) {
        AnimeSource.availableUpdates.remove(source.key);
      }
    } catch (e) {
      if (cancel) return;
      App.rootContext.showMessage(message: e.toString());
    }
    await AnimeSource.reload();
    App.forceRebuild();
  }

  Widget buildCard(BuildContext context) {
    Widget buildButton(
        {required Widget child, required VoidCallback onPressed}) {
      return Button.normal(
        onPressed: onPressed,
        child: child,
      ).fixHeight(32);
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("Add anime source".tl),
              leading: const Icon(Icons.dashboard_customize),
            ),
            TextField(
              decoration: InputDecoration(
                  hintText: "URL",
                  border: const UnderlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  suffix: IconButton(
                      onPressed: () => handleAddSource(url),
                      icon: const Icon(Icons.check))),
              onChanged: (value) {
                url = value;
              },
              onSubmitted: handleAddSource,
            ).paddingHorizontal(16).paddingBottom(8),
            ListTile(
              title: Text("Anime Source list".tl),
              trailing: buildButton(
                child: Text("View".tl),
                onPressed: () {
                  showPopUpWidget(
                    App.rootContext,
                    _AnimeSourceList(handleAddSource),
                  );
                },
              ),
            ),
            ListTile(
              title: Text("Use a config file".tl),
              trailing: buildButton(
                onPressed: _selectFile,
                child: Text("Select".tl),
              ),
            ),
            ListTile(
              title: Text("Help".tl),
              trailing: buildButton(
                onPressed: help,
                child: Text("Open".tl),
              ),
            ),
            ListTile(
              title: Text("Check updates".tl),
              trailing: _CheckUpdatesButton(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _selectFile() async {
    final file = await selectFile(ext: ["js"]);
    if (file == null) return;
    try {
      var fileName = file.name;
      var bytes = await file.readAsBytes();
      var content = utf8.decode(bytes);
      await addSource(content, fileName);
    } catch (e, s) {
      App.rootContext.showMessage(message: e.toString());
      Log.error("Add anime source", "$e\n$s");
    }
  }

  void help() {
    launchUrlString("https://github.com/kostori-app/kostori-configs");
  }

  Future<void> handleAddSource(String url) async {
    if (url.isEmpty) {
      return;
    }
    var splits = url.split("/");
    splits.removeWhere((element) => element == "");
    var fileName = splits.last;
    bool cancel = false;
    var controller = showLoadingDialog(App.rootContext,
        onCancel: () => cancel = true, barrierDismissible: false);
    try {
      var res = await AppDio()
          .get<String>(url, options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await addSource(res.data!, fileName);
    } catch (e, s) {
      if (cancel) return;
      context.showMessage(message: e.toString());
      Log.error("Add anime source", "$e\n$s");
    }
  }

  Future<void> addSource(String js, String fileName) async {
    var animeSource = await AnimeSourceParser().createAndParse(js, fileName);
    AnimeSource.add(animeSource);
    _addAllPagesWithAnimeSource(animeSource);
    appdata.saveData();
    App.forceRebuild();
  }
}

class _AnimeSourceList extends StatefulWidget {
  const _AnimeSourceList(this.onAdd);

  final Future<void> Function(String) onAdd;

  @override
  State<_AnimeSourceList> createState() => _AnimeSourceListState();
}

class _AnimeSourceListState extends State<_AnimeSourceList> {
  bool loading = true;
  List? json;

  void load() async {
    var dio = AppDio();
    var res = await dio.get<String>(appdata.settings['animeSourceListUrl']);
    if (res.statusCode != 200) {
      context.showMessage(message: "Network error".tl);
      return;
    }
    setState(() {
      json = jsonDecode(res.data!);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Anime Source".tl,
      tailing: [
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () async {
            await showInputDialog(
              context: context,
              title: "Set anime source list url".tl,
              initialValue: appdata.settings['animeSourceListUrl'],
              onConfirm: (value) {
                appdata.settings['animeSourceListUrl'] = value;
                appdata.saveData();
                setState(() {
                  loading = true;
                  json = null;
                });
                return null;
              },
            );
          },
        )
      ],
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (loading) {
      load();
      return const Center(child: CircularProgressIndicator());
    } else {
      var currentKey = AnimeSource.all().map((e) => e.key).toList();
      return ListView.builder(
        itemCount: json!.length,
        itemBuilder: (context, index) {
          var key = json![index]["key"];
          var action = currentKey.contains(key)
              ? const Icon(Icons.check, size: 20).paddingRight(8)
              : Button.filled(
                  child: Text("Add".tl),
                  onPressed: () async {
                    var fileName = json![index]["fileName"];
                    var url = json![index]["url"];
                    if (url == null || !(url.toString()).isURL) {
                      var listUrl =
                          appdata.settings['animeSourceListUrl'] as String;
                      if (listUrl
                          .replaceFirst("https://", "")
                          .replaceFirst("http://", "")
                          .contains("/")) {
                        url =
                            listUrl.substring(0, listUrl.lastIndexOf("/") + 1) +
                                fileName;
                      } else {
                        url = '$listUrl/$fileName';
                      }
                    }
                    await widget.onAdd(url);
                    setState(() {});
                  },
                ).fixHeight(32);

          return ListTile(
            title: Text(json![index]["name"]),
            subtitle: Text(json![index]["version"]),
            trailing: action,
          );
        },
      );
    }
  }
}

void _validatePages() {
  List explorePages = appdata.settings['explore_pages'];
  List categoryPages = appdata.settings['categories'];
  List networkFavorites = appdata.settings['favorites'];

  var totalExplorePages = AnimeSource.all()
      .map((e) => e.explorePages.map((e) => e.title))
      .expand((element) => element)
      .toList();
  var totalCategoryPages = AnimeSource.all()
      .map((e) => e.categoryData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
  var totalNetworkFavorites = AnimeSource.all()
      .map((e) => e.favoriteData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();

  for (var page in List.from(explorePages)) {
    if (!totalExplorePages.contains(page)) {
      explorePages.remove(page);
    }
  }
  for (var page in List.from(categoryPages)) {
    if (!totalCategoryPages.contains(page)) {
      categoryPages.remove(page);
    }
  }
  for (var page in List.from(networkFavorites)) {
    if (!totalNetworkFavorites.contains(page)) {
      networkFavorites.remove(page);
    }
  }

  appdata.settings['explore_pages'] = explorePages.toSet().toList();
  appdata.settings['categories'] = categoryPages.toSet().toList();
  appdata.settings['favorites'] = networkFavorites.toSet().toList();

  appdata.saveData();
}

void _addAllPagesWithAnimeSource(AnimeSource source) {
  var explorePages = appdata.settings['explore_pages'];
  var categoryPages = appdata.settings['categories'];
  var networkFavorites = appdata.settings['favorites'];

  if (source.explorePages.isNotEmpty) {
    for (var page in source.explorePages) {
      if (!explorePages.contains(page.title)) {
        explorePages.add(page.title);
      }
    }
  }
  if (source.categoryData != null &&
      !categoryPages.contains(source.categoryData!.key)) {
    categoryPages.add(source.categoryData!.key);
  }
  if (source.favoriteData != null &&
      !networkFavorites.contains(source.favoriteData!.key)) {
    networkFavorites.add(source.favoriteData!.key);
  }

  appdata.settings['explore_pages'] = explorePages.toSet().toList();
  appdata.settings['categories'] = categoryPages.toSet().toList();
  appdata.settings['favorites'] = networkFavorites.toSet().toList();

  appdata.saveData();
}

class _EditFilePage extends StatefulWidget {
  const _EditFilePage(this.path, this.onExit);

  final String path;

  final void Function() onExit;

  @override
  State<_EditFilePage> createState() => __EditFilePageState();
}

class __EditFilePageState extends State<_EditFilePage> {
  var current = '';

  @override
  void initState() {
    super.initState();
    current = File(widget.path).readAsStringSync();
  }

  @override
  void dispose() {
    File(widget.path).writeAsStringSync(current);
    widget.onExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("Edit".tl),
      ),
      body: Column(
        children: [
          Container(
            height: 0.6,
            color: context.colorScheme.outlineVariant,
          ),
          Expanded(
            child: CodeEditor(
              initialValue: current,
              onChanged: (value) => current = value,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckUpdatesButton extends StatefulWidget {
  const _CheckUpdatesButton();

  @override
  State<_CheckUpdatesButton> createState() => _CheckUpdatesButtonState();
}

class _CheckUpdatesButtonState extends State<_CheckUpdatesButton> {
  bool isLoading = false;

  void check() async {
    setState(() {
      isLoading = true;
    });
    var count = await AnimeSourceSettings.checkAnimeSourceUpdate();
    if (count == -1) {
      context.showMessage(message: "Network error".tl);
    } else if (count == 0) {
      context.showMessage(message: "No updates".tl);
    } else {
      context.showMessage(message: "@c updates".tlParams({"c": count}));
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Button.normal(
      onPressed: check,
      isLoading: isLoading,
      child: Text("Check".tl),
    ).fixHeight(32);
  }
}

class _CallbackSetting extends StatefulWidget {
  const _CallbackSetting({required this.setting, required this.sourceKey});

  final MapEntry<String, Map<String, dynamic>> setting;

  final String sourceKey;

  @override
  State<_CallbackSetting> createState() => _CallbackSettingState();
}

class _CallbackSettingState extends State<_CallbackSetting> {
  String get key => widget.setting.key;

  String get buttonText => widget.setting.value['buttonText'] ?? "Click";

  String get title => widget.setting.value['title'] ?? key;

  bool isLoading = false;

  Future<void> onClick() async {
    var func = widget.setting.value['callback'];
    var result = func([]);
    if (result is Future) {
      setState(() {
        isLoading = true;
      });
      try {
        await result;
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title.ts(widget.sourceKey)),
      trailing: Button.normal(
        onPressed: onClick,
        isLoading: isLoading,
        child: Text(buttonText.ts(widget.sourceKey)),
      ).fixHeight(32),
    );
  }
}
