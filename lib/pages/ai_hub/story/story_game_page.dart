part of 'package:kostori/pages/ai_hub/ai_hub_page.dart';

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
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();
  String? _sessionId;
  GameState _state = GameState.empty;
  bool _sending = false;
  bool _booting = true;
  bool _showStreamBubble = false;
  String _streamText = '';
  CancelToken? _cancelToken;
  int _lastMessageCount = 0;

  /// 上次发送的原始输入（失败后用于重试）
  String? _lastOutgoing;
  bool _lastFailed = false;

  /// 最后一条消息是用户消息（说明该轮没有回复，可能失败/中断）——
  /// 重新进入页面时据此恢复「重试」入口
  bool _lastTurnPending = false;

  /// 流式长时间无输出时的看门狗（超时中断，避免一直卡住）
  Timer? _stallTimer;
  bool _stallAborted = false;

  /// 新增但未在图鉴登记的物品（故事层校验结果）
  List<String> _unregistered = const [];
  bool _registering = false;

  /// 是否跟随到底部（用户上滑后暂停，发送时恢复）
  bool _isFollowing = true;

  /// 追问建议：默认收起，展开后是输入框上方靠右的竖排面板
  bool _suggestExpanded = false;

  /// 特殊判定：一次性开关，下一条消息作为动作判定（输出一次即清除）
  bool _pendingCheck = false;

  Widget _suggestToggle() => TextButton.icon(
    onPressed: () => setState(() => _suggestExpanded = true),
    icon: const Icon(Icons.auto_awesome, size: 16),
    label: Text(t.suggestions),
  );

  Widget _suggestPanel(List<String> choices) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        maxHeight: MediaQuery.sizeOf(context).height * 0.4,
      ),
      // 磨砂玻璃背景
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 2, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.suggestions,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: t.collapse,
                    onPressed: () => setState(() => _suggestExpanded = false),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final c in choices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _FollowUpChip(
                          text: c,
                          onTap: _sending
                              ? () {}
                              : () {
                                  setState(() => _suggestExpanded = false);
                                  _send(c);
                                },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  /// 发送后、真正落库前先乐观显示的用户消息
  String? _pendingUserText;

  /// 需要先做开局档案设置（仅新游戏且故事定义了 setup 时）
  bool _needsSetup = false;
  final Map<String, String> _singleValues = {};
  final Map<String, Set<String>> _multiValues = {};
  final Map<String, TextEditingController> _textValues = {};
  final Map<String, int> _numberValues = {};

  /// 选了「自定义」选项后，玩家补充输入的内容
  final Map<String, TextEditingController> _customValues = {};

  /// 「自定义」是约定选项：选中它要额外给出输入框
  static const _customOption = '自定义';

  /// 世界书里固定条目（种族/职业/天赋/事件/MOD…）的说明，用作选项 tooltip
  late final Map<String, String> _fixedHints = parseStoryFixedHints(
    widget.story.worldBook,
  );

  /// 开局档案里填的玩家名（供提示词里的 `{{user}}` 使用）
  String _setupName = '';

  /// 开局档案的选择（字段 key → 选中的选项名），供世界书按需注入
  Map<String, List<String>> _setupSelections = {};

  /// 运行时故事：角色卡来自独立存储，再并入从设定库选择的条目
  late Story _effective = widget.story;

  Story _computeEffective() {
    var s = widget.story;
    final cards = StoryCharacterStore.instance.get(s.id);
    final persona = StoryCharacterStore.instance.persona(s.id);
    if (cards.isNotEmpty || persona != null) {
      s = s.copyWith(
        characters: cards.isEmpty ? s.characters : cards,
        persona: persona ?? s.persona,
      );
    }
    return _mergeSettings(s);
  }

  Story _mergeSettings(Story s) {
    if (s.settingIds.isEmpty) return s;
    final entries = <SettingEntry>[];
    for (final id in s.settingIds) {
      final e = SettingLibraryStore.instance.find(id);
      if (e != null) entries.add(e);
    }
    return mergeSettingLibrary(s, entries);
  }

  Story get story => _effective;

  @override
  void initState() {
    super.initState();
    StoryTextStyleStore.instance.ensureLoaded();
    _boot();
  }

  /// 是否已贴近底部（列表 reverse，底部即 offset 0）
  static bool _atBottom(ScrollMetrics m) => m.pixels <= 48;

  /// 滚动状态机：offset 增大（reverse 列表 = 上滑看历史）即暂停跟随；
  /// 回到底部恢复跟随。程序滚动只会把 offset 拉向 0（变小），不会误判。
  bool _onUserScroll(ScrollNotification n) {
    if (n.metrics.axis == Axis.horizontal) return false;
    // 用户开始拖动（含触摸/鼠标拖拽）时立即解除跟随：
    // 之前要求「已离开底部」才解除，流式输出每帧把列表拉回底部，
    // 导致 json 阶段根本滑不上去。拖动结束再按是否到底决定是否恢复跟随。
    if (n is ScrollStartNotification && n.dragDetails != null) {
      if (_isFollowing) setState(() => _isFollowing = false);
      return false;
    }
    if (n is UserScrollNotification) {
      if (n.direction != ScrollDirection.idle && _isFollowing) {
        setState(() => _isFollowing = false);
      }
    } else if (n is ScrollUpdateNotification) {
      if ((n.scrollDelta ?? 0) > 0 && _isFollowing) {
        setState(() => _isFollowing = false);
      } else if (_atBottom(n.metrics) && !_isFollowing) {
        setState(() => _isFollowing = true);
      }
    } else if (n is ScrollEndNotification &&
        _atBottom(n.metrics) &&
        !_isFollowing) {
      setState(() => _isFollowing = true);
    }
    return false;
  }

  @override
  void dispose() {
    _stallTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    for (final c in _textValues.values) {
      c.dispose();
    }
    for (final c in _customValues.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 滚到底部（列表 reverse，底部即 offset 0）；非跟随状态不强制
  void _scrollToBottom({bool animate = true, bool force = false}) {
    if (!force && !_isFollowing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      // 回调排队期间用户可能已上滑，重新确认，避免把用户拽回底部
      if (!force && !_isFollowing) return;
      if (animate) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else if (_scrollController.offset.abs() > 1) {
        _scrollController.jumpTo(0);
      }
    });
  }

  Future<void> _boot() async {
    await StorySessionStore.instance.ensureLoaded();
    await StoryCharacterStore.instance.ensureLoaded();
    _effective = _computeEffective();
    final saved = StorySessionStore.instance.get(story.id);
    if (saved != null && saved.sessionId.isNotEmpty) {
      _setupSelections = Map<String, List<String>>.from(saved.setup);
      if (!mounted) return;
      setState(() {
        _sessionId = saved.sessionId;
        _state = _mergeResources(saved.state);
        _booting = false;
      });
      // 按消息折叠变量，恢复分支正确的最新值
      await _applyFoldedVariables();
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
    await _send(t.storyCmdStart);
  }

  Future<void> _newSession({GameState? initialState}) async {
    var initial = initialState ?? story.initialState;
    // 故事预置词条并入初始状态（开局即已知）
    if (story.codex.isNotEmpty) {
      final seen = {
        for (final d in initial.codex) '${d.kind}\u0000${d.key}': true,
      };
      final merged = [...initial.codex];
      for (final d in story.codex) {
        if (seen['${d.kind}\u0000${d.key}'] == true) continue;
        merged.add(d);
        seen['${d.kind}\u0000${d.key}'] = true;
      }
      initial = initial.copyWith(codex: merged);
    }
    // 把故事声明的变量初值并入初始状态
    if (story.variables.isNotEmpty) {
      final vars = Map<String, String>.from(initial.variables);
      for (final v in story.variables) {
        if (v.name.trim().isEmpty) continue;
        vars.putIfAbsent(v.name.trim(), () => v.value);
      }
      initial = initial.copyWith(variables: vars);
    }
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
      StorySession(
        sessionId: sessionId,
        state: initial,
        setup: _setupSelections,
      ),
    );
  }

  /// 收集开局选择（字段 key → 选项名），供世界书按选择注入
  Map<String, List<String>> _collectSetupSelections() {
    final out = <String, List<String>>{};
    for (final p in story.setup) {
      if (p.type == 'multi') {
        final set = _multiValues[p.key];
        if (set != null && set.isNotEmpty) out[p.key] = set.toList();
      } else if (p.type == 'single') {
        final v = _singleValues[p.key];
        if (v != null && v.isNotEmpty) out[p.key] = [v];
      }
    }
    return out;
  }

  /// 校验并生成开局档案文本，然后开局（数值项并入初始状态属性）
  Future<void> _startWithSetup() async {
    final buf = StringBuffer(t.storyCmdProfile);
    final attrs = Map<String, int>.from(story.initialState.attributes);
    // 玩家角色卡已有名字时，name 字段不展示，也不参与必填校验
    final personaName =
        StoryCharacterStore.instance.persona(story.id)?.name.trim() ?? '';
    if (personaName.isNotEmpty) buf.writeln('姓名：$personaName');
    for (final part in story.setup) {
      if (personaName.isNotEmpty && part.key == 'name') continue;
      final value = switch (part.type) {
        'multi' => _multiValueText(part),
        'text' => (_textValues[part.key]?.text.trim() ?? ''),
        'number' => '${_partNumber(part)}',
        _ => _singleValueText(part),
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
    _setupName = _textValues['name']?.text.trim() ?? '';
    _setupSelections = _collectSetupSelections();
    final initial = story.initialState.copyWith(attributes: attrs);
    setState(() => _needsSetup = false);
    await _newSession(initialState: initial);
    await _send(buf.toString());
  }

  /// 系统提示词：故事定义 + 开局场景 + 已积累的设定图鉴（供 AI 严格遵守）
  Future<String> _systemPromptFor(
    GameState state, {
    String scanText = '',
    bool check = false,
  }) async {
    final vars = state.variables;
    final persona = story.persona;
    // {{user}} = 玩家名（角色卡 > 开局档案 > 默认），{{persona}} = 玩家设定描述
    final userName = persona.name.trim().isNotEmpty
        ? persona.name.trim()
        : (_setupName.isNotEmpty ? _setupName : '玩家');
    String sub(String text) => replaceStoryVars(text, vars)
        .replaceAll('{{user}}', userName)
        .replaceAll('{{persona}}', persona.description.trim());

    // 命中扫描文本：最近对话 + 本条输入（供世界书按触发词命中，避免整本注入）
    final scanParts = <String>[];
    final sid = _sessionId;
    if (sid != null) {
      final msgs = await AiConversationService().watchMessages(sid).first;
      for (final m in msgs) {
        scanParts.add(
          m.role == 'user' ? m.inputContent : (m.outputContent ?? ''),
        );
      }
    }
    if (scanText.isNotEmpty) scanParts.add(scanText);
    final scanBlob = scanParts.where((s) => s.trim().isNotEmpty).join('\n');

    // 世界书按开局选择裁剪：只注入选中的种族/职业/天赋/事件/MOD 详情
    final buf = StringBuffer(
      sub(
        story.buildSystemPrompt(
          worldBookOverride: filterWorldBook(
            story.worldBook,
            _setupSelections,
            scanText: scanBlob,
          ),
          scanText: scanBlob,
        ),
      ),
    );
    if (check) {
      buf.write(
        '\n\n【特殊判定】玩家本条消息要求进行一次动作判定：'
        '请调用 roll_dice 工具掷骰（给出合适的 label / dice / modifier / dc），'
        '再依据结果描述成败，不要自己编点数。',
      );
    }
    if (!persona.isEmpty) {
      buf.write('\n\n【玩家角色（用户本人，禁止扮演；你只需知道他是谁）】');
      if (persona.name.trim().isNotEmpty) {
        buf.write('\n名字：${persona.name.trim()}');
      }
      if (persona.description.trim().isNotEmpty) {
        buf.write('\n${persona.description.trim()}');
      }
    }
    if (story.opening.trim().isNotEmpty) {
      buf.write('\n\n【开局场景（请从这里开始叙事）】\n${sub(story.opening.trim())}');
    }
    if (story.deathResources.isNotEmpty) {
      final rule = story.deathMode == 'all'
          ? '全部归零才结束'
          : '任意一个归零即结束';
      buf.write(
        '\n\n【致命资源（$rule，请在归零前给出收尾叙事）】'
        '${story.deathResources.join('、')}',
      );
    }
    if (state.resources.isNotEmpty) {
      buf.write('\n\n【数值条（每回合都要完整回传，勿遗漏任何一条）】');
      for (final r in state.resources) {
        buf.write('\n- ${r.name} ${r.cur}/${r.max}');
      }
    }
    if (story.characters.isNotEmpty) {
      buf.write('\n\n【角色设定（需分别扮演，保持各自语气与人设）】');
      for (final c in story.characters) {
        buf.write('\n- ${c.displayName}');
        if (c.personality.trim().isNotEmpty) {
          buf.write('（${c.personality.trim()}）');
        }
        if (c.description.trim().isNotEmpty) {
          buf.write('：${sub(c.description.trim())}');
        }
      }
      buf.write(
        '\n当前在场：'
        '${state.present.isEmpty ? '（暂无。仅在剧情推进需要时逐个引入角色，不要一次性让所有角色登场）' : state.present.join('、')}',
      );
    }
    if (story.achievements.isNotEmpty) {
      buf.write('\n\n【成就（解锁时把 key 加入 achievements，勿自创）】');
      for (final a in story.achievements) {
        buf.write('\n- ${a.key}：${a.name}');
        if (a.description.trim().isNotEmpty) {
          buf.write('（${a.description.trim()}）');
        }
      }
    }
    if (state.equipped.isNotEmpty) {
      buf.write('\n\n【已装备（其机制当前生效）】${state.equipped.join('、')}');
    }
    if (state.combat.active) {
      buf.write('\n\n【战斗中 · 第${state.combat.round}回合】');
      for (final e in state.combat.enemies) {
        buf.write('\n- ${e.name} ${e.hp}/${e.maxHp}${e.note.isEmpty ? '' : '（${e.note}）'}');
      }
    }
    if (vars.isNotEmpty) {
      buf.write('\n\n【变量（每回合回传最新值，需遵守类型约束）】');
      final declared = {for (final v in story.variables) v.name: v};
      for (final e in vars.entries) {
        final d = declared[e.key];
        final meta = <String>[];
        if (d != null) {
          if (d.type == 'number') {
            final range = [
              if (d.min != null) '${d.min}',
              if (d.max != null) '${d.max}',
            ].join('~');
            meta.add(
              '数值${range.isEmpty ? '' : ' $range'}'
              '${d.unit.isEmpty ? '' : d.unit}',
            );
          } else if (d.type == 'enum' && d.options.isNotEmpty) {
            meta.add('取值：${d.options.join('/')}');
          }
          if (d.description.trim().isNotEmpty) meta.add(d.description.trim());
        }
        buf.write(
          '\n- ${e.key} = ${e.value}${meta.isEmpty ? '' : '（${meta.join('；')}）'}',
        );
      }
    }
    if (state.codex.isNotEmpty) {
      // 故事预设词条已在 buildSystemPrompt 的【预置词条】里列出，避免重复注入
      final presetKeys = {
        for (final d in story.codex) '${d.kind}\u0000${d.key}',
      };
      final runtimeCodex = [
        for (final d in state.codex)
          if (!presetKeys.contains('${d.kind}\u0000${d.key}')) d,
      ];
      if (runtimeCodex.isNotEmpty) {
        buf.write('\n\n【已知设定（必须严格遵守，不得矛盾）】');
        for (final d in runtimeCodex) {
          buf.write(
            '\n- ${d.name}（${d.kind}）：'
            '${d.mechanics.isEmpty ? d.display : d.mechanics}',
          );
        }
      }
    }
    if (state.situation.trim().isNotEmpty) {
      buf.write('\n\n【当前局势（延续此设定，除非剧情已推进）】\n');
      buf.write(state.situation.trim());
    }
    // 滚动摘要（长期记忆）：故事走 systemPromptOverride，不会经过
    // buildSystemPrompt，所以这里显式把摘要拼进来，超长局才不掉老上下文
    final summary = _sessionId == null
        ? null
        : await AiConversationService().sessionSummary(_sessionId!);
    if (summary != null) {
      buf.write('\n\n【历史对话摘要（长期记忆）】\n$summary');
    }
    // 故事从库里显式选择的世界书 / 提示词（未选则不注入）
    final injections = await PromptInjectionStore.instance.selectExact(
      story.injectionIds.toSet(),
    );
    for (final inj in injections) {
      if (inj.content.trim().isEmpty) continue;
      buf.write('\n\n【${inj.name.trim().isEmpty ? '提示词' : inj.name.trim()}】\n');
      buf.write(inj.content.trim());
    }
    // 绑定过滤：绑定了角色卡 / 标签的条目，需与故事角色有交集；
    // at_depth 条目不进系统提示词，改由发送时插进对话历史
    final boundIds = {for (final c in story.characters) c.id};
    final boundTags = <String>{
      for (final c in story.characters) ...c.tags,
    };
    // 世界书按触发词命中注入（对齐 ST）：常驻条目始终注入，未显式选择则不注入
    final allWorldBook = story.worldBookIds.isEmpty
        ? const <WorldBookEntry>[]
        : await WorldBookStore.instance.select(
            story.worldBookIds.toSet(),
            scanBlob,
            turn: _lastMessageCount ~/ 2,
          );
    _storyDepthHits = allWorldBook
        .where(
          (e) =>
              e.position == 'at_depth' && e.matchesBinding(boundIds, boundTags),
        )
        .toList();
    final worldBook = allWorldBook
        .where(
          (e) =>
              e.position != 'at_depth' && e.matchesBinding(boundIds, boundTags),
        )
        .toList();
    if (worldBook.isNotEmpty) {
      buf.write('\n\n【世界书】');
      var seq = 0;
      for (final e in worldBook) {
        if (e.content.trim().isEmpty) continue;
        seq++;
        buf.write('\n$seq. ${e.content.trim()}');
      }
    }
    // 角色世界书：仅对在场（或未标记在场时全部）角色按 ST 语义扫描
    final activeCards = state.present.isEmpty
        ? story.characters
        : [
            for (final c in story.characters)
              if (state.present.any((n) => _isNameFor(c, n))) c,
          ];
    if (activeCards.isNotEmpty) {
      for (final c in activeCards) {
        final book = CharacterLoreBook.fromMap(c.characterBook);
        if (book == null) continue;
        final hits = CharacterLorebookResolver.instance.resolve(
          book,
          scanParts,
          cardId: c.id,
          turn: _lastMessageCount ~/ 2,
        );
        if (hits.isEmpty) continue;
        buf.write('\n\n【角色世界书 · ${c.displayName}】');
        var seq = 0;
        for (final e in hits) {
          if (e.content.trim().isEmpty) continue;
          seq++;
          buf.write('\n$seq. ${e.content.trim()}');
        }
      }
    }
    Log.info(
      'StoryPrompt',
      'system≈${buf.length} 字符 · 世界书命中 ${worldBook.length + _storyDepthHits.length} 条',
    );
    return buf.toString();
  }

  Future<void> _send(String text, {bool check = false}) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    final outgoing = applyStoryRegex(text, story.regexes, 'send');
    // 让 roll_dice 工具与页面用同一套暴击/方向规则
    SkillRegistry.instance.diceCrits = story.crits;
    SkillRegistry.instance.diceDirection = story.checkDirection;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _lastOutgoing = text;
    _stallAborted = false;
    setState(() {
      _sending = true;
      _showStreamBubble = true;
      _streamText = '';
      _pendingUserText = outgoing;
      _isFollowing = true;
      _lastFailed = false;
    });
    _scrollToBottom(force: true);
    _armStallWatchdog();
    try {
      await for (final u in AiConversationService().sendMessageStream(
        sessionId: sessionId,
        userMessage: outgoing,
        taskType: 'story',
        // 只允许模型调用 roll_dice（NPC / 剧情判定由系统掷骰），
        // 不暴露其它助手技能
        useTools: true,
        toolNames: const {'roll_dice'},
        providerOverride: aiHubProvider(),
        systemPromptOverride: await _systemPromptFor(
          _state,
          scanText: outgoing,
          check: check,
        ),
        paramsOverride: _storyParams(),
        contextBudgetOverride: story.contextBudgetChars,
        extraDepthHits: _storyDepthHits,
        cancelToken: cancelToken,
      )) {
        if (!mounted) return;
        _armStallWatchdog();
        if (u.errorMessage != null) {
          setState(() {
            _sending = false;
            _showStreamBubble = false;
            _streamText = '';
            _pendingUserText = null;
            _lastFailed = true;
          });
          App.rootContext.showMessage(
            message: u.errorMessage!,
            level: LogLevel.error,
          );
          return;
        }
        setState(() {
          _pendingUserText = null;
          _streamText = u.text;
        });
        _scrollToBottom(animate: false);
        if (u.done) break;
      }
      if (!mounted) return;
      final finalText = _streamText;
      final cancelled = cancelToken.isCancelled;
      final stalled = _stallAborted;
      setState(() {
        _sending = false;
        _showStreamBubble = false;
        _streamText = '';
        _pendingUserText = null;
        // 空回复视为失败，可重试；用户主动停止且有内容时不提示重试
        _lastFailed = finalText.trim().isEmpty;
      });
      _scrollToBottom();
      if (stalled) {
        App.rootContext.showMessage(
          message: t.storyResponseStalled,
          level: LogLevel.warning,
        );
      }
      // 取消时服务端不落库，忽略本次结果
      if (cancelled || finalText.trim().isEmpty) return;
      final parsed = _parseReply(finalText);
      if (parsed.state != null || parsed.varOps.isNotEmpty) {
        var state = parsed.state ?? _state;
        // 变量：增量叠加到当前值
        if (parsed.varOps.isNotEmpty) {
          state = state.copyWith(
            variables: applyVarOps(_state.variables, parsed.varOps),
          );
        } else if (state.variables.isEmpty) {
          state = state.copyWith(variables: _state.variables);
        }
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
        await _applyState(state);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _showStreamBubble = false;
          _streamText = '';
          _pendingUserText = null;
          _lastFailed = true;
        });
        App.rootContext.showMessage(message: e.toString(), level: LogLevel.error);
      }
    } finally {
      _stallTimer?.cancel();
      _cancelToken = null;
    }
  }

  /// 流式看门狗：超过 90 秒没有任何输出则中断本次回复（可重试）
  void _armStallWatchdog() {
    _stallTimer?.cancel();
    _stallTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && _sending) {
        _stallAborted = true;
        _cancelToken?.cancel();
      }
    });
  }

  /// 重试上一次发送：删除失败留下的用户消息，再重新发送。
  /// 重新进入页面后 [_lastOutgoing] 为空，从最后一条未回复的用户消息恢复。
  Future<void> _retryLast() async {
    if (_sending) return;
    var text = _lastOutgoing;
    final sessionId = _sessionId;
    if (sessionId != null) {
      final msgs = await AiConversationService().watchMessages(sessionId).first;
      if (msgs.isNotEmpty && msgs.last.role == 'user') {
        text ??= msgs.last.inputContent;
        await AiConversationService().deleteMessage(msgs.last.id);
      }
    }
    if (!mounted || text == null || text.trim().isEmpty) return;
    setState(() => _lastFailed = false);
    await _send(text);
  }

  /// 初始变量：故事初始状态 + 声明的默认值
  Map<String, String> _initialVars() {
    final vars = Map<String, String>.from(story.initialState.variables);
    for (final v in story.variables) {
      final name = v.name.trim();
      if (name.isEmpty) continue;
      vars.putIfAbsent(name, () => v.value);
    }
    return vars;
  }

  /// 事件溯源：沿消息顺序折叠变量增量（尊重每条消息所选候选）
  Map<String, String> _foldVariables(List<AiTask> messages) {
    var vars = _initialVars();
    for (final m in messages) {
      if (m.role != 'model') continue;
      final parsed = _parseReply(m.outputContent ?? '');
      if (parsed.varOps.isNotEmpty) {
        vars = applyVarOps(vars, parsed.varOps);
      } else if (parsed.state != null) {
        // 旧消息：整表覆盖
        vars = {...vars, ...parsed.state!.variables};
      }
    }
    return normalizeVariables(vars, story.variables);
  }

  /// 重新折叠变量并持久化（swipe / 删除 / 启动时调用）
  Future<void> _applyFoldedVariables() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final messages = await AiConversationService()
        .watchMessages(sessionId)
        .first;
    if (!mounted) return;
    final next = _state.copyWith(variables: _foldVariables(messages));
    setState(() => _state = next);
    await StorySessionStore.instance.put(
      story.id,
      StorySession(sessionId: sessionId, state: next),
    );
  }

  /// 找出背包里未在 codex 登记的道具（按基础名归一，宽松包含匹配）
  List<String> _unregisteredFrom(GameState state) {
    final registered = <String>{
      for (final d in state.codex.where((d) => d.kind == 'item')) ...[d.key, d.name],
    };
    bool isRegistered(String item) {
      final base = item.split(' x').first.split('×').first.trim();
      if (base.isEmpty) return true;
      if (registered.contains(item) || registered.contains(base)) return true;
      for (final r in registered) {
        if (r.trim().isEmpty) continue;
        if (r.contains(base) || base.contains(r)) return true;
      }
      return false;
    }

    // 明显不是道具的（长句/带句读）忽略
    bool looksLikeItem(String item) =>
        item.length <= 40 &&
        !item.contains('。') &&
        !item.contains('；') &&
        !item.contains('！') &&
        !item.contains('？');

    return [
      for (final item in state.inventory)
        if (looksLikeItem(item) && !isRegistered(item)) item,
    ];
  }

  /// 角色条点击：查看角色卡 / 对TA说话
  Future<void> _characterMenu(CharacterCard c) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: c.displayName,
        icon: Icons.person_outline,
        initialSize: 0.36,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(t.characterCards),
              onTap: () {
                Navigator.of(ctx).pop();
                showCharacterCardView(context, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: Text(t.storyNpcStatus),
              subtitle: Text(
                t.storyNpcAffinity(
                  value: '${_npcState(c)?.affinity ?? 0}',
                ),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _showNpcStatus(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(t.storyTalkTo),
              onTap: () {
                Navigator.of(ctx).pop();
                _addressCharacter(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add_outlined),
              title: Text(t.storyExportToLibrary),
              onTap: () async {
                Navigator.of(ctx).pop();
                await CharacterCardStore.instance.upsert(c);
                App.rootContext.showMessage(message: t.storyExported);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 模型可能用昵称或角色名报在场，两者都认
  bool _isNameFor(CharacterCard c, String n) =>
      n == c.name || n == c.displayName;

  /// 按角色名取该角色的运行状态
  NpcState? _npcState(CharacterCard c) {
    for (final n in _state.npcs) {
      if (n.name == c.name || n.name == c.displayName) return n;
    }
    return null;
  }

  /// 角色状态面板：好感度 / 姿态 / 数值条 / 属性 / 技能 / 携带
  Future<void> _showNpcStatus(CharacterCard c) async {
    final npc = _npcState(c);
    if (npc == null) {
      App.rootContext.showMessage(
        message: t.storyNpcNoStatus,
        level: LogLevel.info,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: c.displayName,
        icon: Icons.monitor_heart_outlined,
        initialSize: 0.72,
        builder: (ctx, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: _npcStatusWidgets(npc),
        ),
      ),
    );
  }

  List<Widget> _npcStatusWidgets(NpcState npc) {
    final scheme = Theme.of(context).colorScheme;
    Widget title(String s, IconData icon) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            s,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );

    final (tier, tierColor) = npcAffinityTier(npc.affinity, scheme);
    final out = <Widget>[
      Row(
        children: [
          Text(
            t.storyNpcAffinityLabel,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tier,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tierColor,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${npc.affinity}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tierColor,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ((npc.affinity + 100) / 200).clamp(0.0, 1.0),
          minHeight: 6,
          color: tierColor,
        ),
      ),
    ];
    if (npc.status.trim().isNotEmpty) {
      out.add(const SizedBox(height: 8));
      out.add(
        Text(
          npc.status.trim(),
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      );
    }
    if (npc.resources.isNotEmpty) {
      out.add(title(t.storyState, Icons.monitor_heart_outlined));
      for (final r in npc.resources) {
        out.add(
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
                    value: r.max <= 0 ? 0 : (r.cur / r.max).clamp(0.0, 1.0),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (npc.attributes.isNotEmpty) {
      out.add(title(t.storyAttributes, Icons.tune));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in npc.attributes.entries)
              Chip(label: Text('${e.key} ${e.value}')),
          ],
        ),
      );
    }
    if (npc.skills.isNotEmpty) {
      out.add(title(t.skills, Icons.sports_martial_arts_outlined));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in npc.skills) Chip(label: Text(s))],
        ),
      );
    }
    if (npc.inventory.isNotEmpty) {
      out.add(title(t.storyInventory, Icons.inventory_2_outlined));
      out.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in npc.inventory) Chip(label: Text(s))],
        ),
      );
    }
    return out;
  }

  /// 按角色名取头像（找不到时用默认）
  String _avatarForName(String name) {
    for (final c in story.characters) {
      if (c.name == name || c.displayName == name) return c.avatar;
    }
    return '';
  }

  /// 对某个角色说话：在输入框前缀「对XX：」并聚焦
  void _addressCharacter(CharacterCard c) {
    final prefix = t.storyCmdAddress(name: c.displayName);
    if (!_input.text.startsWith(prefix)) {
      _input.text = '$prefix${_input.text}';
    }
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _inputFocus.requestFocus();
  }

  /// at_depth 世界书条目（_systemPromptFor 解析后填入，发送时插进对话历史）
  List<WorldBookEntry> _storyDepthHits = const [];

  /// 故事的生成参数（为空则跟随服务商默认值）
  AiGenerationParams? _storyParams() {
    if (story.temperature == null &&
        story.topP == null &&
        story.maxTokens == null) {
      return null;
    }
    return AiGenerationParams(
      temperature: story.temperature,
      topP: story.topP,
      maxTokens: story.maxTokens,
    );
  }

  /// 按初始状态顺序补齐模型漏报的数值条；模型有更新则用模型的值。
  /// [extra] 用于并入后续新增/当前已有的资源。
  GameState _mergeResources(GameState state, {List<StatBar> extra = const []}) {
    final aiRes = {for (final r in state.resources) r.name: r};
    final merged = <StatBar>[];
    final seen = <String>{};
    for (final r in story.initialState.resources) {
      merged.add(aiRes[r.name] ?? r);
      seen.add(r.name);
    }
    for (final r in state.resources) {
      if (seen.add(r.name)) merged.add(r);
    }
    for (final r in extra) {
      if (seen.add(r.name)) merged.add(r);
    }
    return state.copyWith(resources: merged);
  }

  /// 属性上限：故事声明了 attributeCaps 时，对玩家与 NPC 属性做 clamp
  GameState _clampAttributes(GameState s) {
    final caps = story.attributeCaps;
    if (caps.isEmpty) return s;
    Map<String, int> clamp(Map<String, int> attrs) {
      if (attrs.isEmpty) return attrs;
      var changed = false;
      final out = <String, int>{};
      for (final e in attrs.entries) {
        final cap = caps[e.key];
        if (cap != null && cap > 0 && e.value > cap) {
          out[e.key] = cap;
          changed = true;
        } else {
          out[e.key] = e.value;
        }
      }
      return changed ? out : attrs;
    }

    final attrs = clamp(s.attributes);
    var npcChanged = false;
    final npcs = [
      for (final n in s.npcs)
        () {
          final a = clamp(n.attributes);
          if (identical(a, n.attributes)) return n;
          npcChanged = true;
          return n.copyWith(attributes: a);
        }(),
    ];
    if (identical(attrs, s.attributes) && !npcChanged) return s;
    return s.copyWith(attributes: attrs, npcs: npcs);
  }

  /// 合并在场角色状态：模型给出的优先，之前已有但本次漏报的保留
  GameState _mergeNpcs(GameState state) {
    if (state.npcs.isEmpty && _state.npcs.isEmpty) return state;
    final merged = <NpcState>[];
    final seen = <String>{};
    for (final n in state.npcs) {
      if (seen.add(n.name)) merged.add(n);
    }
    for (final n in _state.npcs) {
      if (seen.add(n.name)) merged.add(n);
    }
    return state.copyWith(npcs: merged);
  }

  /// 为新登场、还没有角色卡的 NPC 自动生成一张角色卡（按名字去重）
  Future<void> _autoCreateNpcCards(GameState state) async {
    final names = <String>{
      for (final n in state.present)
        if (n.trim().isNotEmpty) n.trim(),
      for (final n in state.npcs)
        if (n.name.trim().isNotEmpty) n.name.trim(),
    };
    if (names.isEmpty) return;
    final existing = {
      for (final c in StoryCharacterStore.instance.get(story.id)) ...[
        c.name,
        c.displayName,
      ],
      for (final c in story.characters) ...[c.name, c.displayName],
    };
    final added = <CharacterCard>[];
    for (final name in names) {
      if (existing.contains(name)) continue;
      final npc = _npcIn(state, name);
      added.add(
        CharacterCard(
          id: 'npc_${name.hashCode.toRadixString(16)}',
          name: name,
          avatar: '',
          description: _npcAutoDescription(name, npc, state),
          tags: [t.storyAutoNpc],
          creator: 'auto',
        ),
      );
      existing.add(name);
    }
    if (added.isEmpty) return;
    await StoryCharacterStore.instance.put(story.id, [
      ...StoryCharacterStore.instance.get(story.id),
      ...added,
    ]);
    _effective = _computeEffective();
  }

  NpcState? _npcIn(GameState state, String name) {
    for (final n in state.npcs) {
      if (n.name == name) return n;
    }
    return null;
  }

  /// 自动角色卡描述：姿态 / 好感度 / 同名词条
  String _npcAutoDescription(String name, NpcState? npc, GameState state) {
    final parts = <String>[];
    if (npc != null && npc.status.trim().isNotEmpty) {
      parts.add(npc.status.trim());
    }
    if (npc != null) parts.add(t.storyNpcAffinity(value: '${npc.affinity}'));
    for (final d in state.codex) {
      if (d.name == name || d.key == name) {
        final text = d.display.trim().isNotEmpty
            ? d.display.trim()
            : d.mechanics.trim();
        if (text.isNotEmpty) parts.add(text);
        break;
      }
    }
    return parts.join('；');
  }

  /// 合并称号：模型给出的优先，之前已有的保留
  GameState _mergeTitles(GameState state) {
    if (state.titles.isEmpty && _state.titles.isEmpty) return state;
    final merged = <TitleState>[...state.titles];
    final seen = {for (final x in merged) x.key};
    for (final x in _state.titles) {
      if (seen.add(x.key)) merged.add(x);
    }
    return state.copyWith(titles: merged);
  }

  /// 合并状态效果：模型给出的优先，之前已有的保留
  GameState _mergeEffects(GameState state) {
    if (state.effects.isEmpty && _state.effects.isEmpty) return state;
    final merged = <EffectState>[...state.effects];
    final seen = {for (final x in merged) x.name};
    for (final x in _state.effects) {
      if (seen.add(x.name)) merged.add(x);
    }
    return state.copyWith(effects: merged);
  }

  /// 应用解析出的状态并持久化（含未登记道具校验 / 成就解锁提示）
  Future<void> _applyState(GameState? state) async {
    final sessionId = _sessionId;
    if (state == null || sessionId == null) return;
    var next = state.copyWith(
      variables: normalizeVariables(state.variables, story.variables),
    );
    // 增量式：本回合未提供的顶层字段保持上一回合的值（省略 ≠ 清空）
    final provided = state.provided;
    next = next.copyWith(
      attributes: provided.contains('attributes')
          ? {..._state.attributes, ...state.attributes}
          : _state.attributes,
    );
    if (!provided.contains('skills')) {
      next = next.copyWith(skills: _state.skills);
    }
    if (!provided.contains('inventory')) {
      next = next.copyWith(inventory: _state.inventory);
    }
    if (!provided.contains('quests')) {
      next = next.copyWith(quests: _state.quests);
    }
    if (!provided.contains('achievements')) {
      next = next.copyWith(achievements: _state.achievements);
    }
    if (!provided.contains('equipped')) {
      next = next.copyWith(equipped: _state.equipped);
    }
    if (!provided.contains('time')) next = next.copyWith(time: _state.time);
    if (!provided.contains('location')) {
      next = next.copyWith(location: _state.location);
    }
    if (!provided.contains('situation')) {
      next = next.copyWith(situation: _state.situation);
    }
    if (!provided.contains('present')) {
      next = next.copyWith(present: _state.present);
    }
    if (!provided.contains('combat')) {
      next = next.copyWith(combat: _state.combat);
    }
    // 词条一旦登记就保留（模型偶尔会漏报），合并而非覆盖
    final mergedCodex = [...next.codex];
    final seenDefs = {
      for (final d in mergedCodex) '${d.kind}\u0000${d.key}': true,
    };
    for (final d in _state.codex) {
      if (seenDefs['${d.kind}\u0000${d.key}'] == true) continue;
      mergedCodex.add(d);
      seenDefs['${d.kind}\u0000${d.key}'] = true;
    }
    next = next.copyWith(codex: mergedCodex);
    // 资源合并：模型偶尔漏报部分数值条（如体力/进食），按初始状态顺序补齐
    next = _mergeResources(next, extra: _state.resources);
    // 角色状态合并：模型漏报时保留上一回合的值
    next = _mergeNpcs(next);
    // 称号 / 状态效果合并；职业 / 据点漏报时保留
    next = _mergeTitles(next);
    next = _mergeEffects(next);
    next = _clampAttributes(next);
    if (next.job.isEmpty && !_state.job.isEmpty) {
      next = next.copyWith(job: _state.job);
    }
    if (next.base.isEmpty && !_state.base.isEmpty) {
      next = next.copyWith(base: _state.base);
    }
    // 致命资源归零 → 游戏结束（any=任一归零；all=全部归零）
    if (!next.gameOver && story.deathResources.isNotEmpty) {
      bool isZero(String name) {
        for (final r in next.resources) {
          if (r.name == name) return r.cur <= 0;
        }
        return false;
      }

      final over = story.deathMode == 'all'
          ? story.deathResources.every(isZero)
          : story.deathResources.any(isZero);
      if (over) next = next.copyWith(gameOver: true);
    }
    final unregistered = _unregisteredFrom(next);
    final newlyUnlocked = next.achievements
        .where((k) => !_state.achievements.contains(k))
        .toList();
    // 新登场的 NPC（非角色卡）自动建卡，便于在 NPC 栏查看/导出
    await _autoCreateNpcCards(next);
    setState(() {
      _state = next;
      _unregistered = unregistered;
    });
    if (newlyUnlocked.isNotEmpty) {
      final names = <String>[];
      for (final k in newlyUnlocked) {
        var name = k;
        for (final a in story.achievements) {
          if (a.key == k) {
            name = a.name;
            break;
          }
        }
        names.add(name);
      }
      App.rootContext.showMessage(
        message: '${t.storyAchievementUnlocked}: ${names.join('、')}',
      );
    }
    await StorySessionStore.instance.put(
      story.id,
      StorySession(sessionId: sessionId, state: next),
    );
    // 有新道具未登记则自动后台补全（无需手动）
    if (unregistered.isNotEmpty && !_registering) {
      unawaited(_registerUnregistered());
    }
  }

  /// 消息内联操作行（复制 / 重新生成 / 编辑 / 删除），无需长按
  Widget _messageFooter(AiTask m) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _msgAction(Icons.copy_outlined, t.copy, () => _copyMessage(m)),
            if (!isUser)
              _msgAction(
                Icons.replay_outlined,
                t.regenerateReply,
                () => _regenerate(m),
              ),
            // 骰子判定结果由系统掷出，只读（防作弊）
            if (isUser && !m.inputContent.startsWith(kStoryDiceMarker))
              _msgAction(Icons.edit_outlined, t.edit, () => _editMessage(m)),
            // 标注本条回复用的是哪个厂商的哪个模型
            if (!isUser && m.provider.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  (m.modelName ?? '').isEmpty
                      ? m.provider
                      : '${m.provider} • ${m.modelName}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _msgAction(IconData icon, String label, VoidCallback onTap) {
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

  void _copyMessage(AiTask m) {
    Clipboard.setData(
      ClipboardData(
        text: m.role == 'user' ? m.inputContent : (m.outputContent ?? ''),
      ),
    );
    App.rootContext.showMessage(message: t.copied);
  }

  /// 消息长按菜单：复制 / 编辑 / 重生成 / 删除
  Future<void> _messageMenu(AiTask m) async {
    final isUser = m.role == 'user';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.more,
        icon: Icons.more_horiz,
        initialSize: 0.46,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(t.copy),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(
                  ClipboardData(
                    text: isUser ? m.inputContent : (m.outputContent ?? ''),
                  ),
                );
                App.rootContext.showMessage(message: t.copied);
              },
            ),
            // 骰子判定结果只读（防作弊）
            if (isUser && !m.inputContent.startsWith(kStoryDiceMarker))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(t.edit),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editMessage(m);
                },
              ),
            if (!isUser)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(t.regenerate),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _regenerate(m);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 编辑消息：用户消息回滚重发；模型消息就地改输出
  Future<void> _editMessage(AiTask m) async {
    final isUser = m.role == 'user';
    await showInputDialog(
      context: App.rootContext,
      title: t.edit,
      initialValue: isUser ? m.inputContent : (m.outputContent ?? ''),
      minLines: 4,
      maxLines: 12,
      onConfirm: (value) async {
        final text = value.toString().trim();
        if (text.isEmpty) return t.required;
        if (isUser) {
          final sessionId = _sessionId;
          if (sessionId == null) return null;
          await AiConversationService().rollbackToMessage(sessionId, m.id);
          await _send(text);
        } else {
          await AiConversationService().editMessageInput(m.id, text);
          await _applyState(_parseReply(text).state);
        }
        return null;
      },
    );
  }

  /// 重新生成：保留旧结果作为候选，追加新候选
  Future<void> _regenerate(AiTask m) async {
    final sessionId = _sessionId;
    if (sessionId == null || _sending) return;
    // 二次确认，避免手滑覆盖当前回复
    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.regenerate,
        content: Text(t.regenerateConfirm),
        // ContentDialog 自带「取消」，这里只加确认，避免出现两个取消
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      final res = await AiConversationService().regenerateMessage(
        sessionId: sessionId,
        taskId: m.id,
        providerOverride: aiHubProvider(),
        systemPromptOverride: await _systemPromptFor(
          _state,
          scanText: m.inputContent,
        ),
        paramsOverride: _storyParams(),
        contextBudgetOverride: story.contextBudgetChars,
        extraDepthHits: _storyDepthHits,
      );
      if (!mounted) return;
      if (!res.success) {
        App.rootContext.showMessage(
          message: res.errorMessage ?? '',
          level: LogLevel.error,
        );
        return;
      }
      await _applyState(_parseReply(res.data).state);
      await _applyFoldedVariables();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// 候选切换（swipe）导航
  Widget _variantNav(AiTask m, List<String> variants) {
    final index = m.variantIndex.clamp(0, variants.length - 1);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: t.back,
            onPressed: index <= 0
                ? null
                : () => _selectVariant(m, variants, index - 1),
          ),
          Text(
            '${index + 1}/${variants.length}',
            style: const TextStyle(fontSize: 11),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: t.next,
            onPressed: index >= variants.length - 1
                ? null
                : () => _selectVariant(m, variants, index + 1),
          ),
        ],
      ),
    );
  }

  Future<void> _selectVariant(
    AiTask m,
    List<String> variants,
    int index,
  ) async {
    await AiConversationService().selectVariant(m.id, variants, index);
    await _applyState(_parseReply(variants[index]).state);
    await _applyFoldedVariables();
  }

  /// 后台为未登记的道具补全图鉴设定（不进入当前对话上下文）
  Future<void> _registerUnregistered() async {
    if (_unregistered.isEmpty || _registering) return;
    await _generateCodex(List<String>.from(_unregistered));
  }

  /// 用 AI 为缺失设定的物品/技能批量生成词条（单个也走这里）
  Future<GameState?> _generateCodex(
    List<String> items, {
    String kind = 'item',
  }) async {
    if (items.isEmpty || _registering) return null;
    setState(() => _registering = true);
    try {
      final res = await AiConversationService().runTask(
        provider: aiHubProvider(),
        taskType: 'story_codex',
        sessionTitle: t.storyRegisterItems,
        systemPrompt: t.storyCodexSystem,
        prompt:
            '${t.storyCodexPrompt}\n'
            '{"codex":[{"kind":"$kind","key":"名称","name":"名称",'
            '"display":"玩家可见描述","mechanics":"机制/数值"}]}\n'
            '${t.storyCodexItems}（kind 用 $kind）：${items.join('、')}',
      );
      if (!mounted) return null;
      if (!res.success) {
        App.rootContext.showMessage(
          message: res.errorMessage ?? '',
          level: LogLevel.error,
        );
        return null;
      }
      final defs = _parseCodexDefs(res.data);
      if (defs.isEmpty) {
        // 模型没给出设定：仍然清掉本次提示，避免反复弹出
        setState(() {
          _unregistered = _unregistered
              .where((i) => !items.contains(i))
              .toList();
        });
        App.rootContext.showMessage(
          message: t.characterImportFailed,
          level: LogLevel.warning,
        );
        return null;
      }
      final codex = [..._state.codex];
      for (final d in defs) {
        final idx = codex.indexWhere(
          (x) => x.kind == d.kind && x.key == d.key,
        );
        if (idx >= 0) {
          codex[idx] = d;
        } else {
          codex.add(d);
        }
      }
      final next = _state.copyWith(codex: codex);
      setState(() {
        _state = next;
        // 已成功合并的不再命中；失败的本次也不再提示
        _unregistered = _unregisteredFrom(next)
            .where((i) => !items.contains(i))
            .toList();
      });
      final sessionId = _sessionId;
      if (sessionId != null) {
        await StorySessionStore.instance.put(
          story.id,
          StorySession(sessionId: sessionId, state: next),
        );
      }
      return next;
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  /// 从模型输出里解析 codex 定义
  List<StoryDefinition> _parseCodexDefs(String text) {
    final matches = RegExp(
      r'```json\s*([\s\S]*?)```',
      caseSensitive: false,
    ).allMatches(text).toList();
    final candidates = <String>[
      if (matches.isNotEmpty) matches.last.group(1)!.trim(),
      text.trim(),
    ];
    // 兜底：截取文本里的第一段 {...} / [...]
    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart >= 0 && objEnd > objStart) {
      candidates.add(text.substring(objStart, objEnd + 1));
    }
    final arrStart = text.indexOf('[');
    final arrEnd = text.lastIndexOf(']');
    if (arrStart >= 0 && arrEnd > arrStart) {
      candidates.add(text.substring(arrStart, arrEnd + 1));
    }
    for (final c in candidates) {
      try {
        final decoded = jsonDecode(c);
        if (decoded is Map && decoded['codex'] is List) {
          return [
            for (final e in decoded['codex'] as List)
              if (e is Map) StoryDefinition.fromJson(e.cast<String, dynamic>()),
          ];
        }
        if (decoded is List) {
          return [
            for (final e in decoded)
              if (e is Map) StoryDefinition.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {}
    }
    return const [];
  }

  void _sendInput() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final check = _pendingCheck;
    _input.clear();
    // 发送后收起键盘：否则移动端会一直占着输入法空间
    _inputFocus.unfocus();
    if (check) setState(() => _pendingCheck = false);
    _send(check ? '$kStoryCheckMarker$text' : text, check: check);
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
      appBar: Appbar(
        title: Text(story.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields_outlined),
            tooltip: t.storyTextStyle,
            onPressed: _showTextStyleSheet,
          ),
          // 便于排查问题：直接打开 AI 请求日志（仅图标，文字在 tooltip）
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: t.aiRequestLog,
            onPressed: () =>
                showPopUpWidget(App.rootContext, const AiRequestLogPage()),
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
                final showPendingUser =
                    _pendingUserText != null &&
                    (messages.isEmpty ||
                        messages.last.role != 'user' ||
                        messages.last.inputContent != _pendingUserText);
                if (messages.length != _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                }
                _lastTurnPending =
                    messages.isNotEmpty && messages.last.role == 'user';
                return Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: NotificationListener<ScrollNotification>(
                        onNotification: _onUserScroll,
                        // 列表铺满整宽，内容用左右留白居中：
                        // 这样鼠标滚轮/拖动在两侧空白处也能滚动
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxW = _chatContentMaxWidth(context);
                            final side = constraints.maxWidth > maxW
                                ? (constraints.maxWidth - maxW) / 2
                                : 12.0;
                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: EdgeInsets.symmetric(
                                horizontal: side,
                                vertical: 12,
                              ),
                              itemCount:
                                  messages.length +
                                  (showPendingUser ? 1 : 0) +
                                  (_showStreamBubble ? 1 : 0),
                              itemBuilder: (context, raw) {
                              final i =
                                  messages.length +
                                  (showPendingUser ? 1 : 0) +
                                  (_showStreamBubble ? 1 : 0) -
                                  1 -
                                  raw;
                              if (showPendingUser && i == messages.length) {
                                final persona = story.persona;
                                return _StoryBubble(
                                  content: _pendingUserText!,
                                  isUser: true,
                                  headerName: persona.name.trim().isEmpty
                                      ? t.storyPersona
                                      : persona.name.trim(),
                                  // 玩家消息显示游戏内时间，而不是现实时间
                                  headerTime: _state.time,
                                  headerAvatar: persona.avatar,
                                );
                              }
                              if (i ==
                                  messages.length + (showPendingUser ? 1 : 0)) {
                                final streamNarrative = applyStoryRegex(
                                  _parseReply(_streamText).narrative,
                                  story.regexes,
                                  'display',
                                );
                                if (streamNarrative.trim().isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: PolygonRefreshIndicator(),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            t.storyThinking,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final b in _blocksFromNarrative(
                                      streamNarrative,
                                    ))
                                      _buildBlock(b, depth: 0),
                                    // 事件/检定卡片要等 JSON 生成完才出现，这里提示仍在生成
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: PolygonRefreshIndicator(),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              t.storyAssemblingData,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                              final m = messages[i];
                              final isUser = m.role == 'user';
                              final parsed = isUser
                                  ? null
                                  : _parseReply(m.outputContent ?? '');
                              final check = parsed?.check;
                              final variants = isUser
                                  ? const <String>[]
                                  : AiConversationService.variantsOf(m);
                              final showCheck =
                                  !isUser &&
                                  check != null &&
                                  i == messages.length - 1 &&
                                  !_sending;
                              final persona = story.persona;
                              final blocks =
                                  parsed?.blocks ?? const <StoryBlock>[];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    onLongPress: () => _messageMenu(m),
                                    child: isUser
                                        ? (m.inputContent.startsWith(
                                                kStoryDiceMarker,
                                              )
                                              ? _DiceResultCard(
                                                  text: m.inputContent
                                                      .substring(
                                                        kStoryDiceMarker.length,
                                                      ),
                                                )
                                              : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    _StoryBubble(
                                                      content: m.inputContent
                                                              .startsWith(
                                                                kStoryCheckMarker,
                                                              )
                                                          ? m.inputContent
                                                                .substring(
                                                                  kStoryCheckMarker
                                                                      .length,
                                                                )
                                                          : m.inputContent,
                                                      isUser: true,
                                                      headerName: persona.name
                                                              .trim()
                                                              .isEmpty
                                                          ? t.storyPersona
                                                          : persona.name.trim(),
                                                      headerTime: _state.time,
                                                      headerAvatar:
                                                          persona.avatar,
                                                    ),
                                                    if (m.inputContent
                                                        .startsWith(
                                                          kStoryCheckMarker,
                                                        ))
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 2,
                                                              right: 4,
                                                            ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons.bolt,
                                                              size: 12,
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.tertiary,
                                                            ),
                                                            const SizedBox(
                                                              width: 3,
                                                            ),
                                                            Text(
                                                              t.storySpecialCheck,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Theme.of(
                                                                  context,
                                                                ).colorScheme.tertiary,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ))
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // 内容块：旁白 / 对白 / 事件 / 检定
                                              for (final b in blocks)
                                                _buildBlock(
                                                  b,
                                                  depth: messages.length - 1 - i,
                                                  showCheck: showCheck,
                                                ),
                                              AiUsageMeta(task: m),
                                            ],
                                          ),
                                  ),
                                  _messageFooter(m),
                                  if (variants.length > 1)
                                    _variantNav(m, variants),
                                ],
                              );
                            },
                          );
                          },
                            ),
                          ),
                          ),
                          // 展开时点其它地方即收起
                          if (choices.isNotEmpty &&
                              _suggestExpanded &&
                              !_state.gameOver)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(
                                  () => _suggestExpanded = false,
                                ),
                              ),
                            ),
                          // 追问建议：浮在对话内容之上（不占内容区高度）
                          if (choices.isNotEmpty && !_state.gameOver)
                            Positioned(
                              right: 12,
                              bottom: 8,
                              child: AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                alignment: Alignment.bottomRight,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  switchInCurve: Curves.easeOutBack,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: Tween<double>(
                                            begin: 0.9,
                                            end: 1,
                                          ).animate(anim),
                                          alignment: Alignment.bottomRight,
                                          child: child,
                                        ),
                                      ),
                                  child: _suggestExpanded
                                      ? _suggestPanel(choices)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (story.characters.isNotEmpty ||
                        (choices.isNotEmpty && !_state.gameOver))
                      Builder(
                        builder: (context) {
                          final presentChars = [
                            for (final c in story.characters)
                              if (_state.present.any((n) => _isNameFor(c, n)))
                                c,
                          ];
                          final showSuggest =
                              choices.isNotEmpty && !_state.gameOver;
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                            child: SizedBox(
                              height: 34,
                              child: Row(
                                children: [
                                  // NPC 卡片：多了就横向滑动
                                  if (presentChars.isNotEmpty)
                                    Expanded(
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: presentChars.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(width: 8),
                                        itemBuilder: (_, i) {
                                          final c = presentChars[i];
                                          return ActionChip(
                                            avatar: CharacterAvatar(
                                              name: c.displayName,
                                              avatar: c.avatar,
                                              radius: 10,
                                              enablePreview: false,
                                            ),
                                            label: Text(c.displayName),
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                            onPressed: () =>
                                                _characterMenu(c),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    const Spacer(),
                                  // 追问建议入口：固定在 NPC 一栏最右边
                                  if (showSuggest) _suggestToggle(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    if (_unregistered.isNotEmpty && !_sending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${t.storyUnregisteredItems}: '
                                '${_unregistered.join('、')}',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_registering)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: PolygonRefreshIndicator(size: 16),
                              )
                            else
                              TextButton(
                                onPressed: _registerUnregistered,
                                child: Text(t.storyRegisterItems),
                              ),
                          ],
                        ),
                      ),
                    if ((_lastFailed || _lastTurnPending) && !_sending)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                t.storyResponseFailed,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: _retryLast,
                              child: Text(t.retry),
                            ),
                          ],
                        ),
                      ),
                    if (_state.gameOver)
                      _gameOverBar(context)
                    else
                      _AiComposerBar(
                      controller: _input,
                      focusNode: _inputFocus,
                      onSend: _sendInput,
                      sending: _sending,
                      onStop: () => _cancelToken?.cancel(),
                      hintText: t.storyInput,
                      bottomLeading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ModelSelector(
                            provider: aiHubProvider(),
                            onProviderChanged: (p) {
                              setAiHubProvider(p);
                              setState(() {});
                            },
                          ),
                          // 已选择「特殊判定」：在模型图标旁显示，点击可取消
                          if (_pendingCheck)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: ActionChip(
                                avatar: const Icon(Icons.bolt, size: 14),
                                label: Text(
                                  t.storySpecialCheck,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _pendingCheck = false),
                              ),
                            ),
                        ],
                      ),
                      bottomTrailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isFollowing)
                            IconButton(
                              icon: const Icon(Icons.arrow_downward),
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              tooltip: t.jumpToBottom,
                              onPressed: () {
                                setState(() => _isFollowing = true);
                                _scrollToBottom(force: true);
                              },
                            ),
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

  /// 字段当前可选项：有 dependsOn 时按被依赖字段的当前值取，否则用自身 options
  List<String> _partOptions(StorySetupPart p) {
    if (p.dependsOn.isEmpty) return p.options;
    final owner = _singleValues[p.dependsOn] ?? '';
    return p.optionsBy[owner] ?? const [];
  }

  /// 依赖字段还没选 / 无可选项时，整个字段先不显示（避免出现空白项）
  bool _partVisible(StorySetupPart p) {
    if (p.dependsOn.isEmpty) return true;
    if ((_singleValues[p.dependsOn] ?? '').isEmpty) return false;
    return _partOptions(p).isNotEmpty;
  }

  /// 「自定义」选项补充输入的内容
  String _customText(StorySetupPart p) =>
      _customValues[p.key]?.text.trim() ?? '';

  /// 单选的最终值：选「自定义」且有补充输入时用补充内容
  String _singleValueText(StorySetupPart p) {
    final sel = _singleValues[p.key] ?? '';
    if (sel != _customOption) return sel;
    final custom = _customText(p);
    return custom.isEmpty ? _customOption : custom;
  }

  /// 多选的最终值：「自定义」项用补充输入替换
  String _multiValueText(StorySetupPart p) {
    final selected = _multiValues[p.key] ?? const <String>{};
    final out = <String>[];
    for (final o in selected) {
      if (o == _customOption) {
        final custom = _customText(p);
        out.add(custom.isEmpty ? _customOption : custom);
      } else {
        out.add(o);
      }
    }
    return out.join('、');
  }

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
    // 已设置玩家角色卡的名字时，跳过开局设置里的 name 字段（{{user}} 优先用角色卡）
    final personaName =
        StoryCharacterStore.instance.persona(story.id)?.name.trim() ?? '';
    final setupParts = [
      for (final p in story.setup)
        if (!(personaName.isNotEmpty && p.key == 'name')) p,
    ];
    final groups = <String, List<StorySetupPart>>{};
    for (final p in setupParts) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    return Scaffold(
      appBar: Appbar(title: Text(story.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (story.description.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.toOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      story.description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final entry in groups.entries)
            _setupSection(context, entry.key, entry.value),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startWithSetup,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  t.storyStart,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 一个分组：卡片式容器（标题 + 剩余点数 + 掷骰 + 字段）
  Widget _setupSection(
    BuildContext context,
    String title,
    List<StorySetupPart> parts,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final visible = [for (final p in parts) if (_partVisible(p)) p];
    if (visible.isEmpty) return const SizedBox.shrink();
    final pool = _groupPool(parts);
    final hasNumber = parts.any((p) => p.type == 'number');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty || pool != null || hasNumber)
              Row(
                children: [
                  if (title.isNotEmpty)
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (pool != null)
                    Container(
                      margin: const EdgeInsets.only(right: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${t.storyPointsLeft} ${pool - _groupAllocated(parts)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (hasNumber)
                    IconButton(
                      icon: const Icon(Icons.casino_outlined, size: 18),
                      tooltip: t.storyRoll,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _rollGroup(parts),
                    ),
                ],
              ),
            for (final part in visible) _buildPart(context, part, parts),
          ],
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final title = part.required ? '${part.title} *' : part.title;

    final Widget content;
    if (part.type == 'number') {
      content = Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: () => _bumpNumber(part, -1, group),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            alignment: Alignment.center,
            child: Text(
              '${_partNumber(part)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            visualDensity: VisualDensity.compact,
            onPressed: () => _bumpNumber(part, 1, group),
          ),
        ],
      );
    } else if (part.type == 'text') {
      content = _setupTextField(
        _textValues.putIfAbsent(part.key, () => TextEditingController()),
        part.hint,
      );
    } else if (part.type == 'multi') {
      final selected = _multiValues[part.key] ?? const <String>{};
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapsuleChipGroup(
            children: [
              for (final o in part.options)
                CapsuleChip(
                  text: o,
                  isSelected: selected.contains(o),
                  onLongPress: () => _showOptionHint(o),
                  onTap: () => setState(() {
                    final set = _multiValues.putIfAbsent(part.key, () => {});
                    if (set.contains(o)) {
                      set.remove(o);
                    } else {
                      set.add(o);
                    }
                  }),
                ),
            ],
          ),
          if (selected.contains(_customOption))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _setupTextField(
                _customValues.putIfAbsent(
                  part.key,
                  () => TextEditingController(),
                ),
                t.storyCustomize,
              ),
            ),
        ],
      );
    } else {
      final selected = _singleValues[part.key] ?? '';
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapsuleChipGroup(
            children: [
              for (final o in _partOptions(part))
                CapsuleChip(
                  text: o,
                  isSelected: selected == o,
                  onLongPress: () => _showOptionHint(o),
                  onTap: () => setState(() {
                    _singleValues[part.key] = o;
                    // 换了被依赖项 → 依赖它的选择要重来（如换主职 → 子职重选）
                    for (final q in story.setup) {
                      if (q.dependsOn == part.key) _singleValues.remove(q.key);
                    }
                  }),
                ),
            ],
          ),
          if (selected == _customOption)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _setupTextField(
                _customValues.putIfAbsent(
                  part.key,
                  () => TextEditingController(),
                ),
                t.storyCustomize,
              ),
            ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (part.hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: GestureDetector(
                      onTap: () => _showHintDialog(part.title, part.hint),
                      onLongPress: () => _showHintDialog(part.title, part.hint),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          content,
        ],
      ),
    );
  }

  Widget _setupTextField(TextEditingController controller, String? hint) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.edit_outlined, size: 18),
        ),
      );

  /// 长按选项：弹出该选项的说明（世界书里的固定条目）
  void _showOptionHint(String name) {
    if (name == _customOption) return;
    final hint = _fixedHints[name];
    if (hint == null || hint.isEmpty) return;
    _showHintDialog(name, hint);
  }

  /// 只读说明弹窗（内容可能较长，用 ContentDialog 而非 tooltip）
  Future<void> _showHintDialog(String title, String text) {
    return ContentDialog.show<void>(
      context: App.rootContext,
      title: title,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 380),
        child: SingleChildScrollView(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      displayButton: false,
      isDismissible: true,
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
    var narrative = content;
    GameState? state;
    var choices = <String>[];
    var events = <StoryEvent>[];
    var varOps = <VarOp>[];
    StoryCheck? check;

    Map<String, dynamic>? decoded;
    // 1) 代码块：不限定 ```json，兼容 ``` / ```JSON / ```markdown 等标记，
    //    取最后一个「像状态块」的（含 state/choices/events/varOps/check）
    final fenceRe = RegExp(r'```[ \t]*[a-zA-Z]*[ \t]*\r?\n?([\s\S]*?)```');
    for (final m in fenceRe.allMatches(content).toList().reversed) {
      final d = _tryDecodeStateJson(m.group(1)?.trim() ?? '');
      if (d != null) {
        decoded = d;
        narrative = content.replaceRange(m.start, m.end, '').trim();
        break;
      }
    }
    // 2) 没有代码块时，尝试末尾的裸 JSON 对象（有些模型不加围栏）
    if (decoded == null) {
      final bare = _trailingJsonObject(content);
      if (bare != null) {
        final d = _tryDecodeStateJson(bare.$1);
        if (d != null) {
          decoded = d;
          narrative = content.substring(0, bare.$2).trim();
        }
      }
    }
    if (decoded != null) {
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
      if (decoded['check'] is Map) {
        check = StoryCheck.fromJson(
          (decoded['check'] as Map).cast<String, dynamic>(),
        );
      }
      final vo = decoded['varOps'];
      if (vo is List) varOps = [for (final e in vo) VarOp.fromJson(e)];
    } else if ('```'.allMatches(content).length.isOdd) {
      // 流式过程中可能出现未闭合的代码块，先隐藏
      narrative = content.substring(0, content.lastIndexOf('```')).trim();
    }
    return _ParsedReply(
      narrative: narrative,
      state: state,
      choices: choices,
      events: events,
      varOps: varOps,
      check: check,
      blocks: _buildBlocks(narrative, events, check),
    );
  }

  /// 把正文 + 事件 + 检定拼成内容块列表
  List<StoryBlock> _buildBlocks(
    String narrative,
    List<StoryEvent> events,
    StoryCheck? check,
  ) {
    final out = _blocksFromNarrative(narrative);
    for (final e in events) {
      out.add(StoryBlock.event(e));
    }
    if (check != null) out.add(StoryBlock.check(check));
    return out;
  }

  /// 正文 → 块：旁白 / 对白（〖角色〗）/ 引用块提示（`> `）
  List<StoryBlock> _blocksFromNarrative(String narrative) {
    final out = <StoryBlock>[];
    for (final seg in _splitSegments(narrative)) {
      if (seg.type == 'npc') {
        out.add(StoryBlock.dialogue(seg.name, seg.text));
      } else {
        out.addAll(_splitCallouts(seg.text));
      }
    }
    return out;
  }

  /// 把一段旁白按 `> ` 引用块拆成 callout / narration 块
  List<StoryBlock> _splitCallouts(String text) {
    final out = <StoryBlock>[];
    final cur = StringBuffer();
    var inQuote = false;
    void flush() {
      final t = cur.toString().trim();
      if (t.isNotEmpty) {
        out.add(inQuote ? StoryBlock.callout(t) : StoryBlock.narration(t));
      }
      cur.clear();
    }

    for (final line in text.split('\n')) {
      final m = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
      final isQuote = m != null;
      if (isQuote != inQuote && cur.isNotEmpty) flush();
      inQuote = isQuote;
      if (cur.isNotEmpty) cur.write('\n');
      cur.write(isQuote ? m.group(1) : line);
    }
    flush();
    return out;
  }

  /// 解析出「像状态块」的 JSON 对象（含 state/choices/events/varOps/check 之一）
  Map<String, dynamic>? _tryDecodeStateJson(String body) {
    if (body.isEmpty || !body.startsWith('{')) return null;
    try {
      final d = jsonDecode(body);
      if (d is! Map) return null;
      const keys = ['state', 'choices', 'events', 'varOps', 'check'];
      if (keys.any(d.containsKey)) return d.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  /// 从文本末尾找一个平衡的 JSON 对象 → (JSON 文本, 起始下标)
  (String, int)? _trailingJsonObject(String content) {
    final end = content.lastIndexOf('}');
    if (end < 0) return null;
    var depth = 0;
    for (var i = end; i >= 0; i--) {
      final ch = content[i];
      if (ch == '}') {
        depth++;
      } else if (ch == '{') {
        depth--;
        if (depth == 0) {
          final candidate = content.substring(i, end + 1);
          const marks = ['"state"', '"choices"', '"events"', '"varOps"'];
          if (marks.any(candidate.contains)) return (candidate, i);
          return null;
        }
      }
    }
    return null;
  }

  /// 渲染单个内容块。新增块类型只需在这里登记渲染方式，不必改消息列表。
  Widget _buildBlock(
    StoryBlock b, {
    required int depth,
    bool showCheck = false,
  }) {
    final s = story;
    String rx(String t) => applyStoryRegex(t, s.regexes, 'display', depth: depth);
    switch (b.type) {
      case 'dialogue':
        return _NpcBubble(
          name: b.name,
          content: rx(b.text),
          avatar: _avatarForName(b.name),
        );
      case 'callout':
        return _StoryCallout(text: rx(b.text));
      case 'event':
        final e = b.event;
        return e == null ? const SizedBox.shrink() : _StoryEventCard(event: e);
      case 'check':
        final c = b.check;
        if (c == null || !showCheck) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: _StoryCheckCard(check: c, onRoll: () => _rollCheck(c)),
        );
      default:
        return _StoryBubble(content: rx(b.text), isUser: false);
    }
  }

  /// 把正文拆成旁白 / 角色片段（〖角色：名字〗...〖/角色〗）。
  /// 容错：结束标记可缺失（也接受 〖/名字〗 / 【角色：名字】）。
  /// 有结束标记 → 整段算该角色；无结束标记 → 按段落判断，
  /// 只把含引号对白的段落算角色发言，纯旁白（含【提示】）拆出来。
  List<StorySegment> _splitSegments(String text) {
    final openRe = RegExp(r'[〖【]\s*角色\s*[:：]\s*([^〗】]+?)\s*[〗】]');
    final segments = <StorySegment>[];
    var index = 0;
    while (index < text.length) {
      final open = openRe.firstMatch(text.substring(index));
      if (open == null) break;
      final openStart = index + open.start;
      final bodyStart = index + open.end;
      final before = text.substring(index, openStart).trim();
      if (before.isNotEmpty) {
        segments.add(StorySegment(type: 'narration', text: before));
      }
      final rest = text.substring(bodyStart);
      final name = open.group(1)!.trim();
      final closeRe = RegExp(
        '[〖【]\\s*/\\s*(?:角色|${RegExp.escape(name)})\\s*[〗】]',
      );
      final nextOpen = openRe.firstMatch(rest);
      final nextClose = closeRe.firstMatch(rest);
      var endRel = rest.length;
      var closed = false;
      if (nextOpen != null) endRel = nextOpen.start;
      if (nextClose != null && nextClose.start < endRel) {
        endRel = nextClose.start;
        closed = true;
      }
      final body = rest.substring(0, endRel).trim();
      if (body.isNotEmpty) {
        _splitNpcBody(segments, name, body, closed: closed);
      }
      index = bodyStart + endRel;
      if (closed && nextClose != null) {
        index += nextClose.end - nextClose.start;
      }
    }
    if (index < text.length) {
      final after = text.substring(index).trim();
      if (after.isNotEmpty) {
        segments.add(StorySegment(type: 'narration', text: after));
      }
    }
    if (segments.isEmpty && text.trim().isNotEmpty) {
      segments.add(StorySegment(type: 'narration', text: text.trim()));
    }
    return segments;
  }

  /// 角色块拆段。
  /// - 有结束标记：气泡里**只保留引号内的对白**，引号外的动作/描写算旁白；
  /// - 无结束标记：从第一个"不以引号开头"的段落起，之后一律算旁白
  ///   （避免把随后的旁白、拟声词如 "啪嗒啪嗒" 误当成角色发言）；
  /// - 整段没有引号时（对白未加引号）整段仍算角色。
  void _splitNpcBody(
    List<StorySegment> segments,
    String name,
    String body, {
    required bool closed,
  }) {
    if (!_speechRe.hasMatch(body)) {
      // 没有引号：有结束标记才算角色发言，否则视为旁白
      // （模型常把动作描写也塞进 〖角色〗 标记里）
      segments.add(
        StorySegment(
          type: closed ? 'npc' : 'narration',
          name: name,
          text: body.trim(),
        ),
      );
      return;
    }
    if (closed) {
      for (final p in body.split(RegExp(r'\n\s*\n'))) {
        final t = p.trim();
        if (t.isEmpty) continue;
        if (_looksLikeCallout(t)) {
          segments.add(StorySegment(type: 'narration', text: t));
        } else {
          _splitByQuotes(segments, name, t);
        }
      }
      return;
    }
    // 无结束标记：从第一个"不以引号开头"的段落起，之后一律算旁白；
    // 之前的对白段落仍按引号切分，把中间的旁白动作也拆出来
    var ended = false;
    for (final p in body.split(RegExp(r'\n\s*\n'))) {
      final t = p.trim();
      if (t.isEmpty) continue;
      if (!ended && !_looksLikeCallout(t) && _startsWithQuote(t)) {
        _splitByQuotes(segments, name, t);
      } else {
        ended = true;
        segments.add(StorySegment(type: 'narration', text: t));
      }
    }
  }

  static final _quoteStartRe = RegExp(r'^[“"「『]');

  static bool _startsWithQuote(String s) =>
      _quoteStartRe.hasMatch(s.trimLeft());

  /// 把一段文字按引号切分：引号内 → 角色，引号外 → 旁白
  void _splitByQuotes(List<StorySegment> segments, String name, String text) {
    final matches = _speechRe.allMatches(text).toList();
    if (matches.isEmpty) {
      segments.add(StorySegment(type: 'narration', text: text.trim()));
      return;
    }
    var index = 0;
    final npcBuf = <String>[];
    void flush() {
      if (npcBuf.isEmpty) return;
      segments.add(StorySegment(type: 'npc', name: name, text: npcBuf.join(' ')));
      npcBuf.clear();
    }

    for (final m in matches) {
      final before = text.substring(index, m.start).trim();
      if (before.isNotEmpty) {
        flush();
        segments.add(StorySegment(type: 'narration', text: before));
      }
      npcBuf.add(m.group(0)!);
      index = m.end;
    }
    final after = text.substring(index).trim();
    if (after.isNotEmpty) {
      flush();
      segments.add(StorySegment(type: 'narration', text: after));
    }
    flush();
  }

  static final _speechRe = RegExp(r'[“"「『][^”"」』]*[”"」』]');

  /// 提示框（`>` 引用块 / 【标签】开头）无论是否含引号都算旁白
  static bool _looksLikeCallout(String s) {
    final t = s.trimLeft();
    if (t.startsWith('>')) return true;
    if (t.startsWith('【')) {
      final close = t.indexOf('】');
      if (close > 1 && close <= 12) return true;
    }
    return false;
  }

  /// 文字样式设置：引号高亮 / 阴影 / 字体 / 字号
  Future<void> _showTextStyleSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.storyTextStyle,
        icon: Icons.text_fields_outlined,
        initialSize: 0.78,
        builder: (ctx, sc) => ListenableBuilder(
          listenable: StoryTextStyleStore.instance,
          builder: (ctx, _) {
            final store = StoryTextStyleStore.instance;
            final s = store.style;
            final scheme = Theme.of(ctx).colorScheme;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            Color preview(StoryRoleStyle r, Color fallback) {
              final v = isDark ? r.dark : r.light;
              return v == null ? fallback : Color(v);
            }

            StoryRoleStyle withColor(StoryRoleStyle r, Color c) => isDark
                ? r.copyWith(dark: c.toARGB32())
                : r.copyWith(light: c.toARGB32());

            Widget roleTile(
              String label,
              StoryRoleStyle role,
              StoryRoleStyle defaultRole,
              Color fallback,
              ValueChanged<StoryRoleStyle> onChanged, {
              bool allowFontStyle = true,
            }) {
              final color = preview(role, fallback);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          final c = await showDialog<Color>(
                            context: App.rootContext,
                            builder: (_) => ColorPickPage(initialColor: color),
                          );
                          if (c != null) onChanged(withColor(role, c));
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restart_alt, size: 18),
                        tooltip: t.reset,
                        onPressed: () => onChanged(defaultRole),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        t.storyOpacity,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: role.opacity,
                          min: 0.1,
                          max: 1.0,
                          divisions: 9,
                          label: '${(role.opacity * 100).round()}%',
                          onChanged: (v) =>
                              onChanged(role.copyWith(opacity: v)),
                        ),
                      ),
                    ],
                  ),
                  if (allowFontStyle)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (value, name) in [
                          ('normal', t.storyNormal),
                          ('italic', t.storyItalic),
                          ('bold', t.storyBold),
                        ])
                          OptionChip(
                            text: name,
                            isSelected: role.fontStyle == value,
                            onTap: () =>
                                onChanged(role.copyWith(fontStyle: value)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              );
            }

            return ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Text(
                      t.storyQuoteGlyph,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Select(
                      current: s.quoteGlyph.label,
                      values: [
                        for (final g in StoryQuoteGlyph.values) g.label,
                      ],
                      onTap: (idx) => store.update(
                        s.copyWith(
                          quoteGlyph: StoryQuoteGlyph.values[idx],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                roleTile(
                  t.storyQuote,
                  s.quote,
                  StoryTextStyle.defaults.quote,
                  scheme.primary,
                  (r) => store.update(s.copyWith(quote: r)),
                ),
                roleTile(
                  t.storyBracket,
                  s.bracket,
                  StoryTextStyle.defaults.bracket,
                  scheme.onSurfaceVariant,
                  (r) => store.update(s.copyWith(bracket: r)),
                ),
                roleTile(
                  t.storyItalic,
                  s.italic,
                  StoryTextStyle.defaults.italic,
                  scheme.onSurfaceVariant,
                  (r) => store.update(s.copyWith(italic: r)),
                  allowFontStyle: false,
                ),
                roleTile(
                  t.storyBold,
                  s.bold,
                  StoryTextStyle.defaults.bold,
                  scheme.onSurface,
                  (r) => store.update(s.copyWith(bold: r)),
                  allowFontStyle: false,
                ),
                const Divider(),
                _toggleRow(
                  t.storyShadow,
                  Icons.blur_on_outlined,
                  s.shadow,
                  (v) => store.update(s.copyWith(shadow: v)),
                ),
                _toggleRow(
                  t.storySystemFont,
                  Icons.font_download_outlined,
                  s.systemFont,
                  (v) => store.update(s.copyWith(systemFont: v)),
                ),
                Row(
                  children: [
                    Text(t.storyFontSize),
                    Expanded(
                      child: Slider(
                        value: s.fontScale,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: '${(s.fontScale * 100).round()}%',
                        onChanged: (v) => store.update(s.copyWith(fontScale: v)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 游戏结束条：提示 + 重新开始
  Widget _gameOverBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.dangerous_outlined, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.storyGameOver,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: _restartGame,
            child: Text(t.storyRestart),
          ),
        ],
      ),
    );
  }

  Future<void> _restartGame() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      await AiConversationService().deleteSession(sessionId);
    }
    await StorySessionStore.instance.clear(story.id);
    if (!mounted) return;
    setState(() {
      _sessionId = null;
      _state = GameState.empty;
      _unregistered = const [];
      _lastMessageCount = 0;
      _booting = true;
      _needsSetup = false;
    });
    await _boot();
  }

  /// 项目风格开关行
  Widget _toggleRow(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
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
    // 打开详情前先失焦：否则关闭 sheet 后焦点回到输入框会重新唤起输入法
    _inputFocus.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _StoryDetailsSheet(
        story: story,
        state: state,
        onCommand: _send,
        onGenerateCodex: (items, kind) => _generateCodex(items, kind: kind),
      ),
    );
  }

  /// 「更多」：内置掷骰 + 故事自定义操作按钮（一键 / 批量等）
  Future<void> _showMore() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Sheet(
        title: t.storyMore,
        icon: Icons.more_horiz,
        initialSize: 0.5,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: Text(t.storySpecialCheck),
              subtitle: Text(
                t.storyCheckPending,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _pendingCheck = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.casino_outlined),
              title: Text(t.storyManualRoll),
              onTap: () {
                Navigator.of(ctx).pop();
                _manualRoll();
              },
            ),
            if (_state.combat.active)
              ListTile(
                leading: const Icon(Icons.skip_next_outlined),
                title: Text(t.storyNextRound),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _send(t.storyCmdNextRound);
                },
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
            if (story.actions.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  t.storyNoActions,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 展示掷骰结果弹窗
  Future<void> _showRollResult(DiceRoll roll, String title) async {
    await ContentDialog.show<void>(
      context: App.rootContext,
      title: title,
      content: Text(
        roll.detail,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(App.rootContext).pop(),
          child: Text(t.confirm),
        ),
      ],
    );
  }

  /// 优势/劣势：单骰记法改成 2dMkh1 / 2dMkl1（取高 / 取低）
  String _withAdvantage(String dice, String mode) {
    final m = RegExp(r'^\s*(\d*)\s*[dD]\s*(\d+)\s*$').firstMatch(dice);
    if (m == null) return dice;
    final count = int.tryParse(m.group(1) ?? '') ?? 1;
    if (count != 1) return dice;
    return '2d${m.group(2)}${mode == 'high' ? 'kh1' : 'kl1'}';
  }

  /// 执行 AI 声明的检定：项目掷骰，再把结果回传给 GM
  Future<void> _rollCheck(StoryCheck check) async {
    if (_sending) return;
    final dice = check.advantage == null
        ? check.dice
        : _withAdvantage(check.dice, check.advantage!);
    final roll = rollDice(
      dice,
      modifier: check.modifier,
      dc: check.dc,
      crits: story.crits,
      direction: story.checkDirection,
    );
    await _showRollResult(roll, check.label.isEmpty ? t.storyRoll : check.label);
    if (!mounted) return;
    await _send(
      '$kStoryDiceMarker${t.storyCmdCheckResult(label: check.label, detail: roll.detail)}',
    );
  }

  /// 解析 NdM 记法 → (数量, 面数)
  (int, int) _parseDiceNotation(String notation) {
    final m = RegExp(r'^\s*(\d+)\s*[dD]\s*(\d+)\s*$').firstMatch(notation);
    if (m == null) return (1, 20);
    return (
      (int.tryParse(m.group(1)!) ?? 1).clamp(1, 20),
      (int.tryParse(m.group(2)!) ?? 20).clamp(2, 1000),
    );
  }

  /// 手动掷骰：从当前属性里选一项 + 输入 DC
  Future<void> _manualRoll() async {
    final entries = _state.attributes.entries.toList();
    if (entries.isEmpty) {
      App.rootContext.showMessage(
        message: t.storyNoAttributes,
        level: LogLevel.warning,
      );
      return;
    }
    var index = 0;
    var sides = 20;
    final dcCtrl = TextEditingController(text: '12');
    final countCtrl = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.storyRoll,
        content: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (story.dice.isNotEmpty) ...[
                Text(
                  t.storyDiceLibrary,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in story.dice)
                      OptionChip(
                        text: d.name,
                        isSelected: false,
                        onTap: () {
                          final (c, s) = _parseDiceNotation(d.dice);
                          countCtrl.text = '$c';
                          setLocal(() => sides = s);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(t.storyRollDice, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in const [4, 6, 8, 10, 12, 20, 100])
                    OptionChip(
                      text: 'd$s',
                      isSelected: sides == s,
                      onTap: () => setLocal(() => sides = s),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: t.storyRollCount,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(t.storyRollAttribute, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < entries.length; i++)
                    OptionChip(
                      text: '${entries[i].key} ${entries[i].value}',
                      isSelected: index == i,
                      onTap: () => setLocal(() => index = i),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dcCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'DC',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.storyRoll),
          ),
        ],
      ),
    );
    final dc = int.tryParse(dcCtrl.text.trim());
    final count = (int.tryParse(countCtrl.text.trim()) ?? 1).clamp(1, 20);
    dcCtrl.dispose();
    countCtrl.dispose();
    if (ok != true || !mounted) return;
    final entry = entries[index];
    final roll = rollDice(
      '${count}d$sides',
      modifier: entry.value,
      dc: dc,
      crits: story.crits,
      direction: story.checkDirection,
    );
    await _showRollResult(roll, '${entry.key} ${entry.value}');
    if (!mounted) return;
    await _send(
      '$kStoryDiceMarker${t.storyCmdCheckResult(label: entry.key, detail: roll.detail)}',
    );
  }
}
