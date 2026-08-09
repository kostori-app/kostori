import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
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
    final name = await _promptName();
    if (name == null || name.isEmpty) return;
    if (_custom.containsKey(name)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    setState(() {
      _custom[name] = [];
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
    final enabled = allEnabledSearchSources();
    final selected = Set<String>.from(_custom[group] ?? []);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDlg) => ContentDialog(
          title: '$group · ${t.groupSources}',
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 420),
            child: enabled.isEmpty
                ? Center(child: Text(t.noSearchSources))
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in enabled)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.name),
                          value: selected.contains(s.key),
                          onChanged: (v) {
                            setDlg(() {
                              if (v == true) {
                                selected.add(s.key);
                              } else {
                                selected.remove(s.key);
                              }
                            });
                          },
                        ),
                    ],
                  ),
          ),
          // 使用内置取消按钮，这里只放确认
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(t.apply),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _custom[group] = result.toList();
      saveCustomSearchGroups(_custom);
    });
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
