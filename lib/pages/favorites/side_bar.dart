part of 'favorites_page.dart';

class _LeftBar extends StatefulWidget {
  const _LeftBar({
    this.favPage,
    this.onSelected,
    this.withAppbar = false,
    required this.favoritesController,
  });

  final _FavoritesPageState? favPage;

  final VoidCallback? onSelected;

  final bool withAppbar;

  final FavoritesController favoritesController;

  @override
  State<_LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends State<_LeftBar> implements FolderList {
  late _FavoritesPageState favPage;

  FavoritesController get favoritesController => widget.favoritesController;

  String get name => widget.favoritesController.bangumiUserName;

  var folders = <String>[];
  String nameAvatar = '';

  @override
  void initState() {
    favPage =
        widget.favPage ??
        context.findAncestorStateOfType<_FavoritesPageState>()!;
    favPage.folderList = this;
    folders = LocalFavoritesManager().folderNames;
    if (name.isNotEmpty) {
      if (appdata.implicitData['nameAvatar'] != null &&
          appdata.implicitData['nameAvatar'] != '') {
        nameAvatar = appdata.implicitData['nameAvatar'];
      } else {
        getNameAvatar();
      }
    }
    // appdata.settings.addListener(updateFolders);
    // LocalFavoritesManager().addListener(updateFolders);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    // appdata.settings.removeListener(updateFolders);
    // LocalFavoritesManager().removeListener(updateFolders);
  }

  Future<void> getNameAvatar() async {
    nameAvatar = await Bangumi.getBangumiUserAvatarByName(name);
    appdata.implicitData['nameAvatar'] = nameAvatar;
    appdata.writeImplicitData();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        children: [
          if (widget.withAppbar)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const CloseButton(),
                  const SizedBox(width: 8),
                  Text("Folders".tl, style: ts.s18),
                ],
              ),
            ).paddingTop(context.padding.top),
          Padding(
            padding: widget.withAppbar
                ? EdgeInsets.zero
                : EdgeInsets.only(top: context.padding.top),
            child: Card(
              color: favPage.pageId == 0
                  ? context.colorScheme.primaryContainer.toOpacity(0.36)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  favPage.setPage(0);
                },
                child: buildLocalTitle(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.zero,
            child: Card(
              color: favPage.pageId == 1
                  ? context.colorScheme.primaryContainer.toOpacity(0.36)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  favPage.setPage(1);
                },
                child: buildBangumiFavoriteTitle(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLocalTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(Icons.star, color: context.colorScheme.secondary),
          const SizedBox(width: 12),
          Text("Local".tl),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add),
            color: context.colorScheme.primary,
            onPressed: () {
              newFolder().then((value) {
                setState(() {
                  favoritesController.isRefreshEnabled = true;
                });
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.reorder),
            color: context.colorScheme.primary,
            onPressed: () {
              sortFolders().then((value) {
                setState(() {
                  favoritesController.isRefreshEnabled = true;
                });
              });
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget buildBangumiFavoriteTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (nameAvatar.isEmpty) ...[
            Icon(Icons.star, color: context.colorScheme.secondary),
            const SizedBox(width: 12),
            Text("番组计划".tl),
          ],
          if (nameAvatar.isNotEmpty) ...[
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(nameAvatar),
              backgroundColor: Colors.transparent, // 如果你不想要背景色
            ),
            const SizedBox(width: 12),
            Text(name),
          ],

          const Spacer(),
          IconButton(
            icon: const Icon(Icons.edit),
            color: context.colorScheme.primary,
            onPressed: () {
              showInputDialog(
                context: App.rootContext,
                title: "切换收藏人".tl,
                hintText: "New Name".tl,
                onConfirm: (value) {
                  if (value.isEmpty) {
                    favoritesController.bangumiUserName = '';
                    appdata.implicitData['nameAvatar'] = '';
                    appdata.writeImplicitData();
                    favPage.setName('');
                  } else {
                    favPage.setName(value);
                    favoritesController.bangumiUserName = value;
                    getNameAvatar();
                  }

                  return null;
                },
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget? buildLocalFolder(String name) {
    if (name == 'default') {
      if (LocalFavoritesManager()
          .getAllAnimes('default', FavoriteSortType.nameAsc)
          .isEmpty) {
        return Container();
      }
    }
    bool isSelected = name == favPage.folder && !favPage.isNetwork;
    int count = 0;

    count = LocalFavoritesManager().folderAnimes(name);

    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        favPage.setFolder(false, name);
        widget.onSelected?.call();
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(child: Text(name == 'default' ? 'default'.tl : name)),
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count.toString()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void update() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void updateFolders() {
    if (!mounted) return;
    setState(() {
      folders = LocalFavoritesManager().folderNames;
    });
  }
}
