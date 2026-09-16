part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

/// 详情面板：状态 / 局势（胶囊切换），条目可点击查看设定
class _StoryDetailsSheet extends StatefulWidget {
  const _StoryDetailsSheet({
    required this.story,
    required this.state,
    required this.onCommand,
    this.onGenerateCodex,
  });

  final Story story;
  final GameState state;
  final ValueChanged<String> onCommand;

  /// 为缺失设定的物品/技能生成词条（返回更新后的状态，供本页刷新）
  final Future<GameState?> Function(List<String> items, String kind)?
  onGenerateCodex;

  @override
  State<_StoryDetailsSheet> createState() => _StoryDetailsSheetState();
}

class _StoryDetailsSheetState extends State<_StoryDetailsSheet> {
  final _pageCtrl = PageController();
  int _tab = 0;

  /// 词条按类型筛选（'' = 全部）
  String _codexKind = '';

  /// 面板分组筛选（'' = 第一个分组）
  String _statePanelGroup = '';

  GameState get state => widget.state;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTab(int i) {
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  /// 本页刚生成的词条（覆盖层）：生成后立即生效，不必重开面板
  List<StoryDefinition>? _codexOverride;
  bool _generating = false;

  /// 头部「补全缺失设定」按钮（icon，文字放 tooltip）
  Widget _generateHeaderButton() {
    final gen = widget.onGenerateCodex;
    if (gen == null) return const SizedBox.shrink();
    if (_generating) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: PolygonRefreshIndicator(),
        ),
      );
    }
    final missing = _missingDefs();
    if (missing.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.auto_awesome, size: 20),
      tooltip: '${t.storyRegisterItems} (${missing.length})',
      onPressed: _generateMissingAll,
    );
  }

  /// 缺失设定的条目（物品 / 技能，带 kind）
  List<({String name, String kind})> _missingDefs() => [
    for (final s in state.inventory)
      if (_findDef(_baseName(s)) == null) (name: _baseName(s), kind: 'item'),
    for (final s in state.skills)
      if (_findDef(s) == null) (name: s, kind: 'skill'),
    for (final a in state.attributes.keys)
      if (_findDef(a) == null) (name: a, kind: 'trait'),
  ];

  Future<void> _generateMissingAll() async {
    final gen = widget.onGenerateCodex;
    final missing = _missingDefs();
    if (gen == null || missing.isEmpty || _generating) return;
    setState(() => _generating = true);
    try {
      GameState? next;
      for (final kind in const ['item', 'skill', 'trait']) {
        final names = [
          for (final m in missing)
            if (m.kind == kind) m.name,
        ];
        if (names.isEmpty) continue;
        next = await gen(names, kind) ?? next;
      }
      if (next != null && mounted) {
        setState(() => _codexOverride = next!.codex);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  /// 在 codex 里按名称/键查找设定（容忍「物品 x2」这类后缀）
  StoryDefinition? _findDef(String name) {
    final key = _baseName(name);
    for (final d in _codexOverride ?? state.codex) {
      if (d.key == name || d.name == name || d.key == key || d.name == key) {
        return d;
      }
    }
    // 宽松匹配：数量后缀 / 名称写法不完全一致（如「工程铅笔（半支）x1」）
    for (final d in _codexOverride ?? state.codex) {
      if (_nameMatch(d.key, key) || _nameMatch(d.name, key)) return d;
    }
    return null;
  }

  IconData _iconFor(String name, String fallbackKind) =>
      _codexIcon(_findDef(name)?.kind ?? fallbackKind);

  Future<void> _inspect(String name, String kind) async {
    final def = _findDef(name);
    final scheme = Theme.of(context).colorScheme;
    await ContentDialog.show<void>(
      context: App.rootContext,
      title: def?.name ?? name,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            def == null
                ? t.storyNoEntry
                : (def.display.isEmpty ? def.mechanics : def.display),
          ),
          if (def != null && def.mechanics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              t.storyDefinition,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              def.mechanics,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
      // 只读查看：不显示底部按钮（displayButton 默认 true，光给空 actions 仍会露出「取消」）
      actions: const [],
      displayButton: false,
    );
  }

  /// 技能菜单：查看 / 施放（让玩家能主动使用技能、法术）
  Future<void> _skillMenu(String skill) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: skill,
        icon: Icons.auto_awesome_outlined,
        initialSize: 0.34,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(t.storyInspect),
              onTap: () {
                Navigator.of(ctx).pop();
                _inspect(skill, 'skill');
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(t.storySkillCast),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onCommand(t.storyCmdCastSkill(skill: skill));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 物品菜单：检查 / 使用 / 装备 / 丢弃
  Future<void> _itemMenu(String item) async {
    final equipped = _isEquipped(item);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: item,
        icon: Icons.inventory_2_outlined,
        initialSize: 0.5,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(t.storyInspect),
              onTap: () {
                Navigator.of(ctx).pop();
                _inspect(item, 'item');
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_arrow_outlined),
              title: Text(t.storyUse),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onCommand(t.storyCmdUse(item: item));
              },
            ),
            ListTile(
              leading: Icon(
                equipped
                    ? Icons.remove_circle_outline
                    : Icons.shield_outlined,
              ),
              title: Text(equipped ? t.storyUnequip : t.storyEquip),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onCommand(
                  equipped
                      ? t.storyCmdUnequip(item: item)
                      : t.storyCmdEquip(item: item),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(t.storyDrop),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onCommand(t.storyCmdDrop(item: item));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 可点击条目：点击看说明，长按 / 右键弹菜单（有菜单时）
  Widget _entry({
    required String label,
    required String kind,
    bool equipped = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onSecondaryTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTap == null ? null : (_) => onSecondaryTap(),
      child: ActionChip(
        avatar: Icon(_iconFor(label, kind), size: 16),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (equipped) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_circle, size: 14, color: scheme.primary),
            ],
          ],
        ),
        backgroundColor: equipped ? scheme.primaryContainer : null,
        onPressed: onTap ?? () => _inspect(label, kind),
      ),
    );
  }

  /// 去掉物品数量后缀（「匕首 x2」→「匕首」）
  String _baseName(String s) =>
      s.replaceFirst(RegExp(r'\s*[x×]\s*\d+\s*$'), '').trim();

  bool _nameMatch(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return a == b || a.contains(b) || b.contains(a);
  }

  bool _ownsItem(String name) =>
      state.inventory.any((s) => _nameMatch(_baseName(s), name));

  bool _isEquipped(String name) =>
      state.equipped.any((s) => _nameMatch(_baseName(s), name));

  bool _hasSkill(String name) =>
      state.skills.any((s) => _nameMatch(_baseName(s), name));

  /// 词条状态：物品（已装备 / 已拥有 / 未拥有）、技能（已习得 / 未习得）
  (String, bool)? _codexStatus(StoryDefinition d) {
    switch (d.kind) {
      case 'item':
        if (_isEquipped(d.name)) return (t.storyEquipped, true);
        if (_ownsItem(d.name)) return (t.storyOwned, true);
        return (t.storyNotOwned, false);
      case 'skill':
        if (_hasSkill(d.name)) return (t.storyLearned, true);
        return (t.storyNotLearned, false);
      default:
        return null;
    }
  }

  String _codexKindLabel(String kind) => switch (kind) {
    'item' => t.storyCodexItem,
    'skill' => t.skills,
    'trait' => t.storyCodexTrait,
    'talent' => t.storyCodexTalent,
    'race' => t.storyCodexRace,
    'body' => t.storyCodexBody,
    _ => kind.isEmpty ? t.storyCodex : kind,
  };

  Widget _codexTile(StoryDefinition d, ColorScheme scheme) {
    final status = _codexStatus(d);
    final owned = status?.$2;
    // 圆角裁切：让点击水波纹也跟随圆角（默认是直角）
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_codexIcon(d.kind), size: 20),
      title: Row(
        children: [
          Flexible(child: Text(d.name)),
          if (status != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: owned == true
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.$1,
                style: TextStyle(
                  fontSize: 10,
                  color: owned == true
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        d.display.isEmpty ? d.mechanics : d.display,
        style: TextStyle(
          fontSize: 12,
          color: owned == false
              ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
              : null,
        ),
      ),
      onTap: () =>
          d.kind == 'skill' ? _skillMenu(d.name) : _inspect(d.name, d.kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Sheet(
      title: t.storyDetails,
      icon: Icons.auto_stories_outlined,
      headerTrailing: _generateHeaderButton(),
      initialSize: 0.7,
      builder: (ctx, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CapsuleOptions(
              alignment: WrapAlignment.center,
              children: [
                CapsuleOption(
                  text: t.storyState,
                  isSelected: _tab == 0,
                  onTap: () => _goTab(0),
                ),
                CapsuleOption(
                  text: t.storySituation,
                  isSelected: _tab == 1,
                  onTap: () => _goTab(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _tab = i),
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _buildState(scheme),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: _buildSituation(scheme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildState(ColorScheme scheme) {
    final panels = widget.story.panels.isNotEmpty
        ? widget.story.panels
        : Story.defaultPanels;
    final widgets = <Widget>[];
    if (state.location.isNotEmpty || state.time.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            [state.location, state.time].where((e) => e.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    // 分区：按 group 归入分段胶囊 tab（无分组时保持平铺）
    final groups = <String>[];
    for (final p in panels) {
      if (!groups.contains(p.group)) groups.add(p.group);
    }
    final grouped =
        groups.length > 1 || (groups.length == 1 && groups.first.isNotEmpty);
    if (grouped) {
      final selected = groups.contains(_statePanelGroup)
          ? _statePanelGroup
          : groups.first;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CapsuleOptions(
            scrollable: true,
            children: [
              for (final g in groups)
                CapsuleOption(
                  text: _panelGroupLabel(g),
                  isSelected: selected == g,
                  onTap: () => setState(() => _statePanelGroup = g),
                ),
            ],
          ),
        ),
      );
      _appendPanels(
        widgets,
        panels.where((p) => p.group == selected).toList(),
        scheme,
      );
      return widgets;
    }

    _appendPanels(widgets, panels, scheme);
    return widgets;
  }

  /// 把分区依次追加到列表（跳过空分区，块间留白）
  void _appendPanels(
    List<Widget> widgets,
    List<StoryPanel> panels,
    ColorScheme scheme,
  ) {
    var first = true;
    for (final p in panels) {
      final section = _buildPanel(p, scheme);
      if (section.isEmpty) continue;
      if (!first) widgets.add(const SizedBox(height: 12));
      first = false;
      widgets.addAll(section);
    }
  }

  String _panelGroupLabel(String group) => group.isEmpty ? t.storyState : group;

  /// 渲染单个面板分区（由故事自定义 source/title/kind/icon）
  List<Widget> _buildPanel(StoryPanel panel, ColorScheme scheme) {
    final icon = _panelIcon(panel.icon);
    switch (panel.source) {
      case 'resources':
        if (state.resources.isEmpty) return const [];
        return [
          _sectionTitle(panel.title.isEmpty ? t.storyState : panel.title, icon),
          for (final r in state.resources)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.name}  ${r.cur}/${r.max}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.max <= 0 ? 0 : (r.cur / r.max).clamp(0.0, 1.0),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
        ];
      case 'attributes':
        if (state.attributes.isEmpty) return const [];
        return [
          _sectionTitle(panel.title.isEmpty ? t.storyState : panel.title, icon),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 属性可点击：查看该属性影响什么（由故事观的词条定义）
              for (final e in state.attributes.entries)
                _entry(
                  label: '${e.key} ${e.value}',
                  kind: 'trait',
                  onTap: () => _inspect(e.key, 'trait'),
                ),
            ],
          ),
        ];
      case 'skills':
        if (state.skills.isEmpty) return const [];
        return [
          _sectionTitle(panel.title.isEmpty ? t.skills : panel.title, icon),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in state.skills)
                _entry(
                  label: s,
                  kind: 'skill',
                  onTap: () => _skillMenu(s),
                  onLongPress: () => _skillMenu(s),
                ),
            ],
          ),
        ];
      case 'inventory':
        if (state.inventory.isEmpty) return const [];
        return [
          _sectionTitle(
            panel.title.isEmpty ? t.storyInventory : panel.title,
            icon,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in state.inventory)
                _entry(
                  label: s,
                  kind: 'item',
                  equipped: _isEquipped(s),
                  onLongPress: () => _itemMenu(s),
                  onSecondaryTap: () => _itemMenu(s),
                ),
            ],
          ),
        ];
      case 'quests':
        if (state.quests.isEmpty) return const [];
        return [
          _sectionTitle(panel.title.isEmpty ? t.storyQuests : panel.title, icon),
          for (final q in state.quests)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: switch (q.status) {
                'done' => const Icon(Icons.check_circle_outline, size: 20),
                'failed' => Icon(
                  Icons.cancel_outlined,
                  size: 20,
                  color: scheme.error,
                ),
                _ => null,
              },
              title: Row(
                children: [
                  Flexible(child: Text(q.title)),
                  if (q.chain.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      (q.status == 'active' && q.totalStages > 1)
                          ? '${q.chain} ${q.stage}/${q.totalStages}'
                          : q.chain,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (q.status == 'done' || q.status == 'failed') ...[
                    const SizedBox(width: 6),
                    Text(
                      q.status == 'done'
                          ? t.storyQuestDone
                          : t.storyQuestFailed,
                      style: TextStyle(
                        fontSize: 11,
                        color: q.status == 'done'
                            ? scheme.primary
                            : scheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (q.desc.isNotEmpty)
                    Text(q.desc, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: q.progressFraction,
                      minHeight: 6,
                      color: q.status == 'failed' ? scheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
        ];
      case 'equipment':
        if (state.equipped.isEmpty) return const [];
        return [
          _sectionTitle(
            panel.title.isEmpty ? t.storyEquipment : panel.title,
            icon,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in state.equipped)
                _entry(
                  label: s,
                  kind: 'item',
                  onLongPress: () => _itemMenu(s),
                  onSecondaryTap: () => _itemMenu(s),
                ),
            ],
          ),
        ];
      case 'combat':
        if (!state.combat.active && state.combat.enemies.isEmpty) {
          return const [];
        }
        return [
          _sectionTitle(
            panel.title.isEmpty
                ? '${t.storyCombat} · ${t.storyRound}${state.combat.round}'
                : panel.title,
            icon,
          ),
          for (final e in state.combat.enemies)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${e.name}  ${e.hp}/${e.maxHp}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.maxHp <= 0
                          ? 0
                          : (e.hp / e.maxHp).clamp(0.0, 1.0),
                      minHeight: 6,
                    ),
                  ),
                  if (e.note.isNotEmpty)
                    Text(
                      e.note,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ];
      case 'achievements':
        if (state.achievements.isEmpty) return const [];
        final byKey = {for (final a in widget.story.achievements) a.key: a};
        return [
          _sectionTitle(
            panel.title.isEmpty ? t.storyAchievements : panel.title,
            icon,
          ),
          for (final key in state.achievements)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.emoji_events_outlined, size: 20),
              title: Text(byKey[key]?.name ?? key),
              subtitle: (byKey[key]?.description.isEmpty ?? true)
                  ? null
                  : Text(
                      byKey[key]!.description,
                      style: const TextStyle(fontSize: 12),
                    ),
            ),
        ];
      case 'variables':
        if (state.variables.isEmpty) return const [];
        return [
          _sectionTitle(
            panel.title.isEmpty ? t.storyVariables : panel.title,
            icon,
          ),
          for (final e in state.variables.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              trailing: Text(
                e.value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ];
      case 'codex':
        final defs = panel.kind.isEmpty
            ? state.codex
            : state.codex.where((d) => d.kind == panel.kind).toList();
        if (defs.isEmpty) return const [];
        final out = <Widget>[
          _sectionTitle(panel.title.isEmpty ? t.storyCodex : panel.title, icon),
        ];
        if (panel.kind.isNotEmpty) {
          for (final d in defs) {
            out.add(_codexTile(d, scheme));
          }
          return out;
        }
        // 未指定 kind：用分段胶囊按类型切换，避免下滑过长
        final kinds = <String>[];
        for (final d in defs) {
          if (!kinds.contains(d.kind)) kinds.add(d.kind);
        }
        final selected = (_codexKind.isEmpty || !kinds.contains(_codexKind))
            ? ''
            : _codexKind;
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CapsuleOptions(
              alignment: WrapAlignment.center,
              children: [
                CapsuleOption(
                  text: t.filterAll,
                  isSelected: selected.isEmpty,
                  onTap: () => setState(() => _codexKind = ''),
                ),
                for (final k in kinds)
                  CapsuleOption(
                    text: _codexKindLabel(k),
                    isSelected: selected == k,
                    onTap: () => setState(() => _codexKind = k),
                  ),
              ],
            ),
          ),
        );
        final shown = selected.isEmpty
            ? defs
            : defs.where((d) => d.kind == selected).toList();
        for (final d in shown) {
          out.add(_codexTile(d, scheme));
        }
        return out;
      case 'titles':
        if (state.titles.isEmpty) return const [];
        return [
          _sectionTitle(
            panel.title.isEmpty ? t.storyTitles : panel.title,
            icon,
          ),
          if (widget.story.titleMode == 'equipped')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t.storyTitleModeEquipped,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          for (final ts in state.titles) _titleTile(ts, scheme),
        ];
      case 'effects':
        if (state.effects.isEmpty) return const [];
        return [
          _sectionTitle(
            panel.title.isEmpty ? t.storyEffects : panel.title,
            icon,
          ),
          for (final e in state.effects)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e.kind == 'debuff'
                    ? Icons.trending_down
                    : Icons.trending_up,
                size: 20,
                color: e.kind == 'debuff' ? Colors.redAccent : Colors.teal,
              ),
              title: Row(
                children: [
                  Flexible(child: Text(e.name)),
                  if (e.stacks > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '×${e.stacks}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
              subtitle: Text(
                [
                  if (e.remaining > 0)
                    '${t.storyEffectRemaining}: ${e.remaining}',
                  if (e.description.isNotEmpty) e.description,
                ].join(' · '),
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ];
      case 'job':
        final jb = widget.story.job;
        final hasJob = !state.job.isEmpty || (jb != null && !jb.isEmpty);
        if (!hasJob) return const [];
        return [
          _sectionTitle(panel.title.isEmpty ? t.storyJob : panel.title, icon),
          if (!state.job.isEmpty)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined, size: 20),
              title: Text('${state.job.name} · Lv.${state.job.level}'),
              subtitle: Text(
                '${t.storyJobExp}: ${state.job.exp}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (jb != null)
            for (final l in jb.levels)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Text(
                  'Lv.${l.level} ${l.name}'
                  '${l.bonus.trim().isEmpty ? '' : '：${l.bonus.trim()}'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
        ];
      case 'base':
        if (state.base.isEmpty && widget.story.facilities.isEmpty) {
          return const [];
        }
        return [
          _sectionTitle(panel.title.isEmpty ? t.storyBase : panel.title, icon),
          for (final f in state.base.facilities)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.home_work_outlined, size: 20),
              title: Text(_facilityName(f.key)),
              subtitle: f.status.isEmpty
                  ? null
                  : Text(f.status, style: const TextStyle(fontSize: 12)),
              trailing: Text(
                'Lv.${f.level}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (state.base.materials.isNotEmpty) ...[
            _subTitle(t.storyBaseMaterials, scheme),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in state.base.materials.entries)
                  Chip(label: Text('${e.key} ${e.value}')),
              ],
            ),
          ],
          if (state.base.storage.isNotEmpty) ...[
            _subTitle(t.storyBaseStorage, scheme),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in state.base.storage.entries)
                  Chip(label: Text('${e.key} ${e.value}')),
              ],
            ),
          ],
        ];
      default:
        return const [];
    }
  }

  /// 称号条目：显示层数 / 是否佩戴 / 效果
  Widget _titleTile(TitleState ts, ColorScheme scheme) {
    StoryTitle? def;
    for (final d in widget.story.titles) {
      if (d.key == ts.key) {
        def = d;
        break;
      }
    }
    final name = (def != null && def.name.trim().isNotEmpty)
        ? def.name
        : ts.key;
    final desc = def == null
        ? ''
        : (def.effects.trim().isNotEmpty ? def.effects : def.description);
    final marks = <String>[
      if (ts.stacks > 1) '×${ts.stacks}',
      if (ts.equipped) t.storyTitleEquipped,
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.military_tech_outlined, size: 20),
      title: Text(name),
      subtitle: desc.trim().isEmpty
          ? null
          : Text(desc, style: const TextStyle(fontSize: 12)),
      trailing: marks.isEmpty
          ? null
          : Text(
              marks.join(' · '),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
    );
  }

  Widget _subTitle(String text, ColorScheme scheme) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 2),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.primary,
      ),
    ),
  );

  String _facilityName(String key) {
    for (final f in widget.story.facilities) {
      if (f.key == key) return f.name.trim().isEmpty ? key : f.name;
    }
    return key;
  }

  List<Widget> _buildSituation(ColorScheme scheme) {
    final blocks = <Widget>[];
    final persona = widget.story.persona;
    if (!persona.isEmpty) {
      blocks.add(_sectionTitle(t.storyPersona));
      blocks.add(
        Row(
          children: [
            CharacterAvatar(
              name: persona.name,
              avatar: persona.avatar,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Text(
              persona.name.trim(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
      if (persona.description.trim().isNotEmpty) {
        blocks.add(const SizedBox(height: 4));
        blocks.add(
          Text(
            persona.description.trim(),
            style: TextStyle(height: 1.5, color: scheme.onSurface),
          ),
        );
      }
    }
    if (widget.story.situation.trim().isNotEmpty) {
      if (blocks.isNotEmpty) blocks.add(const SizedBox(height: 16));
      blocks.add(_sectionTitle(t.storyBackground));
      // 背景里的 {{user}} / {{persona}} 也要替换（否则会原样显示）
      blocks.add(
        Text(
          widget.story.situation
              .replaceAll(
                '{{user}}',
                persona.name.trim().isNotEmpty ? persona.name.trim() : '玩家',
              )
              .replaceAll('{{persona}}', persona.description.trim())
              .trim(),
          style: TextStyle(height: 1.5, color: scheme.onSurface),
        ),
      );
    }
    if (state.situation.trim().isNotEmpty) {
      blocks.add(const SizedBox(height: 16));
      blocks.add(_sectionTitle(t.storySituation));
      blocks.add(
        Text(
          state.situation.trim(),
          style: TextStyle(height: 1.5, color: scheme.onSurface),
        ),
      );
    }
    if (blocks.isEmpty) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: Text(
              t.storyNoSituation,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    return blocks;
  }
}
