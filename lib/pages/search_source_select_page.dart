import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/widget_utils.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/search_source_group_manage_page.dart';
import 'package:kostori/utils/search_source_groups.dart';

/// 搜索源选择弹层返回的结果
class SearchSourceSelection {
  final String group;
  final bool aggregated;
  final String? singleKey;
  final Set<String>? aggregatedKeys;

  const SearchSourceSelection({
    required this.group,
    required this.aggregated,
    this.singleKey,
    this.aggregatedKeys,
  });
}

/// 打开"选择搜索源"底部弹层：分组筛选 + 单源/聚合切换 + 源列表
Future<SearchSourceSelection?> showSearchSourceSheet(
  BuildContext context, {
  required String group,
  String? singleKey,
  Set<String>? aggregatedKeys,
  required bool aggregated,
}) {
  return showModalBottomSheet<SearchSourceSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SearchSourceSheet(
      group: group,
      singleKey: singleKey,
      aggregatedKeys: aggregatedKeys,
      aggregated: aggregated,
    ),
  );
}

/// 弹层内容：单源单选即生效；聚合多选 + 底部确定。
class SearchSourceSheet extends StatefulWidget {
  final String group;
  final String? singleKey;
  final Set<String>? aggregatedKeys;
  final bool aggregated;

  const SearchSourceSheet({
    super.key,
    required this.group,
    this.singleKey,
    this.aggregatedKeys,
    required this.aggregated,
  });

  @override
  State<SearchSourceSheet> createState() => _SearchSourceSheetState();
}

class _SearchSourceSheetState extends State<SearchSourceSheet> {
  late String _group;
  late bool _aggregated;
  late String _singleKey;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _aggregated = widget.aggregated;
    _singleKey = widget.singleKey ?? '';
    _selected = Set.of(widget.aggregatedKeys ?? {});
  }

  void _confirm() {
    Navigator.of(context).pop(
      SearchSourceSelection(
        group: _group,
        aggregated: _aggregated,
        singleKey: _aggregated ? null : _singleKey,
        aggregatedKeys: _aggregated ? _selected : null,
      ),
    );
  }

  Future<void> _manageGroups() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchSourceGroupManagePage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Sheet(
      title: t.chooseSearchSource,
      icon: Icons.travel_explore,
      initialSize: 0.78,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CapsuleOptions(
            alignment: WrapAlignment.end,
            children: [
              CapsuleOption(
                text: t.singleSourceSearch,
                isSelected: !_aggregated,
                onTap: () => setState(() => _aggregated = false),
              ),
              CapsuleOption(
                text: t.aggregatedSearch,
                isSelected: _aggregated,
                onTap: () => setState(() => _aggregated = true),
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: t.manageGroups,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.tune, size: 20, color: cs.primary),
            onPressed: _manageGroups,
          ),
        ],
      ),
      footer: _aggregated
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selected.isEmpty ? null : _confirm,
                    icon: const Icon(Icons.check),
                    label: Text('${t.apply} (${_selected.length})'),
                  ),
                ),
              ),
            )
          : null,
      builder: (context, sc) => SearchSourcePicker(
        multiSelect: _aggregated,
        selected: _aggregated
            ? _selected
            : {if (_singleKey.isNotEmpty) _singleKey},
        initialGroup: _group,
        onChanged: (selected, group) {
          setState(() {
            _selected = selected;
            _group = group;
            if (!_aggregated && selected.isNotEmpty) {
              _singleKey = selected.first;
            }
          });
          // 单源模式点选即生效（切换分组不再走这里，不会自动退出）
          if (!_aggregated) _confirm();
        },
        // 切换源分组只更新分组，不触发确认退出
        onGroupChanged: (group) {
          setState(() => _group = group);
        },
      ),
    );
  }
}

/// 可复用的搜索源选择器：分组胶囊筛选 + 搜索框 + 条目卡片列表。
/// 单选点选即回调；多选（聚合搜索）切换勾选。
/// [sourceProvider]/[groupsProvider] 可覆盖数据源：默认只列启用的搜索源；
/// 文本规则绑定等场景传全部源（禁用/无搜索页的源也要能绑）。
class SearchSourcePicker extends StatefulWidget {
  const SearchSourcePicker({
    super.key,
    required this.multiSelect,
    required this.selected,
    required this.onChanged,
    this.onGroupChanged,
    this.initialGroup = 'all',
    this.sourceProvider,
    this.groupsProvider,
  });

  /// 是否多选（聚合搜索）
  final bool multiSelect;

  /// 当前选中的源 key（单选时只有一个）
  final Set<String> selected;

  /// 选中变化 / 切换分组时回调 (selected, group)
  final void Function(Set<String> selected, String group) onChanged;

  /// 切换分组时的独立回调（只更新分组，不触发选中确认/退出）
  final void Function(String group)? onGroupChanged;

  final String initialGroup;

  /// 按分组取源列表；null 用默认的启用搜索源
  final List<AnimeSource> Function(String group)? sourceProvider;

  /// 分组列表；null 用默认的搜索分组
  final List<String> Function()? groupsProvider;

  @override
  State<SearchSourcePicker> createState() => _SearchSourcePickerState();
}

class _SearchSourcePickerState extends State<SearchSourcePicker> {
  late String _group;
  late Set<String> _selected;
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _selected = Set.of(widget.selected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AnimeSource> get _groupSources {
    final provider = widget.sourceProvider;
    if (provider != null) return provider(_group);
    return enabledSearchSources(_group);
  }

  List<AnimeSource> get _sources {
    final k = _keyword.trim().toLowerCase();
    final list = _groupSources;
    if (k.isEmpty) return list;
    return list
        .where(
          (s) =>
              s.name.toLowerCase().contains(k) ||
              s.key.toLowerCase().contains(k),
        )
        .toList();
  }

  void _switchGroup(String group) {
    if (group == _group) return;
    setState(() {
      _group = group;
      _keyword = '';
      _searchCtrl.clear();
      final keys = _groupSources.map((e) => e.key).toSet();
      _selected.removeWhere((k) => !keys.contains(k));
      if (!widget.multiSelect && _selected.isEmpty) {
        final sources = _groupSources;
        if (sources.isNotEmpty) _selected = {sources.first.key};
      }
    });
    // 切换分组不走 onChanged（单源模式 onChanged 会直接 pop 退出），
    // 只通知分组变化，由上层决定是否更新选中
    if (widget.onGroupChanged != null) {
      widget.onGroupChanged!(_group);
    } else {
      widget.onChanged(Set.of(_selected), _group);
    }
  }

  void _toggle(AnimeSource source, bool selected) {
    setState(() {
      if (widget.multiSelect) {
        if (selected) {
          _selected.add(source.key);
        } else {
          _selected.remove(source.key);
        }
      } else {
        _selected = {source.key};
      }
      widget.onChanged(Set.of(_selected), _group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = widget.groupsProvider?.call() ?? searchGroups();
    // 当前分组在新数据源下不存在时回退（直接取修正值参与本次构建，不调 setState）
    if (!groups.contains(_group)) {
      _group = groups.isNotEmpty ? groups.first : 'all';
    }
    final sources = _sources;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CapsuleOptions(
              children: [
                for (final group in groups)
                  CapsuleOption(
                    text: searchGroupLabel(group),
                    isSelected: _group == group,
                    onTap: () => _switchGroup(group),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // 源搜索筛选
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (v) => setState(() => _keyword = v),
            decoration: InputDecoration(
              hintText: t.search,
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        Expanded(
          child: sources.isEmpty
              ? Center(
                  child: Text(
                    t.noSearchSources,
                    style: TextStyle(color: cs.onSurface.toOpacity(0.5)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  children: [
                    for (final source in sources)
                      SelectCard(
                        title: source.name,
                        selected: _selected.contains(source.key),
                        onChanged: (v) => _toggle(source, v),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
