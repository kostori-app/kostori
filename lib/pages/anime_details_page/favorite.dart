part of 'anime_page.dart';

class _FavoriteDialog extends StatefulWidget {
  const _FavoriteDialog({
    required this.cid,
    required this.type,
    required this.isFavorite,
    required this.onFavorite,
    required this.favoriteItem,
  });

  final String cid;
  final AnimeType type;
  final bool? isFavorite;
  final void Function(bool?) onFavorite;
  final FavoriteItem favoriteItem;

  static Future<void> show({
    required BuildContext context,
    required String cid,
    required AnimeType type,
    required bool? isFavorite,
    required void Function(bool?) onFavorite,
    required FavoriteItem favoriteItem,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => _FavoriteDialog(
        cid: cid,
        type: type,
        isFavorite: isFavorite,
        onFavorite: onFavorite,
        favoriteItem: favoriteItem,
      ),
    );
  }

  @override
  State<_FavoriteDialog> createState() => _FavoriteDialogState();
}

class _FavoriteDialogState extends State<_FavoriteDialog>
    with SingleTickerProviderStateMixin {
  late AnimeSource animeSource;
  late List<String> localFolders;
  late List<String> added;
  var selectedLocalFolders = <String>{};
  var isEditing = false;

  // 定义需要排除的文件夹名称
  final excludedFolders = ["default", "默认"];

  late List<String> filteredFolders;

  @override
  void initState() {
    super.initState();
    animeSource = widget.type.animeSource!;
    localFolders = LocalFavoritesManager().folderNames;
    // 过滤后的数据源
    added = LocalFavoritesManager().find(widget.cid, widget.type);
    if (added.contains('default') || added.contains('默认')) {
      filteredFolders = localFolders.toList();
    } else {
      filteredFolders = localFolders
          .where((folder) => !excludedFolders.contains(folder))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersToAdd = selectedLocalFolders
        .where((f) => !added.contains(f))
        .length;
    final foldersToRemove = selectedLocalFolders
        .where((f) => added.contains(f))
        .length;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Favorite".tl,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(child: buildLocalContent()),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // 编辑功能暂不实现
                    },
                    child: Text("Edit".tl),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // 取消关闭对话框
                        },
                        child: Text("Cancel".tl),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: selectedLocalFolders.isEmpty
                            ? null
                            : () async {
                                // 执行添加操作
                                for (final folder in selectedLocalFolders.where(
                                  (f) => !added.contains(f),
                                )) {
                                  LocalFavoritesManager().addAnime(
                                    folder,
                                    widget.favoriteItem,
                                  );
                                }

                                // 执行删除操作
                                for (final folder in selectedLocalFolders.where(
                                  (f) => added.contains(f),
                                )) {
                                  LocalFavoritesManager().deleteAnimeWithId(
                                    folder,
                                    widget.cid,
                                    widget.type,
                                  );
                                }

                                // 更新状态
                                if (mounted) {
                                  setState(() {
                                    added = LocalFavoritesManager().find(
                                      widget.cid,
                                      widget.type,
                                    );
                                    selectedLocalFolders.clear();
                                  });
                                  widget.onFavorite(foldersToAdd > 0);
                                  Navigator.of(context).pop();
                                }
                              },
                        child: Text('OK'.tl),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 添加操作统计信息
            if (selectedLocalFolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "@a to add • @b to remove".tlParams({
                    "a": foldersToAdd,
                    "b": foldersToRemove,
                  }),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildLocalContent() {
    return ListView.builder(
      itemCount: filteredFolders.length + 1,
      itemBuilder: (context, index) {
        if (index == filteredFolders.length) {
          return _buildNewFolderButton();
        }

        final folder = filteredFolders[index];
        final isAdded = added.contains(folder);
        final isSelected = selectedLocalFolders.contains(folder);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                selectedLocalFolders.add(folder);
              } else {
                selectedLocalFolders.remove(folder);
              }
            });
          },
          title: Row(
            children: [
              Text(folder),
              const SizedBox(width: 8),
              if (isAdded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Added".tl,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewFolderButton() {
    return SizedBox(
      height: 36,
      child: Center(
        child: TextButton(
          onPressed: () async {
            await newFolder().then((_) {
              if (mounted) {
                setState(() {
                  localFolders = LocalFavoritesManager().folderNames;
                });
              }
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 20),
              const SizedBox(width: 4),
              Text("New Folder".tl),
            ],
          ),
        ),
      ),
    );
  }
}
