// 角色卡（酒馆兼容）：支持 JSON / PNG(tEXt:chara) 导入，作为可复用库。
// 故事内角色与全局角色卡库共用本模型。

import 'dart:convert';
import 'dart:io' show zlib;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 角色卡数据（兼容 SillyTavern V1 / V2 / V3 字段）
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

  // ── V3 扩展字段 ──
  /// 昵称（V3）
  final String nickname;

  /// 多语言创作者备注（V3）
  final Map<String, String> creatorNotesMultilingual;

  /// 来源链接（V3）
  final List<String> source;

  /// 仅群聊使用的开场白（V3）
  final List<String> groupOnlyGreetings;

  /// 创建 / 修改时间（V3，Unix 秒）
  final int? creationDate;
  final int? modificationDate;

  /// 资源列表（V3，原样保留）
  final List<Map<String, dynamic>> assets;

  /// 扩展数据（原样保留，避免导入导出丢失）
  final Map<String, dynamic> extensions;

  /// 随卡世界书（character_book，V2/V3）
  final Map<String, dynamic>? characterBook;

  /// 来源规范版本（'' | '1.0' | '2.0' | '3.0'）
  final String specVersion;

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
    this.nickname = '',
    this.creatorNotesMultilingual = const {},
    this.source = const [],
    this.groupOnlyGreetings = const [],
    this.creationDate,
    this.modificationDate,
    this.assets = const [],
    this.extensions = const {},
    this.characterBook,
    this.specVersion = '',
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
    String? nickname,
    Map<String, String>? creatorNotesMultilingual,
    List<String>? source,
    List<String>? groupOnlyGreetings,
    int? creationDate,
    int? modificationDate,
    List<Map<String, dynamic>>? assets,
    Map<String, dynamic>? extensions,
    Map<String, dynamic>? characterBook,
    String? specVersion,
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
    nickname: nickname ?? this.nickname,
    creatorNotesMultilingual:
        creatorNotesMultilingual ?? this.creatorNotesMultilingual,
    source: source ?? this.source,
    groupOnlyGreetings: groupOnlyGreetings ?? this.groupOnlyGreetings,
    creationDate: creationDate ?? this.creationDate,
    modificationDate: modificationDate ?? this.modificationDate,
    assets: assets ?? this.assets,
    extensions: extensions ?? this.extensions,
    characterBook: characterBook ?? this.characterBook,
    specVersion: specVersion ?? this.specVersion,
  );

  factory CharacterCard.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const <String>[];
    Map<String, dynamic> mapOf(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};
    final multilingual = <String, String>{};
    final rawMulti = json['creatorNotesMultilingual'] ??
        json['creator_notes_multilingual'];
    if (rawMulti is Map) {
      for (final e in rawMulti.entries) {
        multilingual[e.key.toString()] = e.value?.toString() ?? '';
      }
    }
    return CharacterCard(
      id: (json['id'] as String?) ??
          'card_${DateTime.now().microsecondsSinceEpoch}',
      name: (json['name'] as String?) ?? '',
      avatar: (json['avatar'] as String?) ?? '🧑',
      description: (json['description'] as String?) ?? '',
      personality:
          (json['personality'] ??
                  (json['persona'] is String ? json['persona'] : null))
              ?.toString() ??
          '',
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
      nickname: (json['nickname'] as String?) ?? '',
      creatorNotesMultilingual: multilingual,
      source: strList(json['source']),
      groupOnlyGreetings: strList(
        json['groupOnlyGreetings'] ?? json['group_only_greetings'],
      ),
      creationDate: (json['creationDate'] ?? json['creation_date'] as num?)
          ?.toInt(),
      modificationDate:
          (json['modificationDate'] ?? json['modification_date'] as num?)
              ?.toInt(),
      assets: [
        for (final a in (json['assets'] as List? ?? const []))
          if (a is Map) a.cast<String, dynamic>(),
      ],
      extensions: mapOf(json['extensions']),
      characterBook: json['characterBook'] is Map
          ? mapOf(json['characterBook'])
          : (json['character_book'] is Map
                ? mapOf(json['character_book'])
                : null),
      specVersion: (json['specVersion'] as String?) ?? '',
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
    'nickname': nickname,
    'creatorNotesMultilingual': creatorNotesMultilingual,
    'source': source,
    'groupOnlyGreetings': groupOnlyGreetings,
    if (creationDate != null) 'creationDate': creationDate,
    if (modificationDate != null) 'modificationDate': modificationDate,
    'assets': assets,
    'extensions': extensions,
    if (characterBook != null) 'characterBook': characterBook,
    'specVersion': specVersion,
  };

  /// 解析角色卡 JSON（V1 扁平 / V2、V3 data 包裹 / character、char 等变体均支持）
  factory CharacterCard.fromSillyTavernJson(Map<String, dynamic> json) {
    final spec = (json['spec_version'] ?? json['specVersion'] ?? json['spec'] ?? '')
        .toString();
    Map<String, dynamic>? unwrap(Map<String, dynamic> m) {
      for (final key in const ['data', 'character', 'char', 'card']) {
        final v = m[key];
        if (v is Map) {
          final vm = v.cast<String, dynamic>();
          if (vm.containsKey('name') ||
              vm.containsKey('description') ||
              vm.containsKey('personality') ||
              vm.containsKey('first_mes')) {
            return vm;
          }
        }
      }
      return null;
    }

    final inner = unwrap(json) ?? json;
    final card = CharacterCard.fromJson(inner);
    return card.copyWith(specVersion: spec);
  }

  /// 导出为酒馆格式（[spec] 为 2 或 3，默认 V3）
  Map<String, dynamic> toSillyTavernJson({int spec = 3}) {
    final isV3 = spec >= 3;
    final data = <String, dynamic>{
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
      if (characterBook != null) 'character_book': characterBook,
      if (extensions.isNotEmpty) 'extensions': extensions,
      if (isV3) ...{
        'nickname': nickname,
        'creator_notes_multilingual': creatorNotesMultilingual,
        'source': source,
        'group_only_greetings': groupOnlyGreetings,
        'creation_date': creationDate ?? 0,
        'modification_date': modificationDate ?? 0,
        'assets': assets,
      },
    };
    return {
      'spec': isV3 ? 'chara_card_v3' : 'chara_card_v2',
      'spec_version': isV3 ? '3.0' : '2.0',
      'data': data,
    };
  }

  /// 酒馆角色卡文本：默认 V3 JSON 的 base64
  String toCharaText({int spec = 3}) => base64.encode(
    utf8.encode(jsonEncode(toSillyTavernJson(spec: spec))),
  );

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
    if (png != null) {
      // 酒馆 PNG 卡：头像就是整张图片，存为 data URL
      if (!png.avatar.trim().startsWith('data:image')) {
        return png.copyWith(
          avatar: 'data:image/png;base64,${base64.encode(bytes)}',
        );
      }
      return png;
    }
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

  /// 从 PNG 的 tEXt / zTXt / iTXt 块中读取 chara 字段
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
      if (type == 'tEXt' || type == 'zTXt' || type == 'iTXt') {
        final card = _readTextChunk(type, bytes.sublist(dataStart, dataEnd));
        if (card != null) return card;
      }
      offset = dataEnd + 4; // 跳过 CRC
    }
    return null;
  }

  /// 解析文本块（tEXt 未压缩 / zTXt zlib / iTXt 可选压缩）
  static CharacterCard? _readTextChunk(String type, List<int> data) {
    final sep = data.indexOf(0);
    if (sep <= 0) return null;
    final keyword = String.fromCharCodes(data.sublist(0, sep));
    if (keyword != 'chara' && keyword != 'character') return null;

    if (type == 'tEXt') {
      return _decodeCharaText(String.fromCharCodes(data.sublist(sep + 1)));
    }
    if (type == 'zTXt') {
      try {
        return _decodeCharaText(
          utf8.decode(zlib.decode(data.sublist(sep + 2))),
        );
      } catch (_) {
        return null;
      }
    }
    // iTXt: keyword\0 flag method lang\0 translated\0 text
    var offset = sep + 1;
    if (offset + 2 > data.length) return null;
    final compressed = data[offset] == 1;
    offset += 2;
    var end = data.indexOf(0, offset);
    if (end < 0) return null;
    offset = end + 1;
    end = data.indexOf(0, offset);
    if (end < 0) return null;
    offset = end + 1;
    var textBytes = data.sublist(offset);
    if (compressed) {
      try {
        textBytes = zlib.decode(textBytes);
      } catch (_) {
        return null;
      }
    }
    return _decodeCharaText(utf8.decode(textBytes, allowMalformed: true));
  }

  static CharacterCard? _decodeCharaText(String text) {
    // 常见：base64 编码的 JSON
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
    // 兜底：直接是 JSON 文本
    try {
      final json = jsonDecode(text.trim());
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
