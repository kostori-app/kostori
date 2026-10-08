import 'package:flutter/material.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/empty_state.dart';
import 'package:kostori/foundation/context.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/torrent/torrent_file_selection.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/utils/io.dart';

class TorrentFileList extends StatefulWidget {
  const TorrentFileList({
    super.key,
    required this.files,
    required this.wanted,
    required this.priorities,
    required this.emptyMessage,
    required this.onPlay,
    required this.onRename,
    required this.onSetPriority,
    required this.onDeleteFiles,
  });

  final List<TorrentFileEntry> files;
  final Set<int> wanted;
  final Map<int, int> priorities;
  final String emptyMessage;
  final void Function(int index) onPlay;
  final Future<Object?> Function(int index, String name) onRename;
  final void Function(Set<int> indices, FilePriority priority) onSetPriority;
  final Future<bool> Function(Set<int> indices) onDeleteFiles;

  @override
  State<TorrentFileList> createState() => _TorrentFileListState();
}

class _TorrentFileListState extends State<TorrentFileList>
    with AutomaticKeepAliveClientMixin {
  final _selection = TorrentFileSelection();
  final Set<String> _collapsed = {};

  @override
  bool get wantKeepAlive => true;

  _FileNode _tree() {
    final root = _FileNode('', '');
    for (final file in widget.files) {
      final parts = file.path
          .replaceAll('\\', '/')
          .split('/')
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isEmpty) parts.add(file.name);
      var parent = root;
      var path = '';
      for (var i = 0; i < parts.length; i++) {
        path = path.isEmpty ? parts[i] : '$path/${parts[i]}';
        parent = parent.children.putIfAbsent(
          parts[i],
          () => _FileNode(path, parts[i]),
        );
      }
      parent.file = file;
    }
    return root;
  }

  List<({_FileNode node, int depth})> _visible(_FileNode root) {
    final rows = <({_FileNode node, int depth})>[];
    void walk(_FileNode parent, int depth) {
      final children = parent.children.values.toList()
        ..sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      for (final child in children) {
        rows.add((node: child, depth: depth));
        if (child.isFolder && !_collapsed.contains(child.path)) {
          walk(child, depth + 1);
        }
      }
    }

    walk(root, 0);
    return rows;
  }

  void _tap(_FileNode node) {
    if (node.isFolder) {
      setState(() {
        if (_selection.active) {
          _selection.toggleGroup(node.indices);
        } else if (!_collapsed.remove(node.path)) {
          _collapsed.add(node.path);
        }
      });
      return;
    }
    final file = node.file!;
    final wasActive = _selection.active;
    setState(() {
      _selection.tap(file.index);
      _closeWhenEmpty();
    });
    if (!wasActive && !_selection.active && file.isStreamable) {
      widget.onPlay(file.index);
    }
  }

  void _longPress(_FileNode node, List<int> order) {
    setState(() {
      if (node.isFolder) {
        _selection.toggleGroup(node.indices);
      } else {
        _selection.longPress(node.file!.index, order);
      }
      _closeWhenEmpty();
    });
  }

  void _closeWhenEmpty() {
    if (_selection.active && _selection.selected.isEmpty) {
      _selection.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final root = _tree();
    final rows = _visible(root);
    // 范围按树中的显示顺序计算，折叠目录内的文件也包含在区间内。
    final order = <int>[];
    void collect(_FileNode node) {
      if (node.file != null) order.add(node.file!.index);
      final children = node.children.values.toList()
        ..sort((a, b) {
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.name.compareTo(b.name);
        });
      for (final child in children) {
        collect(child);
      }
    }

    collect(root);
    _selection.selected.retainAll(order);
    _closeWhenEmpty();
    return PopScope(
      canPop: !_selection.active,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selection.active) setState(_selection.clear);
      },
      child: Column(
        children: [
          Expanded(
            child: rows.isEmpty
                ? EmptyState(message: widget.emptyMessage)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    itemCount: rows.length,
                    itemBuilder: (_, index) =>
                        _row(rows[index].node, rows[index].depth, order),
                  ),
          ),
          if (_selection.active) _toolbar(order),
        ],
      ),
    );
  }

  Widget _row(_FileNode node, int depth, List<int> order) {
    final cs = Theme.of(context).colorScheme;
    final indices = node.indices.toList();
    final selected =
        indices.isNotEmpty && indices.every(_selection.selected.contains);
    final partiallySelected =
        !selected && indices.any(_selection.selected.contains);
    final wanted = indices.where(widget.wanted.contains).length;
    final progress = node.size == 0
        ? 0.0
        : (node.downloaded / node.size).clamp(0.0, 1.0);
    final status = wanted == 0
        ? t.torrentFileSkipped
        : wanted < indices.length
        ? t.torrentFileMixed
        : progress >= 1
        ? t.torrentFileDone
        : t.torrentFileDownloading;
    final priority = node.file == null
        ? null
        : _priorityLabel(node.file!.index);
    final statusText = priority == null || priority == status
        ? status
        : '$priority · $status';
    return Padding(
      padding: EdgeInsets.only(left: (depth * 14.0).clamp(0, 42), bottom: 8),
      child: Material(
        key: ValueKey(
          node.file == null
              ? 'torrent-folder-${node.path}'
              : 'torrent-file-${node.file!.index}',
        ),
        color: selected ? cs.secondaryContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _tap(node),
          onLongPress: () => _longPress(node, order),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                if (node.isFolder)
                  Button.icon(
                    icon: Icon(
                      _collapsed.contains(node.path)
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 20,
                    ),
                    tooltip: _collapsed.contains(node.path)
                        ? t.expand
                        : t.collapse,
                    onPressed: () => setState(() {
                      if (!_collapsed.remove(node.path)) {
                        _collapsed.add(node.path);
                      }
                    }),
                  ),
                Icon(
                  _selection.active && (selected || partiallySelected)
                      ? selected
                            ? Icons.check_circle
                            : Icons.remove_circle_outline
                      : node.isFolder
                      ? Icons.folder_rounded
                      : node.file!.isStreamable
                      ? Icons.video_file_outlined
                      : Icons.insert_drive_file_outlined,
                  color: cs.primary,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.file?.name ?? node.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: wanted == 0 ? cs.outline : cs.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$statusText · ${formatBytesShort(node.downloaded)} / ${formatBytesShort(node.size)} · ${torrentProgressPercent(progress)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _priorityLabel(int index) {
    final raw = widget.priorities[index];
    if (raw == null) return null;
    final priority = FilePriority.values[raw.clamp(0, 3)];
    return switch (priority) {
      FilePriority.skip => t.torrentPrioritySkip,
      FilePriority.low => t.torrentPriorityNormal,
      FilePriority.normal => t.torrentPriorityHigh,
      FilePriority.high => t.torrentPriorityHighest,
    };
  }

  Widget _toolbar(List<int> order) {
    final count = _selection.selected.length;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Button.icon(
                  icon: const Icon(Icons.close),
                  tooltip: t.cancel,
                  onPressed: () => setState(_selection.clear),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.torrentSelectedFiles(count: count),
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Builder(
                  builder: (buttonContext) => Button.icon(
                    icon: const Icon(Icons.low_priority),
                    tooltip: t.torrentPriorityTooltip,
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox;
                      _showPriorityMenu(
                        buttonContext,
                        box.localToGlobal(Offset.zero),
                      );
                    },
                  ),
                ),
                Button.icon(
                  icon: const Icon(Icons.drive_file_rename_outline),
                  tooltip: t.rename,
                  onPressed: _rename,
                ),
                Builder(
                  builder: (buttonContext) => Button.icon(
                    icon: const Icon(Icons.more_vert),
                    tooltip: t.more,
                    onPressed: () {
                      final box = buttonContext.findRenderObject() as RenderBox;
                      _showMoreMenu(
                        buttonContext,
                        box.localToGlobal(Offset.zero),
                        order,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPriorityMenu(BuildContext context, Offset origin) {
    showMenuX(context, origin, [
      MenuEntry(
        text: t.torrentPrioritySkip,
        icon: Icons.block,
        onClick: () => _applyPriority(FilePriority.skip),
      ),
      MenuEntry(
        text: t.torrentPriorityNormal,
        icon: Icons.remove,
        onClick: () => _applyPriority(FilePriority.low),
      ),
      MenuEntry(
        text: t.torrentPriorityHigh,
        icon: Icons.keyboard_double_arrow_up,
        onClick: () => _applyPriority(FilePriority.normal),
      ),
      MenuEntry(
        text: t.torrentPriorityHighest,
        icon: Icons.priority_high,
        onClick: () => _applyPriority(FilePriority.high),
      ),
    ]);
  }

  void _showMoreMenu(BuildContext context, Offset origin, List<int> order) {
    showMenuX(context, origin, [
      MenuEntry(
        text: t.selectAll,
        icon: Icons.select_all,
        onClick: () => setState(() => _selection.selectAll(order)),
      ),
      MenuEntry(
        text: t.invertSelection,
        icon: Icons.flip_to_back,
        onClick: () => setState(() {
          _selection.invert(order);
          _closeWhenEmpty();
        }),
      ),
      MenuEntry(
        text: t.torrentDeleteFiles,
        icon: Icons.delete_outline,
        onClick: () async {
          final deleted = await widget.onDeleteFiles(
            Set.of(_selection.selected),
          );
          if (mounted && deleted) setState(_selection.clear);
        },
      ),
    ]);
  }

  void _applyPriority(FilePriority priority) {
    widget.onSetPriority(Set.of(_selection.selected), priority);
    setState(_selection.clear);
  }

  void _rename() {
    if (_selection.selected.length != 1) {
      context.showMessage(message: t.torrentRenameSingleRequired);
      return;
    }
    final index = _selection.selected.single;
    final file = widget.files.firstWhere((file) => file.index == index);
    showInputDialog(
      context: context,
      title: t.rename,
      initialValue: file.name,
      onConfirm: (name) => widget.onRename(index, name),
    );
  }
}

class _FileNode {
  _FileNode(this.path, this.name);
  final String path;
  final String name;
  final Map<String, _FileNode> children = {};
  TorrentFileEntry? file;
  bool get isFolder => file == null;
  Iterable<int> get indices sync* {
    if (file != null) yield file!.index;
    for (final child in children.values) {
      yield* child.indices;
    }
  }

  int get size =>
      file?.size ?? children.values.fold(0, (sum, child) => sum + child.size);
  int get downloaded =>
      file?.downloaded ??
      children.values.fold(0, (sum, child) => sum + child.downloaded);
}
