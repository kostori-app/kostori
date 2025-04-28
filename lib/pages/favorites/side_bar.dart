part of 'favorites_page.dart';

class _LeftBar extends StatefulWidget {
  const _LeftBar({this.favPage, this.onSelected, this.withAppbar = false});

  final _FavoritesPageState? favPage;

  final VoidCallback? onSelected;

  final bool withAppbar;

  @override
  State<_LeftBar> createState() => _LeftBarState();
}

class _LeftBarState extends State<_LeftBar> implements FolderList {
  late _FavoritesPageState favPage;

  var folders = <String>[];

  var networkFolders = <String>[];

  @override
  void initState() {
    favPage = widget.favPage ??
        context.findAncestorStateOfType<_FavoritesPageState>()!;
    favPage.folderList = this;
    folders = LocalFavoritesManager().folderNames;
    networkFolders = AnimeSource.all()
        .where((e) => e.favoriteData != null && e.isLogged)
        .map((e) => e.favoriteData!.key)
        .toList();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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
                  Text(
                    "Folders".tl,
                    style: ts.s18,
                  ),
                ],
              ),
            ).paddingTop(context.padding.top),
          Expanded(
            child: ListView.builder(
              padding: widget.withAppbar
                  ? EdgeInsets.zero
                  : EdgeInsets.only(top: context.padding.top),
              itemCount: folders.length + networkFolders.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(
                          Icons.star,
                          color: context.colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Text("Local".tl),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.search),
                          color: context.colorScheme.primary,
                          onPressed: () {
                            context.to(() => const LocalSearchPage());
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          color: context.colorScheme.primary,
                          onPressed: () {
                            newFolder().then((value) {
                              setState(() {
                                folders = LocalFavoritesManager().folderNames;
                              });
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  );
                }
                index--;
                if (index < folders.length) {
                  return buildLocalFolder(folders[index]);
                }
              },
            ),
          )
        ],
      ),
    );
  }

  Widget? buildLocalFolder(String name) {
    if (name == 'default') {
      if (LocalFavoritesManager().getAllAnimes('default').isEmpty) {
        return Container();
      }
    }
    bool isSelected = name == favPage.folder && !favPage.isNetwork;
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
              color:
                  isSelected ? context.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Text(name == 'default' ? 'default'.tl : name),
      ),
    );
  }

  Widget buildNetworkFolder(String key) {
    var data = getFavoriteDataOrNull(key);
    if (data == null) {
      return const SizedBox();
    }
    bool isSelected = key == favPage.folder && favPage.isNetwork;
    return InkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        favPage.setFolder(true, key);
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
              color:
                  isSelected ? context.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Text(data.title),
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
      networkFolders = AnimeSource.all()
          .where((e) => e.favoriteData != null)
          .map((e) => e.favoriteData!.key)
          .toList();
    });
  }
}
