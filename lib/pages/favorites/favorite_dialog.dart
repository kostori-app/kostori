part of 'favorites_page.dart';

class _FavoriteDialog extends StatefulWidget {
  const _FavoriteDialog({
    required this.selectedAnimes,
    required this.favPage,
    // required this.updateAnimes,
    required this.cancel,
    required this.favoritesController,
  });

  final Map<Anime, bool> selectedAnimes;
  final _FavoritesPageState favPage;

  // final VoidCallback updateAnimes;
  final VoidCallback cancel;
  final FavoritesController favoritesController;

  static Future<void> show({
    required BuildContext context,
    required Map<Anime, bool> selectedAnimes,
    required _FavoritesPageState favPage,
    // required VoidCallback updateAnimes,
    required VoidCallback cancel,
    required FavoritesController favoritesController,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => _FavoriteDialog(
        selectedAnimes: selectedAnimes,
        favPage: favPage,
        // updateAnimes: updateAnimes,
        cancel: cancel,
        favoritesController: favoritesController,
      ),
    );
  }

  @override
  State<_FavoriteDialog> createState() => _FavoriteDialogState();
}

class _FavoriteDialogState extends State<_FavoriteDialog>
    with SingleTickerProviderStateMixin {
  late List<String> localFolders;
  late List<String> added;
  List<String> selectedLocalFolders = [];
  late List<String> filteredFolders;

  FavoritesController get favoritesController => widget.favoritesController;

  @override
  void initState() {
    super.initState();
    localFolders = LocalFavoritesManager().folderNames;
    // 过滤后的数据源
    added = [];
    for (final a in widget.selectedAnimes.keys) {
      added.addAll(
        LocalFavoritesManager().find(a.id, AnimeType(a.sourceKey.hashCode)),
      );
    }
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
    // 计算要添加和删除的文件夹数量
    int foldersToAdd = 0;

    int foldersToRemove = 0;

    int foldersToMove = 0;

    if (selectedLocalFolders.length > 1 &&
        selectedLocalFolders.contains(widget.favPage.folder)) {
      foldersToMove = widget.selectedAnimes.length;
    } else if (selectedLocalFolders.length == 1 &&
        selectedLocalFolders.contains(widget.favPage.folder)) {
      foldersToRemove = widget.selectedAnimes.length;
    } else {
      foldersToAdd = widget.selectedAnimes.length;
    }

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
                                // 执行移动操作
                                if (selectedLocalFolders.length > 1 &&
                                    selectedLocalFolders.contains(
                                      widget.favPage.folder,
                                    )) {
                                  var animes = widget.selectedAnimes.keys
                                      .map((e) => e as FavoriteItem)
                                      .toList();
                                  final sortedFolders = [
                                    ...selectedLocalFolders.where(
                                      (f) =>
                                          f != widget.favPage.folder as String,
                                    ),
                                    ...selectedLocalFolders.where(
                                      (f) =>
                                          f == widget.favPage.folder as String,
                                    ),
                                  ];

                                  for (var f in sortedFolders) {
                                    LocalFavoritesManager().batchMoveFavorites(
                                      widget.favPage.folder as String,
                                      f,
                                      animes,
                                    );
                                  }
                                } else if (selectedLocalFolders.length == 1 &&
                                    selectedLocalFolders.contains(
                                      widget.favPage.folder,
                                    )) {
                                  for (var a in widget.selectedAnimes.keys) {
                                    LocalFavoritesManager().deleteAnimeWithId(
                                      widget.favPage.folder as String,
                                      a.id,
                                      (a as FavoriteItem).type,
                                    );
                                  }
                                } else {
                                  // 执行添加操作
                                  var animes = widget.selectedAnimes.keys
                                      .map((e) => e as FavoriteItem)
                                      .toList();
                                  for (var f in selectedLocalFolders) {
                                    LocalFavoritesManager().batchCopyFavorites(
                                      widget.favPage.folder as String,
                                      f,
                                      animes,
                                    );
                                  }
                                }

                                // 更新状态
                                if (mounted) {
                                  setState(() {
                                    widget.cancel();
                                  });
                                  showCenter(
                                    seconds: 1,
                                    icon: Gif(
                                      image: AssetImage('assets/img/check.gif'),
                                      height: 80,
                                      fps: 120,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      autostart: Autostart.once,
                                    ),
                                    message: '操作成功',
                                    context: context,
                                  );
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
                  "@a to add • @b to remove • @c to move".tlParams({
                    "a": foldersToAdd,
                    "b": foldersToRemove,
                    "c": foldersToMove,
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
    if (added.contains('default') || added.contains('默认')) {
      filteredFolders = LocalFavoritesManager().folderNames.toList();
    } else {
      filteredFolders = LocalFavoritesManager().folderNames
          .where((folder) => !excludedFolders.contains(folder))
          .toList();
    }
    return ListView.builder(
      itemCount: filteredFolders.length + 1,
      itemBuilder: (context, index) {
        if (index == filteredFolders.length) {
          return _buildNewFolderButton();
        }

        var folder = filteredFolders[index];
        final isAdded = added.contains(folder);

        return CheckboxListTile(
          value: selectedLocalFolders.contains(folder),
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
          onPressed: () {
            newFolder().then((value) {
              setState(() {
                favoritesController.isRefreshEnabled = true;
              });
            });
            if (mounted) {
              setState(() {
                if (added.contains('default') || added.contains('默认')) {
                  filteredFolders = LocalFavoritesManager().folderNames
                      .toList();
                } else {
                  filteredFolders = LocalFavoritesManager().folderNames
                      .where((folder) => !excludedFolders.contains(folder))
                      .toList();
                }
              });
            }
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
