part of 'settings_page.dart';

/// 个人页插件管理卡片：列出已加载插件，支持重新加载与删除。
class MePagePluginSettings extends StatefulWidget {
  const MePagePluginSettings({super.key});

  @override
  State<MePagePluginSettings> createState() => _MePagePluginSettingsState();
}

class _MePagePluginSettingsState extends State<MePagePluginSettings> {
  @override
  void initState() {
    super.initState();
    MePagePluginManager().ensureInit();
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
    return _SettingCard(
      children: [
        _SettingPartTitle(title: t.mePagePlugin, icon: Icons.widgets_outlined),
        if (plugins.isEmpty)
          ListTile(
            dense: true,
            subtitle: Text(
              t.noMePagePlugin,
              style: const TextStyle(fontSize: 12),
            ),
          )
        else
          for (final p in plugins)
            ListTile(
              dense: true,
              title: Text(p.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                'v${p.version}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: t.delete,
                onPressed: () => _delete(p),
              ),
            ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.refresh, size: 20),
          title: Text(t.reload, style: const TextStyle(fontSize: 13)),
          onTap: _reload,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.folder_open, size: 20),
          title: Text(t.openDir, style: const TextStyle(fontSize: 13)),
          onTap: _openDir,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.add, size: 20),
          title: Text(t.createPlugin, style: const TextStyle(fontSize: 13)),
          onTap: _create,
        ),
      ],
    );
  }
}
