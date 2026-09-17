part of 'components.dart';

/// 新建收藏文件夹（收藏弹窗与收藏页共用）
Future<void> showNewFolderDialog() async {
  return showDialog(
    context: App.rootContext,
    builder: (context) {
      final controller = TextEditingController();
      String? error;

      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: t.newFolder,
            content: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: t.folderName,
                    errorText: error,
                  ),
                  onChanged: (s) {
                    if (error != null) {
                      setState(() => error = null);
                    }
                  },
                ),
              ],
            ).paddingHorizontal(16),
            actions: [
              TextButton(
                child: Text(t.importFromFile),
                onPressed: () async {
                  final file = await selectFile(ext: ['json']);
                  if (file == null) return;
                  final data = await file.readAsBytes();
                  try {
                    LocalFavoritesManager().fromJson(utf8.decode(data));
                  } catch (e) {
                    context.showMessage(message: t.failedToImport);
                    return;
                  }
                  context.pop();
                },
              ).paddingRight(4),
              FilledButton(
                onPressed: () {
                  final e = validateFolderName(controller.text);
                  if (e != null) {
                    setState(() => error = e);
                  } else {
                    LocalFavoritesManager().createFolder(controller.text);
                    context.pop();
                  }
                },
                child: Text(t.create),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 收藏时不出现在列表里的特殊文件夹（未分类 / 旧版 default）
const List<String> _kExcludedFavoriteFolders = [
  kUnassignedFolder,
  'default',
  '默认',
];

/// 收藏文件夹选择弹窗：番剧详情页与本地收藏页共用同一套样式与操作逻辑。
///
/// - [items]：要操作的收藏条目（详情页 1 条，本地收藏页可多条）
/// - [sourceFolder]：条目「当前所在文件夹」。本地收藏页传入；详情页为 null，
///   此时选中某个文件夹 = 收藏进去、选中已存在的 = 取消该文件夹的收藏。
class FavoriteDialog extends StatefulWidget {
  const FavoriteDialog({
    super.key,
    required this.items,
    this.sourceFolder,
    this.onCancel,
    this.onFoldersChanged,
  });

  final List<FavoriteItem> items;

  final String? sourceFolder;

  /// 取消时的回调（如清空多选状态）
  final VoidCallback? onCancel;

  /// 新建文件夹后的回调（让调用方刷新文件夹列表）
  final VoidCallback? onFoldersChanged;

  static Future<bool?> show(
    BuildContext context, {
    required List<FavoriteItem> items,
    String? sourceFolder,
    VoidCallback? onCancel,
    VoidCallback? onFoldersChanged,
  }) => showDialog<bool>(
    context: context,
    builder: (_) => FavoriteDialog(
      items: items,
      sourceFolder: sourceFolder,
      onCancel: onCancel,
      onFoldersChanged: onFoldersChanged,
    ),
  );

  @override
  State<FavoriteDialog> createState() => _FavoriteDialogState();
}

class _FavoriteDialogState extends State<FavoriteDialog> {
  LocalFavoritesManager get manager => LocalFavoritesManager();

  /// 勾选的文件夹
  final Set<String> selectedFolders = {};

  /// 展示的文件夹（已过滤掉特殊文件夹）
  late List<String> folders;

  /// 已包含（任一）条目的文件夹
  late Set<String> addedFolders;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    addedFolders = {
      for (final a in widget.items) ...manager.find(a.id, a.type),
    };
    final all = manager.folderNames;
    // 条目已在「未分类」时展示全部文件夹，否则隐藏排除项
    folders = addedFolders.any(isUnassignedFolder)
        ? all.toList()
        : all.where((f) => !_kExcludedFavoriteFolders.contains(f)).toList();
  }

  String _displayName(String folder) =>
      isUnassignedFolder(folder) ? t.kDefault : folder;

  bool _alreadyIn(String folder) => addedFolders.contains(folder);

  /// 执行收藏/取消/移动，返回是否有改动
  Future<bool> _apply() async {
    if (selectedFolders.isEmpty) return false;
    final source = widget.sourceFolder;
    if (source != null) {
      // 本地收藏页：含来源文件夹的多选 = 移动；只选来源 = 取消收藏；否则新增到选中项
      if (selectedFolders.length > 1 && selectedFolders.contains(source)) {
        final targets = [
          ...selectedFolders.where((f) => f != source),
          source,
        ];
        for (final f in targets) {
          manager.batchMoveFavorites(source, f, widget.items);
        }
      } else if (selectedFolders.length == 1 &&
          selectedFolders.contains(source)) {
        for (final a in widget.items) {
          manager.deleteAnimeWithId(source, a.id, a.type);
        }
      } else {
        for (final f in selectedFolders) {
          manager.batchCopyFavorites(source, f, widget.items);
        }
      }
      return true;
    }
    // 详情页：选中的文件夹里，已存在的移除、不存在的加入
    for (final f in selectedFolders) {
      if (_alreadyIn(f)) {
        for (final a in widget.items) {
          manager.deleteAnimeWithId(f, a.id, a.type);
        }
      } else {
        for (final a in widget.items) {
          manager.addAnime(f, a);
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final adding = selectedFolders.where((f) => !_alreadyIn(f)).length;
    final removing = selectedFolders.where(_alreadyIn).length;
    final moving =
        widget.sourceFolder != null &&
            selectedFolders.length > 1 &&
            selectedFolders.contains(widget.sourceFolder)
        ? widget.items.length
        : 0;
    final counts = widget.sourceFolder == null
        ? t.aToAddBToRemove(a: '$adding', b: '$removing')
        : t.aToAddBToRemoveCToMove(
            a: '$adding',
            b: '$removing',
            c: '$moving',
          );

    return ContentDialog(
      title: t.favorite,
      cancel: widget.onCancel,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: _buildList()),
            const Divider(height: 1),
            if (selectedFolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  counts,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: selectedFolders.isEmpty
              ? null
              : () async {
                  final changed = await _apply();
                  if (!mounted) return;
                  if (changed) {
                    showCenter(
                      seconds: 1,
                      icon: Gif(
                        image: const AssetImage('assets/img/check.gif'),
                        height: 80,
                        fps: 120,
                        color: Theme.of(context).colorScheme.primary,
                        autostart: Autostart.once,
                      ),
                      message: t.operationSuccess,
                      context: context,
                    );
                  }
                  Navigator.of(context).pop(changed);
                },
          child: Text(t.ok),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: folders.length + 1,
      itemBuilder: (context, index) {
        if (index == folders.length) return _buildNewFolderButton();
        final folder = folders[index];
        final isAdded = _alreadyIn(folder);
        final selected = selectedFolders.contains(folder);
        final cs = Theme.of(context).colorScheme;
        return SelectCard(
          selected: selected,
          title: _displayName(folder),
          leading: Icon(
            Icons.folder_outlined,
            size: 20,
            color: selected ? cs.onPrimaryContainer : cs.primary,
          ),
          trailing: isAdded
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t.added,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                )
              : null,
          onChanged: (value) {
            setState(() {
              if (value) {
                selectedFolders.add(folder);
              } else {
                selectedFolders.remove(folder);
              }
            });
          },
        );
      },
    );
  }

  Widget _buildNewFolderButton() {
    return SizedBox(
      height: 36,
      child: Center(
        child: CapsuleButton(
          leading: const Icon(Icons.add, size: 20),
          text: t.newFolder,
          onTap: () async {
            await showNewFolderDialog();
            widget.onFoldersChanged?.call();
            if (!mounted) return;
            setState(_reload);
          },
        ),
      ),
    );
  }
}
