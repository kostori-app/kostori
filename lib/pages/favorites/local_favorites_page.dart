part of 'favorites_page.dart';

class _LocalFavoritesPage extends StatefulWidget {
  const _LocalFavoritesPage({required this.folder, super.key});

  final String folder;

  @override
  State<_LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<_LocalFavoritesPage> {
  late _FavoritesPageState favPage;

  late List<FavoriteItem> animes;

  Map<Anime, bool> selectedAnimes = {};

  var selectedLocalFolders = <String>{};

  late List<String> added = [];

  String keyword = "";

  bool searchMode = false;

  bool multiSelectMode = false;

  int? lastSelectedIndex;

  void updateAnimes() {
    if (keyword.isEmpty) {
      setState(() {
        animes = LocalFavoritesManager().getAllAnimes(widget.folder);
      });
    } else {
      setState(() {
        animes = LocalFavoritesManager().searchInFolder(widget.folder, keyword);
      });
    }
  }

  @override
  void initState() {
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    animes = LocalFavoritesManager().getAllAnimes(widget.folder);
    super.initState();
  }

  void selectAll() {
    setState(() {
      selectedAnimes = animes.asMap().map((k, v) => MapEntry(v, true));
    });
  }

  void invertSelection() {
    setState(() {
      animes.asMap().forEach((k, v) {
        selectedAnimes[v] = !selectedAnimes.putIfAbsent(v, () => false);
      });
      selectedAnimes.removeWhere((k, v) => !v);
    });
  }

  var scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        if (!searchMode && !multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Folders".tl,
              child: context.width <= _kTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: favPage.showFolderSelector,
                    )
                  : const SizedBox(),
            ),
            title: GestureDetector(
              onTap: context.width < _kTwoPanelChangeWidth
                  ? favPage.showFolderSelector
                  : null,
              child: Text(favPage.folder != null
                  ? '${'${favPage.folder}'.tl} ( ${animes.length} )'
                  : "Unselected".tl),
            ),
            actions: [
              Tooltip(
                message: "Search".tl,
                child: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      searchMode = true;
                    });
                  },
                ),
              ),
              MenuButton(
                entries: [
                  MenuEntry(
                      icon: Icons.edit_outlined,
                      text: "Rename".tl,
                      onClick: () {
                        showInputDialog(
                          context: App.rootContext,
                          title: "Rename".tl,
                          hintText: "New Name".tl,
                          onConfirm: (value) {
                            var err = validateFolderName(value.toString());
                            if (err != null) {
                              return err;
                            }
                            LocalFavoritesManager().rename(
                              widget.folder,
                              value.toString(),
                            );
                            favPage.folderList?.updateFolders();
                            favPage.setFolder(false, value.toString());
                            return null;
                          },
                        );
                      }),
                  MenuEntry(
                      icon: Icons.reorder,
                      text: "Reorder".tl,
                      onClick: () {
                        context.to(
                          () {
                            return _ReorderAnimesPage(
                              widget.folder,
                              (animes) {
                                this.animes = animes;
                              },
                            );
                          },
                        ).then(
                          (value) {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        );
                      }),
                  MenuEntry(
                      icon: Icons.upload_file,
                      text: "Export".tl,
                      onClick: () {
                        var json = LocalFavoritesManager().folderToJson(
                          widget.folder,
                        );
                        saveFile(
                          data: utf8.encode(json),
                          filename: "${widget.folder}.json",
                        );
                      }),
                  MenuEntry(
                      icon: Icons.update,
                      text: "Update Animes Info".tl,
                      onClick: () {
                        updateAnimesInfo(widget.folder).then((newAnimes) {
                          if (mounted) {
                            setState(() {
                              animes = newAnimes;
                            });
                          }
                        });
                      }),
                  MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Folder".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: App.rootContext,
                          title: "Delete".tl,
                          content: "Delete folder '@f' ?".tlParams({
                            "f": widget.folder,
                          }),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            favPage.setFolder(false, null);
                            LocalFavoritesManager().deleteFolder(widget.folder);
                            favPage.folderList?.updateFolders();
                          },
                        );
                      }),
                ],
              ),
            ],
          )
        else if (multiSelectMode)
          SliverAppbar(
              style: context.width < changePoint
                  ? AppbarStyle.shadow
                  : AppbarStyle.blur,
              leading: Tooltip(
                message: "Cancel".tl,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      multiSelectMode = false;
                      selectedAnimes.clear();
                    });
                  },
                ),
              ),
              title: Text(
                  "Selected @c animes".tlParams({"c": selectedAnimes.length})),
              actions: [
                MenuButton(entries: [
                  MenuEntry(
                      icon: Icons.drive_file_move,
                      text: "Move to folder".tl,
                      onClick: () => favoriteOption('move')),
                  MenuEntry(
                      icon: Icons.copy,
                      text: "Copy to folder".tl,
                      onClick: () => favoriteOption('add')),
                  MenuEntry(
                      icon: Icons.select_all,
                      text: "Select All".tl,
                      onClick: selectAll),
                  MenuEntry(
                      icon: Icons.deselect,
                      text: "Deselect".tl,
                      onClick: _cancel),
                  MenuEntry(
                      icon: Icons.flip,
                      text: "Invert Selection".tl,
                      onClick: invertSelection),
                  MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Anime".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        showConfirmDialog(
                          context: context,
                          title: "Delete".tl,
                          content: "Delete @c animes?"
                              .tlParams({"c": selectedAnimes.length}),
                          btnColor: context.colorScheme.error,
                          onConfirm: () {
                            _deleteAnimeWithId();
                          },
                        );
                      }),
                ]),
              ])
        else if (searchMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    searchMode = false;
                    keyword = "";
                    updateAnimes();
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: InputBorder.none,
              ),
              onChanged: (v) {
                keyword = v;
                updateAnimes();
              },
            ),
          ),
        SliverGridAnimes(
          animes: animes,
          selections: selectedAnimes,
          enableFavorite: false,
          onTap: multiSelectMode
              ? (a) {
                  setState(() {
                    if (selectedAnimes.containsKey(a as FavoriteItem)) {
                      selectedAnimes.remove(a);
                      _checkExitSelectMode();
                    } else {
                      selectedAnimes[a] = true;
                    }
                    lastSelectedIndex = animes.indexOf(a);
                  });
                }
              : (a) {
                  App.mainNavigatorKey?.currentContext
                      ?.to(() => AnimePage(id: a.id, sourceKey: a.sourceKey));
                },
          onLongPressed: (a) {
            setState(() {
              if (!multiSelectMode) {
                multiSelectMode = true;
                if (!selectedAnimes.containsKey(a as FavoriteItem)) {
                  selectedAnimes[a] = true;
                }
                lastSelectedIndex = animes.indexOf(a);
              } else {
                if (lastSelectedIndex != null) {
                  int start = lastSelectedIndex!;
                  int end = animes.indexOf(a as FavoriteItem);
                  if (start > end) {
                    int temp = start;
                    start = end;
                    end = temp;
                  }

                  for (int i = start; i <= end; i++) {
                    if (i == lastSelectedIndex) continue;

                    var anime = animes[i];
                    if (selectedAnimes.containsKey(anime)) {
                      selectedAnimes.remove(anime);
                    } else {
                      selectedAnimes[anime] = true;
                    }
                  }
                }
                lastSelectedIndex = animes.indexOf(a as FavoriteItem);
              }
              _checkExitSelectMode();
            });
          },
        ),
      ],
    );
    body = Scrollbar(
      controller: scrollController,
      thickness: App.isDesktop ? 8 : 12,
      radius: const Radius.circular(8),
      interactive: true,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedAnimes.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            updateAnimes();
          });
        }
      },
      child: body,
    );
  }

  void favoriteOption(String option) {
    var targetFolders = LocalFavoritesManager()
        .folderNames
        .where((folder) => folder != favPage.folder && folder != "default")
        .toList();

    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(
        builder: (context, setState) {
          return PopUpWidgetScaffold(
            title: favPage.folder ?? "Unselected".tl,
            body: Padding(
              padding: EdgeInsets.only(bottom: context.padding.bottom + 16),
              child: Container(
                constraints:
                    const BoxConstraints(maxHeight: 700, maxWidth: 500),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: targetFolders.length + 1,
                        itemBuilder: (context, index) {
                          if (index == targetFolders.length) {
                            return SizedBox(
                              height: 36,
                              child: Center(
                                child: TextButton(
                                  onPressed: () {
                                    newFolder().then((v) {
                                      setState(() {
                                        targetFolders = LocalFavoritesManager()
                                            .folderNames
                                            .where((folder) =>
                                                folder != favPage.folder)
                                            .toList();
                                      });
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
                          var folder = targetFolders[index];
                          var disabled = false;
                          if (selectedLocalFolders.isNotEmpty) {
                            if (added.contains(folder) &&
                                !added.contains(selectedLocalFolders.first)) {
                              disabled = true;
                            } else if (!added.contains(folder) &&
                                added.contains(selectedLocalFolders.first)) {
                              disabled = true;
                            }
                          }
                          return CheckboxListTile(
                            title: Row(
                              children: [
                                Text(folder),
                                const SizedBox(width: 8),
                              ],
                            ),
                            value: selectedLocalFolders.contains(folder),
                            onChanged: disabled
                                ? null
                                : (v) {
                                    setState(() {
                                      if (v!) {
                                        selectedLocalFolders.add(folder);
                                      } else {
                                        selectedLocalFolders.remove(folder);
                                      }
                                    });
                                  },
                          );
                        },
                      ),
                    ),
                    Center(
                      child: FilledButton(
                        onPressed: () {
                          if (selectedLocalFolders.isEmpty) {
                            return;
                          }
                          if (option == 'move') {
                            for (var c in selectedAnimes.keys) {
                              for (var s in selectedLocalFolders) {
                                LocalFavoritesManager().moveFavorite(
                                    favPage.folder as String,
                                    s,
                                    c.id,
                                    (c as FavoriteItem).type);
                              }
                            }
                          } else {
                            for (var c in selectedAnimes.keys) {
                              for (var s in selectedLocalFolders) {
                                LocalFavoritesManager().addAnime(
                                  s,
                                  FavoriteItem(
                                    id: c.id,
                                    name: c.title,
                                    coverPath: c.cover,
                                    author: c.subtitle ?? '',
                                    type: AnimeType((c.sourceKey == 'local'
                                        ? 0
                                        : c.sourceKey.hashCode)),
                                    tags: c.tags ?? [],
                                  ),
                                );
                              }
                            }
                          }
                          App.rootContext.pop();
                          updateAnimes();
                          _cancel();
                        },
                        child: Text(option == 'move' ? "Move".tl : "Add".tl),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _checkExitSelectMode() {
    if (selectedAnimes.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      selectedAnimes.clear();
      multiSelectMode = false;
    });
  }

  void _deleteAnimeWithId() {
    for (var a in selectedAnimes.keys) {
      LocalFavoritesManager().deleteAnimeWithId(
        widget.folder,
        a.id,
        (a as FavoriteItem).type,
      );
    }
    updateAnimes();
    _cancel();
  }
}

class _ReorderAnimesPage extends StatefulWidget {
  const _ReorderAnimesPage(this.name, this.onReorder);

  final String name;

  final void Function(List<FavoriteItem>) onReorder;

  @override
  State<_ReorderAnimesPage> createState() => _ReorderAnimesPageState();
}

class _ReorderAnimesPageState extends State<_ReorderAnimesPage> {
  final _key = GlobalKey();
  var reorderWidgetKey = UniqueKey();
  final _scrollController = ScrollController();
  late var animes = LocalFavoritesManager().getAllAnimes(widget.name);
  bool changed = false;

  static int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }

  Color lightenColor(Color color, double lightenValue) {
    int red =
        (_floatToInt8(color.r) + ((255 - color.r) * lightenValue)).round();
    int green = (_floatToInt8(color.g) * 255 + ((255 - color.g) * lightenValue))
        .round();
    int blue = (_floatToInt8(color.b) * 255 + ((255 - color.b) * lightenValue))
        .round();

    return Color.fromARGB(_floatToInt8(color.a), red, green, blue);
  }

  @override
  void dispose() {
    if (changed) {
      LocalFavoritesManager().reorder(animes, widget.name);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['animeDisplayMode'];
    var tiles = animes.map(
      (e) {
        var animeSource = e.type.animeSource;
        return AnimeTile(
          key: Key(e.hashCode.toString()),
          enableLongPressed: false,
          anime: Anime(
            e.name,
            e.coverPath,
            e.id,
            e.author,
            e.tags,
            type == 'detailed'
                ? "${e.time} | ${animeSource?.name ?? "Unknown"}"
                : "${e.type.animeSource?.name ?? "Unknown"} | ${e.time}",
            animeSource?.key ?? "Unknown",
            null,
          ),
        );
      },
    ).toList();
    return Scaffold(
      appBar: Appbar(
        title: Text("Reorder".tl),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showInfoDialog(
                context: context,
                title: "Reorder".tl,
                content: "Long press and drag to reorder.".tl,
              );
            },
          ),
        ],
      ),
      body: ReorderableBuilder<FavoriteItem>(
        key: reorderWidgetKey,
        scrollController: _scrollController,
        longPressDelay: App.isDesktop
            ? const Duration(milliseconds: 100)
            : const Duration(milliseconds: 500),
        onReorder: (reorderFunc) {
          changed = true;
          setState(() {
            animes = reorderFunc(animes);
          });
          widget.onReorder(animes);
        },
        dragChildBoxDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: lightenColor(
            Theme.of(context).splashColor.withAlpha(255),
            0.2,
          ),
        ),
        builder: (children) {
          return GridView(
            key: _key,
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithAnimes(),
            children: children,
          );
        },
        children: tiles,
      ),
    );
  }
}
