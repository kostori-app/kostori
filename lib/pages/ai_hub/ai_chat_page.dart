part of 'ai_hub_page.dart';

/// 聊天内容的可用最大宽度：随窗口变宽而增大，但不超过 1100
double _chatContentMaxWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width * 0.92).clamp(320.0, 1100.0);
}

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, this.initialProfileId, this.fresh = false});

  /// 打开后为新建会话绑定该助手档案
  final String? initialProfileId;

  /// 为 true 时跳过已有会话，直接新建一个空白会话（用于"试聊"）
  final bool fresh;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  static const _kBase64Limit = 512 * 1024; // 512 KB

  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  String _source = 'siliconFlow';
  String? _sessionId;
  String? _profileId;
  bool _isSending = false;
  String? _lastError;
  String? _toolStatus;

  bool _showStreamBubble = false;
  String _streamText = '';
  String _streamReasoning = '';
  List<AiStep> _streamSteps = const [];
  String? _streamModelName;
  CancelToken? _cancelToken;

  /// 是否自动跟随最新消息（用户向上滚动查看历史时置 false）
  bool _isFollowing = true;

  final List<_PendingAiImage> _pendingImages = [];
  bool _isCompressingImage = false;
  bool _isDragging = false;
  List<String> _followUps = const [];

  /// 思考程度：0=简洁 / 1=标准(跟随档案) / 2=深度思考；可临时覆盖，仅影响本次请求
  int _thinkingLevel = 1;

  // 思考时长统计：首次收到推理内容时起表，推理不再增长时冻结。
  // 数据层没有"思考开始"事件，故以首个推理分片到达时刻作为起点。
  DateTime? _reasoningStartedAt;
  DateTime? _reasoningEndedAt;
  Timer? _reasoningTimer;
  int _lastReasoningLen = 0;

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
    _reasoningTimer?.cancel();
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
        _profileId = session?.profileId;
        _followUps = session == null
            ? const []
            : AiConversationService.parseFollowUps(session.followUps);
        _isFollowing = true;
        if (session != null) {
          _source = session.provider;
        }
      });
    }
  }

  Future<void> _loadOrCreateSession() async {
    final store = AssistantProfileStore.instance;
    if (!store.isInitialized) await store.init();
    if (widget.fresh) {
      await _newSession();
      return;
    }
    // 改造点 9：话题按助手隔离——只加载当前选中助手的话题
    final assistantId =
        widget.initialProfileId ?? store.activeId ?? defaultProfile.id;
    final sessions = await AiConversationService()
        .watchSessions(type: 'chat')
        .first;
    final forAssistant = sessions
        .where(
          (s) =>
              s.profileId == assistantId ||
              (s.profileId == null && assistantId == defaultProfile.id),
        )
        .toList();
    if (forAssistant.isNotEmpty) {
      await _switchSession(forAssistant.first.sessionId);
    } else {
      await _newSession();
    }
  }

  /// 新建话题：不选择人格/助手，总是基于当前选中的助手创建并绑定
  Future<void> _newSession() async {
    final store = AssistantProfileStore.instance;
    if (!store.isInitialized) await store.init();
    final assistantId =
        widget.initialProfileId ?? store.activeId ?? defaultProfile.id;

    final id = await AiConversationService().createSession(
      type: 'chat',
      provider: _source,
      title: t.newChatTitle(time: DateTime.now().toString().substring(0, 16)),
      configKey: null,
    );
    await AiConversationService().updateSessionProfile(id, assistantId);
    if (!mounted) return;
    final profile = store.find(assistantId);
    if (profile != null) {
      if (profile.enabledSkillIds.isEmpty) {
        SkillRegistry.instance.enableAll();
      } else {
        SkillRegistry.instance.setEnabled(profile.enabledSkillIds);
      }
    }
    if (mounted) {
      setState(() {
        _sessionId = id;
        _followUps = const [];
        _profileId = assistantId;
      });
    }
  }

  /// 进入某助手的话题：有则切到最近话题，无则新建（改造点 9.4）
  Future<void> _openOrCreateFor(String assistantId) async {
    final sessions = await AiConversationService()
        .watchSessions(type: 'chat')
        .first;
    final forAssistant = sessions
        .where(
          (s) =>
              s.profileId == assistantId ||
              (s.profileId == null && assistantId == defaultProfile.id),
        )
        .toList();
    if (forAssistant.isNotEmpty) {
      await _switchSession(forAssistant.first.sessionId);
    } else {
      await _newSession();
    }
  }

  Future<void> _send({String? overrideMessage, int? rollbackFromId}) async {
    final text = overrideMessage ?? _inputCtrl.text.trim();
    if (_sessionId == null) return;
    if (text.isEmpty && _pendingImages.isEmpty) return;
    if (_isSending) return;
    if (overrideMessage == null) _inputCtrl.clear();

    final isNewSend = overrideMessage == null;
    final images = isNewSend
        ? _pendingImages
              .map(
                (p) => AiImagePart(
                  'data:${p.mime};base64,${base64Encode(p.bytes)}',
                ),
              )
              .toList()
        : const <AiImagePart>[];

    // 图片不直接发送给模型（部分服务商不支持图片，如 DeepSeek 会 400），
    // 由 recognize_anime 技能通过上下文图片识别处理。

    if (rollbackFromId != null) {
      await AiConversationService().rollbackToMessage(
        _sessionId!,
        rollbackFromId,
      );
    }

    setState(() {
      _isSending = true;
      _showStreamBubble = true;
      _toolStatus = null;
      _lastError = null;
      _streamText = '';
      _streamReasoning = '';
      _streamSteps = const [];
      _streamModelName = null;
      _isFollowing = true;
      _reasoningStartedAt = null;
      _reasoningEndedAt = null;
      _lastReasoningLen = 0;
      _reasoningTimer?.cancel();
      _reasoningTimer = null;
      if (isNewSend) _pendingImages.clear();
    });

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    try {
      await for (final u in AiConversationService().sendMessageStream(
        sessionId: _sessionId!,
        userMessage: text,
        images: images.isEmpty ? null : images,
        taskType: 'chat',
        providerOverride: _source,
        cancelToken: cancelToken,
        paramsOverride: _thinkingLevel == 1 ? null : _thinkingParams(),
        onAutoCompressed: () {
          if (mounted) {
            App.rootContext.showMessage(message: t.contextAutoCompressed);
          }
        },
      )) {
        if (!mounted) return;
        if (u.errorMessage != null) {
          setState(() {
            _lastError = u.errorMessage;
            _streamText = u.text;
            _streamReasoning = u.reasoning;
            _toolStatus = null;
            _isSending = false;
          });
          break;
        }
        setState(() {
          _streamText = u.text;
          _streamReasoning = u.reasoning;
          _streamSteps = u.steps;
          _toolStatus = u.toolStatus;
          if (u.modelName != null) _streamModelName = u.modelName;
          if (u.done) {
            _showStreamBubble = false;
            // 修订 1：每次回复完成后都生成联想建议（不限于首轮）
            if (_sessionId != null) _loadFollowUps();
          }
        });
        // 推理内容仍在增长：更新思考起止时刻，并启动秒级刷新计时器
        final reasoningLen = u.reasoning.length;
        if (reasoningLen > _lastReasoningLen) {
          _lastReasoningLen = reasoningLen;
          _reasoningStartedAt ??= DateTime.now();
          _reasoningEndedAt = DateTime.now();
          _reasoningTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
        }
        _scrollToBottom();
      }

      // 流正常结束（可能因取消而提前结束）
      if (mounted) {
        setState(() {
          _isSending = false;
          _toolStatus = null;
          if (cancelToken.isCancelled && _lastError == null) {
            _lastError = t.streamInterrupted;
          }
          if (_lastError == null) {
            _showStreamBubble = false;
            _streamText = '';
            _streamReasoning = '';
            _streamSteps = const [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _toolStatus = null;
          _lastError = cancelToken.isCancelled
              ? t.streamInterrupted
              : e.toString();
        });
      }
    } finally {
      _reasoningTimer?.cancel();
      _reasoningTimer = null;
      _cancelToken = null;
    }
  }

  /// 重新生成：保留旧回复作为候选，追加新候选并选中
  Future<void> _regenerate(AiTask m) async {
    final sessionId = _sessionId;
    if (sessionId == null || _isSending) return;
    setState(() {
      _isSending = true;
      _showStreamBubble = true;
      _lastError = null;
      _streamText = '';
      _streamReasoning = '';
      _streamSteps = const [];
      _streamModelName = null;
    });
    try {
      final res = await AiConversationService().regenerateMessage(
        sessionId: sessionId,
        taskId: m.id,
        providerOverride: _source,
      );
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _showStreamBubble = false;
        if (!res.success) _lastError = res.errorMessage;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _showStreamBubble = false;
          _lastError = e.toString();
        });
      }
    }
  }

  Future<void> _deleteMessage(AiTask m) =>
      AiConversationService().deleteMessage(m.id);

  /// 重试一条未获回复的用户消息（删除后重发，避免重复）
  Future<void> _retryMessage(AiTask m) async {
    if (_isSending) return;
    await AiConversationService().deleteMessage(m.id);
    if (!mounted) return;
    await _send(overrideMessage: m.inputContent);
  }

  Future<void> _selectVariant(AiTask m, List<String> variants, int index) =>
      AiConversationService().selectVariant(m.id, variants, index);

  Future<void> _loadFollowUps() async {
    if (_sessionId == null) return;
    final suggestions = await AiConversationService().suggestFollowUps(
      _sessionId!,
    );
    await AiConversationService().setSessionFollowUps(_sessionId!, suggestions);
    if (mounted) setState(() => _followUps = suggestions);
  }

  /// 流式思考中的实时耗时；推理阶段结束（不再增长）后冻结
  String? get _thinkingElapsed {
    final start = _reasoningStartedAt;
    if (start == null) return null;
    final end = _reasoningEndedAt ?? DateTime.now();
    final ms = end.difference(start).inMilliseconds;
    if (ms < 0) return null;
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  /// 每帧最多调度一次贴底，避免流式期间重复排队动画导致抖动
  bool _scrollScheduled = false;

  /// 跟随模式下的贴底（RikkaHub 思路）：
  /// - 只有「用户在底部」且「用户当前没有在滚动」时才贴底；
  /// - 用户手势/惯性滚动期间绝不抢滚动，滚回底部后自动恢复跟随。
  void _scrollToBottom() {
    if (!_isFollowing || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_isFollowing || !_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      // 正在拖动 / 惯性滚动：交给用户
      if (pos.isScrollingNotifier.value) return;
      if (pos.maxScrollExtent <= 0) return;
      if ((pos.maxScrollExtent - pos.pixels).abs() <= 1) return;
      // 直接跳到最新，不用动画（动画会被高频流式更新打断）
      _scrollCtrl.jumpTo(pos.maxScrollExtent);
    });
  }

  /// 是否已贴近底部（≤ 60px）
  static bool _isNearBottom(ScrollMetrics metrics) =>
      metrics.maxScrollExtent - metrics.pixels <= 60;

  /// 滚动状态机：仅 [UserScrollNotification]（用户手势触发）可取消跟随；
  /// 程序滚动不触发该通知，不会误伤跟随状态。回到底部时恢复跟随。
  bool _onScrollNotification(ScrollNotification notification) {
    // 忽略子级横向列表（候选卡片横向滑动）的滚动通知，
    // 否则卡片滑到最右端会被误判为"贴近底部"而自动滚动到底
    if (notification.metrics.axis == Axis.horizontal) return false;
    // 跟随状态 = 用户是否在底部：上滑离底解除跟随，回到底部恢复
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      final atBottom = _isNearBottom(notification.metrics);
      if (atBottom != _isFollowing) {
        setState(() => _isFollowing = atBottom);
      }
    }
    return false;
  }

  void _jumpToBottom() {
    setState(() => _isFollowing = true);
    _scrollToBottom();
  }

  Widget _buildJumpToBottomButton() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _jumpToBottom,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Text(
                t.jumpToBottom,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 图片 ──────────────────────────────────

  Future<void> _pickImages() async {
    try {
      if (App.isDesktop) {
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty) return;
        for (final f in result.files) {
          final bytes = await f.readAsBytes();
          await _addImage(bytes, f.name);
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickMultiImage(imageQuality: 85);
        for (final f in picked) {
          final bytes = await f.readAsBytes();
          await _addImage(bytes, f.name);
        }
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.failedToPickImage}: $e',
        level: LogLevel.warning,
      );
    }
  }

  /// 读取剪贴板图片并附加到待发送列表（Ctrl+V 粘贴图片）
  Future<void> _pasteImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return;
      await _addImage(bytes, 'pasted.png');
    } catch (_) {}
  }

  /// 输入框快捷键：Ctrl+Enter 发送、Ctrl+V 粘贴图片（桌面端）
  KeyEventResult _composerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !App.isDesktop) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        HardwareKeyboard.instance.isControlPressed) {
      _send();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        HardwareKeyboard.instance.isControlPressed) {
      unawaited(_pasteImage());
    }
    return KeyEventResult.ignored;
  }

  Future<void> _addImage(Uint8List bytes, String fileName) async {
    if (!mounted) return;
    setState(() => _isCompressingImage = true);
    try {
      var toStore = bytes;
      if (toStore.length > _kBase64Limit) {
        final c1 = await hubCompressImage(bytes, maxDim: 1280, quality: 82);
        toStore = c1.length <= _kBase64Limit
            ? c1
            : await hubCompressImage(c1, maxDim: 800, quality: 60);
      }
      if (!mounted) return;
      setState(() {
        _pendingImages.add(
          _PendingAiImage(
            bytes: toStore,
            fileName: fileName,
            mime: _guessMime(fileName),
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _isCompressingImage = false);
    }
  }

  void _removePendingImage(int index) {
    if (index < 0 || index >= _pendingImages.length) return;
    setState(() => _pendingImages.removeAt(index));
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  // ── 拖拽 ──────────────────────────────────

  Future<void> _onDragDone(DropDoneDetails detail) async {
    for (final file in detail.files) {
      final ext = file.path.split('.').last.toLowerCase();
      if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) {
        final bytes = await File(file.path).readAsBytes();
        await _addImage(bytes, file.name);
      }
    }
    if (mounted) setState(() => _isDragging = false);
  }

  // ── 输入区：助手设置 / 思考程度 / "+" 面板 ──

  /// 思考程度标签
  String get _thinkingLevelLabel => switch (_thinkingLevel) {
    0 => t.thinkingLow,
    1 => t.thinkingStandard,
    _ => t.thinkingDeep,
  };

  /// ③ 扩展管理：回复是否启用 Markdown 渲染（默认开启）
  bool get _useMarkdown {
    final profile = AssistantProfileStore.instance.find(_profileId ?? '');
    return profile?.extensionEnabled('markdown') ?? true;
  }

  void _cycleThinkingLevel() {
    setState(() => _thinkingLevel = (_thinkingLevel + 1) % 3);
  }

  /// 按思考程度生成本次请求的参数（覆盖档案默认）
  AiGenerationParams? _thinkingParams() {
    final base = _profileParamsForCurrent();
    switch (_thinkingLevel) {
      case 0:
        return AiGenerationParams(
          temperature: base?.temperature ?? 0.9,
          maxTokens: (base?.maxTokens ?? 2048).clamp(256, 2048),
        );
      case 2:
        return AiGenerationParams(
          temperature: base?.temperature ?? 0.4,
          maxTokens: (base?.maxTokens ?? 4096).clamp(4096, 32768),
        );
      default:
        return base;
    }
  }

  AiGenerationParams? _profileParamsForCurrent() {
    if (_profileId == null) return null;
    final profile = AssistantProfileStore.instance.find(_profileId!);
    final p = profile?.params;
    if (p == null) return null;
    if (p.temperature == null && p.topP == null && p.maxTokens == null) {
      return null;
    }
    return AiGenerationParams(
      temperature: p.temperature,
      topP: p.topP,
      maxTokens: p.maxTokens,
    );
  }

  /// 右上角统一入口：选择助手档案 / 助手设置 / 话题列表
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 日期分组标签：今天 / 昨天 / M月d日
  String _sessionDayLabel(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff <= 0) return t.today;
    if (diff == 1) return t.yesterday;
    return '${dt.month}月${dt.day}日';
  }

  /// 会话侧边栏：用户信息 / 新建·搜索 / 按日期分组的会话列表 / 助手选择
  Widget _buildSideDrawer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // 窄屏占比大一些、宽屏别覆盖太多
    final width = (screenWidth * 0.8).clamp(260.0, 340.0);
    final profile = _profileId == null
        ? null
        : AssistantProfileStore.instance.find(_profileId!);
    final nickname =
        (appdata.settings['userNickname'] as String?)?.trim() ?? '';

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return Drawer(
      width: width,
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // 顶部：头像 + 昵称 + 欢迎回来
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.secondaryContainer,
                    child: Text(
                      nickname.isEmpty
                          ? '·'
                          : nickname.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname.isEmpty ? t.userNickname : nickname,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          t.welcomeBack,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 新建 / 搜索
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(t.newChat),
              onTap: () => closeThen(_newSession),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.search, size: 20),
              title: Text(t.searchChat),
              onTap: () => closeThen(_showSessionDrawer),
            ),
            const Divider(height: 1),
            // 会话列表：按更新日期分组
            Expanded(
              child: StreamBuilder<List<AiSession>>(
                stream: AiConversationService().watchSessions(type: 'chat'),
                builder: (ctx, snap) {
                  final sessions = snap.data ?? const <AiSession>[];
                  if (sessions.isEmpty) {
                    return Center(
                      child: Text(
                        t.noHistoryYet,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  // 已按 updatedAt 倒序：顺序遍历即可天然按日期分组
                  final groups = <String, List<AiSession>>{};
                  for (final s in sessions) {
                    final label = _sessionDayLabel(s.updatedAt);
                    groups.putIfAbsent(label, () => []).add(s);
                  }
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                        child: Row(
                          children: [
                            Text(
                              t.chat,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final s in entry.value)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            selected: s.sessionId == _sessionId,
                            title: Text(
                              s.title.isEmpty ? t.aiConversation : s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () => closeThen(
                              () => _switchSession(s.sessionId),
                            ),
                            onLongPress: () =>
                                _confirmDeleteSession(ctx, s),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // 底部：助手选择 + AI 设置入口
            ListTile(
              dense: true,
              leading: const Icon(Icons.smart_toy_outlined, size: 20),
              title: Text(
                profile?.name ?? t.noPersonality,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.unfold_more, size: 18),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: t.aiSettings,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () =>
                        closeThen(() => context.to(() => const AiSettings())),
                  ),
                ],
              ),
              onTap: () => closeThen(_showAssistantPicker),
            ),
          ],
        ),
      ),
    );
  }

  /// 长按会话：确认删除
  Future<void> _confirmDeleteSession(BuildContext context, AiSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.delete,
        content: Text(s.title.isEmpty ? t.aiConversation : s.title),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AiConversationService().deleteSession(s.sessionId);
    if (_sessionId == s.sessionId) {
      await _loadOrCreateSession();
    }
  }

  Widget _buildThinkingLevelButton() {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: t.thinkingLevel,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _cycleThinkingLevel,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _thinkingLevel == 2
                    ? Icons.psychology
                    : _thinkingLevel == 0
                    ? Icons.bolt_outlined
                    : Icons.psychology_alt_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _thinkingLevelLabel,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 数据驱动渲染的"+"面板：拍照 / 图片 / 上传文件 / 扩展管理 / 压缩历史
  Future<void> _showMoreSheet() async {
    final options = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.photo_camera_outlined,
        label: t.takePhoto,
        onTap: _pickCamera,
      ),
      (
        icon: Icons.photo_library_outlined,
        label: t.pickImages,
        onTap: _pickImages,
      ),
      (
        icon: Icons.upload_file_outlined,
        label: t.uploadFile,
        onTap: _uploadFile,
      ),
      (
        icon: Icons.extension_outlined,
        label: t.extensionManagement,
        onTap: _openExtensionSettings,
      ),
      (
        icon: Icons.compress_outlined,
        label: t.compressHistory,
        onTap: _compressCurrentSession,
      ),
    ];
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => Sheet(
        title: t.more,
        icon: Icons.more_horiz,
        initialSize: 0.4,
        builder: (context, sc) => SingleChildScrollView(
          controller: sc,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final o in options)
                  _MoreActionTile(
                    icon: o.icon,
                    label: o.label,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      o.onTap();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickCamera() async {
    try {
      final picker = ImagePicker();
      final f = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      await _addImage(bytes, f.name);
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.failedToPickImage}: $e',
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result == null || result.files.isEmpty) return;
      for (final f in result.files) {
        final ext = f.name.split('.').last.toLowerCase();
        if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) {
          final bytes = await f.readAsBytes();
          await _addImage(bytes, f.name);
        } else {
          final text = utf8.decode(await f.readAsBytes(), allowMalformed: true);
          if (text.trim().isNotEmpty) {
            await _send(overrideMessage: text.trim());
          }
        }
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.failedToPickImage}: $e',
        level: LogLevel.warning,
      );
    }
  }

  void _openExtensionSettings() {
    App.rootContext.to(() => const ExtensionSettingsPage());
  }

  Future<void> _compressCurrentSession() async {
    if (_sessionId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.compressHistory,
        content: Text(t.compressHistoryConfirm),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await AiConversationService().compressSession(_sessionId!);
    App.rootContext.showMessage(
      message: result.success ? t.compressed : (result.errorMessage ?? 'Error'),
      level: result.success ? LogLevel.info : LogLevel.warning,
    );
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
        assistantId:
            widget.initialProfileId ??
            (AssistantProfileStore.instance.activeId ?? defaultProfile.id),
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
    if (!mounted) return;
    final ctrl = TextEditingController(text: session.title);
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.rename,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: t.conversationTitle,
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
            child: Text(t.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }

  void _onProviderChanged(String provider) {
    setState(() => _source = provider);
    if (_sessionId != null) {
      AiConversationService().updateSessionProvider(_sessionId!, provider);
    }
  }

  Future<void> _showProviderModelSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderModelSheet(
        provider: _source,
        onProviderChanged: _onProviderChanged,
      ),
    );
  }

  Widget _buildModelProviderButton() {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<AiApiKey?>(
      stream: AiDatabase.instance.aiApiKeyDao.watchByProvider(_source),
      builder: (ctx, snap) {
        final model = snap.data?.model;
        final meta = OpenAiProviderRegistry.allProviders[_source];
        final label = model ?? meta?.name ?? _source;
        return Tooltip(
          message: t.selectModel,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _showProviderModelSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              constraints: const BoxConstraints(maxWidth: 160),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _switchProfile(String? id) async {
    final store = AssistantProfileStore.instance;
    if (!store.isInitialized) await store.init();
    final assistantId = (id == null || id.isEmpty) ? defaultProfile.id : id;
    final profile = store.find(assistantId);
    if (profile == null) return;
    await store.switchTo(assistantId);
    // 应用本地工具（⑦）
    if (profile.enabledSkillIds.isEmpty) {
      SkillRegistry.instance.enableAll();
    } else {
      SkillRegistry.instance.setEnabled(profile.enabledSkillIds);
    }
    if (!mounted) return;
    // 切换助手 → 进入该助手的话题（改造点 9.4）
    await _openOrCreateFor(assistantId);
    if (!mounted) return;
    App.rootContext.showMessage(
      message: t.switchedToProfile(name: profile.name),
    );
  }

  /// 右上角选择助手：改为 BottomSheet 选择
  Future<void> _showAssistantPicker() async {
    final store = AssistantProfileStore.instance;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Sheet(
        title: t.selectAssistantProfile,
        icon: Icons.badge_outlined,
        initialSize: 0.55,
        builder: (sheetCtx, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            for (final p in store.profiles)
              ListTile(
                leading: Text(p.icon, style: const TextStyle(fontSize: 22)),
                title: Text(p.name),
                subtitle: p.persona.trim().isEmpty
                    ? null
                    : Text(
                        p.persona,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                trailing: Icon(
                  p.id == (_profileId ?? '')
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: p.id == (_profileId ?? '')
                      ? Theme.of(sheetCtx).colorScheme.primary
                      : null,
                ),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _switchProfile(selected);
  }

  Widget _buildOptionsIcon(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSideDrawer(context),
      drawerEnableOpenDragGesture: true,
      appBar: Appbar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BackButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            IconButton(
              tooltip: t.more,
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ],
        ),
        title: _sessionId == null
            ? Text(t.aiConversation)
            : StreamBuilder<List<AiSession>>(
                stream: AiConversationService().watchSessions(type: 'chat'),
                builder: (ctx, snap) {
                  final sessions = snap.data ?? const <AiSession>[];
                  final session = sessions.isEmpty
                      ? null
                      : sessions.firstWhere(
                          (s) => s.sessionId == _sessionId,
                          orElse: () => sessions.first,
                        );
                  return GestureDetector(
                    onTap: _renameCurrentSession,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            session?.title ?? t.aiConversation,
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
            tooltip: t.newConversation,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newSession,
          ),
        ],
      ),
      body: DropTarget(
        onDragDone: _onDragDone,
        onDragEntered: (_) {
          if (mounted) setState(() => _isDragging = true);
        },
        onDragExited: (_) {
          if (mounted) setState(() => _isDragging = false);
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _sessionId == null
                      ? const Center(child: PolygonRefreshIndicator())
                      : StreamBuilder<List<AiTask>>(
                          stream: AiConversationService().watchMessages(
                            _sessionId!,
                          ),
                          builder: (ctx, snapshot) {
                            final messages = snapshot.data ?? [];
                            if (messages.isEmpty && !_showStreamBubble) {
                              return _EmptyChatState(
                                onSuggestionTap: (text) =>
                                    _send(overrideMessage: text),
                              );
                            }
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _scrollToBottom(),
                            );
                            return Center(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: _onScrollNotification,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: _chatContentMaxWidth(context),
                                  ),
                                  child: Stack(
                                    children: [
                                      ScrollConfiguration(
                                        behavior: ScrollConfiguration.of(
                                          context,
                                        ).copyWith(scrollbars: false),
                                        child: ListView.builder(
                                          controller: _scrollCtrl,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          itemCount:
                                              messages.length +
                                              (_showStreamBubble ? 1 : 0),
                                          itemBuilder: (_, i) {
                                            if (i == messages.length) {
                                              return _StreamingBubble(
                                                text: _streamText,
                                                reasoning: _streamReasoning,
                                                steps: _streamSteps,
                                                errorText: _lastError,
                                                modelName: _streamModelName,
                                                thinkingElapsed:
                                                    _thinkingElapsed,
                                                useMarkdown: _useMarkdown,
                                              );
                                            }
                                            final m = messages[i];
                                            final isUser = m.role == 'user';
                                            final isLast =
                                                i == messages.length - 1;
                                            final showError =
                                                !_showStreamBubble &&
                                                isLast &&
                                                !isUser &&
                                                _lastError != null;

                                            final variants = isUser
                                                ? const <String>[]
                                                : AiConversationService.variantsOf(
                                                    m,
                                                  );
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                _ChatBubble(
                                                  content: isUser
                                                      ? m.inputContent
                                                      : (m.outputContent ??
                                                            '...'),
                                                  isUser: isUser,
                                                  task: m,
                                                  useMarkdown: _useMarkdown,
                                                  defaultExpandedToolLog:
                                                      !isUser &&
                                                      isLast &&
                                                      !_showStreamBubble,
                                                  errorText: showError
                                                      ? _lastError
                                                      : null,
                                                  onRetry: showError
                                                      ? () => _send(
                                                          overrideMessage:
                                                              m.inputContent,
                                                        )
                                                      : null,
                                                  onRollback: () {
                                                    _send(
                                                      overrideMessage:
                                                          m.inputContent,
                                                      rollbackFromId: m.id,
                                                    );
                                                  },
                                                  onRegenerate: isUser
                                                      ? null
                                                      : () => _regenerate(m),
                                                  onEdit: (newText) {
                                                    _send(
                                                      overrideMessage: newText,
                                                      rollbackFromId: m.id,
                                                    );
                                                  },
                                                  onDelete: () =>
                                                      _deleteMessage(m),
                                                ),
                                                if (variants.length > 1)
                                                  _VariantNav(
                                                    index: m.variantIndex.clamp(
                                                      0,
                                                      variants.length - 1,
                                                    ),
                                                    total: variants.length,
                                                    onSelect: (v) =>
                                                        _selectVariant(
                                                          m,
                                                          variants,
                                                          v,
                                                        ),
                                                  ),
                                                // 该轮无回复（失败/中断，含重进页面后）→ 重试
                                                if (isLast &&
                                                    isUser &&
                                                    !_isSending &&
                                                    !_showStreamBubble)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 4,
                                                          bottom: 6,
                                                        ),
                                                    child: Align(
                                                      alignment: Alignment
                                                          .centerRight,
                                                      child: TextButton.icon(
                                                        onPressed: () =>
                                                            _retryMessage(m),
                                                        icon: const Icon(
                                                          Icons.refresh,
                                                          size: 16,
                                                        ),
                                                        label: Text(t.retry),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      // 回到底部悬浮按钮（非跟随状态下显示）
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: IgnorePointer(
                                          ignoring: _isFollowing,
                                          child: AnimatedOpacity(
                                            opacity: _isFollowing ? 0 : 1,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            curve: Curves.easeOut,
                                            child: AnimatedSlide(
                                              offset: _isFollowing
                                                  ? const Offset(0, 0.4)
                                                  : Offset.zero,
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              curve: Curves.easeOut,
                                              child: _buildJumpToBottomButton(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // ── 发送状态提示 ────────────────────────
                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: PolygonRefreshIndicator(),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _toolStatus != null
                                ? t.toolCallingTool(tool: _toolStatus!)
                                : (_streamReasoning.isNotEmpty &&
                                          _streamText.isEmpty
                                      ? t.thinking
                                      : t.generatingReply),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── 后续引导建议 ────────────────────────
                if (_followUps.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                    child: SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _followUps.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _FollowUpChip(
                          text: _followUps[i],
                          onTap: () => _send(overrideMessage: _followUps[i]),
                        ),
                      ),
                    ),
                  ),

                // ── 输入框（与群聊 / AI 共创共用 ChatComposer）──
                ChatComposer(
                  controller: _inputCtrl,
                  focusNode: _focusNode,
                  hintText: t.inputMessage,
                  sending: _isSending,
                  onSend: _send,
                  onStop: () => _cancelToken?.cancel(),
                  onKeyEvent: _composerKey,
                  top: (_pendingImages.isNotEmpty || _isCompressingImage)
                      ? SizedBox(
                          height: 64,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            itemCount:
                                _pendingImages.length +
                                (_isCompressingImage ? 1 : 0),
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              if (_isCompressingImage &&
                                  i == _pendingImages.length) {
                                return _ImageCompressingTile();
                              }
                              final img = _pendingImages[i];
                              return _PendingImageTile(
                                image: img,
                                onRemove: () => _removePendingImage(i),
                              );
                            },
                          ),
                        )
                      : null,
                  leading: [
                    _buildThinkingLevelButton(),
                    const SizedBox(width: 6),
                    _buildModelProviderButton(),
                  ],
                  trailing: [
                    _buildOptionsIcon(
                      context,
                      icon: Icons.add,
                      tooltip: t.more,
                      onTap: _showMoreSheet,
                    ),
                  ],
                ),
              ],
            ),
            if (_isDragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 12),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(t.dropToSendImage),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "+" 面板中的操作项
class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.toOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              // 允许两行，避免"扩展管理设置"被截断成"扩展管理…"
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingAiImage {
  final Uint8List bytes;
  final String fileName;
  final String mime;

  const _PendingAiImage({
    required this.bytes,
    required this.fileName,
    required this.mime,
  });
}

class _PendingImageTile extends StatelessWidget {
  const _PendingImageTile({required this.image, required this.onRemove});

  final _PendingAiImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            image.bytes,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 56,
              height: 56,
              color: scheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined, size: 24),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 12, color: scheme.onPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageCompressingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: t.compressingImage,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: PolygonRefreshIndicator(),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final starters = [t.chatStart1, t.chatStart2, t.chatStart3, t.chatStart4];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 40, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              t.chatGreeting,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _chatContentMaxWidth(context),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final s in starters)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => onSuggestionTap(s),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpChip extends StatelessWidget {
  const _FollowUpChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide(color: scheme.outlineVariant, width: 0.6),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: onTap,
    );
  }
}

class _ChatSessionSheet extends StatelessWidget {
  const _ChatSessionSheet({
    required this.currentSessionId,
    required this.assistantId,
    required this.onSelectSession,
    required this.onNewSession,
    required this.onDeleteSession,
  });

  final String? currentSessionId;
  final String assistantId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewSession;
  final ValueChanged<String> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return Sheet(
      title: t.topicList,
      icon: Icons.forum_outlined,
      initialSize: 0.6,
      headerTrailing: FilledButton.tonal(
        onPressed: onNewSession,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16),
            const SizedBox(width: 4),
            Text(t.newConversation),
          ],
        ),
      ),
      builder: (context, sc) => StreamBuilder<List<AiSession>>(
        stream: AiConversationService().watchSessions(type: 'chat'),
        builder: (ctx, snapshot) {
          // 改造点 9：只显示当前助手的话题（旧会话 profileId 为空归属默认助手）
          final sessions = (snapshot.data ?? [])
              .where(
                (s) =>
                    s.profileId == assistantId ||
                    (s.profileId == null && assistantId == defaultProfile.id),
              )
              .toList();
          if (sessions.isEmpty) {
            return Center(child: Text(t.noTopicsYet));
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

class ProviderModelSheet extends StatefulWidget {
  const ProviderModelSheet({
    super.key,
    required this.provider,
    required this.onProviderChanged,
    this.currentModel,
    this.onModelSelected,
  });

  final String provider;
  final ValueChanged<String> onProviderChanged;

  /// 自定义当前模型（为空则用该服务商已保存的模型）
  final String? currentModel;

  /// 自定义模型选择回调（为空则写回该服务商的聊天模型）
  final ValueChanged<String>? onModelSelected;

  @override
  State<ProviderModelSheet> createState() => _ProviderModelSheetState();
}

class _ProviderModelSheetState extends State<ProviderModelSheet> {
  late String _provider = widget.provider;

  @override
  Widget build(BuildContext context) {
    final providers = OpenAiProviderRegistry.allProviders.entries.toList();
    final currentMeta = providers.firstWhere(
      (e) => e.key == _provider,
      orElse: () => providers.first,
    );

    return Sheet(
      title: '${t.model} · ${currentMeta.value.name}',
      icon: Icons.model_training,
      initialSize: 0.72,
      builder: (context, _) => Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: providers.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final e = providers[i];
                final selected = e.key == _provider;
                return ChoiceChip(
                  avatar: Icon(
                    e.value.isCustom
                        ? Icons.extension_outlined
                        : Icons.cloud_outlined,
                    size: 16,
                  ),
                  label: Text(e.value.name),
                  selected: selected,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    if (selected) return;
                    setState(() => _provider = e.key);
                    widget.onProviderChanged(e.key);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ProviderModelList(
              provider: _provider,
              currentModel: widget.currentModel,
              onModelSelected: widget.onModelSelected,
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderModelList extends StatefulWidget {
  const ProviderModelList({
    super.key,
    required this.provider,
    this.currentModel,
    this.onModelSelected,
  });

  final String provider;

  /// 自定义当前模型（为空则用该服务商已保存的模型）
  final String? currentModel;

  /// 自定义模型选择回调（为空则写回该服务商的聊天模型）
  final ValueChanged<String>? onModelSelected;

  @override
  State<ProviderModelList> createState() => _ProviderModelListState();
}

class _ProviderModelListState extends State<ProviderModelList> {
  /// 当前类型筛选（null = 全部）
  String? _typeFilter;

  /// 已折叠的基名分组
  final Set<String> _collapsed = {};

  /// 本地选中态：点击后立即高亮，避免等待 DB/回调刷新
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<AiApiKey?>(
      stream: AiDatabase.instance.aiApiKeyDao.watchByProvider(widget.provider),
      builder: (ctx, keySnap) {
        final currentModel =
            _selected ??
            (widget.onModelSelected != null
                ? widget.currentModel
                : keySnap.data?.model);
        return StreamBuilder<List<AiModel>>(
          stream: (AiDatabase.instance.select(
            AiDatabase.instance.aiModels,
          )..where((t) => t.provider.equals(widget.provider))).watch(),
          builder: (ctx, modelSnap) {
            final models = modelSnap.data ?? [];
            if (models.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    t.noModelsAddOneAbove,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: _buildRows(scheme, models, currentModel),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildRows(
    ColorScheme scheme,
    List<AiModel> models,
    String? currentModel,
  ) {
    // ── 类型筛选 chips ─────────────────────────
    final types = <String>[];
    for (final m in models) {
      final t = m.modelType.isEmpty ? 'chat' : m.modelType;
      if (!types.contains(t)) types.add(t);
    }
    final filterRow = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(t.all),
              selected: _typeFilter == null,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => setState(() => _typeFilter = null),
            ),
            const SizedBox(width: 6),
            for (final type in types) ...[
              ChoiceChip(
                label: Text(modelTypeLabel(type)),
                selected: _typeFilter == type,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(
                  () => _typeFilter = _typeFilter == type ? null : type,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );

    // ── 按基名分组 ─────────────────────────────
    final filtered = _typeFilter == null
        ? models
        : models
              .where(
                (m) =>
                    (m.modelType.isEmpty ? 'chat' : m.modelType) == _typeFilter,
              )
              .toList();
    final groups = <String, List<AiModel>>{};
    for (final m in filtered) {
      groups.putIfAbsent(baseModelName(m.modelId), () => []).add(m);
    }
    final bases = groups.keys.toList()..sort();

    return [
      filterRow,
      for (final base in bases) ...[
        _groupHeader(base, groups[base]!),
        if (!_collapsed.contains(base))
          for (final m in groups[base]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AiModelCard(
                model: m,
                isSelected: m.modelId == currentModel,
                onTap: () {
                  if (m.modelId == currentModel) {
                    Navigator.pop(context);
                    return;
                  }
                  setState(() => _selected = m.modelId);
                  final onModelSelected = widget.onModelSelected;
                  if (onModelSelected != null) {
                    onModelSelected(m.modelId);
                  } else {
                    AiDatabase.instance.aiApiKeyDao.updateModel(
                      widget.provider,
                      m.modelId,
                    );
                  }
                  Navigator.pop(context);
                },
              ),
            ),
      ],
    ];
  }

  Widget _groupHeader(String base, List<AiModel> group) {
    final scheme = Theme.of(context).colorScheme;
    final collapsed = _collapsed.contains(base);
    return InkWell(
      onTap: () => setState(() {
        if (collapsed) {
          _collapsed.remove(base);
        } else {
          _collapsed.add(base);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                base,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${group.length}',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 消息顶部行：模型名 + 思考状态标签（位于 "查看思考" / 思考区正上方）
/// 格式化消息时间为 HH:mm
String _fmtTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  final s = t.second.toString().padLeft(2, '0');
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} $h:$m:$s';
}

class _TranslationResultSheet extends StatefulWidget {
  const _TranslationResultSheet({required this.source});

  final String source;

  @override
  State<_TranslationResultSheet> createState() =>
      _TranslationResultSheetState();
}

class _TranslationResultSheetState extends State<_TranslationResultSheet> {
  String? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final res = await TranslationService().translate(widget.source);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = res.success ? res.data : null;
    });
    if (!res.success) {
      App.rootContext.showMessage(
        message: '${t.translationFailed}: ${res.errorMessage}',
        level: LogLevel.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Sheet(
      title: '${t.translate} · ${TranslationService.getPoweredName()}',
      icon: Icons.translate,
      initialSize: 0.6,
      builder: (context, _) {
        if (_loading) {
          return const Center(child: PolygonRefreshIndicator());
        }
        final result = _result;
        if (result == null || result.isEmpty) {
          return Center(
            child: Text(
              t.translationFailed,
              style: TextStyle(color: scheme.error),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SelectableText(
            result,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        );
      },
    );
  }
}

/// 多候选切换（swipe）导航
class _VariantNav extends StatelessWidget {
  const _VariantNav({
    required this.index,
    required this.total,
    required this.onSelect,
  });

  final int index;
  final int total;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: t.back,
            onPressed: index <= 0 ? null : () => onSelect(index - 1),
          ),
          Text('${index + 1}/$total', style: const TextStyle(fontSize: 11)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: t.next,
            onPressed: index >= total - 1 ? null : () => onSelect(index + 1),
          ),
        ],
      ),
    );
  }
}
