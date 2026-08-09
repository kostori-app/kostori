part of 'package:kostori/foundation/hub_services/services.dart';

/// ── Hub 内置 AI 陪聊机器人 ───────────────────────────────────────────────────
/// 可选开关，作为 Hub 服务端的一个"幽灵"客户端存在：
/// 收到房间内 @提及它的消息后，调用已配置的 AI 服务商生成回复并广播到房间。

/// 机器人持久化配置
class HubAiBotConfig {
  /// 是否启用
  bool enabled;

  /// AI 服务商 source key（见 OpenAiProviderRegistry.allProviders）
  String provider;

  /// 模型名（留空用服务商默认）
  String model;

  /// 系统提示词（人设）
  String systemPrompt;

  /// 机器人显示名
  String name;

  /// 最小回复间隔（秒），防止刷屏
  int minIntervalSec;

  /// 是否回复私聊（unicast）
  bool replyDm;

  /// 触发方式：mention=@提及 / prefix=前缀 / keyword=包含关键字 / all=全部
  String triggerMode;

  /// 触发用的前缀或关键字（triggerMode 为 prefix / keyword 时生效）
  String triggerPattern;

  HubAiBotConfig({
    this.enabled = false,
    this.provider = 'deepseek',
    this.model = '',
    this.systemPrompt =
        '你是一个活跃在 Kostori Hub 聊天室里的 AI 陪聊伙伴，'
        '性格友善幽默，说话自然、简洁，用中文回复，不超过 200 字。',
    this.name = 'AI 助手',
    this.minIntervalSec = 3,
    this.replyDm = true,
    this.triggerMode = 'mention',
    this.triggerPattern = './',
  });

  static const _key = 'hub_ai_bot_config';

  static HubAiBotConfig load() {
    final raw = appdata.implicitData[_key];
    if (raw is Map<String, dynamic>) {
      final j = Map<String, dynamic>.from(raw);
      return HubAiBotConfig(
        enabled: j['enabled'] as bool? ?? false,
        provider: j['provider'] as String? ?? 'deepseek',
        model: j['model'] as String? ?? '',
        systemPrompt:
            j['systemPrompt'] as String? ??
            '你是一个活跃在 Kostori Hub 聊天室里的 AI 陪聊伙伴，'
                '性格友善幽默，说话自然、简洁，用中文回复，不超过 200 字。',
        name: j['name'] as String? ?? 'AI 助手',
        minIntervalSec: j['minIntervalSec'] as int? ?? 3,
        replyDm: j['replyDm'] as bool? ?? true,
        triggerMode: j['triggerMode'] as String? ?? 'mention',
        triggerPattern: j['triggerPattern'] as String? ?? './',
      );
    }
    return HubAiBotConfig();
  }

  void save() {
    appdata.implicitData[_key] = toJson();
    appdata.writeImplicitData();
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'provider': provider,
    'model': model,
    'systemPrompt': systemPrompt,
    'name': name,
    'minIntervalSec': minIntervalSec,
    'replyDm': replyDm,
    'triggerMode': triggerMode,
    'triggerPattern': triggerPattern,
  };

  HubAiBotConfig copyWith({
    bool? enabled,
    String? provider,
    String? model,
    String? systemPrompt,
    String? name,
    int? minIntervalSec,
    bool? replyDm,
    String? triggerMode,
    String? triggerPattern,
  }) => HubAiBotConfig(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    model: model ?? this.model,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    name: name ?? this.name,
    minIntervalSec: minIntervalSec ?? this.minIntervalSec,
    replyDm: replyDm ?? this.replyDm,
    triggerMode: triggerMode ?? this.triggerMode,
    triggerPattern: triggerPattern ?? this.triggerPattern,
  );
}

/// Hub 内置 AI 机器人：挂在 [HubService] 上，消费房间广播与私聊。
class HubAiBot {
  /// 机器人用户 ID
  static const userId = 'hub-ai-bot';

  /// 各房间最近一次回复时间（限流用）
  static final Map<String, DateTime> _lastReplyAt = {};

  /// 限流判断
  static bool _throttle(String roomId, int minIntervalSec) {
    final last = _lastReplyAt[roomId];
    if (last != null &&
        DateTime.now().difference(last).inSeconds < minIntervalSec) {
      return true;
    }
    _lastReplyAt[roomId] = DateTime.now();
    return false;
  }

  /// 机器人是否收到过 @提及（触发条件）
  static bool mentionsBot(HubMessage msg, String botName) {
    final text = msg.plainText;
    // 显式 mention segment 指向机器人
    for (final seg in msg.segments) {
      if (seg is MentionSegment && seg.userId == userId) return true;
    }
    // 文本中包含 @机器人名 或 直接 @机器人
    final alias = botName.trim().replaceAll(RegExp(r'\s+'), '');
    if (alias.isNotEmpty) {
      final normalized = text.replaceAll(RegExp(r'\s+'), '');
      return normalized.contains('@$alias') ||
          normalized.contains('@$userId') ||
          normalized.contains('@${userId.replaceAll('-', '')}');
    }
    return false;
  }

  /// 判断消息是否命中触发规则。
  /// [botName] 用于 mention 模式匹配；模式为 prefix/keyword 时用 [pattern]。
  static bool matchesTrigger(
    HubMessage msg,
    String botName,
    String mode,
    String pattern,
  ) {
    switch (mode) {
      case 'prefix':
        final p = pattern.trim();
        if (p.isEmpty) return false;
        return msg.plainText.trimLeft().startsWith(p);
      case 'keyword':
        final p = pattern.trim();
        if (p.isEmpty) return false;
        return msg.plainText.contains(p);
      case 'all':
        return true;
      case 'mention':
      default:
        return mentionsBot(msg, botName);
    }
  }

  /// 提取要发给 AI 的消息文本（去掉 @提及，prefix 模式去掉前缀）
  static String cleanText(
    HubMessage msg, {
    String mode = 'mention',
    String pattern = './',
  }) {
    final sb = StringBuffer();
    for (final seg in msg.segments) {
      if (seg is TextSegment) {
        sb.write(seg.text);
      } else if (seg is MentionSegment) {
        // 保留提及但去掉机器人自身的
        if (seg.userId != userId) {
          sb.write('@${seg.displayName} ');
        }
      }
    }
    var text = sb.toString().trim();
    if (mode == 'prefix' && pattern.trim().isNotEmpty) {
      final p = pattern.trim();
      if (text.startsWith(p)) text = text.substring(p.length).trim();
    }
    return text;
  }
}

extension HubAiBotExtension on HubService {
  /// 是否已初始化（读取配置是否启用）
  HubAiBotConfig get aiBotConfig => HubAiBotConfig.load();

  /// 触发一次机器人回复（由 broadcast / unicast 调用，带节流）。
  void maybeAiBotReply(
    HubMessage incoming,
    HubRoom room, {
    String? dmTargetUserId,
  }) {
    final config = aiBotConfig;
    if (!config.enabled) return;
    // 机器人自己不回复自己 / 系统 / 播放同步消息
    if (incoming.sender.isBot) return;
    if (incoming.sender.userId == HubAiBot.userId) return;
    if (incoming.segments.whereType<TextSegment>().any(
      (s) => isHubSyncText(s.text),
    )) {
      return;
    }

    // 私聊直接回复；房间内按触发模式判断（先判触发，再节流，
    // 避免非触发消息消耗限流预算导致真触发时被跳过）
    final isDm = dmTargetUserId != null;
    if (!isDm &&
        !HubAiBot.matchesTrigger(
          incoming,
          config.name,
          config.triggerMode,
          config.triggerPattern,
        )) {
      return;
    }

    // 限流：同房间最小间隔（私聊与房间分别计）
    final bucket = isDm ? 'dm:$dmTargetUserId' : 'room:${room.roomId}';
    if (HubAiBot._throttle(bucket, config.minIntervalSec)) return;

    unawaited(_runAiBotReply(config, incoming, room, dmTargetUserId));
  }

  Future<void> _runAiBotReply(
    HubAiBotConfig config,
    HubMessage incoming,
    HubRoom room,
    String? dmTargetUserId,
  ) async {
    try {
      final ai = OpenAiProviderRegistry.createAi(config.provider);
      if (ai == null) {
        HubLog.warning('HubAiBot', '服务商 ${config.provider} 未注册');
        return;
      }
      final keyRow = await ai.getKeyRow();
      if (keyRow == null || !keyRow.isEnabled) {
        HubLog.warning('HubAiBot', '服务商 ${config.provider} 未配置可用 Key');
        return;
      }

      // 构造上下文：取房间最近的真实消息（消息有压缩，内部固定窗口即可，无需用户配置）
      final history = room.messageHistory
          .where(
            (m) =>
                !m.sender.isBot &&
                !m.segments.whereType<TextSegment>().any(
                  (s) => isHubSyncText(s.text),
                ),
          )
          .toList();
      const contextWindow = 30;
      final recent = history.length > contextWindow
          ? history.sublist(history.length - contextWindow)
          : history;

      // ── 系统提示词：人设 + 一起看番剧信息 + 跨房间参考 ──
      var systemPrompt = config.systemPrompt;
      if (room.roomType == HubRoomType.watch &&
          room.animeId != null &&
          room.animeId!.isNotEmpty) {
        systemPrompt +=
            '\n\n【当前正在一起看的番剧】\n'
            '标题：${room.animeTitle ?? ''}\n'
            'ID：${room.animeId}';
      }
      // 每个房间的对话相互独立；但允许你参考其他房间近期内容来回答/总结跨房间问题
      final otherRooms = _rooms.values
          .where((r) => r.roomId != room.roomId && r.participants.isNotEmpty)
          .toList();
      if (otherRooms.isNotEmpty) {
        final buf = StringBuffer('\n\n【其他房间近期内容（仅当你被问及/需要总结其他房间时参考）】');
        var roomsShown = 0;
        for (final r in otherRooms) {
          if (roomsShown >= 4) break;
          final recentOfRoom = r.messageHistory
              .where(
                (m) =>
                    !m.sender.isBot &&
                    !m.segments.whereType<TextSegment>().any(
                      (s) => isHubSyncText(s.text),
                    ),
              )
              .toList();
          if (recentOfRoom.isEmpty) continue;
          final tail = recentOfRoom.length > 2
              ? recentOfRoom.sublist(recentOfRoom.length - 2)
              : recentOfRoom;
          buf.write(
            '\n- 房间「${r.roomName}」: '
            '${tail.map((m) => '${m.sender.displayName}: ${HubAiBot.cleanText(m)}').join(' | ')}',
          );
          roomsShown++;
        }
        if (roomsShown > 0) systemPrompt += buf.toString();
      }

      final messages = <AiMessage>[
        for (final m in recent)
          if (m.sender.userId == incoming.sender.userId)
            AiUserMessage(
              content: HubAiBot.cleanText(
                m,
                mode: config.triggerMode,
                pattern: config.triggerPattern,
              ),
            )
          else
            AiUserMessage(
              content:
                  '${m.sender.displayName}: ${HubAiBot.cleanText(m, mode: config.triggerMode, pattern: config.triggerPattern)}',
            ),
        AiUserMessage(
          content:
              '${dmTargetUserId != null ? '[私聊] ' : ''}'
              '${incoming.sender.displayName}: ${HubAiBot.cleanText(incoming, mode: config.triggerMode, pattern: config.triggerPattern)}',
        ),
      ];

      final res = await ai.chat(
        messages,
        systemPrompt: systemPrompt,
        modelOverride: config.model.isEmpty ? null : config.model,
        params: const AiGenerationParams(temperature: 0.8, maxTokens: 800),
      );

      if (res.error) {
        HubLog.warning('HubAiBot', 'AI 生成失败：${res.errorMessage}');
        return;
      }
      final replyText = res.data.trim();
      if (replyText.isEmpty) return;

      final botSender = HubClientInfo(
        userId: HubAiBot.userId,
        displayName: config.name,
        connection: null,
        isBot: true,
        currentRoomId: room.roomId,
      );

      if (dmTargetUserId != null) {
        // 私聊：单播给目标用户
        final reply = HubMessage(
          messageType: HubMessageType.chat,
          sender: botSender.toDto(),
          targetRoomIds: [room.roomId],
          segments: _parseSegments(replyText),
        );
        _unicast(reply, room.roomId, dmTargetUserId);
      } else {
        // 房间：广播
        final reply = HubMessage(
          messageType: HubMessageType.chat,
          sender: botSender.toDto(),
          targetRoomIds: [room.roomId],
          segments: _parseSegments(replyText),
        );
        _broadcastToRoom(room.roomId, reply);
      }
      HubLog.info('HubAiBot', '🤖 ${config.name} 回复完成（${replyText.length} 字）');
    } catch (e, st) {
      HubLog.error('HubAiBot', 'AI 回复异常：$e\n$st');
    }
  }
}
