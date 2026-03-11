part of 'package:kostori/foundation/services/services.dart';

class HubEmojiDef {
  final String id;
  final String? glyph;
  final String? imageUrl;

  const HubEmojiDef.unicode(String g) : id = g, glyph = g, imageUrl = null;

  const HubEmojiDef.custom({required this.id, required this.imageUrl})
    : glyph = null;

  bool get isCustom => imageUrl != null;

  Widget toWidget({double size = 20}) => isCustom
      ? Image.network(imageUrl!, width: size, height: size)
      : Text(glyph!, style: TextStyle(fontSize: size * 0.9));
}

class HubEmoji {
  HubEmoji._();

  // ── 预设：只保留表情 + 手势 ──────────────────────────────────────────────

  static final List<HubEmojiDef> _faces = [
    HubEmojiDef.unicode('😀'),
    HubEmojiDef.unicode('😄'),
    HubEmojiDef.unicode('😂'),
    HubEmojiDef.unicode('🤣'),
    HubEmojiDef.unicode('🥲'),
    HubEmojiDef.unicode('😊'),
    HubEmojiDef.unicode('😇'),
    HubEmojiDef.unicode('🙂'),
    HubEmojiDef.unicode('😉'),
    HubEmojiDef.unicode('😍'),
    HubEmojiDef.unicode('🥰'),
    HubEmojiDef.unicode('😘'),
    HubEmojiDef.unicode('😋'),
    HubEmojiDef.unicode('😜'),
    HubEmojiDef.unicode('🤪'),
    HubEmojiDef.unicode('😎'),
    HubEmojiDef.unicode('🤓'),
    HubEmojiDef.unicode('🧐'),
    HubEmojiDef.unicode('🤔'),
    HubEmojiDef.unicode('🤭'),
    HubEmojiDef.unicode('🤫'),
    HubEmojiDef.unicode('😐'),
    HubEmojiDef.unicode('😶'),
    HubEmojiDef.unicode('😏'),
    HubEmojiDef.unicode('🙄'),
    HubEmojiDef.unicode('😬'),
    HubEmojiDef.unicode('😮'),
    HubEmojiDef.unicode('😯'),
    HubEmojiDef.unicode('😲'),
    HubEmojiDef.unicode('😱'),
    HubEmojiDef.unicode('😢'),
    HubEmojiDef.unicode('😭'),
    HubEmojiDef.unicode('😤'),
    HubEmojiDef.unicode('😠'),
    HubEmojiDef.unicode('😡'),
    HubEmojiDef.unicode('🤬'),
    HubEmojiDef.unicode('🤯'),
    HubEmojiDef.unicode('😳'),
    HubEmojiDef.unicode('🥺'),
    HubEmojiDef.unicode('😞'),
    HubEmojiDef.unicode('😓'),
    HubEmojiDef.unicode('😩'),
    HubEmojiDef.unicode('😫'),
    HubEmojiDef.unicode('🥱'),
    HubEmojiDef.unicode('😴'),
    HubEmojiDef.unicode('🤗'),
    HubEmojiDef.unicode('🫡'),
    HubEmojiDef.unicode('🫠'),
    HubEmojiDef.unicode('🤡'),
    HubEmojiDef.unicode('🥳'),
    HubEmojiDef.unicode('🤠'),
    HubEmojiDef.unicode('😷'),
    HubEmojiDef.unicode('🤒'),
    HubEmojiDef.unicode('🤕'),
    HubEmojiDef.unicode('🤢'),
    HubEmojiDef.unicode('🤮'),
  ];

  static final List<HubEmojiDef> _gestures = [
    HubEmojiDef.unicode('👍'),
    HubEmojiDef.unicode('👎'),
    HubEmojiDef.unicode('👏'),
    HubEmojiDef.unicode('🙌'),
    HubEmojiDef.unicode('🙏'),
    HubEmojiDef.unicode('🫶'),
    HubEmojiDef.unicode('🤝'),
    HubEmojiDef.unicode('💪'),
    HubEmojiDef.unicode('✌️'),
    HubEmojiDef.unicode('🤞'),
    HubEmojiDef.unicode('🤙'),
    HubEmojiDef.unicode('👋'),
    HubEmojiDef.unicode('🫵'),
    HubEmojiDef.unicode('☝️'),
    HubEmojiDef.unicode('👌'),
    HubEmojiDef.unicode('🤌'),
  ];

  static final Map<String, List<HubEmojiDef>> groups = {
    '😀 Faces': _faces,
    '👍 Gestures': _gestures,
  };

  /// 全部预设
  static List<HubEmojiDef> get presets => [..._faces, ..._gestures];

  /// 运行时追加的自定义 emoji（服务端下发后写入）
  static final List<HubEmojiDef> custom = [];

  static List<HubEmojiDef> get all => [...presets, ...custom];

  // ── 查找 ──────────────────────────────────────────────────────────────────

  static HubEmojiDef? find(String id) =>
      all.firstWhereOrNull((e) => e.id == id);

  /// 渲染：找不到就直接显示 id 字符串
  static Widget render(String id, {double size = 20}) =>
      find(id)?.toWidget(size: size) ??
      Text(id, style: TextStyle(fontSize: size * 0.9));

  // ── 快捷反应栏（6个常用） ────────────────────────────────────────────────
  static final List<HubEmojiDef> quickBar = [
    HubEmojiDef.unicode('👍'),
    HubEmojiDef.unicode('❤️'),
    HubEmojiDef.unicode('😂'),
    HubEmojiDef.unicode('😮'),
    HubEmojiDef.unicode('😢'),
    HubEmojiDef.unicode('🙏'),
  ];
}
