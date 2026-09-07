part of 'me_page_plugins.dart';

Future<void> _pushPluginPage(
  BuildContext context,
  MePagePlugin plugin,
  String name,
  Map<String, dynamic> params, {
  Map<String, dynamic>? item,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => name == 'thread'
          ? PluginThreadPage(plugin: plugin, params: params, row: item)
          : PluginSubPage(plugin: plugin, name: name, params: params),
    ),
  );
}

/// 单层插件子页（详情等）：调用 plugin.page(name, params) 渲染模块
class PluginSubPage extends StatefulWidget {
  final MePagePlugin plugin;
  final String name;
  final Map<String, dynamic> params;

  const PluginSubPage({
    super.key,
    required this.plugin,
    required this.name,
    this.params = const {},
  });

  @override
  State<PluginSubPage> createState() => _PluginSubPageState();
}

class _PluginSubPageState extends State<PluginSubPage> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.plugin.page(widget.name, widget.params);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.titleOf(widget.name))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: PolygonRefreshIndicator(),
            );
          }
          final modules = snap.data ?? const [];
          return _contentOrBoard(widget.plugin, modules);
        },
      ),
    );
  }
}

/// 通用模块列表（子页 / 详情页内容）
class _PluginModulesList extends StatelessWidget {
  final MePagePlugin plugin;
  final List<dynamic> modules;

  const _PluginModulesList({required this.plugin, required this.modules});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final m in modules)
          if (_ModuleView.build(context, plugin, m) != null)
            _ModuleView.build(context, plugin, m)!,
      ],
    );
  }
}

/// 个人页上“打开插件导航”的入口卡片
class _PluginShellEntry extends StatelessWidget {
  final MePagePlugin plugin;

  const _PluginShellEntry({required this.plugin});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PluginShellPage(plugin: plugin),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.widgets_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plugin.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  t.open,
                  style: TextStyle(fontSize: 13, color: cs.primary),
                ),
                Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 插件导航壳：顶部/底部导航 + 各导航页内容（每页各自调用 plugin.page）
class PluginShellPage extends StatefulWidget {
  final MePagePlugin plugin;

  /// 打开时定位的初始页 key（如 'login'），null 时取第一个导航页
  final String? initialPageKey;

  const PluginShellPage({
    super.key,
    required this.plugin,
    this.initialPageKey,
  });

  @override
  State<PluginShellPage> createState() => _PluginShellPageState();
}

class _PluginShellPageState extends State<PluginShellPage> {
  late final MePagePluginManager _manager;
  late Future<List<Map<String, dynamic>>> _navFuture;
  PageController? _pageController;
  int _index = 0;
  List<Map<String, dynamic>> _nav = const [];

  // 每个导航子页独立缓存/加载态（对齐 anime_list：目标页未就绪时整块替换，不残留旧内容）
  List<List<dynamic>?> _pages = const [];
  List<bool> _loading = const [];
  List<String?> _errors = const [];
  int _reqToken = 0;

  @override
  void initState() {
    super.initState();
    _manager = MePagePluginManager()..addListener(_onManagerChanged);
    _navFuture = widget.plugin.nav().then((nav) {
      _nav = nav;
      int start = 0;
      if (widget.initialPageKey != null) {
        final found = nav.indexWhere(
          (n) => n['key'] == widget.initialPageKey,
        );
        if (found >= 0) start = found;
      }
      _index = start;
      _pageController = PageController(initialPage: start);
      _pages = List<List<dynamic>?>.filled(nav.length, null);
      _loading = List<bool>.filled(nav.length, false);
      _errors = List<String?>.filled(nav.length, null);
      if (_nav.isNotEmpty) _loadIndex(start);
      return nav;
    });
  }

  @override
  void dispose() {
    _manager.removeListener(_onManagerChanged);
    _pageController?.dispose();
    super.dispose();
  }

  /// 配置写入等数据变更后，自动重拉当前子页（如首页积分配置更新即时生效）
  void _onManagerChanged() {
    if (!mounted) return;
    if (_nav.isEmpty || _index >= _pages.length) return;
    if (_pages[_index] == null || _loading[_index]) return;
    final idx = _index;
    setState(() => _pages[idx] = null);
    _loadIndex(idx);
  }

  Future<void> _loadIndex(int index) async {
    if (index < 0 || index >= _nav.length) return;
    if (_pages[index] != null || _loading[index]) return;
    final token = ++_reqToken;
    setState(() {
      _loading[index] = true;
      _errors[index] = null;
    });
    try {
      final modules =
          await widget.plugin.page(_nav[index]['key']?.toString() ?? '');
      if (!mounted || token != _reqToken) return;
      setState(() {
        _pages[index] = modules;
        _loading[index] = false;
      });
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      setState(() {
        _loading[index] = false;
        _errors[index] = '$e';
      });
    }
  }

  void _select(int index) {
    if (index < 0 || index >= _nav.length) return;
    final pc = _pageController;
    if (pc != null && pc.hasClients) {
      pc.animateToPage(
        index,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    setState(() => _index = index);
    _loadIndex(index);
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _nav.length) return;
    if (_index != index) {
      setState(() => _index = index);
    }
    _loadIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.name)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _navFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: PolygonRefreshIndicator(size: 24));
          }
          if (_nav.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            children: [
              if (_nav.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CapsuleBar(
                      keys: _nav
                          .map((n) => n['key']?.toString() ?? '')
                          .toList(),
                      titles: _nav
                          .map((n) => n['title']?.toString() ?? '')
                          .toList(),
                      icons: _nav
                          .map((n) => n['icon']?.toString() ?? '')
                          .toList(),
                      selected: _index < _nav.length
                          ? (_nav[_index]['key']?.toString() ?? '')
                          : '',
                      onChanged: _select,
                    ),
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    for (var i = 0; i < _nav.length; i++)
                      _NavKeepAlive(
                        key: ValueKey(
                          '${widget.plugin.key}-nav-${_nav[i]['key'] ?? i}',
                        ),
                        child: _pageBody(i),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pageBody(int index) {
    if (index < 0 || index >= _nav.length) {
      return const SizedBox.shrink();
    }
    final key = _nav[index]['key']?.toString() ?? '$index';
    final error = index < _errors.length ? _errors[index] : null;
    final data = index < _pages.length ? _pages[index] : null;
    if (error != null) {
      return _PluginRetry(message: error, onRetry: () => _loadIndex(index));
    }
    if (data == null) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    // 同一插件的多个导航页即使渲染相同类型（如多个板块）也要按 key 重建状态
    return KeyedSubtree(
      key: ValueKey('$key-$index'),
      child: _contentOrBoard(widget.plugin, data),
    );
  }
}

/// 保持各导航页存活（滚到旁边的 tab 再回来不重新加载/不丢滚动位置）
class _NavKeepAlive extends StatefulWidget {
  final Widget child;

  const _NavKeepAlive({super.key, required this.child});

  @override
  State<_NavKeepAlive> createState() => _NavKeepAliveState();
}

class _NavKeepAliveState extends State<_NavKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 内容加载失败占位（可重试，对齐 anime_list 的错误态）
class _PluginRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PluginRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Button.filled(onPressed: onRetry, child: Text(t.retry)),
        ],
      ),
    );
  }
}

IconData _navIcon(String name) => switch (name) {
  'home' => Icons.home_outlined,
  'star' => Icons.star_outline,
  'person' => Icons.person_outline,
  'settings' => Icons.settings_outlined,
  'search' => Icons.search,
  'check' => Icons.check_circle_outline,
  'list' => Icons.list_alt_outlined,
  'rank' => Icons.leaderboard_outlined,
  'folder' => Icons.folder_outlined,
  'cloud' => Icons.cloud_outlined,
  'heart' => Icons.favorite_outline,
  'more' => Icons.more_horiz,
  _ => Icons.widgets_outlined,
};

/// 签到管理详情页：总开关 + 各插件签到卡（一键签到在此也可触发）
