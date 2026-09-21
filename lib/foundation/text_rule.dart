import 'dart:async';
import 'dart:convert';

import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';

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

  /// 按顺序把规则应用到文本（叠加语义：后规则看到前规则处理过的文本）。
  /// 注意：跨规则默认请用 [applyFirstHit]（单一应用，命中即停）；
  /// 本方法保留给“一条规则内部多步骤”（[TextRule.steps] 本来就是多步）
  /// 与明确需要叠加的调用方。
  static String apply(String input, Iterable<TextRule> rules) {
    var text = input;
    for (final rule in rules) {
      for (final step in rule.steps) {
        text = _applyStep(text, step);
      }
    }
    return text;
  }

  /// 单一应用：按优先级顺序（列表顺序）逐条试，第一条命中（改变文本）的规则
  /// 生效后即停，后续规则不再作用于已被正则过的文本。
  /// 未命中任何规则时返回原文。
  static String applyFirstHit(String input, Iterable<TextRule> rules) {
    for (final rule in rules) {
      var text = input;
      var changed = false;
      for (final step in rule.steps) {
        final next = _applyStep(text, step);
        if (next != text) changed = true;
        text = next;
      }
      if (changed) return text;
    }
    return input;
  }

  /// 返回首个命中的规则在 [rules] 中的下标，未命中返回 -1。
  /// 供测试弹窗展示“命中了几条/命中后文本是什么”。
  static int firstHitIndex(String input, List<TextRule> rules) {
    for (var i = 0; i < rules.length; i++) {
      var text = input;
      var changed = false;
      for (final step in rules[i].steps) {
        final next = _applyStep(text, step);
        if (next != text) changed = true;
        text = next;
      }
      if (changed) return i;
    }
    return -1;
  }

  static String _applyStep(String input, TextRuleStep step) {
    if (step.find.isEmpty) return input;
    try {
      final re = RegExp(step.find, caseSensitive: step.caseSensitive);
      // 全部匹配都会被替换；没有匹配到就是原样返回（多条规则不会互相“报错”，
      // 只是按顺序依次作用：后面的规则看到的是前面规则处理过的文本）
      return input.replaceAllMapped(re, (m) => _expand(m, step.replace));
    } catch (e) {
      Log.warning('TextRule', '正则无效，已跳过该步骤「${step.find}」：$e');
      return input;
    }
  }

  /// 预览用：对每一步报告 `skipped（空）/invalid（正则非法）/miss（零匹配）/
  /// hit（命中 n 处）`，与 [_applyStep] 同语义（后步看到前步处理过的文本）。
  ///
  /// 解决“规则明明保存了却没生效，用户看不出是没匹配还是没启用”：
  /// 编辑弹窗逐条展示命中状态，一眼定位。
  static List<TextRuleStepReport> dryRun(
    String input,
    Iterable<TextRuleStep> steps,
  ) {
    final out = <TextRuleStepReport>[];
    var text = input;
    for (final step in steps) {
      if (step.find.isEmpty) {
        out.add(const TextRuleStepReport(TextRuleStepState.skipped, 0));
        continue;
      }
      RegExp re;
      try {
        re = RegExp(step.find, caseSensitive: step.caseSensitive);
      } catch (_) {
        out.add(const TextRuleStepReport(TextRuleStepState.invalid, 0));
        continue;
      }
      final hits = re.allMatches(text).length;
      if (hits == 0) {
        out.add(const TextRuleStepReport(TextRuleStepState.miss, 0));
      } else {
        text = text.replaceAllMapped(re, (m) => _expand(m, step.replace));
        out.add(TextRuleStepReport(TextRuleStepState.hit, hits));
      }
    }
    return out;
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

/// [TextRuleStore.dryRun] 单步报告
enum TextRuleStepState {
  /// find 为空，跳过
  skipped,

  /// 正则非法，应用时同样跳过
  invalid,

  /// 零匹配：原文原样保留（“没生效”最常见原因）
  miss,

  /// 命中
  hit,
}

class TextRuleStepReport {
  final TextRuleStepState state;

  ///命中处数（仅 hit 时有意义）
  final int hits;

  const TextRuleStepReport(this.state, this.hits);
}

/// 番源自身数据文件（`anime_source/<key>.data`）里的本地配置键。
///
/// 这些配置存在源数据里而不是 `implicitData`：`implicitData` 是被刻意排除在
/// 同步之外的（含下载目录、并发数等设备本地设置），而源数据文件随「数据」
/// 同步部分一起上传/下载，多端即可共享这些配置。
class SourceLocalConfig {
  static const String _rulesKey = 'textRuleIds';

  static const String _titleFormatKey = 'downloadTitleFormat';

  /// 文本规则 id 列表
  static List<String> ruleIdsIn(Map<dynamic, dynamic> data) {
    final v = data[_rulesKey];
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  static void setRuleIdsIn(Map<String, dynamic> data, List<String> ids) {
    if (ids.isEmpty) {
      data.remove(_rulesKey);
    } else {
      data[_rulesKey] = ids;
    }
  }

  /// 下载标题格式（文件名模板）
  static String titleFormatIn(Map<dynamic, dynamic> data) =>
      data[_titleFormatKey]?.toString() ?? '';

  static void setTitleFormatIn(Map<String, dynamic> data, String format) {
    final v = format.trim();
    if (v.isEmpty) {
      data.remove(_titleFormatKey);
    } else {
      data[_titleFormatKey] = v;
    }
  }
}

/// 番源 → 选用的文本规则 / 下载标题格式（存于该源自己的数据文件）。
///
/// 规则的定义存在 `history.db` 的 `text_rules` 表（随 history 同步），
/// 这里只保存「哪个源选了哪些规则」，随源数据一起同步。
class SourceTextRuleConfig {
  /// 旧版存储（`implicitData['animeSourceTextRules']`）：读取时一次性迁移到
  /// 源数据文件，迁移后不再回退，避免「取消勾选后又被旧值复活」。
  static const String legacyImplicitKey = 'animeSourceTextRules';

  static AnimeSource? _sourceOf(String sourceKey) =>
      AnimeSource.find(sourceKey);

  static List<String> ruleIdsFor(String sourceKey) {
    final source = _sourceOf(sourceKey);
    if (source == null) return const [];
    final ids = SourceLocalConfig.ruleIdsIn(source.data);
    if (ids.isNotEmpty) return ids;
    final legacy = _legacyRuleIdsFor(sourceKey);
    if (legacy.isEmpty) return const [];
    // 迁移旧选择到源数据（随「数据」部分同步），并清掉旧存储
    SourceLocalConfig.setRuleIdsIn(source.data, legacy);
    _removeLegacy(sourceKey);
    unawaited(source.saveData());
    return legacy;
  }

  static void setRuleIds(String sourceKey, List<String> ids) {
    final source = _sourceOf(sourceKey);
    if (source == null) return;
    SourceLocalConfig.setRuleIdsIn(source.data, ids);
    _removeLegacy(sourceKey);
    unawaited(source.saveData());
  }

  static List<String> _legacyRuleIdsFor(String sourceKey) {
    final raw = appdata.implicitData[legacyImplicitKey];
    if (raw is Map) {
      final v = raw[sourceKey];
      if (v is List) return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static void _removeLegacy(String sourceKey) {
    final raw = appdata.implicitData[legacyImplicitKey];
    if (raw is! Map || !raw.containsKey(sourceKey)) return;
    final map = Map<String, dynamic>.from(raw)..remove(sourceKey);
    if (map.isEmpty) {
      appdata.implicitData.remove(legacyImplicitKey);
    } else {
      appdata.implicitData[legacyImplicitKey] = map;
    }
    appdata.writeImplicitData();
  }

  /// 该源的下载标题格式（文件名模板）
  static String titleFormatFor(String sourceKey) =>
      SourceLocalConfig.titleFormatIn(_sourceOf(sourceKey)?.data ?? const {});

  static void setTitleFormat(String sourceKey, String format) {
    final source = _sourceOf(sourceKey);
    if (source == null) return;
    SourceLocalConfig.setTitleFormatIn(source.data, format);
    unawaited(source.saveData());
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

  /// 源内应用：单一应用语义——按优先级顺序，第一条命中的规则生效即停，
  /// 而不是把已正则过的文本再喂给下一条规则。
  static String applyTo(String sourceKey, String input) =>
      TextRuleStore.applyFirstHit(input, rulesFor(sourceKey));

  /// 有多少个番源选用了该规则
  static int countSourcesUsing(String ruleId) =>
      sourcesUsing(ruleId).length;

  /// 选用该规则的所有番源 key
  static Set<String> sourcesUsing(String ruleId) {
    final out = <String>{};
    for (final source in AnimeSourceManager().all()) {
      if (ruleIdsFor(source.key).contains(ruleId)) out.add(source.key);
    }
    return out;
  }

  /// 设置“哪些番源使用该规则”（其余番源移除该规则）
  static void setSourcesForRule(String ruleId, Set<String> sourceKeys) {
    for (final source in AnimeSourceManager().all()) {
      final list = ruleIdsFor(source.key);
      final wanted = sourceKeys.contains(source.key);
      final has = list.contains(ruleId);
      if (wanted == has) continue;
      if (wanted) {
        SourceLocalConfig.setRuleIdsIn(source.data, [...list, ruleId]);
      } else {
        SourceLocalConfig.setRuleIdsIn(
          source.data,
          list.where((e) => e != ruleId).toList(),
        );
      }
      unawaited(source.saveData());
    }
  }
}
