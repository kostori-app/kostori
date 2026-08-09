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
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.78,
      child: SearchSourceSheet(
        group: group,
        singleKey: singleKey,
        aggregatedKeys: aggregatedKeys,
        aggregated: aggregated,
      ),
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

  List<AnimeSource> get _sources => enabledSearchSources(_group);

  void _switchGroup(String group) {
    if (group == _group) return;
    setState(() {
      _group = group;
      final keys = _sources.map((e) => e.key).toSet();
      _selected.removeWhere((k) => !keys.contains(k));
      if (!_aggregated) {
        final sources = _sources;
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(
            children: [
              Text(
                t.chooseSearchSource,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
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
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
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
        if (_aggregated)
          SafeArea(
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
          ),
      ],
    );
  }
}
