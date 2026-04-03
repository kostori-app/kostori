// ignore_for_file: use_build_context_synchronously
part of 'settings_page.dart';

class AnimeSourceSettings extends StatelessWidget {
  const AnimeSourceSettings({super.key});

  static Future<int> checkAnimeSourceUpdate() async {
    if (AnimeSource.all().isEmpty) {
      return 0;
    }
    var dio = AppDio();
    dynamic res;
    if (appdata.settings['gitMirror'] &&
        appdata.settings['animeSourceListUrl'] == Api.kostoriConfig) {
      res = await dio.get<String>(Api.gitMirror + Api.kostoriConfig);
    } else {
      res = await dio.get<String>(appdata.settings['animeSourceListUrl']);
    }

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
      var updates = <String, String>{};
      for (var key in shouldUpdate) {
        updates[key] = versions[key]!;
      }
      AnimeSourceManager().updateAvailableUpdates(updates);
    }
    return shouldUpdate.length;
  }

  static Future<void> update(
    AnimeSource source, [
    bool showLoading = true,
  ]) async {
    if (!source.url.isURL) {
      if (showLoading) {
        App.rootContext.showMessage(message: "Invalid url config");
        return;
      } else {
        throw Exception("Invalid url config");
      }
    }
    AnimeSourceManager().remove(source.key);
    bool cancel = false;
    LoadingDialogController? controller;
    if (showLoading) {
      controller = showLoadingDialog(
        App.rootContext,
        onCancel: () => cancel = true,
        barrierDismissible: false,
      );
    }
    try {
      var res = await AppDio().get<String>(
        source.url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {"cache-time": "no"},
        ),
      );
      if (cancel) return;
      controller?.close();
      await AnimeSourceParser().parse(res.data!, source.filePath);
      await io.File(source.filePath).writeAsString(res.data!);
      if (AnimeSourceManager().availableUpdates.containsKey(source.key)) {
        AnimeSourceManager().availableUpdates.remove(source.key);
      }
    } catch (e) {
      if (cancel) return;
      if (showLoading) {
        App.rootContext.showMessage(message: e.toString());
      } else {
        rethrow;
      }
    }
    await AnimeSourceManager().reload();
    if (showLoading) {
      App.forceRebuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.transparent, body: const _Body());
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
    AnimeSourceManager().addListener(updateUI);
  }

  @override
  void dispose() {
    super.dispose();
    AnimeSourceManager().removeListener(updateUI);
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.animeSource), style: AppbarStyle.shadow),
        buildCard(context),
        for (var source in AnimeSource.all())
          _SliverAnimeSource(
            key: ValueKey(source.key),
            source: source,
            edit: edit,
            update: update,
            delete: delete,
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
        ),
      ],
    );
  }

  void delete(AnimeSource source) {
    showConfirmDialog(
      context: App.rootContext,
      title: t.delete,
      content: t.deleteAnimeSourceN(n: source.name),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        var file = File(source.filePath);
        file.delete();
        AnimeSourceManager().remove(source.key);
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
          builder: (context) => ContentDialog(
            title: t.reloadConfigs,
            content: SizedBox(),
            actions: [
              TextButton(
                onPressed: () async {
                  await AnimeSourceManager().reload();
                  App.forceRebuild();
                  App.rootContext.showMessage(message: t.loadSuccess);
                  App.pop();
                },
                child: Text(t.continueText),
              ),
            ],
          ),
        );
        return;
      } catch (e) {
        //
      }
    }
    context.to(
      () => _EditFilePage(source.filePath, () async {
        await AnimeSourceManager().reload();
        setState(() {});
      }),
    );
  }

  void update(AnimeSource source, [bool showLoading = true]) {
    AnimeSourceSettings.update(source, showLoading);
  }

  Widget buildCard(BuildContext context) {
    Widget buildButton({
      required Widget child,
      required VoidCallback onPressed,
    }) {
      return Button.normal(onPressed: onPressed, child: child).fixHeight(32);
    }

    return _BuildSectionPadding(
      _SettingCard(
        children: [
          _SettingPartTitle(
            title: t.addAnimeSource,
            icon: Icons.dashboard_customize,
          ),
          TextField(
            decoration: InputDecoration(
              hintText: "URL",
              border: const UnderlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              suffix: IconButton(
                onPressed: () => handleAddSource(url),
                icon: const Icon(Icons.check),
              ),
            ),
            onChanged: (value) {
              url = value;
            },
            onSubmitted: handleAddSource,
          ).paddingHorizontal(16).paddingBottom(8),
          ListTile(
            title: Text(t.animeSourceList),
            trailing: buildButton(
              child: Text(t.view),
              onPressed: () {
                showPopUpWidget(
                  App.rootContext,
                  _AnimeSourceList(handleAddSource),
                );
              },
            ),
          ),
          ListTile(
            title: Text(t.checkUpdates),
            trailing: buildButton(
              child: Text(t.view),
              onPressed: () {
                showPopUpWidget(App.rootContext, _PingTestPage());
              },
            ),
          ),
          ListTile(
            title: Text(t.useAConfigFile),
            trailing: buildButton(
              onPressed: _selectFile,
              child: Text(t.select),
            ),
          ),
          ListTile(
            title: Text(t.help),
            trailing: buildButton(onPressed: help, child: Text(t.open)),
          ),
          ListTile(
            title: Text(t.checkUpdates),
            trailing: _CheckUpdatesButton(),
          ),
          ListTile(
            title: Text(t.gitMirror),
            trailing: CustomSwitch(
              value: appdata.settings["gitMirror"],
              onChanged: (value) {
                setState(() {
                  appdata.settings["gitMirror"] = value;
                });
                appdata.saveData();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
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
      SourceLog.error("Add anime source", "$e\n$s");
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
    var controller = showLoadingDialog(
      App.rootContext,
      onCancel: () => cancel = true,
      barrierDismissible: false,
    );
    try {
      var res = await AppDio().get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: {"cache-time": "no"},
        ),
      );
      if (cancel) return;
      controller.close();
      await addSource(res.data!, fileName);
    } catch (e, s) {
      if (cancel) return;
      context.showMessage(message: e.toString());
      SourceLog.error("Add anime source", "$e\n$s");
    }
  }

  Future<void> addSource(String js, String fileName) async {
    var animeSource = await AnimeSourceParser().createAndParse(js, fileName);
    AnimeSourceManager().add(animeSource);
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
  bool changed = false;
  var controller = TextEditingController();

  void load() async {
    if (json != null) {
      setState(() {
        json = null;
      });
    }
    if (controller.text.isEmpty) {
      setState(() {
        json = [];
      });
      return;
    }
    var dio = AppDio();
    try {
      dynamic res;
      if (appdata.settings['animeSourceListUrl'] == Api.kostoriConfig &&
          appdata.settings['gitMirror']) {
        res = await dio.get<String>(Api.gitMirror + Api.kostoriConfig);
      } else {
        res = await dio.get<String>(appdata.settings['animeSourceListUrl']);
      }
      if (res.statusCode != 200) {
        context.showMessage(message: t.error);
        return;
      }
      if (mounted) {
        setState(() {
          json = jsonDecode(res.data!);
          loading = false;
        });
      }
    } catch (e) {
      context.showMessage(message: t.error);
      if (mounted) {
        setState(() {
          json = [];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controller.text = appdata.settings['animeSourceListUrl'];
    load();
  }

  @override
  void dispose() {
    super.dispose();
    if (changed) {
      appdata.settings['animeSourceListUrl'] = controller.text;
      appdata.saveData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.animeSource,
      tailing: [
        IconButton(
          icon: Icon(Icons.settings),
          onPressed: () async {
            await showInputDialog(
              context: context,
              title: t.setSourceListUrl,
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
        ),
      ],
      body: buildBody(),
    );
  }

  Widget buildBody() {
    var currentKey = AnimeSource.all().map((e) => e.key).toList();

    return ListView.builder(
      itemCount: (json?.length ?? 1) + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: Icon(Icons.source_outlined),
                  title: Text(t.sourceUrl),
                ),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "URL",
                    border: const UnderlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onChanged: (value) {
                    changed = true;
                  },
                ).paddingHorizontal(16).paddingBottom(8),
                Text(t.theUrlShouldPointToAIndexJsonFile).paddingLeft(16),
                Text(
                  t.doNotReportAnyIssuesRelatedToSourcesToAppRepo,
                ).paddingLeft(16),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.text = Api.kostoriConfig;
                        changed = true;
                      },
                      child: Text(t.reset),
                    ),
                    FilledButton.tonal(onPressed: load, child: Text(t.refresh)),
                    const SizedBox(width: 16),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        if (index == 1 && json == null) {
          return Center(child: KostoriRefreshIndicator());
        }

        index--;

        var key = json![index]["key"];
        var action = currentKey.contains(key)
            ? const Icon(Icons.check, size: 20).paddingRight(8)
            : Button.filled(
                child: Text(t.add),
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

        var description = json![index]["version"];
        if (json![index]["description"] != null) {
          description = "$description\n${json![index]["description"]}";
        }

        return ListTile(
          title: Text(json![index]["name"]),
          subtitle: Text(description),
          trailing: action,
        );
      },
    );
  }
}

void _validatePages() {
  final rawMap = appdata.settings["explore_pages_v2"];
  if (rawMap is! Map) return;

  final pagesMap = rawMap.map(
    (k, v) => MapEntry(k as String, List<String>.from(v as List)),
  );

  var changed = false;

  for (var sourceKey in pagesMap.keys.toList()) {
    var source = AnimeSource.find(sourceKey);
    if (source == null) {
      pagesMap.remove(sourceKey);
      changed = true;
      continue;
    }

    var validPages = source.explorePages.map((e) => e.title).toSet();
    var oldPages = pagesMap[sourceKey]!;
    var newPages = oldPages
        .where((p) => validPages.contains(p))
        .toSet()
        .toList();

    if (newPages.length != oldPages.length) {
      pagesMap[sourceKey] = newPages;
      changed = true;
    }
  }

  if (changed) {
    appdata.settings["explore_pages_v2"] = pagesMap;
  }

  List categoryPages = appdata.settings['categories'];
  var totalCategoryPages = AnimeSource.all()
      .map((e) => e.categoryData?.key)
      .where((e) => e != null)
      .map((e) => e!)
      .toList();

  for (var page in List.from(categoryPages)) {
    if (!totalCategoryPages.contains(page)) {
      categoryPages.remove(page);
    }
  }
  appdata.settings['categories'] = categoryPages.toSet().toList();

  appdata.saveData();
}

void _addAllPagesWithAnimeSource(AnimeSource source) {
  final rawMap = appdata.settings["explore_pages_v2"];
  Map<String, List<String>> pagesMap;

  if (rawMap is Map) {
    pagesMap = rawMap.map(
      (k, v) => MapEntry(k as String, List<String>.from(v as List)),
    );
  } else {
    pagesMap = {};
  }

  if (source.explorePages.isNotEmpty) {
    var existing = pagesMap[source.key] ?? [];
    var existingSet = existing.toSet();
    for (var page in source.explorePages) {
      existingSet.add(page.title);
    }
    pagesMap[source.key] = existingSet.toList();
  }

  appdata.settings["explore_pages_v2"] = pagesMap;

  var categoryPages = appdata.settings['categories'];
  var networkFavorites = appdata.settings['favorites'];
  var searchPages = appdata.settings['searchSources'];

  if (source.categoryData != null &&
      !categoryPages.contains(source.categoryData!.key)) {
    categoryPages.add(source.categoryData!.key);
  }
  if (source.searchPageData != null && !searchPages.contains(source.key)) {
    searchPages.add(source.key);
  }

  appdata.settings['categories'] = categoryPages.toSet().toList();
  appdata.settings['favorites'] = networkFavorites.toSet().toList();
  appdata.settings['searchSources'] = searchPages.toSet().toList();

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
      appBar: Appbar(title: Text(t.edit)),
      body: Column(
        children: [
          Container(height: 0.6, color: context.colorScheme.outlineVariant),
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
      context.showMessage(message: t.error);
    } else if (count == 0) {
      context.showMessage(message: t.noUpdates);
    } else {
      showUpdateDialog();
    }
    setState(() {
      isLoading = false;
    });
  }

  void showUpdateDialog() async {
    var text = AnimeSourceManager().availableUpdates.entries
        .where((e) => AnimeSource.find(e.key) != null)
        .map((e) => "${AnimeSource.find(e.key)!.name}: ${e.value}")
        .join("\n");
    bool doUpdate = false;
    await showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: t.updatesAvailable,
          content: Text(text).paddingHorizontal(16),
          actions: [
            FilledButton(
              onPressed: () {
                doUpdate = true;
                context.pop();
              },
              child: Text(t.update),
            ),
          ],
        );
      },
    );
    if (doUpdate) {
      var loadingController = showLoadingDialog(
        context,
        message: t.updating,
        withProgress: true,
      );
      int current = 0;
      int total = AnimeSourceManager().availableUpdates.length;
      try {
        var shouldUpdate = AnimeSourceManager().availableUpdates.keys.toList();
        for (var key in shouldUpdate) {
          final source = AnimeSource.find(key);
          if (source == null) {
            current++;
            loadingController.setProgress(current / total);
            continue;
          }
          try {
            await AnimeSourceSettings.update(source, false);
          } catch (e, s) {
            SourceLog.error('Update ${source.name}', '$e\n$s');
          }
          current++;
          loadingController.setProgress(current / total);
        }
      } catch (e, s) {
        context.showMessage(message: e.toString());
        SourceLog.error('Updates', '$e\n$s');
      }
      loadingController.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Button.normal(
      onPressed: check,
      isLoading: isLoading,
      child: Text(t.check),
    ).fixHeight(32);
  }
}

class _SliverAnimeSource extends StatefulWidget {
  const _SliverAnimeSource({
    super.key,
    required this.source,
    required this.edit,
    required this.update,
    required this.delete,
  });

  final AnimeSource source;

  final void Function(AnimeSource source) edit;
  final void Function(AnimeSource source) update;
  final void Function(AnimeSource source) delete;

  @override
  State<_SliverAnimeSource> createState() => _SliverAnimeSourceState();
}

class _SliverAnimeSourceState extends State<_SliverAnimeSource> {
  AnimeSource get source => widget.source;

  @override
  Widget build(BuildContext context) {
    var newVersion = AnimeSourceManager().availableUpdates[source.key];
    bool hasUpdate =
        newVersion != null && compareSemVer(newVersion, source.version);

    return _BuildSectionPadding(
      _SettingCard(
        children: [
          ListTile(
            title: Row(
              children: [
                Text(source.name, style: ts.s18),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    source.version,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (hasUpdate)
                  Tooltip(
                    message: newVersion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t.newVersion,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ).paddingLeft(4),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: t.edit,
                  child: IconButton(
                    onPressed: () => widget.edit(source),
                    icon: const Icon(Icons.edit_note),
                  ),
                ),
                Tooltip(
                  message: t.update,
                  child: IconButton(
                    onPressed: () => widget.update(source),
                    icon: const Icon(Icons.update),
                  ),
                ),
                Tooltip(
                  message: t.delete,
                  child: IconButton(
                    onPressed: () => widget.delete(source),
                    icon: const Icon(Icons.delete),
                  ),
                ),
              ],
            ),
          ),

          // 分割线
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
          ),
          Column(children: buildSourceSettings().toList()),
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Column(
              children: _buildAccount()
                  .map(
                    (tile) => Material(color: Colors.transparent, child: tile),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Iterable<Widget> buildSourceSettings() sync* {
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
            current =
                item.value['options'].firstWhere(
                  (e) => e['value'] == current,
                )['text'] ??
                current;
          }
          yield ListTile(
            title: Text((item.value['title'] as String).ts(source.key)),
            trailing: Select(
              current: (current as String).ts(source.key),
              values: (item.value['options'] as List)
                  .map<String>(
                    (e) => ((e['text'] ?? e['value']) as String).ts(source.key),
                  )
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
            subtitle: Text(
              current,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
          yield _AnimeSourceCallbackSetting(
            setting: item,
            sourceKey: source.key,
          );
        }
      } catch (e, s) {
        SourceLog.error("animeSourcePage", "Failed to build a setting\n$e\n$s");
      }
    }
  }

  final _reLogin = <String, bool>{};

  Iterable<Widget> _buildAccount() sync* {
    if (source.account == null) return;
    final bool logged = source.isLogged;
    if (!logged) {
      yield ListTile(
        title: Text(t.logIn),
        trailing: const Icon(Icons.arrow_right),
        onTap: () async {
          await context.to(
            () => _LoginPage(config: source.account!, source: source),
          );
          source.saveData();
          setState(() {});
        },
      );
    }
    if (logged) {
      for (var item in source.account!.infoItems) {
        if (item.builder != null) {
          yield item.builder!(context);
        } else {
          yield ListTile(
            title: Text(item.title),
            subtitle: item.data == null ? null : Text(item.data!()),
            onTap: item.onTap,
          );
        }
      }
      if (source.data["account"] is List) {
        bool loading = _reLogin[source.key] == true;
        yield ListTile(
          title: Text(t.reLogin),
          subtitle: Text(t.clickIfLoginExpired),
          onTap: () async {
            if (source.data["account"] == null) {
              context.showMessage(message: t.noData);
              return;
            }
            setState(() {
              _reLogin[source.key] = true;
            });
            final List account = source.data["account"];
            var res = await source.account!.login!(account[0], account[1]);
            if (res.error) {
              context.showMessage(message: res.errorMessage!);
            } else {
              context.showMessage(message: t.saved);
            }
            setState(() {
              _reLogin[source.key] = false;
            });
          },
          trailing: loading
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        );
      }
      yield ListTile(
        title: Text(t.logOut),
        onTap: () {
          source.data["account"] = null;
          source.account?.logout();
          source.saveData();
          AnimeSourceManager().notifyStateChange();
          setState(() {});
        },
        trailing: const Icon(Icons.logout),
      );
    }
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({required this.config, required this.source});

  final AccountConfig config;

  final AnimeSource source;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  String username = "";
  String password = "";
  bool loading = false;

  final Map<String, String> _cookies = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Appbar(title: Text('')),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 400),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.login, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 32),
                if (widget.config.cookieFields == null)
                  TextField(
                    decoration: InputDecoration(
                      labelText: t.username,
                      border: const OutlineInputBorder(),
                    ),
                    enabled: widget.config.login != null,
                    onChanged: (s) {
                      username = s;
                    },
                    autofillHints: const [AutofillHints.username],
                  ).paddingBottom(16),
                if (widget.config.cookieFields == null)
                  TextField(
                    decoration: InputDecoration(
                      labelText: t.password,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: widget.config.login != null,
                    onChanged: (s) {
                      password = s;
                    },
                    onSubmitted: (s) => login(),
                    autofillHints: const [AutofillHints.password],
                  ).paddingBottom(16),
                for (var field in widget.config.cookieFields ?? <String>[])
                  TextField(
                    decoration: InputDecoration(
                      labelText: field,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enabled: widget.config.validateCookies != null,
                    onChanged: (s) {
                      _cookies[field] = s;
                    },
                  ).paddingBottom(16),
                if (widget.config.login == null &&
                    widget.config.cookieFields == null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 8),
                      Text(t.loginWithPasswordIsDisabled),
                    ],
                  )
                else
                  Button.filled(
                    isLoading: loading,
                    onPressed: login,
                    child: Text(t.continueText),
                  ),
                const SizedBox(height: 24),
                if (widget.config.loginWebsite != null)
                  TextButton(
                    onPressed: () {
                      if (App.isLinux) {
                        loginWithWebview2();
                      } else {
                        loginWithWebview();
                      }
                    },
                    child: Text(t.loginWithWebview),
                  ),
                const SizedBox(height: 8),
                if (widget.config.registerWebsite != null)
                  TextButton(
                    onPressed: () =>
                        launchUrlString(widget.config.registerWebsite!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link),
                        const SizedBox(width: 8),
                        Text(t.createAccount),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void login() {
    if (widget.config.login != null) {
      if (username.isEmpty || password.isEmpty) {
        ToastManager.show(
          message: t.cannotBeEmpty,
          icon: const Icon(Icons.error_outline),
          context: context,
        );
        return;
      }
      setState(() {
        loading = true;
      });
      widget.config.login!(username, password).then((value) {
        if (value.error) {
          context.showMessage(message: value.errorMessage!);
          setState(() {
            loading = false;
          });
        } else {
          if (mounted) {
            context.pop();
          }
        }
      });
    } else if (widget.config.validateCookies != null) {
      setState(() {
        loading = true;
      });
      var cookies = widget.config.cookieFields!
          .map((e) => _cookies[e] ?? '')
          .toList();
      widget.config.validateCookies!(cookies).then((value) {
        if (value) {
          widget.source.data['account'] = 'ok';
          widget.source.saveData();
          context.pop();
        } else {
          context.showMessage(message: t.invalidCookies);
          setState(() {
            loading = false;
          });
        }
      });
    }
  }

  void loginWithWebview() async {
    var url = widget.config.loginWebsite!;
    var title = '';
    bool success = false;

    void validate(InAppWebViewController c) async {
      if (widget.config.checkLoginStatus != null &&
          widget.config.checkLoginStatus!(url, title)) {
        var cookies = (await c.getCookies(url)) ?? [];
        var localStorageItems = await c.webStorage.localStorage.getItems();
        var mappedLocalStorage = <String, dynamic>{};
        for (var item in localStorageItems) {
          if (item.key != null) {
            mappedLocalStorage[item.key!] = item.value;
          }
        }
        widget.source.data['_localStorage'] = mappedLocalStorage;
        await widget.source.saveData();
        SingleInstanceCookieJar.instance?.saveFromResponse(
          Uri.parse(url),
          cookies,
        );
        success = true;
        widget.config.onLoginWithWebviewSuccess?.call();
        App.mainNavigatorKey?.currentContext?.pop();
      }
    }

    await context.to(
      () => AppWebview(
        initialUrl: widget.config.loginWebsite!,
        onNavigation: (u, c) {
          url = u;
          validate(c);
          return false;
        },
        onTitleChange: (t, c) {
          title = t;
          validate(c);
        },
      ),
    );
    if (success) {
      widget.source.data['account'] = 'ok';
      widget.source.saveData();
      context.pop();
    }
  }

  // for linux
  void loginWithWebview2() async {
    if (!await DesktopWebview.isAvailable()) {
      context.showMessage(message: t.webviewIsNotAvailable);
    }

    var url = widget.config.loginWebsite!;
    var title = '';
    bool success = false;

    void onClose() {
      if (success) {
        widget.source.data['account'] = 'ok';
        widget.source.saveData();
        context.pop();
      }
    }

    void validate(DesktopWebview webview) async {
      if (widget.config.checkLoginStatus != null &&
          widget.config.checkLoginStatus!(url, title)) {
        var cookiesMap = await webview.getCookies(url);
        var cookies = <io.Cookie>[];
        cookiesMap.forEach((key, value) {
          cookies.add(io.Cookie(key, value));
        });
        SingleInstanceCookieJar.instance?.saveFromResponse(
          Uri.parse(url),
          cookies,
        );
        var localStorageJson = await webview.evaluateJavascript(
          "JSON.stringify(window.localStorage);",
        );
        var localStorage = <String, dynamic>{};
        try {
          var decoded = jsonDecode(localStorageJson ?? '');
          if (decoded is Map<String, dynamic>) {
            localStorage = decoded;
          }
        } catch (e) {
          Log.error("AnimeSourcePage", "Failed to parse localStorage JSON\n$e");
        }
        widget.source.data['_localStorage'] = localStorage;
        await widget.source.saveData();
        success = true;
        widget.config.onLoginWithWebviewSuccess?.call();
        webview.close();
        onClose();
      }
    }

    var webview = DesktopWebview(
      initialUrl: widget.config.loginWebsite!,
      onTitleChange: (t, webview) {
        title = t;
        validate(webview);
      },
      onNavigation: (u, webview) {
        url = u;
        validate(webview);
      },
      onClose: onClose,
    );

    webview.open();
  }
}

class _PingTestPage extends StatefulWidget {
  const _PingTestPage();

  @override
  State<_PingTestPage> createState() => _PingTestPageState();
}

class _PingTestPageState extends State<_PingTestPage> {
  List<TextEditingController> customControllers = [];
  bool changed = false;
  bool testing = false;
  bool continuousPing = false;
  Timer? _continuousTimer;
  List<_PingResult> results = [];
  final int _timeoutSeconds = 5;
  final Set<String> _enabledEndpoints = {};
  List<Map<String, String?>> _defaultEndpointsCache = [];
  final _inputController = TextEditingController();

  void _addCustomEndpoint() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (customControllers.any((c) => c.text == text)) {
      context.showMessage(message: t.addressAlreadyExists);
      return;
    }
    setState(() {
      customControllers.add(TextEditingController(text: text));
      _inputController.clear();
      changed = true;
    });
  }

  Future<void> _loadDefaultEndpoints() async {
    final result = <Map<String, String?>>[];
    for (final source in AnimeSource.all()) {
      final endpoint = source.host != null ? await source.host!() : null;
      result.add({'name': source.name, 'endpoint': endpoint});
    }
    if (mounted) setState(() => _defaultEndpointsCache = result);
  }

  List<Map<String, String?>> get _customEndpoints => customControllers
      .where((c) => c.text.isNotEmpty)
      .map((c) => {'name': c.text, 'endpoint': c.text})
      .toList();

  List<Map<String, String?>> get _activeEndpoints => [
    ..._customEndpoints.where((e) => _enabledEndpoints.contains(e['endpoint'])),
    ..._defaultEndpointsCache.where(
      (e) => _enabledEndpoints.contains(e['endpoint']),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultEndpoints();
    final saved = appdata.settings['pingCustomEndpoints'];
    if (saved is List && saved.isNotEmpty) {
      customControllers = saved
          .map((e) => TextEditingController(text: e.toString()))
          .toList();
    } else {
      customControllers = [TextEditingController()];
    }
  }

  @override
  void dispose() {
    _continuousTimer?.cancel();
    _inputController.dispose();
    if (changed) {
      appdata.settings['pingCustomEndpoints'] = customControllers
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList();
      appdata.saveData();
    }
    for (final c in customControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<int?> _ping(String endpoint) async {
    if (endpoint.isEmpty) return null;
    try {
      final url = endpoint.startsWith('http') ? endpoint : 'https://$endpoint';
      final stopwatch = Stopwatch()..start();
      await AppDio().get(
        url,
        options: Options(
          sendTimeout: Duration(seconds: _timeoutSeconds),
          receiveTimeout: Duration(seconds: _timeoutSeconds),
          validateStatus: (_) => true,
        ),
      );
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }

  Future<void> _runTest(String name, String? endpoint) async {
    if (endpoint == null || endpoint.isEmpty) return;

    if (!continuousPing) {
      if (mounted) {
        setState(() {
          results.removeWhere((r) => r.endpoint == endpoint);
          results.add(
            _PingResult(
              name: name,
              endpoint: endpoint,
              status: _PingStatus.testing,
            ),
          );
        });
      }
    }

    final latency = await _ping(endpoint);

    if (mounted) {
      setState(() {
        final index = results.indexWhere((r) => r.endpoint == endpoint);
        if (index != -1) {
          results[index] = _PingResult(
            name: name,
            endpoint: endpoint,
            status: latency != null ? _PingStatus.success : _PingStatus.failed,
            latency: latency,
          );
        } else {
          results.add(
            _PingResult(
              name: name,
              endpoint: endpoint,
              status: latency != null
                  ? _PingStatus.success
                  : _PingStatus.failed,
              latency: latency,
            ),
          );
        }
      });
    }
  }

  Future<void> _runAllTests() async {
    if (_activeEndpoints.isEmpty) {
      context.showMessage(message: t.pleaseEnableAtLeastOneAddress);
      return;
    }
    setState(() => testing = true);
    await Future.wait(
      _activeEndpoints.map((e) => _runTest(e['name']!, e['endpoint'])),
    );
    setState(() => testing = false);
  }

  void _startContinuousPing() {
    if (_activeEndpoints.isEmpty) {
      context.showMessage(message: t.pleaseEnableAtLeastOneAddress);
      return;
    }
    setState(() => continuousPing = true);
    _continuousTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final e in _activeEndpoints) {
        _runTest(e['name']!, e['endpoint']);
      }
    });
  }

  void _stopContinuousPing() {
    _continuousTimer?.cancel();
    _continuousTimer = null;
    setState(() => continuousPing = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.pingTest,
      body: ListView(
        children: [
          // 自定义输入区域
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 0.6,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.network_ping),
                  title: Text(t.customEndpoint),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'e.g. example.com',
                      border: const UnderlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: '添加地址',
                        onPressed: _addCustomEndpoint,
                      ),
                    ),
                    onSubmitted: (_) => _addCustomEndpoint(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        continuousPing ? Icons.stop : Icons.repeat,
                        color: continuousPing
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      tooltip: continuousPing ? t.close : t.continuousPing,
                      onPressed: testing
                          ? null
                          : continuousPing
                          ? _stopContinuousPing
                          : _startContinuousPing,
                    ),
                    FilledButton.tonal(
                      onPressed: (testing || continuousPing)
                          ? null
                          : _runAllTests,
                      child: Text(t.testAll),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // 自定义地址列表
          if (customControllers.any((c) => c.text.isNotEmpty)) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                t.custom,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            ...customControllers
                .asMap()
                .entries
                .where((e) => e.value.text.isNotEmpty)
                .map((e) {
                  final endpoint = e.value.text;
                  final result = results.firstWhereOrNull(
                    (r) => r.endpoint == endpoint,
                  );
                  final enabled = _enabledEndpoints.contains(endpoint);
                  return _PingListTile(
                    name: endpoint,
                    endpoint: endpoint,
                    result: result,
                    enabled: enabled,
                    onToggle: () {
                      setState(() {
                        if (enabled) {
                          _enabledEndpoints.remove(endpoint);
                        } else {
                          _enabledEndpoints.add(endpoint);
                        }
                      });
                    },
                    onTap: enabled ? () => _runTest(endpoint, endpoint) : null,
                    onDelete: () {
                      setState(() {
                        e.value.dispose();
                        customControllers.removeAt(e.key);
                        results.removeWhere((r) => r.endpoint == endpoint);
                        _enabledEndpoints.remove(endpoint);
                        changed = true;
                      });
                    },
                  );
                }),
            const Divider(indent: 16, endIndent: 16),
          ],

          // 预设 endpoints
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              t.sources,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          ..._defaultEndpointsCache.map((e) {
            final endpoint = e['endpoint'];
            final result = results.firstWhereOrNull(
              (r) => r.endpoint == endpoint,
            );
            final enabled = _enabledEndpoints.contains(endpoint);
            return _PingListTile(
              name: e['name']!,
              endpoint: endpoint,
              result: result,
              enabled: enabled,
              onToggle: () {
                setState(() {
                  if (enabled) {
                    _enabledEndpoints.remove(endpoint);
                  } else {
                    if (endpoint != null) _enabledEndpoints.add(endpoint);
                  }
                });
              },
              onTap: enabled && endpoint != null
                  ? () => _runTest(e['name']!, endpoint)
                  : null,
              onDelete: null,
            );
          }),
        ],
      ),
    );
  }
}

enum _PingStatus { testing, success, failed }

class _PingResult {
  final String name;
  final String endpoint;
  final _PingStatus status;
  final int? latency;

  const _PingResult({
    required this.name,
    required this.endpoint,
    required this.status,
    this.latency,
  });
}

class _PingListTile extends StatelessWidget {
  const _PingListTile({
    required this.name,
    required this.endpoint,
    required this.result,
    required this.enabled,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final String name;
  final String? endpoint;
  final _PingResult? result;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget statusWidget;

    if (!enabled || endpoint == null || endpoint!.isEmpty) {
      statusWidget = const SizedBox.shrink();
    } else {
      switch (result?.status) {
        case _PingStatus.testing:
          statusWidget = const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
          break;
        case _PingStatus.success:
          final ms = result!.latency!;
          final color = ms < 100
              ? Colors.green
              : ms < 300
              ? Colors.orange
              : Colors.red;
          statusWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.toOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${ms}ms',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          );
          break;
        case _PingStatus.failed:
          statusWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.toOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Timeout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          );
          break;
        default:
          statusWidget = IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            onPressed: onTap,
            tooltip: 'Test',
          );
      }
    }

    return ListTile(
      leading: CustomSwitch(value: enabled, onChanged: (_) => onToggle()),
      title: Text(name),
      subtitle: endpoint != null && endpoint!.isNotEmpty
          ? Text(endpoint!)
          : Text('暂无地址', style: TextStyle(color: Colors.grey[500])),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusWidget,
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: '删除',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
      onTap: enabled && onTap != null ? onTap : null,
    );
  }
}
