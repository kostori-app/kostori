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

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    try {
      final text = utf8.decode(await result.files.first.readAsBytes());
      final story = StoryStore.storyFromMarkdown(text);
      await StoryStore.instance.upsert(story);
      if (mounted) {
        App.rootContext.showMessage(message: t.storyImported);
        setState(() {});
      }
    } catch (e) {
      Log.error('importStory', e.toString());
      App.rootContext.showMessage(message: t.importFailed, level: LogLevel.error);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: ListenableBuilder(
        listenable: StoryStore.instance,
        builder: (context, _) {
          final stories = StoryStore.instance.stories;
          if (stories.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.storyNoStories, textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final s in stories)
                _StoryCard(
                  story: s,
                  onTap: () =>
                      context.to(() => StoryGamePage(story: s)),
                  onEdit: () => _edit(s),
                  onExport: () => _export(s),
                  onDelete: s.isBuiltin ? null : () => _delete(s),
                ),
            ],
          );
        },
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
    this.onDelete,
  });

  final Story story;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;
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
              Text(story.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
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
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.edit)),
                  PopupMenuItem(value: 'export', child: Text(t.exportEntries)),
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

class _StoryEditorState extends State<_StoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.story?.name ?? '');
  late final _iconCtrl = TextEditingController(text: widget.story?.icon ?? '📖');
  late final _descCtrl = TextEditingController(
    text: widget.story?.description ?? '',
  );
  late final _openingCtrl = TextEditingController(
    text: widget.story?.opening ?? '',
  );
  late final _systemCtrl = TextEditingController(
    text: widget.story?.systemPrompt ?? '',
  );
  late final _worldCtrl = TextEditingController(
    text: widget.story?.worldBook ?? '',
  );
  late final _choicesCtrl = TextEditingController(
    text: widget.story?.choicesPrompt ?? '',
  );

  bool get _isNew => widget.story == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    _openingCtrl.dispose();
    _systemCtrl.dispose();
    _worldCtrl.dispose();
    _choicesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final story = Story(
      id: widget.story?.id ?? 'story_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      icon: _iconCtrl.text.trim().isEmpty ? '📖' : _iconCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      opening: _openingCtrl.text.trim(),
      systemPrompt: _systemCtrl.text.trim(),
      worldBook: _worldCtrl.text.trim(),
      choicesPrompt: _choicesCtrl.text.trim(),
      initialState: widget.story?.initialState ?? GameState.empty,
      isBuiltin: widget.story?.isBuiltin ?? false,
    );
    await StoryStore.instance.upsert(story);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: _isNew ? t.storyNew : t.storyEdit,
      body: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  child: Column(
                    children: [
                      _field(t.name, _nameCtrl),
                      _field(t.rolePlayAvatar, _iconCtrl, required: false),
                      _field(t.rolePlayDescription, _descCtrl, required: false),
                      _field(
                        t.storyOpening,
                        _openingCtrl,
                        required: false,
                        multiline: true,
                      ),
                      _field(
                        t.storySystemPrompt,
                        _systemCtrl,
                        required: false,
                        multiline: true,
                      ),
                      _field(
                        t.storyWorldBook,
                        _worldCtrl,
                        required: false,
                        multiline: true,
                      ),
                      _field(
                        t.storyChoicesPrompt,
                        _choicesCtrl,
                        required: false,
                        multiline: true,
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
      ),
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
        maxLines: multiline ? 8 : 1,
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
  String? _sessionId;
  GameState _state = GameState.empty;
  bool _sending = false;
  bool _booting = true;

  Story get story => widget.story;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await StorySessionStore.instance.ensureLoaded();
    final saved = StorySessionStore.instance.get(story.id);
    if (saved != null && saved.sessionId.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _sessionId = saved.sessionId;
        _state = saved.state;
        _booting = false;
      });
      return;
    }
    await _restart();
  }

  Future<void> _restart() async {
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
      _state = story.initialState;
      _booting = false;
    });
    await StorySessionStore.instance.put(
      story.id,
      StorySession(sessionId: sessionId, state: story.initialState),
    );
    await _send('开始游戏');
  }

  Future<void> _confirmRestart() async {
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
    if (ok == true) await _restart();
  }

  String get _systemPrompt {
    final base = story.buildSystemPrompt();
    if (story.opening.trim().isEmpty) return base;
    return '$base\n\n【开局场景（请从这里开始叙事）】\n${story.opening.trim()}';
  }

  Future<void> _send(String text) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    setState(() => _sending = true);
    final res = await AiConversationService().sendMessage(
      sessionId: sessionId,
      userMessage: text,
      taskType: 'story',
      maxContextMessages: 40,
      providerOverride: aiHubProvider(),
      systemPromptOverride: _systemPrompt,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.success) {
      final parsed = _parseReply(res.data);
      if (parsed.state != null) {
        await StorySessionStore.instance.put(
          story.id,
          StorySession(sessionId: sessionId, state: parsed.state!),
        );
      }
    } else {
      App.rootContext.showMessage(
        message: res.errorMessage ?? 'Error',
        level: LogLevel.error,
      );
    }
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
    final sessionId = _sessionId;
    return Scaffold(
      appBar: Appbar(
        title: Text('${story.icon} ${story.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: t.storyState,
            onPressed: _showStateSheet,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: t.storyRestart,
            onPressed: _confirmRestart,
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
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _chatContentMaxWidth(context),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            itemCount: messages.length + (_sending ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == messages.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: PolygonRefreshIndicator(),
                                  ),
                                );
                              }
                              final m = messages[i];
                              final isUser = m.role == 'user';
                              return _StoryBubble(
                                content: isUser
                                    ? m.inputContent
                                    : _parseReply(
                                        m.outputContent ?? '',
                                      ).narrative,
                                isUser: isUser,
                                task: m,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (choices.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                        child: SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: choices.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => _FollowUpChip(
                              text: choices[i],
                              onTap: _sending ? () {} : () => _send(choices[i]),
                            ),
                          ),
                        ),
                      ),
                    _AiComposerBar(
                      controller: _input,
                      onSend: _sendInput,
                      sending: _sending,
                      hintText: t.storyInput,
                      bottomLeading: _ModelSelector(
                        provider: aiHubProvider(),
                        onProviderChanged: (p) {
                          setAiHubProvider(p);
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
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
        }
      } catch (_) {}
    }
    return _ParsedReply(narrative: narrative, state: state, choices: choices);
  }

  Future<void> _showStateSheet() async {
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
      builder: (ctx) => Sheet(
        title: t.storyState,
        icon: Icons.assessment_outlined,
        initialSize: 0.6,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (state.location.isNotEmpty || state.time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  [state.location, state.time]
                      .where((e) => e.isNotEmpty)
                      .join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final r in state.resources)
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
                        value: r.max <= 0
                            ? 0
                            : (r.cur / r.max).clamp(0.0, 1.0),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            if (state.attributes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _sectionTitle(t.storyState),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in state.attributes.entries)
                    Chip(label: Text('${e.key} ${e.value}')),
                ],
              ),
            ],
            if (state.skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionTitle(t.skills),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in state.skills) Chip(label: Text(s)),
                ],
              ),
            ],
            if (state.inventory.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionTitle(t.storyInventory),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in state.inventory) Chip(label: Text(s)),
                ],
              ),
            ],
            if (state.quests.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionTitle(t.storyQuests),
              for (final q in state.quests)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(q.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (q.desc.isNotEmpty)
                        Text(q.desc, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (q.progress / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );

}

class _ParsedReply {
  final String narrative;
  final GameState? state;
  final List<String> choices;

  const _ParsedReply({
    required this.narrative,
    this.state,
    this.choices = const [],
  });
}
