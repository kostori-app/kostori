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
      App.rootContext.showMessage(message: t.switchSuccessful);
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
      App.rootContext.showMessage(message: t.switchSuccessful);
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
    App.rootContext.showMessage(message: t.switchSuccessful);
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
                  login: p.hasLogin
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _PluginLoginPage(plugin: p),
                            ),
                          );
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

  /// 打开插件源码编辑（桌面优先 VS Code，否则内置编辑器）
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
class _PluginSliverCard extends StatelessWidget {
  const _PluginSliverCard({
    super.key,
    required this.plugin,
    required this.enabled,
    required this.onToggle,
    required this.edit,
    required this.delete,
    this.login,
  });

  final MePagePlugin plugin;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Future<void> Function(MePagePlugin) edit;
  final Future<void> Function(MePagePlugin) delete;
  final VoidCallback? login;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                CustomSwitch(
                  value: enabled,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (login != null)
                  IconTileButton(
                    icon: const Icon(Icons.login),
                    label: t.login,
                    onTap: login,
                  ),
                IconTileButton(
                  icon: const Icon(Icons.edit_outlined),
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

/// 插件登录：与番剧源设置页的登录模块一致——账号/密码表单，
/// 提交后调用插件 `login(username, password)`（JS 内自行发请求、存 Cookie）
class _PluginLoginPage extends StatefulWidget {
  const _PluginLoginPage({required this.plugin});

  final MePagePlugin plugin;

  @override
  State<_PluginLoginPage> createState() => _PluginLoginPageState();
}

class _PluginLoginPageState extends State<_PluginLoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
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