part of 'me_page_plugins.dart';

// 插件页面模块支持 groupPage、selector 和 detailPage。
// detailPage 的 sections 支持 imageText、gallery 和 cards；cards 可声明分页，
// 或使用 variant:'tags' 渲染可点击的标签组。卡片字段由插件动态提供。

/// 从模块列表里收集图片地址（detailPage 的 gallery/imageText、顶层 gallery）。
List<String> _imagesFromModules(List<dynamic> modules) {
  final out = <String>[];
  void addImages(dynamic v) {
    if (v is List) {
      out.addAll(v.map((e) => e.toString()).where((e) => e.isNotEmpty));
    }
  }

  void addSection(dynamic s) {
    final ss = _asMap2(s);
    if (ss['type'] == 'gallery') {
      addImages(ss['images']);
    } else if (ss['type'] == 'imageText') {
      final img = ss['image']?.toString() ?? '';
      if (img.isNotEmpty) out.add(img);
    }
  }

  for (final m in modules) {
    final mm = _asMap2(m);
    if (mm['type'] == 'detailPage') {
      final secs = mm['sections'];
      if (secs is List) {
        for (final s in secs) {
          addSection(s);
        }
      }
    } else if (mm['type'] == 'gallery') {
      addImages(mm['images']);
    }
  }
  return out;
}

/// 轻量图片预览：底部弹出，按需调用 plugin.page 解析图片，不再跳转新页面。
/// 大图横向连续滑动（非翻页），用 keep-alive 避免滑回时重新加载。
class _PluginImagesSheet extends StatefulWidget {
  const _PluginImagesSheet({
    required this.plugin,
    required this.title,
    required this.future,
  });

  final MePagePlugin plugin;
  final String title;
  final Future<List<dynamic>> future;

  @override
  State<_PluginImagesSheet> createState() => _PluginImagesSheetState();
}

class _PluginImagesSheetState extends State<_PluginImagesSheet> {
  @override
  Widget build(BuildContext context) {
    final title = widget.title.isEmpty ? widget.plugin.name : widget.title;
    return Sheet(
      title: title,
      icon: Icons.image_outlined,
      initialSize: 0.8,
      builder: (context, sc) => FutureBuilder<List<dynamic>>(
        future: widget.future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: PolygonRefreshIndicator(size: 28));
          }
          final images = snap.hasData
              ? _imagesFromModules(snap.data!)
              : const <String>[];
          if (images.isEmpty) {
            return const Center(child: Text('—'));
          }
          return LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight - 24;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: images.length,
                itemBuilder: (context, i) =>
                    KeepAliveWrapper(child: _page(title, images[i], h)),
              );
            },
          );
        },
      ),
    );
  }

  Widget _page(String title, String url, double height) {
    return GestureDetector(
      onTap: () => BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: url,
        title: title,
        imageProvider: _siteProvider(url, plugin: widget.plugin),
        heroTag: 'plugin_sheet_${widget.plugin.key}_${url.hashCode}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _siteImage(
          url,
          plugin: widget.plugin,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// 通用“详细卡片”：左封面 + 右信息，字段全部由插件下发，点击进入详情页
class _GenericPluginCard extends StatelessWidget {
  const _GenericPluginCard({required this.plugin, required this.item});

  final MePagePlugin plugin;
  final Map<String, dynamic> item;

  String _str(String key) => item[key]?.toString() ?? '';

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  List<String> _list(String key) {
    final v = item[key];
    if (v is! List) return const [];
    return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  void _open(BuildContext context) {
    final page = item['page']?.toString() ?? 'detail';
    final params = item['params'] is Map
        ? _asMap2(item['params'])
        : <String, dynamic>{};
    if (item['url'] != null) params['url'] = item['url'].toString();
    final title = _str('title');
    if (title.isNotEmpty) params['title'] ??= title;
    _pushPluginPage(context, plugin, page, params, item: item);
  }

  List<Map<String, dynamic>> get _buttons {
    final v = item['buttons'];
    if (v is! List) return const [];
    return v.map(_asMap2).where((e) => e.isNotEmpty).toList();
  }

  bool get _hasNav => item['page'] != null || item['url'] != null;

  // Hero tag 必须跨重建稳定：优先用条目唯一标识，退回封面地址
  String get _heroTag {
    final id = item['tid'] ?? item['id'] ?? item['url'];
    final seed = (id != null && id.toString().isNotEmpty)
        ? id.toString()
        : _str('cover');
    if (seed.isEmpty) return '';
    return 'plugin_card_${plugin.key}_$seed';
  }

  void _previewCover(String heroTag) {
    final cover = _str('cover');
    if (cover.isEmpty) return;
    final title = _str('title');
    BangumiWidget.showImagePreview(
      context: App.rootContext,
      url: cover,
      title: title.isEmpty ? plugin.name : title,
      imageProvider: _siteProvider(cover, plugin: plugin),
      heroTag: heroTag.isEmpty
          ? 'plugin_card_${plugin.key}_${identityHashCode(item)}'
          : heroTag,
    );
  }

  List<String> _btnImages(Map<String, dynamic> btn) {
    final v = btn['images'];
    if (v is List) {
      return v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    final single = btn['image']?.toString() ?? '';
    return single.isNotEmpty ? [single] : const [];
  }

  Future<void> _buttonTap(
    BuildContext context,
    Map<String, dynamic> btn,
  ) async {
    final label = btn['label']?.toString() ?? '';
    // 按钮可跳转到插件子页（如按需解析预览图）
    final page = btn['page']?.toString() ?? '';
    if (page.isNotEmpty) {
      final params = btn['params'] is Map
          ? _asMap2(btn['params'])
          : <String, dynamic>{};
      if (btn['url'] != null) params['url'] = btn['url'].toString();
      params['title'] ??= label;
      // sheet:true → 轻量底部弹层（按需解析图片），不跳转新页面
      if (btn['sheet'] == true) {
        _showPageImagesSheet(label, page, params);
        return;
      }
      _pushPluginPage(context, plugin, page, params, item: btn);
      return;
    }
    final images = _btnImages(btn);
    final url = btn['url']?.toString() ?? '';
    final text = btn['text']?.toString() ?? '';
    // torrent: 磁力链 / 裸 info hash → 打开「添加种子下载」并预填
    final torrent = btn['torrent']?.toString() ?? '';
    if (torrent.isNotEmpty) {
      await showAddTorrentSheet(
        App.rootContext,
        initialMagnet: normalizeMagnet(torrent),
      );
      return;
    }
    if (images.length == 1) {
      await BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: images.first,
        title: label.isEmpty ? plugin.name : label,
        imageProvider: _siteProvider(images.first, plugin: plugin),
        heroTag: 'plugin_btn_${plugin.key}_${identityHashCode(btn)}_0',
      );
      return;
    }
    if (images.length > 1) {
      _showImagesDialog(label, images, btn);
      return;
    }
    if (url.isNotEmpty) {
      launchUrlString(url);
      return;
    }
    if (text.isNotEmpty) {
      showDialog<void>(
        context: App.rootContext,
        builder: (_) => ContentDialog(
          title: label.isEmpty ? plugin.name : label,
          content: SingleChildScrollView(child: AppSelectableText(text)),
          actions: [
            Button.filled(
              onPressed: () => Navigator.of(App.rootContext).pop(),
              child: Text(t.ok),
            ),
          ],
        ),
      );
    }
  }

  void _showPageImagesSheet(
    String title,
    String page,
    Map<String, dynamic> params,
  ) {
    showModalBottomSheet<void>(
      context: App.rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PluginImagesSheet(
        plugin: plugin,
        title: title,
        future: plugin.page(page, params),
      ),
    );
  }

  void _showImagesDialog(
    String title,
    List<String> images,
    Map<String, dynamic> btn,
  ) {
    showDialog<void>(
      context: App.rootContext,
      builder: (_) => ContentDialog(
        title: title.isEmpty ? plugin.name : title,
        content: SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final u = images[i];
              return GestureDetector(
                onTap: () => BangumiWidget.showImagePreview(
                  context: App.rootContext,
                  url: u,
                  title: title.isEmpty ? plugin.name : title,
                  imageProvider: _siteProvider(u, plugin: plugin),
                  heroTag:
                      'plugin_btn_${plugin.key}_${identityHashCode(btn)}_$i',
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _siteImage(
                    u,
                    plugin: plugin,
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          Button.filled(
            onPressed: () => Navigator.of(App.rootContext).pop(),
            child: Text(t.ok),
          ),
        ],
      ),
    );
  }

  Widget _cardButton(BuildContext context, Map<String, dynamic> btn) {
    final label = btn['label']?.toString() ?? Translations.of(context).open;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 180),
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: () => _buttonTap(context, btn),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cover = _str('cover');
    final title = _str('title');
    final subtitle = _str('subtitle');
    final description =
        item['description']?.toString() ?? item['summary']?.toString() ?? '';
    final badge = _str('badge');
    final tags = _list('tags');
    final meta = _list('meta');
    final rating = _num(item['rating']);
    final ratingMax = _num(item['ratingMax']) ?? 5.0;

    final heroTag = _heroTag;
    final coverBox = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: cover.isNotEmpty
          ? _siteImage(
              cover,
              plugin: plugin,
              width: 104,
              height: 140,
              fit: BoxFit.cover,
            )
          : Container(
              width: 104,
              height: 140,
              color: cs.surfaceContainerHighest,
              child: Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
            ),
    );

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _hasNav ? () => _open(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: cover.isEmpty ? null : () => _previewCover(heroTag),
                child: heroTag.isEmpty
                    ? coverBox
                    : KostoriHero(tag: heroTag, child: coverBox),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meta.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: cs.tertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            ' / ${ratingMax.toStringAsFixed(ratingMax % 1 == 0 ? 0 : 1)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final t in tags.take(4))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_buttons.isNotEmpty) ...[
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final b in _buttons)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _cardButton(context, b),
                      ),
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

/// 分组卡片列表（作为外层 ListView 的子项，本身不再滚动）
class _PluginGroupList extends StatelessWidget {
  const _PluginGroupList({required this.plugin, required this.groups});

  final MePagePlugin plugin;
  final List<Map<String, dynamic>> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groups) _PluginGroupBlock(plugin: plugin, group: g),
      ],
    );
  }
}

class _PluginGroupBlock extends StatelessWidget {
  const _PluginGroupBlock({required this.plugin, required this.group});

  final MePagePlugin plugin;
  final Map<String, dynamic> group;

  @override
  Widget build(BuildContext context) {
    final header = group['header'];
    final headerWidget = header == null
        ? null
        : _ModuleView.buildInline(context, plugin, header);
    final items = group['items'] is List
        ? (group['items'] as List)
              .map(_asMap2)
              .where((e) => e.isNotEmpty)
              .toList()
        : const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (headerWidget != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            child: headerWidget,
          ),
        for (final it in items) ...[
          _GenericPluginCard(plugin: plugin, item: it),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// 选择器（类月份表）+ 分组卡片；切换时由插件重新提供数据
class _SelectorSection extends StatefulWidget {
  const _SelectorSection({required this.plugin, required this.module});

  final MePagePlugin plugin;
  final Map<String, dynamic> module;

  @override
  State<_SelectorSection> createState() => _SelectorSectionState();
}

class _SelectorState {
  final String key;
  List<Map<String, dynamic>> options;
  String selected;

  /// 是否显示左右箭头（快捷切换）
  final bool arrows;

  _SelectorState({
    required this.key,
    required this.options,
    required this.selected,
    this.arrows = false,
  });
}

List<Map<String, dynamic>> _selOptions(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map(_asMap2).where((e) => e.isNotEmpty).toList();
}

List<Map<String, dynamic>> _selGroups(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map(_asMap2).where((e) => e.isNotEmpty).toList();
}

List<_SelectorState> _selParseSelectors(Map<String, dynamic> m) {
  final raw = m['selectors'];
  if (raw is List && raw.isNotEmpty) {
    final out = <_SelectorState>[];
    for (final e in raw) {
      final sm = _asMap2(e);
      final opts = _selOptions(sm['options']);
      if (opts.isEmpty) continue;
      out.add(
        _SelectorState(
          key: sm['key']?.toString() ?? 'selection',
          options: opts,
          selected: sm['selected']?.toString() ?? opts.first['key'].toString(),
          arrows: sm['arrows'] == true,
        ),
      );
    }
    return out;
  }
  final opts = _selOptions(m['options']);
  if (opts.isEmpty) return const [];
  return [
    _SelectorState(
      key: 'selection',
      options: opts,
      selected:
          m['selected']?.toString() ?? (opts.first['key']?.toString() ?? ''),
    ),
  ];
}

class _SelectorSectionState extends State<_SelectorSection> {
  late List<_SelectorState> _sels;
  late List<Map<String, dynamic>> _groups;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _sels = _parseSelectors(widget.module);
    _groups = _parseGroups(widget.module['groups']);
  }

  List<Map<String, dynamic>> _parseOptions(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map(_asMap2).where((e) => e.isNotEmpty).toList();
  }

  List<Map<String, dynamic>> _parseGroups(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map(_asMap2).where((e) => e.isNotEmpty).toList();
  }

  /// 支持两种声明：
  /// - 多选择器：`selectors:[{key,options,selected,arrows}, ...]`
  /// - 单选择器（兼容）：`options:[...]`, `selected`
  List<_SelectorState> _parseSelectors(Map<String, dynamic> m) {
    final raw = m['selectors'];
    if (raw is List && raw.isNotEmpty) {
      final out = <_SelectorState>[];
      for (final e in raw) {
        final sm = _asMap2(e);
        final opts = _parseOptions(sm['options']);
        if (opts.isEmpty) continue;
        out.add(
          _SelectorState(
            key: sm['key']?.toString() ?? 'selection',
            options: opts,
            selected:
                sm['selected']?.toString() ?? opts.first['key'].toString(),
            arrows: sm['arrows'] == true,
          ),
        );
      }
      return out;
    }
    final opts = _parseOptions(m['options']);
    if (opts.isEmpty) return const [];
    return [
      _SelectorState(
        key: 'selection',
        options: opts,
        selected:
            m['selected']?.toString() ?? (opts.first['key']?.toString() ?? ''),
      ),
    ];
  }

  Future<void> _switch(int i, String key) async {
    if (i < 0 || i >= _sels.length) return;
    if (key == _sels[i].selected || _loading) return;
    setState(() {
      _sels[i].selected = key;
      _loading = true;
    });
    try {
      final page = widget.module['page']?.toString() ?? '';
      if (page.isEmpty) return;
      final params = <String, dynamic>{
        for (final s in _sels) s.key: s.selected,
      };
      final modules = await widget.plugin.page(page, params);
      Map<String, dynamic>? mod;
      for (final m in modules) {
        final mm = _asMap2(m);
        if (mm['type'] == 'selector') {
          mod = mm;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        if (mod != null) {
          final newSels = _parseSelectors(mod);
          if (newSels.isNotEmpty) _sels = newSels;
          _groups = _parseGroups(mod['groups']);
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _sels.length; i++) _selectorBar(context, i),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: PolygonRefreshIndicator(size: 24)),
          )
        else
          _PluginGroupList(plugin: widget.plugin, groups: _groups),
      ],
    );
  }

  Widget _selectorBar(BuildContext context, int index) {
    final sel = _sels[index];
    if (sel.options.isEmpty) return const SizedBox.shrink();
    final keys = sel.options.map((o) => o['key']?.toString() ?? '').toList();
    final titles = sel.options
        .map((o) => o['title']?.toString() ?? '')
        .toList();
    final cur = keys.indexOf(sel.selected);
    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) => IconButton(
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onTap : null,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      child: Row(
        children: [
          if (sel.arrows)
            arrow(
              Icons.chevron_left,
              cur > 0,
              () => _switch(index, keys[cur - 1]),
            ),
          Expanded(
            child: _CapsuleBar(
              keys: keys,
              titles: titles,
              selected: sel.selected,
              onChanged: (i) => _switch(index, keys[i]),
            ),
          ),
          if (sel.arrows)
            arrow(
              Icons.chevron_right,
              cur >= 0 && cur < keys.length - 1,
              () => _switch(index, keys[cur + 1]),
            ),
        ],
      ),
    );
  }
}

/// 详情页：由若干 section 组成（imageText / gallery / cards）
class _PluginDetailView extends StatelessWidget {
  const _PluginDetailView({required this.plugin, required this.module});

  final MePagePlugin plugin;
  final Map<String, dynamic> module;

  @override
  Widget build(BuildContext context) {
    final title = module['title']?.toString() ?? '';
    final sections = module['sections'] is List
        ? (module['sections'] as List)
              .map(_asMap2)
              .where((e) => e.isNotEmpty)
              .toList()
        : const <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        for (final s in sections) ...[
          _buildSection(context, s),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSection(BuildContext context, Map<String, dynamic> s) {
    switch (s['type']?.toString()) {
      case 'imageText':
        return _ImageTextSection(plugin: plugin, section: s);
      case 'gallery':
        return _GallerySection(plugin: plugin, section: s);
      case 'cards':
        return _CardsSection(plugin: plugin, section: s);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// 图片 + 文字组件；是否显示标题由插件 showTitle 控制（默认显示）。
/// 文字可复制，并带翻译按钮。
class _ImageTextSection extends StatefulWidget {
  const _ImageTextSection({required this.plugin, required this.section});

  final MePagePlugin plugin;
  final Map<String, dynamic> section;

  @override
  State<_ImageTextSection> createState() => _ImageTextSectionState();
}

class _ImageTextSectionState extends State<_ImageTextSection> {
  final TranslationController _tc = TranslationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    final section = widget.section;
    final title = section['title']?.toString() ?? '';
    final text = section['text']?.toString() ?? '';
    final image = section['image']?.toString() ?? '';
    final buttons = section['buttons'] is List
        ? (section['buttons'] as List)
              .map(_asMap2)
              .where(
                (e) => e.isNotEmpty && (e['url']?.toString() ?? '').isNotEmpty,
              )
              .toList()
        : const <Map<String, dynamic>>[];
    final showTitle = section['showTitle'] != false;
    final tag = 'plugin_imagetext_${plugin.key}_${identityHashCode(section)}';
    return _PluginCard(
      title: showTitle && title.isNotEmpty ? title : null,
      trailing: text.isEmpty
          ? null
          : TranslateIconButton(data: text, controller: _tc, iconSize: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image.isNotEmpty)
            GestureDetector(
              onTap: () => BangumiWidget.showImagePreview(
                context: App.rootContext,
                url: image,
                title: title.isEmpty ? plugin.name : title,
                imageProvider: _siteProvider(image, plugin: plugin),
                heroTag: tag,
              ),
              child: KostoriHero(
                tag: tag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: _siteImage(
                      image,
                      plugin: plugin,
                      height: 320,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          if (image.isNotEmpty && text.isNotEmpty) const SizedBox(height: 8),
          if (text.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: AppSelectableText(
                text,
                style: const TextStyle(fontSize: 13, height: 1.5),
                selectionWidthStyle: ui.BoxWidthStyle.tight,
                textWidthBasis: TextWidthBasis.longestLine,
              ),
            ),
          if (text.isNotEmpty)
            TranslationOutput(
              controller: _tc,
              padding: const EdgeInsets.only(top: 8),
            ),
          if (buttons.isNotEmpty) ...[
            if (text.isNotEmpty) const SizedBox(height: 10),
            CapsuleButtonBar(
              children: [
                for (final button in buttons)
                  CapsuleButton(
                    text:
                        button['label']?.toString() ??
                        Translations.of(context).open,
                    onTap: () => launchUrlString(button['url'].toString()),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 横向滑动的图片展示组件
class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.plugin, required this.section});

  final MePagePlugin plugin;
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final title = section['title']?.toString() ?? '';
    final images = section['images'] is List
        ? (section['images'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];
    if (images.isEmpty) return const SizedBox.shrink();
    // 每张图的稳定 Hero tag（与预览页各页一一对应）
    final tags = [
      for (var i = 0; i < images.length; i++)
        'plugin_gallery_${plugin.key}_${identityHashCode(section)}_$i',
    ];
    final providers = [
      for (final u in images) _siteProvider(u, plugin: plugin),
    ];
    return _PluginCard(
      title: title.isEmpty ? null : title,
      child: SizedBox(
        height: 260,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final url = images[i];
            final tag = tags[i];
            return GestureDetector(
              onTap: () => BangumiWidget.showImagePreview(
                context: App.rootContext,
                url: url,
                title: title.isEmpty ? plugin.name : title,
                imageProvider: providers[i],
                heroTag: tag,
                // 整组图一起传入 → 预览页可左右滑动浏览（像本地多图那样）
                initialIndex: i,
                galleryProviders: providers,
                galleryHeroTags: tags,
              ),
              child: KostoriHero(
                tag: tag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  // 按图片自身比例显示，完整不裁剪、不缩小
                  child: _siteImage(
                    url,
                    plugin: plugin,
                    height: 260,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 卡片组件（复用通用详细卡片），点击进入其详情页
class _CardsSection extends StatefulWidget {
  const _CardsSection({required this.plugin, required this.section});

  final MePagePlugin plugin;
  final Map<String, dynamic> section;

  @override
  State<_CardsSection> createState() => _CardsSectionState();
}

class _CardsSectionState extends State<_CardsSection> {
  late Map<String, dynamic> _section;
  final Map<int, Map<String, dynamic>> _pageCache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _section = widget.section;
    _pageCache[_numberFrom(widget.section, 'pageNum')] = _section;
  }

  int _numberFrom(
    Map<String, dynamic> section,
    String key, [
    int fallback = 1,
  ]) {
    final value = section[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int _number(String key, [int fallback = 1]) {
    return _numberFrom(_section, key, fallback);
  }

  Future<void> _loadPage(int page) async {
    if (_loading || page < 1 || page > _number('totalPages')) return;
    final pageName = _section['page']?.toString() ?? '';
    if (pageName.isEmpty) return;
    final cached = _pageCache[page];
    if (cached != null) {
      setState(() => _section = cached);
      return;
    }
    final rawParams = _asMap2(_section['params']);
    rawParams['page'] = page;
    setState(() => _loading = true);
    try {
      final modules = await widget.plugin.page(pageName, rawParams);
      Map<String, dynamic>? next;
      for (final module in modules) {
        final pageModule = _asMap2(module);
        if (pageModule['type'] != 'detailPage') continue;
        final sections = pageModule['sections'];
        if (sections is! List) continue;
        for (final value in sections) {
          final candidate = _asMap2(value);
          if (candidate['type'] == 'cards' &&
              candidate['title']?.toString() == _section['title']?.toString()) {
            next = candidate;
            break;
          }
        }
      }
      if (!mounted) return;
      final selected = next;
      if (selected != null) {
        _pageCache[page] = selected;
        setState(() => _section = selected);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _section['title']?.toString() ?? '';
    if (_section['variant']?.toString() == 'tags') {
      return _buildTagSection(context, title);
    }
    final cards = _section['cards'] is List
        ? (_section['cards'] as List)
              .map(_asMap2)
              .where((e) => e.isNotEmpty)
              .toList()
        : const <Map<String, dynamic>>[];
    final page = _number('pageNum');
    final totalPages = _number('totalPages');
    if (cards.isEmpty && !_loading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        if (_loading && cards.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: PolygonRefreshIndicator(size: 24)),
          ),
        for (final c in cards) ...[
          _GenericPluginCard(plugin: widget.plugin, item: c),
          const SizedBox(height: 12),
        ],
        if (totalPages > 1)
          _ForumPager(
            page: page,
            totalPages: totalPages,
            busy: _loading,
            onJump: _loadPage,
          ),
      ],
    );
  }

  Widget _buildTagSection(BuildContext context, String title) {
    final raw = _section['items'] is List
        ? _section['items'] as List
        : const [];
    final items = raw.map(_asMap2).where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        CapsuleChipGroup(
          children: [
            for (final item in items)
              CapsuleChip(
                text: item['title']?.toString() ?? '',
                isSelected: false,
                onTap: () {
                  final href = item['url']?.toString() ?? '';
                  final page = item['page']?.toString() ?? '';
                  if (page.isNotEmpty && href.isNotEmpty) {
                    final params = _asMap2(item['params']);
                    params['url'] = href;
                    params['title'] ??= item['title']?.toString() ?? '';
                    _pushPluginPage(context, widget.plugin, page, params);
                  } else if (href.isNotEmpty) {
                    launchUrlString(href);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// 渲染插件声明的 `layout: 'poster'` 卡片列表。
class _GenericPluginPosterCard extends StatelessWidget {
  const _GenericPluginPosterCard({required this.plugin, required this.item});

  final MePagePlugin plugin;
  final Map<String, dynamic> item;

  String _str(String key) => item[key]?.toString() ?? '';

  void _open(BuildContext context) {
    final page = item['page']?.toString() ?? 'detail';
    final params = item['params'] is Map
        ? _asMap2(item['params'])
        : <String, dynamic>{};
    if (item['url'] != null) params['url'] = item['url'].toString();
    final title = _str('title');
    if (title.isNotEmpty) params['title'] ??= title;
    _pushPluginPage(context, plugin, page, params, item: item);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _str('cover');
    final title = _str('title');
    final meta = item['meta'] is List
        ? (item['meta'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .take(2)
              .join(' · ')
        : '';
    final id = item['url']?.toString() ?? title;
    final heroTag = 'plugin_poster_${plugin.key}_${id.hashCode}';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: cover.isEmpty
                  ? Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : KostoriHero(
                      tag: heroTag,
                      child: _siteImage(
                        cover,
                        plugin: plugin,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 卡片列表页：可选选择器（含日期选择）+ 卡片列表 + 底部分页（复用论坛分页组件）。
/// 模块协议：
/// { type:'cardPage', page:'new', pageNum:1, totalPages:10,
///   selectors:[{key,options,selected,arrows}], datePicker:true, dateKey:'date',
///   items:[<card>], groups:[{header,items:[<card>]}], layout:'poster' }
class PluginCardPage extends StatefulWidget {
  const PluginCardPage({
    super.key,
    required this.plugin,
    required this.module,
    this.topPadding = 0,
  });

  final MePagePlugin plugin;
  final Map<String, dynamic> module;
  final double topPadding;

  @override
  State<PluginCardPage> createState() => _PluginCardPageState();
}

class _PluginCardPageState extends State<PluginCardPage> {
  late Map<String, dynamic> _module;
  late List<_SelectorState> _sels;
  final Map<String, Map<String, dynamic>> _pageCache = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _module = widget.module;
    _sels = _selParseSelectors(_module);
    _pageCache[_cacheKey(_pageNum)] = _module;
  }

  String _cacheKey(int page) =>
      '$page|${_sels.map((s) => '${s.key}=${s.selected}').join('&')}';

  int get _pageNum => (_module['pageNum'] as num?)?.toInt() ?? 1;

  int get _totalPages => (_module['totalPages'] as num?)?.toInt() ?? 1;

  bool get _posterLayout => _module['layout']?.toString() == 'poster';

  int _gridColumns(double width) {
    final requested = (_module['gridMaxColumns'] as num?)?.toInt() ?? 5;
    final minWidth = (_module['gridMinItemWidth'] as num?)?.toDouble() ?? 160;
    final available = (width / minWidth).floor();
    return available.clamp(2, requested).toInt();
  }

  String get _fetchPage => _module['page']?.toString() ?? '';

  Future<void> _fetch({int? page}) async {
    if (_fetchPage.isEmpty) return;
    final targetPage = page ?? 1;
    final params = <String, dynamic>{
      for (final s in _sels) s.key: s.selected,
      if (page != null) 'page': page,
    };
    final cached = _pageCache[_cacheKey(targetPage)];
    if (cached != null) {
      setState(() {
        _module = cached;
        final ns = _selParseSelectors(cached);
        if (ns.isNotEmpty) _sels = ns;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final modules = await widget.plugin.page(_fetchPage, params);
      Map<String, dynamic>? mod;
      for (final m in modules) {
        final mm = _asMap2(m);
        if (mm['type'] == 'cardPage') {
          mod = mm;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        if (mod != null) {
          _module = mod;
          final ns = _selParseSelectors(mod);
          if (ns.isNotEmpty) _sels = ns;
          _pageCache[_cacheKey(targetPage)] = mod;
        }
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(int i, String key) {
    if (i < 0 || i >= _sels.length || _sels[i].selected == key) return;
    setState(() => _sels[i].selected = key);
    _fetch();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    if (_sels.isEmpty) return;
    final dateKey = _module['dateKey']?.toString() ?? 'date';
    var idx = _sels.indexWhere((s) => s.key == dateKey);
    if (idx < 0) idx = 0;
    final cur = DateTime.tryParse(_sels[idx].selected) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _sels[idx].selected = _fmtDate(picked));
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _totalPages;
    final groups = _selGroups(_module['groups']);
    final items = _selGroups(_module['items']);
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12 + widget.topPadding,
              12,
              totalPages > 1 ? 84 : 24,
            ),
            children: [
              for (var i = 0; i < _sels.length; i++) _selectorBar(context, i),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: PolygonRefreshIndicator(size: 24)),
                )
              else if (groups.isNotEmpty)
                _PluginGroupList(plugin: widget.plugin, groups: groups)
              else if (items.isNotEmpty && _posterLayout)
                LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(constraints.maxWidth),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.68,
                    ),
                    itemBuilder: (context, index) => _GenericPluginPosterCard(
                      plugin: widget.plugin,
                      item: items[index],
                    ),
                  ),
                )
              else if (items.isNotEmpty)
                for (final it in items) ...[
                  _GenericPluginCard(plugin: widget.plugin, item: it),
                  const SizedBox(height: 12),
                ]
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('—')),
                ),
            ],
          ),
        ),
        if (totalPages > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _GlassBar(
              child: _ForumPager(
                page: _pageNum,
                totalPages: totalPages,
                busy: _loading,
                onJump: (p) => _fetch(page: p),
              ),
            ),
          ),
      ],
    );
  }

  Widget _selectorBar(BuildContext context, int index) {
    final sel = _sels[index];
    if (sel.options.isEmpty) return const SizedBox.shrink();
    final keys = sel.options.map((o) => o['key']?.toString() ?? '').toList();
    final titles = sel.options
        .map((o) => o['title']?.toString() ?? '')
        .toList();
    final cur = keys.indexOf(sel.selected);
    final showDate = _module['datePicker'] == true && index == 0;
    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) => IconButton(
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: enabled ? onTap : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (showDate)
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: t.jumpToPage,
              onPressed: _pickDate,
            ),
          if (sel.arrows)
            arrow(
              Icons.chevron_left,
              cur > 0,
              () => _select(index, keys[cur - 1]),
            ),
          Expanded(
            child: _CapsuleBar(
              keys: keys,
              titles: titles,
              selected: sel.selected,
              onChanged: (i) => _select(index, keys[i]),
            ),
          ),
          if (sel.arrows)
            arrow(
              Icons.chevron_right,
              cur >= 0 && cur < keys.length - 1,
              () => _select(index, keys[cur + 1]),
            ),
        ],
      ),
    );
  }
}
