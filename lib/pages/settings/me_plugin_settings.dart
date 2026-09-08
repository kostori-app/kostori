part of 'settings_page.dart';

/// 个人页插件管理卡片：列出已加载插件，支持重新加载与删除。
class PluginSettings extends StatefulWidget {
  const PluginSettings({super.key});

  @override
  State<PluginSettings> createState() => _PluginSettingsState();
}

class _PluginSettingsState extends State<PluginSettings> {
  late final TextEditingController _urlCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _dragOver = false;
  String _search = '';
  String _loginFilter = 'all';
  String _enabledFilter = 'all';
  String _sort = 'default';

  List<MePagePlugin> _visible(List<MePagePlugin> all) {
    final manager = MePagePluginManager();
    var list = all.where((p) {
      if (_enabledFilter == 'enabled' && !manager.isEnabled(p.key)) {
        return false;
      }
      if (_enabledFilter == 'disabled' && manager.isEnabled(p.key)) {
        return false;
      }
      if (_loginFilter == 'logged' && !p.isLogged) return false;
      if (_loginFilter == 'notLogged' &&
          (!p.hasLogin || p.isLogged)) {
        return false;
      }
      if (_search.trim().isEmpty) return true;
      final q = _search.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          p.key.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q);
    }).toList();
    if (_sort == 'name') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sort == 'id') {
      list.sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    }
    return list;
  }
  /// 从 .js 直链添加单个插件（与番剧源“添加源”一致）
  Future<void> _addPluginByUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    String fileName = trimmed.split('/').last.split('?').first;
    if (!fileName.toLowerCase().endsWith('.js')) {
      App.rootContext.showMessage(
        message: t.mustBeJs,
        level: LogLevel.warning,
      );
      return;
    }
    try {
      final res = await AppDio().get<String>(
        trimmed,
        options: Options(
          method: 'GET',
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if (res.statusCode != 200) {
        App.rootContext.showMessage(
          message: 'HTTP ${res.statusCode}',
          level: LogLevel.error,
        );
        return;
      }
      final dir = io.Directory('${App.dataPath}/$mePluginsDirName');
      if (!await dir.exists()) {
        await dir.create();
      }
      final safe = fileName.split('/').last;
      if (!RegExp(r'^[A-Za-z0-9_\-]+\.js$').hasMatch(safe)) return;
      await io.File('${dir.path}/$safe').writeAsString(res.data ?? '');
      await MePagePluginManager().reload();
      if (mounted) setState(() {});
      App.rootContext.showMessage(message: '${t.imported}: $safe');
    } catch (e) {
      App.rootContext.showMessage(
        message: e.toString(),
        level: LogLevel.error,
      );
    }
  }

  Future<void> _installFromFile(io.File file) async {
    final name = file.uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.js')) return;
    final dir = io.Directory('${App.dataPath}/$mePluginsDirName');
    if (!await dir.exists()) {
      await dir.create();
    }
    final safe = name.split('/').last;
    if (!RegExp(r'^[A-Za-z0-9_\-]+\.js$').hasMatch(safe)) return;
    try {
      await io.File(file.path).copy('${dir.path}/$safe');
      await MePagePluginManager().reload();
      if (mounted) setState(() {});
      App.rootContext.showMessage(message: '${t.imported}: $safe');
    } catch (e) {
      App.rootContext.showMessage(
        message: e.toString(),
        level: LogLevel.error,
      );
    }
  }

  Future<void> _onDrop(DropDoneDetails detail) async {
    for (final file in detail.files) {
      if (!file.name.toLowerCase().endsWith('.js')) continue;
      final path = file.path;
      if (path.isEmpty) continue;
      await _installFromFile(io.File(path));
    }
  }

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    MePagePluginManager().ensureInit();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await MePagePluginManager().reload();
    if (mounted) setState(() {});
    App.rootContext.showMessage(message: t.loadSuccess);
  }

  Future<void> _delete(MePagePlugin p) async {
    try {
      await io.File(p.filePath).delete();
    } catch (_) {}
    await MePagePluginManager().reload();
    if (mounted) setState(() {});
  }

  Future<void> _openDir() async {
    final path = '${App.dataPath}/$mePluginsDirName';
    try {
      if (io.Platform.isWindows) {
        await io.Process.run('explorer', [path]);
      } else if (io.Platform.isMacOS) {
        await io.Process.run('open', [path]);
      } else if (io.Platform.isLinux) {
        await io.Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  Future<void> _create() async {
    await showInputDialog(
      context: context,
      title: t.createPlugin,
      hintText: 'my_plugin',
      inputValidator: RegExp(r'^[A-Za-z0-9_\-]+$'),
      onConfirm: (value) async {
        final name = value.trim();
        if (name.isEmpty) return t.pluginName;
        final dir = io.Directory('${App.dataPath}/$mePluginsDirName');
        if (!await dir.exists()) {
          await dir.create();
        }
        final file = io.File('${dir.path}/$name.js');
        if (await file.exists()) {
          return '${t.pluginName} ($name) ${t.alreadyExists}';
        }
        await file.writeAsString(_pluginTemplate(name));
        await MePagePluginManager().reload();
        if (mounted) setState(() {});
        return null;
      },
    );
  }

  static String _pluginTemplate(String name) =>
      '''
/**
 * 个人页插件：$name
 *
 * 支持模块类型：card / text / keyValue / link / progress / chips / signIn / button / list / form
 * 支持插件导航：plugin.nav + plugin.page(name, params)
 */
const plugin = {
  name: '$name',
  version: '1.0.0',
  description: '',
  async render() {
    return [
      { type: 'card', title: '标题', children: [
        { type: 'text', text: '内容' },
      ]},
    ];
  },
};
''';

  @override
  Widget build(BuildContext context) {
    final plugins = MePagePluginManager().all();
    final visible = _visible(plugins);
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text(t.mePagePlugin),
          style: AppbarStyle.shadow,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: t.reload,
              onPressed: _reload,
            ),
          ],
        ),
        // 操作卡片：插件源 URL（对齐番源"添加番剧源"组件），整卡可拖入 .js 安装
        _BuildSectionPadding(
          DropTarget(
            onDragDone: _onDrop,
            onDragEntered: (_) {
              if (mounted) setState(() => _dragOver = true);
            },
            onDragExited: (_) {
              if (mounted) setState(() => _dragOver = false);
            },
            child: Stack(
              children: [
                _SettingCard(
            children: [
              _SettingPartTitle(
                title: t.pluginSourceUrl,
                icon: Icons.widgets_outlined,
              ),
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://example.com/plugin.js',
                  border: const UnderlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  suffix: IconButton(
                    tooltip: t.add,
                    onPressed: () => _addPluginByUrl(_urlCtrl.text),
                    icon: const Icon(Icons.add),
                  ),
                ),
                onSubmitted: (_) => _addPluginByUrl(_urlCtrl.text),
              ).paddingHorizontal(16).paddingBottom(8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconTileButton(
                      icon: const Icon(Icons.list_alt_outlined),
                      label: t.pluginSourceList,
                      onTap: () {
                        showPopUpWidget(
                          App.rootContext,
                          const _PluginSourceList(),
                        );
                      },
                    ),
                    // 打开目录仅桌面端有意义（移动端无桌面文件管理器）
                    if (App.isDesktop)
                      IconTileButton(
                        icon: const Icon(Icons.folder_open),
                        label: t.openDir,
                        onTap: _openDir,
                      ),
                    IconTileButton(
                      icon: const Icon(Icons.add),
                      label: t.createPlugin,
                      onTap: _create,
                    ),
                  ],
                ),
              ),
            ],
            ),
            if (_dragOver)
              Positioned.fill(
                child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.file_download_outlined,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  t.dropJsPluginHint,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 筛选条：与番剧源设置页一致（搜索 + 登录/启用分段 + 排序）
        SliverToBoxAdapter(
          child: Padding(
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
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _search = '');
                                  },
                                ),
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
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
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      t.sourceCount(count: visible.length),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PluginFilterSegmented(
                        value: _loginFilter,
                        options: [
                          ('all', t.filterAll),
                          ('logged', t.filterLogged),
                          ('notLogged', t.filterNotLogged),
                        ],
                        onChanged: (v) => setState(() => _loginFilter = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PluginFilterSegmented(
                        value: _enabledFilter,
                        options: [
                          ('all', t.filterAll),
                          ('enabled', t.enabled),
                          ('disabled', t.disabled),
                        ],
                        onChanged: (v) => setState(() => _enabledFilter = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: t.sort,
                      initialValue: _sort,
                      onSelected: (v) => setState(() => _sort = v),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                      icon: const Icon(Icons.sort, size: 20),
                      iconColor: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 每个插件一个卡片（对齐番源卡片风格）
        if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.noMePagePlugin,
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
              (context, i) {
                final p = visible[i];
                final manager = MePagePluginManager();
                return _PluginSliverCard(
                  key: ValueKey(p.key),
                  plugin: p,
                  enabled: manager.isEnabled(p.key),
                  onToggle: (v) {
                    manager.setEnabled(p.key, v);
                    if (mounted) setState(() {});
                  },
                  account: p.hasLogin
                      ? () async {
                          await showPopUpWidget(
                            App.rootContext,
                            _PluginAccountPage(plugin: p),
                          );
                          if (mounted) setState(() {});
                        }
                      : null,
                  settings: p.hasSettings
                      ? () async {
                          await showPopUpWidget(
                            App.rootContext,
                            _PluginSettingsPage(plugin: p),
                          );
                          if (mounted) setState(() {});
                        }
                      : null,
                  edit: _edit,
                  delete: _delete,
                );
              },
              childCount: visible.length,
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
        ),
      ],
    );
  }

  Future<void> _edit(MePagePlugin p) async {
    if (App.isDesktop) {
      try {
        await io.Process.run("code", [p.filePath], runInShell: true);
        return;
      } catch (_) {}
    }
    context.to(
      () => _EditFilePage(p.filePath, () async {
        await MePagePluginManager().reload();
        if (mounted) setState(() {});
      }),
    );
  }
}

/// 单个插件卡片：与番剧源设置页列表卡片同构（无内置/开关语义）
/// 单个插件卡片：与番剧源设置页列表卡片同构（启用开关 + 账户/编辑 底部按钮区）
class _PluginSliverCard extends StatelessWidget {
  const _PluginSliverCard({
    super.key,
    required this.plugin,
    required this.enabled,
    required this.onToggle,
    required this.edit,
    required this.delete,
    this.account,
    this.settings,
  });

  final MePagePlugin plugin;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Future<void> Function(MePagePlugin) edit;
  final Future<void> Function(MePagePlugin) delete;

  /// 点击“账户/登录”按钮（进入二级账户页）
  final VoidCallback? account;

  /// 点击“设置”按钮（进入插件设置页，如手动 uid 等配置）
  final VoidCallback? settings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logged = plugin.isLogged;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: _SettingCard(
        children: [
          ListTile(
            title: Text(plugin.name, style: ts.s18),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('v${plugin.version}'),
                if (plugin.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      plugin.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                  onPressed: () => delete(plugin),
                ),
                const SizedBox(width: 4),
                CustomSwitch(value: enabled, onChanged: onToggle),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // 底部操作（与番剧源卡片一致：账户/编辑等 IconTileButton）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (account != null)
                  IconTileButton(
                    icon: Icon(
                      logged
                          ? Icons.person_outline
                          : Icons.person_add_alt_outlined,
                    ),
                    label: logged ? t.account : t.logIn,
                    onTap: account,
                  ),
                if (settings != null)
                  IconTileButton(
                    icon: const Icon(Icons.settings_outlined),
                    label: t.settings,
                    onTap: settings,
                  ),
                IconTileButton(
                  icon: const Icon(Icons.edit_note),
                  label: t.edit,
                  onTap: () => edit(plugin),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
/// 安装单个插件 JS（供源列表页使用）
Future<void> _installPluginUrl(String url) async {
  final trimmed = url.trim();
  final name = trimmed.split('/').last.split('?').first;
  final dir = io.Directory('${App.dataPath}/$mePluginsDirName');
  if (!await dir.exists()) await dir.create();
  final safe = name.split('/').last;
  if (!RegExp(r'^[A-Za-z0-9_\-]+\.js$').hasMatch(safe)) return;
  final res = await AppDio().get<String>(
    trimmed,
    options: Options(
      method: 'GET',
      responseType: ResponseType.plain,
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}');
  }
  await io.File('${dir.path}/$safe').writeAsString(res.data ?? '');
  await MePagePluginManager().reload();
}

/// 插件源列表：与番剧源列表同构（仓库管理 + 仓库内插件行），无内置源。
class _PluginSourceList extends StatefulWidget {
  const _PluginSourceList();

  @override
  State<_PluginSourceList> createState() => _PluginSourceListState();
}

class _PluginSourceListState extends State<_PluginSourceList> {
  static const _reposKey = 'pluginRepos';
  static const _reposCurrentKey = 'pluginReposCurrent';

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
      _repos = [];
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
    _loadRepos();
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
        final path = url.replaceFirst('file://', '');
        final file = io.File(path);
        if (!await file.exists()) {
          text = '';
        } else {
          text = await file.readAsString();
        }
      } else {
        final res = await AppDio().get<String>(url);
        if (res.statusCode != 200) {
          text = '';
        } else {
          text = res.data ?? '';
        }
      }
      final decoded = jsonDecode(text);
      setState(() {
        json = decoded is List ? decoded : [];
        loading = false;
      });
    } catch (_) {
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
        if (index == _currentRepo) load();
        return null;
      },
    );
    if (mounted) setState(() {});
  }

  void _removeRepo(int index) {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: _repos[index]['url']?.toString() ?? '',
      btnColor: Theme.of(context).colorScheme.error,
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

  /// 仓库项 → 完整 js URL（无独立 url 时用仓库目录 + fileName）
  String _resolveUrl(Map item) {
    final url = item['url']?.toString();
    if (url != null && url.isNotEmpty) return url;
    final fileName = item['fileName']?.toString() ?? item['key']?.toString() ?? '';
    if (fileName.isEmpty) return '';
    final base = _currentUrl;
    final clean = base.replaceFirst('https://', '').replaceFirst('http://', '');
    if (clean.contains('/')) {
      return base.substring(0, base.lastIndexOf('/') + 1) + fileName;
    }
    if (!fileName.endsWith('.js')) return '';
    return base.endsWith('/') ? '$base$fileName' : '$base/$fileName';
  }

  @override
  void initState() {
    super.initState();
    _loadRepos();
    load();
  }

  Widget _buildRow(Map item, Set<String> installedKeys) {
    final colorScheme = Theme.of(context).colorScheme;
    final key = item['key']?.toString() ?? '';
    final name = item['name']?.toString() ?? key;
    final version = item['version']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';
    String description = version;
    if (desc.isNotEmpty) description = '$version\n$desc';
    final installed = installedKeys.contains(key);
    final url = _resolveUrl(item);

    Widget trailing;
    if (installed) {
      trailing = Icon(Icons.check, size: 20, color: colorScheme.primary);
    } else {
      trailing = Button.filled(
        child: Text(t.add),
        onPressed: () async {
          if (url.isEmpty) {
            App.rootContext.showMessage(message: t.error);
            return;
          }
          try {
            await _installPluginUrl(url);
            if (mounted) setState(() {});
          } catch (e) {
            App.rootContext.showMessage(
              message: e.toString(),
              level: LogLevel.error,
            );
          }
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

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.pluginSourceList,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add_box_outlined),
          tooltip: t.addRepo,
          onPressed: _addRepo,
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _SettingPartTitle(title: t.repo, icon: Icons.folder_open),
          if (_repos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t.pluginRepoEmpty,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < _repos.length; i++)
              _SettingCard(
                children: [
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
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        _repos[i]['url']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: i == _currentRepo
                            ? TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        _repos[i]['name']?.toString() ?? '',
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
                              color: Theme.of(context).colorScheme.error,
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
          _SettingPartTitle(title: t.pluginSourceList, icon: Icons.source_outlined),
          if (loading)
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
          else if (json != null)
            for (final item in json!)
              _SettingCard(
                children: [
                  _buildRow(
                    item is Map
                        ? Map<String, dynamic>.from(item)
                        : <String, dynamic>{},
                    MePagePluginManager().all().map((p) => p.key).toSet(),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// 插件设置页：渲染插件声明的 `settings` 模块（config 输入等，存插件 .data）
class _PluginSettingsPage extends StatefulWidget {
  final MePagePlugin plugin;

  const _PluginSettingsPage({required this.plugin});

  @override
  State<_PluginSettingsPage> createState() => _PluginSettingsPageState();
}

class _PluginSettingsPageState extends State<_PluginSettingsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  MePagePlugin get p => widget.plugin;

  @override
  void initState() {
    super.initState();
    _future = p.settingsModules();
    // 账号登录/饼干列表写入数据后，各设置卡片即时重建显示
    MePagePluginManager().addListener(_onPluginsChanged);
  }

  @override
  void dispose() {
    MePagePluginManager().removeListener(_onPluginsChanged);
    super.dispose();
  }

  void _onPluginsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: p.name,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: PolygonRefreshIndicator());
          }
          final modules = snap.data ?? const [];
          if (modules.isEmpty) {
            return Center(
              child: Text(t.noData),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in modules) ...[
                _PluginSettingsModule(plugin: p, m: m),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 单个设置模块：目前支持 config（输入项持久化）与 text/说明
class _PluginSettingsModule extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginSettingsModule({required this.plugin, required this.m});

  @override
  Widget build(BuildContext context) {
    final type = m['type']?.toString() ?? '';
    if (type == 'config') {
      return _SettingCard(
        children: [
          if (m['title']?.toString().isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                m['title'].toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PluginConfigEditor(plugin: plugin, m: m),
          ),
        ],
      );
    }
    if (type == 'cookie') {
      return _SettingCard(
        children: [
          if (m['title']?.toString().isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                m['title'].toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PluginCookieEditor(plugin: plugin, m: m),
          ),
        ],
      );
    }
    if (type == 'cookies') {
      return _SettingCard(
        children: [
          if (m['title']?.toString().isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                m['title'].toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PluginCookiesEditor(plugin: plugin, m: m),
          ),
        ],
      );
    }
    if (type == 'account') {
      return _SettingCard(
        children: [
          if (m['title']?.toString().isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                m['title'].toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PluginAccountEditor(plugin: plugin, m: m),
          ),
        ],
      );
    }
    if (type == 'text') {
      return _SettingCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(m['text']?.toString() ?? ''),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// 解析用户粘贴/扫码的饼干内容为纯 userhash：
/// 裸 userhash / userhash=xxx / {"cookie":"…","name":"…"} / {"userhash":…}
String? _normalizeCookieUserhash(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      final map = decoded.map((k, v) => MapEntry('$k', v));
      final hash =
          map['cookie']?.toString() ??
          map['userhash']?.toString() ??
          map['user_hash']?.toString();
      if (hash != null) text = hash.trim();
    }
  } catch (_) {}
  if (text.startsWith('userhash=')) {
    text = text.substring('userhash='.length).trim();
  } else if (text.startsWith('userhash:')) {
    text = text.substring('userhash:'.length).trim();
  }
  if (text.length >= 2 &&
      ((text.startsWith('"') && text.endsWith('"')) ||
          (text.startsWith("'") && text.endsWith("'")))) {
    text = text.substring(1, text.length - 1);
  }
  if (!RegExp(r'^[0-9A-Za-z_-]{4,64}$').hasMatch(text)) return null;
  return text;
}

/// 通用账号登录模块：插件 JS 通过声明 methods 提供会话/验证码/同步能力。
/// 登录成功后自动同步插件返回的饼干列表进通用 cookies 存储。
class _PluginAccountEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginAccountEditor({required this.plugin, required this.m});

  @override
  State<_PluginAccountEditor> createState() => _PluginAccountEditorState();
}

class _PluginAccountEditorState extends State<_PluginAccountEditor> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _verifyCtrl = TextEditingController();
  Timer? _captchaTimeout;
  Timer? _credsTimer;
  bool _busy = false;
  bool _captchaBusy = false;
  bool _logged = false;
  String _email = '';
  String? _captchaData; // 插件返回的 base64 验证码图
  String? _error;

  String _method(String k) {
    final raw = widget.m['methods'];
    if (raw is Map) {
      final v = raw[k];
      if (v != null) return v.toString();
    }
    return '';
  }

  String _txt(String k, String fallback) {
    final raw = widget.m['texts'];
    if (raw is Map) {
      final v = raw[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return fallback;
  }

  String get _listKey => widget.m['listKey']?.toString() ?? 'cookies';

  String get _activeKey => widget.m['activeKey']?.toString() ?? 'activeCookie';

  String get _configKey => widget.m['configKey']?.toString() ?? 'userhash';

  int? _activeIndexOf(List<Map<String, dynamic>> list) {
    final v = widget.plugin.dataValue(_activeKey);
    final idx = v is num
        ? v.toInt()
        : (v is String ? int.tryParse(v) : null);
    if (idx == null || idx < 0 || idx >= list.length) return null;
    return idx;
  }

  @override
  void initState() {
    super.initState();
    // 回填已持久化的账号密码（保存在本插件的 creds）
    final creds = MePagePluginManager().credsOf(widget.plugin.key);
    if (creds != null) {
      _emailCtrl.text = creds['username']?.toString() ?? '';
      _passCtrl.text = creds['password']?.toString() ?? '';
    }
    // 输入即持久化（不需要等登录成功），下次打开自动回填
    _emailCtrl.addListener(_schedulePersistCreds);
    _passCtrl.addListener(_schedulePersistCreds);
    _refreshStatus();
  }

  void _schedulePersistCreds() {
    _credsTimer?.cancel();
    _credsTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      await MePagePluginManager().setCreds(
        widget.plugin.key,
        username: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    });
  }

  @override
  void dispose() {
    _captchaTimeout?.cancel();
    _credsTimer?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _verifyCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_method('status').isEmpty) return;
    final res = await widget.plugin.invoke(_method('status'));
    if (!mounted) return;
    final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
    final logged = m?['logged'] == true;
    setState(() {
      _logged = logged;
      _email = m?['email']?.toString() ?? '';
      _error = null;
    });
    if (!logged) await _refreshCaptcha();
  }

  Future<void> _refreshCaptcha() async {
    if (_method('captcha').isEmpty) return;
    if (_captchaBusy) {
      App.rootContext.showMessage(message: '正在刷新验证码…');
      return;
    }
    setState(() {
      _captchaData = null;
      _captchaBusy = true;
      _error = null;
    });
    _captchaTimeout?.cancel();
    _captchaTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      setState(() {
        _captchaBusy = false;
        _error = t.invalidCookieHash;
      });
    });
    try {
      final res = await widget.plugin.invoke(_method('captcha'));
      if (!mounted) return;
      final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
      final data = m?['data']?.toString() ?? '';
      if (data.isEmpty) {
        setState(() {
          _error =
              m?['error']?.toString().isNotEmpty == true
                  ? m!['error'].toString()
                  : t.invalidCookieHash;
        });
        return;
      }
      setState(() => _captchaData = data);
    } finally {
      _captchaTimeout?.cancel();
      _captchaTimeout = null;
      if (mounted) setState(() => _captchaBusy = false);
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final verify = _verifyCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = t.cannotBeEmpty);
      return;
    }
    if (verify.isEmpty || _captchaData == null) {
      setState(() => _error = t.cookieNameRequired);
      return;
    }
    if (_method('login').isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.plugin
        .invoke(_method('login'), [email, password, verify]);
    if (!mounted) return;
    final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
    setState(() => _busy = false);
    if (m?['ok'] == true) {
      _logged = true;
      _email = m?['email']?.toString() ?? email;
      // 登录成功：持久化账号密码，重启后回填
      await MePagePluginManager().setCreds(
        widget.plugin.key,
        username: email,
        password: password,
      );
      _verifyCtrl.clear();
      setState(() {});
      await _sync();
    } else {
      setState(() {
        _error =
            m?['message']?.toString().isNotEmpty == true
                ? m!['message'].toString()
                : t.loginFailed;
      });
      await _refreshCaptcha();
    }
  }

  Future<void> _sync() async {
    if (_method('sync').isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.plugin.invoke(_method('sync'));
    if (!mounted) return;
    final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
    setState(() => _busy = false);
    if (m == null || m['items'] is! List) {
      if (mounted) {
        setState(() {
          _error =
              m?['error']?.toString().isNotEmpty == true
                  ? m!['error'].toString()
                  : t.noData;
        });
      }
      return;
    }
    final rawItems = m['items'] as List;
    final incoming = <Map<String, dynamic>>[];
    for (final e in rawItems) {
      if (e is Map) {
        final em = e.map((k, v) => MapEntry('$k', v));
        final hash = _normalizeCookieUserhash(em['userhash']?.toString() ?? '');
        if (hash == null) continue;
        incoming.add({
          'name': (em['name']?.toString().trim() ?? '').isEmpty
              ? '饼干'
              : em['name'].toString(),
          'userhash': hash,
          if ((em['note']?.toString().trim() ?? '').isNotEmpty)
            'note': em['note'].toString(),
        });
      }
    }
    _merge(incoming);
    if (incoming.isEmpty) {
      App.rootContext.showMessage(
        message: _txt('noCookies', '账号下没有可同步的饼干'),
        level: LogLevel.warning,
      );
      return;
    }
    App.rootContext.showMessage(message: t.cookieImported);
  }

  void _merge(List<Map<String, dynamic>> incoming) {
    final current = widget.plugin.dataValue(_listKey);
    final list = <Map<String, dynamic>>[];
    if (current is List) {
      for (final e in current) {
        if (e is Map) {
          final m = e.map((k, v) => MapEntry(k.toString(), v));
          if ((m['userhash']?.toString() ?? '').isNotEmpty) list.add(m);
        }
      }
    }
    String? oldActive;
    final oldIdx = _activeIndexOf(list);
    if (oldIdx != null && oldIdx < list.length) {
      oldActive = list[oldIdx]['userhash']?.toString();
    }
    for (final item in incoming) {
      final idx = list.indexWhere(
        (e) => e['userhash'] == item['userhash'],
      );
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }
    }
    var active = oldActive != null
        ? list.indexWhere((e) => e['userhash'] == oldActive)
        : (list.isNotEmpty ? 0 : -1);
    if (active < 0 && incoming.isNotEmpty) {
      active = list.indexWhere((e) => e['userhash'] == incoming.first['userhash']);
    }
    widget.plugin.setDataValue(_listKey, list);
    widget.plugin.setDataValue(
      _activeKey,
      active >= 0 && active < list.length ? active : null,
    );
    if (active >= 0 && active < list.length) {
      widget.plugin.setConfigValue(_configKey, list[active]['userhash']!.toString());
    } else {
      widget.plugin.setConfigValue(_configKey, '');
    }
    MePagePluginManager().touch();
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    if (_method('logout').isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await widget.plugin.invoke(_method('logout'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = false;
      _verifyCtrl.clear();
    });
    await _refreshCaptcha();
  }

  Uint8List? _captchaBytes() {
    final data = _captchaData;
    if (data == null) return null;
    try {
      return base64Decode(data.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_logged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _txt('loggedIn', _email.isEmpty ? t.loggedIn : _email),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconTileButton(
                icon: const Icon(Icons.sync),
                label: _txt('sync', '同步账号饼干'),
                onTap: _sync,
              ),
              IconTileButton(
                icon: const Icon(Icons.logout),
                label: _txt('logout', t.logOut),
                onTap: _logout,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ),
        ],
      );
    }
    final bytes = _captchaBytes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: _txt('email', t.username),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _txt('password', t.password),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _verifyCtrl,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: _txt('verify', 'Verify code'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        // 验证码单独一大块展示，方便辨认；点图即可刷新/重试
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: _txt('captchaTip', '看不清？点击刷新验证码'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _refreshCaptcha,
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: bytes != null
                    ? ColoredBox(
                        color: cs.surfaceContainerHigh,
                        child: Image.memory(
                          bytes,
                          key: ValueKey(_captchaData),
                          fit: BoxFit.contain,
                          gaplessPlayback: false,
                          errorBuilder: (_, _, _) => _captchaFallback(cs),
                        ),
                      )
                    : _captchaFallback(cs),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _refreshCaptcha,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(_txt('captchaRefresh', '刷新验证码')),
          ),
        ),
        const SizedBox(height: 4),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(fontSize: 12, color: cs.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _busy ? null : _login,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: PolygonRefreshIndicator(),
                )
              : const Icon(Icons.login),
          label: Text(_txt('login', t.logIn)),
        ),
      ],
    );
  }

  Widget _captchaFallback(ColorScheme cs) {
    return Container(
      width: double.infinity,
      height: 120,
      color: cs.surfaceContainerHigh,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_captchaBusy)
            const SizedBox.square(
              dimension: 18,
              child: PolygonRefreshIndicator(),
            )
          else ...[
            Icon(Icons.refresh, size: 24, color: cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              _txt('captchaTipShort', '点击重试'),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// 多饼干管理器（对齐 xdnmb-main 饼干页：列表 + 增删 + 选中浏览用）
class _PluginCookiesEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginCookiesEditor({required this.plugin, required this.m});

  @override
  State<_PluginCookiesEditor> createState() => _PluginCookiesEditorState();
}

class _PluginCookiesEditorState extends State<_PluginCookiesEditor> {
  @override
  void initState() {
    super.initState();
    // 旧版单饼干配置 → 迁移进列表（仅首次且列表为空时）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final legacy = widget.plugin.configs[_configKey]?.toString() ?? '';
      if (legacy.isNotEmpty && _list().isEmpty) {
        _addEntry(name: _txt('legacy', '饼干'), hash: legacy);
      }
    });
  }

  String get _listKey => widget.m['key']?.toString() ?? 'cookies';

  String get _activeKey => widget.m['activeKey']?.toString() ?? 'activeCookie';

  String get _configKey => widget.m['configKey']?.toString() ?? 'userhash';

  String _txt(String k, String fallback) {
    final raw = widget.m['texts'];
    if (raw is Map) {
      final v = raw[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return fallback;
  }

  List<Map<String, dynamic>> _list() {
    final raw = widget.plugin.dataValue(_listKey);
    final out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final m = e.map((k, v) => MapEntry(k.toString(), v));
          if ((m['userhash']?.toString() ?? '').isNotEmpty) out.add(m);
        }
      }
    }
    return out;
  }

  int? _active() {
    final v = widget.plugin.dataValue(_activeKey);
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Map<String, dynamic>? _activeCookie() {
    final list = _list();
    final idx = _active();
    if (idx == null || idx < 0 || idx >= list.length) return null;
    return list[idx];
  }

  void _commit(List<Map<String, dynamic>> list, int? active) {
    widget.plugin.setDataValue(_listKey, list);
    widget.plugin.setDataValue(_activeKey, active);
    if (active != null &&
        active >= 0 &&
        active < list.length &&
        (list[active]['userhash']?.toString() ?? '').isNotEmpty) {
      widget.plugin.setConfigValue(
        _configKey,
        list[active]['userhash']!.toString(),
      );
    } else {
      widget.plugin.setConfigValue(_configKey, '');
    }
    MePagePluginManager().touch();
    if (mounted) setState(() {});
  }

  void _select(int idx) {
    final list = _list();
    if (idx < 0 || idx >= list.length) return;
    _commit(list, idx);
    App.rootContext.showMessage(
      message: '${list[idx]['name'] ?? list[idx]['userhash']} · '
          '${_txt('active', '用于浏览')}',
    );
  }

  Future<void> _addManual() async {
    final nameCtrl = TextEditingController();
    final hashCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? error;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => ContentDialog(
          title: _txt('add', '添加自定义饼干'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _txt('name', 'name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hashCtrl,
                decoration: InputDecoration(
                  labelText: _txt('hash', 'userhash / cookie'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: _txt('note', '备注（可不填）'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final hash = _normalizeCookieUserhash(hashCtrl.text);
                if (name.isEmpty) {
                  setD(() => error = t.cookieNameRequired);
                  return;
                }
                if (hash == null) {
                  setD(() => error = t.invalidCookieHash);
                  return;
                }
                Navigator.pop(ctx, true);
                _addEntry(
                  name: name,
                  hash: hash,
                  note: noteCtrl.text.trim(),
                );
              },
              child: Text(_txt('save', t.confirm)),
            ),
          ],
        ),
      ),
    );
    // 注意：不要在这里 dispose 控制器——弹窗关闭的过渡动画期间
    // TextField 仍会引用它们（见 “used after being disposed” 崩溃）
  }

  Future<void> _addByScan() async {
    final result = await QrScannerPage.push(context);
    if (result == null || !mounted) return;
    var name = '';
    var hash = _normalizeCookieUserhash(result.rawValue);
    try {
      final decoded = jsonDecode(result.rawValue);
      if (decoded is Map) {
        final map = decoded.map((k, v) => MapEntry('$k', v));
        name = map['name']?.toString() ?? '';
        hash =
            _normalizeCookieUserhash(
              map['cookie']?.toString() ?? '',
            ) ??
            hash;
      }
    } catch (_) {}
    if (hash == null) {
      App.rootContext.showMessage(
        message: t.invalidCookieQrCode,
        level: LogLevel.error,
      );
      return;
    }
    if (name.isEmpty) name = _txt('scanFallback', '扫码饼干');
    _addEntry(name: name, hash: hash);
  }

  void _addEntry({
    required String name,
    required String hash,
    String note = '',
  }) {
    final list = _list();
    final existing = list.indexWhere((e) => e['userhash'] == hash);
    if (existing >= 0) {
      _commit(list, existing);
      App.rootContext.showMessage(message: '${t.alreadyExists}: $name');
      return;
    }
    list.add({
      'name': name,
      'userhash': hash,
      if (note.isNotEmpty) 'note': note,
    });
    _commit(list, list.length - 1);
    App.rootContext.showMessage(message: t.cookieImported);
  }

  void _remove(int idx) {
    final list = _list();
    if (idx < 0 || idx >= list.length) return;
    final removed = list[idx];
    showConfirmDialog(
      context: context,
      title: t.delete,
      content:
          '${removed['name'] ?? ''}\n${removed['userhash']}'
          '${(removed['note'] ?? '').toString().isNotEmpty ? '\n${removed['note']}' : ''}',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        final active = _active();
        list.removeAt(idx);
        var newActive = active;
        if (newActive != null) {
          if (newActive == idx) {
            newActive = list.isEmpty ? null : 0;
          } else if (newActive > idx) {
            newActive--;
          }
        }
        _commit(list, newActive);
        App.rootContext.showMessage(message: t.deleted);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _list();
    final active = _activeCookie();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cookie_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                active == null
                    ? _txt('none', '还没有饼干')
                    : '${active['name'] ?? active['userhash']} · '
                          '${_txt('active', '用于浏览')}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active == null ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconTileButton(
              icon: const Icon(Icons.edit_note),
              label: _txt('add', '添加自定义饼干'),
              onTap: _addManual,
            ),
            IconTileButton(
              icon: const Icon(Icons.qr_code_scanner),
              label: _txt('scan', '扫描饼干二维码'),
              onTap: _addByScan,
            ),
          ],
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                i == _active()
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: i == _active() ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(
                (list[i]['name']?.toString() ?? '')
                    .isEmpty
                    ? (list[i]['userhash']?.toString() ?? '')
                    : list[i]['name']!.toString(),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                [
                  list[i]['userhash']?.toString() ?? '',
                  list[i]['note']?.toString() ?? '',
                ].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: t.delete,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: cs.error,
                ),
                onPressed: () => _remove(i),
              ),
              onTap: () => _select(i),
            ),
          ],
        ],
      ],
    );
  }
}

/// 饼干设置：自定义粘贴导入 / 扫码导入（对齐 xdnmb-main 的饼干导入）
class _PluginCookieEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginCookieEditor({required this.plugin, required this.m});

  @override
  State<_PluginCookieEditor> createState() => _PluginCookieEditorState();
}

class _PluginCookieEditorState extends State<_PluginCookieEditor> {
  String get _key => widget.m['key']?.toString() ?? 'userhash';

  String get _value => widget.plugin.configs[_key]?.toString() ?? '';

  /// 兼容多种来源：裸 userhash / userhash=xxx / {"cookie":"…","name":"…"} / {"userhash":…}
  String? _normalize(String raw) => _normalizeCookieUserhash(raw);

  void _save(String hash) {
    widget.plugin.setConfigValue(_key, hash);
    MePagePluginManager().touch();
    if (mounted) setState(() {});
    App.rootContext.showMessage(message: t.cookieImported);
  }

  Future<void> _manualImport() async {
    await showInputDialog(
      context: context,
      title: t.importCustomCookie,
      hintText: 'userhash=xxxxx 或 {"cookie":"…","name":"…"}',
      initialValue: _value,
      minLines: 1,
      onConfirm: (raw) {
        final hash = _normalize(raw);
        if (hash == null) return t.invalidCookieQrCode;
        _save(hash);
        return null;
      },
    );
  }

  Future<void> _scanImport() async {
    final result = await QrScannerPage.push(context);
    if (result == null || !mounted) return;
    final hash = _normalize(result.rawValue);
    if (hash == null) {
      App.rootContext.showMessage(
        message: t.invalidCookieQrCode,
        level: LogLevel.error,
      );
      return;
    }
    _save(hash);
  }

  void _clear() {
    widget.plugin.setConfigValue(_key, '');
    MePagePluginManager().touch();
    if (mounted) setState(() {});
    App.rootContext.showMessage(message: t.cookieCleared);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cookie_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              _value.isEmpty ? t.noData : _value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                color: _value.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconTileButton(
              icon: const Icon(Icons.edit_note),
              label: t.importCustomCookie,
              onTap: _manualImport,
            ),
            IconTileButton(
              icon: const Icon(Icons.qr_code_scanner),
              label: t.scanCookieQrCode,
              onTap: _scanImport,
            ),
            if (_value.isNotEmpty)
              IconTileButton(
                icon: const Icon(Icons.backspace_outlined),
                label: t.clear,
                onTap: _clear,
              ),
          ],
        ),
      ],
    );
  }
}

/// 插件 config 输入：写入 `.data['configs']` 并通知刷新
class _PluginConfigEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginConfigEditor({required this.plugin, required this.m});

  @override
  State<_PluginConfigEditor> createState() => _PluginConfigEditorState();
}

class _PluginConfigEditorState extends State<_PluginConfigEditor> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  List<Map<String, dynamic>> get _fields {
    final raw = widget.m['fields'] ?? widget.m['items'];
    final list = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final f in raw) {
        if (f is Map) {
          list.add(f.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      final key = f['key']?.toString() ?? '';
      _ctrls[key] = TextEditingController(
        text: widget.plugin.configs[key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (final f in _fields) {
        final key = f['key']?.toString() ?? '';
        widget.plugin.setConfigValue(key, _ctrls[key]?.text ?? '');
      }
      App.rootContext.showMessage(message: t.saved);
      MePagePluginManager().touch();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in _fields) ...[
          TextField(
            controller: _ctrls[f['key']?.toString() ?? ''],
            keyboardType: (f['kind']?.toString() ?? '') == 'number'
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              isDense: true,
              labelText: f['label']?.toString() ?? '',
              hintText: f['hint']?.toString(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Button.filled(
            isLoading: _saving,
            onPressed: _save,
            child: Text(widget.m['saveText']?.toString() ?? t.apply),
          ),
        ),
      ],
    );
  }
}

/// 插件登录：与番剧源设置页的登录模块一致——账号/密码表单，
/// 提交后调用插件 `login(username, password)`（JS 内自行发请求、存 Cookie）
class _PluginLoginPage extends StatefulWidget {
  const _PluginLoginPage({
    required this.plugin,
    this.initialUsername = '',
  });

  final MePagePlugin plugin;
  final String initialUsername;

  @override
  State<_PluginLoginPage> createState() => _PluginLoginPageState();
}

class _PluginLoginPageState extends State<_PluginLoginPage> {
  late final TextEditingController _userCtrl = TextEditingController(
    text: widget.initialUsername,
  );
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      context.showMessage(message: t.cannotBeEmpty);
      return;
    }
    setState(() => _loading = true);
    final res = await widget.plugin.login(username, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['ok'] == true) {
      widget.plugin.setLogged(true);
      await MePagePluginManager().setCreds(
        widget.plugin.key,
        username: username,
        password: password,
      );
      App.rootContext.showMessage(message: t.switchSuccessful);
      if (mounted) context.pop();
    } else {
      context.showMessage(
        message: res['message']?.toString().isNotEmpty == true
            ? res['message'].toString()
            : t.loginFailed,
        level: LogLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.name)),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.login,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _userCtrl,
                decoration: InputDecoration(
                  labelText: t.username,
                  border: const OutlineInputBorder(),
                ),
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.password,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _login(),
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 24),
              Button.filled(
                isLoading: _loading,
                onPressed: _login,
                child: Text(t.continueText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分段筛选控件（与番剧源设置页 _FilterSegmented 同款式）
class _PluginFilterSegmented extends StatelessWidget {
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  const _PluginFilterSegmented({
    required this.value,
    required this.options,
    required this.onChanged,
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

/// 插件“账户”二级页：与番剧源账户页一致（未登录→登录；已登录→重新登录/登出）
class _PluginAccountPage extends StatefulWidget {
  const _PluginAccountPage({required this.plugin});

  final MePagePlugin plugin;

  @override
  State<_PluginAccountPage> createState() => _PluginAccountPageState();
}

class _PluginAccountPageState extends State<_PluginAccountPage> {
  bool _reloginLoading = false;

  MePagePlugin get p => widget.plugin;

  Future<void> _openLoginForm() async {
    final creds = MePagePluginManager().credsOf(p.key);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PluginLoginPage(
          plugin: p,
          initialUsername: creds?['username']?.toString() ?? '',
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _relogin() async {
    final creds = MePagePluginManager().credsOf(p.key);
    if (creds == null) {
      context.showMessage(message: t.noData);
      return;
    }
    setState(() => _reloginLoading = true);
    final res = await p.login(
      creds['username']?.toString() ?? '',
      creds['password']?.toString() ?? '',
    );
    if (!mounted) return;
    setState(() => _reloginLoading = false);
    if (res['ok'] == true) {
      p.setLogged(true);
      context.showMessage(message: t.switchSuccessful);
    } else {
      context.showMessage(
        message: res['message']?.toString().isNotEmpty == true
            ? res['message'].toString()
            : t.loginFailed,
        level: LogLevel.error,
      );
    }
  }

  Future<void> _logout() async {
    await p.logout();
    MePagePluginManager().clearCreds(p.key);
    p.setLogged(false);
    if (mounted) setState(() {});
    context.showMessage(message: t.switchSuccessful);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final logged = p.isLogged;
    final creds = MePagePluginManager().credsOf(p.key);
    return PopUpWidgetScaffold(
      title: p.name,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!logged)
                  ListTile(
                    title: Text(t.logIn),
                    trailing: const Icon(Icons.arrow_right),
                    onTap: _openLoginForm,
                  )
                else ...[
                  ListTile(
                    leading: Icon(
                      Icons.verified_user_outlined,
                      color: colorScheme.primary,
                    ),
                    title: Text(
                      creds?['username']?.toString().isNotEmpty == true
                          ? creds!['username'].toString()
                          : t.loggedIn,
                    ),
                  ),
                  ListTile(
                    title: Text(t.reLogin),
                    subtitle: Text(t.clickIfLoginExpired),
                    trailing: _reloginLoading
                        ? const SizedBox.square(
                            dimension: 24,
                            child: PolygonRefreshIndicator(),
                          )
                        : const Icon(Icons.refresh),
                    onTap: _relogin,
                  ),
                  ListTile(
                    title: Text(t.logOut),
                    trailing: const Icon(Icons.logout),
                    onTap: _logout,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}