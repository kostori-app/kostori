part of 'settings_page.dart';

/// 个人页插件管理卡片：列出已加载插件，支持重新加载与删除。
class PluginSettings extends StatefulWidget {
  const PluginSettings({super.key});

  @override
  State<PluginSettings> createState() => _PluginSettingsState();
}

class _PluginSettingsState extends State<PluginSettings> {
  late final TextEditingController _urlCtrl;

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
            child: _SettingCard(
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _PluginSliverCard(
                key: ValueKey(plugins[i].key),
                plugin: plugins[i],
                edit: _edit,
                delete: _delete,
              ),
              childCount: plugins.length,
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
    required this.edit,
    required this.delete,
  });

  final MePagePlugin plugin;
  final Future<void> Function(MePagePlugin) edit;
  final Future<void> Function(MePagePlugin) delete;

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
            trailing: IconButton(
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
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: IconTileButton(
                icon: const Icon(Icons.edit_outlined),
                label: t.edit,
                onTap: () => edit(plugin),
              ),
            ),
          ),
        ],
      ),
    );
  }
}