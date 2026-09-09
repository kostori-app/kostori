part of 'me_page_plugins.dart';

class _ThreadPost {
  final int pid;
  final int floor;
  final String floorLabel;
  final String roleLabel;
  final String noLabel;
  final String author;
  final String avatarUrl;
  final String time;
  final String content;
  final List<Map<String, dynamic>> blocks;
  final List<String> images;

  _ThreadPost({
    this.pid = 0,
    this.floor = 0,
    this.floorLabel = '',
    this.roleLabel = '',
    this.noLabel = '',
    this.author = '',
    this.avatarUrl = '',
    this.time = '',
    this.content = '',
    List<Map<String, dynamic>>? blocks,
    this.images = const [],
  }) : blocks = blocks ?? const [];
}

/// 帖子详情页：帖子头部 + 楼层卡片（可加载更多楼层/分页）
class PluginThreadPage extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> params;

  /// 来源列表行的元信息（标题/作者/时间/浏览/回复/头像），用于头部展示
  final Map<String, dynamic>? row;

  const PluginThreadPage({
    super.key,
    required this.plugin,
    required this.params,
    this.row,
  });

  @override
  State<PluginThreadPage> createState() => _PluginThreadPageState();
}

class _PluginThreadPageState extends State<PluginThreadPage> {
  String _title = '';
  String _pageUrl = '';
  List<MapEntry<String, String>> _fields = const [];
  String _bestText = '';
  String _bestReward = '';
  String _bestAuthor = '';
  String _bestDate = '';
  final List<_ThreadPost> _posts = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  /// 简洁帖子模式：不要“详情/楼主详情块”，所有帖子（含楼主）直接以楼层卡片平铺
  bool _simplePosts = false;

  /// 楼主徽标文案，插件可用 poLabel 覆盖，默认 Po
  String _poLabel = 'Po';

  /// 简单模式下记录楼主的 user_hash，用于给楼主后续回复也标 Po
  String _opHash = '';

  /// 楼主等身份标识与 >>引用 跳转高亮
  final Map<int, GlobalKey> _floorKeys = {};
  int? _highlightPid;
  Timer? _hlTimer;

  @override
  void initState() {
    super.initState();
    _title = widget.row?['title']?.toString() ?? '';
    _load();
  }

  @override
  void dispose() {
    _hlTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = Map<String, dynamic>.from(widget.params)..['page'] = _page;
      final modules = await widget.plugin.page('thread', p);
      if (!mounted) return;
      var hasMore = false;
      final parsed = <_ThreadPost>[];
      for (final m in modules) {
        final map = _asMap2(m);
        if (map['type'] != 'threadPage') continue;
        if (map['simple'] == true) _simplePosts = true;
        if (map['simple'] == true && (map['poLabel']?.toString().isNotEmpty ?? false)) {
          _poLabel = map['poLabel']!.toString();
        }
        if (_title.isEmpty) _title = map['title']?.toString() ?? '';
        if (_pageUrl.isEmpty) _pageUrl = map['url']?.toString() ?? '';
        final rawFields = map['fields'];
        if (rawFields is List) {
          final parsedFields = <MapEntry<String, String>>[];
          for (final rf in rawFields) {
            final rfm = _asMap2(rf);
            final k = rfm['k']?.toString() ?? '';
            final v = rfm['v']?.toString() ?? '';
            if (k.isNotEmpty && v.isNotEmpty) {
              parsedFields.add(MapEntry(k, v));
            }
          }
          if (parsedFields.isNotEmpty) _fields = parsedFields;
        }
        final best = map['best'];
        if (best is Map) {
          final bm = best.map((k, v) => MapEntry(k.toString(), v.toString()));
          if ((bm['text'] ?? '').isNotEmpty) {
            _bestText = bm['text']!;
            _bestReward = bm['reward'] ?? '';
            _bestAuthor = bm['author'] ?? '';
            _bestDate = bm['date'] ?? '';
          }
        }
        hasMore = map['hasMore'] == true;
        final posts = map['posts'];
        if (posts is List) {
          for (final b in posts) {
            final bm = _asMap2(b);
            final images = <String>[];
            final imgs = bm['images'];
            if (imgs is List) images.addAll(imgs.map((e) => e.toString()));
            final blocks = <Map<String, dynamic>>[];
            final rawBlocks = bm['blocks'];
            if (rawBlocks is List) {
              for (final rb in rawBlocks) {
                final rbm = _asMap2(rb);
                if (rbm.isEmpty) continue;
                blocks.add(rbm);
              }
            }
            parsed.add(
              _ThreadPost(
                pid: _asInt(bm['pid'], 0),
                floor: _asInt(bm['floor'], 0),
                floorLabel: bm['floorLabel']?.toString() ?? '',
                roleLabel: bm['roleLabel']?.toString() ?? '',
                noLabel: bm['noLabel']?.toString() ?? '',
                author: bm['author']?.toString() ?? '',
                avatarUrl: bm['avatarUrl']?.toString() ?? '',
                time: bm['time']?.toString() ?? '',
                content: bm['content']?.toString() ?? '',
                blocks: blocks,
                images: images,
              ),
            );
          }
        }
      }
      setState(() {
        _posts.addAll(parsed);
        if (_opHash.isEmpty && _simplePosts && _posts.isNotEmpty) {
          _opHash = _posts.first.author;
        }
        _page++;
        _hasMore = hasMore && parsed.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  double get _topInset => MediaQuery.paddingOf(context).top + 56;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: _topInset + 4, bottom: 8),
              child: _body(cs),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _topBar(cs)),
        ],
      ),
    );
  }

  Widget _topBar(ColorScheme cs) {
    return Appbar(
      title: Text(
        _title.isEmpty ? widget.plugin.name : _title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Tooltip(
          message: t.openInBrowser,
          child: IconButton(
            icon: const Icon(Icons.open_in_browser_outlined),
            onPressed: _pageUrl.isEmpty
                ? null
                : () => launchUrlString(_pageUrl),
          ),
        ),
      ],
    );
  }

  Widget _body(ColorScheme cs) {
    if (_error != null && _posts.isEmpty) {
      return _PluginRetry(message: _error!, onRetry: _load);
    }
    if (_loading && _posts.isEmpty) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    final children = <Widget>[
      if (!_simplePosts) _header(cs),
      if (_posts.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(
            child: Text(t.noData, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        )
      else ...[
        if (_simplePosts)
          for (var i = 0; i < _posts.length; i++) ...[
            _keyedFloorCard(cs, _posts[i], i),
            const SizedBox(height: 10),
          ]
        else ...[
          // 楼主 = 帖子详情主体：分类信息 + 正文 + 图合并成一块，不再当楼层
          _mainContent(cs, _posts.first),
          const SizedBox(height: 10),
          for (var i = 1; i < _posts.length; i++) ...[
            _keyedFloorCard(cs, _posts[i], i),
            const SizedBox(height: 10),
          ],
        ],
      ],
    ];
    if (_hasMore) {
      children.add(
        Center(
          child: TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const PolygonRefreshIndicator(size: 14)
                : const Icon(Icons.expand_more),
            label: Text(t.more),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: children,
    );
  }

  /// 帖子头部：标题 + 标签 + 作者/浏览/回复元信息
  Widget _header(ColorScheme cs) {
    final row = widget.row;
    final tag = row?['tag']?.toString() ?? '';
    final name = row?['name']?.toString() ?? row?['author']?.toString() ?? '';
    final avatar = row?['avatarUrl']?.toString() ?? '';
    final time = row?['time']?.toString() ?? '';
    final infoLine = row?['infoLine']?.toString() ?? '';
    final views = row?['views']?.toString() ?? '';
    final replies = row?['replies']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _title.isEmpty ? (row?['title']?.toString() ?? '') : _title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.3,
            color: cs.onSurface,
          ),
        ),
        if (tag.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: TextStyle(fontSize: 12, color: cs.onSecondaryContainer),
            ),
          ),
        ],
        if (name.isNotEmpty || views.isNotEmpty || replies.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (avatar.isNotEmpty) ...[
                ClipOval(
                  child: _siteImage(
                    avatar,
                    width: 36,
                    height: 36,
                    plugin: widget.plugin,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (time.isNotEmpty || infoLine.isNotEmpty)
                      Text(
                        infoLine.isNotEmpty ? infoLine : time,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (views.isNotEmpty)
                _stat(cs, Icons.remove_red_eye_outlined, views),
              if (replies.isNotEmpty) ...[
                const SizedBox(width: 14),
                _stat(cs, Icons.chat_bubble_outline, replies),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _stat(ColorScheme cs, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }

  /// 楼主主内容块：分类信息(类别/原因…) + 正文富文本 + 图片，与上方帖子头合并成一屏详情
  Widget _mainContent(ColorScheme cs, _ThreadPost post) {
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_fields.isNotEmpty)
              for (var i = 0; i < _fields.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 14,
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        _fields[i].key,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _richText(
                        _fields[i].value,
                        fontSize: 13.5,
                        height: 1.5,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            if (_fields.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
            ],
            if (_bestText.isNotEmpty) ...[
              _bestAnswerBlock(cs),
              const SizedBox(height: 10),
            ],
            _postContent(context, cs, post),
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _postImages(context, cs, post),
            ],
          ],
        ),
      ),
    );
  }

  /// “最佳答案”组件块：已解决帖的采纳答案，独立高亮展示
  Widget _bestAnswerBlock(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.secondary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: cs.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                '最佳答案',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          if (_bestReward.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.paid_outlined, size: 15, color: cs.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _bestReward,
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          if (_bestText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _richText(
              _bestText,
              fontSize: 14,
              height: 1.55,
              color: cs.onSurface,
            ),
          ],
          if (_bestAuthor.isNotEmpty || _bestDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (_bestAuthor.isNotEmpty) _bestAuthor,
                if (_bestDate.isNotEmpty) _bestDate,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  /// 给帖子卡片挂跳转用的 GlobalKey（便于 >>No 点击定位）
  Widget _keyedFloorCard(ColorScheme cs, _ThreadPost post, int visibleNo) {
    return _floorCard(
      cs,
      post,
      visibleNo,
      key: post.pid > 0
          ? (_floorKeys[post.pid] ??= GlobalKey())
          : null,
    );
  }

  /// 回帖卡片：头像/作者/时间 + 可见序号 + 富文本内容 + 图片预览
  Widget _floorCard(
    ColorScheme cs,
    _ThreadPost post,
    int visibleNo, {
    Key? key,
  }) {
    final highlighted = _highlightPid == post.pid;
    return Material(
      key: key,
      color: highlighted
          ? cs.secondaryContainer.withValues(alpha: 0.55)
          : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _floorHeader(cs, post, visibleNo),
            const SizedBox(height: 10),
            _postContent(context, cs, post),
            if (post.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              _postImages(context, cs, post),
            ],
          ],
        ),
      ),
    );
  }

  Widget _floorHeader(ColorScheme cs, _ThreadPost post, int visibleNo) {
    final avatarUrl = post.avatarUrl;
    // 右上角标识：优先插件下发的 No 串号，其次楼层序号（楼主有身份标识则不显示 #0）
    String floorNum = '';
    if (post.noLabel.isNotEmpty) {
      floorNum = post.noLabel;
    } else if (post.floorLabel.isNotEmpty) {
      floorNum = post.floorLabel;
    } else if (visibleNo > 0) {
      floorNum = '#$visibleNo';
    }
    return Row(
      children: [
        if (avatarUrl.isNotEmpty) ...[
          ClipOval(
            child: _siteImage(
              avatarUrl,
              width: 38,
              height: 38,
              plugin: widget.plugin,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 楼主判定：插件 roleLabel；或简单模式首条；或楼主后续同 user_hash 回复
              final bool poPost =
                  _simplePosts &&
                  _opHash.isNotEmpty &&
                  post.author == _opHash;
              if (post.author.isNotEmpty ||
                  post.roleLabel.isNotEmpty ||
                  (visibleNo == 0 && _simplePosts) ||
                  poPost)
                Row(
                  children: [
                    if (post.author.isNotEmpty)
                      Flexible(
                        child: Text(
                          post.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if ((visibleNo == 0 && _simplePosts) || poPost) ...[
                      if (post.author.isNotEmpty) const SizedBox(width: 6),
                      _opBadge(cs, _poLabel),
                    ] else if (post.roleLabel.isNotEmpty) ...[
                      if (post.author.isNotEmpty) const SizedBox(width: 6),
                      _opBadge(cs, post.roleLabel),
                    ],
                  ],
                ),
              if (post.time.isNotEmpty)
                Text(
                  post.time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (floorNum.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              floorNum,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );
  }

  /// 通用“楼主”等身份标识组件（供 _floorHeader 复用）
  Widget _opBadge(ColorScheme cs, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onTertiaryContainer,
        ),
      ),
    );
  }

  /// >> 引用：通用引用块（左侧色条 + 淡底色）。色条默认用主题色，
  /// 插件可下发 `color`（#RRGGBB 或 int）覆盖。
  Widget _refBlock(ColorScheme cs, String text, [dynamic rawColor]) {
    final Color? overrideColor = _parseRefColor(rawColor);
    final barColor = overrideColor ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: barColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _jumpToRef(text),
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3.5, color: barColor),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 解析插件下发的引用色：#RRGGBB / #AARRGGBB / int
  Color? _parseRefColor(dynamic v) {
    if (v == null) return null;
    if (v is int && v > 0) return Color(v);
    final s = v.toString().trim();
    if (s.startsWith('#')) {
      final hex = s.substring(1);
      final n = int.tryParse(hex, radix: 16);
      if (n == null) return null;
      const mask = 0xFFFFFFFF;
      if (hex.length == 6) return Color(0xFF000000 | n);
      if (hex.length == 8) return Color(n & mask);
    }
    return null;
  }

  /// 解析 >>No.xxx 并定位到对应楼层
  void _jumpToRef(String text) {
    final m = RegExp(r'\d{6,}').firstMatch(text);
    if (m == null) return;
    final pid = int.tryParse(m.group(0)!);
    if (pid == null) return;
    final has = _posts.any((p) => p.pid == pid);
    if (!has) return;
    final ctx = (_floorKeys[pid]?.currentContext);
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.08,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    _hlTimer?.cancel();
    setState(() => _highlightPid = pid);
    _hlTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlightPid = null);
    });
  }

  Widget _postContent(BuildContext context, ColorScheme cs, _ThreadPost post) {
    if (post.blocks.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in post.blocks) ...[
            if (b['type'] == 'quote')
              _quoteBlock(cs, b['text']?.toString() ?? '')
            else if (b['type'] == 'ref')
              _refBlock(cs, b['text']?.toString() ?? '', b['color'])
            else if (b['text']?.toString().trim().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _plainText(b['text'].toString()),
              ),
          ],
        ],
      );
    }
    if (post.content.trim().isNotEmpty) {
      return _plainText(post.content);
    }
    return const SizedBox.shrink();
  }

  Widget _plainText(String text) {
    return _richText(
      text,
      fontSize: 14.5,
      height: 1.55,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }

  /// 正文富文本：可选中复制；长按段落弹出链接菜单（打开/复制），无链接时原生选中
  Widget _richText(
    String text, {
    double fontSize = 14.5,
    double height = 1.55,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    // 展示前兜底压掉多余空行（多图回复/解析残留常见），避免大片留白
    final src = text
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
    final urls = <String>[];
    final spans = _linkSpans(src, cs.primary, urls);
    final rich = SelectableText.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, height: height, color: color),
        children: spans,
      ),
    );
    if (urls.isEmpty) return rich;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showLinkMenu(urls),
      child: rich,
    );
  }

  List<TextSpan> _linkSpans(String text, Color linkColor, List<String> urls) {
    final urlRe = RegExp(r'(?:https?://|magnet:\?)[^\s<>]+');
    final spans = <TextSpan>[];
    var pos = 0;
    for (final m in urlRe.allMatches(text)) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start)));
      }
      var url = m.group(0)!;
      while (url.isNotEmpty &&
          RegExp(r'[.,;:)\]}]$').hasMatch(url) &&
          !url.endsWith(':')) {
        url = url.substring(0, url.length - 1);
      }
      if (!urls.contains(url)) urls.add(url);
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(color: linkColor),
        ),
      );
      pos = m.start + m.group(0)!.length;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return spans;
  }

  /// 长按含链接段落的操作菜单：每行可点打开 + 复制按钮
  Future<void> _showLinkMenu(List<String> urls) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < urls.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.link),
                  title: Text(
                    urls[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    launchUrlString(urls[i]);
                  },
                  trailing: IconButton(
                    tooltip: t.copyLink,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: urls[i]));
                      App.rootContext.showMessage(message: t.copiedToClipboard);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 引用块样式：与项目 bangumi 话题的引用一致（左侧 4 主色条 + 圆角 8 + 文字描边色）
  Widget _quoteBlock(ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            border: Border(left: BorderSide(color: cs.primary, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _richText(
              text,
              fontSize: 13,
              height: 1.5,
              color: cs.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _postImages(BuildContext context, ColorScheme cs, _ThreadPost post) {
    final pid = post.pid == 0 ? post.floor : post.pid;
    void preview(int i) {
      final url = post.images[i];
      BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: url,
        title: _title,
        imageProvider: _siteProvider(url, plugin: widget.plugin),
        heroTag: 'thread_${widget.plugin.key}_${pid}_$i',
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: post.images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final heroTag = 'thread_${widget.plugin.key}_${pid}_$i';
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
                borderRadius: BorderRadius.circular(10),
                child: _siteImage(
                  post.images[i],
                  width: 150,
                  height: 110,
                  plugin: widget.plugin,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// anime 风格分页器（宽/窄屏两套，与番源列表一致）
class _ForumPager extends StatelessWidget {
  final int page;
  final int totalPages;
  final bool busy;
  final ValueChanged<int> onJump;

  const _ForumPager({
    required this.page,
    required this.totalPages,
    required this.busy,
    required this.onJump,
  });

  void _jump(BuildContext context) {
    String value = '';
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: t.jumpToPage,
          content: TextField(
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(labelText: t.page),
            onChanged: (v) => value = v,
          ).paddingHorizontal(16),
          actions: [
            Button.filled(
              onPressed: () {
                Navigator.of(context).pop();
                final p = int.tryParse(value);
                if (p == null || p <= 0 || p > totalPages) {
                  App.rootContext.showMessage(message: t.invalidPage);
                  return;
                }
                onJump(p);
              },
              child: Text(t.apply),
            ),
          ],
        );
      },
    );
  }

  Widget _pagePill(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: t.jumpToPage,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _jump(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.toOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(t.pagePM(p: '$page', m: '$totalPages')),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 600;
    final prevBtn = _PagerIcon(
      icon: Icons.chevron_left,
      label: t.back,
      enabled: page > 1 ,
      onTap: () => onJump(page - 1),
      onRepeat: () {
        if (page > 1 ) onJump(page - 1);
      },
    );
    final nextBtn = _PagerIcon(
      icon: Icons.chevron_right,
      label: t.next,
      enabled: page < totalPages ,
      onTap: () => onJump(page + 1),
      onRepeat: () {
        if (page < totalPages ) onJump(page + 1);
      },
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pagePill(context),
            Row(children: [prevBtn, const SizedBox(width: 12), nextBtn]),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          Row(
            children: [
              _PagerIcon(
                icon: Icons.first_page,
                label: t.first,
                enabled: page > 1 ,
                onTap: () => onJump(1),
              ),
              const SizedBox(width: 4),
              prevBtn,
              const SizedBox(width: 8),
              _pagePill(context),
              const SizedBox(width: 8),
              nextBtn,
              const SizedBox(width: 4),
              _PagerIcon(
                icon: Icons.last_page,
                label: t.last,
                enabled: page < totalPages ,
                onTap: () => onJump(totalPages),
              ),
            ],
          ),
          const SizedBox(),
        ],
      ),
    );
  }
}

/// 分页图标按钮（支持长按连续触发）
class _PagerIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onRepeat;

  const _PagerIcon({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.onRepeat,
  });

  @override
  State<_PagerIcon> createState() => _PagerIconState();
}

class _PagerIconState extends State<_PagerIcon> {
  Timer? _timer;

  void _start() {
    if (!widget.enabled) return;
    widget.onTap();
    _timer?.cancel();
    if (widget.onRepeat != null) {
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!widget.enabled || !mounted) {
          _timer?.cancel();
          return;
        }
        widget.onRepeat!();
      });
    }
  }

  void _end() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.label,
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _end(),
        onLongPressCancel: _end,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: 48,
            height: 48,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : null,
              borderRadius: BorderRadius.circular(16),
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return colorScheme.primary.toOpacity(0.2);
                }
                if (states.contains(WidgetState.hovered)) {
                  return colorScheme.secondary.toOpacity(0.1);
                }
                return null;
              }),
              child: Center(
                child: Icon(
                  widget.icon,
                  color: widget.enabled
                      ? colorScheme.primary
                      : colorScheme.onSurface.toOpacity(0.3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 项目风格分段胶囊切换条（settings/favorites 同款，可横向滚动）
class _CapsuleBar extends StatelessWidget {
  final List<String> keys;
  final List<String> titles;
  final List<String>? icons;
  final String selected;
  final ValueChanged<int> onChanged;

  const _CapsuleBar({
    required this.keys,
    required this.titles,
    required this.selected,
    required this.onChanged,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < keys.length; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected == keys[i]
                        ? cs.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: selected == keys[i]
                        ? [
                            BoxShadow(
                              color: Colors.black.toOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons != null && icons![i].isNotEmpty) ...[
                        Icon(
                          _navIcon(icons![i]),
                          size: 13,
                          color: selected == keys[i]
                              ? cs.primary
                              : cs.onSurface.toOpacity(0.45),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        titles[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected == keys[i]
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected == keys[i]
                              ? cs.primary
                              : cs.onSurface.toOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
