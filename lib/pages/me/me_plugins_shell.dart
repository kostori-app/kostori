part of 'me_page_plugins.dart';

Future<void> _pushPluginPage(
  BuildContext context,
  MePagePlugin plugin,
  String name,
  Map<String, dynamic> params, {
  Map<String, dynamic>? item,
}) async {
  await context.to(
    () => name == 'thread'
        ? PluginThreadPage(plugin: plugin, params: params, row: item)
        : PluginSubPage(plugin: plugin, name: name, params: params),
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
    return SizedBox(
      width: 108,
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.to(() => PluginShellPage(plugin: plugin));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.widgets_outlined, size: 22, color: cs.primary),
                const SizedBox(height: 6),
                Text(
                  plugin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class _PluginShellPageState extends State<PluginShellPage>
    with SingleTickerProviderStateMixin {
  late final MePagePluginManager _manager;
  late Future<List<Map<String, dynamic>>> _navFuture;
  TabController? _outerTabs;
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
      if (nav.isNotEmpty) {
        _outerTabs = TabController(length: nav.length, vsync: this)
          ..index = start
          ..addListener(_onOuterTabChanged);
      }
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
    _outerTabs?.dispose();
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
    final tabs = _outerTabs;
    if (tabs != null) {
      tabs.animateTo(index);
      return;
    }
    setState(() => _index = index);
    _loadIndex(index);
  }

  void _onOuterTabChanged() {
    final tabs = _outerTabs;
    if (tabs == null || !mounted) return;
    if (tabs.indexIsChanging) return;
    final index = tabs.index;
    if (index < 0 || index >= _nav.length) return;
    if (_index != index) {
      setState(() => _index = index);
    }
    _loadIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(widget.plugin.name),
        actions: [
          if (widget.plugin.hasSearch)
            IconButton(
              tooltip: t.search,
              icon: const Icon(Icons.search),
              onPressed: () {
                context.to(
                  () => PluginSearchPage(plugin: widget.plugin),
                );
              },
            ),
        ],
      ),
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
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
                child: ExtendedTabBarView(
                  controller: _outerTabs,
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

/// 搜索页：走插件 `search(query)`，结构与插件子页一致（输入框 + 结果）
class PluginSearchPage extends StatefulWidget {
  final MePagePlugin plugin;

  const PluginSearchPage({super.key, required this.plugin});

  @override
  State<PluginSearchPage> createState() => _PluginSearchPageState();
}

class _PluginSearchPageState extends State<PluginSearchPage> {
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;
  String _query = '';
  int _page = 1;
  int _total = 1;
  final Map<int, List<Map<String, dynamic>>> _pageCache = {};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search([String? _]) async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    _query = q;
    _pageCache.clear();
    _total = 1;
    await _load(1);
  }

  Future<void> _go(int page) {
    if (page < 1) return _load(1);
    return _load(page);
  }

  Future<void> _load(int page) async {
    if (_query.isEmpty || page < 1) return;
    // 已缓存页直接秒开（返回上一页不重新请求）
    final hit = _pageCache[page];
    if (hit != null) {
      setState(() {
        _page = page;
        _rows = hit;
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
      _error = null;
      _page = page;
      _rows = const [];
    });
    try {
      final modules = await widget.plugin.search(_query, {'page': page});
      if (!mounted) return;
      final rows = <Map<String, dynamic>>[];
      var total = _total;
      for (final m in modules) {
        final mm = _asMap2(m);
        if (mm['type'] == 'boardPage' || mm['type'] == 'searchResult') {
          final t = _asInt(mm['totalPages'], 0);
          if (t > 0) total = t;
          final raw = mm['items'];
          if (raw is List) {
            rows.addAll(raw.map((e) => _asMap2(e)));
          }
        }
      }
      _pageCache[page] = rows;
      setState(() {
        _rows = rows;
        _total = total > 1 ? total : _total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = _searched && _total > 1 ? 76.0 : 16.0;
    return Scaffold(
      appBar: Appbar(title: Text(t.search)),
      body: Stack(
        children: [
          Positioned.fill(
            child: _searched && _rows.isNotEmpty
                ? ListView.separated(
                    padding: EdgeInsets.fromLTRB(8, 84, 8, bottomPad),
                    itemCount: _rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _ForumBoardRow(plugin: widget.plugin, item: _rows[i]),
                  )
                : Padding(
                    padding: EdgeInsets.only(
                      top: 84,
                      bottom: bottomPad,
                      left: 16,
                      right: 16,
                    ),
                    child: _body(cs),
                  ),
          ),
          // 顶部搜索框：磨砂玻璃，内容从下方滚过
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _GlassBar(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: t.search,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: PolygonRefreshIndicator(size: 18),
                          )
                        : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                    ),
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          // 底部翻页：磨砂玻璃，内容从上方滚过
          if (_searched && _total > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _GlassBar(
                child: _ForumPager(
                  page: _page,
                  totalPages: _total,
                  busy: _loading,
                  onJump: _go,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (!_searched) {
      return Center(
        child: Text(
          t.noSearchResults,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    if (_error != null) {
      return _PluginRetry(message: _error!, onRetry: () => _load(_page));
    }
    if (_loading) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          t.noSearchResults,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return const SizedBox.shrink();
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
