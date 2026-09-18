// ignore_for_file: use_build_context_synchronously

part of 'favorites_page.dart';

/// 新建收藏文件夹（共用组件实现）
Future<void> newFolder() => showNewFolderDialog();

String? validateFolderName(String newFolderName) {
  var folders = LocalFavoritesManager().folderNames;
  if (newFolderName.isEmpty) {
    return t.folderNameCannotBeEmpty;
  } else if (newFolderName.length > 50) {
    return t.folderNameTooLong;
  } else if (folders.contains(newFolderName)) {
    return t.folderAlreadyExists;
  }
  return null;
}

void defaultFavorite(Anime anime) {
  LocalFavoritesManager().addAnime(kUnassignedFolder, favoriteItemOf(anime));
}

Future<List<FavoriteItem>> updateAnimesInfo(String folder) async {
  var animes = LocalFavoritesManager().getAllAnimes(
    folder,
    FavoriteSortType.displayOrderAsc,
  );

  Future<void> updateSingleAnime(int index) async {
    int retry = 3;

    while (true) {
      try {
        var a = animes[index];
        var animeSource = a.type.animeSource;
        if (animeSource == null) return;

        var newInfo = (await animeSource.loadAnimeInfo!(a.id)).data;

        animes[index] = FavoriteItem(
          id: a.id,
          name: newInfo.title,
          coverPath: newInfo.cover,
          author:
              newInfo.subTitle ??
              newInfo.tags['author']?.firstOrNull ??
              a.author,
          type: a.type,
          tags: a.tags,
        );

        LocalFavoritesManager().updateInfo(folder, animes[index]);
        return;
      } catch (e) {
        retry--;
        if (retry == 0) {
          rethrow;
        }
        continue;
      }
    }
  }

  var finished = ValueNotifier(0);

  var errors = 0;

  var index = 0;

  bool isCanceled = false;

  showDialog(
    context: App.rootContext,
    builder: (context) {
      return ValueListenableBuilder(
        valueListenable: finished,
        builder: (context, value, child) {
          var isFinished = value == animes.length;
          return ContentDialog(
            title: isFinished ? t.finished : t.updating,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                LinearProgressIndicator(value: value / animes.length),
                const SizedBox(height: 4),
                Text("$value/${animes.length}"),
                const SizedBox(height: 4),
                if (errors > 0) Text(t.errorsLabel(n: errors)),
              ],
            ).paddingHorizontal(16),
            cancel: () {
              isCanceled = true;
            },
            actions: [
              if (isFinished)
                Button.filled(
                  onPressed: () {
                    context.pop();
                  },
                  child: Text(t.ok),
                ),
            ],
          );
        },
      );
    },
  ).then((_) {
    isCanceled = true;
  });

  while (index < animes.length) {
    var futures = <Future>[];
    const maxConcurrency = 4;

    if (isCanceled) {
      return animes;
    }

    for (var i = 0; i < maxConcurrency; i++) {
      if (index + i >= animes.length) break;
      futures.add(
        updateSingleAnime(index + i).then(
          (v) {
            finished.value++;
          },
          onError: (_) {
            errors++;
            finished.value++;
          },
        ),
      );
    }

    await Future.wait(futures);
    index += maxConcurrency;
  }

  return animes;
}

Future<void> sortFolders() async {
  final original = LocalFavoritesManager().folderNames;
  var folders = original;

  await showPopUpWidget(
    App.rootContext,
    StatefulBuilder(
      builder: (context, setState) {
        return PopUpWidgetScaffold(
          title: t.sort,
          tailing: [
            Tooltip(
              message: t.help,
              child: IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () {
                  showInfoDialog(
                    context: context,
                    title: t.reorder,
                    content: t.longPressAndDragToReorder,
                  );
                },
              ),
            ),
          ],
          body: SettingReorderableList<String>(
            items: folders,
            itemHeight: 56,
            itemBuilder: (folder) {
              return ListTile(
                title: Text(
                  isUnassignedFolder(folder) ? t.kDefault : folder,
                ),
                trailing: const Icon(Icons.drag_handle),
              );
            },
            onReorder: (reorderFunc) {
              setState(() {
                folders = List.from(reorderFunc(folders));
              });
            },
          ),
        );
      },
    ),
  );

  // 顺序没有变化时不写回，避免无谓刷新
  if (!listEquals(folders, original)) {
    LocalFavoritesManager().updateOrder(folders);
  }
}
