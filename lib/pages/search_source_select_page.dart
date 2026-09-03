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
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _aggregated = widget.aggregated;
    _singleKey = widget.singleKey ?? '';
    _selected = Set.of(widget.aggregatedKeys ?? {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 当前分组全部源（未过滤，供切换分组等逻辑用）
  List<AnimeSource> get _groupSources => enabledSearchSources(_group);

  /// 按关键词过滤后的源列表（显示用）
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
      if (!_aggregated) {
        final sources = _groupSources;
        if (sources.isNotEmpty && !sources.any((e) => e.key == _singleKey)) {
          _singleKey = sources.first.key;
        }
      }
    });
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
    final sources = _sources;
    return Sheet(
      title: t.chooseSearchSource,
      icon: Icons.travel_explore,
      initialSize: 0.78,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(t.singleSourceSearch),
              ),
              ButtonSegment(value: true, label: Text(t.aggregatedSearch)),
            ],
            selected: {_aggregated},
            onSelectionChanged: (s) =>
                setState(() => _aggregated = s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
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
                    onPressed: sources.isEmpty ? null : _confirm,
                    icon: const Icon(Icons.check),
                    label: Text('${t.apply} (${_selected.length})'),
                  ),
                ),
              ),
            )
          : null,
      builder: (context, sc) => Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final group in searchGroups())
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OptionChip(
                      text: searchGroupLabel(group),
                      isSelected: _group == group,
                      onTap: () => _switchGroup(group),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 源搜索筛选
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
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
                    children: [
                      for (final source in sources)
                        _aggregated
                            ? CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                title: Text(source.name),
                                value: _selected.contains(source.key),
                                onChanged: (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(source.key);
                                  } else {
                                    _selected.remove(source.key);
                                  }
                                }),
                              )
                            : ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                leading: Icon(
                                  _singleKey == source.key
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: _singleKey == source.key
                                      ? cs.primary
                                      : cs.onSurfaceVariant,
                                ),
                                title: Text(source.name),
                                onTap: () {
                                  setState(() => _singleKey = source.key);
                                  _confirm();
                                },
                              ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
