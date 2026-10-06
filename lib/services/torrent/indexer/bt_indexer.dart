import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:path/path.dart' as p;

/// BT 检索结果
class BtSearchResult {
  final String title;
  final String magnet;
  final int size; // bytes，未知为 0
  final DateTime? createdAt;
  final String sourceKey;
  final String source; // 站点名
  final String? fansub;

  const BtSearchResult({
    required this.title,
    required this.magnet,
    required this.sourceKey,
    required this.source,
    this.size = 0,
    this.createdAt,
    this.fansub,
  });
}

/// BT 资源站（只负责检索）
abstract class BtIndexer {
  String get key;
  String get name;
  Future<List<BtSearchResult>> search(String keyword, {int page = 1});
}

/// BT 站点检索用的 Dio。
///
/// 必须设超时：BT 站点常年挂着/半开，不设超时时一个站点就能把
/// `Future.wait` 永远拖住，表现为检索转圈且无法取消。
final Dio _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 10),
  ),
);

/// 复用项目的 UA（含用户在设置里的覆盖）。
String get _ua => appdata.implicitData['ua']?.toString() ?? webUA;

/// 把用户/插件给的种子标识规范成磁力链接：完整磁力（base32 顺带转 hex）、
/// 裸 40 位 hex、裸 32 位 base32。裸 hash 会被包成最小磁力链，
/// 后续 `TorrentManager._augmentTrackers` 再补 tracker。
///
/// base32 必须在 40 位 hex 之后判断：`[A-Za-z2-7]` 与 hex 字符集有重叠，
/// 反过来会把约 1/7500 的合法 hex 磁力改写成错误 infohash。
String normalizeMagnet(String magnet) {
  final raw = magnet.trim();
  if (!RegExp(r'xt=urn:btih:', caseSensitive: false).hasMatch(raw)) {
    final bare = _bareInfoHashToMagnet(raw);
    if (bare != null) return bare;
  }
  final m = RegExp(
    r'xt=urn:btih:([A-Z2-7]{32})(?![A-Z2-7])',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return raw;
  final hex = base32ToInfoHashHex(m.group(1)!);
  if (hex == null) return raw;
  return raw.replaceRange(m.start, m.end, 'xt=urn:btih:$hex');
}

/// 裸 infohash → `magnet:?xt=urn:btih:<hex>`；不是裸 infohash 返回 null。
String? _bareInfoHashToMagnet(String raw) {
  final s = raw.trim();
  if (s.contains('://') || s.contains('=')) return null;
  final upper = s.toUpperCase();
  if (RegExp(r'^[0-9A-F]{40}$').hasMatch(upper)) {
    return 'magnet:?xt=urn:btih:$upper';
  }
  if (RegExp(r'^[A-Z2-7]{32}$').hasMatch(upper)) {
    final hex = base32ToInfoHashHex(upper);
    return hex == null ? null : 'magnet:?xt=urn:btih:$hex';
  }
  return null;
}

/// 从磁力里取 hex infohash（小写），取不到返回 null。
String? btInfoHashOfMagnet(String magnet) =>
    parseInfoHash(normalizeMagnet(magnet))?.toLowerCase();

/// BT 资源站配置：完全数据驱动（不内置任何站点），由用户导入。
///
/// `type=regex`：抓取 [urlTemplate]，用 [itemRegex] 切分条目，各正则取字段。
/// `type=json`：抓取 [urlTemplate]，用 [jsonPath] 取数组，各字段名取字段。
class BtSourceConfig {
  final String key;
  final String name;
  final bool enabled;
  final String type; // regex | json
  final String urlTemplate; // {query} {page}

  // regex
  final String itemRegex;
  final String magnetRegex;
  final String hashRegex;
  final String magnetTemplate;
  final String titleRegex;
  final String sizeRegex;
  final String groupRegex;
  final String dateRegex;

  // json
  final String jsonPath;
  final String titleField;
  final String magnetField;
  final String hashField;
  final String sizeField;
  final String groupField;
  final String dateField;

  const BtSourceConfig({
    required this.key,
    required this.name,
    this.enabled = true,
    this.type = 'regex',
    this.urlTemplate = '',
    this.itemRegex = '',
    this.magnetRegex = '',
    this.hashRegex = '',
    this.magnetTemplate = '',
    this.titleRegex = '',
    this.sizeRegex = '',
    this.groupRegex = '',
    this.dateRegex = '',
    this.jsonPath = '',
    this.titleField = '',
    this.magnetField = '',
    this.hashField = '',
    this.sizeField = '',
    this.groupField = '',
    this.dateField = '',
  });

  BtSourceConfig copyWith({
    String? key,
    String? name,
    bool? enabled,
    String? type,
    String? urlTemplate,
    String? itemRegex,
    String? magnetRegex,
    String? hashRegex,
    String? magnetTemplate,
    String? titleRegex,
    String? sizeRegex,
    String? groupRegex,
    String? dateRegex,
    String? jsonPath,
    String? titleField,
    String? magnetField,
    String? hashField,
    String? sizeField,
    String? groupField,
    String? dateField,
  }) {
    return BtSourceConfig(
      key: key ?? this.key,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      urlTemplate: urlTemplate ?? this.urlTemplate,
      itemRegex: itemRegex ?? this.itemRegex,
      magnetRegex: magnetRegex ?? this.magnetRegex,
      hashRegex: hashRegex ?? this.hashRegex,
      magnetTemplate: magnetTemplate ?? this.magnetTemplate,
      titleRegex: titleRegex ?? this.titleRegex,
      sizeRegex: sizeRegex ?? this.sizeRegex,
      groupRegex: groupRegex ?? this.groupRegex,
      dateRegex: dateRegex ?? this.dateRegex,
      jsonPath: jsonPath ?? this.jsonPath,
      titleField: titleField ?? this.titleField,
      magnetField: magnetField ?? this.magnetField,
      hashField: hashField ?? this.hashField,
      sizeField: sizeField ?? this.sizeField,
      groupField: groupField ?? this.groupField,
      dateField: dateField ?? this.dateField,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'enabled': enabled,
    'type': type,
    'urlTemplate': urlTemplate,
    'itemRegex': itemRegex,
    'magnetRegex': magnetRegex,
    'hashRegex': hashRegex,
    'magnetTemplate': magnetTemplate,
    'titleRegex': titleRegex,
    'sizeRegex': sizeRegex,
    'groupRegex': groupRegex,
    'dateRegex': dateRegex,
    'jsonPath': jsonPath,
    'titleField': titleField,
    'magnetField': magnetField,
    'hashField': hashField,
    'sizeField': sizeField,
    'groupField': groupField,
    'dateField': dateField,
  };

  static BtSourceConfig fromJson(Object? v) {
    final m = v is Map ? v : const {};
    String s(String k) => m[k]?.toString() ?? '';
    final key = s('key');
    return BtSourceConfig(
      key: key,
      name: s('name').isEmpty ? key : s('name'),
      enabled: m['enabled'] is bool ? m['enabled'] as bool : true,
      type: s('type').isEmpty ? 'regex' : s('type'),
      urlTemplate: s('urlTemplate'),
      itemRegex: s('itemRegex'),
      magnetRegex: s('magnetRegex'),
      hashRegex: s('hashRegex'),
      magnetTemplate: s('magnetTemplate'),
      titleRegex: s('titleRegex'),
      sizeRegex: s('sizeRegex'),
      groupRegex: s('groupRegex'),
      dateRegex: s('dateRegex'),
      jsonPath: s('jsonPath'),
      titleField: s('titleField'),
      magnetField: s('magnetField'),
      hashField: s('hashField'),
      sizeField: s('sizeField'),
      groupField: s('groupField'),
      dateField: s('dateField'),
    );
  }
}

/// BT 资源站配置存储：全部来自文件（导入式，不内置任何站点）。
///
/// 目录：`<dataPath>/bt_source/*.json`。每个文件是一个配置对象或数组。
class BtSources {
  BtSources._();

  static final List<BtSourceConfig> _cache = [];
  static bool _loaded = false;

  static List<BtSourceConfig> get all => List.unmodifiable(_cache);

  static Directory get dir => Directory(p.join(App.dataPath, 'bt_source'));

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await reload();
  }

  static Future<void> reload() async {
    _cache.clear();
    try {
      if (await dir.exists()) {
        final files = (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.json'))
            .toList();
        for (final f in files) {
          try {
            final data = jsonDecode(await f.readAsString());
            if (data is Map) {
              final c = BtSourceConfig.fromJson(data);
              if (c.key.isNotEmpty) _cache.add(c);
            } else if (data is List) {
              for (final e in data) {
                final c = BtSourceConfig.fromJson(e);
                if (c.key.isNotEmpty) _cache.add(c);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    _loaded = true;
  }

  /// 站点 key → 配置文件名。
  ///
  /// 直接把非法字符换成 `_` 会撞名：`a/b` 与 `a_b` 都变成 `a_b.json`，
  /// 后写入的会静默覆盖前者。需要净化的 key 追加一段稳定的 FNV-1a 短哈希；
  /// 本身合法的 key 保持原文件名，避免旧配置全部变成孤儿文件。
  static String _safeFileName(String key) {
    final base = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (base == key) return base;
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(key)) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return '${base}_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static Future<void> _writeFile(BtSourceConfig c) async {
    if (!await dir.exists()) await dir.create(recursive: true);
    await File(p.join(dir.path, '${_safeFileName(c.key)}.json'))
        .writeAsString(const JsonEncoder.withIndent('  ').convert(c.toJson()));
  }

  static Future<void> upsert(BtSourceConfig config) async {
    await _writeFile(config);
    await reload();
  }

  static Future<void> remove(String key) async {
    try {
      if (await dir.exists()) {
        for (final f in await dir.list().toList()) {
          if (f is! File || !f.path.toLowerCase().endsWith('.json')) continue;
          try {
            final data = jsonDecode(await f.readAsString());
            final has =
                (data is Map && data['key'] == key) ||
                (data is List && data.any((e) => e is Map && e['key'] == key));
            if (has) await f.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
    await reload();
  }

  static Future<void> setEnabled(String key, bool enabled) async {
    for (final c in List.of(_cache)) {
      if (c.key == key) await _writeFile(c.copyWith(enabled: enabled));
    }
    await reload();
  }

  /// 导入 JSON（对象或数组），写入目录并重载。返回导入的站点数。
  static Future<int> importJson(String json) async {
    dynamic data;
    try {
      data = jsonDecode(json);
    } catch (_) {
      return 0;
    }
    final configs = <BtSourceConfig>[];
    if (data is Map) {
      configs.add(BtSourceConfig.fromJson(data));
    } else if (data is List) {
      for (final e in data) {
        configs.add(BtSourceConfig.fromJson(e));
      }
    }
    configs.removeWhere((c) => c.key.isEmpty);
    if (configs.isEmpty) return 0;
    for (final c in configs) {
      await _writeFile(c);
    }
    await reload();
    return configs.length;
  }
}

/// 通用检索器：按配置抓取 + 解析（regex / json），项目内不含任何站点逻辑。
class HttpIndexer extends BtIndexer {
  HttpIndexer(this.config);

  final BtSourceConfig config;

  @override
  String get key => config.key;
  @override
  String get name => config.name;

  @override
  Future<List<BtSearchResult>> search(String keyword, {int page = 1}) async {
    if (config.urlTemplate.isEmpty) return const [];
    final url = config.urlTemplate
        .replaceAll('{query}', Uri.encodeComponent(keyword))
        .replaceAll('{page}', '$page');
    final isJson = config.type == 'json';
    final res = await _dio.getUri<dynamic>(
      Uri.parse(url),
      options: Options(
        headers: {'user-agent': _ua},
        responseType: isJson ? ResponseType.json : ResponseType.plain,
      ),
    );
    final data = res.data;
    return isJson ? _parseJson(data) : _parseRegex(data?.toString() ?? '');
  }

  List<BtSearchResult> _parseJson(dynamic data) {
    dynamic raw = data;
    if (data is String) {
      try {
        raw = jsonDecode(data);
      } catch (_) {
        return const [];
      }
    }
    final list = _dig(raw, config.jsonPath);
    if (list is! List) return const [];
    final out = <BtSearchResult>[];
    for (final e in list) {
      if (e is! Map) continue;
      final title = _str(_dig(e, config.titleField));
      var magnet = _str(_dig(e, config.magnetField));
      if (magnet.isEmpty) {
        final hash = _str(_dig(e, config.hashField));
        if (hash.isNotEmpty) magnet = _applyTemplate(hash);
      }
      if (magnet.isEmpty) continue;
      out.add(
        BtSearchResult(
          title: title.isEmpty ? magnet : title,
          magnet: normalizeMagnet(magnet),
          sourceKey: key,
          source: name,
          size: _sizeFromJson(_dig(e, config.sizeField)),
          createdAt: DateTime.tryParse(_str(_dig(e, config.dateField))),
          fansub: _str(_dig(e, config.groupField)),
        ),
      );
    }
    return out;
  }

  List<BtSearchResult> _parseRegex(String body) {
    if (body.isEmpty) return const [];
    final itemRe = config.itemRegex.isNotEmpty
        ? RegExp(config.itemRegex, dotAll: true, caseSensitive: false)
        : null;
    final blocks = itemRe != null
        ? itemRe
              .allMatches(body)
              .map(
                (m) => m.groupCount >= 1
                    ? (m.group(1) ?? m.group(0)!)
                    : m.group(0)!,
              )
              .toList()
        : [body];
    final out = <BtSearchResult>[];
    for (final b in blocks) {
      var magnet = _group(config.magnetRegex, b) ?? '';
      if (magnet.isEmpty) {
        final hash = _group(config.hashRegex, b) ?? '';
        if (hash.isNotEmpty) magnet = _applyTemplate(hash);
      }
      if (magnet.isEmpty) continue;
      final title = _stripTags(_group(config.titleRegex, b) ?? '');
      final group = _stripTags(_group(config.groupRegex, b) ?? '');
      out.add(
        BtSearchResult(
          title: title.isEmpty ? magnet : title,
          magnet: normalizeMagnet(magnet),
          sourceKey: key,
          source: name,
          size: _parseSizeStr(_group(config.sizeRegex, b)),
          createdAt: DateTime.tryParse(
            _stripTags(_group(config.dateRegex, b) ?? ''),
          ),
          fansub: group.isEmpty ? null : group,
        ),
      );
    }
    return out;
  }

  String _applyTemplate(String hash) {
    final tpl = config.magnetTemplate.isNotEmpty
        ? config.magnetTemplate
        : 'magnet:?xt=urn:btih:{hash}';
    return tpl.replaceAll('{hash}', hash.trim());
  }

  static String? _group(String pattern, String input) {
    if (pattern.isEmpty) return null;
    final m = RegExp(
      pattern,
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(input);
    if (m == null) return null;
    return m.groupCount >= 1 ? (m.group(1) ?? m.group(0)) : m.group(0);
  }

  static String _stripTags(String s) => s
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _str(dynamic v) => v?.toString() ?? '';

  /// 以点号路径取值（支持 Map 键与 List 下标，如 `data.list` / `items.0`）。
  static dynamic _dig(dynamic data, String path) {
    var cur = data;
    if (path.isEmpty) return cur;
    for (final seg in path.split('.')) {
      if (cur is Map) {
        cur = cur[seg];
      } else if (cur is List) {
        final i = int.tryParse(seg);
        cur = (i != null && i >= 0 && i < cur.length) ? cur[i] : null;
      } else {
        return null;
      }
    }
    return cur;
  }

  static int _sizeFromJson(dynamic v) {
    if (v is num) return v.toInt();
    return _parseSizeStr(v?.toString());
  }
}

int _parseSizeStr(String? s) {
  if (s == null) return 0;
  final m = RegExp(
    r'([\d.]+)\s*(B|KiB|MiB|GiB|TiB|KB|MB|GB|TB)',
    caseSensitive: false,
  ).firstMatch(s);
  if (m == null) return 0;
  final v = double.tryParse(m.group(1)!) ?? 0;
  final unit = m.group(2)!.toUpperCase();
  const fac = {
    'B': 1,
    'KIB': 1024,
    'MIB': 1024 * 1024,
    'GIB': 1024 * 1024 * 1024,
    'TIB': 1024 * 1024 * 1024 * 1024,
    'KB': 1000,
    'MB': 1000 * 1000,
    'GB': 1000 * 1000 * 1000,
    'TB': 1000 * 1000 * 1000 * 1000,
  };
  return (v * (fac[unit] ?? 1)).round();
}

/// 由配置构建的检索器集合。
class BtIndexers {
  BtIndexers._();

  static List<BtIndexer> get all => BtSources.all.map(HttpIndexer.new).toList();

  static bool isEnabled(String key) {
    for (final c in BtSources.all) {
      if (c.key == key) return c.enabled;
    }
    return false;
  }

  static Future<void> setEnabled(String key, bool enabled) =>
      BtSources.setEnabled(key, enabled);

  static List<BtIndexer> enabled() =>
      all.where((e) => isEnabled(e.key)).toList();
}
