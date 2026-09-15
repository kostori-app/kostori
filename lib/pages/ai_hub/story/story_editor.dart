part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

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
  final TextEditingController group;
  String source;

  _StoryPanelDraft({
    String titleText = '',
    this.source = 'attributes',
    String kindText = '',
    String iconText = '',
    String groupText = '',
  }) : title = TextEditingController(text: titleText),
       kind = TextEditingController(text: kindText),
       icon = TextEditingController(text: iconText),
       group = TextEditingController(text: groupText);

  void dispose() {
    title.dispose();
    kind.dispose();
    icon.dispose();
    group.dispose();
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
  bool passive;

  _StoryTitleDraft({
    String keyText = '',
    String nameText = '',
    String effectsText = '',
    this.stackable = false,
    this.passive = false,
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

class _StoryEditorState extends State<_StoryEditor>
    with SingleTickerProviderStateMixin {
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
  late final _contextBudgetCtrl = TextEditingController(
    text: widget.story?.contextBudgetChars?.toString() ?? '',
  );
  late final TabController _tabCtrl;
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
  // 玩家角色卡来自独立存储（与角色卡同文件），故事文件里不存
  late final StoryPersona _personaInit = widget.story == null
      ? const StoryPersona()
      : (StoryCharacterStore.instance.persona(widget.story!.id) ??
            widget.story!.persona);
  late String _personaAvatar = _personaInit.avatar;
  late final _personaNameCtrl = TextEditingController(text: _personaInit.name);
  late final _personaDescCtrl = TextEditingController(
    text: _personaInit.description,
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
        groupText: p.group,
      ),
  ];
  // 角色卡来自独立存储（不再写进故事文件）
  late final List<CharacterCard> _characters = [
    ...StoryCharacterStore.instance.get(widget.story?.id ?? ''),
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
  /// 高级分区：当前选中的子 tab
  int _advIdx = 0;
  late final List<_StoryTitleDraft> _titles = [
    for (final x in widget.story?.titles ?? const <StoryTitle>[])
      _StoryTitleDraft(
        keyText: x.key,
        nameText: x.name,
        effectsText: x.effects,
        stackable: x.stackable,
        passive: x.passive,
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
    StoryCharacterStore.instance.ensureLoaded();
    SettingLibraryStore.instance.ensureLoaded();
  }

  bool _tabCtrlReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 不能在 initState 里构建页签（部分页签会调用 Theme.of），放到这里
    if (!_tabCtrlReady) {
      _tabCtrl = TabController(length: _editorTabs().length, vsync: this);
      _tabCtrlReady = true;
    }
  }

  static const _codexKinds = kStoryCodexKinds;

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
    _tabCtrl.dispose();
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
    _contextBudgetCtrl.dispose();
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
    // 名称在「基本信息」页；TabBarView 不构建屏幕外的页，需自己查并切回去
    if (_nameCtrl.text.trim().isEmpty) {
      _tabCtrl.animateTo(0);
      App.rootContext.showMessage(
        message: '${t.required}: ${t.name}',
        level: LogLevel.warning,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final initialState = _parseState();
    if (initialState == null) {
      App.rootContext.showMessage(
        message: t.storyInvalidState,
        level: LogLevel.error,
      );
      return;
    }
    final id =
        widget.story?.id ?? 'story_${DateTime.now().millisecondsSinceEpoch}';
    final story = Story(
      id: id,
      key: widget.story?.key ?? '',
      version: widget.story?.version ?? '',
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
      contextBudgetChars: int.tryParse(_contextBudgetCtrl.text.trim()),
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
            group: p.group.text.trim(),
          ),
      ],
      // 角色卡不写进故事文件（见下方 StoryCharacterStore.put）
      characters: const [],
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
              passive: x.passive,
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
      persona: const StoryPersona(),
      initialState: initialState,
      isBuiltin: widget.story?.isBuiltin ?? false,
    );
    await StoryStore.instance.upsert(story);
    await StoryCharacterStore.instance.put(id, [
      for (final c in _characters)
        if (c.name.trim().isNotEmpty) c,
    ]);
    await StoryCharacterStore.instance.putPersona(
      id,
      StoryPersona(
        name: _personaNameCtrl.text.trim(),
        avatar: _personaAvatar,
        description: _personaDescCtrl.text.trim(),
      ),
    );
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
                progress: _tabCtrl.animation,
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    CapsuleOption(
                      text: tabs[i].$1,
                      isSelected: _tabCtrl.index == i,
                      onTap: () => _tabCtrl.animateTo(i),
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
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
        const SizedBox(height: 8),
        _field(t.contextBudget, _contextBudgetCtrl, required: false),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Text(
            t.contextBudgetHint,
            style: const TextStyle(fontSize: 12),
          ),
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
    final sources = [for (final s in storyPanelSources) s.id];
    String sourceLabel(String s) => storyPanelSources
        .firstWhere((e) => e.id == s, orElse: () => storyPanelSources.first)
        .label();
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
                TextFormField(
                  controller: _panels[i].group,
                  decoration: InputDecoration(
                    labelText: t.storyPanelGroup,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
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
                        groupText: p.group,
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
    final advTabs = [
      t.storyCodexDefs,
      t.storyTitles,
      t.storyJob,
      t.storyBase,
      t.storyCharacters,
      t.storyVariables,
      t.storyRegex,
      t.storyAchievements,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CapsuleOptions(
            alignment: WrapAlignment.start,
            scrollable: true,
            children: [
              for (var i = 0; i < advTabs.length; i++)
                CapsuleOption(
                  text: advTabs[i],
                  isSelected: _advIdx == i,
                  onTap: () => setState(() => _advIdx = i),
                ),
            ],
          ),
        ),
        if (_advIdx == 0) ...[
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
                labelText: t.storyCodexName,
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

        ],
        if (_advIdx == 1) ...[
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
                      labelText: t.storyTitleName,
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
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.storyTitlePassive,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                CustomSwitch(
                  value: _titles[i].passive,
                  onChanged: (v) => setState(() => _titles[i].passive = v),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _titles.add(_StoryTitleDraft())),
            icon: const Icon(Icons.add),
            label: Text(t.storyAddEntry),
          ),
        ),

        ],
        if (_advIdx == 2) ...[
        // ── 职业 ──
        sectionTitle(t.storyJob),
        TextFormField(
          controller: _jobNameCtrl,
          decoration: InputDecoration(
            labelText: t.storyJobName,
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
                      labelText: t.storyJobLevelName,
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

        ],
        if (_advIdx == 3) ...[
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
                      labelText: t.storyFacilityName,
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

        ],
        if (_advIdx == 4) ...[
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
        ],
        if (_advIdx == 5) ...[
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
        ],
        if (_advIdx == 6) ...[
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
        ],
        if (_advIdx == 7) ...[
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
                      labelText: t.storyAchievementName,
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
