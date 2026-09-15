// 群聊：把多张角色卡放进同一个会话里分别扮演（对齐 SillyTavern Group Chat 的基本能力）。
// 与「故事(GM)」模式并存：故事是旁白驱动的冒险，群聊是纯角色对话。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/ai_service/character_card.dart';
import 'package:kostori/foundation/app.dart';

/// 群聊配置
class GroupChat {
  final String id;
  final String name;

  /// 群成员（全局角色卡库中的角色卡 id），可多张
  final List<String> memberIds;

  /// 群聊场景 / 世界设定（可选）
  final String scenario;

  /// 附加系统提示词（可选）
  final String systemExtra;

  /// 发言顺序：natural（模型决定）| list（按成员轮流）
  final String order;

  /// 自动模式：一轮结束后自动让下一位继续
  final bool autoMode;

  /// 当前会话 id（空 = 未开始）
  final String sessionId;

  const GroupChat({
    required this.id,
    this.name = '',
    this.memberIds = const [],
    this.scenario = '',
    this.systemExtra = '',
    this.order = 'natural',
    this.autoMode = false,
    this.sessionId = '',
  });

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const <String>[];
    return GroupChat(
      id: json['id']?.toString() ?? 'group_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name']?.toString() ?? '',
      memberIds: strList(json['memberIds']),
      scenario: json['scenario']?.toString() ?? '',
      systemExtra: json['systemExtra']?.toString() ?? '',
      order: json['order']?.toString() ?? 'natural',
      autoMode: json['autoMode'] == true,
      sessionId: json['sessionId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'memberIds': memberIds,
    'scenario': scenario,
    'systemExtra': systemExtra,
    'order': order,
    'autoMode': autoMode,
    'sessionId': sessionId,
  };

  GroupChat copyWith({
    String? name,
    List<String>? memberIds,
    String? scenario,
    String? systemExtra,
    String? order,
    bool? autoMode,
    String? sessionId,
  }) => GroupChat(
    id: id,
    name: name ?? this.name,
    memberIds: memberIds ?? this.memberIds,
    scenario: scenario ?? this.scenario,
    systemExtra: systemExtra ?? this.systemExtra,
    order: order ?? this.order,
    autoMode: autoMode ?? this.autoMode,
    sessionId: sessionId ?? this.sessionId,
  );
}

/// 群聊存储：`dataPath/group_chats/<id>.json`
class GroupChatStore extends ChangeNotifier {
  static final GroupChatStore instance = GroupChatStore._();

  GroupChatStore._();

  static const _dirName = 'group_chats';

  List<GroupChat> _chats = [];
  bool _loaded = false;

  List<GroupChat> get chats => List.unmodifiable(_chats);

  GroupChat? find(String id) {
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  String get dirPath => '${App.dataPath}/$_dirName';

  Future<void> init() async {
    _chats = [];
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      for (final entity in dir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final json = jsonDecode(await entity.readAsString());
          if (json is Map) {
            _chats.add(GroupChat.fromJson(json.cast<String, dynamic>()));
          }
        } catch (_) {}
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  Future<void> reload() async {
    _loaded = false;
    await init();
  }

  Future<void> upsert(GroupChat chat) async {
    await ensureLoaded();
    final idx = _chats.indexWhere((c) => c.id == chat.id);
    if (idx >= 0) {
      _chats[idx] = chat;
    } else {
      _chats.add(chat);
    }
    final dir = Directory(dirPath);
    await dir.create(recursive: true);
    await File(
      '$dirPath/${chat.id}.json',
    ).writeAsString(jsonEncode(chat.toJson()));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _chats.removeWhere((c) => c.id == id);
    final f = File('$dirPath/$id.json');
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    notifyListeners();
  }
}

/// 组装群聊系统提示词：[members] 已解析好的角色卡，[nextSpeaker] 指定本轮发言者。
String buildGroupSystemPrompt({
  required GroupChat chat,
  required List<CharacterCard> members,
  String? nextSpeaker,
}) {
  final buf = StringBuffer('你是「群聊」扮演助手，需要分别扮演群成员，各自保持人设与语气。\n');
  if (chat.scenario.trim().isNotEmpty) {
    buf.write('\n【场景】\n${chat.scenario.trim()}\n');
  }
  buf.write('\n【群成员】');
  for (final c in members) {
    buf.write('\n\n${c.toPrompt()}');
  }
  if (chat.systemExtra.trim().isNotEmpty) {
    buf.write('\n\n【附加要求】\n${chat.systemExtra.trim()}');
  }
  buf.write(
    '\n\n【发言规则】\n'
    '- 每次只扮演一名成员：用 〖角色：名字〗该成员的对白与动作〖/角色〗 包裹；'
    '标记之外只写极简旁白（可省略）。\n'
    '- 不要在同一轮里替多名成员发言，也不要替用户发言。\n'
    '- 保持各成员的口吻、称呼与关系。',
  );
  final n = nextSpeaker?.trim() ?? '';
  if (n.isNotEmpty) {
    buf.write('\n- 本轮请由「$n」发言。');
  } else if (chat.order == 'list') {
    buf.write('\n- 本轮按成员顺序轮到下一位发言。');
  } else {
    buf.write('\n- 本轮由你判断此刻最该由谁发言，只让一名成员发言。');
  }
  return buf.toString();
}
