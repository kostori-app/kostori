part of kostori_settings;

class AnimeSourceSettings extends StatefulWidget {
  const AnimeSourceSettings({super.key});

  @override
  State<AnimeSourceSettings> createState() => _AnimeSourceSettingsState();

  static void checkCustomAnimeSourceUpdate([bool showLoading = false]) async {
    if (AnimeSource.sources.isEmpty) {
      return;
    }
    var controller = showLoading ? showLoadingDialog(App.globalContext!) : null;
    var dio = logDio();
    var res = await dio.get<String>(
        "https://raw.githubusercontent.com/wgh136/pica_configs/master/index.json");
    if (res.statusCode != 200) {
      showToast(message: "网络错误");
      return;
    }
    var list = jsonDecode(res.data!) as List;
    var versions = <String, String>{};
    for (var source in list) {
      versions[source['key']] = source['version'];
    }
    var shouldUpdate = <String>[];
    for (var source in AnimeSource.sources) {
      if (versions.containsKey(source.key) &&
          versions[source.key] != source.version) {
        shouldUpdate.add(source.key);
      }
    }
    controller?.close();
    if (shouldUpdate.isEmpty) {
      return;
    }
    var msg = "";
    for (var key in shouldUpdate) {
      msg += "${AnimeSource.find(key)?.name}: v${versions[key]}\n";
    }
    msg = msg.trim();
    showConfirmDialog(App.globalContext!, "有可用更新", msg, () {
      for (var key in shouldUpdate) {
        var source = AnimeSource.find(key);
        _AnimeSourceSettingsState.update(source!);
      }
    });
  }
}

extension _WidgetExt on Widget {
  Widget withDivider() {
    return Column(
      children: [
        this,
        const Divider(),
      ],
    );
  }
}

class _AnimeSourceSettingsState extends State<AnimeSourceSettings> {
  var url = "";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildCard(context),
        const _BuiltInSources(),
        if (appdata.appSettings.isAnimeSourceEnabled("girigirilove"))
          const GiriGiriLoveSettings(false).withDivider(),
        // if (appdata.appSettings.isAnimeSourceEnabled("ehentai"))
        //   const EhSettings(false).withDivider(),
        // if (appdata.appSettings.isAnimeSourceEnabled("jm"))
        //   const JmSettings(false).withDivider(),
        // if (appdata.appSettings.isAnimeSourceEnabled("htmanga"))
        //   const HtSettings(false).withDivider(),
        buildCustomSettings(),
        for (var source in AnimeSource.sources.where((e) => !e.isBuiltIn))
          buildCustom(context, source),
        Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
      ],
    );
  }

  Widget buildCustomSettings() {
    return Column(
      children: [
        ListTile(
          title: Text("自定义番源"),
        ),
        ListTile(
          leading: const Icon(Icons.update_outlined),
          title: Text("检查更新"),
          onTap: () => AnimeSourceSettings.checkCustomAnimeSourceUpdate(true),
          trailing: const Icon(Icons.arrow_right),
        ),
        SwitchSetting(
          title: "启动时检查更新",
          icon: const Icon(Icons.security_update),
          settingsIndex: 80,
        )
      ],
    );
  }

  Widget buildCustom(BuildContext context, AnimeSource source) {
    return Column(
      children: [
        const Divider(),
        ListTile(
          title: Text(source.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (App.isDesktop)
                Tooltip(
                  message: "Edit",
                  child: IconButton(
                      onPressed: () => edit(source),
                      icon: const Icon(Icons.edit_note)),
                ),
              Tooltip(
                message: "Update",
                child: IconButton(
                    onPressed: () => update(source),
                    icon: const Icon(Icons.update)),
              ),
              Tooltip(
                message: "Delete",
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
        )
      ],
    );
  }

  void delete(AnimeSource source) {
    showConfirmDialog(App.globalContext!, "删除", "要删除此番源吗?", () {
      var file = File(source.filePath);
      file.delete();
      AnimeSource.sources.remove(source);
      _validatePages();
      MyApp.updater?.call();
    });
  }

  void edit(AnimeSource source) async {
    try {
      await Process.run("code", [source.filePath], runInShell: true);
      await showDialog(
          context: App.globalContext!,
          builder: (context) => AlertDialog(
                title: const Text("Reload Configs"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("cancel")),
                  TextButton(
                      onPressed: () async {
                        await AnimeSource.reload();
                        MyApp.updater?.call();
                      },
                      child: const Text("continue")),
                ],
              ));
    } catch (e) {
      showToast(message: "Failed to launch vscode");
    }
  }

  static void update(AnimeSource source) async {
    AnimeSource.sources.remove(source);
    if (!source.url.isURL) {
      showToast(message: "Invalid url config");
    }
    bool cancel = false;
    var controller = showLoadingDialog(App.globalContext!,
        onCancel: () => cancel = true, barrierDismissible: false);
    try {
      var res = await logDio().get<String>(source.url,
          options: Options(responseType: ResponseType.plain));
      if (cancel) return;
      controller.close();
      await AnimeSourceParser().parse(res.data!, source.filePath);
      await File(source.filePath).writeAsString(res.data!);
    } catch (e) {
      if (cancel) return;
      showToast(message: e.toString());
    }
    await AnimeSource.reload();
    MyApp.updater?.call();
  }

  Widget buildCard(BuildContext context) {
    return Card.outlined(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text("添加番源"),
              leading: const Icon(Icons.dashboard_customize),
            ),
            TextField(
                    decoration: InputDecoration(
                        hintText: "URL",
                        border: const UnderlineInputBorder(),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        suffix: IconButton(
                            onPressed: () => handleAddSource(url),
                            icon: const Icon(Icons.check))),
                    onChanged: (value) {
                      url = value;
                    },
                    onSubmitted: handleAddSource)
                .paddingHorizontal(16)
                .paddingBottom(32),
            Row(
              children: [
                TextButton(onPressed: chooseFile, child: Text("选择文件"))
                    .paddingLeft(8),
                const Spacer(),
                TextButton(
                    onPressed: () {
                      showPopUpWidget(
                          context, _AnimeSourceList(handleAddSource));
                    },
                    child: Text("浏览列表")),
                const Spacer(),
                TextButton(onPressed: help, child: Text("查看帮助"))
                    .paddingRight(8),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).paddingHorizontal(12);
  }

  void chooseFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      extensions: <String>['js'],
    );
    final XFile? file =
        await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    try {
      var fileName = file.name;
      // file.readAsString 会导致中文乱码
      var bytes = await file.readAsBytes();
      var content = utf8.decode(bytes);
      await addSource(content, fileName);
    } catch (e) {
      showToast(message: e.toString());
    }
  }

  void help() {
    launchUrlString(
        "https://github.com/wgh136/PicaComic/blob/master/doc/comic_source.md");
  }

  Future<void> handleAddSource(String url) async {
    if (url.isEmpty) {
      showToast(message: "URL 不能为空");
      return;
    }

    var splits = url.split("/");
    splits.removeWhere((element) => element == "");
    var fileName = splits.last;
    bool cancel = false;
    var controller = showLoadingDialog(App.globalContext!,
        onCancel: () => cancel = true, barrierDismissible: false);

    try {
      var res = await logDio()
          .get<String>(url, options: Options(responseType: ResponseType.plain));

      if (cancel) return;
      controller.close();
      await addSource(res.data!, fileName);

      showToast(message: "源添加成功"); // 添加成功提示
    } catch (e) {
      if (cancel) return;
      if (e is DioException) {
        showToast(message: "网络错误: ${e.message}"); // 针对网络错误的处理
      } else {
        showToast(message: "添加源失败: ${e.toString()}"); // 处理其他类型的错误
      }
    }
  }

  Future<void> addSource(String js, String fileName) async {
    var animeSource = await AnimeSourceParser().createAndParse(js, fileName);
    AnimeSource.sources.add(animeSource);
    _addAllPagesWithAnimeSource(animeSource);
    appdata.updateSettings();
    MyApp.updater?.call();
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
    var dio = logDio();
    var res = await dio.get<String>(
        "https://raw.githubusercontent.com/wgh136/pica_configs/master/index.json");
    if (res.statusCode != 200) {
      showToast(message: "网络错误");
      return;
    }
    setState(() {
      json = jsonDecode(res.data!);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("番源"),
        actions: const [
          IconButton(onPressed: App.globalBack, icon: Icon(Icons.close)),
        ],
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (loading) {
      load();
      return const Center(child: CircularProgressIndicator());
    } else {
      var currentKey = AnimeSource.sources.map((e) => e.key).toList();
      return ListView.builder(
        itemCount: json!.length,
        itemBuilder: (context, index) {
          var key = json![index]["key"];
          var action = currentKey.contains(key)
              ? const Icon(Icons.check)
              : Tooltip(
                  message: "Add",
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      await widget.onAdd(
                          "https://raw.githubusercontent.com/wgh136/pica_configs/master/${json![index]["fileName"]}");
                      setState(() {});
                    },
                  ),
                );

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

class _BuiltInSources extends StatefulWidget {
  const _BuiltInSources();

  @override
  State<_BuiltInSources> createState() => _BuiltInSourcesState();
}

class _BuiltInSourcesState extends State<_BuiltInSources> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        ListTile(
          title: Text("内置番源"),
        ),
        for (int index = 0; index < builtInSources.length; index++)
          buildTile(index),
        const Divider(),
      ],
    );
  }

  bool isLoading = false;

  Widget buildTile(int index) {
    var key = builtInSources[index];
    return ListTile(
      title: Text(AnimeSource.builtIn.firstWhere((e) => e.key == key).name),
      trailing: Switch(
        value: appdata.appSettings.isAnimeSourceEnabled(key),
        onChanged: (v) async {
          if (isLoading) return;
          isLoading = true;
          appdata.appSettings.setAnimeSourceEnabled(key, v);
          await appdata.updateSettings();
          if (!v) {
            AnimeSource.sources.removeWhere((e) => e.key == key);
            _validatePages();
          } else {
            var source = AnimeSource.builtIn.firstWhere((e) => e.key == key);
            AnimeSource.sources.add(source);
            source.loadData();
            _addAllPagesWithAnimeSource(source);
          }
          isLoading = false;
          if (mounted) {
            setState(() {});
            context
                .findAncestorStateOfType<_AnimeSourceSettingsState>()
                ?.setState(() {});
          }
        },
      ),
    );
  }
}

void _validatePages() {
  var explorePages = appdata.appSettings.explorePages;
  var categoryPages = appdata.appSettings.categoryPages;
  var networkFavorites = appdata.appSettings.networkFavorites;

  var totalExplorePages = AnimeSource.sources
      .map((e) => e.explorePages.map((e) => e.title))
      .expand((element) => element)
      .toList();
  var totalCategoryPages = AnimeSource.sources
      .map((e) => e.categoryData?.key)
      .where((element) => element != null)
      .map((e) => e!)
      .toList();
  var totalNetworkFavorites = AnimeSource.sources
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

  appdata.appSettings.explorePages = explorePages;
  appdata.appSettings.categoryPages = categoryPages;
  appdata.appSettings.networkFavorites = networkFavorites;

  appdata.updateSettings();
}

void _addAllPagesWithAnimeSource(AnimeSource source) {
  var explorePages = appdata.appSettings.explorePages;
  var categoryPages = appdata.appSettings.categoryPages;
  var networkFavorites = appdata.appSettings.networkFavorites;

  // 添加拓展番源探索页面
  if (source.explorePages.isNotEmpty) {
    for (var page in source.explorePages) {
      if (!explorePages.contains(page.title)) {
        explorePages.add(page.title);
      }
    }
  }
  // 添加分类页面
  if (source.categoryData != null &&
      !categoryPages.contains(source.categoryData!.key)) {
    categoryPages.add(source.categoryData!.key);
  }
  // 添加收藏页面
  if (source.favoriteData != null &&
      !networkFavorites.contains(source.favoriteData!.key)) {
    networkFavorites.add(source.favoriteData!.key);
  }

  // 更新设置并去重
  appdata.appSettings.explorePages = explorePages.toSet().toList();
  appdata.appSettings.categoryPages = categoryPages.toSet().toList();
  appdata.appSettings.networkFavorites = networkFavorites.toSet().toList();

  appdata.updateSettings();
}
