part of 'ai_hub_page.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key});

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  String _source = 'siliconFlow';
  String? _sessionId;
  bool _isSending = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.unfocus();
    });
    _loadOrCreateSession();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _switchSession(String id) async {
    final session = await AiDatabase.instance.aiSessionDao.getSession(id);
    if (mounted) {
      setState(() {
        _sessionId = id;
        if (session != null) _source = session.provider;
      });
    }
  }

  Future<void> _loadOrCreateSession() async {
    final sessions = await AiConversationService()
        .watchSessions(type: 'chat')
        .first;
    if (sessions.isNotEmpty) {
      await _switchSession(sessions.first.sessionId);
    } else {
      await _newSession();
    }
  }

  Future<void> _newSession() async {
    final selectedKey = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _PersonalityPickerDialog(),
    );

    if (selectedKey == null) return;
    if (!context.mounted) return;

    final id = await AiConversationService().createSession(
      type: 'chat',
      provider: _source,
      title: '新对话 ${DateTime.now().toString().substring(0, 16)}',
      configKey: selectedKey.isEmpty ? null : selectedKey,
    );
    if (mounted) setState(() => _sessionId = id);
  }

  Future<void> _send({String? overrideMessage, int? rollbackFromId}) async {
    final text = overrideMessage ?? _inputCtrl.text.trim();
    if (text.isEmpty || _sessionId == null) return;
    if (overrideMessage == null) _inputCtrl.clear();

    if (rollbackFromId != null) {
      await AiConversationService().rollbackToMessage(
        _sessionId!,
        rollbackFromId,
      );
    }

    setState(() => _isSending = true);
    try {
      final result = await AiConversationService().sendMessage(
        sessionId: _sessionId!,
        userMessage: text,
        taskType: 'chat',
        providerOverride: _source,
      );
      if (!result.success && mounted) {
        setState(() => _lastError = result.errorMessage);
      } else {
        setState(() => _lastError = null);
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() => _lastError = e.toString());
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
        onSelectSession: (id) async {
          await _switchSession(id);
          if (mounted) Navigator.pop(context);
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
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: '话题列表'.tl,
            onPressed: _showSessionDrawer,
          ),
        ],
      ),
      body: Column(
        children: [
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
                          final isLast = i == messages.length - 1;

                          return _ChatBubble(
                            content: isUser
                                ? m.inputContent
                                : (m.outputContent ?? '...'),
                            isUser: isUser,
                            task: m,
                            errorText: (isLast && !isUser && _lastError != null)
                                ? _lastError
                                : null,
                            onRetry: (isLast && !isUser && _lastError != null)
                                ? () => _send(overrideMessage: m.inputContent)
                                : null,
                            onRollback: () {
                              if (isUser) {
                                _send(
                                  overrideMessage: m.inputContent,
                                  rollbackFromId: m.id,
                                );
                              } else {
                                _send(
                                  overrideMessage: m.inputContent,
                                  rollbackFromId: m.id,
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
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
                    if (_sessionId != null) {
                      AiConversationService().updateSessionProvider(
                        _sessionId!,
                        v,
                      );
                    }
                  },
                ),
                const Spacer(),
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
                    focusNode: _focusNode,
                    autofocus: false,
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
                        child: PolygonRefreshIndicator(),
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
    return Sheet(
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

class _ProviderModelSelector extends StatelessWidget {
  const _ProviderModelSelector({
    required this.source,
    required this.onSourceChanged,
  });

  final String source;
  final ValueChanged<String> onSourceChanged;

  static List<(String, String)> get _sources => OpenAiProviderRegistry
      .allProviders
      .entries
      .map((e) => (e.key, e.value.name))
      .toList();

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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.content,
    required this.isUser,
    required this.task,
    this.onRetry,
    this.onRollback,
    this.errorText,
  });

  final String content;
  final bool isUser;
  final AiTask task;
  final VoidCallback? onRetry;
  final VoidCallback? onRollback;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget bubble = GestureDetector(
      onLongPress: () => _showMenu(context),
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
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(child: bubble),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          // 错误提示 + 重试
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 40),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 14, color: scheme.error),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      errorText!,
                      style: TextStyle(fontSize: 11, color: scheme.error),
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onRetry,
                      child: Text(
                        '重试',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Sheet(
        title: isUser ? '我的消息' : 'AI 消息',
        icon: isUser ? Icons.person_outline : Icons.auto_awesome,
        initialSize: 0.28,
        builder: (ctx, _) => Column(
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: content));
                App.rootContext.showMessage(message: '已复制');
              },
            ),
            if (onRollback != null)
              ListTile(
                leading: const Icon(Icons.replay_outlined),
                title: Text(isUser ? '从此处重新发送' : '重新生成此回复'),
                onTap: () {
                  Navigator.pop(ctx);
                  onRollback!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonalityPickerDialog extends StatefulWidget {
  const _PersonalityPickerDialog();

  @override
  State<_PersonalityPickerDialog> createState() =>
      _PersonalityPickerDialogState();
}

class _PersonalityPickerDialogState extends State<_PersonalityPickerDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: '选择 AI 人格'.tl,
      content: SizedBox(
        height: 400,
        child: FutureBuilder<List<AiConfig>>(
          future: AiDatabase.instance.aiConfigDao.getAll(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final configs = snap.data!;
            return Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ConfigTile(
                      label: '无人格',
                      memo: '不使用系统提示词',
                      isSelected: _selected == null,
                      onTap: () => setState(() => _selected = null),
                    ),
                    const Divider(height: 8),
                    ...configs.map(
                      (c) => _ConfigTile(
                        label: c.memo ?? c.configKey,
                        memo: c.systemPrompt.length > 40
                            ? '${c.systemPrompt.substring(0, 40)}...'
                            : c.systemPrompt,
                        isSelected: _selected == c.configKey,
                        onTap: () => setState(() => _selected = c.configKey),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected ?? ''),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

class _ConfigTile extends StatelessWidget {
  const _ConfigTile({
    required this.label,
    required this.memo,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String memo;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: isSelected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? scheme.primary : scheme.outline,
        size: 20,
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        memo,
        style: TextStyle(fontSize: 11, color: scheme.outline),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}
