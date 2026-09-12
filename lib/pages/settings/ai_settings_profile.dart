part of 'settings_page.dart';

/// 打开助手档案编辑器（供 AI 工坊等外部页面复用）
Future<void> openAssistantProfileEditor({AssistantProfile? profile}) async {
  await showPopUpWidget(
    App.rootContext,
    _AssistantProfileEditor(profile: profile),
  );
}

class _AssistantProfileEditor extends StatefulWidget {
  const _AssistantProfileEditor({this.profile});

  final AssistantProfile? profile;

  @override
  State<_AssistantProfileEditor> createState() =>
      _AssistantProfileEditorState();
}

class _AssistantProfileEditorState extends State<_AssistantProfileEditor> {
  static const _prefKeys = [
    'concise',
    'useMarkdown',
    'codeFirst',
    'actionable',
  ];

  static List<String> get _tagSuggestions => [
    t.aiTagRational,
    t.aiTagHumorous,
    t.aiTagSarcastic,
    t.aiTagGentle,
    t.aiTagRigorous,
    t.aiTagPassionate,
    t.aiTagCalm,
    t.aiTagCool,
    t.aiTagEnergetic,
    t.aiTagChuuni,
    t.aiTagCunning,
    t.aiTagFriendly,
  ];

  static List<(String, String, String)> get _knownExtensions => [
    ('markdown', t.aiExtMarkdown, t.aiExtMarkdownHint),
    (
      'image_understanding',
      t.aiExtImageUnderstanding,
      t.aiExtImageUnderstandingHint,
    ),
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _personaCtrl;
  late final TextEditingController _toneCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _catchphrasesCtrl;
  late final TextEditingController _examplesCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _knowledgeCtrl;
  late final TextEditingController _fragmentsCtrl;
  late final TextEditingController _temperatureCtrl;
  late final TextEditingController _topPCtrl;
  late final TextEditingController _maxTokensCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _headersCtrl;
  late final TextEditingController _extraBodyCtrl;
  late final TextEditingController _stopCtrl;
  late final TextEditingController _memoryEntryCtrl;
  late final TextEditingController _memoryMaxCtrl;

  late Set<String> _enabledSkillIds;
  late List<String> _skillIds;
  late List<AssistantExtension> _extensions;
  late MemorySettings _memory;
  late List<McpBinding> _mcpServers;
  late Map<String, bool> _behaviorPrefs;
  late ReplyLength _replyLength;
  late bool _useEmoji;
  late bool _useMarkdown;
  late bool _askBack;

  bool get _isNew => widget.profile == null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _iconCtrl = TextEditingController(text: p?.icon ?? '🤖');
    _personaCtrl = TextEditingController(text: p?.persona ?? '');
    _toneCtrl = TextEditingController(text: p?.tone ?? '');
    _tagsCtrl = TextEditingController(
      text: (p?.personalityTags ?? const []).join('\n'),
    );
    _catchphrasesCtrl = TextEditingController(
      text: (p?.catchphrases ?? const []).join('\n'),
    );
    _examplesCtrl = TextEditingController(
      text: [
        for (final e in (p?.examples ?? const [])) '${e.user} | ${e.assistant}',
      ].join('\n'),
    );
    _promptCtrl = TextEditingController(text: p?.systemPrompt ?? '');
    _knowledgeCtrl = TextEditingController(
      text: (p?.knowledge ?? const []).join('\n'),
    );
    _fragmentsCtrl = TextEditingController(
      text: (p?.promptFragments ?? const []).join('\n'),
    );
    _temperatureCtrl = TextEditingController(
      text: p?.params.temperature?.toString() ?? '',
    );
    _topPCtrl = TextEditingController(text: p?.params.topP?.toString() ?? '');
    _maxTokensCtrl = TextEditingController(
      text: p?.params.maxTokens?.toString() ?? '',
    );
    _baseUrlCtrl = TextEditingController(
      text: p?.request.baseUrlOverride ?? '',
    );
    _apiKeyCtrl = TextEditingController(text: p?.request.apiKeyOverride ?? '');
    _headersCtrl = TextEditingController(
      text: [
        for (final e in (p?.request.customHeaders ?? const {}).entries)
          '${e.key}: ${e.value}',
      ].join('\n'),
    );
    _extraBodyCtrl = TextEditingController(
      text: (p?.request.extraBodyFields ?? const {}).isNotEmpty
          ? const JsonEncoder.withIndent(
              '  ',
            ).convert(p!.request.extraBodyFields)
          : '',
    );
    _stopCtrl = TextEditingController(
      text: (p?.request.stopSequences ?? const []).join('\n'),
    );
    _memoryEntryCtrl = TextEditingController();
    _memoryMaxCtrl = TextEditingController(
      text: (p?.memory.maxEntries ?? 50).toString(),
    );
    _enabledSkillIds = {...?p?.enabledSkillIds};
    _skillIds = [...?p?.skillIds];
    _extensions = [...?p?.extensions];
    _memory = p?.memory ?? const MemorySettings();
    _mcpServers = [...?p?.mcpServers];
    _behaviorPrefs = {
      for (final k in _prefKeys) k: p?.behaviorPrefs[k] == true,
    };
    _replyLength = p?.replyStyle.length ?? ReplyLength.normal;
    _useEmoji = p?.replyStyle.useEmoji ?? false;
    _useMarkdown = p?.replyStyle.useMarkdown ?? true;
    _askBack = p?.replyStyle.askBack ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _personaCtrl.dispose();
    _toneCtrl.dispose();
    _tagsCtrl.dispose();
    _catchphrasesCtrl.dispose();
    _examplesCtrl.dispose();
    _promptCtrl.dispose();
    _knowledgeCtrl.dispose();
    _fragmentsCtrl.dispose();
    _temperatureCtrl.dispose();
    _topPCtrl.dispose();
    _maxTokensCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _headersCtrl.dispose();
    _extraBodyCtrl.dispose();
    _stopCtrl.dispose();
    _memoryEntryCtrl.dispose();
    _memoryMaxCtrl.dispose();
    super.dispose();
  }

  List<String> _lines(TextEditingController ctrl) => ctrl.text
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  AssistantProfile _buildProfile() {
    final id =
        widget.profile?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';
    final allIds = SkillRegistry.instance.all.map((s) => s.id).toSet();
    final skills =
        _enabledSkillIds.isEmpty || setEquals(_enabledSkillIds, allIds)
        ? const <String>{}
        : {..._enabledSkillIds};
    final examples = <ProfileExample>[];
    for (final line in _lines(_examplesCtrl)) {
      final parts = line.split('|');
      if (parts.length >= 2) {
        examples.add(
          ProfileExample(
            user: parts[0].replaceFirst(RegExp(r'^用户\s*[:：]?\s*'), '').trim(),
            assistant: parts[1]
                .replaceFirst(RegExp(r'^助手\s*[:：]?\s*'), '')
                .trim(),
          ),
        );
      }
    }
    return AssistantProfile(
      id: id,
      name: _nameCtrl.text.trim(),
      icon: _iconCtrl.text.trim().isEmpty ? '🤖' : _iconCtrl.text.trim(),
      persona: _personaCtrl.text.trim(),
      tone: _toneCtrl.text.trim(),
      personalityTags: _lines(_tagsCtrl),
      catchphrases: _lines(_catchphrasesCtrl),
      examples: examples,
      replyStyle: ReplyStylePrefs(
        length: _replyLength,
        useEmoji: _useEmoji,
        useMarkdown: _useMarkdown,
        askBack: _askBack,
      ),
      systemPrompt: _promptCtrl.text.trim(),
      knowledge: _lines(_knowledgeCtrl),
      enabledSkillIds: skills,
      skillIds: _skillIds,
      extensions: _extensions,
      memory: MemorySettings(
        enabled: _memory.enabled,
        maxEntries: int.tryParse(_memoryMaxCtrl.text.trim()) ?? 50,
      ),
      request: RequestSettings(
        baseUrlOverride: _baseUrlCtrl.text.trim().isEmpty
            ? null
            : _baseUrlCtrl.text.trim(),
        apiKeyOverride: _apiKeyCtrl.text.trim().isEmpty
            ? null
            : _apiKeyCtrl.text.trim(),
        customHeaders: _parseHeaderLines(_headersCtrl),
        extraBodyFields: _parseJsonObject(_extraBodyCtrl.text),
        stopSequences: _lines(_stopCtrl),
      ),
      mcpServers: _mcpServers,
      params: AssistantParams(
        temperature: double.tryParse(_temperatureCtrl.text.trim()),
        topP: double.tryParse(_topPCtrl.text.trim()),
        maxTokens: int.tryParse(_maxTokensCtrl.text.trim()),
      ),
      behaviorPrefs: {
        for (final e in _behaviorPrefs.entries)
          if (e.value) e.key: true,
      },
      promptFragments: _lines(_fragmentsCtrl),
      isBuiltin: widget.profile?.isBuiltin ?? false,
    );
  }

  /// 解析多行 "Key: Value" 头
  Map<String, String> _parseHeaderLines(TextEditingController ctrl) {
    final result = <String, String>{};
    for (final line in _lines(ctrl)) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      final key = line.substring(0, idx).trim();
      final value = line.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }

  /// 解析 JSON 对象；非法或空返回空 Map
  Map<String, dynamic> _parseJsonObject(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const {};
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic>
          ? decoded
          : const <String, dynamic>{};
    } catch (_) {
      return const {};
    }
  }

  String? _validateRange(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final d = double.tryParse(v.trim());
    if (d == null || d < 0 || d > 1) return t.valueRange;
    return null;
  }

  String? _validatePositiveInt(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return t.invalidNumber;
    return null;
  }

  void _toggleSkill(String id, bool selected) {
    setState(() {
      final allIds = SkillRegistry.instance.all.map((s) => s.id).toSet();
      if (selected) {
        _enabledSkillIds.add(id);
      } else if (_enabledSkillIds.isEmpty) {
        _enabledSkillIds = {...allIds}..remove(id);
      } else {
        _enabledSkillIds.remove(id);
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile = _buildProfile();
    await AssistantProfileStore.instance.upsert(profile);
    if (mounted) {
      App.rootContext.showMessage(message: t.profileSaved);
      App.rootContext.pop();
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.deleteProfile,
        content: Text(t.confirmDeleteProfile),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AssistantProfileStore.instance.remove(widget.profile!.id);
      if (mounted) App.rootContext.pop();
    }
  }

  Future<void> _previewPrompt() async {
    final profile = _buildProfile();
    final enabled = SkillRegistry.instance.all
        .where(
          (s) => _enabledSkillIds.isEmpty || _enabledSkillIds.contains(s.id),
        )
        .toList();
    final injections = await PromptInjectionStore.instance.enabledSorted();
    final prompt = buildSystemPrompt(
      profile: profile,
      availableSkills: [for (final s in enabled) s.name],
      injections: injections,
    );
    if (!mounted) return;
    await ContentDialog.show(
      context: context,
      title: t.previewSystemPrompt,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: SelectableText(
            prompt,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ),
    );
  }

  Future<void> _tryChatting() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile = _buildProfile();
    await AssistantProfileStore.instance.upsert(profile);
    if (!mounted) return;
    App.rootContext.showMessage(message: t.profileSaved);
    App.rootContext.to(
      () => AiChatPage(fresh: true, initialProfileId: profile.id),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    // ignore: unused_element_parameter
    IconData? icon,
    bool multiline = false,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        maxLines: multiline ? 6 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          alignLabelWithHint: multiline,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  /// 占位符说明区（与 replaceTemplateVars 共用同一注册表）
  Widget _templateVarHint(
    TextEditingController ctrl, {
    bool insertOnTap = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    void insert(String token) {
      if (!insertOnTap) return;
      final selection = ctrl.selection;
      final start = selection.isValid ? selection.start : ctrl.text.length;
      final end = selection.isValid ? selection.end : ctrl.text.length;
      ctrl.text = ctrl.text
          .replaceRange(start, end, token)
          .replaceAll('$token$token', token);
      ctrl.selection = TextSelection.collapsed(offset: start + token.length);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            t.templateVarHint,
            style: TextStyle(fontSize: 11, color: scheme.outline),
          ),
          for (final v in templateVarEntries)
            InkWell(
              onTap: () => insert(v.token),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${v.token} ${v.label}',
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      child: child,
    );
  }

  Widget _buildTopFields() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _SettingCard(
        children: [
          _field(
            t.profileName,
            _nameCtrl,
            icon: Icons.badge_outlined,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? t.required : null,
          ),
          _field(
            t.profileIcon,
            _iconCtrl,
            icon: Icons.emoji_emotions_outlined,
            hintText: t.profileIconHint,
          ),
        ],
      ),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      final current = _lines(_tagsCtrl);
      final next = <String>[...current];
      if (next.contains(tag)) {
        next.remove(tag);
      } else {
        next.add(tag);
      }
      _tagsCtrl.text = next.join('\n');
    });
  }

  Widget _personaSectionTitle(String title, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  static List<(String, String)> get _personaSuggestions => [
    (t.aiPersonaGeneral, t.aiPersonaGeneralDesc),
    (t.aiPersonaEngineer, t.aiPersonaEngineerDesc),
    (t.aiPersonaButler, t.aiPersonaButlerDesc),
    (t.aiPersonaWriter, t.aiPersonaWriterDesc),
    (t.aiPersonaAdvisor, t.aiPersonaAdvisorDesc),
    (t.aiPersonaFriend, t.aiPersonaFriendDesc),
  ];

  static List<String> get _toneSuggestions => [
    t.aiToneFormal,
    t.aiTagHumorous,
    t.aiTagGentle,
    t.aiToneConcise,
    t.aiToneNatural,
    t.aiTagSarcastic,
  ];

  /// 点击选择式字段（readOnly，点击弹出 BottomSheet 选择）
  Widget _pickerField(
    String label,
    TextEditingController ctrl, {
    required VoidCallback onTap,
    bool multiline = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        maxLines: multiline ? 3 : 1,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _pickPersona() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.profilePersona,
        icon: Icons.face_outlined,
        initialSize: 0.55,
        builder: (sheetCtx, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            for (final p in _personaSuggestions)
              ListTile(
                leading: Icon(
                  _personaCtrl.text.trim() == p.$2
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _personaCtrl.text.trim() == p.$2
                      ? Theme.of(sheetCtx).colorScheme.primary
                      : null,
                ),
                title: Text(p.$1),
                subtitle: Text(p.$2, style: const TextStyle(fontSize: 12)),
                onTap: () => Navigator.pop(ctx, p.$2),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.custom),
              onTap: () => Navigator.pop(ctx, '__custom__'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__custom__') {
      if (!mounted) return;
      final ctrl = TextEditingController(text: _personaCtrl.text);
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => ContentDialog(
          title: t.profilePersona,
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(border: const OutlineInputBorder()),
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
      if (text != null && text.isNotEmpty) {
        setState(() => _personaCtrl.text = text);
      }
    } else {
      setState(() => _personaCtrl.text = selected);
    }
  }

  Future<void> _pickTone() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.profileTone,
        icon: Icons.format_quote_outlined,
        initialSize: 0.4,
        builder: (sheetCtx, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            for (final tone in _toneSuggestions)
              ListTile(
                leading: Icon(
                  _toneCtrl.text.trim() == tone
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _toneCtrl.text.trim() == tone
                      ? Theme.of(sheetCtx).colorScheme.primary
                      : null,
                ),
                title: Text(tone),
                onTap: () => Navigator.pop(ctx, tone),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.custom),
              onTap: () => Navigator.pop(ctx, '__custom__'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__custom__') {
      if (!mounted) return;
      final ctrl = TextEditingController(text: _toneCtrl.text);
      final text = await showDialog<String>(
        context: context,
        builder: (ctx) => ContentDialog(
          title: t.profileTone,
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(border: const OutlineInputBorder()),
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
      if (text != null && text.isNotEmpty) {
        setState(() => _toneCtrl.text = text);
      }
    } else {
      setState(() => _toneCtrl.text = selected);
    }
  }

  Widget _buildPersonaTab() {
    final currentTags = _lines(_tagsCtrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pickerField(
          t.profilePersona,
          _personaCtrl,
          multiline: true,
          onTap: _pickPersona,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? t.profilePersonaRequired : null,
        ),
        _pickerField(
          t.profileTone,
          _toneCtrl,
          multiline: true,
          onTap: _pickTone,
        ),
        _personaSectionTitle(
          t.profilePersonalityTags,
          Icons.interests_outlined,
        ),
        _field(
          t.profilePersonalityTagsHint,
          _tagsCtrl,
          icon: Icons.local_offer_outlined,
          multiline: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tagSuggestions)
                FilterChip(
                  label: Text(tag),
                  selected: currentTags.contains(tag),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _toggleTag(tag),
                ),
            ],
          ),
        ),
        _personaSectionTitle(t.profileCatchphrases, Icons.format_quote),
        _field(
          t.profileCatchphrasesHint,
          _catchphrasesCtrl,
          icon: Icons.chat_bubble_outline,
          multiline: true,
        ),
        _personaSectionTitle(t.profileReplyStyle, Icons.tune),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<ReplyLength>(
            segments: [
              ButtonSegment(
                value: ReplyLength.short,
                label: Text(t.lengthShort),
                icon: Icon(Icons.short_text, size: 18),
              ),
              ButtonSegment(
                value: ReplyLength.normal,
                label: Text(t.lengthMedium),
                icon: Icon(Icons.format_align_left, size: 18),
              ),
              ButtonSegment(
                value: ReplyLength.detailed,
                label: Text(t.detailed),
                icon: Icon(Icons.notes, size: 18),
              ),
            ],
            selected: {_replyLength},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _replyLength = s.first),
          ),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.emoji_emotions_outlined, size: 20),
          title: Text(t.replyUseEmoji),
          value: _useEmoji,
          onChanged: (v) => setState(() => _useEmoji = v ?? false),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.format_align_left, size: 20),
          title: Text(t.replyUseMarkdown),
          value: _useMarkdown,
          onChanged: (v) => setState(() => _useMarkdown = v ?? false),
        ),
        CheckboxListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          controlAffinity: ListTileControlAffinity.leading,
          secondary: const Icon(Icons.help_outline, size: 20),
          title: Text(t.replyAskBack),
          value: _askBack,
          onChanged: (v) => setState(() => _askBack = v ?? false),
        ),
        _personaSectionTitle(t.profileExamples, Icons.forum_outlined),
        _field(
          t.profileExamplesHint,
          _examplesCtrl,
          icon: Icons.record_voice_over_outlined,
          multiline: true,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPromptTab() {
    return Column(
      children: [
        _field(
          t.systemPrompt,
          _promptCtrl,
          icon: Icons.auto_awesome_outlined,
          multiline: true,
        ),
        _templateVarHint(_promptCtrl),
        _field(
          t.profilePromptFragments,
          _fragmentsCtrl,
          icon: Icons.format_list_numbered_outlined,
          multiline: true,
        ),
        _field(
          t.profileKnowledge,
          _knowledgeCtrl,
          icon: Icons.menu_book_outlined,
          multiline: true,
        ),
      ],
    );
  }

  Widget _buildLocalToolsTab() {
    final scheme = Theme.of(context).colorScheme;
    final localTools = SkillRegistry.instance.all;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileLocalTools,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.profileLocalToolsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (localTools.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.noSkillsAvailable, style: ts.s12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in localTools)
                  FilterChip(
                    avatar: const Icon(Icons.extension, size: 16),
                    label: Text(s.name),
                    selected:
                        _enabledSkillIds.isEmpty ||
                        _enabledSkillIds.contains(s.id),
                    visualDensity: VisualDensity.compact,
                    onSelected: (sel) => _toggleSkill(s.id, sel),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileSkills,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.profileSkillsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AiSkill>>(
            stream: AiDatabase.instance.aiSkillDao.watchAll(),
            builder: (context, snapshot) {
              final skills = snapshot.data ?? [];
              if (skills.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.noSkillsYet, style: ts.s12),
                );
              }
              return Column(
                children: skills.map((s) {
                  final selected = _skillIds.contains(s.key);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: const Icon(Icons.build_outlined, size: 20),
                    title: Text(s.name),
                    subtitle: Text(
                      s.description ?? s.key,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!_skillIds.contains(s.key)) _skillIds.add(s.key);
                      } else {
                        _skillIds.remove(s.key);
                      }
                    }),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    final scheme = Theme.of(context).colorScheme;
    final prefs = [
      ('concise', t.conciseReplies, Icons.bolt_outlined),
      ('useMarkdown', t.useMarkdownFormatting, Icons.format_align_left),
      ('codeFirst', t.codeFirst, Icons.code),
      ('actionable', t.actionableAdvice, Icons.checklist),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileParams,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.customParamsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          _field(
            t.temperature,
            _temperatureCtrl,
            icon: Icons.thermostat_outlined,
            hintText: t.valueRange,
            validator: _validateRange,
          ),
          _field(
            'Top P',
            _topPCtrl,
            icon: Icons.speed_outlined,
            hintText: t.valueRange,
            validator: _validateRange,
          ),
          _field(
            t.tokens,
            _maxTokensCtrl,
            icon: Icons.numbers_outlined,
            hintText: t.customParamsHint,
            validator: _validatePositiveInt,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.checklist_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileBehaviorPrefs,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          for (final (key, label, icon) in prefs)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Icon(icon, size: 20),
              title: Text(label),
              value: _behaviorPrefs[key] ?? false,
              onChanged: (v) =>
                  setState(() => _behaviorPrefs[key] = v ?? false),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.http_outlined, size: 20),
              const SizedBox(width: 8),
              Text(
                t.profileRequest,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.profileRequestSensitiveHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          _field(
            t.profileRequestBaseUrl,
            _baseUrlCtrl,
            icon: Icons.link_outlined,
            hintText: 'https://api.example.com/v1',
          ),
          _field(t.profileRequestApiKey, _apiKeyCtrl, icon: Icons.key_outlined),
          _field(
            t.profileRequestHeaders,
            _headersCtrl,
            icon: Icons.code_outlined,
            hintText: 'Authorization: Bearer xxx',
            multiline: true,
          ),
          _field(
            t.profileRequestExtraBody,
            _extraBodyCtrl,
            icon: Icons.data_object_outlined,
            hintText: '{"temperature": 0.7}',
            multiline: true,
          ),
          _field(
            t.profileRequestStop,
            _stopCtrl,
            icon: Icons.stop_circle_outlined,
            hintText: t.profileRequestStopHint,
            multiline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionsTab() {
    final scheme = Theme.of(context).colorScheme;
    bool isEnabled(String id) =>
        _extensions.any((e) => e.extensionId == id && e.enabled);
    void toggle(String id, bool v) {
      setState(() {
        final idx = _extensions.indexWhere((e) => e.extensionId == id);
        if (idx >= 0) {
          _extensions[idx] = _extensions[idx].copyWith(enabled: v);
        } else {
          _extensions.add(AssistantExtension(extensionId: id, enabled: v));
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.profileExtensionsHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final (id, label, desc) in _knownExtensions)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: const Icon(Icons.extension_outlined, size: 20),
              title: Text(label),
              subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
              value: isEnabled(id),
              onChanged: (v) => toggle(id, v ?? false),
            ),
        ],
      ),
    );
  }

  Widget _buildMemoryTab() {
    final scheme = Theme.of(context).colorScheme;
    final profileId =
        widget.profile?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToggleRow(
            t.profileMemoryEnabled,
            Icons.memory_outlined,
            _memory.enabled,
            (v) => setState(() => _memory = _memory.copyWith(enabled: v)),
          ),
          const SizedBox(height: 4),
          Text(
            t.profileMemoryHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          _field(
            t.profileMemoryMaxEntries,
            _memoryMaxCtrl,
            icon: Icons.numbers_outlined,
            validator: _validatePositiveInt,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.history_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.profileMemoryEntries,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await AssistantMemoryStore.instance.clear(profileId);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(t.profileMemoryClear),
              ),
            ],
          ),
          FutureBuilder<List<String>>(
            future: AssistantMemoryStore.instance.entriesFor(profileId),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <String>[];
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.profileMemoryEmpty, style: ts.s12),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        '${i + 1}.',
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                      title: Text(
                        entries[i],
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () async {
                          await AssistantMemoryStore.instance.removeAt(
                            profileId,
                            i,
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  t.profileMemoryAdd,
                  _memoryEntryCtrl,
                  icon: Icons.add_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  final text = _memoryEntryCtrl.text.trim();
                  if (text.isEmpty) return;
                  await AssistantMemoryStore.instance.add(profileId, text);
                  _memoryEntryCtrl.clear();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(t.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMcpTab() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.profileMcpHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<AiMcpServer>>(
            stream: AiDatabase.instance.aiMcpServerDao.watchAll(),
            builder: (context, snapshot) {
              final servers = snapshot.data ?? [];
              if (servers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.noMcpServers, style: ts.s12),
                );
              }
              bool bound(String id) =>
                  _mcpServers.any((m) => m.id == id && m.enabled);
              return Column(
                children: servers.map((s) {
                  final endpoint = s.transport == 'stdio'
                      ? (s.command ?? '')
                      : (s.url ?? '');
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: const Icon(Icons.dns_outlined, size: 20),
                    title: Text(s.name),
                    subtitle: Text(
                      endpoint,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: bound(s.id.toString()),
                    onChanged: (v) => setState(() {
                      final id = s.id.toString();
                      final idx = _mcpServers.indexWhere((m) => m.id == id);
                      if (v == true) {
                        if (idx >= 0) {
                          _mcpServers[idx] = _mcpServers[idx].copyWith(
                            enabled: true,
                          );
                        } else {
                          _mcpServers.add(
                            McpBinding(
                              id: id,
                              name: s.name,
                              serverUrl: endpoint,
                              enabled: true,
                            ),
                          );
                        }
                      } else if (idx >= 0) {
                        _mcpServers[idx] = _mcpServers[idx].copyWith(
                          enabled: false,
                        );
                      }
                    }),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: _isNew
          ? t.newProfile
          : '${t.editAssistantProfile} · ${widget.profile!.name}',
      tailing: [
        IconButton(
          icon: const Icon(Icons.visibility_outlined),
          tooltip: t.previewSystemPrompt,
          onPressed: _previewPrompt,
        ),
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: t.tryChatting,
          onPressed: _tryChatting,
        ),
        if (!_isNew && widget.profile!.isPreset == false)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: scheme.error,
            tooltip: t.deleteProfile,
            onPressed: _delete,
          ),
      ],
      body: DefaultTabController(
        length: 7,
        child: Stack(
          children: [
            Positioned.fill(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTopFields(),
                    TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: t.profileTabBasic),
                        Tab(text: t.profileTabPrompt),
                        Tab(text: t.profileTabExtensions),
                        Tab(text: t.profileTabMemory),
                        Tab(text: t.profileTabRequest),
                        Tab(text: t.profileTabMcp),
                        Tab(text: t.profileTabLocalTools),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _tabScroll(_buildPersonaTab()),
                          _tabScroll(_buildPromptTab()),
                          _tabScroll(_buildExtensionsTab()),
                          _tabScroll(_buildMemoryTab()),
                          _tabScroll(_buildRequestTab()),
                          _tabScroll(_buildMcpTab()),
                          _tabScroll(_buildLocalToolsTab()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: _save,
                label: Text(t.apply),
                icon: const Icon(Icons.check),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 通用开关行
// ─────────────────────────────────────────────

Widget _buildToggleRow(
  String title,
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
        Expanded(child: Text(title)),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    ),
  );
}
