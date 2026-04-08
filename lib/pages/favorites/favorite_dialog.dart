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

  static Future<bool?> show({
    required BuildContext context,
    required Map<Anime, bool> selectedAnimes,
    required _FavoritesPageState favPage,
    required VoidCallback cancel,
    required FavoritesController favoritesController,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => _FavoriteDialog(
        selectedAnimes: selectedAnimes,
        favPage: favPage,
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

  String _displayName(String folder) =>
      folder == 'default' ? t.kDefault : folder;

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

    return ContentDialog(
      title: t.favorite,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: buildLocalContent()),
            const Divider(height: 1),
            if (selectedLocalFolders.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  t.aToAddBToRemoveCToMove(
                    a: foldersToAdd.toString(),
                    b: foldersToRemove.toString(),
                    c: foldersToMove.toString(),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      isDismissible: true,
      cancel: () => Navigator.of(context).pop(false),
      actions: [
        FilledButton(
          onPressed: selectedLocalFolders.isEmpty
              ? null
              : () async {
                  bool hasChanged = false;
                  if (selectedLocalFolders.length > 1 &&
                      selectedLocalFolders.contains(widget.favPage.folder)) {
                    var animes = widget.selectedAnimes.keys
                        .map((e) => e as FavoriteItem)
                        .toList();

                    final sortedFolders = [
                      ...selectedLocalFolders.where(
                        (f) => f != widget.favPage.folder as String,
                      ),
                      ...selectedLocalFolders.where(
                        (f) => f == widget.favPage.folder as String,
                      ),
                    ];

                    for (var f in sortedFolders) {
                      LocalFavoritesManager().batchMoveFavorites(
                        widget.favPage.folder as String,
                        f,
                        animes,
                      );
                    }

                    hasChanged = true;
                  } else if (selectedLocalFolders.length == 1 &&
                      selectedLocalFolders.contains(widget.favPage.folder)) {
                    for (var a in widget.selectedAnimes.keys) {
                      LocalFavoritesManager().deleteAnimeWithId(
                        widget.favPage.folder as String,
                        a.id,
                        (a as FavoriteItem).type,
                      );
                    }

                    hasChanged = true;
                  } else {
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

                    hasChanged = true;
                  }

                  if (mounted && hasChanged) {
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
                  if (mounted) {
                    Navigator.of(context).pop(hasChanged);
                  }
                },
          child: Text(t.ok),
        ),
      ],
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
              Text(_displayName(folder)),
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
                    t.added,
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
            newFolder().then((_) {
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
              Text(t.newFolder),
            ],
          ),
        ),
      ),
    );
  }
}
