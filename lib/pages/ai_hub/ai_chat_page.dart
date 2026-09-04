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

  /// 跟随模式下的平滑滚动到底；非跟随（用户正在看历史）时忽略。
  void _scrollToBottom() {
    if (!_isFollowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      final pos = _scrollCtrl.position;
      if (pos.maxScrollExtent <= 0) return;
      _scrollCtrl.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse &&
          !_isNearBottom(notification.metrics) &&
          _isFollowing) {
        setState(() => _isFollowing = false);
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_isNearBottom(notification.metrics) && !_isFollowing) {
        setState(() => _isFollowing = true);
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
  Widget _buildTopRightButton() {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: t.more,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _showTopRightSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.more_horiz,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _showTopRightSheet() async {
    final profile = _profileId == null
        ? null
        : AssistantProfileStore.instance.find(_profileId!);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Sheet(
        title: t.aiChat,
        icon: Icons.more_horiz,
        initialSize: 0.4,
        builder: (sheetCtx, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(t.selectAssistantProfile),
              subtitle: Text(
                profile?.name ?? t.noPersonality,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAssistantPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(t.assistantSettings),
              onTap: () {
                Navigator.pop(ctx);
                showAssistantProfileEditor(profile: profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(t.topicList),
              onTap: () {
                Navigator.pop(ctx);
                _showSessionDrawer();
              },
            ),
          ],
        ),
      ),
    );
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
      appBar: Appbar(
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
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(child: _buildTopRightButton()),
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

                                            return _ChatBubble(
                                              content: isUser
                                                  ? m.inputContent
                                                  : (m.outputContent ?? '...'),
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
                                              onEdit: (newText) {
                                                _send(
                                                  overrideMessage: newText,
                                                  rollbackFromId: m.id,
                                                );
                                              },
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

                // ── 输入框 ────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_pendingImages.isNotEmpty || _isCompressingImage)
                        SizedBox(
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
                        ),
                      // 输入行：文本框（图片/文件等入口移入右下"+"面板）
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Focus(
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent ||
                                      !App.isDesktop) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event.logicalKey ==
                                      LogicalKeyboardKey.enter) {
                                    if (HardwareKeyboard
                                        .instance
                                        .isControlPressed) {
                                      _send();
                                      return KeyEventResult.handled;
                                    }
                                  }
                                  // 支持粘贴剪贴板图片（Ctrl+V）
                                  if (event.logicalKey ==
                                          LogicalKeyboardKey.keyV &&
                                      HardwareKeyboard
                                          .instance
                                          .isControlPressed) {
                                    unawaited(_pasteImage());
                                  }
                                  return KeyEventResult.ignored;
                                },
                                child: TextField(
                                  controller: _inputCtrl,
                                  focusNode: _focusNode,
                                  autofocus: false,
                                  maxLines: 4,
                                  minLines: 1,
                                  textInputAction: TextInputAction.newline,
                                  decoration: InputDecoration(
                                    hintText: t.inputMessage,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 选项行：思考程度 + 模型 + 新对话 + "+" + 发送（右下）
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                        child: Row(
                          children: [
                            _buildThinkingLevelButton(),
                            const SizedBox(width: 6),
                            _buildModelProviderButton(),
                            const SizedBox(width: 6),
                            _buildOptionsIcon(
                              context,
                              icon: Icons.add_comment_outlined,
                              tooltip: t.newConversation,
                              onTap: _newSession,
                            ),
                            const Spacer(),
                            _buildOptionsIcon(
                              context,
                              icon: Icons.add,
                              tooltip: t.more,
                              onTap: _showMoreSheet,
                            ),
                            const SizedBox(width: 4),
                            _isSending
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.stop_rounded,
                                      size: 20,
                                    ),
                                    tooltip: t.stopGenerating,
                                    onPressed: () => _cancelToken?.cancel(),
                                  )
                                : IconButton.filled(
                                    icon: const Icon(
                                      Icons.arrow_upward,
                                      size: 20,
                                    ),
                                    tooltip: t.sendMessage,
                                    onPressed: _send,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
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
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              maxLines: 1,
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
  });

  final String provider;
  final ValueChanged<String> onProviderChanged;

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
          Expanded(child: ProviderModelList(provider: _provider)),
        ],
      ),
    );
  }
}

class ProviderModelList extends StatefulWidget {
  const ProviderModelList({super.key, required this.provider});

  final String provider;

  @override
  State<ProviderModelList> createState() => _ProviderModelListState();
}

class _ProviderModelListState extends State<ProviderModelList> {
  /// 当前类型筛选（null = 全部）
  String? _typeFilter;

  /// 已折叠的基名分组
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<AiApiKey?>(
      stream: AiDatabase.instance.aiApiKeyDao.watchByProvider(widget.provider),
      builder: (ctx, keySnap) {
        final currentModel = keySnap.data?.model;
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
                  if (m.modelId != currentModel) {
                    AiDatabase.instance.aiApiKeyDao.updateModel(
                      widget.provider,
                      m.modelId,
                    );
                  }
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

/// 消息头部：头像 + 名称 + 时间（AI/用户镜像对称）
class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.name,
    required this.time,
    required this.isUser,
    this.isThinking = false,
    this.thinkingElapsed,
  });

  final String name;
  final String time;
  final bool isUser;
  final bool isThinking;
  final String? thinkingElapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: isUser
          ? scheme.tertiaryContainer
          : scheme.primaryContainer,
      child: Icon(
        isUser ? Icons.person_outline : Icons.auto_awesome,
        size: 14,
        color: isUser ? scheme.onTertiaryContainer : scheme.primary,
      ),
    );

    final nameLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ),
        if (isThinking) ...[
          const SizedBox(width: 6),
          const SizedBox(
            width: 10,
            height: 10,
            child: PolygonRefreshIndicator(),
          ),
          if (thinkingElapsed != null) ...[
            const SizedBox(width: 4),
            Text(
              thinkingElapsed!,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        nameLine,
        Text(time, style: TextStyle(fontSize: 11, color: scheme.outline)),
      ],
    );

    // 镜像对称：AI = [头像][名称/时间] 靠左；用户 = [名称/时间][头像] 靠右
    final row = isUser
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [info, const SizedBox(width: 8), avatar],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [avatar, const SizedBox(width: 8), info],
          );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: row,
    );
  }
}

class _StepProcessArea extends StatefulWidget {
  const _StepProcessArea({required this.steps, required this.isStreaming});

  final List<AiStep> steps;

  /// 流式中：过程区自动展开、进行中的步骤实时展开
  final bool isStreaming;

  @override
  State<_StepProcessArea> createState() => _StepProcessAreaState();
}

class _StepProcessAreaState extends State<_StepProcessArea> {
  bool _areaExpanded = false;
  List<bool> _cardExpanded = [];
  final Map<int, AiStepStatus> _prevStatuses = {};

  @override
  void initState() {
    super.initState();
    _areaExpanded = widget.isStreaming;
    _cardExpanded = List.generate(widget.steps.length, (_) => false);
    for (var i = 0; i < widget.steps.length; i++) {
      _prevStatuses[i] = widget.steps[i].status;
    }
  }

  @override
  void didUpdateWidget(_StepProcessArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steps.length != widget.steps.length) {
      _cardExpanded = List.generate(widget.steps.length, (i) {
        return _cardExpanded.length > i && _cardExpanded[i];
      });
    }
    if (widget.isStreaming) {
      _areaExpanded = true;
      for (var i = 0; i < widget.steps.length; i++) {
        final prev = _prevStatuses[i];
        final cur = widget.steps[i].status;
        if (cur == AiStepStatus.running) {
          // 进行中的步骤保持展开实时更新
          _cardExpanded[i] = true;
        } else if (prev == AiStepStatus.running &&
            cur != AiStepStatus.running) {
          // 完成后自动收起
          _cardExpanded[i] = false;
        }
        _prevStatuses[i] = cur;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    if (steps.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final running = steps.any((s) => s.status == AiStepStatus.running);

    // 全部步骤完成：整体折叠为一行（点击展开）
    if (!_areaExpanded) {
      return InkWell(
        onTap: () => setState(() => _areaExpanded = true),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hub_outlined, size: 13),
              const SizedBox(width: 4),
              Text(
                '${t.viewProcess} ▾${t.aiStepsSuffix(n: steps.length)}',
                style: TextStyle(fontSize: 11, color: scheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _areaExpanded = false),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (running)
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: PolygonRefreshIndicator(),
                  )
                else
                  const Icon(Icons.hub_outlined, size: 13),
                const SizedBox(width: 4),
                Text(
                  '${t.viewProcess} ▴${t.aiStepsSuffix(n: steps.length)}',
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < steps.length; i++) ...[
          _StepCard(
            step: steps[i],
            expanded: _cardExpanded[i],
            autoExpand:
                widget.isStreaming && steps[i].status == AiStepStatus.running,
            onToggle: () =>
                setState(() => _cardExpanded[i] = !_cardExpanded[i]),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

/// 单个步骤卡片：独立可展开
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.expanded,
    required this.autoExpand,
    required this.onToggle,
  });

  final AiStep step;
  final bool expanded;
  final bool autoExpand;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isThinking = step.type == AiStepType.thinking;
    final isError = step.status == AiStepStatus.error;
    final isRunning = step.status == AiStepStatus.running;
    final icon = isThinking ? Icons.psychology : Icons.handyman;
    final iconColor = isThinking
        ? const Color(0xFF4C8BF5)
        : const Color(0xFFFF8F00);
    final typeLabel = isThinking ? t.stepThinking : t.stepTool;

    final bg = isError
        ? scheme.errorContainer.withValues(alpha: 0.45)
        : isThinking
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : scheme.tertiaryContainer.withValues(alpha: 0.45);
    final borderColor = isError
        ? scheme.error.withValues(alpha: 0.5)
        : isThinking
        ? scheme.primary.withValues(alpha: 0.35)
        : scheme.tertiary.withValues(alpha: 0.35);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor, width: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    '$typeLabel · ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isRunning)
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: PolygonRefreshIndicator(),
                    )
                  else if (isError)
                    Icon(Icons.error_outline, size: 13, color: scheme.error)
                  else
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: _StepContent(step: step),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// 步骤展开内容：思考正文 / 工具名+参数+结果
class _StepContent extends StatelessWidget {
  const _StepContent({required this.step});

  final AiStep step;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (step.type == AiStepType.thinking) {
      return SelectableText(
        step.content.isEmpty ? t.thinkingInProgress : step.content,
        style: const TextStyle(fontSize: 12, height: 1.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (step.toolName != null)
          Text(
            '${t.stepTool}：${step.toolName}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        if (step.args != null && step.args!.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(step.args),
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (step.result != null && step.result!.isNotEmpty) ...[
          const SizedBox(height: 4),
          SelectableText(
            step.result!,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReasoningToggle extends StatefulWidget {
  const _ReasoningToggle({required this.reasoning, this.durationMs});

  final String reasoning;

  /// 已完成消息的思考总耗时（毫秒），展示在 "查看思考 ▾" 旁
  final int? durationMs;

  @override
  State<_ReasoningToggle> createState() => _ReasoningToggleState();
}

class _ReasoningToggleState extends State<_ReasoningToggle> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String toggleLabel;
    if ((widget.durationMs ?? 0) > 0) {
      toggleLabel =
          '${t.showThinking} ${(widget.durationMs! / 1000).toStringAsFixed(1)}s';
    } else {
      toggleLabel = t.showThinking;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology, size: 13, color: scheme.outline),
                const SizedBox(width: 4),
                Text(
                  toggleLabel,
                  style: TextStyle(fontSize: 11, color: scheme.outline),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: scheme.outline,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.reasoning,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// 流式生成中的幽灵气泡
/// 工具调用日志：折叠式展示一次回复调用的工具列表。
/// 旧消息（无步骤数据）的兼容工具日志区：落库后默认折叠，仅最后一条展开。
class _ToolLogSection extends StatefulWidget {
  const _ToolLogSection({required this.tools, this.defaultExpanded = false});

  final List<String> tools;
  final bool defaultExpanded;

  @override
  State<_ToolLogSection> createState() => _ToolLogSectionState();
}

class _ToolLogSectionState extends State<_ToolLogSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tools = widget.tools;
    final subtitle = t.toolCallLog(count: tools.length);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.handyman,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded && tools.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2),
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  for (final name in tools)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({
    required this.text,
    required this.reasoning,
    this.steps = const [],
    this.errorText,
    this.modelName,
    this.thinkingElapsed,
    this.useMarkdown = true,
  });

  final String text;
  final String reasoning;
  final List<AiStep> steps;
  final String? errorText;
  final String? modelName;
  final String? thinkingElapsed;
  final bool useMarkdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasReasoning = reasoning.trim().isNotEmpty;
    final hasText = text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MessageHeader(
            name: modelName?.isNotEmpty == true ? modelName! : t.aiLabel,
            time: _fmtTime(DateTime.now()),
            isUser: false,
            isThinking: hasReasoning || steps.isNotEmpty,
            thinkingElapsed: thinkingElapsed,
          ),
          const SizedBox(height: 6),
          if (hasReasoning || steps.isNotEmpty)
            _StepProcessArea(steps: steps, isStreaming: true),
          if (hasText)
            useMarkdown
                ? CustomMarkdownWidget(data: text, indentFirstLine: false)
                : SelectableText(text),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.content,
    required this.isUser,
    required this.task,
    this.defaultExpandedToolLog = false,
    this.onRetry,
    this.onRollback,
    this.onEdit,
    this.errorText,
    this.useMarkdown = true,
  });

  final String content;
  final bool isUser;
  final AiTask task;
  final bool defaultExpandedToolLog;
  final VoidCallback? onRetry;
  final VoidCallback? onRollback;
  final ValueChanged<String>? onEdit;
  final String? errorText;
  final bool useMarkdown;

  Map<String, dynamic>? get _thoughtMap {
    final thought = task.thought;
    if (thought == null || thought.isEmpty) return null;
    try {
      final decoded = jsonDecode(thought);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// usage 字段；兼容旧格式（thought 直接存放 usage JSON）
  Map<String, dynamic>? get _usageMap {
    final map = _thoughtMap;
    if (map == null) return null;
    final usage = map['usage'];
    if (usage is Map<String, dynamic>) return usage;
    return map;
  }

  String? get _reasoningText {
    final map = _thoughtMap;
    if (map == null) return null;
    final r = map['reasoning'];
    if (r is String && r.isNotEmpty) return r;
    return null;
  }

  int? get _promptTokens {
    final u = _usageMap;
    if (u == null) return null;
    return (u['prompt'] as num?)?.toInt();
  }

  int? get _completionTokens {
    final u = _usageMap;
    if (u == null) return null;
    return (u['completion'] as num?)?.toInt();
  }

  int? get _cachedTokens {
    final u = _usageMap;
    if (u == null) return null;
    return (u['cached'] as num?)?.toInt();
  }

  /// 生成耗时（毫秒），由服务端落库时写入 thought.durationMs
  int? get _durationMs {
    final map = _thoughtMap;
    if (map == null) return null;
    return (map['durationMs'] as num?)?.toInt();
  }

  /// 思考阶段耗时（毫秒），由服务端在推理阶段记录；兼容旧消息回退到总耗时
  int? get _thinkingMs {
    final map = _thoughtMap;
    if (map == null) return null;
    return (map['thinkingMs'] as num?)?.toInt();
  }

  /// 本回复调用的工具名列表（由服务端在执行时写入 thought.toolCalls）
  List<String> get _toolCalls {
    final map = _thoughtMap;
    if (map == null) return const [];
    final calls = map['toolCalls'];
    if (calls is List) {
      return calls.whereType<String>().toList();
    }
    return const [];
  }

  /// 步骤列表（新格式：thinking/tool_call 按顺序独立成块）
  List<AiStep> get _savedSteps {
    final map = _thoughtMap;
    if (map == null) return const [];
    final steps = map['steps'];
    if (steps is List) {
      return [
        for (final s in steps)
          if (s is Map) AiStep.fromJson(s.cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  /// 用户消息图片解码缓存：流式回复期间消息列表高频重建，
  /// 若每次 build 都 base64Decode 会产生新的 Uint8List，
  /// 导致 Image.memory 的 MemoryImage 引用不同而缓存失效、图片反复解码闪烁。
  static final Map<int, List<Uint8List>> _userImageCache = {};

  /// 用户消息附带的图片字节（从 task.inputImages 解析）
  List<Uint8List> get _userImages {
    final cached = _ChatBubble._userImageCache[task.id];
    if (cached != null) return cached;
    final raw = task.inputImages;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final bytes = [
          for (final e in decoded)
            if (e is String && e.contains(',')) base64Decode(e.split(',').last),
        ];
        if (bytes.isNotEmpty) {
          _ChatBubble._userImageCache[task.id] = bytes;
          if (_ChatBubble._userImageCache.length > 100) {
            _ChatBubble._userImageCache.remove(
              _ChatBubble._userImageCache.keys.first,
            );
          }
        }
        return bytes;
      }
    } catch (_) {}
    return const [];
  }

  /// 本回复中 search_bangumi 返回的候选条目（UI 渲染卡片供选择跳转）
  List<BangumiItem> get _bangumiCandidates {
    for (final s in _savedSteps) {
      if (s.toolName != 'search_bangumi' || s.result == null) continue;
      final marker = RegExp(
        r'\[KOSTORI_BANGUMI_CARDS\]([\s\S]*?)\[/KOSTORI_BANGUMI_CARDS\]',
      ).firstMatch(s.result!);
      if (marker == null) continue;
      try {
        final decoded = jsonDecode(marker.group(1)!);
        if (decoded is List) {
          return [
            for (final e in decoded)
              if (e is Map) BangumiItem.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {}
    }
    return const [];
  }

  /// 本回复中查询角色/声优返回的候选（UI 渲染卡片供选择跳转）。
  /// [isCharacter] 决定点击后进入角色页还是声优（人物）页。
  ({bool isCharacter, List<CharacterActor> items})? get _characterCandidates {
    for (final s in _savedSteps) {
      if (s.result == null) continue;
      final marker = RegExp(
        r'\[KOSTORI_CHARACTER_CARDS\]([\s\S]*?)\[/KOSTORI_CHARACTER_CARDS\]',
      ).firstMatch(s.result!);
      if (marker == null) continue;
      try {
        final decoded = jsonDecode(marker.group(1)!);
        if (decoded is Map<String, dynamic>) {
          final items = decoded['items'];
          if (items is List) {
            return (
              isCharacter: decoded['isCharacter'] == true,
              items: [
                for (final e in items)
                  if (e is Map)
                    CharacterActor.fromJson(e.cast<String, dynamic>()),
              ],
            );
          }
        }
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 第一层：头部（头像 + 名称 + 时间，AI/用户镜像对称）
    final header = _MessageHeader(
      name: isUser
          ? currentUserNickname
          : (task.modelName?.isNotEmpty == true ? task.modelName! : t.aiLabel),
      time: _fmtTime(task.createdAt),
      isUser: isUser,
    );

    // 第二层起：内容（占满整行，不被头像挤到右侧）
    final Widget body;
    if (isUser) {
      final userImages = _userImages;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 用户附带的图片：按原图比例自适应尺寸并右对齐，右缘与文字气泡对齐
          for (final bytes in userImages) ...[
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _chatContentMaxWidth(context),
                  maxHeight: 220,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _chatContentMaxWidth(context),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  content,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      final reasoning = _reasoningText;
      final hasReasoning = reasoning != null;
      final effectiveContent = (content.isEmpty && hasReasoning)
          ? reasoning
          : content;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_savedSteps.isNotEmpty)
            _StepProcessArea(steps: _savedSteps, isStreaming: false)
          else ...[
            if (hasReasoning && content.isNotEmpty)
              _ReasoningToggle(
                reasoning: reasoning,
                durationMs: _thinkingMs ?? _durationMs,
              ),
            if (_toolCalls.isNotEmpty)
              _ToolLogSection(
                tools: _toolCalls,
                defaultExpanded: defaultExpandedToolLog,
              ),
          ],
          useMarkdown
              ? CustomMarkdownWidget(
                  data: effectiveContent,
                  indentFirstLine: false,
                )
              : SelectableText(effectiveContent),
          // 多个候选：横向排列 BangumiBriefCard，供用户左右滑动选择跳转
          if (_bangumiCandidates.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _bangumiCandidates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final candidate = _bangumiCandidates[i];
                  return SizedBox(
                    width: 160,
                    child: BangumiBriefCard(
                      bangumiItem: candidate,
                      heroTag: 'chat_bangumi_${candidate.id}_${task.id}_$i',
                    ),
                  );
                },
              ),
            ),
          ],
          // 多个候选：横向排列 BangumiCharacterCard（角色/声优），供用户左右滑动选择跳转
          if (_characterCandidates case final candidates?
              when candidates.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: candidates.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final candidate = candidates.items[i];
                  return SizedBox(
                    width: 160,
                    child: BangumiCharacterCard(
                      character: candidate,
                      heroTag: 'chat_character_${candidate.id}_${task.id}_$i',
                      isCharacter: candidates.isCharacter,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 6),
          body,
          // 错误提示 + 重试
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
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
                        t.retry,
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
          // 消息操作区
          if (isUser) _userFooter(context) else _aiFooter(context),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: scheme.outline),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(fontSize: 11, color: scheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _userFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionButton(context, Icons.copy_outlined, t.copy, () => _copy()),
            _actionButton(
              context,
              Icons.replay_outlined,
              t.resendFromHere,
              () => onRollback?.call(),
            ),
            if (onEdit != null)
              _actionButton(
                context,
                Icons.edit_outlined,
                t.edit,
                () => _edit(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _aiFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                context,
                Icons.copy_outlined,
                t.copy,
                () => _copy(),
              ),
              _actionButton(
                context,
                Icons.replay_outlined,
                t.regenerateReply,
                () => onRollback?.call(),
              ),
              _actionButton(
                context,
                Icons.translate,
                t.translate,
                () => _translate(context),
              ),
            ],
          ),
          _metaRow(context),
        ],
      ),
    );
  }

  /// 千分位格式化：1234567 -> 1,234,567
  static String _thousands(num v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// 底部元数据：图标 + 紧凑统计（输入 / 缓存 / 输出 tokens · 速度 · 耗时）
  Widget _metaRow(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: Colors.grey.shade500);
    final segments = <Widget>[];

    void addSegment(IconData icon, String text) {
      segments.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey.shade500),
            const SizedBox(width: 2),
            Text(text, style: style),
          ],
        ),
      );
    }

    final prompt = _promptTokens;
    final completion = _completionTokens;
    final cached = _cachedTokens;
    final durationMs = _durationMs;

    if (prompt != null) {
      addSegment(
        Icons.subdirectory_arrow_left,
        '${_thousands(prompt)} ${t.tokens}',
      );
    }
    if (cached != null && cached > 0) {
      addSegment(Icons.cached, '(${_thousands(cached)} ${t.statsCached})');
    }
    if (completion != null) {
      addSegment(
        Icons.subdirectory_arrow_right,
        '${_thousands(completion)} ${t.tokens}',
      );
    }
    if (completion != null && durationMs != null && durationMs > 0) {
      final speed = completion / (durationMs / 1000);
      addSegment(Icons.speed, '${speed.toStringAsFixed(1)} tok/s');
    }
    if (durationMs != null && durationMs > 0) {
      addSegment(
        Icons.timer_outlined,
        '${(durationMs / 1000).toStringAsFixed(1)}s',
      );
    }

    if (segments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: segments,
      ),
    );
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: content));
    App.rootContext.showMessage(message: t.copied);
  }

  Future<void> _edit(BuildContext context) async {
    final ctrl = TextEditingController(text: content);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.edit,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          decoration: InputDecoration(border: const OutlineInputBorder()),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(t.save),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onEdit?.call(result);
  }

  Future<void> _translate(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TranslationResultSheet(source: content),
    );
  }
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
