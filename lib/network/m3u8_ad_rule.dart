import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

enum M3u8RuleType { urlPattern, domainBlock, maxDuration, tagPresent, keyword }

class M3u8AdRule {
  final String name;
  final bool enabled;
  final M3u8RuleType type;

  final String? pattern;

  final List<String>? blockedDomains;

  final double? maxDuration;

  final String? tag;

  /// 是否大小写敏感（仅 urlPattern / keyword 生效，默认不敏感）
  final bool caseSensitive;

  /// 正则编译缓存（key: pattern@case）
  static final Map<String, RegExp> _regexCache = {};

  RegExp _compile(String p) {
    final cacheKey = '$caseSensitive@$p';
    return _regexCache[cacheKey] ??= RegExp(p, caseSensitive: caseSensitive);
  }

  const M3u8AdRule({
    required this.name,
    required this.type,
    this.enabled = true,
    this.pattern,
    this.blockedDomains,
    this.maxDuration,
    this.tag,
    this.caseSensitive = false,
  });

  factory M3u8AdRule.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    // 未知类型降级为 urlPattern，避免一条坏数据拖垮整个规则列表
    final type = M3u8RuleType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => M3u8RuleType.urlPattern,
    );
    return M3u8AdRule(
      name: json['name']?.toString() ?? '',
      type: type,
      enabled: json['enabled'] as bool? ?? true,
      pattern: json['pattern']?.toString(),
      blockedDomains: (json['blockedDomains'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      maxDuration: (json['maxDuration'] as num?)?.toDouble(),
      tag: json['tag']?.toString(),
      caseSensitive: json['caseSensitive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'enabled': enabled,
    if (pattern != null) 'pattern': pattern,
    if (blockedDomains != null) 'blockedDomains': blockedDomains,
    if (maxDuration != null) 'maxDuration': maxDuration,
    if (tag != null) 'tag': tag,
    if (caseSensitive) 'caseSensitive': true,
  };

  /// 当前规则是否匹配该分片。
  /// [segUri] 解析后的分片 URL；[duration] 分片时长秒数。
  bool matches(String segUri, double duration) {
    switch (type) {
      case M3u8RuleType.urlPattern:
        final p = pattern;
        if (p == null || p.isEmpty) return false;
        return _compile(p).hasMatch(segUri);
      case M3u8RuleType.keyword:
        final k = pattern;
        if (k == null || k.isEmpty) return false;
        return caseSensitive
            ? segUri.contains(k)
            : segUri.toLowerCase().contains(k.toLowerCase());
      case M3u8RuleType.domainBlock:
        final host = Uri.tryParse(segUri)?.host ?? '';
        if (host.isEmpty) return false;
        final domains = blockedDomains ?? const [];
        return domains.any((d) => host == d || host.endsWith('.$d'));
      case M3u8RuleType.maxDuration:
        final m = maxDuration;
        return m != null && duration > 0 && duration < m;
      case M3u8RuleType.tagPresent:
        return false; // tag 规则由播放列表行级处理
    }
  }
}

/// 规则仓库：从 appdata 读写，带内置默认规则
class M3u8AdRuleStore {
  static const _key = 'm3u8AdRules';

  static List<M3u8AdRule>? _cache;

  /// 解析并缓存规则列表；解析失败/空列表回退默认规则
  static List<M3u8AdRule> get rules {
    final cached = _cache;
    if (cached != null) return cached;
    final saved = appdata.settings[_key];
    if (saved is List && saved.isNotEmpty) {
      final parsed = <M3u8AdRule>[];
      for (final item in saved) {
        if (item is! Map) continue;
        try {
          parsed.add(M3u8AdRule.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // 单条解析失败不影响其余规则
        }
      }
      if (parsed.isNotEmpty) {
        _cache = List.unmodifiable(parsed);
        return _cache!;
      }
    }
    _cache = List.unmodifiable(_defaults);
    return _cache!;
  }

  static void save(List<M3u8AdRule> rules) {
    appdata.settings[_key] = rules.map((r) => r.toJson()).toList();
    appdata.saveData();
    _cache = null; // 失效缓存
  }

  static void invalidate() => _cache = null;

  static List<M3u8AdRule> get _defaults => [
    M3u8AdRule(
      name: t.cueAdTag,
      type: M3u8RuleType.tagPresent,
      tag: '#EXT-X-CUE-OUT',
    ),
    M3u8AdRule(
      name: t.ultraShortSegment,
      type: M3u8RuleType.maxDuration,
      maxDuration: 4.0,
    ),
    M3u8AdRule(
      name: t.commonAdUrlPattern,
      type: M3u8RuleType.urlPattern,
      pattern: r'ad[_\-]?segment|commercial|preroll|midroll|/ads?/',
    ),
    M3u8AdRule(
      name: t.commonAdKeyword,
      type: M3u8RuleType.keyword,
      pattern: r'advert',
    ),
  ];
}
