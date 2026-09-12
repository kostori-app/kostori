part of 'ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：AI 扮演（角色列表 + 扮演式对话）
// ═════════════════════════════════════════════

class RolePlayPage extends ConsumerStatefulWidget {
  const RolePlayPage({super.key});

  @override
  ConsumerState<RolePlayPage> createState() => _RolePlayPageState();
}

class _RolePlayPageState extends ConsumerState<RolePlayPage> {
  @override
  void initState() {
    super.initState();
    AiRoleStore.instance.init();
  }

  Future<void> _add() async {
    await showPopUpWidget(App.rootContext, const _RoleEditor());
    if (mounted) setState(() {});
  }

  Future<void> _edit(AiRole role) async {
    await showPopUpWidget(App.rootContext, _RoleEditor(role: role));
    if (mounted) setState(() {});
  }

  Future<void> _delete(AiRole role) async {
    final ok = await AiRoleStore.instance.remove(role.id);
    if (!ok && mounted) {
      App.rootContext.showMessage(
        message: t.builtinPluginCannotDelete,
        level: LogLevel.warning,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(t.rolePlay)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(t.rolePlayNew),
      ),
      body: ListenableBuilder(
        listenable: AiRoleStore.instance,
        builder: (context, _) {
          final roles = AiRoleStore.instance.roles;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: roles.length,
            itemBuilder: (context, i) {
              final r = roles[i];
              return _RoleCard(
                role: r,
                onTap: () => context.to(() => RoleChatPage(role: r)),
                onEdit: r.isBuiltin ? null : () => _edit(r),
                onDelete: r.isBuiltin ? null : () => _delete(r),
              );
            },
          );
        },
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final AiRole role;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
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
              Text(role.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (role.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        role.description,
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
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  tooltip: t.more,
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(t.edit)),
                    PopupMenuItem(value: 'delete', child: Text(t.delete)),
                  ],
                )
              else
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 扮演式对话
// ─────────────────────────────────────────────

class RoleChatPage extends ConsumerStatefulWidget {
  const RoleChatPage({super.key, required this.role});

  final AiRole role;

  @override
  ConsumerState<RoleChatPage> createState() => _RoleChatPageState();
}

class _RoleChatPageState extends ConsumerState<RoleChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final String _provider = aiHubProvider();
  String? _sessionId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    final id = await AiConversationService().createSession(
      type: 'roleplay',
      provider: _provider,
      title: widget.role.name,
    );
    if (mounted) setState(() => _sessionId = id);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _systemPrompt {
    final g = widget.role.greeting.trim();
    final base = widget.role.persona.trim();
    if (g.isEmpty) return base;
    return '$base\n\n（你在对话开始时已经说过：「$g」）';
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final sessionId = _sessionId;
    if (text.isEmpty || sessionId == null || _sending) return;
    _input.clear();
    setState(() => _sending = true);
    final res = await AiConversationService().sendMessage(
      sessionId: sessionId,
      userMessage: text,
      taskType: 'roleplay',
      systemPromptOverride: _systemPrompt,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res.error) {
      App.rootContext.showMessage(
        message: res.errorMessage ?? 'Error',
        level: LogLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text('${widget.role.emoji} ${widget.role.name}')),
      body: Column(
        children: [
          Expanded(
            child: _sessionId == null
                ? const Center(child: PolygonRefreshIndicator())
                : StreamBuilder<List<AiTask>>(
                    stream: AiConversationService().watchMessages(_sessionId!),
                    builder: (context, snap) {
                      final messages = snap.data ?? [];
                      final showGreeting =
                          messages.isEmpty &&
                          widget.role.greeting.trim().isNotEmpty;
                      return ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (showGreeting)
                            _bubble(context, widget.role.greeting, false),
                          for (final m in messages)
                            _bubble(
                              context,
                              m.role == 'user'
                                  ? m.inputContent
                                  : (m.outputContent ?? ''),
                              m.role == 'user',
                            ),
                          if (_sending) _thinking(context),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: t.rolePlayHint,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, String text, bool isUser) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomMarkdownWidget(data: text),
      ),
    );
  }

  Widget _thinking(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: PolygonRefreshIndicator(),
            ),
            SizedBox(width: 8),
            Text('...'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 角色编辑
// ─────────────────────────────────────────────

class _RoleEditor extends StatefulWidget {
  const _RoleEditor({this.role});

  final AiRole? role;

  @override
  State<_RoleEditor> createState() => _RoleEditorState();
}

class _RoleEditorState extends State<_RoleEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.role?.name ?? '');
  late final _emojiCtrl = TextEditingController(text: widget.role?.emoji ?? '🧑');
  late final _descCtrl = TextEditingController(
    text: widget.role?.description ?? '',
  );
  late final _personaCtrl = TextEditingController(
    text: widget.role?.persona ?? '',
  );
  late final _greetingCtrl = TextEditingController(
    text: widget.role?.greeting ?? '',
  );
  late final _tagsCtrl = TextEditingController(
    text: widget.role?.tags.join(', ') ?? '',
  );

  bool get _isNew => widget.role == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _descCtrl.dispose();
    _personaCtrl.dispose();
    _greetingCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final role = AiRole(
      id: widget.role?.id ?? 'role_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '🧑' : _emojiCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      persona: _personaCtrl.text.trim(),
      greeting: _greetingCtrl.text.trim(),
      tags: _tagsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      isBuiltin: widget.role?.isBuiltin ?? false,
    );
    await AiRoleStore.instance.upsert(role);
    if (mounted) {
      App.rootContext.showMessage(message: t.saved);
      App.rootContext.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: _isNew ? t.rolePlayNew : t.edit,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _field(t.rolePlayName, _nameCtrl),
                      _field(t.rolePlayAvatar, _emojiCtrl, required: false),
                      _field(
                        t.rolePlayDescription,
                        _descCtrl,
                        required: false,
                      ),
                      _field(
                        t.rolePlayPersona,
                        _personaCtrl,
                        multiline: true,
                      ),
                      _field(
                        t.rolePlayGreeting,
                        _greetingCtrl,
                        required: false,
                        multiline: true,
                      ),
                      _field(t.rolePlayTags, _tagsCtrl, required: false),
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
        maxLines: multiline ? 6 : 1,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? t.required : null
            : null,
      ),
    );
  }
}
