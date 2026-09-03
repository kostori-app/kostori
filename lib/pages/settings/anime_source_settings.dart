// ignore_for_file: use_build_context_synchronously
part of 'settings_page.dart';

class AnimeSourceSettings extends StatelessWidget {
  const AnimeSourceSettings({super.key});

  static Future<int> checkAnimeSourceUpdate() async {
    try {
      if (AnimeSource.allSources().isEmpty) {
        return 0;
      }
      // 汇总所有仓库（多仓库 + 兼容旧的单 URL 配置）的版本表
      final versions = <String, String>{};
      final failures = <String>[];
      for (final url in _collectRepoUrls()) {
        try {
          final text = await _fetchRepoText(url);
          if (text == null || text.isEmpty) continue;
          final list = jsonDecode(text);
          if (list is! List) continue;
          for (final source in list) {
            if (source is Map &&
                source['key'] is String &&
                source['version'] is String) {
              versions[source['key'] as String] = source['version'] as String;
            }
          }
        } catch (e) {
          failures.add('$url: $e');
        }
      }
      if (failures.isNotEmpty) {
        NetLog.warning(
          'checkAnimeSourceUpdate',
          '部分仓库拉取失败: ${failures.join('; ')}',
        );
      }
      var shouldUpdate = <String>[];
      for (var source in AnimeSource.allSources()) {
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
    } catch (e) {
      // 后台启动检查：网络不可达/超时时静默失败，避免未处理异常刷屏
      NetLog.warning('checkAnimeSourceUpdate', '更新检查失败（网络不可达或超时）: $e');
      return 0;
    }
  }

  /// 收集所有番剧源仓库 URL：优先多仓库列表（implicitData['animeSourceRepos']），
  /// 无多仓库配置时回退到旧的 settings['animeSourceListUrl']。
  static List<String> _collectRepoUrls() {
    final raw = appdata.implicitData['animeSourceRepos'];
    if (raw is List && raw.isNotEmpty) {
      return [
        for (final r in raw)
          if (r is Map && (r['url']?.toString() ?? '').isNotEmpty)
            r['url'].toString()
          else if (r is String && r.isNotEmpty)
            r,
      ];
    }
    final legacy = appdata.settings['animeSourceListUrl'];
    return (legacy == null || legacy.isEmpty) ? [] : [legacy];
  }

  /// 拉取仓库 index.json 文本：本地路径（file:// 或无 scheme/盘符）直接读文件，
  /// 远程走 HTTP；默认仓库走 gitMirror。
  static Future<String?> _fetchRepoText(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('file://')) {
      final file = io.File(trimmed.substring('file://'.length));
      return await file.exists() ? await file.readAsString() : null;
    }
    final uri = Uri.tryParse(trimmed);
    // 无 scheme 或 Windows 盘符路径 → 本地文件
    if (uri != null && (!uri.hasScheme || uri.scheme.length == 1)) {
      final file = io.File(trimmed);
      return await file.exists() ? await file.readAsString() : null;
    }
    final dio = AppDio();
    final target =
        (trimmed == Api.kostoriConfig && appdata.settings['gitMirror'])
        ? Api.gitMirror + Api.kostoriConfig
        : trimmed;
    final res = await dio.get<String>(
      target,
      options: Options(
        method: 'GET',
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    if (res.statusCode != 200) return null;
    return res.data;
  }

  static Future<void> update(
    AnimeSource source, [
    bool showLoading = true,
    String? urlOverride,
  ]) async {
    final target = urlOverride ?? source.url;
    if (!target.isURL) {
      if (showLoading) {
        App.rootContext.showMessage(message: t.invalidUrlConfig);
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
        target,
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

  bool _isDragging = false;

  // ── 番源筛选 / 检索 / 排序（持久化） ─────────────────────────
  static const _filterKey = 'anime_source_filter';

  final _searchCtrl = TextEditingController();

  /// 是否番组：all / yes / no
  String _isBangumiFilter = 'all';

  /// 启用状态：all / enabled / disabled
  String _enabledFilter = 'all';

  /// 排序：default / name / id
  String _sort = 'default';

  void _loadFilter() {
    final saved = appdata.implicitData[_filterKey];
    if (saved is Map) {
      _searchCtrl.text = saved['search']?.toString() ?? '';
      _isBangumiFilter = saved['isBangumi']?.toString() ?? 'all';
      _enabledFilter = saved['enabled']?.toString() ?? 'all';
      _sort = saved['sort']?.toString() ?? 'default';
    }
  }

  void _saveFilter() {
    appdata.implicitData[_filterKey] = {
      'search': _searchCtrl.text,
      'isBangumi': _isBangumiFilter,
      'enabled': _enabledFilter,
      'sort': _sort,
    };
    appdata.writeImplicitData();
  }

  void _setFilter(VoidCallback update) {
    update();
    setState(() {});
    _saveFilter();
  }

  /// 按筛选条件过滤 + 排序
  List<AnimeSource> _filteredSources() {
    var list = AnimeSource.allSources();
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.key.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_isBangumiFilter != 'all') {
      final wantBangumi = _isBangumiFilter == 'yes';
      list = list.where((s) => s.isBangumi == wantBangumi).toList();
    }
    if (_enabledFilter != 'all') {
      final wantEnabled = _enabledFilter == 'enabled';
      list = list
          .where((s) => AnimeSourceManager().isEnabled(s.key) == wantEnabled)
          .toList();
    }
    switch (_sort) {
      case 'name':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case 'id':
        list.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    }
    return list;
  }

  void updateUI() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    _loadFilter();
    AnimeSourceManager().addListener(updateUI);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    AnimeSourceManager().removeListener(updateUI);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sources = _filteredSources();
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text(t.animeSource),
          style: AppbarStyle.shadow,
          actions: const [_CheckUpdatesAction()],
        ),
        buildCard(context),
        SliverToBoxAdapter(child: _buildFilterBar(context)),
        // SliverList 惰性构建：只构建视口内的源卡片，
        // 避免进入页面时一次性构建所有源导致首帧卡顿、跳转动画消失
        if (sources.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  t.noMatchingSource,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _SliverAnimeSource(
                key: ValueKey(sources[i].key),
                source: sources[i],
                edit: edit,
                update: update,
                delete: delete,
              ),
              childCount: sources.length,
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
        ),
      ],
    );
  }

  /// 筛选栏：搜索（含源数量）+ 番组/启用分段筛选 + 排序
  Widget _buildFilterBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = _filteredSources().length;
    return Padding(
      // 与源卡片外边界(16+卡片自带4)对齐
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: t.search,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                t.sourceCount(count: count),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterSegmented(
                  value: _isBangumiFilter,
                  options: [
                    ('all', t.filterAll),
                    ('yes', t.bangumi),
                    ('no', t.filterNonBangumi),
                  ],
                  onChanged: (v) => _setFilter(() => _isBangumiFilter = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterSegmented(
                  value: _enabledFilter,
                  options: [
                    ('all', t.filterAll),
                    ('enabled', t.enabled),
                    ('disabled', t.disabled),
                  ],
                  onChanged: (v) => _setFilter(() => _enabledFilter = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: t.sort,
                initialValue: _sort,
                onSelected: (v) => _setFilter(() => _sort = v),
                itemBuilder: (_) => [
                  for (final (key, label) in [
                    ('default', t.sortByDefault),
                    ('name', t.sortByName),
                    ('id', t.sortById),
                  ])
                    PopupMenuItem(
                      value: key,
                      child: Text(
                        label,
                        style: _sort == key
                            ? TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                ],
                icon: Icon(Icons.sort, size: 20),
                iconColor: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ],
      ),
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
    return _BuildSectionPadding(
      DropTarget(
        onDragDone: _onDragDone,
        onDragEntered: (_) {
          if (mounted) setState(() => _isDragging = true);
        },
        onDragExited: (_) {
          if (mounted) setState(() => _isDragging = false);
        },
        child: Stack(
          children: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IconTileButton(
                        icon: const Icon(Icons.extension_outlined),
                        label: t.builderEntry,
                        onTap: () {
                          showPopUpWidget(
                            App.rootContext,
                            const AnimeSourceBuilderPage(),
                          );
                        },
                      ),
                      IconTileButton(
                        icon: const Icon(Icons.list_alt_outlined),
                        label: t.animeSourceList,
                        onTap: () {
                          showPopUpWidget(
                            App.rootContext,
                            _AnimeSourceList(handleAddSource),
                          );
                        },
                      ),
                      IconTileButton(
                        icon: const Icon(Icons.network_check_outlined),
                        label: t.pingTest,
                        onTap: () {
                          showPopUpWidget(App.rootContext, _PingTestPage());
                        },
                      ),
                      IconTileButton(
                        icon: const Icon(Icons.file_open_outlined),
                        label: t.useAConfigFile,
                        onTap: _selectFile,
                      ),
                      IconTileButton(
                        icon: const Icon(Icons.help_outline),
                        label: t.help,
                        onTap: help,
                      ),
                    ],
                  ),
                ),
                _SwitchSetting(title: t.gitMirror, settingKey: "gitMirror"),
                const SizedBox(height: 8),
              ],
            ),
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t.dropFileToImport,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
      SourceLog.error("Add anime source", "$e\n$s");
    }
  }

  /// 拖拽 .js 文件到「添加番剧源」区域即导入
  Future<void> _onDragDone(DropDoneDetails detail) async {
    if (mounted) setState(() => _isDragging = false);
    for (final file in detail.files) {
      final name = file.name.toLowerCase();
      if (!name.endsWith('.js')) continue;
      try {
        final bytes = await File(file.path).readAsBytes();
        final content = utf8.decode(bytes);
        await addSource(content, file.name);
      } catch (e, s) {
        App.rootContext.showMessage(message: e.toString());
        SourceLog.error("Add anime source", "$e\n$s");
      }
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
    App.forceRebuild();
  }
}

/// 紧凑分段选择器（风格同探索页布局切换），用于番剧源筛选：番组/启用。
class _FilterSegmented extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, String)> options;

  const _FilterSegmented({
    required this.value,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: options.map((opt) {
          final (key, label) = opt;
          final selected = value == key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.toOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.toOpacity(0.45),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnimeSourceList extends StatefulWidget {
  const _AnimeSourceList(this.onAdd);

  final Future<void> Function(String) onAdd;

  @override
  State<_AnimeSourceList> createState() => _AnimeSourceListState();
}

class _AnimeSourceListState extends State<_AnimeSourceList> {
  static const _reposKey = 'animeSourceRepos';
  static const _reposCurrentKey = 'animeSourceReposCurrent';

  List<Map<String, dynamic>> _repos = [];
  int _currentRepo = 0;
  bool loading = true;
  List? json;

  bool get _isLocalRepo {
    final url = _currentUrl;
    if (url.startsWith('file://')) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (!uri.hasScheme) return true;
    // Windows 盘符路径 C:\...
    if (uri.scheme.length == 1) return true;
    return false;
  }

  String get _currentUrl =>
      _repos.isEmpty ? '' : (_repos[_currentRepo]['url']?.toString() ?? '');

  void _loadRepos() {
    final raw = appdata.implicitData[_reposKey];
    if (raw is List && raw.isNotEmpty) {
      _repos = raw
          .map(
            (e) => e is Map
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{'url': e.toString()},
          )
          .toList();
    } else {
      _repos = [
        {'url': appdata.settings['animeSourceListUrl'] ?? Api.kostoriConfig},
      ];
    }
    _currentRepo = appdata.implicitData[_reposCurrentKey] as int? ?? 0;
    if (_currentRepo < 0 || _currentRepo >= _repos.length) {
      _currentRepo = 0;
    }
  }

  void _saveRepos() {
    appdata.implicitData[_reposKey] = _repos;
    appdata.implicitData[_reposCurrentKey] = _currentRepo;
    appdata.writeImplicitData();
  }

  Future<void> load() async {
    if (_repos.isEmpty) _loadRepos();
    final url = _currentUrl;
    if (url.trim().isEmpty) {
      setState(() {
        json = [];
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      json = null;
    });
    try {
      String text;
      if (_isLocalRepo) {
        // 本地仓库：直接读 index.json 文件
        final path = url.replaceFirst('file://', '');
        final file = io.File(path);
        if (!await file.exists()) {
          context.showMessage(message: t.error);
          setState(() {
            json = [];
            loading = false;
          });
          return;
        }
        text = await file.readAsString();
      } else {
        var dio = AppDio();
        dynamic res;
        if (url == Api.kostoriConfig && appdata.settings['gitMirror']) {
          res = await dio.get<String>(Api.gitMirror + Api.kostoriConfig);
        } else {
          res = await dio.get<String>(url);
        }
        if (res.statusCode != 200) {
          context.showMessage(message: t.error);
          setState(() {
            json = [];
            loading = false;
          });
          return;
        }
        text = res.data!;
      }
      final decoded = jsonDecode(text);
      setState(() {
        json = decoded is List ? decoded : [];
        loading = false;
      });
    } catch (e) {
      context.showMessage(message: t.error);
      setState(() {
        json = [];
        loading = false;
      });
    }
  }

  void _switchRepo(int index) {
    if (index == _currentRepo) return;
    _currentRepo = index;
    _saveRepos();
    load();
  }

  Future<void> _addRepo() async {
    await showInputDialog(
      context: context,
      title: t.addRepo,
      hintText: t.repoUrlHint,
      onConfirm: (value) {
        final v = value.toString().trim();
        if (v.isEmpty) return t.repoUrlHint;
        setState(() {
          _repos.add({'url': v});
          _currentRepo = _repos.length - 1;
        });
        _saveRepos();
        load();
        return null;
      },
    );
  }

  Future<void> _editRepo(int index) async {
    final current = _repos[index]['url']?.toString() ?? '';
    await showInputDialog(
      context: context,
      title: t.edit,
      hintText: t.repoUrlHint,
      initialValue: current,
      onConfirm: (value) {
        final v = value.toString().trim();
        if (v.isEmpty) return t.repoUrlHint;
        setState(() {
          _repos[index]['url'] = v;
        });
        _saveRepos();
        if (index == _currentRepo) {
          load();
        }
        return null;
      },
    );
    if (mounted) setState(() {});
  }

  void _removeRepo(int index) {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: t.deleteAnimeSourceN(n: _repos[index]['url']?.toString() ?? ''),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        setState(() {
          _repos.removeAt(index);
          if (_currentRepo >= _repos.length) {
            _currentRepo = _repos.isEmpty ? 0 : _repos.length - 1;
          }
        });
        _saveRepos();
        load();
      },
    );
  }

  /// 从仓库下载新版本 JS 并更新已安装的源
  Future<void> _updateFromRepo(AnimeSource source, Map item) async {
    var url = item['url']?.toString();
    if (url == null || !url.isURL) {
      url = source.url;
    }
    await AnimeSourceSettings.update(source, true, url);
    if (mounted) setState(() {});
  }

  /// 拼接仓库项的完整 URL（无独立 url 时按仓库目录 + fileName）
  String _resolveUrl(Map item) {
    final url = item['url']?.toString();
    if (url != null && url.isURL) return url;
    final fileName = item['fileName']?.toString();
    final base = _currentUrl;
    if (fileName == null || fileName.isEmpty) return '';
    if (base
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .contains('/')) {
      return base.substring(0, base.lastIndexOf('/') + 1) + fileName;
    }
    return '$base/$fileName';
  }

  @override
  void initState() {
    super.initState();
    _loadRepos();
    load();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.animeSource,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add_box_outlined),
          tooltip: t.addRepo,
          onPressed: _addRepo,
        ),
      ],
      body: buildBody(),
    );
  }

  Widget buildBody() {
    final currentKey = AnimeSource.allSources().map((e) => e.key).toSet();
    final sourcesMap = {for (final s in AnimeSource.allSources()) s.key: s};
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // ── 仓库管理区 ──────────────────────────────
        _SettingPartTitle(title: t.repo, icon: Icons.folder_open),
        for (var i = 0; i < _repos.length; i++)
          _SettingCard(
            children: [
              // 点击/长按高亮覆盖整张卡片（圆角），而不是只盖住 ListTile 矩形
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _switchRepo(i),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    _isLocalRepo && i == _currentRepo
                        ? Icons.folder
                        : Icons.cloud_outlined,
                    color: i == _currentRepo
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    _repos[i]['name']?.toString() ??
                        _repos[i]['url']?.toString() ??
                        '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: i == _currentRepo
                        ? TextStyle(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          )
                        : null,
                  ),
                  subtitle: Text(
                    _repos[i]['url']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: t.edit,
                        icon: const Icon(Icons.edit_note, size: 18),
                        onPressed: () => _editRepo(i),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        tooltip: t.delete,
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colorScheme.error,
                        ),
                        onPressed: () => _removeRepo(i),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),

        // ── 当前仓库的源列表 ─────────────────────────
        _SettingPartTitle(title: t.animeSource, icon: Icons.source_outlined),
        if (json == null && loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: KostoriRefreshIndicator()),
          )
        else if (json != null && json!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                t.repoEmpty,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else ...[
          for (final item in json!)
            _SettingCard(
              children: [_buildSourceRow(item, currentKey, sourcesMap)],
            ),
        ],
      ],
    );
  }

  Widget _buildSourceRow(
    Map item,
    Set<String> currentKey,
    Map<String, AnimeSource> sourcesMap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final key = item['key']?.toString() ?? '';
    final name = item['name']?.toString() ?? key;
    final version = item['version']?.toString() ?? '';
    final installed = sourcesMap[key];
    final hasUpdate =
        installed != null &&
        version.isNotEmpty &&
        compareSemVer(version, installed.version);
    final url = _resolveUrl(item);

    String description = version;
    final desc = item['description']?.toString();
    if (desc != null && desc.isNotEmpty) description = '$description\n$desc';

    Widget trailing;
    if (installed != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasUpdate)
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: t.update,
              icon: Icon(Icons.update, size: 18, color: colorScheme.primary),
              onPressed: () => _updateFromRepo(installed, item),
            ),
          Icon(Icons.check, size: 20, color: colorScheme.primary),
        ],
      );
    } else {
      trailing = Button.filled(
        child: Text(t.add),
        onPressed: () async {
          if (url.isEmpty) {
            context.showMessage(message: t.error);
            return;
          }
          await widget.onAdd(url);
          if (mounted) setState(() {});
        },
      ).fixHeight(32);
    }

    return ListTile(
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );
  }
}

void _validatePages() {
  final rawMap = appdata.settings.s.explorePagesV2;

  final pagesMap = rawMap.map(
    (k, v) => MapEntry(k, List<String>.from(v as List)),
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
    appdata.settings.update((s) => s.copyWith(explorePagesV2: pagesMap));
  }

  List categoryPages = appdata.settings['categories'];
  var totalCategoryPages = AnimeSource.allSources()
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
  final rawMap = appdata.settings.s.explorePagesV2;
  Map<String, List<String>> pagesMap;

  pagesMap = rawMap.map((k, v) => MapEntry(k, List<String>.from(v as List)));

  if (source.explorePages.isNotEmpty) {
    var existing = pagesMap[source.key] ?? [];
    var existingSet = existing.toSet();
    for (var page in source.explorePages) {
      existingSet.add(page.title);
    }
    pagesMap[source.key] = existingSet.toList();
  }

  appdata.settings.update((s) => s.copyWith(explorePagesV2: pagesMap));

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

class _CheckUpdatesAction extends StatefulWidget {
  const _CheckUpdatesAction();

  @override
  State<_CheckUpdatesAction> createState() => _CheckUpdatesActionState();
}

class _CheckUpdatesActionState extends State<_CheckUpdatesAction> {
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
    return IconButton(
      onPressed: isLoading ? null : check,
      tooltip: t.checkUpdates,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: PolygonRefreshIndicator(),
            )
          : const Icon(Icons.update),
    );
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

  /// 设置该源独立的下载标题格式模板
  Future<void> _setDownloadFormat(AnimeSource source) async {
    final map = Map<String, dynamic>.from(
      appdata.implicitData['downloadTitleFormats'] as Map? ?? {},
    );
    final current = map[source.key] as String? ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _DownloadFormatDialog(initialValue: current),
    );
    if (value == null) return;
    final v = value.trim();
    if (v.isEmpty) {
      map.remove(source.key);
    } else {
      map[source.key] = v;
    }
    appdata.implicitData['downloadTitleFormats'] = map;
    appdata.writeImplicitData();
  }

  @override
  Widget build(BuildContext context) {
    var newVersion = AnimeSourceManager().availableUpdates[source.key];
    bool hasUpdate =
        newVersion != null && compareSemVer(newVersion, source.version);
    final enabled = AnimeSourceManager().isEnabled(source.key);
    final logged = source.isLogged;
    final colorScheme = Theme.of(context).colorScheme;

    // 返回 box（非 sliver）：该卡片由 SliverList 惰性构建
    return Padding(
      // 垂直间距尽量小，减少番源卡片之间的空隙
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: _SettingCard(
        children: [
          // 标题行：源名 + 版本（右侧更新图标）+ 右侧删除/开关
          ListTile(
            title: Text(source.name, style: ts.s18),
            subtitle: Row(
              children: [
                Text('v${source.version}'),
                const SizedBox(width: 2),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: t.update,
                  icon: const Icon(Icons.update, size: 18),
                  onPressed: () => widget.update(source),
                ),
                if (hasUpdate) ...[
                  const SizedBox(width: 2),
                  Tooltip(
                    message: newVersion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t.newVersion,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: t.delete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  onPressed: () => widget.delete(source),
                ),
                const SizedBox(width: 4),
                CustomSwitch(
                  value: enabled,
                  onChanged: (v) {
                    AnimeSourceManager().toggleSource(source.key, v);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // 版本行与操作按钮之间的分隔线
          const Divider(height: 1, indent: 16, endIndent: 16),

          // 底部按钮（Wrap 流式排列，按需显示）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (source.account != null)
                  IconTileButton(
                    icon: logged
                        ? const Icon(Icons.person_outline)
                        : const Icon(Icons.person_add_alt_outlined),
                    label: logged ? t.account : t.logIn,
                    onTap: () {
                      showPopUpWidget(
                        context,
                        _AnimeSourceDetailPage(
                          source: source,
                          initialTab: _DetailTab.account,
                        ),
                      );
                    },
                  ),
                if (source.settings != null && source.settings!.isNotEmpty)
                  IconTileButton(
                    icon: const Icon(Icons.settings_outlined),
                    label: t.settings,
                    onTap: () {
                      showPopUpWidget(
                        context,
                        _AnimeSourceDetailPage(
                          source: source,
                          initialTab: _DetailTab.settings,
                        ),
                      );
                    },
                  ),
                IconTileButton(
                  icon: const Icon(Icons.edit_note),
                  label: t.edit,
                  onTap: () => widget.edit(source),
                ),
                IconTileButton(
                  icon: const Icon(Icons.title),
                  label: t.downloadTitleFormat,
                  onTap: () => _setDownloadFormat(source),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 下载标题格式编辑弹窗：输入框 + 下方提示 + 快捷占位符按钮。
class _DownloadFormatDialog extends StatefulWidget {
  const _DownloadFormatDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_DownloadFormatDialog> createState() => _DownloadFormatDialogState();
}

class _DownloadFormatDialogState extends State<_DownloadFormatDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focus = FocusNode();

  static const _placeholders = [
    '{title}',
    '{episode}',
    '{author}',
    '{resolution}',
    '{source}',
    '{year}',
  ];

  /// 在光标位置插入占位符
  void _insert(String ph) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(start, end, ph),
      selection: TextSelection.collapsed(offset: start + ph.length),
    );
    _focus.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ContentDialog(
      title: t.downloadTitleFormat,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ).paddingHorizontal(12),
          // 占位符说明放在输入框下方，避免一输入就看不见
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              t.downloadFormatHint,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // 快捷占位符按钮：点击插入到光标处
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ph in _placeholders)
                  ActionChip(
                    label: Text(ph, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _insert(ph),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Button.filled(
          onPressed: () => context.pop(_ctrl.text.trim()),
          child: Text(t.confirm),
        ),
      ],
    );
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
    for (final source in AnimeSource.allSources()) {
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
    final saved = appdata.implicitData['pingCustomEndpoints'];
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
      appdata.implicitData['pingCustomEndpoints'] = customControllers
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList();
      appdata.writeImplicitData();
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
                        tooltip: t.addAddress,
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
                    onTap: () {
                      // 点卡片即测试；未启用时先自动启用
                      if (!_enabledEndpoints.contains(endpoint)) {
                        _enabledEndpoints.add(endpoint);
                      }
                      _runTest(endpoint, endpoint);
                    },
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
              onTap: endpoint != null
                  ? () {
                      // 点卡片即测试；未启用时先自动启用
                      if (!_enabledEndpoints.contains(endpoint)) {
                        _enabledEndpoints.add(endpoint);
                      }
                      _runTest(e['name']!, endpoint);
                    }
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
    final cs = Theme.of(context).colorScheme;
    Widget statusWidget;

    if (!enabled || endpoint == null || endpoint!.isEmpty) {
      statusWidget = const SizedBox.shrink();
    } else {
      switch (result?.status) {
        case _PingStatus.testing:
          statusWidget = const SizedBox(
            width: 20,
            height: 20,
            child: PolygonRefreshIndicator(),
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
          statusWidget = Icon(
            Icons.play_arrow_rounded,
            size: 22,
            color: cs.primary,
          );
      }
    }

    // 卡片布局：整卡点击测试（大热区），右上角开关独立控制启用
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (endpoint != null && endpoint!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          endpoint!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                statusWidget,
                const SizedBox(width: 4),
                CustomSwitch(value: enabled, onChanged: (_) => onToggle()),
                if (onDelete != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 18, color: cs.outline),
                    tooltip: t.delete,
                    onPressed: onDelete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 源详情二级页（账号 / 设置） ────────────────────────────────────────────

enum _DetailTab { account, settings }

class _AnimeSourceDetailPage extends StatefulWidget {
  final AnimeSource source;
  final _DetailTab initialTab;

  const _AnimeSourceDetailPage({
    required this.source,
    this.initialTab = _DetailTab.account,
  });

  @override
  State<_AnimeSourceDetailPage> createState() => _AnimeSourceDetailPageState();
}

class _AnimeSourceDetailPageState extends State<_AnimeSourceDetailPage> {
  AnimeSource get source => widget.source;

  final _reLogin = <String, bool>{};

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
            trailing: CustomSwitch(
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
            subtitle: Text(current, maxLines: null),
            isThreeLine: current.length > 40,
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                showInputDialog(
                  context: context,
                  title: (item.value['title'] as String).ts(source.key),
                  initialValue: current,
                  minLines: 2,
                  maxLines: 6,
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
                  child: PolygonRefreshIndicator(),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAccount = widget.initialTab == _DetailTab.account;
    final children = (isAccount ? _buildAccount() : buildSourceSettings())
        .toList();
    return PopUpWidgetScaffold(
      title: source.name,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: cs.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant, width: 0.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: children.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            t.noData,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ]
                  : children
                        .map(
                          (tile) =>
                              Material(color: Colors.transparent, child: tile),
                        )
                        .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
