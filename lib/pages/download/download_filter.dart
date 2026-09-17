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

/// 筛选/分组胶囊条（排序与管理入口在 AppBar）
class DownloadFilterBar extends StatelessWidget {
  const DownloadFilterBar({
    super.key,
    required this.builtins,
    this.groups = const [],
    required this.selected,
    required this.onSelected,
    this.groupCounts = const {},
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 2),
  });

  final List<DownloadFilterOption> builtins;

  /// 自定义分组（顶层分组用完整名，子组用最后一段显示）
  final List<String> groups;

  /// 分组名 → 条目数（有值时显示为「组名 (n)」）
  final Map<String, int> groupCounts;

  final String selected;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  /// 分组显示名：子组只显示最后一段；带条目数时追加「 (n)」
  String _groupLabel(String name) {
    final label = DownloadManager.isSubGroup(name)
        ? DownloadManager.leafOf(name)
        : name;
    final n = groupCounts[name];
    return n == null ? label : '$label ($n)';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: CapsuleOptions(
          alignment: WrapAlignment.start,
          children: [
            for (final b in builtins)
              CapsuleOption(
                text: b.label,
                isSelected: selected == b.key,
                onTap: () => onSelected(b.key),
              ),
            for (final name in groups)
              CapsuleOption(
                text: _groupLabel(name),
                isSelected: selected == '$kDownloadGroupPrefix$name',
                onTap: () => onSelected('$kDownloadGroupPrefix$name'),
              ),
          ],
        ),
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

/// 选择要移动到的分组（长按条目卡片触发）：支持搜索 + 全部/未分组/顶层/子组筛选
Future<void> showDownloadGroupPicker(
  BuildContext context, {
  required String current,
  required Future<void> Function(String group) onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DownloadGroupPicker(
      current: current,
      onSelected: onSelected,
    ),
  );
}

class _DownloadGroupPicker extends StatefulWidget {
  const _DownloadGroupPicker({required this.current, required this.onSelected});

  final String current;
  final Future<void> Function(String group) onSelected;

  @override
  State<_DownloadGroupPicker> createState() => _DownloadGroupPickerState();
}

class _DownloadGroupPickerState extends State<_DownloadGroupPicker> {
  final _searchCtrl = TextEditingController();
  String _keyword = '';

  /// all / ungrouped / root / sub
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _groups {
    if (_filter == 'ungrouped') return const [];
    final all = DownloadManager.groups();
    final k = _keyword.trim().toLowerCase();
    return all.where((g) {
      final isSub = DownloadManager.isSubGroup(g);
      if (_filter == 'root' && isSub) return false;
      if (_filter == 'sub' && !isSub) return false;
      if (k.isEmpty) return true;
      final leaf = DownloadManager.leafOf(g).toLowerCase();
      return g.toLowerCase().contains(k) || leaf.contains(k);
    }).toList();
  }

  String _label(String group) => DownloadManager.isSubGroup(group)
      ? '${DownloadManager.leafOf(group)}  ·  '
            '${group.substring(0, group.lastIndexOf(DownloadManager.groupSeparator))}'
      : group;

  void _choose(String group) {
    Navigator.pop(context);
    widget.onSelected(group);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = _groups;
    return Sheet(
      title: t.moveToFolder,
      icon: Icons.drive_file_move_outline,
      initialSize: 0.65,
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
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _keyword = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          DownloadFilterBar(
            builtins: [
              (key: 'all', label: t.all),
              (key: 'ungrouped', label: t.ungrouped),
              (key: 'root', label: t.downloadGroupRoot),
              (key: 'sub', label: t.downloadSubGroup),
            ],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const Divider(height: 1),
          Expanded(child: _buildList(sc, cs, groups)),
        ],
      ),
    );
  }

  Widget _buildList(
    ScrollController sc,
    ColorScheme cs,
    List<String> groups,
  ) {
    final showUngrouped = _filter == 'all' || _filter == 'ungrouped';
    if (!showUngrouped && groups.isEmpty) {
      return Center(
        child: Text(t.noData, style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView(
      controller: sc,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        if (showUngrouped)
          _GroupChoiceTile(
            label: t.ungrouped,
            selected: widget.current.isEmpty,
            onTap: () => _choose(''),
          ),
        for (final g in groups)
          _GroupChoiceTile(
            label: _label(g),
            selected: widget.current == g,
            onTap: () => _choose(g),
          ),
      ],
    );
  }
}

class _GroupChoiceTile extends StatelessWidget {
  const _GroupChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.folder_outlined,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onTap: onTap,
    );
  }
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
  /// 层级展示用扁平列表：顶层分组 + 其直接子组（保持登记顺序）
  late List<String> _groups;

  @override
  void initState() {
    super.initState();
    _groups = _flatten();
  }

  List<String> _flatten() {
    final out = <String>[];
    for (final g in DownloadManager.rootGroups()) {
      out.add(g);
      out.addAll(DownloadManager.subGroupsOf(g));
    }
    // 兜底：登记顺序异常时也把漏掉的组补上
    for (final g in DownloadManager.groups()) {
      if (!out.contains(g)) out.add(g);
    }
    return out;
  }

  void _refresh() {
    setState(() => _groups = _flatten());
    widget.onChanged();
  }

  Future<String?> _promptName({String initial = '', String? title}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
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
    ).whenComplete(ctrl.dispose);
  }

  /// 新建分组；[parent] 非空时在其下新建子组
  Future<void> _create({String parent = ''}) async {
    final name = await _promptName(
      title: parent.isEmpty ? t.newGroup : t.downloadNewSubGroup,
    );
    if (name == null || name.isEmpty) return;
    final full = DownloadManager.childName(parent, name);
    if (DownloadManager.groups().contains(full)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    await DownloadManager.createGroup(full);
    _refresh();
  }

  Future<void> _rename(String old) async {
    final name = await _promptName(
      initial: DownloadManager.leafOf(old),
      title: t.rename,
    );
    if (name == null || name.isEmpty) return;
    final parent = DownloadManager.isSubGroup(old)
        ? old.substring(0, old.lastIndexOf(DownloadManager.groupSeparator))
        : '';
    final full = DownloadManager.childName(parent, name);
    if (full == old) return;
    if (DownloadManager.groups().contains(full)) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
    await DownloadManager.instance.renameGroup(old, full);
    _refresh();
  }

  /// 迁移分组：选一个父分组（空 = 顶层）
  Future<void> _migrate(String name) async {
    final excluded = DownloadManager.groupWithDescendants(name).toSet();
    final candidates = DownloadManager.groups()
        .where((g) => !excluded.contains(g))
        .toList();
    final parent = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Sheet(
        title: t.downloadMigrateGroup,
        icon: Icons.drive_file_move_outline,
        initialSize: 0.5,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.home_outlined),
              title: Text(t.downloadMigrateToRoot),
              enabled: DownloadManager.isSubGroup(name),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final g in candidates)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_outlined),
                title: Text(g, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx, g),
              ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(t.downloadNoMigrateTarget)),
              ),
          ],
        ),
      ),
    );
    if (parent == null) return;
    final ok = await DownloadManager.instance.migrateGroup(name, parent);
    if (ok == null) {
      App.rootContext.showMessage(message: t.groupExists);
      return;
    }
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
          child: CapsuleButton(
            primary: true,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: const Icon(Icons.add),
            text: t.newGroup,
            onTap: () => _create(),
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
          : ReorderableListView.builder(
              scrollController: sc,
              buildDefaultDragHandles: false,
              itemCount: _groups.length,
              onReorderItem: (oldIndex, newIndex) {
                final list = List<String>.from(_groups);
                final item = list.removeAt(oldIndex);
                list.insert(newIndex.clamp(0, list.length), item);
                DownloadManager.setGroupOrder(list);
                _refresh();
              },
              itemBuilder: (context, i) => _groupTile(context, cs, i),
            ),
    );
  }

  Widget _groupTile(BuildContext context, ColorScheme cs, int i) {
    final name = _groups[i];
    final isSub = DownloadManager.isSubGroup(name);
    final count = widget.items.where((e) => e.group == name).length;
    return ListTile(
      key: ValueKey(name),
      dense: true,
      contentPadding: EdgeInsets.only(left: isSub ? 36 : 12, right: 4),
      leading: Icon(
        isSub ? Icons.subdirectory_arrow_right : Icons.create_new_folder_outlined,
        color: cs.primary,
      ),
      title: Text(DownloadManager.leafOf(name)),
      subtitle: Text(
        isSub
            ? '${t.itemsCount(n: count)} · '
                  '${name.substring(0, name.lastIndexOf(DownloadManager.groupSeparator))}'
            : t.itemsCount(n: count),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 20, color: cs.onSurfaceVariant),
            onSelected: (v) {
              switch (v) {
                case 'assign':
                  _assign(name);
                case 'sub':
                  _create(parent: name);
                case 'migrate':
                  _migrate(name);
                case 'rename':
                  _rename(name);
                case 'delete':
                  _delete(name);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'assign',
                child: Row(
                  children: [
                    const Icon(Icons.checklist, size: 18),
                    const SizedBox(width: 8),
                    Text(t.assignSources),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sub',
                child: Row(
                  children: [
                    const Icon(Icons.create_new_folder_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(t.downloadNewSubGroup),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'migrate',
                child: Row(
                  children: [
                    const Icon(Icons.drive_file_move_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(t.downloadMigrateGroup),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(t.rename),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: cs.error),
                    const SizedBox(width: 8),
                    Text(t.delete),
                  ],
                ),
              ),
            ],
          ),
          // 子组跟随父组展示，只允许顶层分组拖动排序
          if (!isSub)
            ReorderableDelayedDragStartListener(
              index: i,
              child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
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
          child: CapsuleButton(
            primary: true,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: const Icon(Icons.check),
            text: '${t.confirm} (${_selected.length})',
            onTap: () => Navigator.of(context).pop(_selected),
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
