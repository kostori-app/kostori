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
                  onTap: () => context.to(() => StoryGamePage(story: s)),
                  onEdit: () => _edit(s),
                  onExport: () => _export(s),
                  onRestart: () => _restart(s),
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
    required this.onRestart,
    this.onDelete,
  });

  final Story story;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;
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
                  if (v == 'restart') onRestart();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.edit)),
                  PopupMenuItem(value: 'export', child: Text(t.exportEntries)),
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
  late final _situationCtrl = TextEditingController(
    text: widget.story?.situation ?? '',
  );
  late final _choicesCtrl = TextEditingController(
    text: widget.story?.choicesPrompt ?? '',
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
      buf.writeln('【${name.isEmpty ? '设定' : name}】');
      buf.writeln(content);
      buf.writeln();
    }
    return buf.toString().trim();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _descCtrl.dispose();
    _openingCtrl.dispose();
    _systemCtrl.dispose();
    _situationCtrl.dispose();
    _choicesCtrl.dispose();
    _stateCtrl.dispose();
    for (final e in _worldBook) {
      e.dispose();
    }
    for (final a in _actions) {
      a.dispose();
    }
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
      icon: _iconCtrl.text.trim().isEmpty ? '📖' : _iconCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      opening: _openingCtrl.text.trim(),
      systemPrompt: _systemCtrl.text.trim(),
      worldBook: _serializeWorldBook(),
      situation: _situationCtrl.text.trim(),
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
      initialState: initialState,
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
    return DefaultTabController(
      length: 8,
      child: PopUpWidgetScaffold(
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
              TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: t.basicInfo),
                  Tab(text: t.storyOpening),
                  Tab(text: t.storySystemPrompt),
                  Tab(text: t.storyWorldBook),
                  Tab(text: t.storySituation),
                  Tab(text: t.storyInitialState),
                  Tab(text: t.storyChoicesPrompt),
                  Tab(text: t.storyActions),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _basicTab(),
                    _textTab(_openingCtrl),
                    _textTab(_systemCtrl),
                    _worldBookTab(),
                    _textTab(_situationCtrl),
                    _textTab(_stateCtrl),
                    _textTab(_choicesCtrl),
                    _actionsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _basicTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(t.name, _nameCtrl),
        _field(t.rolePlayAvatar, _iconCtrl, required: false),
        _field(
          t.rolePlayDescription,
          _descCtrl,
          required: false,
          multiline: true,
        ),
      ],
    );
  }

  Widget _textTab(TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: ctrl,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    );
  }

  Widget _worldBookTab() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
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
    return ListView(
      padding: const EdgeInsets.all(16),
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
  final _scrollController = ScrollController();
  String? _sessionId;
  GameState _state = GameState.empty;
  bool _sending = false;
  bool _booting = true;
  bool _showStreamBubble = false;
  String _streamText = '';
  CancelToken? _cancelToken;
  int _lastMessageCount = 0;

  /// 需要先做开局档案设置（仅新游戏且故事定义了 setup 时）
  bool _needsSetup = false;
  final Map<String, String> _singleValues = {};
  final Map<String, Set<String>> _multiValues = {};
  final Map<String, TextEditingController> _textValues = {};
  final Map<String, int> _numberValues = {};

  Story get story => widget.story;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    for (final c in _textValues.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 滚到底部（流式时用 jump，新消息时用动画），与 AI 聊天的焦点逻辑对齐
  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else if ((_scrollController.offset - target).abs() > 1) {
        _scrollController.jumpTo(target);
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
        _state = saved.state;
        _booting = false;
      });
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
    await _send('开始游戏');
  }

  Future<void> _newSession({GameState? initialState}) async {
    final initial = initialState ?? story.initialState;
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
    final buf = StringBuffer('【角色档案】');
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
  String _systemPromptFor(GameState state) {
    final buf = StringBuffer(story.buildSystemPrompt());
    if (story.opening.trim().isNotEmpty) {
      buf.write('\n\n【开局场景（请从这里开始叙事）】\n${story.opening.trim()}');
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
    return buf.toString();
  }

  Future<void> _send(String text) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _sending = true;
      _showStreamBubble = true;
      _streamText = '';
    });
    try {
      await for (final u in AiConversationService().sendMessageStream(
        sessionId: sessionId,
        userMessage: text,
        taskType: 'story',
        providerOverride: aiHubProvider(),
        systemPromptOverride: _systemPromptFor(_state),
        cancelToken: cancelToken,
      )) {
        if (!mounted) return;
        if (u.errorMessage != null) {
          setState(() {
            _sending = false;
            _showStreamBubble = false;
            _streamText = '';
          });
          App.rootContext.showMessage(
            message: u.errorMessage!,
            level: LogLevel.error,
          );
          return;
        }
        setState(() => _streamText = u.text);
        _scrollToBottom(animate: false);
        if (u.done) break;
      }
      if (!mounted) return;
      final finalText = _streamText;
      final cancelled = cancelToken.isCancelled;
      setState(() {
        _sending = false;
        _showStreamBubble = false;
        _streamText = '';
      });
      _scrollToBottom();
      // 取消时服务端不落库，忽略本次结果
      if (cancelled || finalText.trim().isEmpty) return;
      final parsed = _parseReply(finalText);
      if (parsed.state != null) {
        var state = parsed.state!;
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
        setState(() => _state = state);
        await StorySessionStore.instance.put(
          story.id,
          StorySession(sessionId: sessionId, state: state),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _showStreamBubble = false;
          _streamText = '';
        });
        App.rootContext.showMessage(message: e.toString(), level: LogLevel.error);
      }
    } finally {
      _cancelToken = null;
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
    if (_needsSetup) return _buildSetup(context);
    final sessionId = _sessionId;
    return Scaffold(
      appBar: Appbar(title: Text('${story.icon} ${story.name}')),
      body: sessionId == null
          ? const Center(child: PolygonRefreshIndicator())
          : StreamBuilder<List<AiTask>>(
              stream: AiConversationService().watchMessages(sessionId),
              builder: (context, snap) {
                final messages = snap.data ?? [];
                final choices = _lastAiReply(messages)?.choices ?? const <String>[];
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: _chatContentMaxWidth(context),
                          ),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            itemCount:
                                messages.length + (_showStreamBubble ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == messages.length) {
                                final streamNarrative = _parseReply(
                                  _streamText,
                                ).narrative;
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
                                return _StoryBubble(
                                  content: streamNarrative,
                                  isUser: false,
                                );
                              }
                              final m = messages[i];
                              final isUser = m.role == 'user';
                              final parsed = isUser
                                  ? null
                                  : _parseReply(m.outputContent ?? '');
                              return _StoryBubble(
                                content: isUser
                                    ? m.inputContent
                                    : (parsed?.narrative ?? ''),
                                isUser: isUser,
                                task: m,
                                events: parsed?.events ?? const [],
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
      appBar: Appbar(title: Text('${story.icon} ${story.name}')),
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
            FilterChip(
              label: Text(o),
              selected: _multiValues[part.key]?.contains(o) ?? false,
              onSelected: (v) => setState(() {
                final set = _multiValues.putIfAbsent(part.key, () => {});
                if (v) {
                  set.add(o);
                } else {
                  set.remove(o);
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
            ChoiceChip(
              label: Text(o),
              selected: _singleValues[part.key] == o,
              onSelected: (v) {
                if (v) setState(() => _singleValues[part.key] = o);
              },
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

  /// 「更多」：故事自定义的操作按钮（一键 / 批量等）
  Future<void> _showMore() async {
    if (story.actions.isEmpty) {
      App.rootContext.showMessage(
        message: t.storyNoActions,
        level: LogLevel.warning,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.storyMore,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
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
  int _tab = 0;

  GameState get state => widget.state;

  /// 在 codex 里按名称/键查找设定（容忍「物品 x2」这类后缀）
  StoryDefinition? _findDef(String name) {
    final key = name.split(' x').first.split('×').first.trim();
    for (final d in state.codex) {
      if (d.key == name || d.name == name || d.key == key || d.name == key) {
        return d;
      }
    }
    return null;
  }

  IconData _iconFor(String name, String fallbackKind) =>
      _codexIcon(_findDef(name)?.kind ?? fallbackKind);

  /// 查看条目说明：图鉴里显示图鉴描述，否则提示暂无
  Future<void> _inspect(String name, String kind) async {
    final def = _findDef(name);
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_codexIcon(def?.kind ?? kind), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(def?.name ?? name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                def == null
                    ? t.storyNoSituation
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
  }

  /// 物品菜单：检查 / 使用 / 丢弃
  Future<void> _itemMenu(String item) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                widget.onCommand('使用 $item');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(t.storyDrop),
              onTap: () {
                Navigator.of(ctx).pop();
                widget.onCommand('丢弃 $item');
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
    VoidCallback? onLongPress,
    VoidCallback? onSecondaryTap,
  }) {
    return GestureDetector(
      onLongPress: onLongPress,
      onSecondaryTapDown: onSecondaryTap == null ? null : (_) => onSecondaryTap(),
      child: ActionChip(
        avatar: Icon(_iconFor(label, kind), size: 16),
        label: Text(label),
        onPressed: () => _inspect(label, kind),
      ),
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
                  onTap: () => setState(() => _tab = 0),
                ),
                CapsuleOption(
                  text: t.storySituation,
                  isSelected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: _tab == 0 ? _buildState(scheme) : _buildSituation(scheme),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildState(ColorScheme scheme) {
    return [
      if (state.location.isNotEmpty || state.time.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            [state.location, state.time].where((e) => e.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
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
            for (final s in state.skills) _entry(label: s, kind: 'skill'),
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
            for (final s in state.inventory)
              _entry(
                label: s,
                kind: 'item',
                onLongPress: () => _itemMenu(s),
                onSecondaryTap: () => _itemMenu(s),
              ),
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
      if (state.codex.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionTitle(t.storyCodex),
        for (final d in state.codex)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_codexIcon(d.kind), size: 20),
            title: Text(d.name),
            subtitle: Text(
              d.display.isEmpty ? d.mechanics : d.display,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => _inspect(d.name, d.kind),
          ),
      ],
    ];
  }

  List<Widget> _buildSituation(ColorScheme scheme) {
    final blocks = <Widget>[];
    if (widget.story.situation.trim().isNotEmpty) {
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
  _ => Icons.menu_book_outlined,
};

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  ),
);

class _ParsedReply {
  final String narrative;
  final GameState? state;
  final List<String> choices;
  final List<StoryEvent> events;

  const _ParsedReply({
    required this.narrative,
    this.state,
    this.choices = const [],
    this.events = const [],
  });
}
