part of 'ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：AI 冒险（故事选择 + 文字冒险 / 状态面板）
// ═════════════════════════════════════════════

class StoryPage extends ConsumerStatefulWidget {
  const StoryPage({super.key});

  @override
  ConsumerState<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends ConsumerState<StoryPage> {
  bool _dragOver = false;

  @override
  void initState() {
    super.initState();
    StoryStore.instance.init();
  }

  Future<void> _new() async {
    await showPopUpWidget(App.rootContext, const _StoryEditor());
    if (mounted) setState(() {});
  }

  Future<void> _edit(Story s) async {
    await showPopUpWidget(App.rootContext, _StoryEditor(story: s));
    if (mounted) setState(() {});
  }

  Future<void> _export(Story s) async {
    await saveFile(
      data: utf8.encode(StoryStore.storyToMarkdown(s)),
      filename: '${s.name}.md',
    );
  }

  /// 导出为 SillyTavern 可读的角色卡（V2，含内嵌世界书）
  Future<void> _exportSt(Story s) async {
    final data = <String, dynamic>{
      'name': s.name,
      'description': s.description,
      'personality': '',
      'scenario': s.situation,
      'first_mes': s.opening,
      'mes_example': '',
      'system_prompt': s.systemPrompt,
      'post_history_instructions': '',
      'creator_notes': s.description,
      'tags': <String>[],
      'creator': '',
      'character_version': '',
      'alternate_greetings': <String>[],
      'extensions': <String, dynamic>{},
    };
    final book = _storyLorebookJson(s);
    if (book != null) data['character_book'] = book;
    final card = {
      'spec': 'chara_card_v2',
      'spec_version': '2.0',
      'data': data,
    };
    await saveFile(
      data: utf8.encode(const JsonEncoder.withIndent('  ').convert(card)),
      filename: '${s.name}.st.json',
    );
  }

  /// 把故事的 `## 世界书` 文本（按【名称】分段）转成 ST character_book
  Map<String, dynamic>? _storyLorebookJson(Story s) {
    final text = s.worldBook.trim();
    if (text.isEmpty) return null;
    final entries = <Map<String, dynamic>>[];
    var order = 0;
    void add(String name, String content) {
      if (content.trim().isEmpty) return;
      entries.add({
        'keys': <String>[],
        'content': content.trim(),
        'enabled': true,
        'constant': true,
        'insertion_order': order++,
        'name': name,
      });
    }

    final matches = RegExp(r'【([^】]*)】').allMatches(text).toList();
    if (matches.isEmpty) {
      add(s.name, text);
    } else {
      for (var i = 0; i < matches.length; i++) {
        final name = matches[i].group(1) ?? '';
        final start = matches[i].end;
        final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
        add(name, text.substring(start, end));
      }
    }
    if (entries.isEmpty) return null;
    return {
      'name': s.name,
      'description': s.description,
      'scan_depth': 4,
      'token_budget': 500,
      'recursive_scanning': false,
      'extensions': <String, dynamic>{},
      'entries': entries,
    };
  }

  /// 导入一个故事：**同名则原地更新**（保留 id 与存档，方便升级故事版本）。
  /// 返回 'updated' / 'new'。
  Future<String> _importBytes(Uint8List bytes) async {
    final text = utf8.decode(bytes);
    final parsed = StoryStore.storyFromMarkdown(text);
    final name = parsed.name.trim();
    Story? existing;
    for (final s in StoryStore.instance.stories) {
      if (!s.isBuiltin && s.name.trim() == name) {
        existing = s;
        break;
      }
    }
    if (existing != null) {
      // 升级：其余定义用新版，但**保留 App 里加的角色卡**（按 id/名字去重合并）
      await StoryStore.instance.upsert(
        parsed.copyWith(
          id: existing.id,
          characters: _mergeCharacters(
            existing.characters,
            parsed.characters,
          ),
        ),
      );
      return 'updated';
    }
    await StoryStore.instance.upsert(parsed);
    return 'new';
  }

  /// 合并角色卡：保留已有的，追加新版新增的（按 id 或名字去重）
  List<CharacterCard> _mergeCharacters(
    List<CharacterCard> current,
    List<CharacterCard> incoming,
  ) {
    final out = [...current];
    for (final c in incoming) {
      final dup = out.any(
        (x) =>
            x.id == c.id ||
            (c.name.trim().isNotEmpty && x.name.trim() == c.name.trim()),
      );
      if (!dup) out.add(c);
    }
    return out;
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final mode = await _importBytes(await result.files.first.readAsBytes());
      if (mounted) {
        App.rootContext.showMessage(
          message: mode == 'updated' ? t.storyUpdated : t.storyImported,
        );
        setState(() {});
      }
    } catch (e) {
      Log.error('importStory', e.toString());
      App.rootContext.showMessage(message: t.importFailed, level: LogLevel.error);
    }
  }

  /// 拖动导入故事（.md / .markdown / .txt）
  Future<void> _onDrop(DropDoneDetails detail) async {
    var imported = 0;
    for (final file in detail.files) {
      final name = file.name.toLowerCase();
      if (!name.endsWith('.md') &&
          !name.endsWith('.markdown') &&
          !name.endsWith('.txt')) {
        continue;
      }
      try {
        await _importBytes(await file.readAsBytes());
        imported++;
      } catch (_) {}
      // 同名会被原地更新（见 _importBytes）
    }
    if (!mounted) return;
    setState(() => _dragOver = false);
    if (imported > 0) {
      App.rootContext.showMessage(message: t.storyImported);
    } else if (detail.files.isNotEmpty) {
      App.rootContext.showMessage(
        message: t.importFailed,
        level: LogLevel.error,
      );
    }
  }

  Future<void> _delete(Story s) async {
    final ok = await StoryStore.instance.remove(s.id);
    if (!ok && mounted) {
      App.rootContext.showMessage(
        message: t.cannotDeletePreset,
        level: LogLevel.warning,
      );
    }
    if (mounted) setState(() {});
  }

  /// 重启世界：删除该故事存档（会话 + 状态），下次进入即从头开始
  Future<void> _restart(Story s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.storyRestart,
        content: Text(t.storyRestartConfirm),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await StorySessionStore.instance.ensureLoaded();
    final session = StorySessionStore.instance.get(s.id);
    if (session != null) {
      await AiConversationService().deleteSession(session.sessionId);
      await StorySessionStore.instance.clear(s.id);
    }
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StoryStore.instance,
      builder: (context, _) {
        final stories = StoryStore.instance.stories;
        return DropTarget(
          onDragDone: _onDrop,
          onDragEntered: (_) {
            if (mounted) setState(() => _dragOver = true);
          },
          onDragExited: (_) {
            if (mounted) setState(() => _dragOver = false);
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: Appbar(
                  title: Text(t.rolePlay),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.file_open_outlined),
                      tooltip: t.importEntries,
                      onPressed: _import,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: t.storyNew,
                      onPressed: _new,
                    ),
                  ],
                ),
                body: stories.isEmpty
                    ? _emptyState(context)
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          for (final s in stories)
                            _StoryCard(
                              story: s,
                              onTap: () =>
                                  context.to(() => StoryGamePage(story: s)),
                              onEdit: () => _edit(s),
                              onExport: () => _export(s),
                        onExportSt: () => _exportSt(s),
                              onRestart: () => _restart(s),
                              onDelete: s.isBuiltin ? null : () => _delete(s),
                            ),
                        ],
                      ),
                floatingActionButton: stories.isEmpty
                    ? null
                    : FloatingActionButton(
                        onPressed: _new,
                        tooltip: t.storyNew,
                        child: const Icon(Icons.add),
                      ),
              ),
              if (_dragOver)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.scrim.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.download_outlined, size: 48),
                          const SizedBox(height: 12),
                          Text(t.storyDropHint),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 空状态：图标 + 引导 + 新建 / 导入两个入口
  Widget _emptyState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.toOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              t.storyNoStories,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _new,
                  icon: const Icon(Icons.add),
                  label: Text(t.storyNew),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(t.importEntries),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.onTap,
    required this.onEdit,
    required this.onExport,
    required this.onExportSt,
    required this.onRestart,
    this.onDelete,
  });

  final Story story;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onExportSt;
  final VoidCallback onRestart;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            story.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (story.isBuiltin) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.builtin,
                              style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (story.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        story.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: t.more,
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'export') onExport();
                  if (v == 'export_st') onExportSt();
                  if (v == 'restart') onRestart();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.edit)),
                  PopupMenuItem(value: 'export', child: Text(t.exportEntries)),
                  PopupMenuItem(
                    value: 'export_st',
                    child: Text(t.storyExportSt),
                  ),
                  PopupMenuItem(value: 'restart', child: Text(t.storyRestart)),
                  if (onDelete != null)
                    PopupMenuItem(value: 'delete', child: Text(t.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 故事编辑器
// ─────────────────────────────────────────────

class _StoryEditor extends StatefulWidget {
  const _StoryEditor({this.story});

  final Story? story;

  @override
  State<_StoryEditor> createState() => _StoryEditorState();
}

class _WorldBookDraft {
  final TextEditingController name;
  final TextEditingController content;

  _WorldBookDraft({String nameText = '', String contentText = ''})
    : name = TextEditingController(text: nameText),
      content = TextEditingController(text: contentText);

  void dispose() {
    name.dispose();
    content.dispose();
  }
}

class _StoryActionDraft {
  final TextEditingController label;
  final TextEditingController prompt;
  final TextEditingController icon;

  _StoryActionDraft({String labelText = '', String promptText = '', String iconText = ''})
    : label = TextEditingController(text: labelText),
      prompt = TextEditingController(text: promptText),
      icon = TextEditingController(text: iconText);

  void dispose() {
    label.dispose();
    prompt.dispose();
    icon.dispose();
  }
}

class _StoryPanelDraft {
  final TextEditingController title;
  final TextEditingController kind;
  final TextEditingController icon;
  String source;

  _StoryPanelDraft({
    String titleText = '',
    this.source = 'attributes',
    String kindText = '',
    String iconText = '',
  }) : title = TextEditingController(text: titleText),
       kind = TextEditingController(text: kindText),
       icon = TextEditingController(text: iconText);

  void dispose() {
    title.dispose();
    kind.dispose();
    icon.dispose();
  }
}

class _StoryVariableDraft {
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController description;
  final TextEditingController min;
  final TextEditingController max;
  final TextEditingController unit;
  final TextEditingController options;
  String type;

  _StoryVariableDraft({
    String nameText = '',
    String valueText = '',
    String descriptionText = '',
    String minText = '',
    String maxText = '',
    String unitText = '',
    String optionsText = '',
    this.type = 'text',
  }) : name = TextEditingController(text: nameText),
       value = TextEditingController(text: valueText),
       description = TextEditingController(text: descriptionText),
       min = TextEditingController(text: minText),
       max = TextEditingController(text: maxText),
       unit = TextEditingController(text: unitText),
       options = TextEditingController(text: optionsText);

  void dispose() {
    name.dispose();
    value.dispose();
    description.dispose();
    min.dispose();
    max.dispose();
    unit.dispose();
    options.dispose();
  }
}

class _StoryRegexDraft {
  final TextEditingController name;
  final TextEditingController pattern;
  final TextEditingController replacement;
  final TextEditingController minDepth;
  final TextEditingController maxDepth;
  String phase;
  bool enabled;

  _StoryRegexDraft({
    String nameText = '',
    String patternText = '',
    String replacementText = '',
    String minDepthText = '',
    String maxDepthText = '',
    this.phase = 'display',
    this.enabled = true,
  }) : name = TextEditingController(text: nameText),
       pattern = TextEditingController(text: patternText),
       replacement = TextEditingController(text: replacementText),
       minDepth = TextEditingController(text: minDepthText),
       maxDepth = TextEditingController(text: maxDepthText);

  void dispose() {
    name.dispose();
    pattern.dispose();
    replacement.dispose();
    minDepth.dispose();
    maxDepth.dispose();
  }
}

class _StoryAchievementDraft {
  final TextEditingController key;
  final TextEditingController name;
  final TextEditingController description;

  _StoryAchievementDraft({
    String keyText = '',
    String nameText = '',
    String descriptionText = '',
  }) : key = TextEditingController(text: keyText),
       name = TextEditingController(text: nameText),
       description = TextEditingController(text: descriptionText);

  void dispose() {
    key.dispose();
    name.dispose();
    description.dispose();
  }
}

class _StoryCodexDraft {
  final TextEditingController key;
  final TextEditingController name;
  final TextEditingController display;
  final TextEditingController mechanics;
  String kind;

  _StoryCodexDraft({
    String keyText = '',
    String nameText = '',
    String displayText = '',
    String mechanicsText = '',
    this.kind = 'item',
  }) : key = TextEditingController(text: keyText),
       name = TextEditingController(text: nameText),
       display = TextEditingController(text: displayText),
       mechanics = TextEditingController(text: mechanicsText);

  void dispose() {
    key.dispose();
    name.dispose();
    display.dispose();
    mechanics.dispose();
  }
}

class _StoryTitleDraft {
  final TextEditingController key = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController effects = TextEditingController();
  bool stackable;

  _StoryTitleDraft({
    String keyText = '',
    String nameText = '',
    String effectsText = '',
    this.stackable = false,
  }) {
    key.text = keyText;
    name.text = nameText;
    effects.text = effectsText;
  }

  void dispose() {
    key.dispose();
    name.dispose();
    effects.dispose();
  }
}

class _StoryJobLevelDraft {
  final TextEditingController level = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController bonus = TextEditingController();

  _StoryJobLevelDraft({
    String levelText = '',
    String nameText = '',
    String bonusText = '',
  }) {
    level.text = levelText;
    name.text = nameText;
    bonus.text = bonusText;
  }

  void dispose() {
    level.dispose();
    name.dispose();
    bonus.dispose();
  }
}

class _StoryFacilityDraft {
  final TextEditingController key = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController maxLevel = TextEditingController();

  _StoryFacilityDraft({
    String keyText = '',
    String nameText = '',
    String descriptionText = '',
    String maxLevelText = '1',
  }) {
    key.text = keyText;
    name.text = nameText;
    description.text = descriptionText;
    maxLevel.text = maxLevelText;
  }

  void dispose() {
    key.dispose();
    name.dispose();
    description.dispose();
    maxLevel.dispose();
  }
}

class _StoryEditorState extends State<_StoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.story?.name ?? '');

  late final _descCtrl = TextEditingController(
    text: widget.story?.description ?? '',
  );
  late final _deathCtrl = TextEditingController(
    text: (widget.story?.deathResources ?? const []).join('、'),
  );
  late String _deathMode = widget.story?.deathMode ?? 'any';
  late final _tempCtrl = TextEditingController(
    text: widget.story?.temperature?.toString() ?? '',
  );
  late final _topPCtrl = TextEditingController(
    text: widget.story?.topP?.toString() ?? '',
  );
  late final _maxTokensCtrl = TextEditingController(
    text: widget.story?.maxTokens?.toString() ?? '',
  );
  int _tab = 0;
  late final _openingCtrl = TextEditingController(
    text: widget.story?.opening ?? '',
  );
  late final _systemCtrl = TextEditingController(
    text: widget.story?.systemPrompt ?? '',
  );
  late final _situationCtrl = TextEditingController(
    text: widget.story?.situation ?? '',
  );
  late final _choicesCtrl = TextEditingController(
    text: widget.story?.choicesPrompt ?? '',
  );
  late String _personaAvatar = widget.story?.persona.avatar ?? '';
  late final _personaNameCtrl = TextEditingController(
    text: widget.story?.persona.name ?? '',
  );
  late final _personaDescCtrl = TextEditingController(
    text: widget.story?.persona.description ?? '',
  );
  late final _stateCtrl = TextEditingController(
    text: widget.story == null
        ? '{\n  "resources": {},\n  "attributes": {},\n  "skills": [],\n  "inventory": [],\n  "quests": []\n}'
        : const JsonEncoder.withIndent('  ')
              .convert(widget.story!.initialState.toJson()),
  );
  late final List<_WorldBookDraft> _worldBook = _parseWorldBook(
    widget.story?.worldBook ?? '',
  );
  late final List<_StoryActionDraft> _actions = [
    for (final a in widget.story?.actions ?? const <StoryAction>[])
      _StoryActionDraft(
        labelText: a.label,
        promptText: a.prompt,
        iconText: a.icon,
      ),
  ];
  late final List<_StoryPanelDraft> _panels = [
    for (final p in (widget.story?.panels.isNotEmpty == true
        ? widget.story!.panels
        : Story.defaultPanels))
      _StoryPanelDraft(
        titleText: p.title,
        source: p.source,
        kindText: p.kind,
        iconText: p.icon,
      ),
  ];
  late final List<CharacterCard> _characters = [
    ...widget.story?.characters ?? const <CharacterCard>[],
  ];
  late final List<_StoryVariableDraft> _variables = [
    for (final v in widget.story?.variables ?? const <StoryVariable>[])
      _StoryVariableDraft(
        nameText: v.name,
        valueText: v.value,
        descriptionText: v.description,
        minText: v.min?.toString() ?? '',
        maxText: v.max?.toString() ?? '',
        unitText: v.unit,
        optionsText: v.options.join('、'),
        type: v.type,
      ),
  ];
  late final List<_StoryRegexDraft> _regexes = [
    for (final r in widget.story?.regexes ?? const <StoryRegex>[])
      _StoryRegexDraft(
        nameText: r.name,
        patternText: r.pattern,
        replacementText: r.replacement,
        minDepthText: r.minDepth > 0 ? '${r.minDepth}' : '',
        maxDepthText: r.maxDepth > 0 ? '${r.maxDepth}' : '',
        phase: r.phase,
        enabled: r.enabled,
      ),
  ];
  late final List<_StoryAchievementDraft> _achievements = [
    for (final a in widget.story?.achievements ?? const <StoryAchievement>[])
      _StoryAchievementDraft(
        keyText: a.key,
        nameText: a.name,
        descriptionText: a.description,
      ),
  ];
  late final List<_StoryCodexDraft> _codexDefs = [
    for (final d in widget.story?.codex ?? const <StoryDefinition>[])
      _StoryCodexDraft(
        keyText: d.key,
        nameText: d.name,
        displayText: d.display,
        mechanicsText: d.mechanics,
        kind: d.kind,
      ),
  ];
  late String _titleMode = widget.story?.titleMode ?? 'all';
  late final List<_StoryTitleDraft> _titles = [
    for (final x in widget.story?.titles ?? const <StoryTitle>[])
      _StoryTitleDraft(
        keyText: x.key,
        nameText: x.name,
        effectsText: x.effects,
        stackable: x.stackable,
      ),
  ];
  late final _jobNameCtrl = TextEditingController(
    text: widget.story?.job?.name ?? '',
  );
  late final _jobDescCtrl = TextEditingController(
    text: widget.story?.job?.description ?? '',
  );
  late final List<_StoryJobLevelDraft> _jobLevels = [
    for (final l in widget.story?.job?.levels ?? const <StoryJobLevel>[])
      _StoryJobLevelDraft(
        levelText: '${l.level}',
        nameText: l.name,
        bonusText: l.bonus,
      ),
  ];
  late final List<_StoryFacilityDraft> _facilities = [
    for (final f in widget.story?.facilities ?? const <StoryFacility>[])
      _StoryFacilityDraft(
        keyText: f.key,
        nameText: f.name,
        descriptionText: f.description,
        maxLevelText: '${f.maxLevel}',
      ),
  ];
  late final Set<String> _worldBookIds = {
    ...widget.story?.worldBookIds ?? const <String>[],
  };
  late final Set<String> _injectionIds = {
    ...widget.story?.injectionIds ?? const <String>[],
  };
  late final Set<String> _settingIds = {
    ...widget.story?.settingIds ?? const <String>[],
  };

  @override
  void initState() {
    super.initState();
    WorldBookStore.instance.ensureLoaded();
    PromptInjectionStore.instance.ensureLoaded();
  }

  static const _codexKinds = [
    'item',
    'trait',
    'race',
    'skill',
    'talent',
    'body',
  ];

  String _codexKindName(String kind) => switch (kind) {
    'item' => t.storyCodexItem,
    'trait' => t.storyCodexTrait,
    'race' => t.storyCodexRace,
    'skill' => t.skills,
    'talent' => t.storyCodexTalent,
    'body' => t.storyCodexBody,
    _ => kind,
  };

  bool get _isNew => widget.story == null;

  static List<_WorldBookDraft> _parseWorldBook(String text) {
    final entries = <_WorldBookDraft>[];
    if (text.trim().isEmpty) return entries;
    final matches = RegExp(r'【([^】]*)】').allMatches(text).toList();
    if (matches.isEmpty) {
      entries.add(_WorldBookDraft(contentText: text.trim()));
      return entries;
    }
    for (var i = 0; i < matches.length; i++) {
      final name = matches[i].group(1) ?? '';
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      entries.add(
        _WorldBookDraft(
          nameText: name,
          contentText: text.substring(start, end).trim(),
        ),
      );
    }
    return entries;
  }

  String _serializeWorldBook() {
    final buf = StringBuffer();
    for (final e in _worldBook) {
      final name = e.name.text.trim();
      final content = e.content.text.trim();
      if (name.isEmpty && content.isEmpty) continue;
      buf.writeln('【${name.isEmpty ? t.storyDefinition : name}】');
      buf.writeln(content);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _deathCtrl.dispose();
    _openingCtrl.dispose();
    _systemCtrl.dispose();
    _situationCtrl.dispose();
    _personaNameCtrl.dispose();
    _personaDescCtrl.dispose();
    _choicesCtrl.dispose();
    _stateCtrl.dispose();
    for (final e in _worldBook) {
      e.dispose();
    }
    for (final a in _actions) {
      a.dispose();
    }
    for (final p in _panels) {
      p.dispose();
    }
    for (final v in _variables) {
      v.dispose();
    }
    for (final r in _regexes) {
      r.dispose();
    }
    for (final a in _achievements) {
      a.dispose();
    }
    for (final d in _codexDefs) {
      d.dispose();
    }
    for (final x in _titles) {
      x.dispose();
    }
    _jobNameCtrl.dispose();
    _jobDescCtrl.dispose();
    for (final l in _jobLevels) {
      l.dispose();
    }
    for (final f in _facilities) {
      f.dispose();
    }
    _tempCtrl.dispose();
    _topPCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  GameState? _parseState() {
    try {
      final decoded = jsonDecode(_stateCtrl.text.trim());
      if (decoded is Map) {
        return GameState.fromJson(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final initialState = _parseState();
    if (initialState == null) {
      App.rootContext.showMessage(
        message: t.storyInvalidState,
        level: LogLevel.error,
      );
      return;
    }
    final story = Story(
      id: widget.story?.id ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      icon: widget.story?.icon ?? '📖',
      description: _descCtrl.text.trim(),
      opening: _openingCtrl.text.trim(),
      systemPrompt: _systemCtrl.text.trim(),
      worldBook: _serializeWorldBook(),
      situation: _situationCtrl.text.trim(),
      deathResources: _deathCtrl.text
          .split(RegExp(r'[、,，/]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      deathMode: _deathMode,
      temperature: double.tryParse(_tempCtrl.text.trim()),
      topP: double.tryParse(_topPCtrl.text.trim()),
      maxTokens: int.tryParse(_maxTokensCtrl.text.trim()),
      choicesPrompt: _choicesCtrl.text.trim(),
      setup: widget.story?.setup ?? const [],
      actions: [
        for (final a in _actions)
          if (a.label.text.trim().isNotEmpty)
            StoryAction(
              label: a.label.text.trim(),
              prompt: a.prompt.text.trim().isEmpty
                  ? a.label.text.trim()
                  : a.prompt.text.trim(),
              icon: a.icon.text.trim(),
            ),
      ],
      worldBookIds: _worldBookIds.toList(),
      injectionIds: _injectionIds.toList(),
      settingIds: _settingIds.toList(),
      panels: [
        for (final p in _panels)
          StoryPanel(
            title: p.title.text.trim(),
            source: p.source,
            kind: p.kind.text.trim(),
            icon: p.icon.text.trim(),
          ),
      ],
      characters: [
        for (final c in _characters)
          if (c.name.trim().isNotEmpty) c,
      ],
      codex: [
        for (final d in _codexDefs)
          if (d.name.text.trim().isNotEmpty)
            StoryDefinition(
              kind: d.kind,
              key: d.key.text.trim().isEmpty
                  ? d.name.text.trim()
                  : d.key.text.trim(),
              name: d.name.text.trim(),
              display: d.display.text.trim(),
              mechanics: d.mechanics.text.trim(),
            ),
      ],
      titleMode: _titleMode,
      titles: [
        for (final x in _titles)
          if (x.name.text.trim().isNotEmpty)
            StoryTitle(
              key: x.key.text.trim().isEmpty
                  ? x.name.text.trim()
                  : x.key.text.trim(),
              name: x.name.text.trim(),
              effects: x.effects.text.trim(),
              stackable: x.stackable,
            ),
      ],
      job: (_jobNameCtrl.text.trim().isEmpty && _jobLevels.isEmpty)
          ? null
          : StoryJob(
              name: _jobNameCtrl.text.trim(),
              description: _jobDescCtrl.text.trim(),
              levels: [
                for (final l in _jobLevels)
                  if (l.name.text.trim().isNotEmpty ||
                      l.bonus.text.trim().isNotEmpty)
                    StoryJobLevel(
                      level: int.tryParse(l.level.text.trim()) ?? 0,
                      name: l.name.text.trim(),
                      bonus: l.bonus.text.trim(),
                    ),
              ],
            ),
      facilities: [
        for (final f in _facilities)
          if (f.name.text.trim().isNotEmpty)
            StoryFacility(
              key: f.key.text.trim().isEmpty
                  ? f.name.text.trim()
                  : f.key.text.trim(),
              name: f.name.text.trim(),
              description: f.description.text.trim(),
              maxLevel: int.tryParse(f.maxLevel.text.trim()) ?? 1,
            ),
      ],
      variables: [
        for (final v in _variables)
          if (v.name.text.trim().isNotEmpty)
            StoryVariable(
              name: v.name.text.trim(),
              value: v.value.text.trim(),
              description: v.description.text.trim(),
              type: v.type,
              min: int.tryParse(v.min.text.trim()),
              max: int.tryParse(v.max.text.trim()),
              unit: v.unit.text.trim(),
              options: v.options.text
                  .split(RegExp(r'[、,，/]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            ),
      ],
      regexes: [
        for (final r in _regexes)
          if (r.pattern.text.trim().isNotEmpty)
            StoryRegex(
              name: r.name.text.trim(),
              pattern: r.pattern.text.trim(),
              replacement: r.replacement.text,
              enabled: r.enabled,
              phase: r.phase,
              minDepth: int.tryParse(r.minDepth.text.trim()) ?? 0,
              maxDepth: int.tryParse(r.maxDepth.text.trim()) ?? 0,
            ),
      ],
      achievements: [
        for (final a in _achievements)
          if (a.key.text.trim().isNotEmpty)
            StoryAchievement(
              key: a.key.text.trim(),
              name: a.name.text.trim().isEmpty
                  ? a.key.text.trim()
                  : a.name.text.trim(),
              description: a.description.text.trim(),
            ),
      ],
      persona: StoryPersona(
        name: _personaNameCtrl.text.trim(),
        avatar: _personaAvatar,
        description: _personaDescCtrl.text.trim(),
      ),
      initialState: initialState,
      isBuiltin: widget.story?.isBuiltin ?? false,
    );
    await StoryStore.instance.upsert(story);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  /// 编辑/新增角色卡（index 为空表示新增）
  Future<void> _editCharacter(int? index) async {
    final existing = index == null ? null : _characters[index];
    final result = await showCharacterCardEditor(App.rootContext, existing);
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _characters.add(result);
      } else {
        _characters[index] = result;
      }
    });
  }

  /// 导入角色卡：从文件或从角色卡库
  Future<void> _importCharacterCard() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.importCharacter,
        icon: Icons.badge_outlined,
        initialSize: 0.34,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(t.importEntries),
              onTap: () => Navigator.of(ctx).pop('file'),
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(t.characterImportFromLibrary),
              onTap: () => Navigator.of(ctx).pop('library'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'file') {
      await _importCharacterFromFile();
    } else if (choice == 'library') {
      await _pickCharacterFromLibrary();
    }
  }

  /// 从文件导入角色卡（JSON / PNG）
  Future<void> _importCharacterFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final bytes = await result.files.first.readAsBytes();
      final card = CharacterCard.fromBytes(bytes);
      if (card == null) {
        App.rootContext.showMessage(
          message: t.characterImportFailed,
          level: LogLevel.error,
        );
        return;
      }
      if (!mounted) return;
      if (_hasCharacter(card)) {
        App.rootContext.showMessage(
          message: t.storyCharacterAlreadyAdded,
          level: LogLevel.warning,
        );
        return;
      }
      setState(() => _characters.add(card));
      App.rootContext.showMessage(message: t.storyImported);
    } catch (e) {
      App.rootContext.showMessage(
        message: t.characterImportFailed,
        level: LogLevel.error,
      );
    }
  }

  /// 该角色卡是否已在本故事中（按 id 或名字去重）
  bool _hasCharacter(CharacterCard c) {
    for (final x in _characters) {
      if (x.id.isNotEmpty && x.id == c.id) return true;
      if (x.name.trim().isNotEmpty && x.name.trim() == c.name.trim()) {
        return true;
      }
    }
    return false;
  }

  /// 弹出全局角色卡库选择器；[excludeAdded] 时不显示已添加过的
  Future<CharacterCard?> _pickCardFromLibrary({
    bool excludeAdded = false,
  }) async {
    await CharacterCardStore.instance.ensureLoaded();
    final all = CharacterCardStore.instance.cards;
    final cards = excludeAdded
        ? [for (final c in all) if (!_hasCharacter(c)) c]
        : all;
    if (cards.isEmpty) {
      App.rootContext.showMessage(
        message: all.isEmpty
            ? t.characterCardsEmpty
            : t.storyAllCharactersAdded,
        level: LogLevel.warning,
      );
      return null;
    }
    return showModalBottomSheet<CharacterCard>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.characterImportFromLibrary,
        icon: Icons.badge_outlined,
        initialSize: 0.6,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            for (final c in cards)
              ListTile(
                leading: CharacterAvatar(
                  name: c.name,
                  avatar: c.avatar,
                  radius: 16,
                ),
                title: Text(c.name),
                subtitle: c.tags.isEmpty ? null : Text(c.tags.join(' · ')),
                onTap: () => Navigator.of(ctx).pop(c),
              ),
          ],
        ),
      ),
    );
  }

  /// 从全局角色卡库选择为 NPC（已添加过的不再显示）
  Future<void> _pickCharacterFromLibrary() async {
    final picked = await _pickCardFromLibrary(excludeAdded: true);
    if (picked == null || !mounted) return;
    if (_hasCharacter(picked)) {
      App.rootContext.showMessage(
        message: t.storyCharacterAlreadyAdded,
        level: LogLevel.warning,
      );
      return;
    }
    setState(() => _characters.add(picked));
  }

  /// 从全局角色卡库选择，填入玩家角色
  Future<void> _pickPersonaFromLibrary() async {
    final picked = await _pickCardFromLibrary();
    if (picked == null || !mounted) return;
    setState(() {
      _personaNameCtrl.text = picked.name;
      _personaAvatar = picked.avatar;
      _personaDescCtrl.text = picked.description;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _editorTabs();
    return PopUpWidgetScaffold(
      title: _isNew ? t.storyNew : t.storyEdit,
      tailing: [
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: t.apply,
          onPressed: _save,
        ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: CapsuleOptions(
                scrollable: true,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    CapsuleOption(
                      text: tabs[i].$1,
                      isSelected: _tab == i,
                      onTap: () => setState(() => _tab = i),
                    ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab.clamp(0, tabs.length - 1),
                children: [
                  for (final tab in tabs)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                      child: tab.$2,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 编辑器分区（分段胶囊 tab）
  List<(String, Widget)> _editorTabs() => [
    (t.basicInfo, _basicTab()),
    (t.storyPersona, _personaTab()),
    (t.storyOpening, _textTab(_openingCtrl)),
    (t.storySystemPrompt, _systemPromptTab()),
    (t.storyWorldBook, _worldBookTab()),
    (t.storySituation, _textTab(_situationCtrl)),
    (t.storyInitialState, _textTab(_stateCtrl)),
    (t.storyChoicesPrompt, _textTab(_choicesCtrl)),
    (t.storyActions, _actionsTab()),
    (t.storyLibrary, _libraryTab()),
    (t.storySettingLibrary, _settingLibraryTab()),
    (t.storyPanels, _panelsTab()),
    (t.storyAdvanced, _advancedTab()),
  ];

  Widget _basicTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(t.name, _nameCtrl),
        _field(
          t.rolePlayDescription,
          _descCtrl,
          required: false,
          multiline: true,
        ),
        _deathSection(),
        _genParamsSection(),
      ],
    );
  }

  /// 生成参数（temperature / top_p / max tokens，留空跟随默认）
  Widget _genParamsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Text(
            t.storyGenParams,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Row(
          children: [
            Expanded(child: _field(t.temperature, _tempCtrl, required: false)),
            Expanded(child: _field(t.topP, _topPCtrl, required: false)),
            Expanded(
              child: _field(t.maxTokens, _maxTokensCtrl, required: false),
            ),
          ],
        ),
      ],
    );
  }

  /// 致命资源：判定方式（任一/全部归零）+ 资源名
  Widget _deathSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              Text(
                '${t.storyDeathMode}: ',
                style: const TextStyle(fontSize: 13),
              ),
              Select(
                current: _deathMode == 'all'
                    ? t.storyDeathModeAll
                    : t.storyDeathModeAny,
                values: [t.storyDeathModeAny, t.storyDeathModeAll],
                onTap: (i) =>
                    setState(() => _deathMode = i == 1 ? 'all' : 'any'),
              ),
            ],
          ),
        ),
        _field(t.storyDeathResources, _deathCtrl, required: false),
      ],
    );
  }

  Widget _personaTab() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Text(
            t.storyPersonaHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        _field(t.storyCharacterName, _personaNameCtrl, required: false),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.badge_outlined, size: 18),
            label: Text(t.characterImportFromLibrary),
            onPressed: _pickPersonaFromLibrary,
          ),
        ),
        AvatarPicker(
          name: _personaNameCtrl.text,
          avatar: _personaAvatar,
          onChanged: (v) => setState(() => _personaAvatar = v),
        ),
        _field(
          t.characterDescription,
          _personaDescCtrl,
          required: false,
          multiline: true,
        ),
      ],
    );
  }

  Widget _textTab(TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        controller: ctrl,
        minLines: 6,
        maxLines: null,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    );
  }

  /// 系统提示词：可导入 SillyTavern 预设 / 纯文本提示词
  Widget _systemPromptTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _importPrompt,
            icon: const Icon(Icons.file_open_outlined, size: 18),
            label: Text(t.storyImportPrompt),
          ),
        ),
        _textTab(_systemCtrl),
      ],
    );
  }

  Future<void> _importPrompt() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt', 'md'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final text = utf8.decode(await result.files.first.readAsBytes());
      final prompt = _extractPrompt(text);
      if (prompt == null || prompt.trim().isEmpty) {
        App.rootContext.showMessage(
          message: t.importFailed,
          level: LogLevel.error,
        );
        return;
      }
      setState(() {
        final cur = _systemCtrl.text.trim();
        _systemCtrl.text = cur.isEmpty ? prompt.trim() : '$cur\n\n${prompt.trim()}';
      });
      App.rootContext.showMessage(message: t.storyImported);
    } catch (e) {
      App.rootContext.showMessage(
        message: t.importFailed,
        level: LogLevel.error,
      );
    }
  }

  /// 从 ST 预设 JSON（prompts/prompt_order）或纯文本中提取提示词
  String? _extractPrompt(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final prompts = decoded['prompts'];
          if (prompts is List) {
            final enabled = <String>{};
            final order = decoded['prompt_order'];
            if (order is List && order.isNotEmpty) {
              final first = order.first;
              final list = first is Map ? first['order'] : first;
              if (list is List) {
                for (final o in list) {
                  if (o is Map &&
                      o['enabled'] != false &&
                      o['identifier'] != null) {
                    enabled.add(o['identifier'].toString());
                  }
                }
              }
            }
            final buf = StringBuffer();
            for (final p in prompts) {
              if (p is! Map) continue;
              final id = p['identifier']?.toString() ?? '';
              if (enabled.isNotEmpty && !enabled.contains(id)) continue;
              final c = (p['content'] ?? '').toString().trim();
              if (c.isEmpty) continue;
              buf.writeln('【${(p['name'] ?? id).toString()}】');
              buf.writeln(c);
              buf.writeln();
            }
            final out = buf.toString().trim();
            if (out.isNotEmpty) return out;
          }
          final sp = decoded['system_prompt'] ?? decoded['systemPrompt'];
          if (sp is String && sp.trim().isNotEmpty) return sp.trim();
        }
      } catch (_) {}
    }
    return trimmed;
  }

  Widget _worldBookTab() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _worldBook.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant, width: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _worldBook[i].name,
                        decoration: InputDecoration(
                          labelText: t.worldBookName,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _worldBook[i].dispose();
                        _worldBook.removeAt(i);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _worldBook[i].content,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: t.worldBookContent,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _worldBook.add(_WorldBookDraft())),
          icon: const Icon(Icons.add),
          label: Text(t.add),
        ),
      ],
    );
  }

  Widget _actionsTab() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _actions.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant, width: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _actions[i].label,
                        decoration: InputDecoration(
                          labelText: t.storyActionLabel,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TextFormField(
                          controller: _actions[i].icon,
                          decoration: InputDecoration(
                            labelText: t.storyActionIcon,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _actions[i].dispose();
                        _actions.removeAt(i);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _actions[i].prompt,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: t.storyActionPrompt,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(() => _actions.add(_StoryActionDraft())),
          icon: const Icon(Icons.add),
          label: Text(t.storyAddAction),
        ),
      ],
    );
  }

  Widget _libraryTab() {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        WorldBookStore.instance,
        PromptInjectionStore.instance,
      ]),
      builder: (context, _) {
        final worldBook = WorldBookStore.instance.entries;
        final injections = PromptInjectionStore.instance.items;
        final manage = Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => App.rootContext.to(
              () => const PromptManagementSettingsPage(),
            ),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(t.storyLibraryManage),
          ),
        );
        if (worldBook.isEmpty && injections.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.storyLibraryEmpty, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                manage,
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            manage,
            Text(
              t.storyLibraryHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (worldBook.isNotEmpty) ...[
              Text(
                t.worldBook,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final e in worldBook)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name.isEmpty ? e.content : e.name),
                  value: _worldBookIds.contains(e.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _worldBookIds.add(e.id);
                    } else {
                      _worldBookIds.remove(e.id);
                    }
                  }),
                ),
              const SizedBox(height: 12),
            ],
            if (injections.isNotEmpty) ...[
              Text(
                t.promptInjection,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final i in injections)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i.name),
                  value: _injectionIds.contains(i.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _injectionIds.add(i.id);
                    } else {
                      _injectionIds.remove(i.id);
                    }
                  }),
                ),
            ],
          ],
        );
      },
    );
  }

  /// 设定库：勾选要并入本故事的词条 / 称号 / 职业 / 据点
  Widget _settingLibraryTab() {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: SettingLibraryStore.instance,
      builder: (context, _) {
        final store = SettingLibraryStore.instance;
        final manage = Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => App.rootContext.to(
              () => const PromptManagementSettingsPage(),
            ),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: Text(t.storyLibraryManage),
          ),
        );
        if (store.items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.storySettingLibraryEmpty,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                manage,
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            manage,
            Text(
              t.storySettingLibraryHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final type in SettingTypes.all)
              if (store.byType(type).isNotEmpty) ...[
                Text(
                  _settingTypeLabel(type),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final e in store.byType(type))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.name.isEmpty ? e.id : e.name),
                    value: _settingIds.contains(e.id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _settingIds.add(e.id);
                      } else {
                        _settingIds.remove(e.id);
                      }
                    }),
                  ),
              ],
          ],
        );
      },
    );
  }

  String _settingTypeLabel(String type) => switch (type) {
    SettingTypes.codex => t.storyCodex,
    SettingTypes.title => t.storyTitles,
    SettingTypes.job => t.storyJob,
    SettingTypes.facility => t.storyBase,
    _ => type,
  };

  Widget _panelsTab() {
    final scheme = Theme.of(context).colorScheme;
    const sources = [
      'resources',
      'attributes',
      'skills',
      'inventory',
      'quests',
      'effects',
      'titles',
      'job',
      'base',
      'codex',
      'variables',
      'equipment',
      'combat',
      'achievements',
    ];
    String sourceLabel(String s) => switch (s) {
      'resources' => t.storyResources,
      'attributes' => t.storyAttributes,
      'skills' => t.skills,
      'inventory' => t.storyInventory,
      'quests' => t.storyQuests,
      'effects' => t.storyEffects,
      'titles' => t.storyTitles,
      'job' => t.storyJob,
      'base' => t.storyBase,
      'codex' => t.storyCodex,
      'variables' => t.storyVariables,
      'equipment' => t.storyEquipment,
      'combat' => t.storyCombat,
      'achievements' => t.storyAchievements,
      _ => s,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _panels.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant, width: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _panels[i].title,
                        decoration: InputDecoration(
                          labelText: t.storyPanelTitle,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TextFormField(
                          controller: _panels[i].icon,
                          decoration: InputDecoration(
                            labelText: t.storyActionIcon,
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _panels[i].dispose();
                        _panels.removeAt(i);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${t.storyPanelSource}: ',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Select(
                      current: sourceLabel(_panels[i].source),
                      values: [for (final s in sources) sourceLabel(s)],
                      onTap: (idx) =>
                          setState(() => _panels[i].source = sources[idx]),
                    ),
                  ],
                ),
                if (_panels[i].source == 'codex') ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _panels[i].kind,
                    decoration: InputDecoration(
                      labelText: t.storyPanelKind,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _panels.add(_StoryPanelDraft())),
              icon: const Icon(Icons.add),
              label: Text(t.storyAddPanel),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                for (final p in _panels) {
                  p.dispose();
                }
                _panels
                  ..clear()
                  ..addAll([
                    for (final p in Story.defaultPanels)
                      _StoryPanelDraft(
                        titleText: p.title,
                        source: p.source,
                        kindText: p.kind,
                        iconText: p.icon,
                      ),
                  ]);
              }),
              icon: const Icon(Icons.restart_alt),
              label: Text(t.storyResetPanels),
            ),
          ],
        ),
      ],
    );
  }

  Widget _advancedTab() {
    final scheme = Theme.of(context).colorScheme;
    Widget card(List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant, width: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(t.storyCodexDefs),
        for (var i = 0; i < _codexDefs.length; i++)
          card([
            Row(
              children: [
                Select(
                  current: _codexKindName(_codexDefs[i].kind),
                  values: [for (final k in _codexKinds) _codexKindName(k)],
                  onTap: (idx) => setState(
                    () => _codexDefs[i].kind = _codexKinds[idx],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _codexDefs.removeAt(i).dispose()),
                ),
              ],
            ),
            TextFormField(
              controller: _codexDefs[i].name,
              decoration: InputDecoration(
                labelText: t.storyCharacterName,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codexDefs[i].display,
              decoration: InputDecoration(
                labelText: t.storyCodexDisplay,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _codexDefs[i].mechanics,
              decoration: InputDecoration(
                labelText: t.storyCodexMechanics,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _codexDefs.add(_StoryCodexDraft())),
            icon: const Icon(Icons.add),
            label: Text(t.storyAddEntry),
          ),
        ),

        // ── 称号 ──
        sectionTitle(t.storyTitles),
        Row(
          children: [
            Text(
              '${t.storyTitleMode}: ',
              style: const TextStyle(fontSize: 13),
            ),
            Select(
              current: _titleMode == 'equipped'
                  ? t.storyTitleModeEquipped
                  : t.storyTitleModeAll,
              values: [t.storyTitleModeAll, t.storyTitleModeEquipped],
              onTap: (i) =>
                  setState(() => _titleMode = i == 1 ? 'equipped' : 'all'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _titles.length; i++)
          card([
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _titles[i].name,
                    decoration: InputDecoration(
                      labelText: t.storyCharacterName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _titles.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titles[i].effects,
              decoration: InputDecoration(
                labelText: t.storyCodexMechanics,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            Row(
              children: [
                Text(t.storyTitleStackable),
                const Spacer(),
                CustomSwitch(
                  value: _titles[i].stackable,
                  onChanged: (v) =>
                      setState(() => _titles[i].stackable = v),
                ),
              ],
            ),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _titles.add(_StoryTitleDraft())),
            icon: const Icon(Icons.add),
            label: Text(t.storyAddEntry),
          ),
        ),

        // ── 职业 ──
        sectionTitle(t.storyJob),
        TextFormField(
          controller: _jobNameCtrl,
          decoration: InputDecoration(
            labelText: t.storyCharacterName,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _jobDescCtrl,
          decoration: InputDecoration(
            labelText: t.storyCodexDisplay,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _jobLevels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: TextFormField(
                    controller: _jobLevels[i].level,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t.storyJobLevel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    controller: _jobLevels[i].name,
                    decoration: InputDecoration(
                      labelText: t.storyCharacterName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextFormField(
                    controller: _jobLevels[i].bonus,
                    decoration: InputDecoration(
                      labelText: t.storyJobBonus,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _jobLevels.removeAt(i).dispose()),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _jobLevels.add(_StoryJobLevelDraft())),
            icon: const Icon(Icons.add),
            label: Text(t.storyAddEntry),
          ),
        ),

        // ── 据点 ──
        sectionTitle(t.storyBase),
        for (var i = 0; i < _facilities.length; i++)
          card([
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _facilities[i].name,
                    decoration: InputDecoration(
                      labelText: t.storyCharacterName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: _facilities[i].maxLevel,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t.storyBaseMaxLevel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _facilities.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _facilities[i].description,
              decoration: InputDecoration(
                labelText: t.storyCodexDisplay,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _facilities.add(_StoryFacilityDraft())),
            icon: const Icon(Icons.add),
            label: Text(t.storyAddEntry),
          ),
        ),

        sectionTitle(t.storyCharacters),
        for (var i = 0; i < _characters.length; i++)
          card([
            Row(
              children: [
                CharacterAvatar(
                  name: _characters[i].name,
                  avatar: _characters[i].avatar,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _characters[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (_characters[i].tags.isNotEmpty)
                        Text(
                          _characters[i].tags.join(' · '),
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: t.edit,
                  onPressed: () => _editCharacter(i),
                ),
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: t.characterExport,
                  onPressed: () => exportCharacterCardPng(_characters[i]),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _characters.removeAt(i)),
                ),
              ],
            ),
          ]),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _editCharacter(null),
              icon: const Icon(Icons.add),
              label: Text(t.storyAddCharacter),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _importCharacterCard,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(t.importCharacter),
            ),
          ],
        ),
        sectionTitle(t.storyVariables),
        for (var i = 0; i < _variables.length; i++)
          card([
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _variables[i].name,
                    decoration: InputDecoration(
                      labelText: t.storyVariableName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _variables[i].value,
                    decoration: InputDecoration(
                      labelText: t.storyVariableValue,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    _variables[i].dispose();
                    _variables.removeAt(i);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _variables[i].description,
              decoration: InputDecoration(
                labelText: t.storyVariableDescription,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${t.storyVariableType}: ',
                  style: const TextStyle(fontSize: 13),
                ),
                Select(
                  current: switch (_variables[i].type) {
                    'number' => t.storyVarTypeNumber,
                    'enum' => t.storyVarTypeEnum,
                    _ => t.storyVarTypeText,
                  },
                  values: [
                    t.storyVarTypeText,
                    t.storyVarTypeNumber,
                    t.storyVarTypeEnum,
                  ],
                  onTap: (idx) => setState(
                    () => _variables[i].type = const [
                      'text',
                      'number',
                      'enum',
                    ][idx],
                  ),
                ),
                const Spacer(),
                if (_variables[i].type == 'number') ...[
                  SizedBox(
                    width: 68,
                    child: TextFormField(
                      controller: _variables[i].min,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t.storyVariableMin,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 68,
                    child: TextFormField(
                      controller: _variables[i].max,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: t.storyVariableMax,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 68,
                    child: TextFormField(
                      controller: _variables[i].unit,
                      decoration: InputDecoration(
                        labelText: t.storyVariableUnit,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (_variables[i].type == 'enum') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _variables[i].options,
                decoration: InputDecoration(
                  labelText: t.storyVariableOptions,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ]),
        TextButton.icon(
          onPressed: () => setState(() => _variables.add(_StoryVariableDraft())),
          icon: const Icon(Icons.add),
          label: Text(t.storyAddVariable),
        ),
        sectionTitle(t.storyRegex),
        for (var i = 0; i < _regexes.length; i++)
          card([
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regexes[i].name,
                    decoration: InputDecoration(
                      labelText: t.storyRegexName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    _regexes[i].dispose();
                    _regexes.removeAt(i);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _regexes[i].pattern,
              decoration: InputDecoration(
                labelText: t.storyRegexPattern,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _regexes[i].replacement,
              decoration: InputDecoration(
                labelText: t.storyRegexReplacement,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${t.storyRegexPhase}: ',
                  style: const TextStyle(fontSize: 13),
                ),
                Select(
                  current: switch (_regexes[i].phase) {
                    'send' => t.storyRegexTargetUser,
                    'both' => t.storyRegexTargetBoth,
                    _ => t.storyRegexTargetAi,
                  },
                  values: [
                    t.storyRegexTargetAi,
                    t.storyRegexTargetUser,
                    t.storyRegexTargetBoth,
                  ],
                  onTap: (idx) => setState(
                    () => _regexes[i].phase = const [
                      'display',
                      'send',
                      'both',
                    ][idx],
                  ),
                ),
                const Spacer(),
                Text(
                  t.storyRegexEnabled,
                  style: const TextStyle(fontSize: 13),
                ),
                CustomSwitch(
                  value: _regexes[i].enabled,
                  onChanged: (v) => setState(() => _regexes[i].enabled = v),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regexes[i].minDepth,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t.storyRegexMinDepth,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _regexes[i].maxDepth,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t.storyRegexMaxDepth,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ]),
        TextButton.icon(
          onPressed: () => setState(() => _regexes.add(_StoryRegexDraft())),
          icon: const Icon(Icons.add),
          label: Text(t.storyAddRegex),
        ),
        sectionTitle(t.storyAchievements),
        for (var i = 0; i < _achievements.length; i++)
          card([
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _achievements[i].key,
                    decoration: InputDecoration(
                      labelText: t.storyRegexName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _achievements[i].name,
                    decoration: InputDecoration(
                      labelText: t.storyCharacterName,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    _achievements[i].dispose();
                    _achievements.removeAt(i);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _achievements[i].description,
              decoration: InputDecoration(
                labelText: t.storyCharacterDescription,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ]),
        TextButton.icon(
          onPressed: () =>
              setState(() => _achievements.add(_StoryAchievementDraft())),
          icon: const Icon(Icons.add),
          label: Text(t.storyAddAction),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = true,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        controller: ctrl,
        maxLines: multiline ? 6 : 1,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? t.required : null
            : null,
      ),
    );
  }
}


// ─────────────────────────────────────────────
// 文字冒险游戏页
// ─────────────────────────────────────────────

class StoryGamePage extends ConsumerStatefulWidget {
  const StoryGamePage({super.key, required this.story});

  final Story story;

  @override
  ConsumerState<StoryGamePage> createState() => _StoryGamePageState();
}

class _StoryGamePageState extends ConsumerState<StoryGamePage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();
  String? _sessionId;
  GameState _state = GameState.empty;
  bool _sending = false;
  bool _booting = true;
  bool _showStreamBubble = false;
  String _streamText = '';
  CancelToken? _cancelToken;
  int _lastMessageCount = 0;

  /// 上次发送的原始输入（失败后用于重试）
  String? _lastOutgoing;
  bool _lastFailed = false;

  /// 流式长时间无输出时的看门狗（超时中断，避免一直卡住）
  Timer? _stallTimer;
  bool _stallAborted = false;

  /// 新增但未在图鉴登记的物品（故事层校验结果）
  List<String> _unregistered = const [];
  bool _registering = false;

  /// 是否跟随到底部（用户上滑后暂停，发送时恢复）
  bool _isFollowing = true;

  /// 发送后、真正落库前先乐观显示的用户消息
  String? _pendingUserText;

  /// 需要先做开局档案设置（仅新游戏且故事定义了 setup 时）
  bool _needsSetup = false;
  final Map<String, String> _singleValues = {};
  final Map<String, Set<String>> _multiValues = {};
  final Map<String, TextEditingController> _textValues = {};
  final Map<String, int> _numberValues = {};

  /// 运行时故事：并入从设定库选择的条目（词条/称号/职业/据点）
  late final Story _effective = _mergeSettings(widget.story);

  Story _mergeSettings(Story s) {
    if (s.settingIds.isEmpty) return s;
    final entries = <SettingEntry>[];
    for (final id in s.settingIds) {
      final e = SettingLibraryStore.instance.find(id);
      if (e != null) entries.add(e);
    }
    return mergeSettingLibrary(s, entries);
  }

  Story get story => _effective;

  @override
  void initState() {
    super.initState();
    StoryTextStyleStore.instance.ensureLoaded();
    _boot();
  }

  /// 是否已贴近底部（列表 reverse，底部即 offset 0）
  static bool _atBottom(ScrollMetrics m) => m.pixels <= 48;

  /// 滚动状态机：offset 增大（reverse 列表 = 上滑看历史）即暂停跟随；
  /// 回到底部恢复跟随。程序滚动只会把 offset 拉向 0（变小），不会误判。
  bool _onUserScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.horizontal) return false;
    if (n is UserScrollNotification) {
      if (n.direction != ScrollDirection.idle &&
          !_atBottom(n.metrics) &&
          _isFollowing) {
        setState(() => _isFollowing = false);
      }
    } else if (n is ScrollUpdateNotification) {
      if ((n.scrollDelta ?? 0) > 0 && !_atBottom(n.metrics)) {
        if (_isFollowing) setState(() => _isFollowing = false);
      } else if (_atBottom(n.metrics) && !_isFollowing) {
        setState(() => _isFollowing = true);
      }
    }
    return false;
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    for (final c in _textValues.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 滚到底部（列表 reverse，底部即 offset 0）；非跟随状态不强制
  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!force && !_isFollowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // 回调排队期间用户可能已上滑，重新确认，避免把用户拽回底部
      if (!force && !_isFollowing) return;
      if (animate) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else if (_scrollController.offset.abs() > 1) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _boot() async {
    await StorySessionStore.instance.ensureLoaded();
    final saved = StorySessionStore.instance.get(story.id);
    if (saved != null && saved.sessionId.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _sessionId = saved.sessionId;
        _state = _mergeResources(saved.state);
        _booting = false;
      });
      // 按消息折叠变量，恢复分支正确的最新值
      await _applyFoldedVariables();
      return;
    }
    // 新游戏：有开局档案则先让玩家设置，否则直接开始
    if (story.setup.isNotEmpty) {
      setState(() {
        _booting = false;
        _needsSetup = true;
      });
      return;
    }
    await _newSession();
    await _send(t.storyCmdStart);
  }

  Future<void> _newSession({GameState? initialState}) async {
    var initial = initialState ?? story.initialState;
    // 故事预置词条并入初始状态（开局即已知）
    if (story.codex.isNotEmpty) {
      final seen = {
        for (final d in initial.codex) '${d.kind}\u0000${d.key}': true,
      };
      final merged = [...initial.codex];
      for (final d in story.codex) {
        if (seen['${d.kind}\u0000${d.key}'] == true) continue;
        merged.add(d);
        seen['${d.kind}\u0000${d.key}'] = true;
      }
      initial = initial.copyWith(codex: merged);
    }
    // 把故事声明的变量初值并入初始状态
    if (story.variables.isNotEmpty) {
      final vars = Map<String, String>.from(initial.variables);
      for (final v in story.variables) {
        if (v.name.trim().isEmpty) continue;
        vars.putIfAbsent(v.name.trim(), () => v.value);
      }
      initial = initial.copyWith(variables: vars);
    }
    final old = _sessionId;
    if (old != null) {
      await AiConversationService().deleteSession(old);
    }
    final sessionId = await AiConversationService().createSession(
      type: 'story',
      provider: aiHubProvider(),
      title: story.name,
    );
    if (!mounted) return;
    setState(() {
      _sessionId = sessionId;
      _state = initial;
      _booting = false;
    });
    await StorySessionStore.instance.put(
      story.id,
      StorySession(sessionId: sessionId, state: initial),
    );
  }

  /// 校验并生成开局档案文本，然后开局（数值项并入初始状态属性）
  Future<void> _startWithSetup() async {
    final buf = StringBuffer(t.storyCmdProfile);
    final attrs = Map<String, int>.from(story.initialState.attributes);
    for (final part in story.setup) {
      final value = switch (part.type) {
        'multi' => (_multiValues[part.key] ?? const <String>{}).join('、'),
        'text' => (_textValues[part.key]?.text.trim() ?? ''),
        'number' => '${_partNumber(part)}',
        _ => (_singleValues[part.key] ?? ''),
      };
      if (part.required && value.isEmpty) {
        App.rootContext.showMessage(
          message: '${t.required}: ${part.title}',
          level: LogLevel.warning,
        );
        return;
      }
      if (value.isEmpty) continue;
      buf.writeln('${part.title}：$value');
      if (part.type == 'number') attrs[part.title] = _partNumber(part);
    }
    final initial = story.initialState.copyWith(attributes: attrs);
    setState(() => _needsSetup = false);
    await _newSession(initialState: initial);
    await _send(buf.toString());
  }

  /// 系统提示词：故事定义 + 开局场景 + 已积累的设定图鉴（供 AI 严格遵守）
  Future<String> _systemPromptFor(
    GameState state, {
    String scanText = '',
  }) async {
    final vars = state.variables;
    final persona = story.persona;
    String sub(String text) {
      var out = replaceStoryVars(text, vars);
      if (!persona.isEmpty) {
        final name = persona.name.trim().isEmpty ? '玩家' : persona.name.trim();
        out = out
            .replaceAll('{{user}}', name)
            .replaceAll('{{persona}}', persona.description.trim());
      }
      return out;
    }

    final buf = StringBuffer(sub(story.buildSystemPrompt()));
    if (!persona.isEmpty) {
      buf.write('\n\n【玩家角色（用户本人，禁止扮演；你只需知道他是谁）】');
      if (persona.name.trim().isNotEmpty) {
        buf.write('\n名字：${persona.name.trim()}');
      }
      if (persona.description.trim().isNotEmpty) {
        buf.write('\n${persona.description.trim()}');
      }
    }
    if (story.opening.trim().isNotEmpty) {
      buf.write('\n\n【开局场景（请从这里开始叙事）】\n${sub(story.opening.trim())}');
    }
    if (story.deathResources.isNotEmpty) {
      final rule = story.deathMode == 'all'
          ? '全部归零才结束'
          : '任意一个归零即结束';
      buf.write(
        '\n\n【致命资源（$rule，请在归零前给出收尾叙事）】'
        '${story.deathResources.join('、')}',
      );
    }
    if (state.resources.isNotEmpty) {
      buf.write('\n\n【数值条（每回合都要完整回传，勿遗漏任何一条）】');
      for (final r in state.resources) {
        buf.write('\n- ${r.name} ${r.cur}/${r.max}');
      }
    }
    if (story.characters.isNotEmpty) {
      buf.write('\n\n【角色设定（需分别扮演，保持各自语气与人设）】');
      for (final c in story.characters) {
        buf.write('\n- ${c.name}');
        if (c.personality.trim().isNotEmpty) {
          buf.write('（${c.personality.trim()}）');
        }
        if (c.description.trim().isNotEmpty) {
          buf.write('：${sub(c.description.trim())}');
        }
      }
      buf.write(
        '\n当前在场：'
        '${state.present.isEmpty ? '（暂无。仅在剧情推进需要时逐个引入角色，不要一次性让所有角色登场）' : state.present.join('、')}',
      );
    }
    if (story.achievements.isNotEmpty) {
      buf.write('\n\n【成就（解锁时把 key 加入 achievements，勿自创）】');
      for (final a in story.achievements) {
        buf.write('\n- ${a.key}：${a.name}');
        if (a.description.trim().isNotEmpty) {
          buf.write('（${a.description.trim()}）');
        }
      }
    }
    if (state.equipped.isNotEmpty) {
      buf.write('\n\n【已装备（其机制当前生效）】${state.equipped.join('、')}');
    }
    if (state.combat.active) {
      buf.write('\n\n【战斗中 · 第${state.combat.round}回合】');
      for (final e in state.combat.enemies) {
        buf.write('\n- ${e.name} ${e.hp}/${e.maxHp}${e.note.isEmpty ? '' : '（${e.note}）'}');
      }
    }
    if (vars.isNotEmpty) {
      buf.write('\n\n【变量（每回合回传最新值，需遵守类型约束）】');
      final declared = {for (final v in story.variables) v.name: v};
      for (final e in vars.entries) {
        final d = declared[e.key];
        final meta = <String>[];
        if (d != null) {
          if (d.type == 'number') {
            final range = [
              if (d.min != null) '${d.min}',
              if (d.max != null) '${d.max}',
            ].join('~');
            meta.add(
              '数值${range.isEmpty ? '' : ' $range'}'
              '${d.unit.isEmpty ? '' : d.unit}',
            );
          } else if (d.type == 'enum' && d.options.isNotEmpty) {
            meta.add('取值：${d.options.join('/')}');
          }
          if (d.description.trim().isNotEmpty) meta.add(d.description.trim());
        }
        buf.write(
          '\n- ${e.key} = ${e.value}${meta.isEmpty ? '' : '（${meta.join('；')}）'}',
        );
      }
    }
    if (state.codex.isNotEmpty) {
      buf.write('\n\n【已知设定（必须严格遵守，不得矛盾）】');
      for (final d in state.codex) {
        buf.write(
          '\n- ${d.name}（${d.kind}）：'
          '${d.mechanics.isEmpty ? d.display : d.mechanics}',
        );
      }
    }
    if (state.situation.trim().isNotEmpty) {
      buf.write('\n\n【当前局势（延续此设定，除非剧情已推进）】\n');
      buf.write(state.situation.trim());
    }
    // 故事从库里显式选择的世界书 / 提示词（未选则不注入）
    final injections = await PromptInjectionStore.instance.selectExact(
      story.injectionIds.toSet(),
    );
    for (final inj in injections) {
      if (inj.content.trim().isEmpty) continue;
      buf.write('\n\n【${inj.name.trim().isEmpty ? '提示词' : inj.name.trim()}】\n');
      buf.write(inj.content.trim());
    }
    final worldBook = await WorldBookStore.instance.selectAll(
      story.worldBookIds.toSet(),
    );
    if (worldBook.isNotEmpty) {
      buf.write('\n\n【世界书】');
      var seq = 0;
      for (final e in worldBook) {
        if (e.content.trim().isEmpty) continue;
        seq++;
        buf.write('\n$seq. ${e.content.trim()}');
      }
    }
    // 角色世界书：仅对在场（或未标记在场时全部）角色按 ST 语义扫描
    final activeCards = state.present.isEmpty
        ? story.characters
        : [
            for (final c in story.characters)
              if (state.present.contains(c.name)) c,
          ];
    if (activeCards.isNotEmpty) {
      final scanMessages = <String>[];
      final sessionId = _sessionId;
      if (sessionId != null) {
        final msgs = await AiConversationService()
            .watchMessages(sessionId)
            .first;
        for (final m in msgs) {
          scanMessages.add(
            m.role == 'user' ? m.inputContent : (m.outputContent ?? ''),
          );
        }
      }
      if (scanText.isNotEmpty) scanMessages.add(scanText);
      for (final c in activeCards) {
        final book = CharacterLoreBook.fromMap(c.characterBook);
        if (book == null) continue;
        final hits = CharacterLorebookResolver.instance.resolve(
          book,
          scanMessages,
          cardId: c.id,
          turn: _lastMessageCount ~/ 2,
        );
        if (hits.isEmpty) continue;
        buf.write('\n\n【角色世界书 · ${c.name}】');
        var seq = 0;
        for (final e in hits) {
          if (e.content.trim().isEmpty) continue;
          seq++;
          buf.write('\n$seq. ${e.content.trim()}');
        }
      }
    }
    return buf.toString();
  }

  Future<void> _send(String text) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    final outgoing = applyStoryRegex(text, story.regexes, 'send');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _lastOutgoing = text;
    _stallAborted = false;
    setState(() {
      _sending = true;
      _showStreamBubble = true;
      _streamText = '';
      _pendingUserText = outgoing;
      _isFollowing = true;
      _lastFailed = false;
    });
    _scrollToBottom(force: true);
    _armStallWatchdog();
    try {
      await for (final u in AiConversationService().sendMessageStream(
        sessionId: sessionId,
        userMessage: outgoing,
        taskType: 'story',
        useTools: false,
        providerOverride: aiHubProvider(),
        systemPromptOverride: await _systemPromptFor(
          _state,
          scanText: outgoing,
        ),
        paramsOverride: _storyParams(),
        cancelToken: cancelToken,
      )) {
        if (!mounted) return;
        _armStallWatchdog();
        if (u.errorMessage != null) {
          setState(() {
            _sending = false;
            _showStreamBubble = false;
            _streamText = '';
            _pendingUserText = null;
            _lastFailed = true;
          });
          App.rootContext.showMessage(
            message: u.errorMessage!,
            level: LogLevel.error,
          );
          return;
        }
        setState(() {
          _pendingUserText = null;
          _streamText = u.text;
        });
        _scrollToBottom(animate: false);
        if (u.done) break;
      }
      if (!mounted) return;
      final finalText = _streamText;
      final cancelled = cancelToken.isCancelled;
      final stalled = _stallAborted;
      setState(() {
        _sending = false;
        _showStreamBubble = false;
        _streamText = '';
        _pendingUserText = null;
        // 空回复视为失败，可重试；用户主动停止且有内容时不提示重试
        _lastFailed = finalText.trim().isEmpty;
      });
      _scrollToBottom();
      if (stalled) {
        App.rootContext.showMessage(
          message: t.storyResponseStalled,
          level: LogLevel.warning,
        );
      }
      // 取消时服务端不落库，忽略本次结果
      if (cancelled || finalText.trim().isEmpty) return;
      final parsed = _parseReply(finalText);
      if (parsed.state != null || parsed.varOps.isNotEmpty) {
        var state = parsed.state ?? _state;
        // 变量：增量叠加到当前值
        if (parsed.varOps.isNotEmpty) {
          state = state.copyWith(
            variables: applyVarOps(_state.variables, parsed.varOps),
          );
        } else if (state.variables.isEmpty) {
          state = state.copyWith(variables: _state.variables);
        }
        // 把「获得道具」事件并入背包（去重），保证道具一定被持久化
        final gained = parsed.events
            .where((e) => e.type == 'item' && e.text.trim().isNotEmpty)
            .map((e) => e.text.trim());
        if (gained.isNotEmpty) {
          final inv = [...state.inventory];
          for (final item in gained) {
            if (!inv.contains(item)) inv.add(item);
          }
          state = state.copyWith(inventory: inv);
        }
        await _applyState(state);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _showStreamBubble = false;
          _streamText = '';
          _pendingUserText = null;
          _lastFailed = true;
        });
        App.rootContext.showMessage(message: e.toString(), level: LogLevel.error);
      }
    } finally {
      _stallTimer?.cancel();
      _cancelToken = null;
    }
  }

  /// 流式看门狗：超过 90 秒没有任何输出则中断本次回复（可重试）
  void _armStallWatchdog() {
    _stallTimer?.cancel();
    _stallTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && _sending) {
        _stallAborted = true;
        _cancelToken?.cancel();
      }
    });
  }

  /// 重试上一次发送：删除失败留下的用户消息，再重新发送
  Future<void> _retryLast() async {
    final text = _lastOutgoing;
    if (text == null || _sending) return;
    final sessionId = _sessionId;
    if (sessionId != null) {
      final msgs = await AiConversationService().watchMessages(sessionId).first;
      if (msgs.isNotEmpty && msgs.last.role == 'user') {
        await AiConversationService().deleteMessage(msgs.last.id);
      }
    }
    if (!mounted) return;
    setState(() => _lastFailed = false);
    await _send(text);
  }

  /// 初始变量：故事初始状态 + 声明的默认值
  Map<String, String> _initialVars() {
    final vars = Map<String, String>.from(story.initialState.variables);
    for (final v in story.variables) {
      final name = v.name.trim();
      if (name.isEmpty) continue;
      vars.putIfAbsent(name, () => v.value);
    }
    return vars;
  }

  /// 事件溯源：沿消息顺序折叠变量增量（尊重每条消息所选候选）
  Map<String, String> _foldVariables(List<AiTask> messages) {
    var vars = _initialVars();
    for (final m in messages) {
      if (m.role != 'model') continue;
      final parsed = _parseReply(m.outputContent ?? '');
      if (parsed.varOps.isNotEmpty) {
        vars = applyVarOps(vars, parsed.varOps);
      } else if (parsed.state != null) {
        // 旧消息：整表覆盖
        vars = {...vars, ...parsed.state!.variables};
      }
    }
    return normalizeVariables(vars, story.variables);
  }

  /// 重新折叠变量并持久化（swipe / 删除 / 启动时调用）
  Future<void> _applyFoldedVariables() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final messages = await AiConversationService()
        .watchMessages(sessionId)
        .first;
    if (!mounted) return;
    final next = _state.copyWith(variables: _foldVariables(messages));
    setState(() => _state = next);
    await StorySessionStore.instance.put(
      story.id,
      StorySession(sessionId: sessionId, state: next),
    );
  }

  /// 找出背包里未在 codex 登记的道具（按基础名归一，宽松包含匹配）
  List<String> _unregisteredFrom(GameState state) {
    final registered = <String>{
      for (final d in state.codex.where((d) => d.kind == 'item')) ...[d.key, d.name],
    };
    bool isRegistered(String item) {
      final base = item.split(' x').first.split('×').first.trim();
      if (base.isEmpty) return true;
      if (registered.contains(item) || registered.contains(base)) return true;
      for (final r in registered) {
        if (r.trim().isEmpty) continue;
        if (r.contains(base) || base.contains(r)) return true;
      }
      return false;
    }

    // 明显不是道具的（长句/带句读）忽略
    bool looksLikeItem(String item) =>
        item.length <= 40 &&
        !item.contains('。') &&
        !item.contains('；') &&
        !item.contains('！') &&
        !item.contains('？');

    return [
      for (final item in state.inventory)
        if (looksLikeItem(item) && !isRegistered(item)) item,
    ];
  }

  /// 角色条点击：查看角色卡 / 对TA说话
  Future<void> _characterMenu(CharacterCard c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: c.name,
        icon: Icons.person_outline,
        initialSize: 0.36,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(t.characterCards),
              onTap: () {
                Navigator.of(ctx).pop();
                showCharacterCardView(context, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: Text(t.storyNpcStatus),
              subtitle: Text(
                t.storyNpcAffinity(
                  value: '${_npcState(c.name)?.affinity ?? 0}',
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _showNpcStatus(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(t.storyTalkTo),
              onTap: () {
                Navigator.of(ctx).pop();
                _addressCharacter(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 按角色名取该角色的运行状态
  NpcState? _npcState(String name) {
    for (final n in _state.npcs) {
      if (n.name == name) return n;
    }
    return null;
  }

  /// 角色状态面板：好感度 / 姿态 / 数值条 / 属性 / 技能 / 携带
  Future<void> _showNpcStatus(CharacterCard c) async {
    final npc = _npcState(c.name);
    if (npc == null) {
      App.rootContext.showMessage(
        message: t.storyNpcNoStatus,
        level: LogLevel.info,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: c.name,
        icon: Icons.monitor_heart_outlined,
        initialSize: 0.72,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: _npcStatusWidgets(npc),
        ),
      ),
    );
  }

  List<Widget> _npcStatusWidgets(NpcState npc) {
    final scheme = Theme.of(context).colorScheme;
    Widget title(String s, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            s,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );

    final out = <Widget>[
      Row(
        children: [
          const Icon(Icons.favorite, size: 16, color: Colors.pinkAccent),
          const SizedBox(width: 6),
          Text(
            t.storyNpcAffinity(value: '${npc.affinity}'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ];
    if (npc.status.trim().isNotEmpty) {
      out.add(const SizedBox(height: 8));
      out.add(
        Text(
          npc.status.trim(),
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      );
    }
    if (npc.resources.isNotEmpty) {
      out.add(title(t.storyState, Icons.monitor_heart_outlined));
      for (final r in npc.resources) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.name}  ${r.cur}/${r.max}',
                  style: const TextStyle(fontSize: 12),
                ),
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
        );
      }
    }
    if (npc.attributes.isNotEmpty) {
      out.add(title(t.storyAttributes, Icons.tune));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in npc.attributes.entries)
              Chip(label: Text('${e.key} ${e.value}')),
          ],
        ),
      );
    }
    if (npc.skills.isNotEmpty) {
      out.add(title(t.skills, Icons.sports_martial_arts_outlined));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in npc.skills) Chip(label: Text(s))],
        ),
      );
    }
    if (npc.inventory.isNotEmpty) {
      out.add(title(t.storyInventory, Icons.inventory_2_outlined));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in npc.inventory) Chip(label: Text(s))],
        ),
      );
    }
    return out;
  }

  /// 按角色名取头像（找不到时用默认）
  String _avatarForName(String name) {
    for (final c in story.characters) {
      if (c.name == name) return c.avatar;
    }
    return '';
  }

  /// 消息时间：yyyy-MM-dd HH:mm:ss
  String _formatTime(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  /// 对某个角色说话：在输入框前缀「对XX：」并聚焦
  void _addressCharacter(CharacterCard c) {
    final prefix = t.storyCmdAddress(name: c.name);
    if (!_input.text.startsWith(prefix)) {
      _input.text = '$prefix${_input.text}';
    }
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _inputFocus.requestFocus();
  }

  /// 故事的生成参数（为空则跟随服务商默认值）
  AiGenerationParams? _storyParams() {
    if (story.temperature == null &&
        story.topP == null &&
        story.maxTokens == null) {
      return null;
    }
    return AiGenerationParams(
      temperature: story.temperature,
      topP: story.topP,
      maxTokens: story.maxTokens,
    );
  }

  /// 按初始状态顺序补齐模型漏报的数值条；模型有更新则用模型的值。
  /// [extra] 用于并入后续新增/当前已有的资源。
  GameState _mergeResources(GameState state, {List<StatBar> extra = const []}) {
    final aiRes = {for (final r in state.resources) r.name: r};
    final merged = <StatBar>[];
    final seen = <String>{};
    for (final r in story.initialState.resources) {
      merged.add(aiRes[r.name] ?? r);
      seen.add(r.name);
    }
    for (final r in state.resources) {
      if (seen.add(r.name)) merged.add(r);
    }
    for (final r in extra) {
      if (seen.add(r.name)) merged.add(r);
    }
    return state.copyWith(resources: merged);
  }

  /// 合并在场角色状态：模型给出的优先，之前已有但本次漏报的保留
  GameState _mergeNpcs(GameState state) {
    if (state.npcs.isEmpty && _state.npcs.isEmpty) return state;
    final merged = <NpcState>[];
    final seen = <String>{};
    for (final n in state.npcs) {
      if (seen.add(n.name)) merged.add(n);
    }
    for (final n in _state.npcs) {
      if (seen.add(n.name)) merged.add(n);
    }
    return state.copyWith(npcs: merged);
  }

  /// 合并称号：模型给出的优先，之前已有的保留
  GameState _mergeTitles(GameState state) {
    if (state.titles.isEmpty && _state.titles.isEmpty) return state;
    final merged = <TitleState>[...state.titles];
    final seen = {for (final x in merged) x.key};
    for (final x in _state.titles) {
      if (seen.add(x.key)) merged.add(x);
    }
    return state.copyWith(titles: merged);
  }

  /// 合并状态效果：模型给出的优先，之前已有的保留
  GameState _mergeEffects(GameState state) {
    if (state.effects.isEmpty && _state.effects.isEmpty) return state;
    final merged = <EffectState>[...state.effects];
    final seen = {for (final x in merged) x.name};
    for (final x in _state.effects) {
      if (seen.add(x.name)) merged.add(x);
    }
    return state.copyWith(effects: merged);
  }

  /// 应用解析出的状态并持久化（含未登记道具校验 / 成就解锁提示）
  Future<void> _applyState(GameState? state) async {
    final sessionId = _sessionId;
    if (state == null || sessionId == null) return;
    var next = state.copyWith(
      variables: normalizeVariables(state.variables, story.variables),
    );
    // 词条一旦登记就保留（模型偶尔会漏报），合并而非覆盖
    final mergedCodex = [...next.codex];
    final seenDefs = {
      for (final d in mergedCodex) '${d.kind}\u0000${d.key}': true,
    };
    for (final d in _state.codex) {
      if (seenDefs['${d.kind}\u0000${d.key}'] == true) continue;
      mergedCodex.add(d);
      seenDefs['${d.kind}\u0000${d.key}'] = true;
    }
    next = next.copyWith(codex: mergedCodex);
    // 资源合并：模型偶尔漏报部分数值条（如体力/进食），按初始状态顺序补齐
    next = _mergeResources(next, extra: _state.resources);
    // 角色状态合并：模型漏报时保留上一回合的值
    next = _mergeNpcs(next);
    // 称号 / 状态效果合并；职业 / 据点漏报时保留
    next = _mergeTitles(next);
    next = _mergeEffects(next);
    if (next.job.isEmpty && !_state.job.isEmpty) {
      next = next.copyWith(job: _state.job);
    }
    if (next.base.isEmpty && !_state.base.isEmpty) {
      next = next.copyWith(base: _state.base);
    }
    // 致命资源归零 → 游戏结束（any=任一归零；all=全部归零）
    if (!next.gameOver && story.deathResources.isNotEmpty) {
      bool isZero(String name) {
        for (final r in next.resources) {
          if (r.name == name) return r.cur <= 0;
        }
        return false;
      }

      final over = story.deathMode == 'all'
          ? story.deathResources.every(isZero)
          : story.deathResources.any(isZero);
      if (over) next = next.copyWith(gameOver: true);
    }
    final unregistered = _unregisteredFrom(next);
    final newlyUnlocked = next.achievements
        .where((k) => !_state.achievements.contains(k))
        .toList();
    setState(() {
      _state = next;
      _unregistered = unregistered;
    });
    if (newlyUnlocked.isNotEmpty) {
      final names = <String>[];
      for (final k in newlyUnlocked) {
        var name = k;
        for (final a in story.achievements) {
          if (a.key == k) {
            name = a.name;
            break;
          }
        }
        names.add(name);
      }
      App.rootContext.showMessage(
        message: '${t.storyAchievementUnlocked}: ${names.join('、')}',
      );
    }
    await StorySessionStore.instance.put(
      story.id,
      StorySession(sessionId: sessionId, state: next),
    );
    // 有新道具未登记则自动后台补全（无需手动）
    if (unregistered.isNotEmpty && !_registering) {
      unawaited(_registerUnregistered());
    }
  }

  /// 消息内联操作行（复制 / 重新生成 / 编辑 / 删除），无需长按
  Widget _messageFooter(AiTask m) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _msgAction(Icons.copy_outlined, t.copy, () => _copyMessage(m)),
            if (!isUser)
              _msgAction(
                Icons.replay_outlined,
                t.regenerateReply,
                () => _regenerate(m),
              ),
            if (isUser)
              _msgAction(Icons.edit_outlined, t.edit, () => _editMessage(m)),
          ],
        ),
      ),
    );
  }

  Widget _msgAction(IconData icon, String label, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: scheme.outline),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11, color: scheme.outline)),
          ],
        ),
      ),
    );
  }

  void _copyMessage(AiTask m) {
    Clipboard.setData(
      ClipboardData(
        text: m.role == 'user' ? m.inputContent : (m.outputContent ?? ''),
      ),
    );
    App.rootContext.showMessage(message: t.copied);
  }

  /// 消息长按菜单：复制 / 编辑 / 重生成 / 删除
  Future<void> _messageMenu(AiTask m) async {
    final isUser = m.role == 'user';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.more,
        icon: Icons.more_horiz,
        initialSize: 0.46,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(t.copy),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(
                  ClipboardData(
                    text: isUser ? m.inputContent : (m.outputContent ?? ''),
                  ),
                );
                App.rootContext.showMessage(message: t.copied);
              },
            ),
            if (isUser)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(t.edit),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editMessage(m);
                },
              ),
            if (!isUser)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(t.regenerate),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _regenerate(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 编辑消息：用户消息回滚重发；模型消息就地改输出
  Future<void> _editMessage(AiTask m) async {
    final isUser = m.role == 'user';
    await showInputDialog(
      context: App.rootContext,
      title: t.edit,
      initialValue: isUser ? m.inputContent : (m.outputContent ?? ''),
      minLines: 4,
      maxLines: 12,
      onConfirm: (value) async {
        final text = value.toString().trim();
        if (text.isEmpty) return t.required;
        if (isUser) {
          final sessionId = _sessionId;
          if (sessionId == null) return null;
          await AiConversationService().rollbackToMessage(sessionId, m.id);
          await _send(text);
        } else {
          await AiConversationService().editMessageInput(m.id, text);
          await _applyState(_parseReply(text).state);
        }
        return null;
      },
    );
  }

  /// 重新生成：保留旧结果作为候选，追加新候选
  Future<void> _regenerate(AiTask m) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await AiConversationService().regenerateMessage(
        sessionId: sessionId,
        taskId: m.id,
        providerOverride: aiHubProvider(),
        systemPromptOverride: await _systemPromptFor(
          _state,
          scanText: m.inputContent,
        ),
        paramsOverride: _storyParams(),
      );
      if (!mounted) return;
      if (!res.success) {
        App.rootContext.showMessage(
          message: res.errorMessage ?? '',
          level: LogLevel.error,
        );
        return;
      }
      await _applyState(_parseReply(res.data).state);
      await _applyFoldedVariables();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 候选切换（swipe）导航
  Widget _variantNav(AiTask m, List<String> variants) {
    final index = m.variantIndex.clamp(0, variants.length - 1);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: t.back,
            onPressed: index <= 0
                ? null
                : () => _selectVariant(m, variants, index - 1),
          ),
          Text(
            '${index + 1}/${variants.length}',
            style: const TextStyle(fontSize: 11),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: t.next,
            onPressed: index >= variants.length - 1
                ? null
                : () => _selectVariant(m, variants, index + 1),
          ),
        ],
      ),
    );
  }

  Future<void> _selectVariant(
    AiTask m,
    List<String> variants,
    int index,
  ) async {
    await AiConversationService().selectVariant(m.id, variants, index);
    await _applyState(_parseReply(variants[index]).state);
    await _applyFoldedVariables();
  }

  /// 后台为未登记的道具补全图鉴设定（不进入当前对话上下文）
  Future<void> _registerUnregistered() async {
    if (_unregistered.isEmpty || _registering) return;
    final items = List<String>.from(_unregistered);
    setState(() => _registering = true);
    try {
      final res = await AiConversationService().runTask(
        provider: aiHubProvider(),
        taskType: 'story_codex',
        sessionTitle: t.storyRegisterItems,
        systemPrompt: t.storyCodexSystem,
        prompt:
            '${t.storyCodexPrompt}\n'
            '{"codex":[{"kind":"item","key":"道具名","name":"道具名",'
            '"display":"玩家可见描述","mechanics":"机制/数值"}]}\n'
            '${t.storyCodexItems}：${items.join('、')}',
      );
      if (!mounted) return;
      if (!res.success) {
        App.rootContext.showMessage(
          message: res.errorMessage ?? '',
          level: LogLevel.error,
        );
        return;
      }
      final defs = _parseCodexDefs(res.data);
      if (defs.isEmpty) {
        // 模型没给出设定：仍然清掉本次提示，避免反复弹出
        setState(() {
          _unregistered = _unregistered
              .where((i) => !items.contains(i))
              .toList();
        });
        App.rootContext.showMessage(
          message: t.characterImportFailed,
          level: LogLevel.warning,
        );
        return;
      }
      final codex = [..._state.codex];
      for (final d in defs) {
        final idx = codex.indexWhere(
          (x) => x.kind == d.kind && x.key == d.key,
        );
        if (idx >= 0) {
          codex[idx] = d;
        } else {
          codex.add(d);
        }
      }
      final next = _state.copyWith(codex: codex);
      setState(() {
        _state = next;
        // 已成功合并的不再命中；失败的本次也不再提示
        _unregistered = _unregisteredFrom(next)
            .where((i) => !items.contains(i))
            .toList();
      });
      final sessionId = _sessionId;
      if (sessionId != null) {
        await StorySessionStore.instance.put(
          story.id,
          StorySession(sessionId: sessionId, state: next),
        );
      }
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  /// 从模型输出里解析 codex 定义
  List<StoryDefinition> _parseCodexDefs(String text) {
    final matches = RegExp(
      r'```json\s*([\s\S]*?)```',
      caseSensitive: false,
    ).allMatches(text).toList();
    final candidates = <String>[
      if (matches.isNotEmpty) matches.last.group(1)!.trim(),
      text.trim(),
    ];
    // 兜底：截取文本里的第一段 {...} / [...]
    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart >= 0 && objEnd > objStart) {
      candidates.add(text.substring(objStart, objEnd + 1));
    }
    final arrStart = text.indexOf('[');
    final arrEnd = text.lastIndexOf(']');
    if (arrStart >= 0 && arrEnd > arrStart) {
      candidates.add(text.substring(arrStart, arrEnd + 1));
    }
    for (final c in candidates) {
      try {
        final decoded = jsonDecode(c);
        if (decoded is Map && decoded['codex'] is List) {
          return [
            for (final e in decoded['codex'] as List)
              if (e is Map) StoryDefinition.fromJson(e.cast<String, dynamic>()),
          ];
        }
        if (decoded is List) {
          return [
            for (final e in decoded)
              if (e is Map) StoryDefinition.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {}
    }
    return const [];
  }

  void _sendInput() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _send(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return Scaffold(
        appBar: Appbar(title: Text(story.name)),
        body: const Center(child: PolygonRefreshIndicator()),
      );
    }
    if (_needsSetup) return _buildSetup(context);
    final sessionId = _sessionId;
    return Scaffold(
      appBar: Appbar(
        title: Text(story.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields_outlined),
            tooltip: t.storyTextStyle,
            onPressed: _showTextStyleSheet,
          ),
        ],
      ),
      body: sessionId == null
          ? const Center(child: PolygonRefreshIndicator())
          : StreamBuilder<List<AiTask>>(
              stream: AiConversationService().watchMessages(sessionId),
              builder: (context, snap) {
                final messages = snap.data ?? [];
                final choices = _lastAiReply(messages)?.choices ?? const <String>[];
                final showPendingUser =
                    _pendingUserText != null &&
                    (messages.isEmpty ||
                        messages.last.role != 'user' ||
                        messages.last.inputContent != _pendingUserText);
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }
                return Column(
                  children: [
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onUserScroll,
                        // 列表铺满整宽，内容用左右留白居中：
                        // 这样鼠标滚轮/拖动在两侧空白处也能滚动
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxW = _chatContentMaxWidth(context);
                            final side = constraints.maxWidth > maxW
                                ? (constraints.maxWidth - maxW) / 2
                                : 12.0;
                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: EdgeInsets.symmetric(
                                horizontal: side,
                                vertical: 12,
                              ),
                              itemCount:
                                  messages.length +
                                  (showPendingUser ? 1 : 0) +
                                  (_showStreamBubble ? 1 : 0),
                              itemBuilder: (context, raw) {
                              final i =
                                  messages.length +
                                  (showPendingUser ? 1 : 0) +
                                  (_showStreamBubble ? 1 : 0) -
                                  1 -
                                  raw;
                              if (showPendingUser && i == messages.length) {
                                final persona = story.persona;
                                return _StoryBubble(
                                  content: _pendingUserText!,
                                  isUser: true,
                                  headerName: persona.name.trim().isEmpty
                                      ? t.storyPersona
                                      : persona.name.trim(),
                                  headerTime: _formatTime(DateTime.now()),
                                  headerAvatar: persona.avatar,
                                );
                              }
                              if (i ==
                                  messages.length + (showPendingUser ? 1 : 0)) {
                                final streamNarrative = applyStoryRegex(
                                  _parseReply(_streamText).narrative,
                                  story.regexes,
                                  'display',
                                );
                                if (streamNarrative.trim().isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: PolygonRefreshIndicator(),
                                      ),
                                    ),
                                  );
                                }
                                final streamSegments = _splitSegments(
                                  streamNarrative,
                                );
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final seg in streamSegments)
                                      seg.type == 'npc'
                                          ? _NpcBubble(
                                              name: seg.name,
                                              content: applyStoryRegex(
                                                seg.text,
                                                story.regexes,
                                                'display',
                                                depth: 0,
                                              ),
                                              avatar: _avatarForName(seg.name),
                                            )
                                          : _StoryBubble(
                                              content: applyStoryRegex(
                                                seg.text,
                                                story.regexes,
                                                'display',
                                                depth: 0,
                                              ),
                                              isUser: false,
                                            ),
                                    // 事件/检定卡片要等 JSON 生成完才出现，这里提示仍在生成
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: PolygonRefreshIndicator(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              final m = messages[i];
                              final isUser = m.role == 'user';
                              final parsed = isUser
                                  ? null
                                  : _parseReply(m.outputContent ?? '');
                              final check = parsed?.check;
                              final variants = isUser
                                  ? const <String>[]
                                  : AiConversationService.variantsOf(m);
                              final showCheck =
                                  !isUser &&
                                  check != null &&
                                  i == messages.length - 1 &&
                                  !_sending;
                              final persona = story.persona;
                              final segments =
                                  parsed?.segments ?? const <StorySegment>[];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    onLongPress: () => _messageMenu(m),
                                    child: isUser
                                        ? _StoryBubble(
                                            content: m.inputContent,
                                            isUser: true,
                                            headerName:
                                                persona.name.trim().isEmpty
                                                ? t.storyPersona
                                                : persona.name.trim(),
                                            headerTime: _formatTime(
                                              m.createdAt,
                                            ),
                                            headerAvatar: persona.avatar,
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (final seg in segments)
                                                seg.type == 'npc'
                                                    ? _NpcBubble(
                                                        name: seg.name,
                                                        content:
                                                            applyStoryRegex(
                                                              seg.text,
                                                              story.regexes,
                                                              'display',
                                                              depth:
                                                                  messages
                                                                      .length -
                                                                  1 -
                                                                  i,
                                                            ),
                                                        avatar: _avatarForName(
                                                          seg.name,
                                                        ),
                                                      )
                                                    : _StoryBubble(
                                                        content:
                                                            applyStoryRegex(
                                                              seg.text,
                                                              story.regexes,
                                                              'display',
                                                              depth:
                                                                  messages
                                                                      .length -
                                                                  1 -
                                                                  i,
                                                            ),
                                                        isUser: false,
                                                      ),
                                              for (final e
                                                  in parsed?.events ??
                                                      const <StoryEvent>[])
                                                _StoryEventCard(event: e),
                                              AiUsageMeta(task: m),
                                            ],
                                          ),
                                  ),
                                  _messageFooter(m),
                                  if (variants.length > 1)
                                    _variantNav(m, variants),
                                  if (showCheck)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 6,
                                        bottom: 4,
                                      ),
                                      child: _StoryCheckCard(
                                        check: check,
                                        onRoll: () => _rollCheck(check),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                          },
                            ),
                          ),
                    ),
                    if (choices.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 132),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final c in choices)
                                _FollowUpChip(
                                  text: c,
                                  onTap: _sending ? () {} : () => _send(c),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (story.characters.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final presentChars = [
                            for (final c in story.characters)
                              if (_state.present.contains(c.name)) c,
                          ];
                          if (presentChars.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            child: SizedBox(
                              height: 34,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: presentChars.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) {
                                  final c = presentChars[i];
                                  return ActionChip(
                                    avatar: CharacterAvatar(
                                      name: c.name,
                                      avatar: c.avatar,
                                      radius: 10,
                                      enablePreview: false,
                                    ),
                                    label: Text(c.name),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                    onPressed: () => _characterMenu(c),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    if (_unregistered.isNotEmpty && !_sending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${t.storyUnregisteredItems}: '
                                '${_unregistered.join('、')}',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_registering)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            else
                              TextButton(
                                onPressed: _registerUnregistered,
                                child: Text(t.storyRegisterItems),
                              ),
                          ],
                        ),
                      ),
                    if (_lastFailed && !_sending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t.storyResponseFailed,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _retryLast,
                              child: Text(t.retry),
                            ),
                          ],
                        ),
                      ),
                    if (_state.gameOver)
                      _gameOverBar(context)
                    else
                      _AiComposerBar(
                      controller: _input,
                      focusNode: _inputFocus,
                      onSend: _sendInput,
                      sending: _sending,
                      onStop: () => _cancelToken?.cancel(),
                      hintText: t.storyInput,
                      bottomLeading: _ModelSelector(
                        provider: aiHubProvider(),
                        onProviderChanged: (p) {
                          setAiHubProvider(p);
                          setState(() {});
                        },
                      ),
                      bottomTrailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isFollowing)
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              tooltip: t.jumpToBottom,
                              onPressed: () {
                                setState(() => _isFollowing = true);
                                _scrollToBottom(force: true);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.auto_stories_outlined),
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            tooltip: t.storyDetails,
                            onPressed: _showDetailsSheet,
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz),
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            tooltip: t.storyMore,
                            onPressed: _showMore,
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

  /// 开局档案设置（类似 DnD 捏人）：单选 / 多选 / 自填，仅开局一次
  int _partNumber(StorySetupPart p) =>
      _numberValues[p.key] ?? p.value ?? p.min ?? 0;

  int? _groupPool(List<StorySetupPart> parts) {
    for (final p in parts) {
      if (p.pool != null) return p.pool;
    }
    return null;
  }

  int _groupAllocated(List<StorySetupPart> parts) {
    var sum = 0;
    for (final p in parts) {
      if (p.type == 'number') sum += _partNumber(p);
    }
    return sum;
  }

  void _bumpNumber(StorySetupPart p, int delta, List<StorySetupPart> group) {
    final min = p.min ?? 0;
    final max = p.max ?? (min + 99);
    if (delta > 0) {
      final pool = _groupPool(group);
      if (pool != null && pool - _groupAllocated(group) <= 0) return;
    }
    final next = (_partNumber(p) + delta).clamp(min, max);
    setState(() => _numberValues[p.key] = next);
  }

  void _rollGroup(List<StorySetupPart> group) {
    final nums = group.where((p) => p.type == 'number').toList();
    if (nums.isEmpty) return;
    final rng = math.Random();
    final pool = _groupPool(group);
    setState(() {
      if (pool == null) {
        for (final p in nums) {
          final min = p.min ?? 1;
          final max = p.max ?? min;
          _numberValues[p.key] =
              max > min ? min + rng.nextInt(max - min + 1) : min;
        }
        return;
      }
      final values = [for (final p in nums) p.min ?? 0];
      final maxs = [for (final p in nums) p.max ?? pool];
      var remaining = pool - values.fold(0, (a, b) => a + b);
      var guard = 0;
      while (remaining > 0 && guard < 100000) {
        guard++;
        final order = List<int>.generate(nums.length, (i) => i)..shuffle(rng);
        for (final i in order) {
          if (remaining <= 0) break;
          if (values[i] < maxs[i]) {
            values[i]++;
            remaining--;
          }
        }
      }
      for (var i = 0; i < nums.length; i++) {
        _numberValues[nums[i].key] = values[i];
      }
    });
  }

  /// 开局档案设置（类似 DnD 捏人）：单选 / 多选 / 自填 / 数值(可掷骰)，仅开局一次
  Widget _buildSetup(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String, List<StorySetupPart>>{};
    for (final p in story.setup) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    return Scaffold(
      appBar: Appbar(title: Text(story.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (story.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                story.description,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          for (final entry in groups.entries) ...[
            if (entry.key.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_groupPool(entry.value) != null)
                    Text(
                      '${t.storyPointsLeft}: '
                      '${_groupPool(entry.value)! - _groupAllocated(entry.value)}',
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            for (final part in entry.value)
              _buildPart(context, part, entry.value),
            if (entry.value.any((p) => p.type == 'number'))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _rollGroup(entry.value),
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  label: Text(t.storyRoll),
                ),
              ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startWithSetup,
              icon: const Icon(Icons.play_arrow),
              label: Text(t.storyStart),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPart(
    BuildContext context,
    StorySetupPart part,
    List<StorySetupPart> group,
  ) {
    // points 仅用于定义分组点数池，不渲染控件
    if (part.type == 'points') return const SizedBox.shrink();
    final title = part.required ? '${part.title} *' : part.title;
    if (part.type == 'number') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _bumpNumber(part, -1, group),
            ),
            Text(
              '${_partNumber(part)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _bumpNumber(part, 1, group),
            ),
          ],
        ),
      );
    }

    final Widget content;
    if (part.type == 'multi') {
      content = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in part.options)
            OptionChip(
              text: o,
              isSelected: _multiValues[part.key]?.contains(o) ?? false,
              onTap: () => setState(() {
                final set = _multiValues.putIfAbsent(part.key, () => {});
                if (set.contains(o)) {
                  set.remove(o);
                } else {
                  set.add(o);
                }
              }),
            ),
        ],
      );
    } else if (part.type == 'text') {
      content = TextField(
        controller: _textValues.putIfAbsent(
          part.key,
          () => TextEditingController(),
        ),
        decoration: InputDecoration(
          hintText: part.hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      );
    } else {
      content = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in part.options)
            OptionChip(
              text: o,
              isSelected: _singleValues[part.key] == o,
              onTap: () => setState(() => _singleValues[part.key] = o),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        content,
        const SizedBox(height: 14),
      ],
    );
  }

  _ParsedReply? _lastAiReply(List<AiTask> messages) {
    for (final m in messages.reversed) {
      if (m.role == 'model' && (m.outputContent?.isNotEmpty ?? false)) {
        return _parseReply(m.outputContent!);
      }
    }
    return null;
  }

  _ParsedReply _parseReply(String content) {
    final matches = RegExp(
      r'```json\s*([\s\S]*?)```',
      caseSensitive: false,
    ).allMatches(content).toList();
    var narrative = content;
    GameState? state;
    var choices = <String>[];
    var events = <StoryEvent>[];
    var varOps = <VarOp>[];
    StoryCheck? check;
    if (matches.isNotEmpty) {
      final m = matches.last;
      narrative = content.replaceRange(m.start, m.end, '').trim();
      try {
        final decoded = jsonDecode(m.group(1)!.trim());
        if (decoded is Map) {
          if (decoded['state'] is Map) {
            state = GameState.fromJson(
              (decoded['state'] as Map).cast<String, dynamic>(),
            );
          }
          final c = decoded['choices'];
          if (c is List) choices = c.map((e) => e.toString()).toList();
          final ev = decoded['events'];
          if (ev is List) {
            events = [for (final e in ev) StoryEvent.fromJson(e)];
          }
          if (decoded['check'] is Map) {
            check = StoryCheck.fromJson(
              (decoded['check'] as Map).cast<String, dynamic>(),
            );
          }
          final vo = decoded['varOps'];
          if (vo is List) varOps = [for (final e in vo) VarOp.fromJson(e)];
        }
      } catch (_) {}
    } else if ('```'.allMatches(content).length.isOdd) {
      // 流式过程中可能出现未闭合的代码块，先隐藏
      narrative = content
          .substring(0, content.lastIndexOf('```'))
          .trim();
    }
    return _ParsedReply(
      narrative: narrative,
      state: state,
      choices: choices,
      events: events,
      varOps: varOps,
      check: check,
      segments: _splitSegments(narrative),
    );
  }

  /// 把正文拆成旁白 / 角色片段（〖角色：名字〗...〖/角色〗）。
  /// 容错：结束标记可缺失（也接受 〖/名字〗 / 【角色：名字】）。
  /// 有结束标记 → 整段算该角色；无结束标记 → 按段落判断，
  /// 只把含引号对白的段落算角色发言，纯旁白（含【提示】）拆出来。
  List<StorySegment> _splitSegments(String text) {
    final openRe = RegExp(r'[〖【]\s*角色\s*[:：]\s*([^〗】]+?)\s*[〗】]');
    final segments = <StorySegment>[];
    var index = 0;
    while (index < text.length) {
      final open = openRe.firstMatch(text.substring(index));
      if (open == null) break;
      final openStart = index + open.start;
      final bodyStart = index + open.end;
      final before = text.substring(index, openStart).trim();
      if (before.isNotEmpty) {
        segments.add(StorySegment(type: 'narration', text: before));
      }
      final rest = text.substring(bodyStart);
      final name = open.group(1)!.trim();
      final closeRe = RegExp(
        '[〖【]\\s*/\\s*(?:角色|${RegExp.escape(name)})\\s*[〗】]',
      );
      final nextOpen = openRe.firstMatch(rest);
      final nextClose = closeRe.firstMatch(rest);
      var endRel = rest.length;
      var closed = false;
      if (nextOpen != null) endRel = nextOpen.start;
      if (nextClose != null && nextClose.start < endRel) {
        endRel = nextClose.start;
        closed = true;
      }
      final body = rest.substring(0, endRel).trim();
      if (body.isNotEmpty) {
        _splitNpcBody(segments, name, body, closed: closed);
      }
      index = bodyStart + endRel;
      if (closed && nextClose != null) {
        index += nextClose.end - nextClose.start;
      }
    }
    if (index < text.length) {
      final after = text.substring(index).trim();
      if (after.isNotEmpty) {
        segments.add(StorySegment(type: 'narration', text: after));
      }
    }
    if (segments.isEmpty && text.trim().isNotEmpty) {
      segments.add(StorySegment(type: 'narration', text: text.trim()));
    }
    return segments;
  }

  /// 角色块拆段。
  /// - 有结束标记：气泡里**只保留引号内的对白**，引号外的动作/描写算旁白；
  /// - 无结束标记：从第一个"不以引号开头"的段落起，之后一律算旁白
  ///   （避免把随后的旁白、拟声词如 "啪嗒啪嗒" 误当成角色发言）；
  /// - 整段没有引号时（对白未加引号）整段仍算角色。
  void _splitNpcBody(
    List<StorySegment> segments,
    String name,
    String body, {
    required bool closed,
  }) {
    if (!_speechRe.hasMatch(body)) {
      segments.add(StorySegment(type: 'npc', name: name, text: body.trim()));
      return;
    }
    if (closed) {
      for (final p in body.split(RegExp(r'\n\s*\n'))) {
        final t = p.trim();
        if (t.isEmpty) continue;
        if (_looksLikeCallout(t)) {
          segments.add(StorySegment(type: 'narration', text: t));
        } else {
          _splitByQuotes(segments, name, t);
        }
      }
      return;
    }
    // 无结束标记：从第一个"不以引号开头"的段落起，之后一律算旁白；
    // 之前的对白段落仍按引号切分，把中间的旁白动作也拆出来
    var ended = false;
    for (final p in body.split(RegExp(r'\n\s*\n'))) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (!ended && !_looksLikeCallout(t) && _startsWithQuote(t)) {
        _splitByQuotes(segments, name, t);
      } else {
        ended = true;
        segments.add(StorySegment(type: 'narration', text: t));
      }
    }
  }

  static final _quoteStartRe = RegExp(r'^[“"「『]');

  static bool _startsWithQuote(String s) =>
      _quoteStartRe.hasMatch(s.trimLeft());

  /// 把一段文字按引号切分：引号内 → 角色，引号外 → 旁白
  void _splitByQuotes(List<StorySegment> segments, String name, String text) {
    final matches = _speechRe.allMatches(text).toList();
    if (matches.isEmpty) {
      segments.add(StorySegment(type: 'narration', text: text.trim()));
      return;
    }
    var index = 0;
    final npcBuf = <String>[];
    void flush() {
      if (npcBuf.isEmpty) return;
      segments.add(StorySegment(type: 'npc', name: name, text: npcBuf.join(' ')));
      npcBuf.clear();
    }

    for (final m in matches) {
      final before = text.substring(index, m.start).trim();
      if (before.isNotEmpty) {
        flush();
        segments.add(StorySegment(type: 'narration', text: before));
      }
      npcBuf.add(m.group(0)!);
      index = m.end;
    }
    final after = text.substring(index).trim();
    if (after.isNotEmpty) {
      flush();
      segments.add(StorySegment(type: 'narration', text: after));
    }
    flush();
  }

  static final _speechRe = RegExp(r'[“"「『][^”"」』]*[”"」』]');

  /// 提示框（`>` 引用块 / 【标签】开头）无论是否含引号都算旁白
  static bool _looksLikeCallout(String s) {
    final t = s.trimLeft();
    if (t.startsWith('>')) return true;
    if (t.startsWith('【')) {
      final close = t.indexOf('】');
      if (close > 1 && close <= 12) return true;
    }
    return false;
  }

  /// 文字样式设置：引号高亮 / 阴影 / 字体 / 字号
  Future<void> _showTextStyleSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.storyTextStyle,
        icon: Icons.text_fields_outlined,
        initialSize: 0.78,
        builder: (ctx, sc) => ListenableBuilder(
          listenable: StoryTextStyleStore.instance,
          builder: (ctx, _) {
            final store = StoryTextStyleStore.instance;
            final s = store.style;
            final scheme = Theme.of(ctx).colorScheme;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            Color preview(StoryRoleStyle r, Color fallback) {
              final v = isDark ? r.dark : r.light;
              return v == null ? fallback : Color(v);
            }

            StoryRoleStyle withColor(StoryRoleStyle r, Color c) => isDark
                ? r.copyWith(dark: c.toARGB32())
                : r.copyWith(light: c.toARGB32());

            Widget roleTile(
              String label,
              StoryRoleStyle role,
              StoryRoleStyle defaultRole,
              Color fallback,
              ValueChanged<StoryRoleStyle> onChanged, {
              bool allowFontStyle = true,
            }) {
              final color = preview(role, fallback);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          final c = await showDialog<Color>(
                            context: App.rootContext,
                            builder: (_) => ColorPickPage(initialColor: color),
                          );
                          if (c != null) onChanged(withColor(role, c));
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restart_alt, size: 18),
                        tooltip: t.reset,
                        onPressed: () => onChanged(defaultRole),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        t.storyOpacity,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: role.opacity,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: '${(role.opacity * 100).round()}%',
                          onChanged: (v) =>
                              onChanged(role.copyWith(opacity: v)),
                        ),
                      ),
                    ],
                  ),
                  if (allowFontStyle)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (value, name) in [
                          ('normal', t.storyNormal),
                          ('italic', t.storyItalic),
                          ('bold', t.storyBold),
                        ])
                          OptionChip(
                            text: name,
                            isSelected: role.fontStyle == value,
                            onTap: () =>
                                onChanged(role.copyWith(fontStyle: value)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              );
            }

            return ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Text(
                      t.storyQuoteGlyph,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Select(
                      current: s.quoteGlyph.label,
                      values: [
                        for (final g in StoryQuoteGlyph.values) g.label,
                      ],
                      onTap: (idx) => store.update(
                        s.copyWith(
                          quoteGlyph: StoryQuoteGlyph.values[idx],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                roleTile(
                  t.storyQuote,
                  s.quote,
                  StoryTextStyle.defaults.quote,
                  scheme.primary,
                  (r) => store.update(s.copyWith(quote: r)),
                ),
                roleTile(
                  t.storyBracket,
                  s.bracket,
                  StoryTextStyle.defaults.bracket,
                  scheme.onSurfaceVariant,
                  (r) => store.update(s.copyWith(bracket: r)),
                ),
                roleTile(
                  t.storyItalic,
                  s.italic,
                  StoryTextStyle.defaults.italic,
                  scheme.onSurfaceVariant,
                  (r) => store.update(s.copyWith(italic: r)),
                  allowFontStyle: false,
                ),
                roleTile(
                  t.storyBold,
                  s.bold,
                  StoryTextStyle.defaults.bold,
                  scheme.onSurface,
                  (r) => store.update(s.copyWith(bold: r)),
                  allowFontStyle: false,
                ),
                const Divider(),
                _toggleRow(
                  t.storyShadow,
                  Icons.blur_on_outlined,
                  s.shadow,
                  (v) => store.update(s.copyWith(shadow: v)),
                ),
                _toggleRow(
                  t.storySystemFont,
                  Icons.font_download_outlined,
                  s.systemFont,
                  (v) => store.update(s.copyWith(systemFont: v)),
                ),
                Row(
                  children: [
                    Text(t.storyFontSize),
                    Expanded(
                      child: Slider(
                        value: s.fontScale,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: '${(s.fontScale * 100).round()}%',
                        onChanged: (v) => store.update(s.copyWith(fontScale: v)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 游戏结束条：提示 + 重新开始
  Widget _gameOverBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.dangerous_outlined, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.storyGameOver,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: _restartGame,
            child: Text(t.storyRestart),
          ),
        ],
      ),
    );
  }

  Future<void> _restartGame() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      await AiConversationService().deleteSession(sessionId);
    }
    await StorySessionStore.instance.clear(story.id);
    if (!mounted) return;
    setState(() {
      _sessionId = null;
      _state = GameState.empty;
      _unregistered = const [];
      _lastMessageCount = 0;
      _booting = true;
      _needsSetup = false;
    });
    await _boot();
  }

  /// 项目风格开关行
  Widget _toggleRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 详情面板：状态 / 局势两个页签（用项目胶囊布局）
  Future<void> _showDetailsSheet() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final messages = await AiConversationService()
        .watchMessages(sessionId)
        .first;
    final state = _lastAiReply(messages)?.state ?? _state;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StoryDetailsSheet(
        story: story,
        state: state,
        onCommand: _send,
      ),
    );
  }

  /// 「更多」：内置掷骰 + 故事自定义操作按钮（一键 / 批量等）
  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.storyMore,
        icon: Icons.more_horiz,
        initialSize: 0.5,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.casino_outlined),
              title: Text(t.storyRoll),
              onTap: () {
                Navigator.of(ctx).pop();
                _manualRoll();
              },
            ),
            if (_state.combat.active)
              ListTile(
                leading: const Icon(Icons.skip_next_outlined),
                title: Text(t.storyNextRound),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _send(t.storyCmdNextRound);
                },
              ),
            for (final a in story.actions)
              ListTile(
                leading: Icon(_storyActionIcon(a.icon)),
                title: Text(a.label),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _send(a.prompt);
                },
              ),
            if (story.actions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  t.storyNoActions,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 展示掷骰结果弹窗
  Future<void> _showRollResult(DiceRoll roll, String title) async {
    await ContentDialog.show<void>(
      context: App.rootContext,
      title: title,
      content: Text(
        roll.detail,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(App.rootContext).pop(),
          child: Text(t.confirm),
        ),
      ],
    );
  }

  /// 执行 AI 声明的检定：项目掷骰，再把结果回传给 GM
  Future<void> _rollCheck(StoryCheck check) async {
    if (_sending) return;
    final roll = rollDice(check.dice, modifier: check.modifier, dc: check.dc);
    await _showRollResult(roll, check.label.isEmpty ? t.storyRoll : check.label);
    if (!mounted) return;
    await _send(
      t.storyCmdCheckResult(label: check.label, detail: roll.detail),
    );
  }

  /// 手动掷骰：从当前属性里选一项 + 输入 DC
  Future<void> _manualRoll() async {
    final entries = _state.attributes.entries.toList();
    if (entries.isEmpty) {
      App.rootContext.showMessage(
        message: t.storyNoAttributes,
        level: LogLevel.warning,
      );
      return;
    }
    var index = 0;
    final dcCtrl = TextEditingController(text: '12');
    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.storyRoll,
        content: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.storyRollAttribute, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < entries.length; i++)
                    OptionChip(
                      text: '${entries[i].key} ${entries[i].value}',
                      isSelected: index == i,
                      onTap: () => setLocal(() => index = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dcCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'DC',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.storyRoll),
          ),
        ],
      ),
    );
    final dc = int.tryParse(dcCtrl.text.trim());
    dcCtrl.dispose();
    if (ok != true || !mounted) return;
    final entry = entries[index];
    final roll = rollDice('1d20', modifier: entry.value, dc: dc);
    await _showRollResult(roll, '${entry.key} ${entry.value}');
    if (!mounted) return;
    await _send(
      t.storyCmdCheckResult(label: entry.key, detail: roll.detail),
    );
  }
}

/// 详情面板：状态 / 局势（胶囊切换），条目可点击查看设定
class _StoryDetailsSheet extends StatefulWidget {
  const _StoryDetailsSheet({
    required this.story,
    required this.state,
    required this.onCommand,
  });

  final Story story;
  final GameState state;
  final ValueChanged<String> onCommand;

  @override
  State<_StoryDetailsSheet> createState() => _StoryDetailsSheetState();
}

class _StoryDetailsSheetState extends State<_StoryDetailsSheet> {
  final _pageCtrl = PageController();
  int _tab = 0;

  /// 词条按类型筛选（'' = 全部）
  String _codexKind = '';

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

  /// 在 codex 里按名称/键查找设定（容忍「物品 x2」这类后缀）
  StoryDefinition? _findDef(String name) {
    final key = _baseName(name);
    for (final d in state.codex) {
      if (d.key == name || d.name == name || d.key == key || d.name == key) {
        return d;
      }
    }
    // 宽松匹配：数量后缀 / 名称写法不完全一致（如「工程铅笔（半支）x1」）
    for (final d in state.codex) {
      if (_nameMatch(d.key, key) || _nameMatch(d.name, key)) return d;
    }
    return null;
  }

  IconData _iconFor(String name, String fallbackKind) =>
      _codexIcon(_findDef(name)?.kind ?? fallbackKind);

  /// 查看条目说明：图鉴里显示图鉴描述，否则提示暂无
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
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(App.rootContext).pop(),
          child: Text(t.confirm),
        ),
      ],
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
        onPressed: () => _inspect(label, kind),
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
    return ListTile(
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
      onTap: () => _inspect(d.name, d.kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Sheet(
      title: t.storyDetails,
      icon: Icons.auto_stories_outlined,
      initialSize: 0.7,
      builder: (ctx, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CapsuleOptions(
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
    for (final p in panels) {
      final section = _buildPanel(p, scheme);
      if (section.isEmpty) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
      widgets.addAll(section);
    }
    return widgets;
  }

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
              for (final e in state.attributes.entries)
                Chip(label: Text('${e.key} ${e.value}')),
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
              for (final s in state.skills) _entry(label: s, kind: 'skill'),
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
                      q.totalStages > 1
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
                      value: q.status == 'done'
                          ? 1.0
                          : (q.progress / 100).clamp(0.0, 1.0),
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
              scrollable: true,
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
      blocks.add(
        Text(
          widget.story.situation.trim(),
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

IconData _storyActionIcon(String name) => switch (name) {
  'use' => Icons.play_arrow_outlined,
  'drop' => Icons.delete_outline,
  'rest' => Icons.bedtime_outlined,
  'move' => Icons.directions_walk,
  'inspect' => Icons.search,
  'trade' => Icons.swap_horiz,
  'talk' => Icons.chat_bubble_outline,
  'fight' => Icons.sports_martial_arts_outlined,
  'map' => Icons.map_outlined,
  _ => Icons.bolt_outlined,
};

IconData _codexIcon(String kind) => switch (kind) {
  'item' => Icons.inventory_2_outlined,
  'race' => Icons.groups_outlined,
  'trait' => Icons.psychology_alt_outlined,
  'talent' => Icons.auto_awesome_outlined,
  'skill' => Icons.sports_martial_arts_outlined,
  'body' => Icons.monitor_heart_outlined,
  _ => Icons.menu_book_outlined,
};

Widget _sectionTitle(String text, [IconData? icon]) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16),
        const SizedBox(width: 6),
      ],
      Flexible(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  ),
);

IconData? _panelIcon(String name) {
  if (name.isEmpty) return null;
  return switch (name) {
    'resources' => Icons.favorite_border,
    'attributes' => Icons.insights_outlined,
    'skills' => Icons.sports_martial_arts_outlined,
    'inventory' => Icons.inventory_2_outlined,
    'quests' => Icons.flag_outlined,
    'codex' => Icons.menu_book_outlined,
    'variables' => Icons.tune,
    'equipment' => Icons.shield_outlined,
    'combat' => Icons.local_fire_department_outlined,
    'achievements' => Icons.emoji_events_outlined,
    _ => _storyActionIcon(name),
  };
}

class _ParsedReply {
  final String narrative;
  final GameState? state;
  final List<String> choices;
  final List<StoryEvent> events;
  final List<VarOp> varOps;
  final StoryCheck? check;
  final List<StorySegment> segments;

  const _ParsedReply({
    required this.narrative,
    this.state,
    this.choices = const [],
    this.events = const [],
    this.varOps = const [],
    this.check,
    this.segments = const [],
  });
}


