part of 'me_page_plugins.dart';

// ═══════════════════════════════════════════════════════════
// 通用布局：分组卡片 / 选择器（类月份表）/ 详情页
//
// 模块协议（均由插件 JS 下发）：
//
// 1) 分组卡片列表
//    { type:'groupPage', groups:[
//        { header:{type:'groupHeader', title, subtitle}, items:[<card>, ...] },
//        ...
//    ]}
//
// 2) 选择器页（类似月份表，可快捷切换多组数据）
//    { type:'selector', page:'preview',        // 切换时重新请求的 page 名
//      selectors:[ {key:'genre', options:[{key,title}], selected:'k'},
//                  {key:'month', options:[{key,title}], selected:'k'} ],
//      groups:[...] }
//    切换时调用 plugin.page(page, {genre:..., month:...})，期望返回同样结构的 selector 模块。
//    也兼容单选择器写法：options:[...] + selected（键名为 selection）。
//
// 3) 详情页
//    { type:'detailPage', title?, sections:[
//        { type:'imageText', title?, text?, image?, showTitle?:true },
//        { type:'gallery', title?, images:[url,...] },
//        { type:'cards', title?, cards:[<card>, ...] },
//    ]}
//
// <card> 字段：cover / title / subtitle / description / tags[] / meta[] /
//              rating / ratingMax / badge / page / params / url
//              buttons:[{ label, images?|image?|url?|text?|page?+params?,
//                         sheet?:true }]
//   sheet:true 时调用 plugin.page(page,params)，收集其中图片用底部弹层展示，
//   不跳转新页面（适合“预览图”这类按需解析的轻量动作）。
// ═══════════════════════════════════════════════════════════

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
class _PluginImagesSheet extends StatelessWidget {
  const _PluginImagesSheet({
    required this.plugin,
    required this.title,
    required this.future,
  });

  final MePagePlugin plugin;
  final String title;
  final Future<List<dynamic>> future;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: FutureBuilder<List<dynamic>>(
          future: future,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final images = snap.hasData
                ? _imagesFromModules(snap.data!)
                : const <String>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title.isEmpty ? plugin.name : title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (loading)
                  const SizedBox(
                    height: 200,
                    child: Center(child: PolygonRefreshIndicator(size: 28)),
                  )
                else if (images.isEmpty)
                  const SizedBox(height: 120, child: Center(child: Text('—')))
                else
                  SizedBox(
                    height: 260,
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
                            heroTag: 'plugin_sheet_${plugin.key}_${u.hashCode}',
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _siteImage(
                              u,
                              plugin: plugin,
                              height: 260,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
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

  Future<void> _buttonTap(BuildContext context, Map<String, dynamic> btn) async {
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
          content: SingleChildScrollView(child: SelectableText(text)),
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
    final label = btn['label']?.toString() ?? '...';
    return SizedBox(
      width: 76,
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
    final description = item['description']?.toString() ??
        item['summary']?.toString() ??
        '';
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
              child: Icon(
                Icons.image_outlined,
                color: cs.onSurfaceVariant,
              ),
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
            selected: sm['selected']?.toString() ?? opts.first['key'].toString(),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    // 完整显示且尽量放大
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
            // 可选中复制
            SelectableText(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          if (text.isNotEmpty)
            TranslationOutput(
              controller: _tc,
              padding: const EdgeInsets.only(top: 8),
            ),
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
            final tag =
                'plugin_gallery_${plugin.key}_${identityHashCode(section)}_$i';
            return GestureDetector(
              onTap: () => BangumiWidget.showImagePreview(
                context: App.rootContext,
                url: url,
                title: title.isEmpty ? plugin.name : title,
                imageProvider: _siteProvider(url, plugin: plugin),
                heroTag: tag,
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
class _CardsSection extends StatelessWidget {
  const _CardsSection({required this.plugin, required this.section});

  final MePagePlugin plugin;
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final title = section['title']?.toString() ?? '';
    final cards = section['cards'] is List
        ? (section['cards'] as List)
              .map(_asMap2)
              .where((e) => e.isNotEmpty)
              .toList()
        : const <Map<String, dynamic>>[];
    if (cards.isEmpty) return const SizedBox.shrink();
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
        for (final c in cards) ...[
          _GenericPluginCard(plugin: plugin, item: c),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// 卡片列表页：可选选择器（含日期选择）+ 卡片列表 + 底部分页（复用论坛分页组件）。
/// 模块协议：
/// { type:'cardPage', page:'new', pageNum:1, totalPages:10,
///   selectors:[{key,options,selected,arrows}], datePicker:true, dateKey:'date',
///   items:[<card>], groups:[{header,items:[<card>]}] }
class PluginCardPage extends StatefulWidget {
  const PluginCardPage({super.key, required this.plugin, required this.module});

  final MePagePlugin plugin;
  final Map<String, dynamic> module;

  @override
  State<PluginCardPage> createState() => _PluginCardPageState();
}

class _PluginCardPageState extends State<PluginCardPage> {
  late Map<String, dynamic> _module;
  late List<_SelectorState> _sels;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _module = widget.module;
    _sels = _selParseSelectors(_module);
  }

  int get _pageNum => (_module['pageNum'] as num?)?.toInt() ?? 1;

  int get _totalPages => (_module['totalPages'] as num?)?.toInt() ?? 1;

  String get _fetchPage => _module['page']?.toString() ?? '';

  Future<void> _fetch({int? page}) async {
    if (_fetchPage.isEmpty) return;
    final params = <String, dynamic>{
      for (final s in _sels) s.key: s.selected,
      if (page != null) 'page': page,
    };
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
            padding: EdgeInsets.fromLTRB(12, 12, 12, totalPages > 1 ? 84 : 24),
            children: [
              for (var i = 0; i < _sels.length; i++) _selectorBar(context, i),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: PolygonRefreshIndicator(size: 24)),
                )
              else if (groups.isNotEmpty)
                _PluginGroupList(plugin: widget.plugin, groups: groups)
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