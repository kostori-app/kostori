part of 'anime_page.dart';

/// 下载选集选择弹窗：多选/全选，已下载的集排除，确认后批量下载
/// 下载项统一抽象（剧集 epKey 或系列条目 id）
class _DownloadItem {
  final String key;

  /// 下载记录归属的番剧 id：剧集 = 当前页 id，系列 = 该系列条目自身 id
  /// （系列里同名条目靠它区分，避免互相覆盖 / 误标已下载）
  final String animeId;

  final String title;

  final String subtitle;

  /// 下载记录里的 episode 字段（用于已下载标记）
  final String episodeName;

  /// 纯集号（数字索引时才有），用于“不使用集标题”命名
  final String? episodeNo;

  /// 封面所属源 key
  final String sourceKey;

  /// 是否为当前 anime page 对应的条目（系列下载时用于置顶/标记）
  final bool isCurrent;

  const _DownloadItem({
    required this.key,
    required this.animeId,
    required this.title,
    this.subtitle = '',
    required this.episodeName,
    this.episodeNo,
    required this.sourceKey,
    this.isCurrent = false,
  });
}

/// 下载选择弹窗的筛选：全部 / 未下载 / 下载中 / 已下载
enum _DownloadFilter { all, notDownloaded, downloading, downloaded }

/// 下载选择结果
class _DownloadPick {
  final String key;

  final String animeId;

  final String episodeName;

  /// 集名的原始值（套用规则/改名之前）：随任务存入记录，
  /// 规则开关变化后仍能命中“已下载”
  final String episodeRaw;

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
    required this.animeId,
    required this.episodeName,
    required this.episodeRaw,
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
  /// 新建分组：可选上级分组（顶层 / 某个顶层组），即支持新建子组
  Future<void> _create() async {
    final ctrl = TextEditingController();
    var parent = '';
    final roots = DownloadManager.rootGroups();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => ContentDialog(
          title: t.newGroup,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                decoration: InputDecoration(labelText: t.groupName),
              ),
              if (roots.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  t.downloadGroupParent,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                CapsuleOptions(
                  alignment: WrapAlignment.start,
                  children: [
                    CapsuleOption(
                      text: t.downloadGroupRoot,
                      isSelected: parent.isEmpty,
                      onTap: () => setDlg(() => parent = ''),
                    ),
                    for (final g in roots)
                      CapsuleOption(
                        text: g,
                        isSelected: parent == g,
                        onTap: () => setDlg(() => parent = g),
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t.confirm),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    final n = name?.trim() ?? '';
    if (n.isEmpty) return;
    // 两层限制：父只能选顶层；同名时报错
    final full = DownloadManager.childName(parent, n);
    if (DownloadManager.groups().contains(full)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    await DownloadManager.createGroup(full);
    if (!mounted) return;
    Navigator.of(context).pop(full);
  }

  Future<void> _delete(String name) async {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${t.deleteGroupConfirm}\n"$name"',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () async {
        await DownloadManager.instance.deleteGroup(name);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Sheet(
      title: t.downloadDir,
      icon: Icons.folder_outlined,
      initialSize: 0.6,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: CapsuleButton(
            primary: true,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: const Icon(Icons.add),
            text: t.newGroup,
            onTap: _create,
          ),
        ),
      ),
      // 与「移动到文件夹」同一套：搜索 + 全部/未分组/顶层/子组 + 层级列表
      builder: (context, sc) => DownloadGroupPickerBody(
        current: widget.initial,
        scrollController: sc,
        onSelected: (g) => Navigator.of(context).pop(g),
        trailingBuilder: (g) => IconButton(
          tooltip: t.delete,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
          onPressed: () => _delete(g),
        ),
      ),
    );
  }
}

/// 卡片化下载选择弹窗：每集一张卡片（封面 + 标题 + 分辨率选择）
class _EpisodeDownloadPicker extends StatefulWidget {
  const _EpisodeDownloadPicker({
    required this.items,
    required this.downloadedFiles,
    required this.activeTasks,
    required this.resolvePlay,
    required this.animeTitle,
    required this.sourceKey,
    this.resolveAnimeTitle,
  });

  final List<_DownloadItem> items;

  /// `animeId|episodeName` → 本地文件路径（仅文件仍存在的已下载项）
  final Map<String, String> downloadedFiles;

  /// `animeId|episodeName` → 已在下载列表里的任务状态（排队/下载中/暂停/失败）
  final Map<String, DownloadStatus> activeTasks;

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

  /// 该源默认选用的文本规则（源内配置）
  late final List<TextRule> _defaultRules;

  /// Q10：手动选择的文本规则 id（null = 用源内默认）；
  /// 下载选择器内可手动指定一条规则覆盖源内配置
  String? _manualRuleId;

  /// 实际生效的规则：手动选择优先，否则源内默认
  List<TextRule> get _rules {
    final manual = _manualRuleId;
    if (manual != null) {
      final r = TextRuleStore.byId(manual);
      return r == null ? const [] : [r];
    }
    return _defaultRules;
  }

  /// 原始番剧标题（未套用规则）
  late final String _originalTitle;

  /// 是否套用规则（一键开关）
  bool _useRules = false;

  /// 选定的下载分组（= 下载目录子目录），持久化上次选择
  late String _group;

  /// 当前筛选：全部 / 未下载 / 已下载
  _DownloadFilter _filter = _DownloadFilter.all;

  bool _isDownloaded(_DownloadItem item) =>
      widget.downloadedFiles.containsKey('${item.animeId}|${_itemName(item)}') ||
      // 规则开关/改名后：记录里同时存了原始名，按原始名也能命中
      widget.downloadedFiles.containsKey(
        '${item.animeId}|${item.episodeName}',
      );

  /// 该条目是否已经在下载列表里（避免重复下载）：
  /// 任务存的是确认瞬间的集名，规则开关/改名后按下当前名查不到，
  /// 同 _isDownloaded 做双键回退
  DownloadStatus? _activeStatusOf(_DownloadItem item) =>
      widget.activeTasks['${item.animeId}|${_itemName(item)}'] ??
      widget.activeTasks['${item.animeId}|${item.episodeName}'];

  bool _isActive(_DownloadItem item) => _activeStatusOf(item) != null;

  String _statusLabel(DownloadStatus status) => switch (status) {
    DownloadStatus.queued => t.downloadQueued,
    DownloadStatus.paused => t.paused,
    DownloadStatus.failed => t.failed,
    _ => t.downloading,
  };

  /// 套用文本规则（开关关闭或无规则时原样返回）；
  /// Q10 单一应用：多条规则按优先级，第一条命中即停
  String _applyRules(String input) =>
      (_useRules && _rules.isNotEmpty)
      ? TextRuleStore.applyFirstHit(input, _rules)
      : input;

  /// 规则是否至少命中了一处（主标题或任一条目）：开关开着但零匹配时，
  /// 标题看起来“没变化”，必须明确提示，否则用户以为开关坏了。
  /// 注意用原始名比较，不受手动重命名（_nameOverrides）干扰。
  bool get _rulesMatched {
    if (!_useRules || _rules.isEmpty) return true;
    if (_applyRules(_originalTitle) != _originalTitle) return true;
    for (final item in widget.items) {
      if (_applyRules(item.episodeName) != item.episodeName) return true;
    }
    return false;
  }

  /// 番剧主标题（顶部输入框）：原始标题套用规则后的结果
  String _computedTitle() => _applyRules(_originalTitle);

  /// 条目标题（列表展示 / 文件名 / 去重标记）：手动重命名优先，
  /// 其次套用文本规则（与主标题一致，否则列表显示的是未清洗的原始标题）
  String _itemName(_DownloadItem item) {
    final override = _nameOverrides[item.key];
    if (override != null) return override;
    return _applyRules(item.episodeName);
  }

  @override
  void initState() {
    super.initState();
    // 默认不选择任何集，避免误下载整部（尤其是大批量番剧）
    selected = <String>{};
    _defaultRules = SourceTextRuleConfig.rulesFor(widget.sourceKey);
    _originalTitle = widget.animeTitle;
    _useRules = _defaultRules.isNotEmpty;
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
    final ctrl = TextEditingController(text: _itemName(item));
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
            // 系列条目取到的是源里的原始标题：同样要套用文本规则，
            // 否则加了规则后文件名仍是清洗前的标题
            ? _applyRules(itemTitle.trim())
            : (_animeTitle.trim().isEmpty ? null : _animeTitle.trim());
        return _DownloadPick(
          key: item.key,
          animeId: item.animeId,
          // 用户编辑过标题时用它（用于文件名），否则用集名（套用规则后）
          episodeName: _itemName(item),
          // 原始集名一并带上：记录双键，规则开关/改名后仍判已下载
          episodeRaw: item.episodeName,
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
    final visibleItems = widget.items.where((item) {
      final downloaded = _isDownloaded(item);
      final active = _isActive(item);
      return switch (_filter) {
        _DownloadFilter.all => true,
        _DownloadFilter.notDownloaded => !downloaded && !active,
        _DownloadFilter.downloading => active,
        _DownloadFilter.downloaded => downloaded,
      };
    }).toList();
    // 已下载 / 已在下载列表里的条目不可勾选，全选只作用于当前筛选下可下载项
    final selectable = visibleItems
        .where((item) => !_isDownloaded(item) && !_isActive(item))
        .toList();
    final allSelected =
        selectable.isNotEmpty &&
        selectable.every((item) => selected.contains(item.key));
    return Sheet(
      title: t.downloadEpisode,
      icon: Icons.download_outlined,
      initialSize: 0.7,
      headerTrailing: CapsuleButton(
        text: allSelected ? t.selectNone : t.selectAll,
        enabled: selectable.isNotEmpty,
        onTap: () => setState(() {
          if (allSelected) {
            selected.removeAll(selectable.map((e) => e.key));
          } else {
            selected.addAll(selectable.map((e) => e.key));
          }
        }),
      ),
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: CapsuleButton(
            primary: true,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            enabled: selected.isNotEmpty,
            text: t.downloadSelectedCount(n: selected.length),
            onTap: _confirm,
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
                // 一键切换是否套用文本规则；Q10：可手动指定一条规则覆盖源内默认
                suffixIcon: TextRuleStore.rules.isEmpty
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PopupMenuButton<String?>(
                            tooltip: t.textRuleApply,
                            icon: Icon(
                              Icons.rule_folder_outlined,
                              size: 20,
                              color: _manualRuleId != null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (v) => setState(() {
                              _manualRuleId = v;
                              _useRules = _rules.isNotEmpty;
                              _animeTitle = _computedTitle();
                              _titleCtrl.text = _animeTitle;
                            }),
                            itemBuilder: (_) => [
                              PopupMenuItem<String?>(
                                value: null,
                                child: Text(
                                  '${t.textRuleApply} (${_defaultRules.length})',
                                ),
                              ),
                              for (final r in TextRuleStore.rules)
                                PopupMenuItem<String?>(
                                  value: r.id,
                                  child: Text(
                                    r.name.isEmpty ? t.textRuleName : r.name,
                                  ),
                                ),
                            ],
                          ),
                          IconButton(
                            tooltip: _useRules
                                ? t.textRuleApplied
                                : t.textRuleNotApplied,
                            icon: Icon(
                              Icons.rule,
                              size: 20,
                              color: _useRules
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            onPressed: _toggleRules,
                          ),
                        ],
                      ),
              ),
            ),
          ),
          // 规则开着但对当前标题/条目零匹配：明确提示，否则看起来像开关坏了
          if (!_rulesMatched)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                t.textRuleNoMatch,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
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
          // Q9：当前下载目录存储空间（总量/剩余 + 进度条）
          const StorageBar(dense: true),
          // 筛选：全部 / 未下载 / 下载中 / 已下载
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SegmentedButton<_DownloadFilter>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _DownloadFilter.all,
                  label: Text(t.all),
                ),
                ButtonSegment(
                  value: _DownloadFilter.notDownloaded,
                  label: Text(t.downloadNotDownloaded),
                ),
                ButtonSegment(
                  value: _DownloadFilter.downloading,
                  label: Text(t.downloading),
                ),
                ButtonSegment(
                  value: _DownloadFilter.downloaded,
                  label: Text(t.downloadDownloaded),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          if (visibleItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  t.noData,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            for (final item in visibleItems)
              _DownloadItemCard(
                item: item,
                displayTitle: _itemName(item),
                isDownloaded: _isDownloaded(item),
                activeLabel: switch (_activeStatusOf(item)) {
                  final DownloadStatus s => _statusLabel(s),
                  null => null,
                },
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
    this.activeLabel,
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

  /// 已在下载列表里时的状态文案（下载中/排队/暂停/失败）
  final String? activeLabel;

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
        // 已下载（且文件仍在）：绿色调高亮，点击播放本地文件
        color: widget.isDownloaded
            ? Colors.green.withValues(alpha: 0.12)
            : (widget.activeLabel != null
                  ? colorScheme.tertiaryContainer.withValues(alpha: 0.25)
                  : (widget.isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : colorScheme.surfaceContainerLow)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: widget.isDownloaded
                ? Colors.green.withValues(alpha: 0.6)
                : (widget.activeLabel != null
                      ? colorScheme.tertiary
                      : (widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant)),
            width: widget.isSelected ? 1.5 : (widget.isDownloaded ? 1.0 : 0.6),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: (widget.isDownloaded || widget.activeLabel != null)
              ? null
              : widget.onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 标题 + 副标题
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.displayTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (item.isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t.current,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                // 右侧控件固定宽度 + 右对齐：各卡片的控件列对齐
                SizedBox(
                  width: 160,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 已在下载列表里：显示状态（避免重复下载）
                      if (widget.activeLabel != null)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.downloading,
                                  size: 14,
                                  color: colorScheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.activeLabel!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      // 分辨率选择 / 已下载标记（已下载可重下）
                      else if (widget.isDownloaded) ...[
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
                      ] else
                        Flexible(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: _pickResolution,
                            icon: _resolving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: PolygonRefreshIndicator(),
                                  )
                                : const Icon(
                                    Icons.high_quality_outlined,
                                    size: 16,
                                  ),
                            label: Text(
                              widget.resolutionLabel ?? t.defaultResolution,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      // 编辑标题（超长标题影响建文件名时改短）
                      if (!widget.isDownloaded && widget.activeLabel == null)
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 解析单集/系列条目的播放结果（String 或 AnimePlayResult），下载流程共用
Future<AnimePlayResult?> resolveAnimePlayResult(
  AnimeSource source,
  String dataId,
  String epKey,
) async {
  final loadPages = source.loadAnimePages;
  if (loadPages == null) return null;
  final res = await loadPages(dataId, epKey);
  if (res is! Map) return null;
  try {
    return AnimePlayResult.fromJson(Map<String, dynamic>.from(res));
  } catch (_) {
    return null;
  }
}

/// 解析最终下载地址（已给定的 url 优先；blob/空视为不可下载）
Future<String?> resolveAnimeEpisodeUrl({
  required AnimeSource source,
  required String dataId,
  required String epKey,
  String? url,
}) async {
  if (url != null && url.isNotEmpty && !url.startsWith('blob:')) return url;
  final loadPages = source.loadAnimePages;
  if (loadPages == null) return null;
  final res = await loadPages(dataId, epKey);
  if (res is String) return res;
  if (res is Map) {
    try {
      return AnimePlayResult.fromJson(Map<String, dynamic>.from(res)).url;
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// 入队一部剧集：落盘命名/文本规则/历史行为与详情页下载一致，
/// 返回 task（null 表示失败，内部已提示）
Future<DownloadTask?> enqueueAnimeEpisode({
  required AnimeSource source,
  required String animeId,
  required String dataId,
  required String epKey,
  required String epName,
  String? url,
  String? resolution,
  String? animeTitle,
  String? displayTitle,
  String? cover,
  String? uploader,
  String? episodeNo,
  String? episodeRaw,
  String? group,
}) async {
  final targetUrl = await resolveAnimeEpisodeUrl(
    source: source,
    dataId: dataId,
    epKey: epKey,
    url: url,
  );
  if (targetUrl == null ||
      targetUrl.isEmpty ||
      targetUrl.startsWith('blob:')) {
    App.rootContext.showMessage(message: t.downloadFailed);
    return null;
  }
  final task = await DownloadManager.instance.enqueue(
    url: targetUrl,
    title: animeTitle ?? displayTitle ?? epName,
    subtitle: epName,
    cover: cover,
    sourceKey: source.key,
    animeId: animeId,
    animeTitle: animeTitle ?? displayTitle ?? epName,
    episode: epName,
    episodeRaw: episodeRaw ?? epName,
    episodeNo: episodeNo,
    author: uploader,
    headers: source.httpHeaders ?? const {},
    resolution: resolution,
    group: group,
  );
  // 并发未满时任务已立即开始（status 已切 downloading），
  // 排队中则提示等待，给用户明确反馈
  App.rootContext.showMessage(
    message: task != null && task.status == DownloadStatus.queued
        ? t.downloadQueued
        : t.downloadStarted,
  );
  return task;
}

/// `animeId|episode` → 未完成任务的当前状态（下载中/排队/暂停/失败），
/// 供下载面板标记「已在下载列表」，避免重复下载
Map<String, DownloadStatus> activeDownloadTasksOf(String sourceKey) {
  final out = <String, DownloadStatus>{};
  for (final task in DownloadManager.instance.tasks) {
    if (task.status == DownloadStatus.completed) continue;
    if (task.sourceKey != sourceKey) continue;
    final animeId = task.animeId;
    final episode = task.episode;
    if (animeId == null || episode == null) continue;
    out.putIfAbsent('$animeId|$episode', () => task.status);
  }
  return out;
}

/// 列表卡片右键/长按菜单的“下载”：在外层直接拉起与详情页**同款**下载选择器
///（文本规则/分组/清晰度/筛选/已下载判定逻辑完全一致）。
/// 同时写入一条历史，之后能在历史页找到该番剧，避免“下了但找不到”。
Future<void> openAnimeDownloadPicker(Anime anime) async {
  final source = AnimeSource.find(anime.sourceKey);
  if (source == null) return;
  final context = App.rootContext;
  // 先弹 loading 再请求：详情/系列两段网络可能各花几秒，黑等会被当成没点上。
  // loading 可取消（取消按钮/点外部）：每个网络等待后都检查，中断后不再
  // 写历史、不开选择器（JS/网络请求本身停不掉，但结果会被丢弃）。
  var cancelled = false;
  final loading = showLoadingDialog(
    context,
    barrierDismissible: true,
    allowCancel: true,
    onCancel: () => cancelled = true,
    message: anime.title,
  );
  bool gone() => cancelled || loading.closed;
  try {
    AnimeDetails? data;
    Object? infoError;
    // Q7：加载 Massively 展示当前步骤
    loading.setMessage('${anime.title} · ${t.downloadStepLoadingInfo}');
    try {
      data = (await source.loadAnimeInfo?.call(anime.id))?.dataOrNull;
    } catch (e) {
      infoError = e;
    }
    if (gone()) return;
    if (data == null) {
      // Q7：错误也要有报告（原因写进提示，而不是只有“下载失败”）
      final detail = infoError?.toString().split('\n').first ?? '';
      context.showMessage(
        message: detail.isEmpty
            ? t.downloadFailed
            : '${t.downloadFailed}: $detail',
        level: LogLevel.error,
      );
      return;
    }
    if (gone()) return;
    final episode = data.episode;
    if (episode == null || episode.isEmpty || episode.values.first.isEmpty) {
      loading.setMessage('${data.title} · ${t.downloadStepResolving}');
      await _openSeriesDownloadPicker(
        context,
        source,
        data,
        anime.id,
        coverFallback: anime.cover,
        isCancelled: gone,
      );
      return;
    }
    final eps = episode.values.first;
    final items = <_DownloadItem>[
      for (final e in eps.entries)
        () {
          final title = AnimeDetails.episodeTitleOf(e.value);
          final name = title.isEmpty ? t.episodeN(n: e.key) : title;
          final keyStr = e.key.toString();
          return _DownloadItem(
            key: keyStr,
            animeId: anime.id,
            title: name,
            subtitle: '',
            episodeName: name,
            episodeNo: int.tryParse(keyStr) != null ? keyStr : null,
            sourceKey: anime.sourceKey,
          );
        }(),
    ];
    // Q7：历史推后到分集解析完成、选择器打开前再写，
    // 此时已知集数信息，避免早写导致历史条目内容为空（0/0）
    await _writeDownloadHistory(data, anime.cover);
    if (gone()) return;
    await _openAnimeDownloadPicker(
      context,
      source: source,
      data: data,
      animeTitle: data.title,
      items: items,
      isCancelled: gone,
    );
  } finally {
    // 选择器已接管界面（或已失败/取消）：loading 必须收掉，
    // 否则它盖在选择器上面
    loading.close();
  }
}

/// 卡片入口下载流程写历史（推后到分集就绪后调用）：
/// 入口封面兜底（详情接口可能不返 cover），之后历史页可回找。
Future<void> _writeDownloadHistory(AnimeDetails data, String coverFallback) async {
  try {
    final history = History.fromModel(model: data);
    if (history.cover.isEmpty && coverFallback.isNotEmpty) {
      history.cover = coverFallback;
    }
    history.time = DateTime.now();
    await HistoryManager().addHistory(history);
  } catch (_) {}
}

/// 卡片入口的系列模式：与详情页 `_onDownloadSeries` 同逻辑
Future<void> _openSeriesDownloadPicker(
  BuildContext context,
  AnimeSource source,
  AnimeDetails data,
  String animeId, {
  String coverFallback = '',
  bool Function()? isCancelled,
}) async {
  if (source.loadSeries == null) {
    App.rootContext.showMessage(message: t.downloadNotYet);
    return;
  }
  final res = await source.loadSeries!(data);
  // 系列是第二段网络：等回来时用户可能已经取消，不再开选择器
  if (isCancelled?.call() ?? false) return;
  final series = res.dataOrNull ?? const <Anime>[];
  if (series.isEmpty) {
    App.rootContext.showMessage(message: t.downloadNotYet);
    return;
  }
  final ordered = List<Anime>.from(series);
  final currentIndex = ordered.indexWhere((a) => a.id == animeId);
  Anime? currentEntry;
  if (currentIndex >= 0) {
    currentEntry = ordered.removeAt(currentIndex);
  }
  final items = <_DownloadItem>[
    if (currentEntry != null)
      _DownloadItem(
        key: currentEntry.id,
        animeId: currentEntry.id,
        title: currentEntry.title,
        subtitle: currentEntry.subtitle ?? '',
        episodeName: currentEntry.title,
        sourceKey: source.key,
        isCurrent: true,
      )
    else
      _DownloadItem(
        key: animeId,
        animeId: animeId,
        title: data.title,
        subtitle: data.subTitle ?? '',
        episodeName: data.title,
        sourceKey: source.key,
        isCurrent: true,
      ),
    for (final a in ordered)
      _DownloadItem(
        key: a.id,
        animeId: a.id,
        title: a.title,
        subtitle: a.subtitle ?? '',
        episodeName: a.title,
        sourceKey: source.key,
      ),
  ];
  await _writeDownloadHistory(data, coverFallback);
  if (isCancelled?.call() ?? false) return;
  await _openAnimeDownloadPicker(
    context,
    source: source,
    data: data,
    animeTitle: data.title,
    items: items,
    resolveAnimeTitle: (id) async {
      final load = source.loadAnimeInfo;
      if (load == null) return null;
      try {
        final info = await load(id);
        return info.dataOrNull?.title;
      } catch (_) {
        return null;
      }
    },
  );
}

/// 弹出下载选择器并入队：详情页与卡片入口共用，行为完全一致
Future<void> _openAnimeDownloadPicker(
  BuildContext context, {
  required AnimeSource source,
  required AnimeDetails data,
  required String animeTitle,
  required List<_DownloadItem> items,
  Future<String?> Function(String id)? resolveAnimeTitle,
  bool Function()? isCancelled,
}) async {
  final downloadedFiles = await DownloadManager.downloadedFilesFor(source.key);
  if (isCancelled?.call() ?? false) return;
  if (!context.mounted) return;
  final result = await showModalBottomSheet<List<_DownloadPick>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EpisodeDownloadPicker(
      items: items,
      downloadedFiles: downloadedFiles,
      activeTasks: activeDownloadTasksOf(source.key),
      resolvePlay: (epKey) => resolveAnimePlayResult(source, data.id, epKey),
      animeTitle: animeTitle,
      sourceKey: source.key,
      resolveAnimeTitle: resolveAnimeTitle,
    ),
  );
  if (result == null || result.isEmpty) return;
  for (final item in result) {
    await enqueueAnimeEpisode(
      source: source,
      animeId: item.animeId,
      dataId: data.id,
      epKey: item.key,
      epName: item.episodeName,
      url: item.url,
      resolution: item.resolution,
      animeTitle: item.animeTitle,
      episodeNo: item.episodeNo,
      episodeRaw: item.episodeRaw,
      group: item.group,
      cover: data.cover,
      displayTitle: data.title,
      uploader: data.uploader,
    );
  }
}
