import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 下载筛选/分组工具。
///
/// 分组持久化在 implicitData：`{组名: [条目key...]}`；
/// 当前选中的筛选项也持久化（内置 key 或 `g:<组名>`）。

typedef DownloadFilterItem = ({String key, String label});

/// 自定义分组在筛选条里的 key 前缀（避免与内置 key 冲突）
const String kDownloadGroupPrefix = 'g:';

Map<String, List<String>> readDownloadGroups(String storageKey) {
  final raw = appdata.implicitData[storageKey];
  if (raw is Map) {
    final result = <String, List<String>>{};
    raw.forEach((k, v) {
      if (v is List) result[k.toString()] = v.whereType<String>().toList();
    });
    return result;
  }
  return {};
}

void saveDownloadGroups(String storageKey, Map<String, List<String>> groups) {
  appdata.implicitData[storageKey] = groups;
  appdata.writeImplicitData();
}

String readDownloadFilter(String storageKey, String fallback) {
  final v = appdata.implicitData[storageKey]?.toString();
  return (v == null || v.isEmpty) ? fallback : v;
}

void saveDownloadFilter(String storageKey, String value) {
  appdata.implicitData[storageKey] = value;
  appdata.writeImplicitData();
}

/// 顶部筛选/分组胶囊条 + 管理入口
class DownloadFilterBar extends StatelessWidget {
  const DownloadFilterBar({
    super.key,
    required this.builtins,
    required this.groups,
    required this.selected,
    required this.onSelected,
    required this.onManage,
  });

  final List<DownloadFilterItem> builtins;
  final Map<String, List<String>> groups;
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 2),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: CapsuleOptions(
                children: [
                  for (final b in builtins)
                    CapsuleOption(
                      text: b.label,
                      isSelected: selected == b.key,
                      onTap: () => onSelected(b.key),
                    ),
                  for (final name in groups.keys)
                    CapsuleOption(
                      text: name,
                      isSelected: selected == '$kDownloadGroupPrefix$name',
                      onTap: () =>
                          onSelected('$kDownloadGroupPrefix$name'),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: t.manageGroups,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.tune, size: 20),
            onPressed: onManage,
          ),
        ],
      ),
    );
  }
}

/// 管理下载分组：新建/重命名/删除 + 勾选条目
Future<void> showDownloadGroupManageSheet(
  BuildContext context, {
  required String storageKey,
  required List<DownloadFilterItem> items,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DownloadGroupManageSheet(
      storageKey: storageKey,
      items: items,
      onChanged: onChanged,
    ),
  );
}

class _DownloadGroupManageSheet extends StatefulWidget {
  const _DownloadGroupManageSheet({
    required this.storageKey,
    required this.items,
    required this.onChanged,
  });

  final String storageKey;
  final List<DownloadFilterItem> items;
  final VoidCallback onChanged;

  @override
  State<_DownloadGroupManageSheet> createState() =>
      _DownloadGroupManageSheetState();
}

class _DownloadGroupManageSheetState extends State<_DownloadGroupManageSheet> {
  late Map<String, List<String>> _groups;

  @override
  void initState() {
    super.initState();
    _groups = readDownloadGroups(widget.storageKey);
  }

  void _persist() {
    saveDownloadGroups(widget.storageKey, _groups);
    widget.onChanged();
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
    final name = await _promptName(title: t.newGroup);
    if (name == null || name.isEmpty) return;
    if (_groups.containsKey(name)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    setState(() {
      _groups[name] = [];
      _persist();
    });
  }

  Future<void> _rename(String old) async {
    final name = await _promptName(initial: old, title: t.rename);
    if (name == null || name.isEmpty || name == old) return;
    if (_groups.containsKey(name)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    setState(() {
      _groups[name] = _groups.remove(old) ?? [];
      _persist();
    });
  }

  void _delete(String name) {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${t.deleteGroupConfirm}\n"$name"',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        setState(() {
          _groups.remove(name);
          _persist();
        });
      },
    );
  }

  Future<void> _assign(String name) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadGroupItemPicker(
        title: name,
        items: widget.items,
        selected: Set.of(_groups[name] ?? const []),
      ),
    );
    if (result == null) return;
    setState(() {
      _groups[name] = result.toList();
      _persist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Sheet(
      title: t.manageGroups,
      icon: Icons.tune,
      initialSize: 0.7,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(t.newGroup),
            ),
          ),
        ),
      ),
      builder: (context, sc) => _groups.isEmpty
          ? Center(
              child: Text(
                t.noData,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          : ListView(
              controller: sc,
              children: [
                for (final entry in _groups.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key)))
                  ListTile(
                    leading: Icon(
                      Icons.create_new_folder_outlined,
                      color: cs.primary,
                    ),
                    title: Text(entry.key),
                    subtitle: Text('${entry.value.length} ${t.sources}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: t.assignSources,
                          icon: const Icon(Icons.checklist),
                          onPressed: () => _assign(entry.key),
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
              ],
            ),
    );
  }
}

/// 给分组勾选条目
class _DownloadGroupItemPicker extends StatefulWidget {
  const _DownloadGroupItemPicker({
    required this.title,
    required this.items,
    required this.selected,
  });

  final String title;
  final List<DownloadFilterItem> items;
  final Set<String> selected;

  @override
  State<_DownloadGroupItemPicker> createState() =>
      _DownloadGroupItemPickerState();
}

class _DownloadGroupItemPickerState extends State<_DownloadGroupItemPicker> {
  late final Set<String> _selected = Set.of(widget.selected);
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DownloadFilterItem> get _items {
    final k = _keyword.trim().toLowerCase();
    if (k.isEmpty) return widget.items;
    return widget.items
        .where((e) => e.label.toLowerCase().contains(k))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _items;
    return Sheet(
      title: widget.title,
      icon: Icons.checklist,
      initialSize: 0.8,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_selected),
              icon: const Icon(Icons.check),
              label: Text('${t.confirm} (${_selected.length})'),
            ),
          ),
        ),
      ),
      builder: (context, sc) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
            child: items.isEmpty
                ? Center(
                    child: Text(
                      t.noData,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: sc,
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final it = items[i];
                      return CheckboxListTile(
                        dense: true,
                        title: Text(it.label),
                        value: _selected.contains(it.key),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(it.key);
                          } else {
                            _selected.remove(it.key);
                          }
                        }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
