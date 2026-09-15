part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：AI 共创角色卡（头脑风暴 → 生成 → 精修）
// 思路移植自 CarFrog，产出本项目的 CharacterCard。
// ═════════════════════════════════════════════

class _CreatorMessage {
  final String role; // user | assistant
  String content;
  bool excluded = false;
  CharacterCard? snapshot;

  _CreatorMessage(this.role, this.content);
}

class CharacterCardCreatorPage extends StatefulWidget {
  const CharacterCardCreatorPage({super.key, this.initial});

  final CharacterCard? initial;

  @override
  State<CharacterCardCreatorPage> createState() =>
      _CharacterCardCreatorPageState();
}

class _CharacterCardCreatorPageState extends State<CharacterCardCreatorPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scrollController = ScrollController();

  final _messages = <_CreatorMessage>[];
  late String _mode = widget.initial == null ? 'brainstorm' : 'refine';
  CharacterCard? _card;
  String? _summary;
  bool _sending = false;
  String _streamText = '';
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _card = widget.initial;
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _input.dispose();
    _focus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  Future<(String, String?, AiGenerationParams?)> _resolveModel() async {
    final aux = await AiConversationService().loadAuxConfig('cardGen');
    final provider = aux.provider.isNotEmpty ? aux.provider : aiHubProvider();
    return (
      provider,
      aux.model,
      aux.temperature == null
          ? null
          : AiGenerationParams(temperature: aux.temperature),
    );
  }

  List<AiMessage> _apiMessages() => [
    for (final m in _messages)
      if (!m.excluded)
        m.role == 'user'
            ? AiUserMessage(content: m.content)
            : AiAssistantMessage(content: m.content),
  ];

  String _systemPrompt() {
    final lang = creatorLanguage();
    return switch (_mode) {
      'brainstorm' =>
        '$cardBrainstormPrompt\n请始终用$lang与用户交流。',
      'refine' => buildCardRefineSystemPrompt(
        _card ?? CharacterCard(id: 'tmp', name: ''),
        summary: _summary,
        extra: '$cardRefinePrompt\n请始终用$lang与用户交流。',
      ),
      _ => cardGeneratePrompt,
    };
  }

  /// 发起一轮流式调用；返回累计文本（失败返回 null）
  Future<String?> _run(String systemPrompt, List<AiMessage> messages) async {
    final (provider, model, params) = await _resolveModel();
    final ai = AiFactory.create(provider);
    if (ai == null) {
      App.rootContext.showMessage(
        message: t.unknownServiceProvider(provider: provider),
        level: LogLevel.error,
      );
      return null;
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _sending = true;
      _streamText = '';
    });
    _scrollToBottom();
    final buffer = StringBuffer();
    try {
      await for (final chunk in ai.chatStream(
        messages,
        systemPrompt: systemPrompt,
        modelOverride: model,
        params: params,
        cancelToken: cancelToken,
      )) {
        if (!mounted) return null;
        if (chunk.errorMessage != null) {
          App.rootContext.showMessage(
            message: chunk.errorMessage!,
            level: LogLevel.error,
          );
          return null;
        }
        buffer
          ..clear()
          ..write(chunk.text);
        setState(() => _streamText = chunk.text);
        _scrollToBottom();
        if (chunk.done) break;
      }
    } catch (e) {
      if (mounted && !cancelToken.isCancelled) {
        App.rootContext.showMessage(message: e.toString(), level: LogLevel.error);
      }
      return null;
    } finally {
      _cancelToken = null;
      if (mounted) {
        setState(() {
          _sending = false;
          _streamText = '';
        });
      }
    }
    return buffer.toString();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() => _messages.add(_CreatorMessage('user', text)));
    _scrollToBottom();

    final reply = await _run(_systemPrompt(), _apiMessages());
    if (!mounted || reply == null) return;
    setState(() => _messages.add(_CreatorMessage('assistant', reply)));
    if (_mode == 'refine') _applyRefine(reply);
  }

  /// 头脑风暴 → 生成角色卡
  Future<void> _generate() async {
    if (_sending) return;
    final messages = [
      ..._apiMessages(),
      AiUserMessage(content: cardGenerateInstruction),
    ];
    final reply = await _run(
      '$cardGeneratePrompt\n请始终用${creatorLanguage()}输出。',
      messages,
    );
    if (!mounted || reply == null) return;
    setState(() => _messages.add(_CreatorMessage('assistant', reply)));
    final card = parseCardJsonFromText(reply);
    if (card == null) {
      App.rootContext.showMessage(
        message: t.cardAiParseFailed,
        level: LogLevel.warning,
      );
      return;
    }
    // 折叠头脑风暴上下文；精修只带当前卡 + 摘要
    setState(() {
      _summary = extractCardSummary(reply) ?? _summary;
      for (final m in _messages) {
        m.excluded = true;
      }
      _card = card;
      _mode = 'refine';
      _messages.add(
        _CreatorMessage('assistant', t.cardAiGeneratedNote),
      );
    });
    _scrollToBottom();
  }

  /// 应用精修差分（带回滚快照）
  void _applyRefine(String reply) {
    final actions = parseJsonActions(reply);
    if (actions.isEmpty || _card == null) return;
    final snapshot = _card!;
    final next = applyCardActions(_card!, actions);
    setState(() {
      _messages.last.snapshot = snapshot;
      _card = next;
    });
  }

  void _rollback() {
    if (_card == null) return;
    // 找到最近一条带快照的消息并回滚
    for (final m in _messages.reversed) {
      if (m.snapshot != null) {
        setState(() {
          _card = m.snapshot;
          m.snapshot = null;
        });
        return;
      }
    }
  }

  bool get _canRollback => _messages.any((m) => m.snapshot != null);

  void _finish() {
    final card = _card;
    if (card == null) return;
    context.pop(card);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.cardAiCreate),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          tooltip: t.back,
          onPressed: () => context.canPop() ? context.pop() : App.pop(),
        ),
        actions: [
          if (_canRollback)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: t.cardAiRollback,
              onPressed: _sending ? null : _rollback,
            ),
          if (_card != null)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: t.cardAiApply,
              onPressed: _sending ? null : _finish,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_card != null) _cardPreview(_card!),
          Expanded(
            child: ListView(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              children: [
                if (_streamText.trim().isNotEmpty)
                  _StoryBubble(content: _streamText, isUser: false),
                for (final m in _messages.reversed)
                  _StoryBubble(content: m.content, isUser: m.role == 'user'),
              ],
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _cardPreview(CharacterCard card) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.6),
        ),
      ),
      child: Row(
        children: [
          CharacterAvatar(
            name: card.displayName,
            avatar: card.avatar,
            radius: 18,
            enablePreview: false,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (card.description.trim().isNotEmpty)
                  Text(
                    card.description.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(
              children: [
                if (_mode == 'refine')
                  Expanded(
                    child: Text(
                      t.cardAiRefineHint,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (_mode == 'brainstorm' && _messages.isNotEmpty)
                  Expanded(child: TextButton.icon(
                    onPressed: _sending ? null : _generate,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(t.cardAiGenerate),
                  )),
              ],
            ),
          ),
          ChatComposerShell(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: t.cardAiHint,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_sending)
                    IconButton(
                      onPressed: () => _cancelToken?.cancel(),
                      tooltip: t.stopGenerating,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else
                    IconButton.filled(
                      onPressed: _send,
                      tooltip: t.sendMessage,
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
}
