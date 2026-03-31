import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

enum M3u8RuleType { urlPattern, domainBlock, maxDuration, tagPresent }

class M3u8AdRule {
  final String name;
  final bool enabled;
  final M3u8RuleType type;

  final String? pattern;

  final List<String>? blockedDomains;

  final double? maxDuration;

  final String? tag;

  const M3u8AdRule({
    required this.name,
    required this.type,
    this.enabled = true,
    this.pattern,
    this.blockedDomains,
    this.maxDuration,
    this.tag,
  });

  factory M3u8AdRule.fromJson(Map<String, dynamic> json) => M3u8AdRule(
    name: json['name'] ?? '',
    type: M3u8RuleType.values.byName(json['type']),
    enabled: json['enabled'] ?? true,
    pattern: json['pattern'],
    blockedDomains: (json['blockedDomains'] as List?)?.cast<String>(),
    maxDuration: (json['maxDuration'] as num?)?.toDouble(),
    tag: json['tag'],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'enabled': enabled,
    if (pattern != null) 'pattern': pattern,
    if (blockedDomains != null) 'blockedDomains': blockedDomains,
    if (maxDuration != null) 'maxDuration': maxDuration,
    if (tag != null) 'tag': tag,
  };
}

/// 规则仓库：从 appdata 读写，带内置默认规则
class M3u8AdRuleStore {
  static const _key = 'm3u8AdRules';

  static List<M3u8AdRule> get rules {
    final saved = appdata.settings[_key];
    if (saved is List && saved.isNotEmpty) {
      return saved
          .whereType<Map<String, dynamic>>()
          .map(M3u8AdRule.fromJson)
          .toList();
    }
    return _defaults;
  }

  static void save(List<M3u8AdRule> rules) {
    appdata.settings[_key] = rules.map((r) => r.toJson()).toList();
    appdata.saveData();
  }

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
  ];
}
