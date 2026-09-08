import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/search_source_groups.dart';

/// 搜索源分组管理：内置分组只读展示，自定义分组可新建/重命名/删除/分配源。
class SearchSourceGroupManagePage extends StatefulWidget {
  const SearchSourceGroupManagePage({super.key});

  @override
  State<SearchSourceGroupManagePage> createState() =>
      _SearchSourceGroupManagePageState();
}

class _SearchSourceGroupManagePageState
    extends State<SearchSourceGroupManagePage> {
  late Map<String, List<String>> _custom;

  @override
  void initState() {
    super.initState();
    _custom = customSearchGroups();
  }

  Future<String?> _promptName({String initial = '', String? title}) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final ctrl = TextEditingController(text: initial);
        return ContentDialog(
          title: title ?? t.groupName,
          content: TextField(
            controller: ctrl,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
            decoration: InputDecoration(labelText: t.groupName),
          ),
          // 使用内置取消按钮（自动 pop 返回 null），这里只放确认
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
              child: Text(t.confirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _create() async {
    final result = await _pickGroupSources(
      creating: true,
    );
    if (result == null) return;
    final (name, selected) = result;
    final n = name.trim();
    if (n.isEmpty || _custom.containsKey(n)) {
      if (n.isNotEmpty) {
        App.rootContext.showMessage(message: t.groupExists);
      }
      return;
    }
    setState(() {
      _custom[n] = selected.toList()..sort();
      saveCustomSearchGroups(_custom);
    });
  }

  Future<void> _rename(String old) async {
    final name = await _promptName(initial: old, title: t.rename);
    if (name == null || name.isEmpty || name == old) return;
    if (_custom.containsKey(name)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    setState(() {
      _custom[name] = _custom.remove(old) ?? [];
      saveCustomSearchGroups(_custom);
    });
  }

  Future<void> _editSources(String group) async {
    final result = await _pickGroupSources(
      creating: false,
      title: '$group · ${t.groupSources}',
      initialName: group,
      initialSelected: Set.from(_custom[group] ?? []),
    );
    if (result == null) return;
    final (name, selected) = result;
    setState(() {
      _custom[group] = selected.toList()..sort();
      saveCustomSearchGroups(_custom);
    });
  }

  /// 统一的“源分配”Sheet：新建分组(带命名) 或 编辑已有分组
  Future<(String, Set<String>)?> _pickGroupSources({
    required bool creating,
    String? title,
    String initialName = '',
    Set<String> initialSelected = const {},
  }) {
    return showModalBottomSheet<(String, Set<String>)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupSourcesPicker(
        creating: creating,
        title: title,
        initialName: initialName,
        initialSelected: initialSelected,
      ),
    );
  }

  Future<void> _delete(String group) async {
    showConfirmDialog(
      context: context,
      title: t.deleteGroup,
      content: '${t.deleteGroupConfirm}\n"$group"',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        setState(() {
          _custom.remove(group);
          saveCustomSearchGroups(_custom);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allGroups = searchGroups();

    return Scaffold(
      appBar: Appbar(title: Text(t.manageGroups)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader(t.searchGroupBuiltIn),
          for (final group in allGroups)
            if (!_custom.containsKey(group))
              ListTile(
                leading: Icon(
                  group == 'all' ? Icons.all_inclusive : Icons.folder_outlined,
                  color: cs.primary,
                ),
                title: Text(searchGroupLabel(group)),
                subtitle: Text(
                  '${enabledSearchSources(group).length} ${t.sources}',
                ),
              ),
          _sectionHeader(t.searchGroupCustom),
          for (final entry
              in _custom.entries.toList()
                ..sort((a, b) => a.key.compareTo(b.key)))
            ListTile(
              leading: Icon(
                Icons.create_new_folder_outlined,
                color: cs.primary,
              ),
              title: Text(entry.key),
              subtitle: Text(
                '${enabledSearchSources(entry.key).length} ${t.sources}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: t.assignSources,
                    icon: const Icon(Icons.checklist),
                    onPressed: () => _editSources(entry.key),
                  ),
                  IconButton(
                    tooltip: t.rename,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _rename(entry.key),
                  ),
                  IconButton(
                    tooltip: t.delete,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(entry.key),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(t.newGroup),
              onPressed: _create,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.toOpacity(0.55),
        ),
      ),
    );
  }
}

/// 新建/编辑分组时的源分配 Sheet（大屏、可搜索、多选计数）
class _GroupSourcesPicker extends StatefulWidget {
  final bool creating;
  final String? title;
  final String initialName;
  final Set<String> initialSelected;

  const _GroupSourcesPicker({
    required this.creating,
    this.title,
    this.initialName = '',
    this.initialSelected = const {},
  });

  @override
  State<_GroupSourcesPicker> createState() => _GroupSourcesPickerState();
}

class _GroupSourcesPickerState extends State<_GroupSourcesPicker> {
  late final TextEditingController _nameCtrl;
  final _searchCtrl = TextEditingController();
  late Set<String> _selected;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selected = Set.of(widget.initialSelected);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AnimeSource> get _sources {
    final all = allEnabledSearchSources();
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return all;
    return all
        .where(
          (s) =>
              s.name.toLowerCase().contains(k) ||
              s.key.toLowerCase().contains(k),
        )
        .toList();
  }

  void _submit() {
    Navigator.of(
      context,
    ).pop((_nameCtrl.text.trim(), Set<String>.from(_selected)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sources = _sources;
    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                widget.creating ? t.newGroup : (widget.title ?? t.manageGroups),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            if (widget.creating)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t.groupName,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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
                ),
              ),
            ),
            Expanded(
              child: sources.isEmpty
                  ? Center(
                      child: Text(
                        t.noSearchSources,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: sources.length,
                      itemBuilder: (context, i) {
                        final s = sources[i];
                        return CheckboxListTile(
                          dense: true,
                          title: Text(s.name),
                          secondary: Text(
                            s.key,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          value: _selected.contains(s.key),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(s.key);
                            } else {
                              _selected.remove(s.key);
                            }
                          }),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(t.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          if (widget.creating && _nameCtrl.text.trim().isEmpty) {
                            App.rootContext.showMessage(
                              message: t.thisFieldCannotBeEmpty,
                            );
                            return;
                          }
                          _submit();
                        },
                        icon: const Icon(Icons.check),
                        label: Text('${t.confirm} (${_selected.length})'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
