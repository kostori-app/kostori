// hub_sticker_manager.dart
part of 'package:kostori/foundation/hub_services/services.dart';

// ── 表情包数据模型 ─────────────────────────────────────────────────────────────

class HubSticker {
  final String url; // data URI 或 http(s) URL
  final String? label;
  final DateTime savedAt;

  HubSticker({required this.url, this.label, DateTime? savedAt})
    : savedAt = savedAt ?? DateTime.now();

  bool get isBase64 => url.startsWith('data:');

  Map<String, dynamic> toJson() => {
    'url': url,
    if (label != null) 'label': label,
    'savedAt': savedAt.toIso8601String(),
  };

  factory HubSticker.fromJson(Map<String, dynamic> j) => HubSticker(
    url: j['url'] as String,
    label: j['label'] as String?,
    savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

// ── 表情包管理器（本地持久化）─────────────────────────────────────────────────

class HubStickerManager {
  static const _key = 'hub_stickers';
  static const _maxCount = 200;

  /// 从 appdata 加载表情包列表
  static List<HubSticker> load() {
    final raw = appdata.implicitData[_key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => HubSticker.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// 保存表情包列表到 appdata
  static void _save(List<HubSticker> stickers) {
    appdata.implicitData[_key] = stickers.map((s) => s.toJson()).toList();
    appdata.writeImplicitData();
  }

  /// 添加表情包（同 URL 不重复，超出上限自动截断）
  static void add(HubSticker sticker) {
    final list = load();
    if (list.any((s) => s.url == sticker.url)) return; // 去重
    list.insert(0, sticker);
    if (list.length > _maxCount) list.removeLast();
    _save(list);
  }

  /// 删除指定 URL 的表情包
  static void remove(String url) {
    final list = load()..removeWhere((s) => s.url == url);
    _save(list);
  }

  /// 清空全部
  static void clear() => _save([]);
}
