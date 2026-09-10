import 'package:kostori/foundation/appdata.dart';

/// 文本规则的单个“查找 → 替换”步骤（正则；替换支持 `$1`、`${name}`）
class TextRuleStep {
  final String find;
  final String replace;
  final bool caseSensitive;

  const TextRuleStep({
    required this.find,
    this.replace = '',
    this.caseSensitive = false,
  });

  Map<String, dynamic> toJson() => {
    'find': find,
    'replace': replace,
    'caseSensitive': caseSensitive,
  };

  static TextRuleStep fromJson(Map m) => TextRuleStep(
    find: m['find']?.toString() ?? '',
    replace: m['replace']?.toString() ?? '',
    caseSensitive: m['caseSensitive'] == true,
  );

  TextRuleStep copyWith({
    String? find,
    String? replace,
    bool? caseSensitive,
  }) => TextRuleStep(
    find: find ?? this.find,
    replace: replace ?? this.replace,
    caseSensitive: caseSensitive ?? this.caseSensitive,
  );
}

/// 一条文本规则：若干步骤按顺序执行
class TextRule {
  final String id;
  String name;
  List<TextRuleStep> steps;

  TextRule({required this.id, required this.name, List<TextRuleStep>? steps})
    : steps = steps ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'steps': steps.map((e) => e.toJson()).toList(),
  };

  static TextRule fromJson(Map m) => TextRule(
    id: m['id']?.toString() ?? '',
    name: m['name']?.toString() ?? '',
    steps:
        (m['steps'] as List?)
            ?.whereType<Map>()
            .map((e) => TextRuleStep.fromJson(e))
            .toList() ??
        [],
  );
}

/// 文本规则存储与执行（存于 `implicitData['textRules']`）
class TextRuleStore {
  static const String _key = 'textRules';
  static List<TextRule>? _cache;

  static List<TextRule> get rules {
    if (_cache != null) return _cache!;
    final raw = appdata.implicitData[_key];
    final list = <TextRule>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) list.add(TextRule.fromJson(e));
      }
    }
    return _cache = list;
  }

  static void invalidate() => _cache = null;

  static void save() {
    appdata.implicitData[_key] = rules.map((e) => e.toJson()).toList();
    appdata.writeImplicitData();
  }

  static TextRule? byId(String id) {
    for (final r in rules) {
      if (r.id == id) return r;
    }
    return null;
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// 按顺序把规则应用到文本
  static String apply(String input, Iterable<TextRule> rules) {
    var text = input;
    for (final rule in rules) {
      for (final step in rule.steps) {
        text = _applyStep(text, step);
      }
    }
    return text;
  }

  static String _applyStep(String input, TextRuleStep step) {
    if (step.find.isEmpty) return input;
    try {
      final re = RegExp(step.find, caseSensitive: step.caseSensitive);
      return input.replaceAllMapped(re, (m) => _expand(m, step.replace));
    } catch (_) {
      return input;
    }
  }

  /// 展开替换串中的 `$1`、`${1}`、`${name}`（`$$` 表示字面 `$`）
  static String _expand(Match m, String replacement) {
    final sb = StringBuffer();
    for (var i = 0; i < replacement.length; i++) {
      final ch = replacement[i];
      if (ch == r'$' && i + 1 < replacement.length) {
        final next = replacement[i + 1];
        if (next == r'$') {
          sb.write(r'$');
          i++;
          continue;
        }
        if (next == '{') {
          final end = replacement.indexOf('}', i + 2);
          if (end > 0) {
            final name = replacement.substring(i + 2, end);
            final n = int.tryParse(name);
            if (n != null) {
              sb.write(m.group(n) ?? '');
            } else if (m is RegExpMatch &&
                m.groupNames.contains(name)) {
              sb.write(m.namedGroup(name) ?? '');
            }
            i = end;
            continue;
          }
        }
        final d = int.tryParse(next);
        if (d != null) {
          sb.write(m.group(d) ?? '');
          i++;
          continue;
        }
      }
      sb.write(ch);
    }
    return sb.toString();
  }
}

/// 番源 → 选用的文本规则（存于 `implicitData['animeSourceTextRules']`）
class SourceTextRuleConfig {
  static const String _key = 'animeSourceTextRules';

  static List<String> ruleIdsFor(String sourceKey) {
    final raw = appdata.implicitData[_key];
    if (raw is Map) {
      final v = raw[sourceKey];
      if (v is List) return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static void setRuleIds(String sourceKey, List<String> ids) {
    final map = Map<String, dynamic>.from(
      appdata.implicitData[_key] as Map? ?? {},
    );
    if (ids.isEmpty) {
      map.remove(sourceKey);
    } else {
      map[sourceKey] = ids;
    }
    appdata.implicitData[_key] = map;
    appdata.writeImplicitData();
  }

  static List<TextRule> rulesFor(String sourceKey) {
    final out = <TextRule>[];
    for (final id in ruleIdsFor(sourceKey)) {
      final r = TextRuleStore.byId(id);
      if (r != null) out.add(r);
    }
    return out;
  }

  static bool hasRules(String sourceKey) => rulesFor(sourceKey).isNotEmpty;

  static String applyTo(String sourceKey, String input) =>
      TextRuleStore.apply(input, rulesFor(sourceKey));
}
