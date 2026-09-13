// 角色卡（酒馆兼容）：支持 JSON / PNG(tEXt:chara) 导入，作为可复用库。
// 故事内角色与全局角色卡库共用本模型。

import 'dart:convert';
import 'dart:io' show zlib;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 角色卡数据（兼容 SillyTavern V2 / V1 字段）
class CharacterCard {
  final String id;
  final String name;

  /// 头像：emoji 或图片 data URL
  final String avatar;
  final String description;
  final String personality;
  final String scenario;
  final String firstMessage;
  final String exampleDialogue;
  final String creatorNotes;
  final String systemPrompt;
  final String postHistoryInstructions;
  final List<String> alternateGreetings;
  final List<String> tags;
  final String creator;
  final String version;

  const CharacterCard({
    required this.id,
    required this.name,
    this.avatar = '🧑',
    this.description = '',
    this.personality = '',
    this.scenario = '',
    this.firstMessage = '',
    this.exampleDialogue = '',
    this.creatorNotes = '',
    this.systemPrompt = '',
    this.postHistoryInstructions = '',
    this.alternateGreetings = const [],
    this.tags = const [],
    this.creator = '',
    this.version = '',
  });

  CharacterCard copyWith({
    String? name,
    String? avatar,
    String? description,
    String? personality,
    String? scenario,
    String? firstMessage,
    String? exampleDialogue,
    String? creatorNotes,
    String? systemPrompt,
    String? postHistoryInstructions,
    List<String>? alternateGreetings,
    List<String>? tags,
    String? creator,
    String? version,
  }) => CharacterCard(
    id: id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    description: description ?? this.description,
    personality: personality ?? this.personality,
    scenario: scenario ?? this.scenario,
    firstMessage: firstMessage ?? this.firstMessage,
    exampleDialogue: exampleDialogue ?? this.exampleDialogue,
    creatorNotes: creatorNotes ?? this.creatorNotes,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    postHistoryInstructions:
        postHistoryInstructions ?? this.postHistoryInstructions,
    alternateGreetings: alternateGreetings ?? this.alternateGreetings,
    tags: tags ?? this.tags,
    creator: creator ?? this.creator,
    version: version ?? this.version,
  );

  factory CharacterCard.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const <String>[];
    return CharacterCard(
      id: (json['id'] as String?) ??
          'card_${DateTime.now().microsecondsSinceEpoch}',
      name: (json['name'] as String?) ?? '',
      avatar: (json['avatar'] as String?) ?? '🧑',
      description: (json['description'] as String?) ?? '',
      personality:
          (json['personality'] ?? json['persona'])?.toString() ?? '',
      scenario: (json['scenario'] as String?) ?? '',
      firstMessage:
          (json['firstMessage'] ?? json['first_mes'])?.toString() ?? '',
      exampleDialogue:
          (json['exampleDialogue'] ?? json['mes_example'])?.toString() ?? '',
      creatorNotes:
          (json['creatorNotes'] ?? json['creator_notes'] ?? json['creatorcomment'])
              ?.toString() ??
          '',
      systemPrompt:
          (json['systemPrompt'] ?? json['system_prompt'])?.toString() ?? '',
      postHistoryInstructions:
          (json['postHistoryInstructions'] ?? json['post_history_instructions'])
              ?.toString() ??
          '',
      alternateGreetings: strList(
        json['alternateGreetings'] ?? json['alternate_greetings'],
      ),
      tags: strList(json['tags']),
      creator: (json['creator'] as String?) ?? '',
      version:
          (json['version'] ?? json['character_version'])?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'description': description,
    'personality': personality,
    'scenario': scenario,
    'firstMessage': firstMessage,
    'exampleDialogue': exampleDialogue,
    'creatorNotes': creatorNotes,
    'systemPrompt': systemPrompt,
    'postHistoryInstructions': postHistoryInstructions,
    'alternateGreetings': alternateGreetings,
    'tags': tags,
    'creator': creator,
    'version': version,
  };

  /// 解析酒馆角色卡 JSON（自动识别 V2 data 包裹 / V1 扁平结构）
  factory CharacterCard.fromSillyTavernJson(Map<String, dynamic> json) {
    final data = json['data'];
    final source = data is Map ? data.cast<String, dynamic>() : json;
    return CharacterCard.fromJson(source);
  }

  /// 导出为酒馆 V2 格式
  Map<String, dynamic> toSillyTavernJson() => {
    'spec': 'chara_card_v2',
    'spec_version': '2.0',
    'data': {
      'name': name,
      'description': description,
      'personality': personality,
      'scenario': scenario,
      'first_mes': firstMessage,
      'mes_example': exampleDialogue,
      'creator_notes': creatorNotes,
      'system_prompt': systemPrompt,
      'post_history_instructions': postHistoryInstructions,
      'alternate_greetings': alternateGreetings,
      'tags': tags,
      'creator': creator,
      'character_version': version,
    },
  };

  /// 酒馆角色卡文本：V2 JSON 的 base64
  String toCharaText() =>
      base64.encode(utf8.encode(jsonEncode(toSillyTavernJson())));

  /// 头像若为图片 data URL 则解码出原始字节
  Uint8List? decodeAvatarImage() {
    final a = avatar.trim();
    if (!a.startsWith('data:image')) return null;
    final comma = a.indexOf(',');
    if (comma < 0) return null;
    try {
      return base64.decode(a.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  /// 把 chara 文本作为 tEXt 块写入 PNG（插在 IEND 之前）
  static Uint8List embedCharaChunk(Uint8List png, String charaText) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (png.length < 8) return png;
    for (var i = 0; i < 8; i++) {
      if (png[i] != signature[i]) return png;
    }

    final iendType = ascii.encode('IEND');
    int? iendOffset;
    var offset = 8;
    while (offset + 8 <= png.length) {
      final length = _readUint32(png, offset);
      final typeStart = offset + 4;
      final dataEnd = offset + 8 + length;
      if (dataEnd + 4 > png.length) break;
      var isIend = true;
      for (var i = 0; i < 4; i++) {
        if (png[typeStart + i] != iendType[i]) {
          isIend = false;
          break;
        }
      }
      if (isIend) {
        iendOffset = offset;
        break;
      }
      offset = dataEnd + 4;
    }
    if (iendOffset == null) return png;

    final chunkData = <int>[
      ...ascii.encode('chara'),
      0,
      ...ascii.encode(charaText),
    ];
    final typeAndData = <int>[...ascii.encode('tEXt'), ...chunkData];
    final chunk = <int>[
      ..._uint32(chunkData.length),
      ...typeAndData,
      ..._uint32(_crc32(typeAndData)),
    ];

    return Uint8List.fromList([
      ...png.sublist(0, iendOffset),
      ...chunk,
      ...png.sublist(iendOffset),
    ]);
  }

  static List<int> _uint32(int value) => [
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ];

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  /// 供系统提示词注入的文本
  String toPrompt() {
    final buf = StringBuffer('【角色：$name】');
    if (description.trim().isNotEmpty) {
      buf.write('\n描述：${description.trim()}');
    }
    if (personality.trim().isNotEmpty) {
      buf.write('\n性格：${personality.trim()}');
    }
    if (scenario.trim().isNotEmpty) {
      buf.write('\n场景：${scenario.trim()}');
    }
    return buf.toString();
  }

  /// 从文件字节解析（PNG 角色卡或 JSON）
  static CharacterCard? fromBytes(Uint8List bytes) {
    final png = fromPngBytes(bytes);
    if (png != null) return png;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) {
        return CharacterCard.fromSillyTavernJson(
          decoded.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return null;
  }

  /// 从 PNG 的 tEXt / zTXt 块中读取 chara 字段
  static CharacterCard? fromPngBytes(Uint8List bytes) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 8) return null;
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != signature[i]) return null;
    }
    var offset = 8;
    while (offset + 12 <= bytes.length) {
      final length = _readUint32(bytes, offset);
      final type = String.fromCharCodes(
        bytes.sublist(offset + 4, offset + 8),
      );
      final dataStart = offset + 8;
      final dataEnd = dataStart + length;
      if (length < 0 || dataEnd + 4 > bytes.length) break;
      if (type == 'tEXt' || type == 'zTXt') {
        final data = bytes.sublist(dataStart, dataEnd);
        final sep = data.indexOf(0);
        if (sep > 0) {
          final keyword = String.fromCharCodes(data.sublist(0, sep));
          if (keyword == 'chara' || keyword == 'character') {
            String text;
            if (type == 'zTXt') {
              try {
                text = utf8.decode(zlib.decode(data.sublist(sep + 2)));
              } catch (_) {
                offset = dataEnd + 4;
                continue;
              }
            } else {
              text = String.fromCharCodes(data.sublist(sep + 1));
            }
            final card = _decodeCharaText(text);
            if (card != null) return card;
          }
        }
      }
      offset = dataEnd + 4; // 跳过 CRC
    }
    return null;
  }

  static CharacterCard? _decodeCharaText(String text) {
    try {
      final normalized = text.replaceAll(RegExp(r'\s'), '');
      final decoded = utf8.decode(base64.decode(normalized));
      final json = jsonDecode(decoded);
      if (json is Map) {
        return CharacterCard.fromSillyTavernJson(
          json.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return null;
  }

  static int _readUint32(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

/// 全局角色卡库：shared_preferences 持久化
class CharacterCardStore extends ChangeNotifier {
  static final CharacterCardStore instance = CharacterCardStore._();

  CharacterCardStore._();

  static const _kKey = 'character_cards';

  List<CharacterCard> _cards = [];
  bool _loaded = false;

  List<CharacterCard> get cards => List.unmodifiable(_cards);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) {
      _cards = [];
    } else {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _cards = [
            for (final e in decoded)
              if (e is Map) CharacterCard.fromJson(e.cast<String, dynamic>()),
          ];
        }
      } catch (_) {
        _cards = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (!_loaded) await init();
  }

  CharacterCard? find(String id) {
    for (final c in _cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode([for (final c in _cards) c.toJson()]),
    );
  }

  Future<void> upsert(CharacterCard card) async {
    await ensureLoaded();
    final idx = _cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      _cards[idx] = card;
    } else {
      _cards.add(card);
    }
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await ensureLoaded();
    _cards.removeWhere((c) => c.id == id);
    await _save();
    notifyListeners();
  }
}
