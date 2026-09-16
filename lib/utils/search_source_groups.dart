import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 搜索源分组相关工具。
/// 分组来源：
/// - 'all'：全部启用源；
/// - 派生分组：由源脚本在 data 中声明 `group`，否则按 isBangumi 推断（'default'/'bangumi'）；
/// - 自定义分组：用户自建，存于 implicitData['searchSourceGroups']（组名 -> 源 key 列表）。
const customSearchGroupsKey = 'searchSourceGroups';

/// 上次选中的搜索源分组（UI 偏好）
const searchSelectedGroupKey = 'searchSourceGroup';

/// 读取上次选中的分组，若已失效（被删除/不存在）则回退到 'all'
String selectedSearchGroup() {
  final raw = appdata.implicitData[searchSelectedGroupKey];
  final group = raw?.toString();
  if (group == null || !searchGroups().contains(group)) return 'all';
  return group;
}

void saveSelectedSearchGroup(String group) {
  appdata.implicitData[searchSelectedGroupKey] = group;
  appdata.writeImplicitData();
}

Map<String, List<String>> _normalizeGroups(dynamic raw) {
  if (raw is! Map) return {};
  final result = <String, List<String>>{};
  raw.forEach((k, v) {
    if (v is List) {
      result[k.toString()] = v.whereType<String>().toList();
    }
  });
  return result;
}

/// 用户自定义分组：{组名: [源 key...]}
///
/// 存于 `settings['searchSourceGroups']`（appdata.json），随 WebDAV 同步；
/// 旧版本存于 implicitData，这里读取时做一次迁移。
Map<String, List<String>> customSearchGroups() {
  final current = _normalizeGroups(appdata.settings['searchSourceGroups']);
  if (current.isNotEmpty) return current;
  final legacy = _normalizeGroups(appdata.implicitData[customSearchGroupsKey]);
  if (legacy.isNotEmpty) {
    appdata.settings['searchSourceGroups'] = legacy;
    appdata.saveData();
  }
  return legacy;
}

void saveCustomSearchGroups(Map<String, List<String>> groups) {
  appdata.settings['searchSourceGroups'] = groups;
  appdata.saveData();
}

/// 全部启用搜索源（未分组过滤）
List<AnimeSource> allEnabledSearchSources() {
  final enabled = (appdata.settings['searchSources'] as List? ?? [])
      .whereType<String>()
      .toSet();
  return AnimeSource.all()
      .where((e) => e.searchPageData != null && enabled.contains(e.key))
      .toList();
}

/// 按分组过滤后的启用搜索源；[group] 为 'all' 或 null 时返回全部启用源。
/// 自定义分组优先，其次派生分组。
List<AnimeSource> enabledSearchSources([String? group]) {
  if (group == null || group == 'all') return allEnabledSearchSources();
  final custom = customSearchGroups();
  if (custom.containsKey(group)) {
    final keys = custom[group]!.toSet();
    return allEnabledSearchSources()
        .where((e) => keys.contains(e.key))
        .toList();
  }
  return allEnabledSearchSources()
      .where((e) => e.searchGroup == group)
      .toList();
}

/// 全部搜索源分组（含自定义），'all' 恒在最前，其余按名称排序并去重。
List<String> searchGroups() {
  final derived = <String>{};
  for (final s in allEnabledSearchSources()) {
    derived.add(s.searchGroup);
  }
  final builtIn = <String>['all', ...derived.toList()..sort()];
  final custom = customSearchGroups().keys.toList()..sort();
  final result = <String>[];
  for (final g in [...builtIn, ...custom]) {
    if (!result.contains(g)) result.add(g);
  }
  return result;
}

/// 分组是否用户自建（可编辑）
bool isCustomSearchGroup(String group) =>
    customSearchGroups().containsKey(group);

/// 分组显示名称。
String searchGroupLabel(String group) => switch (group) {
  'all' => t.searchGroupAll,
  'bangumi' => t.searchGroupBangumi,
  'default' => t.searchGroupDefault,
  _ => group,
};
