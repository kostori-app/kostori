part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

// ═════════════════════════════════════════════
// 模块：群聊（多张角色卡同场对话，区别于 GM 驱动的「故事」）
// ═════════════════════════════════════════════

/// 解析模型输出里的 〖角色：名字〗…〖/角色〗 分段；无标记的文本为旁白（name=null）
final _groupOpenRe = RegExp(r'[〖【]\s*角色\s*[:：]\s*([^〗】]+?)\s*[〗】]');
final _groupCloseRe = RegExp(r'[〖【]\s*/\s*角色\s*[〗】]');

List<(String?, String)> parseGroupSegments(String text) {
  final out = <(String?, String)>[];
  final buf = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final open = _groupOpenRe.matchAsPrefix(text, i);
    if (open != null) {
      final plain = buf.toString().trim();
      if (plain.isNotEmpty) out.add((null, plain));
      buf.clear();
      final name = open.group(1)?.trim() ?? '';
      final start = open.end;
      final close = _groupCloseRe.firstMatch(text.substring(start));
      final end = close == null ? text.length : start + close.start;
      final body = text.substring(start, end).trim();
      if (body.isNotEmpty) out.add((name, body));
      i = close == null ? text.length : start + close.end;
    } else {
      buf.write(text[i]);
      i++;
    }
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) out.add((null, tail));
  return out;
}

// ─────────────────────────────────────────────
// 群聊列表
// ─────────────────────────────────────────────

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  @override
  void initState() {
    super.initState();
    GroupChatStore.instance.init();
    CharacterCardStore.instance.ensureLoaded();
  }

  Future<void> _new() async {
    final created = await showPopUpWidget<GroupChat?>(
      App.rootContext,
      const _GroupChatEditor(),
    );
    if (created == null || !mounted) return;
    await GroupChatStore.instance.upsert(created);
    if (mounted) context.to(() => GroupChatRoomPage(groupId: created.id));
  }

  Future<void> _delete(GroupChat g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text('${t.areYouSureYouWantToDeleteGeneric} "${g.name}"?'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (g.sessionId.isNotEmpty) {
      await AiConversationService().deleteSession(g.sessionId);
    }
    await GroupChatStore.instance.remove(g.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        GroupChatStore.instance,
        CharacterCardStore.instance,
      ]),
      builder: (context, _) {
        final groups = GroupChatStore.instance.chats;
        return Scaffold(
          appBar: Appbar(
            title: Text(t.groupChat),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              tooltip: t.back,
              onPressed: () => context.canPop() ? context.pop() : App.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: t.newGroupChat,
                onPressed: _new,
              ),
            ],
          ),
          body: groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t.groupChatEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.tonalIcon(
                          onPressed: _new,
                          icon: const Icon(Icons.add),
                          label: Text(t.newGroupChat),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final g in groups)
                      _GroupChatCard(
                        chat: g,
                        onTap: () =>
                            context.to(() => GroupChatRoomPage(groupId: g.id)),
                        onEdit: () async {
                          final edited = await showPopUpWidget<GroupChat?>(
                            App.rootContext,
                            _GroupChatEditor(chat: g),
                          );
                          if (edited != null) {
                            await GroupChatStore.instance.upsert(edited);
                          }
                        },
                        onDelete: () => _delete(g),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _GroupChatCard extends StatelessWidget {
  const _GroupChatCard({
    required this.chat,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final GroupChat chat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members = [
      for (final id in chat.memberIds)
        if (CharacterCardStore.instance.find(id) case final c?) c,
    ];
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
                    Text(
                      chat.name.isEmpty ? t.groupChat : chat.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 24,
                      child: Row(
                        children: [
                          for (final c in members.take(6))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: CharacterAvatar(
                                name: c.displayName,
                                avatar: c.avatar,
                                radius: 10,
                                enablePreview: false,
                              ),
                            ),
                          if (members.length > 6)
                            Text(
                              '+${members.length - 6}',
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
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(t.edit)),
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
// 群聊编辑（新建 / 修改）
// ─────────────────────────────────────────────

class _GroupChatEditor extends StatefulWidget {
  const _GroupChatEditor({this.chat});

  final GroupChat? chat;

  @override
  State<_GroupChatEditor> createState() => _GroupChatEditorState();
}

class _GroupChatEditorState extends State<_GroupChatEditor> {
  late final _nameCtrl = TextEditingController(text: widget.chat?.name ?? '');
  late final _scenarioCtrl = TextEditingController(
    text: widget.chat?.scenario ?? '',
  );
  late final _extraCtrl = TextEditingController(
    text: widget.chat?.systemExtra ?? '',
  );
  late final List<String> _memberIds = [...?widget.chat?.memberIds];
  late String _order = widget.chat?.order ?? 'natural';
  late bool _auto = widget.chat?.autoMode ?? false;

  bool get _isNew => widget.chat == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _scenarioCtrl.dispose();
    _extraCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_memberIds.isEmpty) {
      App.rootContext.showMessage(
        message: t.groupChatNoMembers,
        level: LogLevel.warning,
      );
      return;
    }
    final chat = (widget.chat ?? GroupChat(id: 'group_${DateTime.now().microsecondsSinceEpoch}'))
        .copyWith(
          name: _nameCtrl.text.trim(),
          memberIds: _memberIds,
          scenario: _scenarioCtrl.text.trim(),
          systemExtra: _extraCtrl.text.trim(),
          order: _order,
          autoMode: _auto,
        );
    // 编辑器在 PopUpWidget 的嵌套 Navigator 里，必须 pop 根 Navigator 才能返回结果
    Navigator.of(App.rootContext, rootNavigator: true).pop(chat);
  }

  @override
  Widget build(BuildContext context) {
    final cards = CharacterCardStore.instance.cards;
    return PopUpWidgetScaffold(
      title: _isNew ? t.newGroupChat : t.edit,
      tailing: [
        IconButton(
          icon: const Icon(Icons.check),
          tooltip: t.apply,
          onPressed: _save,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: t.groupChatName,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.groupChatMembers,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (cards.isEmpty)
              Text(t.characterCardsEmpty, style: ts.s12)
            else
              for (final c in cards)
                SelectCard(
                  title: c.displayName,
                  subtitle: c.tags.isEmpty ? null : c.tags.join(' · '),
                  leading: CharacterAvatar(
                    name: c.displayName,
                    avatar: c.avatar,
                    radius: 14,
                    enablePreview: false,
                  ),
                  selected: _memberIds.contains(c.id),
                  onChanged: (v) => setState(() {
                    if (v) {
                      if (!_memberIds.contains(c.id)) _memberIds.add(c.id);
                    } else {
                      _memberIds.remove(c.id);
                    }
                  }),
                ),
            const SizedBox(height: 16),
            TextField(
              controller: _scenarioCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t.groupChatScenario,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _extraCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: t.groupChatExtraPrompt,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.groupChatOrder,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            CapsuleOptions(
              alignment: WrapAlignment.start,
              children: [
                CapsuleOption(
                  text: t.groupChatOrderNatural,
                  isSelected: _order == 'natural',
                  onTap: () => setState(() => _order = 'natural'),
                ),
                CapsuleOption(
                  text: t.groupChatOrderList,
                  isSelected: _order == 'list',
                  onTap: () => setState(() => _order = 'list'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(t.groupChatAutoMode)),
                CustomSwitch(
                  value: _auto,
                  onChanged: (v) => setState(() => _auto = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 群聊房间
// ─────────────────────────────────────────────

class GroupChatRoomPage extends StatefulWidget {
  const GroupChatRoomPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupChatRoomPage> createState() => _GroupChatRoomPageState();
}

class _GroupChatRoomPageState extends State<GroupChatRoomPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();

  GroupChat? _chat;
  String? _sessionId;
  Stream<List<AiTask>>? _messagesStream;
  List<CharacterCard> _members = const [];
  String? _nextSpeaker;
  int _speakerIndex = 0;
  bool _auto = false;
  bool _sending = false;
  bool _booting = true;
  String _streamText = '';
  CancelToken? _cancelToken;
  int _autoRemaining = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _boot() async {
    await GroupChatStore.instance.ensureLoaded();
    await CharacterCardStore.instance.ensureLoaded();
    final chat = GroupChatStore.instance.find(widget.groupId);
    if (chat == null || !mounted) return;
    _chat = chat;
    _auto = chat.autoMode;
    _speakerIndex = chat.speakerIndex;
    _members = [
      for (final id in chat.memberIds)
        if (CharacterCardStore.instance.find(id) case final c?) c,
    ];
    if (chat.sessionId.isEmpty) {
      await _newSession(chat);
    } else {
      setState(() {
        _sessionId = chat.sessionId;
        _messagesStream = AiConversationService().watchMessages(
          chat.sessionId,
        );
        _booting = false;
      });
    }
  }

  String? _greetingOf(CharacterCard c) {
    if (c.groupOnlyGreetings.isNotEmpty) {
      final g = c.groupOnlyGreetings.first.trim();
      if (g.isNotEmpty) return g;
    }
    final f = c.firstMessage.trim();
    return f.isEmpty ? null : f;
  }

  Future<void> _newSession(GroupChat chat) async {
    final old = chat.sessionId;
    if (old.isNotEmpty) {
      await AiConversationService().deleteSession(old);
    }
    final sessionId = await AiConversationService().createSession(
      type: 'group',
      provider: aiHubProvider(),
      title: chat.name.isEmpty ? t.groupChat : chat.name,
    );
    // 预置开场白：只放当前轮到的成员（对齐 ST 群聊的初始问候，不一次性铺满）
    if (_members.isNotEmpty) {
      final first = _members[_speakerIndex % _members.length];
      final g = _greetingOf(first);
      if (g != null) {
        await AiConversationService().insertMessage(
          sessionId: sessionId,
          role: 'model',
          content: '〖角色：${first.displayName}〗$g〖/角色〗',
          taskType: 'group',
        );
      }
    }
    final updated = chat.copyWith(sessionId: sessionId);
    await GroupChatStore.instance.upsert(updated);
    if (!mounted) return;
    setState(() {
      _chat = updated;
      _sessionId = sessionId;
      _messagesStream = AiConversationService().watchMessages(sessionId);
      _booting = false;
    });
    _scrollToBottom(force: true);
  }

  Future<void> _restart() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.storyRestart,
        content: Text(t.groupChatRestartConfirm),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final chat = _chat;
    if (chat == null) return;
    setState(() {
      _booting = true;
      _speakerIndex = 0;
    });
    await _newSession(chat.copyWith(speakerIndex: 0));
    await _send(t.groupChatStart);
  }

  CharacterCard? _memberByName(String? name) {
    final n = name?.trim() ?? '';
    if (n.isEmpty) return null;
    for (final c in _members) {
      if (c.name == n || c.displayName == n) return c;
    }
    for (final c in _members) {
      if (c.name.contains(n) ||
          n.contains(c.name) ||
          c.displayName.contains(n) ||
          n.contains(c.displayName)) {
        return c;
      }
    }
    return _members.length == 1 ? _members.first : null;
  }

  /// 本轮实际发言人：手动指定优先；轮流模式取指针指向的成员；自然模式为空
  String? get _effectiveNext {
    if (_nextSpeaker != null) return _nextSpeaker;
    if (_chat?.order == 'list' && _members.isNotEmpty) {
      return _members[_speakerIndex % _members.length].displayName;
    }
    return null;
  }

  /// 一轮结束后推进轮流指针（手动指定则跳到该成员的下一位）
  Future<void> _advanceSpeaker() async {
    final chat = _chat;
    if (chat == null || _members.isEmpty) return;
    var next = _speakerIndex;
    final manual = _nextSpeaker;
    if (manual != null) {
      final at = _members.indexWhere((c) => c.displayName == manual);
      next = at < 0 ? _speakerIndex : at + 1;
    } else if (chat.order == 'list') {
      next = _speakerIndex + 1;
    } else {
      return;
    }
    next = next % _members.length;
    if (next == _speakerIndex) return;
    setState(() => _speakerIndex = next);
    await GroupChatStore.instance.upsert(chat.copyWith(speakerIndex: next));
    _chat = chat.copyWith(speakerIndex: next);
  }

  Future<void> _send(String text) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    final outgoing = text.trim();
    if (outgoing.isEmpty) return;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    final next = _effectiveNext;
    setState(() {
      _sending = true;
      _streamText = '';
    });
    _scrollToBottom(force: true);
    try {
      await for (final u in AiConversationService().sendMessageStream(
        sessionId: sessionId,
        userMessage: outgoing,
        taskType: 'group',
        useTools: false,
        providerOverride: aiHubProvider(),
        systemPromptOverride: buildGroupSystemPrompt(
          chat: _chat!,
          members: _members,
          nextSpeaker: next,
        ),
        cancelToken: cancelToken,
      )) {
        if (!mounted) return;
        if (u.errorMessage != null) {
          setState(() => _sending = false);
          App.rootContext.showMessage(
            message: u.errorMessage!,
            level: LogLevel.error,
          );
          return;
        }
        setState(() => _streamText = u.text);
        _scrollToBottom();
        if (u.done) break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        App.rootContext.showMessage(message: e.toString(), level: LogLevel.error);
      }
      return;
    } finally {
      _cancelToken = null;
    }
    if (!mounted) return;
    // 推进轮流指针（手动指定则跳到该成员的下一位）
    await _advanceSpeaker();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _streamText = '';
      _nextSpeaker = null;
    });
    _scrollToBottom();
    // 自动模式：继续推进（有次数上限，防止无限循环）
    if (_auto && _autoRemaining > 0 && !cancelToken.isCancelled) {
      _autoRemaining--;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted && !_sending) await _send(t.groupChatContinue);
    }
  }

  void _sendInput() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _autoRemaining = _auto ? 6 : 0;
    _send(text);
  }

  /// 重新生成最后一次回复（保持同一位发言者）
  Future<void> _regenerate() async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    final messages = await AiConversationService()
        .watchMessages(sessionId)
        .first;
    if (messages.isEmpty) return;
    final lastModel = messages.lastWhere(
      (m) => m.role == 'model',
      orElse: () => messages.last,
    );
    if (lastModel.role != 'model') return;
    // 保持同一位发言者：优先取该条现有候选里的说话人
    String? speaker;
    for (final seg in parseGroupSegments(lastModel.outputContent ?? '')) {
      if (seg.$1 != null) {
        speaker = seg.$1;
        break;
      }
    }
    final next = speaker ?? _effectiveNext;
    setState(() => _sending = true);
    final res = await AiConversationService().regenerateMessage(
      sessionId: sessionId,
      taskId: lastModel.id,
      providerOverride: aiHubProvider(),
      systemPromptOverride: buildGroupSystemPrompt(
        chat: _chat!,
        members: _members,
        nextSpeaker: next,
      ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (!res.success) {
      App.rootContext.showMessage(
        message: res.errorMessage ?? '',
        level: LogLevel.error,
      );
    }
    _scrollToBottom(force: true);
  }

  /// 切换某条消息的候选（swipe）
  Future<void> _swipe(AiTask m, List<String> variants, int index) async {
    if (index < 0 || index >= variants.length) return;
    await AiConversationService().selectVariant(m.id, variants, index);
  }

  void _stop() {
    _cancelToken?.cancel();
    _autoRemaining = 0;
    setState(() {
      _sending = false;
      _streamText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    return Scaffold(
      appBar: Appbar(
        title: Text(chat?.name.isEmpty != false ? t.groupChat : chat!.name),
        actions: [
          if (_members.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'regenerate') _regenerate();
                if (v == 'restart') _restart();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'regenerate',
                  child: Text(t.regenerateReply),
                ),
                PopupMenuItem(value: 'restart', child: Text(t.storyRestart)),
              ],
            ),
        ],
      ),
      body: _booting
          ? const Center(child: PolygonRefreshIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messagesStream == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<List<AiTask>>(
                          stream: _messagesStream,
                          builder: (context, snap) {
                            final messages = snap.data ?? const <AiTask>[];
                            int lastModelId = -1;
                            for (final m in messages) {
                              if (m.role == 'model') lastModelId = m.id;
                            }
                            return ListView(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              children: [
                                if (_streamText.trim().isNotEmpty)
                                  ..._renderModel(_streamText, streaming: true),
                                for (final m in messages.reversed)
                                  ..._renderMessage(
                                    m,
                                    isLastModel: m.id == lastModelId,
                                  ),
                              ],
                            );
                          },
                        ),
                ),
                _inputBar(),
              ],
            ),
    );
  }

  List<Widget> _renderMessage(AiTask m, {required bool isLastModel}) {
    if (m.role == 'user') {
      return [_StoryBubble(content: m.inputContent, isUser: true)];
    }
    return [
      ..._renderModel(m.outputContent ?? ''),
      _modelFooter(m, isLastModel: isLastModel),
    ];
  }

  /// 模型消息底栏：多候选 swipe（‹ i/n ›）+ 重新生成
  Widget _modelFooter(AiTask m, {required bool isLastModel}) {
    final variants = AiConversationService.variantsOf(m);
    final idx = m.variantIndex.clamp(
      0,
      variants.isEmpty ? 0 : variants.length - 1,
    );
    final scheme = Theme.of(context).colorScheme;
    Widget action(IconData icon, VoidCallback? onTap) => IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: onTap,
      icon: Icon(icon),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (variants.length > 1) ...[
            action(
              Icons.chevron_left,
              idx > 0 ? () => _swipe(m, variants, idx - 1) : null,
            ),
            Text(
              '${idx + 1}/${variants.length}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            action(
              Icons.chevron_right,
              idx < variants.length - 1
                  ? () => _swipe(m, variants, idx + 1)
                  : null,
            ),
          ],
          if (isLastModel)
            action(
              Icons.replay_outlined,
              _sending ? null : _regenerate,
            ),
        ],
      ),
    );
  }

  /// 展示前清洗：去掉 HTML 注释，替换 {{user}}/{{char}} 等占位符
  String _cleanGroupText(String text, {String? speaker}) {
    var s = text.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    final user = currentUserNickname;
    s = s.replaceAll('{{user}}', user).replaceAll('<user>', user);
    final charName = _memberByName(speaker)?.displayName ?? speaker ?? '';
    if (charName.isNotEmpty) {
      s = s
          .replaceAll('{{char}}', charName)
          .replaceAll('<char>', charName)
          .replaceAll('<bot>', charName);
    }
    return s.trim();
  }

  List<Widget> _renderModel(String text, {bool streaming = false}) {
    final segs = parseGroupSegments(text);
    if (segs.isEmpty) {
      final clean = _cleanGroupText(text);
      if (clean.isEmpty) return const [];
      return [_StoryBubble(content: clean, isUser: false)];
    }
    return [
      for (final seg in segs)
        if (seg.$1 == null)
          if (_cleanGroupText(seg.$2).isNotEmpty)
            _StoryBubble(content: _cleanGroupText(seg.$2), isUser: false)
          else
            const SizedBox.shrink()
        else
          _NpcBubble(
            name: seg.$1!,
            content: _cleanGroupText(seg.$2, speaker: seg.$1),
            avatar: _memberByName(seg.$1)?.avatar ?? '',
          ),
    ];
  }

  Widget _inputBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_members.isNotEmpty && _effectiveNext != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.groupChatTurn(name: _effectiveNext!),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (_members.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                children: [
                  for (final c in _members)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: CharacterAvatar(
                          name: c.displayName,
                          avatar: c.avatar,
                          radius: 10,
                          enablePreview: false,
                        ),
                        label: Text(c.displayName),
                        selected: _effectiveNext == c.displayName,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() {
                          _nextSpeaker = _nextSpeaker == c.displayName
                              ? null
                              : c.displayName;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendInput(),
                    decoration: InputDecoration(
                      hintText: t.groupChatInputHint,
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_sending)
                  IconButton.filled(
                    onPressed: _stop,
                    tooltip: t.stopGenerating,
                    icon: const Icon(Icons.stop),
                  )
                else
                  IconButton.filled(
                    onPressed: _sendInput,
                    tooltip: t.sendMessage,
                    icon: const Icon(Icons.send),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
