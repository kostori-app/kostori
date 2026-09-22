// 角色世界书（SillyTavern character_book）解析与激活。
// 注意：它与项目全局世界书（WorldBookEntry）是两套逻辑，故独立处理，
// 仅在角色卡被激活（在场 / 被绑定）时扫描并注入，不并入全局库。

import 'dart:math' as math;

/// character_book 中的单个条目（保留 ST 语义字段）
class CharacterLoreEntry {
  final int index;
  final String name;
  final List<String> keys;
  final List<String> secondaryKeys;
  final String content;
  final bool enabled;

  /// 常驻：无视触发词始终注入
  final bool constant;

  /// 次级键是否参与判断
  final bool selective;

  /// 0=AND_ANY 1=NOT_ALL 2=NOT_ANY 3=AND_ALL
  final int selectiveLogic;
  final bool caseSensitive;
  final bool matchWholeWords;
  final int insertionOrder;

  /// before_char | after_char | at_depth
  final String position;
  final int depth;
  final int probability;
  final bool useProbability;
  final int sticky;
  final int cooldown;
  final int delay;
  final String group;
  final int groupWeight;

  const CharacterLoreEntry({
    required this.index,
    this.name = '',
    this.keys = const [],
    this.secondaryKeys = const [],
    this.content = '',
    this.enabled = true,
    this.constant = false,
    this.selective = false,
    this.selectiveLogic = 0,
    this.caseSensitive = false,
    this.matchWholeWords = false,
    this.insertionOrder = 100,
    this.position = 'after_char',
    this.depth = 4,
    this.probability = 100,
    this.useProbability = true,
    this.sticky = 0,
    this.cooldown = 0,
    this.delay = 0,
    this.group = '',
    this.groupWeight = 100,
  });

  factory CharacterLoreEntry.fromJson(int index, Map<String, dynamic> e) {
    List<String> strList(Object? v) =>
        v is List ? v.whereType<String>().toList() : const <String>[];
    int intOf(Object? a, Object? b, int fallback) {
      final v = a ?? b;
      return v is num ? v.toInt() : fallback;
    }

    return CharacterLoreEntry(
      index: index,
      name: (e['name'] ?? e['comment'] ?? '').toString(),
      keys: strList(e['keys'] ?? e['key']),
      secondaryKeys: strList(e['secondary_keys'] ?? e['secondaryKeys']),
      content: (e['content'] ?? '').toString(),
      enabled: e['enabled'] as bool? ?? true,
      constant: e['constant'] as bool? ?? false,
      selective: e['selective'] as bool? ?? false,
      selectiveLogic: intOf(e['selectiveLogic'], e['selective_logic'], 0),
      caseSensitive:
          (e['case_sensitive'] as bool?) ??
          (e['caseSensitive'] as bool?) ??
          false,
      matchWholeWords: e['matchWholeWords'] as bool? ?? false,
      insertionOrder: intOf(e['insertion_order'], e['insertionOrder'], 100),
      position: (e['position'] ?? 'after_char').toString(),
      depth: intOf(e['depth'], null, 4),
      probability: intOf(e['probability'], null, 100),
      useProbability: e['useProbability'] as bool? ?? true,
      sticky: intOf(e['sticky'], null, 0),
      cooldown: intOf(e['cooldown'], null, 0),
      delay: intOf(e['delay'], null, 0),
      group: (e['group'] as String?) ?? '',
      groupWeight: intOf(e['group_weight'], e['groupWeight'], 100),
    );
  }
}

/// 角色世界书（整本书）
class CharacterLoreBook {
  final int scanDepth;
  final int tokenBudget;
  final bool recursiveScanning;
  final List<CharacterLoreEntry> entries;

  const CharacterLoreBook({
    this.scanDepth = 4,
    this.tokenBudget = 500,
    this.recursiveScanning = false,
    this.entries = const [],
  });

  static CharacterLoreBook? fromMap(Map<String, dynamic>? book) {
    if (book == null) return null;
    final raw = book['entries'];
    final entries = <CharacterLoreEntry>[];
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final e = raw[i];
        if (e is Map) {
          entries.add(
            CharacterLoreEntry.fromJson(i, e.cast<String, dynamic>()),
          );
        }
      }
    }
    if (entries.isEmpty) return null;
    return CharacterLoreBook(
      scanDepth: (book['scan_depth'] as num?)?.toInt() ?? 4,
      tokenBudget: (book['token_budget'] as num?)?.toInt() ?? 500,
      recursiveScanning: book['recursive_scanning'] as bool? ?? false,
      entries: entries,
    );
  }
}

/// 角色世界书激活器：处理触发 / 次级键 / 常驻 / 递归 / sticky / 冷却 / 概率 / 分组
class CharacterLorebookResolver {
  static final CharacterLorebookResolver instance =
      CharacterLorebookResolver._();

  CharacterLorebookResolver._();

  final Map<String, int> _stickyUntil = {};
  final Map<String, int> _cooldownUntil = {};

  /// 解析激活条目，按 insertion_order 升序返回
  List<CharacterLoreEntry> resolve(
    CharacterLoreBook book,
    List<String> recentMessages, {
    required String cardId,
    required int turn,
    int maxRecursive = 3,
  }) {
    final depth = book.scanDepth <= 0 ? 1 : book.scanDepth;
    final window = recentMessages.length <= depth
        ? recentMessages
        : recentMessages.sublist(recentMessages.length - depth);
    final scanText = window.join('\n');

    final enabled = book.entries.where((e) => e.enabled).toList()
      ..sort((a, b) => a.insertionOrder.compareTo(b.insertionOrder));

    final selected = <CharacterLoreEntry>[];
    final selectedIdx = <int>{};
    final rng = math.Random();

    String stateKey(CharacterLoreEntry e) => '$cardId#${e.index}';

    bool cooling(CharacterLoreEntry e) {
      final until = _cooldownUntil[stateKey(e)];
      return until != null && turn < until;
    }

    bool isSticky(CharacterLoreEntry e) {
      final until = _stickyUntil[stateKey(e)];
      return until != null && turn < until;
    }

    void activate(CharacterLoreEntry e) {
      selected.add(e);
      selectedIdx.add(e.index);
      if (e.sticky > 0) _stickyUntil[stateKey(e)] = turn + e.sticky;
      if (e.cooldown > 0) {
        _cooldownUntil[stateKey(e)] = turn + e.sticky + e.cooldown;
      }
    }

    for (final e in enabled) {
      if (e.delay > 0 && turn < e.delay) continue;
      if (cooling(e)) continue;
      if (_matches(e, scanText) || isSticky(e)) activate(e);
    }

    // 书级递归：用已注入内容继续扫描
    if (book.recursiveScanning) {
      for (var d = 0; d < maxRecursive; d++) {
        final hay = selected.map((e) => e.content).join('\n');
        if (hay.isEmpty) break;
        final before = selected.length;
        for (final e in enabled) {
          if (selectedIdx.contains(e.index) || cooling(e)) continue;
          if (_matches(e, hay)) activate(e);
        }
        if (selected.length == before) break;
      }
    }

    // 概率
    var result = selected
        .where(
          (e) =>
              !e.useProbability ||
              e.probability >= 100 ||
              rng.nextInt(100) < e.probability,
        )
        .toList();

    // 分组：同组按权重随机保留一个
    final groups = <String, List<CharacterLoreEntry>>{};
    final ungrouped = <CharacterLoreEntry>[];
    for (final e in result) {
      if (e.group.isEmpty) {
        ungrouped.add(e);
      } else {
        groups.putIfAbsent(e.group, () => []).add(e);
      }
    }
    result = [...ungrouped];
    for (final g in groups.values) {
      if (g.length == 1) {
        result.add(g.first);
        continue;
      }
      final total = g.fold<int>(
        0,
        (a, e) => a + (e.groupWeight <= 0 ? 1 : e.groupWeight),
      );
      var pick = rng.nextInt(total);
      for (final e in g) {
        pick -= (e.groupWeight <= 0 ? 1 : e.groupWeight);
        if (pick < 0) {
          result.add(e);
          break;
        }
      }
    }
    result.sort((a, b) => a.insertionOrder.compareTo(b.insertionOrder));

    // token 预算（按 4 字符 ≈ 1 token 近似）
    final budgetChars = (book.tokenBudget <= 0 ? 500 : book.tokenBudget) * 4;
    final out = <CharacterLoreEntry>[];
    var used = 0;
    for (final e in result) {
      final len = e.content.length;
      if (out.isNotEmpty && used + len > budgetChars) break;
      out.add(e);
      used += len;
    }
    return out;
  }

  /// 是否命中条目（keys + selective/secondaryKeys/selectiveLogic/constant）
  bool _matches(CharacterLoreEntry e, String text) {
    if (e.constant) return true;
    if (!e.keys.any((k) => _keyHit(text, k, e))) return false;
    if (!e.selective || e.secondaryKeys.isEmpty) return true;
    final hits = e.secondaryKeys.where((k) => _keyHit(text, k, e)).length;
    return switch (e.selectiveLogic) {
      1 => hits != e.secondaryKeys.length, // NOT_ALL
      2 => hits == 0, // NOT_ANY
      3 => hits == e.secondaryKeys.length, // AND_ALL
      _ => hits > 0, // AND_ANY
    };
  }

  bool _keyHit(String text, String key, CharacterLoreEntry e) {
    if (key.trim().isEmpty) return false;
    var hay = text;
    var needle = key.trim();
    if (!e.caseSensitive) {
      hay = hay.toLowerCase();
      needle = needle.toLowerCase();
    }
    if (e.matchWholeWords) {
      final re = RegExp(
        '(?:^|[^A-Za-z0-9_])${RegExp.escape(needle)}(?:\$|[^A-Za-z0-9_])',
      );
      return re.hasMatch(hay);
    }
    return hay.contains(needle);
  }
}
