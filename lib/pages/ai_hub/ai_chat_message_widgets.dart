part of 'ai_hub_page.dart';

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

/// 底部元数据：输入 / 缓存 / 输出 tokens · 速度 · 耗时（AI 聊天与冒险复用）
class AiUsageMeta extends StatelessWidget {
  const AiUsageMeta({super.key, required this.task});

  final AiTask task;

  Map<String, dynamic>? get _thoughtMap {
    final thought = task.thought;
    if (thought == null || thought.isEmpty) return null;
    try {
      final decoded = jsonDecode(thought);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? get _usageMap {
    final map = _thoughtMap;
    if (map == null) return null;
    final usage = map['usage'];
    if (usage is Map<String, dynamic>) return usage;
    return map;
  }

  static String _thousands(num v) {
    final s = v.toInt().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
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

    final u = _usageMap;
    final prompt = (u?['prompt'] as num?)?.toInt();
    final completion = (u?['completion'] as num?)?.toInt();
    final cached = (u?['cached'] as num?)?.toInt();
    final durationMs = (_thoughtMap?['durationMs'] as num?)?.toInt();

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
    ctrl.dispose();
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
