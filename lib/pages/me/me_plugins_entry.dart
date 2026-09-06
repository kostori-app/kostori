part of 'me_page_plugins.dart';

/// 打开插件管理页（项目风格 Scaffold + 内置 SliverAppbar）
Future<void> openMePagePluginManage(BuildContext context) {
  return context.to(
    () => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const SafeArea(child: PluginSettings()),
    ),
  );
}

/// 安全转 double：避免插件返回非数字时 as 强转崩溃
double _asDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// 安全转 String
String _asStr(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

/// 安全转 int
int _asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// 个人页插件模块渲染：读取 data/me_plugins 下的插件，渲染其 render() 返回的模块。
class MePagePluginModules extends ConsumerStatefulWidget {
  const MePagePluginModules({super.key});

  @override
  ConsumerState<MePagePluginModules> createState() =>
      _MePagePluginModulesState();
}

class _MePagePluginModulesState extends ConsumerState<MePagePluginModules> {
  List<Widget> _cards = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await MePagePluginManager().ensureInit();
      final plugins = MePagePluginManager().all();
      final cards = <Widget>[];
      for (final p in plugins) {
        if (!MePagePluginManager().isEnabled(p.key)) continue;
        // 带导航的插件：进入“导航壳”浏览，不在 Me 页直接铺开 render()
        if (p.hasNav) {
          cards.add(_PluginShellEntry(plugin: p));
          continue;
        }
        final modules = await p.render();
        for (final m in modules) {
          final w = _ModuleView.build(context, p, m);
          if (w != null) cards.add(w);
        }
      }
      if (mounted) {
        setState(() {
          _cards = cards;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题 + 插件管理入口（与个人页其它模块头一致）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.widgets_outlined, color: cs.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.mePagePlugin,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: t.oneKeySign,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _signAll,
                      onLongPress: _openSignDetail,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 20,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openManage,
                    icon: const Icon(Icons.settings_outlined, size: 16),
                    label: Text(t.manage),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: _cards.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        t.noMePagePlugin,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.toOpacity(0.7),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _cards,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 一键签到（自动跳过未登录/今日已签/不在名单）
  Future<void> _signAll() async {
    final results = await MePagePluginManager().runCollectiveSignin();
    if (!mounted) return;
    await _load();
    final ok = results.where((r) => r['ok'] == true).length;
    final fail = results.length - ok;
    if (results.isEmpty) {
      App.rootContext.showMessage(message: t.noPluginToSign);
    } else if (fail == 0) {
      App.rootContext.showMessage(message: t.signAllSuccess(success: ok));
    } else {
      App.rootContext.showMessage(
        message: t.signAllPartial(success: ok, fail: fail),
        level: LogLevel.warning,
      );
    }
  }

  void _openSignDetail() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PluginSignManagerPage(),
      ),
    );
  }

  /// 打开插件管理页
  void _openManage() {
    App.mainNavigatorKey?.currentContext?.to(
      () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(child: const PluginSettings()),
      ),
    );
  }
}

/// 单个模块的渲染器
