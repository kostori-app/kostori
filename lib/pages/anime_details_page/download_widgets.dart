part of 'anime_page.dart';

/// 下载选集选择弹窗：多选/全选，已下载的集排除，确认后批量下载
/// 下载项统一抽象（剧集 epKey 或系列条目 id）
class _DownloadItem {
  final String key;

  final String title;

  final String subtitle;

  /// 下载记录里的 episode 字段（用于已下载标记）
  final String episodeName;

  /// 纯集号（数字索引时才有），用于“不使用集标题”命名
  final String? episodeNo;

  /// 封面所属源 key
  final String sourceKey;

  const _DownloadItem({
    required this.key,
    required this.title,
    this.subtitle = '',
    required this.episodeName,
    this.episodeNo,
    required this.sourceKey,
  });
}

/// 下载选择结果
class _DownloadPick {
  final String key;

  final String episodeName;

  /// 选定的番剧主标题（用户可在弹窗顶部编辑，覆盖文件名的 {title} 部分）
  final String? animeTitle;

  /// 纯集号（“不使用集标题”命名用）
  final String? episodeNo;

  /// 选定分辨率的 url（null = 使用默认）
  final String? url;

  /// 分辨率标签（如 1080p）
  final String? resolution;

  /// 下载分组（= 下载目录子目录，空 = 未分组）
  final String group;

  const _DownloadPick({
    required this.key,
    required this.episodeName,
    this.animeTitle,
    this.episodeNo,
    this.url,
    this.resolution,
    this.group = '',
  });
}

/// 下载分组选择弹层：选择 / 新建 / 删除分组
class _DownloadGroupSelectSheet extends StatefulWidget {
  const _DownloadGroupSelectSheet({required this.initial});

  final String initial;

  @override
  State<_DownloadGroupSelectSheet> createState() =>
      _DownloadGroupSelectSheetState();
}

class _DownloadGroupSelectSheetState extends State<_DownloadGroupSelectSheet> {
  late List<String> _groups = DownloadManager.groups();

  Future<void> _create() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.newGroup,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: InputDecoration(labelText: t.groupName),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final n = name?.trim() ?? '';
    if (n.isEmpty) return;
    await DownloadManager.createGroup(n);
    if (!mounted) return;
    setState(() => _groups = DownloadManager.groups());
    if (mounted) Navigator.of(context).pop(n);
  }

  Future<void> _delete(String name) async {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${t.deleteGroupConfirm}\n"$name"',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () async {
        await DownloadManager.instance.deleteGroup(name);
        if (mounted) setState(() => _groups = DownloadManager.groups());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget tile({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      Widget? trailing,
    }) => ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.folder_outlined,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(label),
      selected: selected,
      onTap: onTap,
      trailing: trailing,
    );
    return Sheet(
      title: t.downloadDir,
      icon: Icons.folder_outlined,
      initialSize: 0.55,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(t.newGroup),
            ),
          ),
        ),
      ),
      builder: (context, sc) => ListView(
        controller: sc,
        children: [
          tile(
            label: t.ungrouped,
            selected: widget.initial.isEmpty,
            onTap: () => Navigator.of(context).pop(''),
          ),
          for (final g in _groups)
            tile(
              label: g,
              selected: widget.initial == g,
              onTap: () => Navigator.of(context).pop(g),
              trailing: IconButton(
                tooltip: t.delete,
                icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                onPressed: () => _delete(g),
              ),
            ),
        ],
      ),
    );
  }
}

/// 卡片化下载选择弹窗：每集一张卡片（封面 + 标题 + 分辨率选择）
class _EpisodeDownloadPicker extends StatefulWidget {
  const _EpisodeDownloadPicker({
    required this.items,
    required this.downloaded,
    required this.resolvePlay,
    required this.animeTitle,
    required this.sourceKey,
    this.resolveAnimeTitle,
  });

  final List<_DownloadItem> items;

  /// 已下载的 episodeName 集合
  final Set<String> downloaded;

  /// 解析单集/系列条目的播放结果（获取多分辨率）
  final Future<AnimePlayResult?> Function(String key) resolvePlay;

  /// 番剧主标题（用于文件名的 {title}，可在弹窗内修改）
  final String animeTitle;

  /// 所属番源 key（决定可用文本规则）
  final String sourceKey;

  /// 系列条目：需单独访问其详情获取自身标题（用于命名）；剧集模式为 null
  final Future<String?> Function(String id)? resolveAnimeTitle;

  @override
  State<_EpisodeDownloadPicker> createState() => _EpisodeDownloadPickerState();
}

class _EpisodeDownloadPickerState extends State<_EpisodeDownloadPicker> {
  late final Set<String> selected;

  /// key → 选定分辨率（存 url + label）
  final Map<String, String?> _resolutionByKey = {};
  final Map<String, String?> _resolutionLabelByKey = {};

  /// key → 自定义标题（用于文件名；默认用 item.title）
  final Map<String, String> _nameOverrides = {};

  /// 番剧主标题（顶部输入框，可编辑，覆盖文件名的 {title} 部分）
  late String _animeTitle;
  late final TextEditingController _titleCtrl;

  /// 该源选用的文本规则
  late final List<TextRule> _rules;

  /// 原始番剧标题（未套用规则）
  late final String _originalTitle;

  /// 是否套用规则（一键开关）
  bool _useRules = false;

  /// 选定的下载分组（= 下载目录子目录），持久化上次选择
  late String _group;

  /// 按当前开关计算标题
  String _computedTitle() {
    if (_useRules && _rules.isNotEmpty) {
      return TextRuleStore.apply(_originalTitle, _rules);
    }
    return _originalTitle;
  }

  @override
  void initState() {
    super.initState();
    // 默认不选择任何集，避免误下载整部（尤其是大批量番剧）
    selected = <String>{};
    _rules = SourceTextRuleConfig.rulesFor(widget.sourceKey);
    _originalTitle = widget.animeTitle;
    _useRules = _rules.isNotEmpty;
    _animeTitle = _computedTitle();
    _titleCtrl = TextEditingController(text: _animeTitle);
    _group = readDownloadFilter(kDownloadDefaultGroupKey, '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _toggleRules() {
    setState(() {
      _useRules = !_useRules;
      _animeTitle = _computedTitle();
      _titleCtrl.text = _animeTitle;
    });
  }

  void _toggle(String key) {
    setState(() {
      if (!selected.add(key)) selected.remove(key);
    });
  }

  /// 打开分组选择弹层（可新建/删除分组）
  Future<void> _pickGroup() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadGroupSelectSheet(initial: _group),
    );
    if (result == null || !mounted) return;
    setState(() => _group = result);
    saveDownloadFilter(kDownloadDefaultGroupKey, _group);
  }

  /// 编辑下载标题（用于生成文件名，避免超长标题导致无法创建文件）
  Future<void> _editItemName(_DownloadItem item) async {
    final ctrl = TextEditingController(
      text: _nameOverrides[item.key] ?? item.title,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.rename,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(labelText: t.fileName),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              setState(() {
                if (name.isEmpty) {
                  _nameOverrides.remove(item.key);
                } else {
                  _nameOverrides[item.key] = name;
                }
              });
              Navigator.of(ctx).pop();
            },
            child: Text(t.apply),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  /// 默认清晰度：取最高清晰度（1080 > 720 > 480 …），而非列表第一个
  Future<VideoStreamInfo?> _bestStream(_DownloadItem item) async {
    try {
      final res = await widget.resolvePlay(item.key);
      final streams = (res?.videoStreams ?? const <VideoStreamInfo>[])
          .where((s) => s.url != null && s.url!.isNotEmpty)
          .toList();
      if (streams.isEmpty) return null;
      var best = streams.first;
      var bestScore = _resScore(best.label);
      for (final s in streams.skip(1)) {
        final score = _resScore(s.label);
        if (score > bestScore) {
          best = s;
          bestScore = score;
        }
      }
      return best;
    } catch (_) {}
    return null;
  }

  /// 从清晰度标签取排序分：无压缩的「原画/source」最高；
  /// 其余按分辨率数字（1080 > 720 > 480 …）；无数字记 0。
  int _resScore(String label) {
    final l = label.toLowerCase();
    const lossless = [
      'source',
      'original',
      '原画',
      '原畫',
      '原盘',
      '原盤',
      '无损',
      '無損',
      'blu-ray',
      'bluray',
      'bdrip',
      'remux',
    ];
    if (lossless.any(l.contains)) return 100000;
    final m = RegExp(r'(\d{3,4})').firstMatch(label);
    return m != null ? (int.tryParse(m.group(1)!) ?? 0) : 0;
  }

  /// 并发映射（带上限，避免同时打太多请求被源盯上）
  Future<List<T>> _mapConcurrent<T>(
    List<_DownloadItem> items,
    int limit,
    Future<T> Function(_DownloadItem item) fn,
  ) async {
    final results = List<T?>.filled(items.length, null);
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= items.length) return;
        results[i] = await fn(items[i]);
      }
    }

    final n = items.isEmpty ? 0 : limit.clamp(1, items.length);
    await Future.wait(List.generate(n, (_) => worker()));
    return results.cast<T>();
  }

  Future<void> _confirm() async {
    final selectedItems = widget.items
        .where((i) => selected.contains(i.key))
        .toList();
    // 并发（上限 4）：避免逐个串行过慢，同时不至于一次打太多请求
    final picks = await _mapConcurrent<_DownloadPick>(
      selectedItems,
      4,
      (item) async {
        var url = _resolutionByKey[item.key];
        var resLabel = _resolutionLabelByKey[item.key];
        // 未手动选清晰度：默认选最高清晰度（而非第一个）
        if (url == null) {
          final best = await _bestStream(item);
          if (best != null) {
            url = best.url;
            if (best.label.isNotEmpty) resLabel = best.label;
          }
        }
        // 系列条目：单独访问其详情取自身标题，避免全部用当前番剧标题命名
        String? itemTitle;
        final resolver = widget.resolveAnimeTitle;
        if (resolver != null) {
          try {
            itemTitle = await resolver(item.key);
          } catch (_) {}
        }
        final resolvedTitle = (itemTitle != null && itemTitle.trim().isNotEmpty)
            ? itemTitle.trim()
            : (_animeTitle.trim().isEmpty ? null : _animeTitle.trim());
        return _DownloadPick(
          key: item.key,
          // 用户编辑过标题时用它（用于文件名），否则用原始集名
          episodeName: _nameOverrides[item.key] ?? item.episodeName,
          animeTitle: resolvedTitle,
          episodeNo: item.episodeNo,
          url: url,
          resolution: resLabel,
          group: _group,
        );
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop(picks);
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = selected.length == widget.items.length;
    return Sheet(
      title: t.downloadEpisode,
      icon: Icons.download_outlined,
      initialSize: 0.7,
      headerTrailing: TextButton(
        onPressed: () => setState(() {
          if (allSelected) {
            selected.clear();
          } else {
            selected.addAll(widget.items.map((e) => e.key));
          }
        }),
        child: Text(allSelected ? t.selectNone : t.selectAll),
      ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: selected.isEmpty ? null : _confirm,
              child: Text(t.downloadSelectedCount(n: selected.length)),
            ),
          ),
        ),
      ),
      builder: (context, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          // 番剧主标题：可编辑，作为所有选中项文件名的 {title} 前缀
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: TextField(
              controller: _titleCtrl,
              onChanged: (v) => _animeTitle = v,
              // 不限制行数：完整展示标题，方便手动修改
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: t.downloadMainTitle,
                alignLabelWithHint: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title, size: 18),
                // 一键切换是否套用文本规则；无规则时不显示
                suffixIcon: _rules.isEmpty
                    ? null
                    : IconButton(
                        tooltip: _useRules
                            ? t.textRuleApplied
                            : t.textRuleNotApplied,
                        icon: Icon(
                          Icons.rule,
                          size: 20,
                          color: _useRules
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        onPressed: _toggleRules,
                      ),
              ),
            ),
          ),
          // 下载分组（= 下载目录子目录）：点击打开选择弹层（可新建/删除）
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickGroup,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: t.downloadDir,
                  isDense: true,
                  prefixIcon: const Icon(Icons.folder_outlined, size: 18),
                  suffixIcon: const Icon(Icons.chevron_right, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _group.isEmpty ? t.ungrouped : _group,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          for (final item in widget.items)
            _DownloadItemCard(
              item: item,
              displayTitle: _nameOverrides[item.key] ?? item.title,
              isDownloaded: widget.downloaded.contains(item.episodeName),
              isSelected: selected.contains(item.key),
              resolutionLabel: _resolutionLabelByKey[item.key],
              onToggle: () => _toggle(item.key),
              onEditName: () => _editItemName(item),
              onResolution: (url, label) => setState(() {
                _resolutionByKey[item.key] = url;
                _resolutionLabelByKey[item.key] = label;
              }),
              resolvePlay: widget.resolvePlay,
              // 已下载条目：重下 = 重新勾选（再次下载会覆盖）
              onRedownload: () => setState(() {
                if (!selected.add(item.key)) selected.remove(item.key);
              }),
            ),
        ],
      ),
    );
  }
}

/// 单个下载项卡片：封面 + 标题/副标题 + 分辨率选择
class _DownloadItemCard extends StatefulWidget {
  const _DownloadItemCard({
    required this.item,
    required this.displayTitle,
    required this.isDownloaded,
    required this.isSelected,
    required this.resolutionLabel,
    required this.onToggle,
    required this.onEditName,
    required this.onResolution,
    required this.resolvePlay,
    required this.onRedownload,
  });

  final _DownloadItem item;

  /// 显示标题（用户编辑后为其自定义名）
  final String displayTitle;

  final bool isDownloaded;

  final bool isSelected;

  final String? resolutionLabel;

  final VoidCallback onToggle;

  /// 编辑标题（改文件名用）
  final VoidCallback onEditName;

  final void Function(String url, String label) onResolution;

  final Future<AnimePlayResult?> Function(String key) resolvePlay;

  /// 已下载时重新下载（重新勾选）
  final VoidCallback onRedownload;

  @override
  State<_DownloadItemCard> createState() => _DownloadItemCardState();
}

class _DownloadItemCardState extends State<_DownloadItemCard> {
  bool _resolving = false;

  /// 解析多分辨率并弹出选择（只有一种分辨率时提示无更多可选）
  Future<void> _pickResolution() async {
    if (_resolving || widget.isDownloaded) return;
    setState(() => _resolving = true);
    final result = await widget.resolvePlay(widget.item.key);
    if (!mounted) return;
    setState(() => _resolving = false);
    final options = (result?.videoStreams ?? const <VideoStreamInfo>[])
        .where((s) => s.url != null && s.url!.isNotEmpty)
        .toList();
    if (options.length <= 1) {
      App.rootContext.showMessage(message: t.noResolutionAvailable);
      return;
    }
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.selectResolution,
        icon: Icons.high_quality_outlined,
        initialSize: 0.45,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            for (var i = 0; i < options.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.high_quality_outlined),
                title: Text(options[i].label),
                trailing: options[i].label == widget.resolutionLabel
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (index == null || !mounted) return;
    widget.onResolution(options[index].url!, options[index].label);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: widget.isDownloaded
            ? colorScheme.surfaceContainerHigh
            : (widget.isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : colorScheme.surfaceContainerLow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: widget.isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: widget.isSelected ? 1.5 : 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.isDownloaded ? null : widget.onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  widget.isSelected
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: widget.isDownloaded
                      ? colorScheme.outline
                      : (widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant),
                ),
                const SizedBox(width: 8),
                // 标题 + 副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 分辨率选择 / 已下载标记（已下载可重下）
                if (widget.isDownloaded)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.download_done,
                        size: 20,
                        color: Colors.green,
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: t.redownload,
                        icon: const Icon(Icons.refresh, size: 18),
                        color: colorScheme.primary,
                        onPressed: widget.onRedownload,
                      ),
                    ],
                  )
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: _pickResolution,
                    icon: _resolving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: PolygonRefreshIndicator(),
                          )
                        : const Icon(Icons.high_quality_outlined, size: 16),
                    label: Text(
                      widget.resolutionLabel ?? t.defaultResolution,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                // 编辑标题（超长标题影响建文件名时改短）
                if (!widget.isDownloaded)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: t.rename,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: widget.onEditName,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
