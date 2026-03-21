part of 'ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块3：AI 对话（带上下文记忆 + 多话题）
// ═════════════════════════════════════════════

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _source = 'siliconFlow';
  String? _sessionId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateSession();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // 启动时加载最近一个 chat 会话，没有则新建
  Future<void> _loadOrCreateSession() async {
    final sessions = await AiConversationService()
        .watchSessions(type: 'chat')
        .first;
    if (sessions.isNotEmpty) {
      if (mounted) setState(() => _sessionId = sessions.first.sessionId);
    } else {
      await _newSession();
    }
  }

  Future<void> _newSession({String? title}) async {
    final id = await AiConversationService().createSession(
      type: 'chat',
      provider: _source,
      title: title ?? '新对话 ${DateTime.now().toString().substring(0, 16)}',
    );
    if (mounted) setState(() => _sessionId = id);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sessionId == null) return;
    _inputCtrl.clear();
    setState(() => _isSending = true);
    try {
      await AiConversationService().sendMessage(
        sessionId: _sessionId!,
        userMessage: text,
        taskType: 'chat',
      );
      _scrollToBottom();
    } catch (e) {
      App.rootContext.showMessage(message: 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSessionDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ChatSessionSheet(
        currentSessionId: _sessionId,
        onSelectSession: (id) {
          setState(() => _sessionId = id);
          Navigator.pop(context);
        },
        onNewSession: () async {
          Navigator.pop(context);
          await _newSession();
        },
        onDeleteSession: (id) async {
          await AiConversationService().deleteSession(id);
          if (_sessionId == id) await _loadOrCreateSession();
        },
      ),
    );
  }

  Future<void> _renameCurrentSession() async {
    if (_sessionId == null) return;
    final session = await AiDatabase.instance.aiSessionDao.getSession(
      _sessionId!,
    );
    if (session == null) return;
    final ctrl = TextEditingController(text: session.title);
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: 'Rename'.tl,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: '对话标题'.tl,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await AiConversationService().renameSession(
                _sessionId!,
                ctrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save'.tl),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: _sessionId == null
            ? Text('AI 对话'.tl)
            : StreamBuilder<List<AiSession>>(
                stream: AiConversationService().watchSessions(type: 'chat'),
                builder: (ctx, snap) {
                  final session = snap.data?.firstWhere(
                    (s) => s.sessionId == _sessionId,
                    orElse: () => snap.data!.first,
                  );
                  return GestureDetector(
                    onTap: _renameCurrentSession,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            session?.title ?? 'AI 对话'.tl,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 14),
                      ],
                    ),
                  );
                },
              ),
        actions: [
          // 话题列表
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: '话题列表'.tl,
            onPressed: _showSessionDrawer,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 消息列表 ──────────────────────────
          Expanded(
            child: _sessionId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<AiTask>>(
                    stream: AiConversationService().watchMessages(_sessionId!),
                    builder: (ctx, snapshot) {
                      final messages = snapshot.data ?? [];
                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '开始与 AI 对话吧'.tl,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );
                      return ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final m = messages[i];
                          final isUser = m.role == 'user';
                          return _ChatBubble(
                            content: isUser
                                ? m.inputContent
                                : (m.outputContent ?? '...'),
                            isUser: isUser,
                          );
                        },
                      );
                    },
                  ),
          ),

          // ── 服务商/模型 选择栏 ─────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                _ProviderModelSelector(
                  source: _source,
                  onSourceChanged: (v) {
                    setState(() => _source = v);
                  },
                ),
                const Spacer(),
                // 新建对话快捷按钮
                IconButton(
                  icon: const Icon(Icons.add_comment_outlined, size: 20),
                  tooltip: '新建对话'.tl,
                  onPressed: _newSession,
                ),
              ],
            ),
          ),

          // ── 输入框 ────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '输入消息...'.tl,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.send, size: 20),
                        onPressed: _send,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 话题列表 Sheet
// ─────────────────────────────────────────────

class _ChatSessionSheet extends StatelessWidget {
  const _ChatSessionSheet({
    required this.currentSessionId,
    required this.onSelectSession,
    required this.onNewSession,
    required this.onDeleteSession,
  });

  final String? currentSessionId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewSession;
  final ValueChanged<String> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return HubSheet(
      title: '话题列表'.tl,
      icon: Icons.forum_outlined,
      initialSize: 0.6,
      headerTrailing: FilledButton.tonal(
        onPressed: onNewSession,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16),
            const SizedBox(width: 4),
            Text('新建'.tl),
          ],
        ),
      ),
      builder: (context, sc) => StreamBuilder<List<AiSession>>(
        stream: AiConversationService().watchSessions(type: 'chat'),
        builder: (ctx, snapshot) {
          final sessions = snapshot.data ?? [];
          if (sessions.isEmpty) {
            return Center(child: Text('暂无话题'.tl));
          }
          return ListView.separated(
            controller: sc,
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = sessions[i];
              final isCurrent = s.sessionId == currentSessionId;
              final scheme = Theme.of(context).colorScheme;
              return ListTile(
                selected: isCurrent,
                selectedTileColor: scheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: isCurrent
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  s.updatedAt.toLocal().toString().substring(0, 16),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: scheme.error,
                  onPressed: () => onDeleteSession(s.sessionId),
                ),
                onTap: () => onSelectSession(s.sessionId),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 服务商 + 模型选择器（左下角）
// ─────────────────────────────────────────────

class _ProviderModelSelector extends StatelessWidget {
  const _ProviderModelSelector({
    required this.source,
    required this.onSourceChanged,
  });

  final String source;
  final ValueChanged<String> onSourceChanged;

  static const _sources = [
    ('siliconFlow', 'SiliconFlow'),
    ('doubao', 'Doubao'),
    ('gemini', 'Gemini'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sourceName = _sources
        .firstWhere((s) => s.$1 == source, orElse: () => _sources.first)
        .$2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 服务商
        PopupMenuButton<String>(
          onSelected: onSourceChanged,
          offset: const Offset(0, -160),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.psychology, size: 14),
                const SizedBox(width: 4),
                Text(sourceName, style: const TextStyle(fontSize: 12)),
                const Icon(Icons.arrow_drop_up, size: 16),
              ],
            ),
          ),
          itemBuilder: (_) => _sources
              .map(
                (s) => PopupMenuItem(
                  value: s.$1,
                  child: Row(
                    children: [
                      if (s.$1 == source)
                        Icon(Icons.check, size: 16, color: scheme.primary),
                      if (s.$1 != source) const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(s.$2),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(width: 8),
        // 模型
        _ModelSelector(provider: source),
      ],
    );
  }
}

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<AiApiKey?>(
      future: AiDatabase.instance.aiApiKeyDao.getByProvider(provider),
      builder: (ctx, keySnap) {
        final currentModel = keySnap.data?.model ?? '...';
        return StreamBuilder<List<AiModel>>(
          stream: (AiDatabase.instance.select(
            AiDatabase.instance.aiModels,
          )..where((t) => t.provider.equals(provider))).watch(),
          builder: (ctx, modelSnap) {
            final models = modelSnap.data ?? [];
            final chip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.model_training, size: 14),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      currentModel,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (models.length > 1)
                    const Icon(Icons.arrow_drop_up, size: 16),
                ],
              ),
            );

            if (models.length <= 1) return chip;

            return PopupMenuButton<String>(
              offset: const Offset(0, -160),
              onSelected: (modelId) async {
                await AiDatabase.instance.aiApiKeyDao.updateModel(
                  provider,
                  modelId,
                );
              },
              child: chip,
              itemBuilder: (_) => models
                  .map(
                    (m) => PopupMenuItem(
                      value: m.modelId,
                      child: Row(
                        children: [
                          if (m.modelId == currentModel)
                            Icon(Icons.check, size: 16, color: scheme.primary)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(m.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// 消息气泡
// ─────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.content, required this.isUser});

  final String content;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isUser
                  ? Text(
                      content,
                      style: TextStyle(color: scheme.onPrimary, fontSize: 14),
                    )
                  : CustomMarkdownWidget(data: content),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
