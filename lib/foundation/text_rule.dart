import 'dart:async';
import 'dart:convert';

import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/appdata.dart';

/// 文本规则预览的默认示例文本
const String kTextRulePreviewDefault = '[字幕组] 示例番剧名 - 第01集 [1080P]';

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

  /// 最后修改时间（多端合并用，新者胜）
  int updatedAt;

  TextRule({
    required this.id,
    required this.name,
    List<TextRuleStep>? steps,
    this.updatedAt = 0,
  }) : steps = steps ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'steps': steps.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt,
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
    updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
  );
}

/// 文本规则存储：持久化在 `history.db` 的 `text_rules` 表，运行时用内存缓存。
class TextRuleStore {
  static List<TextRule>? _cache;
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  static List<TextRule> get rules => _cache ?? const [];

  /// 从数据库加载到内存缓存（启动时调用一次）
  static Future<void> load() async {
    try {
      final rows = await HistoryManager().getTextRules();
      _cache = rows
          .map(
            (m) => TextRule(
              id: m['id']?.toString() ?? '',
              name: m['name']?.toString() ?? '',
              steps: _decodeSteps(m['stepsJson']?.toString()),
              updatedAt: (m['updatedAt'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((r) => r.id.isNotEmpty)
          .toList();
      _loaded = true;
    } catch (_) {
      _cache ??= [];
    }
  }

  /// 重新从数据库加载
  static Future<void> reload() async {
    _loaded = false;
    await load();
  }

  static void invalidate() {
    _cache = null;
    _loaded = false;
  }

  /// 把当前内存缓存整表写回数据库（不阻塞 UI）
  static void save() {
    final list = _cache ?? const <TextRule>[];
    unawaited(
      HistoryManager().replaceTextRules([
        for (final r in list)
          {
            'id': r.id,
            'name': r.name,
            'stepsJson': jsonEncode(r.steps.map((e) => e.toJson()).toList()),
            'updatedAt': r.updatedAt,
          },
      ]),
    );
  }

  static TextRule? byId(String id) {
    for (final r in rules) {
      if (r.id == id) return r;
    }
    return null;
  }

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  static List<TextRuleStep> _decodeSteps(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final list = jsonDecode(json);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => TextRuleStep.fromJson(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

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
            } else if (m is RegExpMatch && m.groupNames.contains(name)) {
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
    final ids = ruleIdsFor(sourceKey).toSet();
    final out = <TextRule>[];
    // 按规则列表顺序返回，保证“展示顺序 == 应用顺序”
    for (final r in TextRuleStore.rules) {
      if (ids.contains(r.id)) out.add(r);
    }
    return out;
  }

  static bool hasRules(String sourceKey) => rulesFor(sourceKey).isNotEmpty;

  static String applyTo(String sourceKey, String input) =>
      TextRuleStore.apply(input, rulesFor(sourceKey));

  /// 有多少个番源选用了该规则
  static int countSourcesUsing(String ruleId) {
    final raw = appdata.implicitData[_key];
    if (raw is! Map) return 0;
    var n = 0;
    for (final v in raw.values) {
      if (v is List && v.map((e) => e.toString()).contains(ruleId)) n++;
    }
    return n;
  }

  /// 选用该规则的所有番源 key
  static Set<String> sourcesUsing(String ruleId) {
    final raw = appdata.implicitData[_key];
    final out = <String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List && v.map((e) => e.toString()).contains(ruleId)) {
          out.add(k.toString());
        }
      });
    }
    return out;
  }

  /// 设置“哪些番源使用该规则”（其余番源移除该规则）
  static void setSourcesForRule(String ruleId, Set<String> sourceKeys) {
    final map = Map<String, dynamic>.from(
      appdata.implicitData[_key] as Map? ?? {},
    );
    final keys = <String>{
      ...map.keys.map((e) => e.toString()),
      ...sourceKeys,
    };
    for (final k in keys) {
      final list = map[k] is List
          ? (map[k] as List).map((e) => e.toString()).toList()
          : <String>[];
      if (sourceKeys.contains(k)) {
        if (!list.contains(ruleId)) list.add(ruleId);
      } else {
        list.remove(ruleId);
      }
      if (list.isEmpty) {
        map.remove(k);
      } else {
        map[k] = list;
      }
    }
    appdata.implicitData[_key] = map;
    appdata.writeImplicitData();
  }
}
