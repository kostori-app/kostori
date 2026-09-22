part of '../settings_page.dart';

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
  late final TextEditingController _memoryBudgetCtrl;

  late Set<String> _enabledSkillIds;
  late List<String> _skillIds;
  late Set<String> _worldBookIds;
  late Set<String> _injectionIds;
  late bool _inheritGlobalLibrary;
  late Set<String> _characterIds;
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
    _iconCtrl = TextEditingController(
      text: (p?.icon ?? '').startsWith('data:image') ? p!.icon : '',
    );
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
          ? const JsonEncoder.withIndent('  ')
                .convert(p!.request.extraBodyFields)
          : '',
    );
    _stopCtrl = TextEditingController(
      text: (p?.request.stopSequences ?? const []).join('\n'),
    );
    _memoryEntryCtrl = TextEditingController();
    _memoryMaxCtrl = TextEditingController(
      text: (p?.memory.maxEntries ?? 50).toString(),
    );
    _memoryBudgetCtrl = TextEditingController(
      text: p?.memory.contextBudgetChars?.toString() ?? '',
    );
    _enabledSkillIds = {...?p?.enabledSkillIds};
    _skillIds = [...?p?.skillIds];
    _worldBookIds = {...?p?.worldBookIds};
    _injectionIds = {...?p?.injectionIds};
    _inheritGlobalLibrary = p?.inheritGlobalLibrary ?? false;
    _characterIds = {...?p?.characterIds};
    _extensions = [...?p?.extensions];
    WorldBookStore.instance.ensureLoaded();
    PromptInjectionStore.instance.ensureLoaded();
    CharacterCardStore.instance.ensureLoaded();
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
    _memoryBudgetCtrl.dispose();
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
      icon: _iconCtrl.text.trim(),
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
      worldBookIds: _worldBookIds.toList(),
      injectionIds: _injectionIds.toList(),
      inheritGlobalLibrary: _inheritGlobalLibrary,
      characterIds: _characterIds.toList(),
      extensions: _extensions,
      memory: MemorySettings(
        enabled: _memory.enabled,
        maxEntries: int.tryParse(_memoryMaxCtrl.text.trim()) ?? 50,
        contextBudgetChars: int.tryParse(_memoryBudgetCtrl.text.trim()),
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

  /// 本地工具是否启用（空集合表示全部启用）
  bool _localToolEnabled(String id) =>
      _enabledSkillIds.isEmpty || _enabledSkillIds.contains(id);

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
          child: AppSelectableText(
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
        // 内容有多高就多高：空的时候不占一大片
        minLines: multiline ? 1 : null,
        maxLines: multiline ? null : 1,
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
          // 头像：仅支持上传图片（base64 存储），不再用 emoji
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                AssistantAvatar(icon: _iconCtrl.text, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Text(t.profileIcon, style: ts.s12)),
                if (_iconCtrl.text.startsWith('data:image'))
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(t.remove),
                    onPressed: () => setState(() => _iconCtrl.text = ''),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(t.profileIconUpload),
                    onPressed: _pickIconImage,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 上传头像图片 → 转 base64 data URI 存进 icon
  Future<void> _pickIconImage() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 256,
        maxHeight: 256,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final ext = f.name.split('.').last.toLowerCase();
      final mime = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      if (!mounted) return;
      setState(
        () => _iconCtrl.text = 'data:$mime;base64,${base64Encode(bytes)}',
      );
    } catch (e) {
      App.rootContext.showMessage(message: '$e', level: LogLevel.warning);
    }
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
        minLines: multiline ? 1 : null,
        maxLines: multiline ? null : 1,
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
        SelectCard(
          title: t.replyUseEmoji,
          selected: _useEmoji,
          leading: const Icon(Icons.emoji_emotions_outlined, size: 20),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          onChanged: (v) => setState(() => _useEmoji = v),
        ),
        SelectCard(
          title: t.replyUseMarkdown,
          selected: _useMarkdown,
          leading: const Icon(Icons.format_align_left, size: 20),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          onChanged: (v) => setState(() => _useMarkdown = v),
        ),
        SelectCard(
          title: t.replyAskBack,
          selected: _askBack,
          leading: const Icon(Icons.help_outline, size: 20),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          onChanged: (v) => setState(() => _askBack = v),
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
            CapsuleChipGroup(
              children: [
                for (final s in localTools)
                  CapsuleChip(
                    text: s.name,
                    isSelected: _localToolEnabled(s.id),
                    onTap: () => _toggleSkill(s.id, !_localToolEnabled(s.id)),
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
          ListenableBuilder(
            listenable: AiSkillStore.instance,
            builder: (context, _) {
              final skills = AiSkillStore.instance.items;
              if (skills.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t.noSkillsYet, style: ts.s12),
                );
              }
              return Column(
                children: skills.map((s) {
                  return SelectCard(
                    title: s.name,
                    subtitle: s.description.isEmpty ? s.key : s.description,
                    leading: const Icon(Icons.build_outlined, size: 20),
                    selected: _skillIds.contains(s.key),
                    onChanged: (v) => setState(() {
                      if (v) {
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

  Widget _buildLibraryTab() {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([
        WorldBookStore.instance,
        PromptInjectionStore.instance,
        CharacterCardStore.instance,
      ]),
      builder: (context, _) {
        final worldBook = WorldBookStore.instance.entries;
        final injections = PromptInjectionStore.instance.items;
        final cards = CharacterCardStore.instance.cards;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.profileLibraryHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.inheritGlobalLibrary),
              subtitle: Text(
                t.inheritGlobalLibraryHint,
                style: const TextStyle(fontSize: 12),
              ),
              value: _inheritGlobalLibrary,
              onChanged: (v) => setState(() => _inheritGlobalLibrary = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.worldBook,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (worldBook.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(t.noWorldBookEntriesYet, style: ts.s12),
              )
            else
              for (final book in WorldBookStore.instance.books)
                if (book.entries.isNotEmpty)
                  _bookSelectCard(
                    name: book.name.isEmpty ? t.worldBook : book.name,
                    count: book.entries.length,
                    selected: book.entries.every(
                      (e) => _worldBookIds.contains(e.id),
                    ),
                    onChanged: (v) => setState(() {
                      if (v) {
                        _worldBookIds.addAll([
                          for (final e in book.entries) e.id,
                        ]);
                      } else {
                        _worldBookIds.removeAll([
                          for (final e in book.entries) e.id,
                        ]);
                      }
                    }),
                  ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.push_pin_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.promptInjection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (injections.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(t.noPromptInjectionsYet, style: ts.s12),
              )
            else
              for (final i in injections)
                SelectCard(
                  title: i.name,
                  selected: _injectionIds.contains(i.id),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _injectionIds.add(i.id);
                    } else {
                      _injectionIds.remove(i.id);
                    }
                  }),
                ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.characterCards,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (cards.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(t.characterCardsEmpty, style: ts.s12),
              )
            else
              for (final c in cards)
                _bookSelectCard(
                  name: c.displayName,
                  leading: CharacterAvatar(
                    name: c.displayName,
                    avatar: c.avatar,
                    radius: 14,
                  ),
                  selected: _characterIds.contains(c.id),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _characterIds.add(c.id);
                    } else {
                      _characterIds.remove(c.id);
                    }
                  }),
                ),
          ],
        );
      },
    );
  }

  /// 勾选卡片：点击切换，选中时高亮（与故事编辑一致，无左侧勾选框）
  Widget _bookSelectCard({
    required String name,
    required bool selected,
    required ValueChanged<bool> onChanged,
    int? count,
    Widget? leading,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SelectCard(
      title: name,
      selected: selected,
      onChanged: onChanged,
      leading: leading,
      trailing: count == null
          ? null
          : Text(
              '$count',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
            SelectCard(
              title: label,
              selected: _behaviorPrefs[key] ?? false,
              leading: Icon(icon, size: 20),
              onChanged: (v) => setState(() => _behaviorPrefs[key] = v),
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
          _field(
            t.profileMemoryContextBudget,
            _memoryBudgetCtrl,
            icon: Icons.data_usage_outlined,
          ),
          const SizedBox(height: 4),
          Text(
            t.profileMemoryContextBudgetHint,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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
                  return SelectCard(
                    title: s.name,
                    subtitle: endpoint,
                    leading: const Icon(Icons.dns_outlined, size: 20),
                    selected: bound(s.id.toString()),
                    onChanged: (v) => setState(() {
                      final id = s.id.toString();
                      final idx = _mcpServers.indexWhere((m) => m.id == id);
                      if (v) {
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
                    CapsuleTabBar(
                      labels: [
                        t.profileTabBasic,
                        t.profileTabPrompt,
                        t.profileTabMemory,
                        t.profileTabRequest,
                        t.profileTabMcp,
                        t.profileTabLocalTools,
                        t.profileTabLibrary,
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _tabScroll(_buildPersonaTab()),
                          _tabScroll(_buildPromptTab()),
                          _tabScroll(_buildMemoryTab()),
                          _tabScroll(_buildRequestTab()),
                          _tabScroll(_buildMcpTab()),
                          _tabScroll(_buildLocalToolsTab()),
                          _tabScroll(_buildLibraryTab()),
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
