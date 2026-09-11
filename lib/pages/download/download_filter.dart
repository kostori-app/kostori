import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/download/download_manager.dart';

/// 下载筛选/分组。
///
/// 分组 = 下载目录下的子目录；组名列表存在 `DownloadManager.groups()`。
/// 每个任务/记录自带 `group` 字段；筛选选中项持久化在 implicitData。

/// 筛选条上的内置筛选项
typedef DownloadFilterOption = ({String key, String label});

/// 分组管理里的条目（key 唯一；group 为当前所属分组）
typedef DownloadFilterItem = ({String key, String label, String group});

/// 自定义分组在筛选条里的 key 前缀（避免与内置 key 冲突）
const String kDownloadGroupPrefix = 'g:';

/// 下载弹窗里“默认下载分组”的持久化 key
const String kDownloadDefaultGroupKey = 'downloadDefaultGroup';

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

  final List<DownloadFilterOption> builtins;
  final List<String> groups;
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
                  for (final name in groups)
                    CapsuleOption(
                      text: name,
                      isSelected: selected == '$kDownloadGroupPrefix$name',
                      onTap: () => onSelected('$kDownloadGroupPrefix$name'),
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

/// 管理下载分组：新建/重命名/删除 + 勾选条目（勾选即移动到该分组目录）
Future<void> showDownloadGroupManageSheet(
  BuildContext context, {
  required List<DownloadFilterItem> items,
  required Future<void> Function(String itemKey, String group) onSetGroup,
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
      items: items,
      onSetGroup: onSetGroup,
      onChanged: onChanged,
    ),
  );
}

class _DownloadGroupManageSheet extends StatefulWidget {
  const _DownloadGroupManageSheet({
    required this.items,
    required this.onSetGroup,
    required this.onChanged,
  });

  final List<DownloadFilterItem> items;
  final Future<void> Function(String itemKey, String group) onSetGroup;
  final VoidCallback onChanged;

  @override
  State<_DownloadGroupManageSheet> createState() =>
      _DownloadGroupManageSheetState();
}

class _DownloadGroupManageSheetState extends State<_DownloadGroupManageSheet> {
  late List<String> _groups;

  @override
  void initState() {
    super.initState();
    _groups = DownloadManager.groups();
  }

  void _refresh() {
    setState(() => _groups = DownloadManager.groups());
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
    if (_groups.contains(name)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    await DownloadManager.createGroup(name);
    _refresh();
  }

  Future<void> _rename(String old) async {
    final name = await _promptName(initial: old, title: t.rename);
    if (name == null || name.isEmpty || name == old) return;
    if (_groups.contains(name)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    await DownloadManager.instance.renameGroup(old, name);
    _refresh();
  }

  Future<void> _delete(String name) async {
    showConfirmDialog(
      context: context,
      title: t.delete,
      content: '${t.deleteGroupConfirm}\n"$name"',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () async {
        await DownloadManager.instance.deleteGroup(name);
        _refresh();
      },
    );
  }

  Future<void> _assign(String name) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadGroupItemPicker(
        title: name,
        items: widget.items,
        initialSelected: {
          for (final it in widget.items)
            if (it.group == name) it.key,
        },
      ),
    );
    if (selected == null) return;
    for (final it in widget.items) {
      final was = it.group == name;
      final now = selected.contains(it.key);
      if (was != now) {
        await widget.onSetGroup(it.key, now ? name : '');
      }
    }
    _refresh();
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
                for (final name in _groups)
                  ListTile(
                    leading: Icon(
                      Icons.create_new_folder_outlined,
                      color: cs.primary,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      '${widget.items.where((e) => e.group == name).length} ${t.sources}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: t.assignSources,
                          icon: const Icon(Icons.checklist),
                          onPressed: () => _assign(name),
                        ),
                        IconButton(
                          tooltip: t.rename,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _rename(name),
                        ),
                        IconButton(
                          tooltip: t.delete,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(name),
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
    required this.initialSelected,
  });

  final String title;
  final List<DownloadFilterItem> items;
  final Set<String> initialSelected;

  @override
  State<_DownloadGroupItemPicker> createState() =>
      _DownloadGroupItemPickerState();
}

class _DownloadGroupItemPickerState extends State<_DownloadGroupItemPicker> {
  late final Set<String> _selected = Set.of(widget.initialSelected);
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
