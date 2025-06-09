part of 'components.dart';

ImageProvider? _findImageProvider(Anime anime) {
  ImageProvider image;
  if (anime is History) {
    image = HistoryImageProvider(anime);
  } else {
    image = CachedImageProvider(
      anime.cover,
      sourceKey: anime.sourceKey,
      aid: anime.id,
    );
  }
  return image;
}

class AnimeTile extends StatelessWidget {
  const AnimeTile({
    super.key,
    required this.anime,
    this.isRecommend = false,
    this.enableLongPressed = true,
    this.enableFavorite = true,
    this.enableHistory = false,
    this.badge,
    this.menuOptions,
    this.onTap,
    this.onLongPressed,
    this.heroID,
  });

  final Anime anime;

  final bool enableLongPressed;

  final bool enableFavorite;

  final bool enableHistory;

  final bool isRecommend;

  final String? badge;

  final List<MenuEntry>? menuOptions;

  final VoidCallback? onTap;

  final VoidCallback? onLongPressed;

  final int? heroID;

  void _onTap() {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (isRecommend) {
      App.mainNavigatorKey?.currentContext?.toReplacement(() => AnimePage(
            id: anime.id,
            sourceKey: anime.sourceKey,
            cover: anime.cover,
            title: anime.title,
            heroID: heroID,
          ));
    } else {
      App.mainNavigatorKey?.currentContext?.to(() => AnimePage(
            id: anime.id,
            sourceKey: anime.sourceKey,
            cover: anime.cover,
            title: anime.title,
            heroID: heroID,
          ));
    }

    LocalFavoritesManager()
        .updateRecentlyWatched(anime.id, AnimeType(anime.sourceKey.hashCode));
  }

  void _onLongPressed(context) {
    if (onLongPressed != null) {
      onLongPressed!();
      return;
    }
    onLongPress(context);
  }

  void onLongPress(BuildContext context) {
    if (!enableHistory) {
      if (!LocalFavoritesManager()
          .isExist(anime.id, AnimeType(anime.sourceKey.hashCode))) {
        defaultFavorite(anime);
        App.rootContext.showMessage(message: '收藏成功');
      }
    } else {
      var renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var location = renderBox.localToGlobal(
        Offset((size.width - 242) / 2, size.height / 2),
      );
      showMenu(location, context);
    }
  }

  void onSecondaryTap(TapDownDetails details, BuildContext context) {
    showMenu(details.globalPosition, context);
  }

  void showMenu(Offset location, BuildContext context) {
    showMenuX(
      App.rootContext,
      location,
      [
        MenuEntry(
          icon: Icons.copy,
          text: 'Copy Title'.tl,
          onClick: () {
            Clipboard.setData(ClipboardData(text: anime.title));
            App.rootContext.showMessage(message: 'Title copied'.tl);
          },
        ),
        MenuEntry(
          icon: Icons.stars_outlined,
          text: 'Add to favorites'.tl,
          onClick: () {
            addFavorite(anime);
          },
        ),
        // MenuEntry(
        //   icon: Icons.block,
        //   text: 'Block'.tl,
        //   onClick: () => block(context),
        // ),
        ...?menuOptions,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var type = appdata.settings['animeDisplayMode'];

    Widget child = type == 'detailed'
        ? _buildDetailedMode(context)
        : _buildBriefMode(context);

    var isFavorite = appdata.settings['showFavoriteStatusOnTile']
        ? LocalFavoritesManager()
            .isExist(anime.id, AnimeType(anime.sourceKey.hashCode))
        : false;
    var history = appdata.settings['showHistoryStatusOnTile']
        ? HistoryManager().find(anime.id, AnimeType(anime.sourceKey.hashCode))
        : null;
    // if (history?.lastWatchTime == 0) {
    //   history!.lastWatchTime = 1;
    // }

    if (!isFavorite && history == null) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: child,
        ),
        Positioned(
          left: type == 'detailed' ? 16 : 6,
          top: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  if (isFavorite && enableFavorite)
                    Container(
                      height: 24,
                      width: 24,
                      color: Colors.redAccent,
                      child: const Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  if (history != null && type == 'detailed')
                    Container(
                      height: 24,
                      color: Colors.black.toOpacity(0.5),
                      constraints: const BoxConstraints(minWidth: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                          '${history.lastWatchEpisode} / ${history.allEpisode}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          )),
                    )
                ],
              ),
            ),
          ),
        ),
        if (type != 'detailed')
          Positioned(
              right: 6,
              top: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(children: [
                    if (history != null)
                      Container(
                        height: 24,
                        color: Colors.black.toOpacity(0.5),
                        constraints: const BoxConstraints(minWidth: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                            '${history.lastWatchEpisode} / ${history.allEpisode}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            )),
                      )
                  ]),
                ),
              )),
      ],
    );
  }

  Widget buildImage(BuildContext context) {
    var image = _findImageProvider(anime);
    if (image == null) {
      return const SizedBox();
    }
    return AnimatedImage(
      image: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildDetailedMode(BuildContext context) {
    return LayoutBuilder(builder: (context, constrains) {
      final height = constrains.maxHeight - 16;

      Widget image = Container(
        width: height * 0.68,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.outlineVariant,
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: buildImage(context),
      );

      if (heroID != null) {
        image = Hero(
          tag: "cover$heroID",
          child: image,
        );
      }

      return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _onTap,
          onLongPress: enableLongPressed ? () => _onLongPressed(context) : null,
          onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(
                  size: const Size(16, 5),
                ),
                Expanded(
                  child: _AnimeDescription(
                    title: anime.title.replaceAll("\n", ""),
                    subtitle: anime.subtitle ?? '',
                    description: anime.description,
                    badge: badge ?? anime.language,
                    tags: anime.tags,
                    maxLines: 2,
                    enableTranslate: AnimeSource.find(anime.sourceKey)
                            ?.enableTagsTranslate ??
                        false,
                    rating: anime.stars,
                  ),
                ),
              ],
            ),
          ));
    });
  }

  Widget _buildBriefMode(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget image = Container(
              decoration: BoxDecoration(
                color: context.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.toOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: buildImage(context),
            );

            if (heroID != null) {
              image = Hero(
                tag: "cover$heroID",
                child: image,
              );
            }

            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _onTap,
              onLongPress:
                  enableLongPressed ? () => _onLongPressed(context) : null,
              onSecondaryTapDown: (detail) => onSecondaryTap(detail, context),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: image,
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: (() {
                            final subtitle =
                                anime.subtitle?.replaceAll('\n', '').trim();
                            final text = anime.description.isNotEmpty
                                ? anime.description.split('|').join('\n')
                                : (subtitle?.isNotEmpty == true
                                    ? subtitle
                                    : null);
                            final fortSize = constraints.maxWidth < 80
                                ? 8.0
                                : constraints.maxWidth < 150
                                    ? 10.0
                                    : 12.0;

                            if (text == null) {
                              return const SizedBox();
                            }

                            var children = <Widget>[];
                            for (var line in text.split('\n')) {
                              children.add(Container(
                                margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                                padding: constraints.maxWidth < 80
                                    ? const EdgeInsets.fromLTRB(3, 1, 3, 1)
                                    : constraints.maxWidth < 150
                                        ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
                                        : const EdgeInsets.fromLTRB(5, 2, 5, 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.toOpacity(0.5),
                                ),
                                constraints: BoxConstraints(
                                  maxWidth: constraints.maxWidth,
                                ),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: fortSize,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ));
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: children,
                            );
                          })(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text(
                      anime.title.replaceAll('\n', ''),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ).paddingHorizontal(2).paddingVertical(2),
            );
          },
        ));
  }

  List<String> _splitText(String text) {
    // split text by comma, brackets
    var words = <String>[];
    var buffer = StringBuffer();
    var inBracket = false;
    String? prevBracket;
    for (var i = 0; i < text.length; i++) {
      var c = text[i];
      if (c == '[' || c == '(') {
        if (inBracket) {
          buffer.write(c);
        } else {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = true;
          prevBracket = c;
        }
      } else if (c == ']' || c == ')') {
        if (prevBracket == '[' && c == ']' || prevBracket == '(' && c == ')') {
          if (buffer.isNotEmpty) {
            words.add(buffer.toString().trim());
            buffer.clear();
          }
          inBracket = false;
        } else {
          buffer.write(c);
        }
      } else if (c == ',') {
        if (inBracket) {
          buffer.write(c);
        } else {
          words.add(buffer.toString().trim());
          buffer.clear();
        }
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) {
      words.add(buffer.toString().trim());
    }
    words.removeWhere((element) => element == "");
    words = words.toSet().toList();
    return words;
  }

  void block(BuildContext animeTileContext) {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        var words = <String>[];
        var all = <String>[];
        all.addAll(_splitText(anime.title));
        if (anime.subtitle != null && anime.subtitle != "") {
          all.add(anime.subtitle!);
        }
        all.addAll(anime.tags ?? []);
        return StatefulBuilder(builder: (context, setState) {
          return ContentDialog(
            title: 'Block'.tl,
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.min(400, context.height - 136),
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    for (var word in all)
                      OptionChip(
                        text: word,
                        isSelected: words.contains(word),
                        onTap: () {
                          setState(() {
                            if (!words.contains(word)) {
                              words.add(word);
                            } else {
                              words.remove(word);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ).paddingHorizontal(16),
            ),
            actions: [
              Button.filled(
                onPressed: () {
                  context.pop();
                  for (var word in words) {
                    appdata.settings['blockedWords'].add(word);
                  }
                  appdata.saveData();
                  context.showMessage(message: 'Blocked'.tl);
                  animeTileContext
                      .findAncestorStateOfType<_SliverGridAnimesState>()!
                      .update();
                },
                child: Text('Block'.tl),
              ),
            ],
          );
        });
      },
    );
  }
}

class _AnimeDescription extends StatelessWidget {
  const _AnimeDescription({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.enableTranslate,
    this.badge,
    this.maxLines = 2,
    this.tags,
    this.rating,
  });

  final String title;
  final String subtitle;
  final String description;
  final String? badge;
  final List<String>? tags;
  final int maxLines;
  final bool enableTranslate;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    if (tags != null) {
      tags!.removeWhere((element) => element.removeAllBlank == "");
      for (var s in tags!) {
        s = s.replaceAll("\n", " ");
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.trim(),
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14.0,
          ),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        if (subtitle != "")
          Text(
            subtitle,
            style: TextStyle(
                fontSize: 10.0,
                color: context.colorScheme.onSurface.toOpacity(0.7)),
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        if (tags != null && tags!.isNotEmpty)
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxHeight < 22) {
                return Container();
              }
              int cnt = (constraints.maxHeight - 22).toInt() ~/ 25;
              return Container(
                clipBehavior: Clip.antiAlias,
                height: 22 + cnt * 25,
                width: double.infinity,
                decoration: const BoxDecoration(),
                child: Wrap(
                  runAlignment: WrapAlignment.start,
                  clipBehavior: Clip.antiAlias,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    for (var s in tags!)
                      Container(
                          height: 22,
                          padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.45,
                          ),
                          decoration: BoxDecoration(
                            color: s == "Unavailable"
                                ? Theme.of(context).colorScheme.errorContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                            borderRadius:
                                const BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Center(
                              widthFactor: 1,
                              child: Text(
                                s.split(':').last,
                                style: const TextStyle(fontSize: 12),
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ))),
                  ],
                ),
              ).toAlign(Alignment.topCenter);
            }),
          )
        else
          const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rating != null) StarRating(value: rating!, size: 18),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12.0,
                    ),
                    maxLines: (tags == null || tags!.isEmpty) ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Center(
                    child: Text(
                      "${badge![0].toUpperCase()}${badge!.substring(1).toLowerCase()}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
          ],
        )
      ],
    );
  }
}

class SliverGridAnimes extends StatefulWidget {
  const SliverGridAnimes(
      {super.key,
      required this.animes,
      this.onLastItemBuild,
      this.badgeBuilder,
      this.menuBuilder,
      this.onTap,
      this.onLongPressed,
      this.selections,
      this.enableFavorite,
      this.enableHistory,
      this.isRecommend});

  final List<Anime> animes;

  final Map<Anime, bool>? selections;

  final void Function()? onLastItemBuild;

  final String? Function(Anime)? badgeBuilder;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final void Function(Anime)? onTap;

  final void Function(Anime)? onLongPressed;

  final bool? enableFavorite;

  final bool? enableHistory;

  final bool? isRecommend;

  @override
  State<SliverGridAnimes> createState() => _SliverGridAnimesState();
}

class _SliverGridAnimesState extends State<SliverGridAnimes> {
  List<Anime> animes = [];
  List<int> heroIDs = [];

  static int _nextHeroID = 0;

  void generateHeroID() {
    heroIDs.clear();
    for (var i = 0; i < animes.length; i++) {
      heroIDs.add(_nextHeroID++);
    }
  }

  @override
  void didUpdateWidget(covariant SliverGridAnimes oldWidget) {
    if (!oldWidget.animes.isEqualTo(widget.animes)) {
      animes.clear();
      for (var anime in widget.animes) {
        if (isBlocked(anime) == null) {
          animes.add(anime);
        }
      }
      generateHeroID();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    for (var anime in widget.animes) {
      if (isBlocked(anime) == null) {
        animes.add(anime);
      }
    }
    generateHeroID();
    HistoryManager().addListener(update);
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(update);
    super.dispose();
  }

  void update() {
    setState(() {
      animes.clear();
      for (var anime in widget.animes) {
        if (isBlocked(anime) == null) {
          animes.add(anime);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SliverGridAnimes(
      animes: animes,
      heroIDs: heroIDs,
      selection: widget.selections,
      onLastItemBuild: widget.onLastItemBuild,
      badgeBuilder: widget.badgeBuilder,
      menuBuilder: widget.menuBuilder,
      onTap: widget.onTap,
      onLongPressed: widget.onLongPressed,
      enableFavorite: widget.enableFavorite,
      enableHistory: widget.enableHistory,
      isRecommend: widget.isRecommend,
    );
  }
}

class _SliverGridAnimes extends StatelessWidget {
  const _SliverGridAnimes(
      {required this.animes,
      required this.heroIDs,
      this.onLastItemBuild,
      this.badgeBuilder,
      this.menuBuilder,
      this.onTap,
      this.onLongPressed,
      this.selection,
      this.enableFavorite,
      this.enableHistory,
      this.isRecommend});

  final List<Anime> animes;

  final List<int> heroIDs;

  final Map<Anime, bool>? selection;

  final void Function()? onLastItemBuild;

  final String? Function(Anime)? badgeBuilder;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final void Function(Anime)? onTap;

  final void Function(Anime)? onLongPressed;

  final bool? enableFavorite;

  final bool? enableHistory;

  final bool? isRecommend;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == animes.length - 1) {
            onLastItemBuild?.call();
          }
          var badge = badgeBuilder?.call(animes[index]);
          var isSelected =
              selection == null ? false : selection![animes[index]] ?? false;
          var anime = AnimeTile(
            anime: animes[index],
            isRecommend: isRecommend ?? false,
            enableFavorite: enableFavorite ?? true,
            enableHistory: enableHistory ?? false,
            badge: badge,
            menuOptions: menuBuilder?.call(animes[index]),
            onTap: onTap != null ? () => onTap!(animes[index]) : null,
            onLongPressed: onLongPressed != null
                ? () => onLongPressed!(animes[index])
                : null,
            heroID: heroIDs[index],
          );
          if (selection == null) {
            return anime;
          }
          return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .toOpacity(0.72)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(4),
              child: anime);
        },
        childCount: animes.length,
      ),
      gridDelegate: SliverGridDelegateWithAnimes(),
    );
  }
}

/// return the first blocked keyword, or null if not blocked
String? isBlocked(Anime item) {
  for (var word in appdata.settings['blockedWords']) {
    if (item.title.contains(word)) {
      return word;
    }
    if (item.subtitle?.contains(word) ?? false) {
      return word;
    }
    if (item.description.contains(word)) {
      return word;
    }
    for (var tag in item.tags ?? <String>[]) {
      if (tag == word) {
        return word;
      }
      if (tag.contains(':')) {
        tag = tag.split(':')[1];
        if (tag == word) {
          return word;
        }
      }
    }
  }
  return null;
}

class AnimeList extends StatefulWidget {
  const AnimeList({
    super.key,
    this.loadPage,
    this.loadNext,
    this.leadingSliver,
    this.trailingSliver,
    this.errorLeading,
    this.menuBuilder,
    this.controller,
    this.refreshHandlerCallback,
    this.enablePageStorage = false,
  });

  final Future<Res<List<Anime>>> Function(int page)? loadPage;

  final Future<Res<List<Anime>>> Function(String? next)? loadNext;

  final Widget? leadingSliver;

  final Widget? trailingSliver;

  final Widget? errorLeading;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final ScrollController? controller;

  final void Function(VoidCallback c)? refreshHandlerCallback;

  final bool enablePageStorage;

  @override
  State<AnimeList> createState() => AnimeListState();
}

class AnimeListState extends State<AnimeList> {
  int? _maxPage;

  final Map<int, List<Anime>> _data = {};

  int _page = 1;

  String? _error;

  final Map<int, bool> _loading = {};

  String? _nextUrl;

  late bool enablePageStorage = widget.enablePageStorage;

  Map<String, dynamic> get state => {
        'maxPage': _maxPage,
        'data': _data,
        'page': _page,
        'error': _error,
        'loading': _loading,
        'nextUrl': _nextUrl,
      };

  void restoreState(Map<String, dynamic>? state) {
    if (state == null || !enablePageStorage) {
      return;
    }
    _maxPage = state['maxPage'];
    _data.clear();
    _data.addAll(state['data']);
    _page = state['page'];
    _error = state['error'];
    _loading.clear();
    _loading.addAll(state['loading']);
    _nextUrl = state['nextUrl'];
  }

  void storeState() {
    if (enablePageStorage) {
      PageStorage.of(context).writeState(context, state);
    }
  }

  void refresh() {
    _data.clear();
    _page = 1;
    _maxPage = null;
    _error = null;
    _nextUrl = null;
    _loading.clear();
    storeState();
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    restoreState(PageStorage.of(context).readState(context));
    widget.refreshHandlerCallback?.call(refresh);
  }

  void remove(Anime c) {
    if (_data[_page] == null || !_data[_page]!.remove(c)) {
      for (var page in _data.values) {
        if (page.remove(c)) {
          break;
        }
      }
    }
    setState(() {});
  }

  Widget _buildPageSelector() {
    return Row(
      children: [
        FilledButton(
          onPressed: _page > 1
              ? () {
                  setState(() {
                    _error = null;
                    _page--;
                  });
                }
              : null,
          child: Text("Back".tl),
        ).fixWidth(84),
        Expanded(
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  String value = '';
                  showDialog(
                    context: App.rootContext,
                    builder: (context) {
                      return ContentDialog(
                        title: "Jump to page".tl,
                        content: TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Page".tl,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (v) {
                            value = v;
                          },
                        ).paddingHorizontal(16),
                        actions: [
                          Button.filled(
                            onPressed: () {
                              Navigator.of(context).pop();
                              var page = int.tryParse(value);
                              if (page == null) {
                                context.showMessage(message: "Invalid page".tl);
                              } else {
                                if (page > 0 &&
                                    (_maxPage == null || page <= _maxPage!)) {
                                  setState(() {
                                    _error = null;
                                    _page = page;
                                  });
                                } else {
                                  context.showMessage(
                                      message: "Invalid page".tl);
                                }
                              }
                            },
                            child: Text("Jump".tl),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text("Page $_page / ${_maxPage ?? '?'}"),
                ),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: _page < (_maxPage ?? (_page + 1))
              ? () {
                  setState(() {
                    _error = null;
                    _page++;
                  });
                }
              : null,
          child: Text("Next".tl),
        ).fixWidth(84),
      ],
    ).paddingVertical(8).paddingHorizontal(16);
  }

  Widget _buildSliverPageSelector() {
    return SliverToBoxAdapter(
      child: _buildPageSelector(),
    );
  }

  Future<void> _loadPage(int page) async {
    if (widget.loadPage == null && widget.loadNext == null) {
      _error = "loadPage and loadNext can't be null at the same time";
      Future.microtask(() {
        setState(() {});
      });
    }
    if (_loading[page] == true) {
      return;
    }
    _loading[page] = true;
    try {
      if (widget.loadPage != null) {
        var res = await widget.loadPage!(page);
        if (!mounted) return;
        if (res.success) {
          if (res.data.isEmpty) {
            _data[page] = const [];
            setState(() {
              _maxPage = page;
            });
          } else {
            setState(() {
              _data[page] = res.data;
              if (res.subData != null && res.subData is int) {
                _maxPage = res.subData;
              }
            });
          }
        } else {
          setState(() {
            _error = res.errorMessage ?? "Unknown error".tl;
          });
        }
      } else {
        try {
          while (_data[page] == null) {
            await _fetchNext();
          }
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _error = e.toString();
            });
          }
        }
      }
    } finally {
      _loading[page] = false;
      storeState();
    }
  }

  Future<void> _fetchNext() async {
    var res = await widget.loadNext!(_nextUrl);
    _data[_data.length + 1] = res.data;
    if (res.subData == null) {
      _maxPage = _data.length;
    } else {
      _nextUrl = res.subData;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          _buildPageSelector(),
          Expanded(
            child: NetworkError(
              withAppbar: false,
              message: _error!,
              retry: () {
                setState(() {
                  _error = null;
                });
              },
            ),
          ),
        ],
      );
    }
    if (_data[_page] == null) {
      _loadPage(_page);
      return Column(
        children: [
          if (widget.errorLeading != null) widget.errorLeading!,
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }
    return SmoothCustomScrollView(
      key: enablePageStorage ? PageStorageKey('scroll$_page') : null,
      controller: widget.controller,
      slivers: [
        if (widget.leadingSliver != null) widget.leadingSliver!,
        if (_maxPage != 1) _buildSliverPageSelector(),
        SliverGridAnimes(
          animes: _data[_page] ?? const [],
          menuBuilder: widget.menuBuilder,
        ),
        if (_data[_page]!.length > 6 && _maxPage != 1)
          _buildSliverPageSelector(),
        if (widget.trailingSliver != null) widget.trailingSliver!,
      ],
    );
  }
}

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.onTap,
    this.size = 20,
  });

  final double value; // 0-5

  final VoidCallback? onTap;

  final double size;

  @override
  Widget build(BuildContext context) {
    var interval = size * 0.1;
    var value = this.value;
    if (value.isNaN) {
      value = 0;
    }
    var child = SizedBox(
      height: size,
      width: size * 5 + interval * 4,
      child: Row(
        children: [
          for (var i = 0; i < 5; i++)
            _Star(
              value: (value - i).clamp(0.0, 1.0),
              size: size,
            ).paddingRight(i == 4 ? 0 : interval),
        ],
      ),
    );
    return onTap == null
        ? child
        : GestureDetector(
            onTap: onTap,
            child: child,
          );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.value, required this.size});

  final double value; // 0-1

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(
            Icons.star_outline,
            size: size,
            color: context.colorScheme.secondary,
          ),
          ClipRect(
            clipper: _StarClipper(value),
            child: Icon(
              Icons.star,
              size: size,
              color: context.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarClipper extends CustomClipper<Rect> {
  final double value;

  _StarClipper(this.value);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * value, size.height);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) {
    return oldClipper is! _StarClipper || oldClipper.value != value;
  }
}

class RatingWidget extends StatefulWidget {
  /// star number
  final int count;

  /// Max score
  final double maxRating;

  /// Current score value
  final double value;

  /// Star size
  final double size;

  /// Space between the stars
  final double padding;

  /// Whether the score can be modified by sliding
  final bool selectable;

  /// Callbacks when ratings change
  final ValueChanged<double> onRatingUpdate;

  const RatingWidget(
      {super.key,
      this.maxRating = 10.0,
      this.count = 5,
      this.value = 10.0,
      this.size = 20,
      required this.padding,
      this.selectable = false,
      required this.onRatingUpdate});

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  double value = 10;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        double x = event.localPosition.dx;
        if (x < 0) x = 0;
        pointValue(x);
      },
      onPointerMove: (PointerMoveEvent event) {
        double x = event.localPosition.dx;
        if (x < 0) x = 0;
        pointValue(x);
      },
      onPointerUp: (_) {},
      behavior: HitTestBehavior.deferToChild,
      child: buildRowRating(),
    );
  }

  pointValue(double dx) {
    if (!widget.selectable) {
      return;
    }
    if (dx >=
        widget.size * widget.count + widget.padding * (widget.count - 1)) {
      value = widget.maxRating;
    } else {
      for (double i = 1; i < widget.count + 1; i++) {
        if (dx > widget.size * i + widget.padding * (i - 1) &&
            dx < widget.size * i + widget.padding * i) {
          value = i * (widget.maxRating / widget.count);
          break;
        } else if (dx > widget.size * (i - 1) + widget.padding * (i - 1) &&
            dx < widget.size * i + widget.padding * i) {
          value = (dx - widget.padding * (i - 1)) /
              (widget.size * widget.count) *
              widget.maxRating;
          break;
        }
      }
    }
    if (value % 1 >= 0.5) {
      value = value ~/ 1 + 1;
    } else {
      value = (value ~/ 1).toDouble();
    }
    if (value < 0) {
      value = 0;
    } else if (value > 10) {
      value = 10;
    }
    setState(() {
      widget.onRatingUpdate(value);
    });
  }

  int fullStars() {
    return (value / (widget.maxRating / widget.count)).floor();
  }

  double star() {
    if (widget.count / fullStars() == widget.maxRating / value) {
      return 0;
    }
    return (value % (widget.maxRating / widget.count)) /
        (widget.maxRating / widget.count);
  }

  List<Widget> buildRow() {
    int full = fullStars();
    List<Widget> children = [];
    for (int i = 0; i < full; i++) {
      children.add(Icon(
        Icons.star,
        size: widget.size,
        color: context.colorScheme.secondary,
      ));
      if (i < widget.count - 1) {
        children.add(
          SizedBox(
            width: widget.padding,
          ),
        );
      }
    }
    if (full < widget.count) {
      children.add(ClipRect(
        clipper: _SMClipper(rating: star() * widget.size),
        child: Icon(
          Icons.star,
          size: widget.size,
          color: context.colorScheme.secondary,
        ),
      ));
    }

    return children;
  }

  List<Widget> buildNormalRow() {
    List<Widget> children = [];
    for (int i = 0; i < widget.count; i++) {
      children.add(Icon(
        Icons.star_border,
        size: widget.size,
        color: context.colorScheme.secondary,
      ));
      if (i < widget.count - 1) {
        children.add(SizedBox(
          width: widget.padding,
        ));
      }
    }
    return children;
  }

  Widget buildRowRating() {
    return Stack(
      children: <Widget>[
        Row(
          children: buildNormalRow(),
        ),
        Row(
          children: buildRow(),
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    value = widget.value;
  }
}

class _SMClipper extends CustomClipper<Rect> {
  final double rating;

  _SMClipper({required this.rating});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0.0, 0.0, rating, size.height);
  }

  @override
  bool shouldReclip(_SMClipper oldClipper) {
    return rating != oldClipper.rating;
  }
}

class SimpleAnimeTile extends StatelessWidget {
  const SimpleAnimeTile(
      {super.key, required this.anime, this.onTap, this.withTitle = false});

  final Anime anime;

  final void Function()? onTap;

  final bool withTitle;

  @override
  Widget build(BuildContext context) {
    var image = _findImageProvider(anime);

    Widget child = image == null
        ? const SizedBox()
        : AnimatedImage(
            image: image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          );

    child = Container(
      width: 98,
      height: 136,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    child = AnimatedTapRegion(
      borderRadius: 8,
      onTap: onTap ??
          () {
            context.to(
              () => AnimePage(
                id: anime.id,
                sourceKey: anime.sourceKey,
              ),
            );
          },
      child: child,
    );

    if (withTitle) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          SizedBox(
            width: 92,
            child: Center(
              child: Text(
                anime.title.replaceAll('\n', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}

class BangumiCard extends StatefulWidget {
  const BangumiCard(
      {super.key, required this.bangumiItem, this.onTap, this.heroTag});

  final BangumiItem bangumiItem;
  final void Function()? onTap;
  final String? heroTag;

  @override
  State<BangumiCard> createState() => _BangumiCardState();
}

class _BangumiCardState extends State<BangumiCard> {
  BangumiItem get bangumiItem => widget.bangumiItem;

  Widget _score() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${bangumiItem.score}',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(
          width: 5,
        ),
        Container(
          padding: EdgeInsets.fromLTRB(8, 5, 8, 5), // 可选，设置内边距
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8), // 设置圆角半径
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.toOpacity(0.72),
              width: 1.0, // 设置边框宽度
            ),
          ),
          child: Text(Utils.getRatingLabel(bangumiItem.score),
              style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          width: 4,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end, // 右对齐
          children: [
            RatingBarIndicator(
              itemCount: 5,
              rating: bangumiItem.score.toDouble() / 2,
              itemBuilder: (context, index) => const Icon(
                Icons.star_rounded,
              ),
              itemSize: 16.0,
            ),
            Text(
              '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
              style: TextStyle(fontSize: 10),
            )
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String? image = widget.bangumiItem.images['large'];

    return AnimatedTapRegion(
      borderRadius: 8,
      onTap: widget.onTap ?? () {},
      child: Container(
        width: 300 * 0.72,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // **背景图片（无Hero）**
            Widget backgroundImage = BangumiWidget.kostoriImage(
              context,
              image!,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );

            backgroundImage = Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              clipBehavior: Clip.antiAlias,
              child: backgroundImage,
            );

            // **前景图片（保留Hero动画）**
            Widget foregroundImage = Hero(
              tag: '${widget.heroTag}-${widget.bangumiItem.id}',
              child: BangumiWidget.kostoriImage(
                context,
                image,
                width: constraints.maxWidth,
                height: constraints.maxHeight * 0.85,
              ),
            );

            foregroundImage = Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.secondaryContainer,
              ),
              clipBehavior: Clip.antiAlias,
              child: foregroundImage,
            );

            return Stack(
              children: [
                // 图片作为背景层（可调整透明度或添加滤镜）
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.2, // 调整背景图片透明度
                    child: backgroundImage,
                  ),
                ),

                // 保持原有的Column布局
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 原有图片显示
                      SizedBox(
                        height: constraints.maxHeight * 0.85,
                        width: constraints.maxWidth,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: foregroundImage,
                            ),
                            Positioned(
                              bottom: App.isAndroid ? 42 : 46,
                              right: 8,
                              child: ClipRRect(
                                // 确保圆角区域也能正确裁剪模糊效果
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Stack(
                                        children: [
                                          // 背景噪声图（建议用半透明 PNG 或 SVG）
                                          Positioned.fill(
                                            child: Opacity(
                                              opacity: 0.6,
                                              child: Image.asset(
                                                'assets/img/noise.png',
                                                // 模拟毛玻璃颗粒的纹理图
                                                fit: BoxFit.cover,
                                                color: context.brightness ==
                                                        Brightness.light
                                                    ? Colors.white
                                                        .toOpacity(0.3)
                                                    : Colors.black
                                                        .toOpacity(0.3),
                                                colorBlendMode:
                                                    BlendMode.srcOver,
                                              ),
                                            ),
                                          ),

                                          // 渐变遮罩（调整透明度过渡）
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: context.brightness ==
                                                        Brightness.light
                                                    ? Colors.white
                                                        .toOpacity(0.3)
                                                    : Colors.black
                                                        .toOpacity(0.3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 原有内容（需要在模糊层之上）
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                                      child: Text(
                                          '放送时间: ${DateFormat('HH:mm').format(DateTime.parse(bangumiItem.airTime as String).toLocal())}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          )),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: ClipRRect(
                                // 确保圆角区域也能正确裁剪模糊效果
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Stack(
                                        children: [
                                          // 背景噪声图（建议用半透明 PNG 或 SVG）
                                          Positioned.fill(
                                            child: Opacity(
                                              opacity: 0.6,
                                              child: Image.asset(
                                                'assets/img/noise.png',
                                                // 模拟毛玻璃颗粒的纹理图
                                                fit: BoxFit.cover,
                                                color: context.brightness ==
                                                        Brightness.light
                                                    ? Colors.white
                                                        .toOpacity(0.3)
                                                    : Colors.black
                                                        .toOpacity(0.3),
                                                colorBlendMode:
                                                    BlendMode.srcOver,
                                              ),
                                            ),
                                          ),

                                          // 渐变遮罩（调整透明度过渡）
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: context.brightness ==
                                                        Brightness.light
                                                    ? Colors.white
                                                        .toOpacity(0.3)
                                                    : Colors.black
                                                        .toOpacity(0.3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 原有内容（需要在模糊层之上）
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
                                      child: _score(),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                      // 文字部分
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 8.0, left: 4, right: 4, bottom: 4),
                          child: TextScroll(
                            bangumiItem.nameCn != ''
                                ? bangumiItem.nameCn
                                : bangumiItem.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: context.brightness == Brightness.light
                                      ? Colors.white.toOpacity(0.3)
                                      : Colors.black.toOpacity(0.3),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            mode: TextScrollMode.endless,
                            delayBefore: Duration(milliseconds: 500),
                            velocity:
                                const Velocity(pixelsPerSecond: Offset(40, 0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
