// ignore_for_file: use_build_context_synchronously

part of 'favorites_page.dart';

/// Open a dialog to create a new favorite folder.
Future<void> newFolder() async {
  return showDialog(
    context: App.rootContext,
    builder: (context) {
      var controller = TextEditingController();
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
                      setState(() {
                        error = null;
                      });
                    }
                  },
                ),
              ],
            ).paddingHorizontal(16),
            actions: [
              TextButton(
                child: Text(t.importFromFile),
                onPressed: () async {
                  var file = await selectFile(ext: ['json']);
                  if (file == null) return;
                  var data = await file.readAsBytes();
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
                  var e = validateFolderName(controller.text);
                  if (e != null) {
                    setState(() {
                      error = e;
                    });
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

void addFavorite(Anime anime) {
  var folders = LocalFavoritesManager().folderNames
      .where((folder) => folder != "default")
      .toList();

  showDialog(
    context: App.rootContext,
    builder: (context) {
      String? selectedFolder;

      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: t.selectAFolder,
            content: ListTile(
              title: Text(t.folder),
              trailing: Select(
                current: selectedFolder,
                values: folders,
                minWidth: 112,
                onTap: (v) {
                  setState(() {
                    selectedFolder = folders[v];
                  });
                },
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  if (selectedFolder != null) {
                    LocalFavoritesManager().addAnime(
                      selectedFolder!,
                      FavoriteItem(
                        id: anime.id,
                        name: anime.title,
                        coverPath: anime.cover,
                        author: anime.subtitle ?? '',
                        type: AnimeType(
                          (anime.sourceKey == 'local'
                              ? 0
                              : anime.sourceKey.hashCode),
                        ),
                        tags: anime.tags ?? [],
                        viewMore: anime.viewMore,
                      ),
                    );
                    context.pop();
                  }
                },
                child: Text(t.confirm),
              ),
            ],
          );
        },
      );
    },
  );
}

void defaultFavorite(Anime anime) {
  LocalFavoritesManager().addAnime(
    'default',
    FavoriteItem(
      id: anime.id,
      name: anime.title,
      coverPath: anime.cover,
      author: anime.subtitle ?? '',
      type: AnimeType((anime.sourceKey.hashCode)),
      tags: anime.tags ?? [],
      viewMore: anime.viewMore,
    ),
  );
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
                if (errors > 0) Text("Errors: $errors"),
              ],
            ).paddingHorizontal(16),
            actions: [
              Button.filled(
                color: isFinished ? null : context.colorScheme.error,
                onPressed: () {
                  isCanceled = true;
                  context.pop();
                },
                child: isFinished ? Text(t.ok) : Text(t.cancel),
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
                title: Text(folder),
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
