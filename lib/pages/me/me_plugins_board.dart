part of 'me_page_plugins.dart';

CachedImageProvider _siteProvider(String url, {required MePagePlugin plugin}) {
  final referer = plugin.referer;
  return CachedImageProvider(
    url,
    headers: referer == null || referer.isEmpty ? null : {'referer': referer},
    sourceKey: plugin.key,
  );
}

/// 站点图片：走项目缓存图片组件
Widget _siteImage(
  String url, {
  required MePagePlugin plugin,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return AnimatedImage(
    image: _siteProvider(url, plugin: plugin),
    width: width,
    height: height,
    fit: fit,
  );
}

/// 若页面内容本身就是 board 模块则直接渲染板块内容。
/// [presetController] 由外壳下发时走“外壳托管模式”（顶部导航统一在外壳渲染）。
Widget _contentOrBoard(
  MePagePlugin plugin,
  List<dynamic> modules, {
  TabController? presetController,
  double? presetTopInset,
}) {
  for (final m in modules) {
    if (_asMap2(m)['type'] == 'board') {
      if (presetController != null) {
        final mm = _asMap2(m);
        final raw = mm['tabs'];
        final tabs = raw is List
            ? raw.map((e) => _asMap2(e)).toList()
            : <Map<String, dynamic>>[];
        return PluginBoardContent(
          plugin: plugin,
          presetTabs: tabs,
          presetListPage: mm['page']?.toString(),
          presetController: presetController,
          presetTopInset: presetTopInset,
        );
      }
      return PluginBoardContent(plugin: plugin, metaModules: modules);
    }
  }
  return _PluginModulesList(plugin: plugin, modules: modules);
}

/// 磨砂玻璃条（样式对齐 anime_list 分页条：BlurEffect + 半透明 surface，直边无圆角）
class _GlassBar extends StatelessWidget {
  final Widget child;

  const _GlassBar({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlurEffect(
      blur: 10,
      child: Container(
        decoration: BoxDecoration(color: cs.surface.toOpacity(0.85)),
        child: child,
      ),
    );
  }
}

/// 论坛列表条目卡片：作者行 + 标题 + 条目信息 + 图片(可点击预览) + 辅助信息
class _ForumBoardRow extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> item;

  const _ForumBoardRow({required this.plugin, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = item['title']?.toString() ?? '';
    final name = item['name']?.toString() ?? item['author']?.toString() ?? '';
    final infoLine =
        item['infoLine']?.toString() ?? item['meta']?.toString() ?? '';
    final time = item['time']?.toString() ?? '';
    // 无 infoLine（如搜索结果）时用时间兜底显示
    final subLine = infoLine.isNotEmpty ? infoLine : time;
    final summary =
        item['summary']?.toString() ?? item['subtitle']?.toString() ?? '';
    final avatar =
        item['avatarUrl']?.toString() ?? item['avatar']?.toString() ?? '';
    final views = item['views']?.toString() ?? '';
    final replies = item['replies']?.toString() ?? '';
    final images = <String>[];
    final imgs = item['images'];
    if (imgs is List) images.addAll(imgs.map((e) => e.toString()));

    // Hero tag 必须用稳定值：优先顶层 tid，其次 params.tid，最后条目对象身份
    final tidObj = item['tid'] ?? _asMap2(item['params'])['tid'];
    final heroBase =
        'forum_${plugin.key}_${(tidObj?.toString().isNotEmpty ?? false) ? tidObj.toString() : identityHashCode(item)}';
    String heroTagFor(int i) => '${heroBase}_$i';

    Widget? avatarWidget;
    if (avatar.isNotEmpty) {
      avatarWidget = ClipOval(
        child: _siteImage(avatar, width: 40, height: 40, plugin: plugin),
      );
    }

    // 图片预览：复用被点击的 provider（同 headers/sourceKey，缓存命中），Hero 与列表 tile 同 tag
    void preview(int index) {
      if (images.isEmpty) return;
      final url = images[index];
      BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: url,
        title: title.isEmpty ? plugin.name : title,
        imageProvider: _siteProvider(url, plugin: plugin),
        heroTag: heroTagFor(index),
      );
    }

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final page = item['page']?.toString() ?? 'thread';
          final params = item['params'] is Map
              ? _asMap2(item['params'])
              : <String, dynamic>{};
          if (item['url'] != null) params['url'] = item['url'].toString();
          if (page == 'thread') params['tid'] ??= item['tid'];
          _pushPluginPage(context, plugin, page, params, item: item);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (avatarWidget == null)
                _ForumHeaderText(name: name, subLine: subLine)
              else
                Row(
                  children: [
                    avatarWidget,
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ForumHeaderText(name: name, subLine: subLine),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
              if (images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final heroTag = heroTagFor(i);
                      return GestureDetector(
                        onTap: () => preview(i),
                        child: Hero(
                          tag: heroTag,
                          flightShuttleBuilder:
                              (
                                flightContext,
                                animation,
                                direction,
                                fromContext,
                                toContext,
                              ) {
                                return direction == HeroFlightDirection.pop
                                    ? (fromContext.widget as Hero).child
                                    : (toContext.widget as Hero).child;
                              },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _siteImage(
                              images[i],
                              width: 130,
                              height: 100,
                              plugin: plugin,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (views.isNotEmpty || replies.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (views.isNotEmpty) ...[
                      Icon(
                        Icons.visibility_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        views,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (replies.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.mode_comment_outlined,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        replies,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 板块内容（可内联进插件页，也可放进弹层页）：
/// 分类 Tab + 列表 + 页码跳转
class PluginBoardContent extends StatefulWidget {
  final MePagePlugin plugin;

  /// 外层（插件导航壳）已经取到的板块 meta 模块，避免再按写死的 'board' 拉一次
  final List<dynamic>? metaModules;

  /// 外壳托管模式：分类列表/请求页/控制器由外壳下发并统一渲染顶部导航
  /// （此模式下组件不自建 TabController、不画顶部玻璃胶囊条）
  final List<Map<String, dynamic>>? presetTabs;
  final String? presetListPage;
  final TabController? presetController;
  final double? presetTopInset;

  const PluginBoardContent({
    super.key,
    required this.plugin,
    this.metaModules,
    this.presetTabs,
    this.presetListPage,
    this.presetController,
    this.presetTopInset,
  });

  @override
  State<PluginBoardContent> createState() => _PluginBoardContentState();
}

class _PluginBoardContentState extends State<PluginBoardContent>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _tabs = [];
  String _listPage = 'boardList';
  int _index = 0;
  bool _metaLoaded = false;
  bool _external = false;
  int _page = 1;
  int _totalPages = 1;
  String? _error;
  int _reqToken = 0;

  // 分类缓存：tabKey -> (page -> rows)，页码/总数按分类记住（对齐 anime_list）
  final Map<String, Map<int, List<Map<String, dynamic>>>> _cache = {};
  final Map<String, int> _tabPage = {};
  final Map<String, int> _tabTotal = {};

  final ScrollController _scroll = ScrollController();
  TabController? _tabsCtrl;

  // 分页 / 连续滑动两种模式（连续 = 滚动到末尾自动加载下一页，对齐 anime_list 双模式）
  bool _continuous = false;
  bool _appending = false;

  String get _tabKey =>
      _index < _tabs.length ? (_tabs[_index]['key']?.toString() ?? '') : '';

  String _tabKeyOf(int i) =>
      i < _tabs.length ? (_tabs[i]['key']?.toString() ?? '') : '';

  String get _modeSettingKey => 'mePluginListMode_${widget.plugin.key}';

  @override
  void initState() {
    super.initState();
    _continuous = appdata.settings[_modeSettingKey] == true;
    if (widget.presetTabs != null && widget.presetController != null) {
      _external = true;
      _tabs = widget.presetTabs!;
      _listPage = widget.presetListPage ?? 'boardList';
      _tabsCtrl = widget.presetController!..addListener(_onTabChanged);
      _metaLoaded = true;
      if (_tabs.isNotEmpty) _go(_tabPage[_tabKey] ?? 1);
      return;
    }
    _loadMeta();
  }

  @override
  void dispose() {
    _scroll.dispose();
    final c = _tabsCtrl;
    if (c != null) {
      if (_external) {
        c.removeListener(_onTabChanged);
      } else {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final modules = widget.metaModules ?? await widget.plugin.page('board');
    if (!mounted) return;
    for (final m in modules) {
      final mm = _asMap2(m);
      if (mm['type'] != 'board') continue;
      final raw = mm['tabs'];
      if (raw is List) _tabs = raw.map((e) => _asMap2(e)).toList();
      _listPage = mm['page']?.toString() ?? 'boardList';
    }
    if (_tabs.isNotEmpty) {
      _tabsCtrl?.dispose();
      _tabsCtrl = TabController(length: _tabs.length, vsync: this)
        ..addListener(_onTabChanged);
    }
    setState(() {
      _metaLoaded = true;
      _index = 0;
    });
    if (_tabs.isNotEmpty) _go(_tabPage[_tabKey] ?? 1);
  }

  Future<void> _fetch(String tabKey, int page) async {
    final token = ++_reqToken;
    // 立即清空旧内容并进入加载态（anime_list 行为：目标页未就绪时不留旧页）
    setState(() {
      _error = null;
      _page = page;
      // 立刻更新“当前页指针”，让渲染端不再展示上一页内容
      _tabPage[tabKey] = page;
    });
    try {
      final parsed = _parseBoard(
        await widget.plugin.page(_listPage, {'tab': tabKey, 'page': page}),
        page,
      );
      if (!mounted || token != _reqToken) return;
      (_cache[tabKey] ??= {})[parsed.current] = parsed.rows;
      _tabPage[tabKey] = parsed.current;
      _tabTotal[tabKey] = parsed.total;
      if (_tabKey != tabKey) return;
      setState(() {
        _page = parsed.current;
        _totalPages = parsed.total;
      });
      if (_continuous) _scheduleFetchMore();
    } catch (e) {
      if (!mounted || token != _reqToken) return;
      if (_tabKey == tabKey) {
        setState(() => _error = '$e');
      }
    }
  }

  ({List<Map<String, dynamic>> rows, int total, int current}) _parseBoard(
    List<dynamic> modules,
    int page,
  ) {
    var rows = <Map<String, dynamic>>[];
    var total = 1;
    var current = page;
    for (final m in modules) {
      final mm = _asMap2(m);
      if (mm['type'] != 'boardPage') continue;
      total = _asInt(mm['totalPages'], total);
      current = _asInt(mm['page'], page);
      final raw = mm['items'];
      if (raw is List) {
        rows = raw.map((e) => _asMap2(e)).toList();
      }
    }
    if (total < 1) total = 1;
    return (rows: rows, total: total, current: current);
  }

  static int _asInt(dynamic v, int fallback) {
    final n = int.tryParse('$v');
    return n == null || n < 1 ? fallback : n;
  }

  /// 切到某页：命中缓存直接显示，否则清空并重新拉取（分页模式）
  void _go(int page) {
    if (page < 1) return;
    final key = _tabKey;
    if (_continuous) {
      // 连续模式只从第 1 页顺序累积
      if (page == 1 && (_cache[key]?[1] == null)) {
        _cache.remove(key);
        _fetch(key, 1);
      }
      return;
    }
    final cached = _cache[key]?[page];
    if (cached != null) {
      setState(() {
        _page = page;
        _tabPage[key] = page;
        _error = null;
        _totalPages = _tabTotal[key] ?? _totalPages;
      });
      return;
    }
    _fetch(key, page);
  }

  /// 状态切换（PageView 停稳后调用）
  void _switchTo(int i) {
    if (_index == i) return;
    setState(() {
      _index = i;
      _error = null;
    });
    _enterCurrentTab();
  }

  /// 顶部胶囊点击：动画切到对应分类页
  void _selectTab(int i) {
    if (i < 0 || i >= _tabs.length) return;
    final c = _tabsCtrl;
    if (c != null) {
      c.animateTo(i);
      return;
    }
    _switchTo(i);
  }

  /// TabController 停稳后的同步（分类滑动落点）
  void _onTabChanged() {
    final c = _tabsCtrl;
    if (c == null || !mounted || c.indexIsChanging) return;
    _switchTo(c.index);
  }

  void _enterCurrentTab() {
    if (!_continuous) {
      final p = _tabPage[_tabKey] ?? 1;
      _go(p);
      return;
    }
    final pages = _cache[_tabKey];
    if (pages == null || pages.isEmpty || pages[1] == null) {
      _fetch(_tabKey, 1);
    } else {
      setState(() {
        _page = _nextMissing(_tabKey) - 1;
        _totalPages = _tabTotal[_tabKey] ?? _totalPages;
      });
      _scheduleFetchMore();
    }
  }

  List<Map<String, dynamic>> _mergedOf(String tabKey) {
    final pages = _cache[tabKey];
    final out = <Map<String, dynamic>>[];
    var i = 1;
    while (pages != null) {
      final pageRows = pages[i];
      if (pageRows == null) break;
      out.addAll(pageRows);
      i++;
    }
    return out;
  }

  int _nextMissing(String tabKey) {
    final pages = _cache[tabKey];
    var i = 1;
    while (pages?[i] != null) {
      i++;
    }
    return i;
  }

  bool get _hasMore {
    final total = _tabTotal[_tabKey];
    final next = _nextMissing(_tabKey);
    return total == null || next <= total;
  }

  void _scheduleFetchMore() {
    Future.microtask(() {
      if (mounted) _fetchMore();
    });
  }

  /// 连续模式：滚动到末尾时顺序加载下一页并累积
  Future<void> _fetchMore() async {
    if (!_continuous || _appending || _error != null) return;
    final key = _tabKey;
    final pages = _cache[key];
    if (pages == null || pages.isEmpty || pages[1] == null) {
      await _fetch(key, 1);
      return;
    }
    final next = _nextMissing(key);
    if (!_hasMore) return;
    if (pages[next] != null) return;
    final token = _reqToken;
    _appending = true;
    setState(() {});
    try {
      final parsed = _parseBoard(
        await widget.plugin.page(_listPage, {'tab': key, 'page': next}),
        next,
      );
      if (!mounted || token != _reqToken) {
        _appending = false;
        return;
      }
      (_cache[key] ??= {})[parsed.current] = parsed.rows;
      _tabTotal[key] = parsed.total;
      if (_tabKey == key) {
        setState(() {
          _totalPages = parsed.total;
        });
      }
    } catch (e) {
      if (!mounted || token != _reqToken) {
        _appending = false;
        return;
      }
      if (_tabKey == key) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        if (token == _reqToken) {
          setState(() => _appending = false);
        } else {
          _appending = false;
        }
      }
    }
  }

  void _retryContinuous() {
    setState(() => _error = null);
    _scheduleFetchMore();
  }

  void _toggleMode() {
    setState(() => _continuous = !_continuous);
    appdata.settings[_modeSettingKey] = _continuous;
    appdata.saveData();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (!_continuous) {
      // 回到分页：从该分类上次停留页展示
      final p = _tabPage[_tabKey] ?? 1;
      _go(p);
    } else {
      _enterCurrentTab();
    }
  }

  void _refreshList() {
    final key = _tabKey;
    _cache.remove(key);
    _tabPage.remove(key);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (_continuous) {
      _fetch(key, 1);
    } else {
      _page = 1;
      _go(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_metaLoaded) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    final cs = Theme.of(context).colorScheme;
    // 留白放在滚动内容自身（anime_list 同款）：网格铺满，行可滚到玻璃条下方产生磨砂
    return Stack(
      children: [
        Positioned.fill(
          child: ExtendedTabBarView(
            controller: _tabsCtrl,
            children: [
              for (var i = 0; i < _tabs.length; i++) _categoryPane(i),
            ],
          ),
        ),
        if (_tabs.isNotEmpty && !_external)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _GlassBar(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CapsuleBar(
                    keys: _tabs.map((t) => t['key']?.toString() ?? '').toList(),
                    titles: _tabs
                        .map((t) => t['title']?.toString() ?? '')
                        .toList(),
                    selected: _index < _tabs.length
                        ? (_tabs[_index]['key']?.toString() ?? '')
                        : '',
                    onChanged: _selectTab,
                  ),
                ),
              ),
            ),
          ),
        if (!_continuous)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlassBar(
              child: _ForumPager(
                page: _page,
                totalPages: _totalPages,
                busy: _isBusy,
                onJump: _go,
              ),
            ),
          ),
        Positioned(
          right: 8,
          bottom: _continuous ? 16 : 80,
          child: FloatingMenu(
            controller: _scroll,
            child: [
              [
                SpeedDialChild(
                  child: const Icon(Icons.refresh),
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  onTap: _refreshList,
                ),
              ],
              [
                SpeedDialChild(
                  child: Icon(
                    _continuous ? Icons.view_cozy_outlined : Icons.menu,
                  ),
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  onTap: _toggleMode,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool get _isBusy {
    if (_error != null) return false;
    if (_continuous) {
      // 连续模式：只要还没拿到第 1 页即为加载中
      return _cache[_tabKey]?[1] == null;
    }
    // 分页：当前页无缓存即视为加载中（清空后第一次 build 进入 loader）
    return _cache[_tabKey]?[_page] == null;
  }

  /// 分类页内容（每个 tab 一页，状态从各自缓存取）
  Widget _categoryPane(int tabIdx) {
    final cs = Theme.of(context).colorScheme;
    final key = _tabKeyOf(tabIdx);
    final active = tabIdx == _index;
    final edge = EdgeInsets.fromLTRB(
      8,
      // 外壳托管时顶部导航悬浮，内容按外壳下发的高度让位并从其下方滚过；
      // 自管理模式仍需让出 ~44px 顶部玻璃胶囊
      _external
          ? (widget.presetTopInset ?? 10)
          : (_tabs.isNotEmpty ? 50 : 8),
      8,
      _continuous ? 24 : 66,
    );

    List<Map<String, dynamic>> visible;
    if (_continuous) {
      if (active && _cache[_tabKey]?[1] == null && _error != null) {
        return Padding(
          padding: edge,
          child: _PluginRetry(message: _error!, onRetry: _retryContinuous),
        );
      }
      if (_cache[key]?[1] == null) {
        return Padding(
          padding: edge,
          child: const Center(child: PolygonRefreshIndicator(size: 24)),
        );
      }
      visible = _mergedOf(key);
    } else {
      final page = _tabPage[key] ?? 1;
      final cached = _cache[key]?[page];
      if (active && _error != null && cached == null) {
        return Padding(
          padding: edge,
          child: _PluginRetry(message: _error!, onRetry: () => _go(page)),
        );
      }
      if (cached == null) {
        return Padding(
          padding: edge,
          child: const Center(child: PolygonRefreshIndicator(size: 24)),
        );
      }
      visible = cached;
    }
    if (visible.isEmpty) {
      return Padding(
        padding: edge,
        child: Center(
          child: Text(t.noData, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    // 连续模式：底部追加载器行 / 加载失败重试行（仅当前页）
    final showTail = _continuous && active && _appending;
    final showError =
        _continuous && active && _error != null && !_appending;
    return ListView.separated(
      controller: active ? _scroll : null,
      padding: edge,
      itemCount: visible.length + (showTail ? 1 : 0) + (showError ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i >= visible.length) {
          if (showError) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: _PluginRetry(
                message: _error!,
                onRetry: _retryContinuous,
              ),
            );
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: PolygonRefreshIndicator(size: 22),
            ),
          );
        }
        // 连续模式滑到末尾自动加载下一页（失败后不自动循环重试）
        if (_continuous &&
            active &&
            i == visible.length - 1 &&
            _hasMore &&
            _error == null) {
          _scheduleFetchMore();
        }
        return _ForumBoardRow(plugin: widget.plugin, item: visible[i]);
      },
    );
  }
}

/// 论坛行头部：无头像时直接铺开，作者为空则只显示信息行
class _ForumHeaderText extends StatelessWidget {
  final String name;
  final String subLine;

  const _ForumHeaderText({required this.name, this.subLine = ''});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (subLine.isNotEmpty) ...[
          if (name.isNotEmpty) const SizedBox(height: 2),
          Text(
            subLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 板块弹层页（供 board 模块入口使用）
class PluginBoardPage extends StatelessWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> meta;

  const PluginBoardPage({super.key, required this.plugin, required this.meta});

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: meta['title']?.toString() ?? '',
      body: PluginBoardContent(plugin: plugin, metaModules: [meta]),
    );
  }
}
