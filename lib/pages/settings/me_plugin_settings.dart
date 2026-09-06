part of 'settings_page.dart';

/// 个人页插件管理卡片：列出已加载插件，支持重新加载与删除。
class PluginSettings extends StatefulWidget {
  const PluginSettings({super.key});

  @override
  State<PluginSettings> createState() => _PluginSettingsState();
}

class _PluginSettingsState extends State<PluginSettings> {
  late final TextEditingController _urlCtrl;
  bool _dragOver = false;

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
    if (mounted) setState(() => _dragOver = false);
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
    _urlCtrl = TextEditingController(text: _sourceUrl);
    MePagePluginManager().ensureInit();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
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

  String get _sourceUrl =>
      (appdata.implicitData['pluginSourceUrl'] as String?)?.trim() ?? '';

  Future<void> _editSourceUrl() async {
    await showInputDialog(
      context: context,
      title: t.pluginSourceUrl,
      hintText: 'https://example.com/plugins/index.json',
      initialValue: _sourceUrl,
      onConfirm: (value) async {
        final v = value.trim();
        appdata.implicitData['pluginSourceUrl'] = v;
        appdata.writeImplicitData();
        if (mounted) setState(() {});
        return null;
      },
    );
  }

  Future<void> _fetchPlugins() async {
    final url = _sourceUrl;
    if (url.isEmpty) {
      await _editSourceUrl();
      return;
    }
    try {
      final count = await MePagePluginManager().fetchFromUrl(url);
      if (mounted) setState(() {});
      App.rootContext.showMessage(
        message: t.fetchPluginsCount(fetchPlugins: t.fetchPlugins, count: count),
        level: LogLevel.info,
      );
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.fetchPlugins} $e',
        level: LogLevel.error,
      );
    }
  }

  static String _pluginTemplate(String name) =>
      '''
/**
 * 个人页插件：$name
 *
 * 支持的模块类型：card / text / keyValue / link / progress / chips / signIn / button
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
        // 操作卡片：插件源 URL（对齐番源"添加番剧源"组件）
        _BuildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: t.pluginSourceUrl,
                icon: Icons.widgets_outlined,
              ),
              TextField(
                controller: _urlCtrl,
                decoration: InputDecoration(
                  hintText: 'https://example.com/plugins/index.json',
                  border: const UnderlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  suffix: IconButton(
                    onPressed: _fetchPlugins,
                    icon: const Icon(Icons.check),
                  ),
                ),
                onChanged: (value) {
                  appdata.implicitData['pluginSourceUrl'] = value.trim();
                  appdata.writeImplicitData();
                },
                onSubmitted: (_) => _fetchPlugins(),
              ).paddingHorizontal(16).paddingBottom(8),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconTileButton(
                      icon: const Icon(Icons.download_outlined),
                      label: t.fetchPlugins,
                      onTap: _fetchPlugins,
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
        ),
        // 拖拽安装 .js 插件
        _BuildSectionPadding(
          DropTarget(
            onDragDone: _onDrop,
            onDragEntered: (_) {
              if (mounted) setState(() => _dragOver = true);
            },
            onDragExited: (_) {
              if (mounted) setState(() => _dragOver = false);
            },
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.installPluginByDrop,
                  icon: Icons.file_download_outlined,
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: _dragOver
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest.toOpacity(0.4),
                    border: Border.all(
                      color: _dragOver
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: _dragOver ? 1.6 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_present_outlined,
                          size: 26,
                          color: _dragOver
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.dropJsPluginHint,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 每个插件一个卡片（对齐番源卡片风格）
        if (plugins.isEmpty)
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
          for (final p in plugins)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  ListTile(
                    title: Text(p.name, style: ts.s18),
                    subtitle: Text('v${p.version}'),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      tooltip: t.delete,
                      onPressed: () => _delete(p),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconTileButton(
                          icon: const Icon(Icons.edit_outlined),
                          label: t.edit,
                          onTap: () => _edit(p),
                        ),
                        IconTileButton(
                          icon: const Icon(Icons.delete_outline),
                          label: t.delete,
                          color: Theme.of(context).colorScheme.error,
                          onTap: () => _delete(p),
                        ),
                      ],
                    ),
                  ),
                ],
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
