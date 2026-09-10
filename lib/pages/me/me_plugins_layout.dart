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
// ═══════════════════════════════════════════════════════════

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

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: cover.isNotEmpty
                    ? _siteImage(
                        cover,
                        plugin: plugin,
                        width: 86,
                        height: 116,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 86,
                        height: 116,
                        color: cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
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
          const SizedBox(height: 8),
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

/// 图片 + 文字组件；是否显示标题由插件 showTitle 控制（默认显示）
class _ImageTextSection extends StatelessWidget {
  const _ImageTextSection({required this.plugin, required this.section});

  final MePagePlugin plugin;
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final title = section['title']?.toString() ?? '';
    final text = section['text']?.toString() ?? '';
    final image = section['image']?.toString() ?? '';
    final showTitle = section['showTitle'] != false;
    final tag = 'plugin_imagetext_${plugin.key}_${identityHashCode(section)}';
    return _PluginCard(
      title: showTitle && title.isNotEmpty ? title : null,
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
              child: Hero(
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
            Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
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
              child: Hero(
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
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
