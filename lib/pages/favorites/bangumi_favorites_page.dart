part of 'favorites_page.dart';

class BangumiFavoritesPage extends StatefulWidget {
  const BangumiFavoritesPage({super.key, required this.favoritesController});

  final FavoritesController favoritesController;

  @override
  State<BangumiFavoritesPage> createState() => _BangumiFavoritesPageState();
}

class _BangumiFavoritesPageState extends State<BangumiFavoritesPage>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<BangumiFavoritesPage> {
  late TabController controller;
  late _FavoritesPageState favPage;

  FavoritesController get favoritesController => widget.favoritesController;

  String get name => widget.favoritesController.bangumiUserName;

  final List<String> tab = ['抛弃', '想看', '在看', '搁置', '看过'];

  bool useBriefMode = true;

  bool doingIsLoading = false;
  bool collectIsLoading = false;
  bool wishIsLoading = false;
  bool onHoldIsLoading = false;
  bool droppedIsLoading = false;

  bool doingQueryTimeout = false;
  bool collectQueryTimeout = false;
  bool wishQueryTimeout = false;
  bool onHoldQueryTimeout = false;
  bool droppedQueryTimeout = false;

  @override
  void initState() {
    super.initState();
    favPage = context.findAncestorStateOfType<_FavoritesPageState>()!;
    favoritesController.doingList.clear();
    favoritesController.collectList.clear();
    favoritesController.droppedList.clear();
    favoritesController.wishList.clear();
    favoritesController.onHoldList.clear();
    useBriefMode = appdata.settings['animeDisplayMode'] == 'brief';
    controller = TabController(length: 5, vsync: this, initialIndex: 2);
    controller.addListener(() {
      int index = controller.index;
      if (index == 0 &&
          favoritesController.droppedList.isEmpty &&
          !droppedIsLoading) {
        if (name.isNotEmpty) {
          loadDroppedList();
        }
      }
      if (index == 1 &&
          favoritesController.wishList.isEmpty &&
          !wishIsLoading) {
        if (name.isNotEmpty) {
          loadWishList();
        }
      }
      if (index == 3 &&
          favoritesController.onHoldList.isEmpty &&
          !onHoldIsLoading) {
        if (name.isNotEmpty) {
          loadOnHoldList();
        }
      }
      if (index == 4 &&
          favoritesController.collectList.isEmpty &&
          !collectIsLoading) {
        if (name.isNotEmpty) {
          loadCollectList();
        }
      }
    });
    if (name.isNotEmpty) {
      loadDoingList();
    }
  }

  @override
  void dispose() {
    favoritesController.doingList.clear();
    favoritesController.collectList.clear();
    favoritesController.droppedList.clear();
    favoritesController.wishList.clear();
    favoritesController.onHoldList.clear();
    super.dispose();
  }

  Future<void> loadDoingList({int offset = 0}) async {
    if (doingIsLoading) return;
    setState(() {
      doingIsLoading = true;
      doingQueryTimeout = false;
    });
    favoritesController
        .queryBangumiFavoriteDoingByName(name: name, offset: offset)
        .then((_) {
          if (favoritesController.doingList.isEmpty && mounted) {
            setState(() {
              doingIsLoading = false;
              doingQueryTimeout = true;
            });
          }
          if (favoritesController.doingList.isNotEmpty && mounted) {
            setState(() {
              doingIsLoading = false;
            });
          }
        });
  }

  Future<void> loadCollectList({int offset = 0}) async {
    if (collectIsLoading) return;
    setState(() {
      collectIsLoading = true;
      collectQueryTimeout = false;
    });
    favoritesController
        .queryBangumiFavoriteCollectByName(name: name, offset: offset)
        .then((_) {
          if (favoritesController.collectList.isEmpty && mounted) {
            setState(() {
              collectIsLoading = false;
              collectQueryTimeout = true;
            });
          }
          if (favoritesController.collectList.isNotEmpty && mounted) {
            setState(() {
              collectIsLoading = false;
            });
          }
        });
  }

  Future<void> loadWishList({int offset = 0}) async {
    if (wishIsLoading) return;
    setState(() {
      wishIsLoading = true;
      wishQueryTimeout = false;
    });
    favoritesController
        .queryBangumiFavoriteWishByName(name: name, offset: offset)
        .then((_) {
          if (favoritesController.wishList.isEmpty && mounted) {
            setState(() {
              wishIsLoading = false;
              wishQueryTimeout = true;
            });
          }
          if (favoritesController.wishList.isNotEmpty && mounted) {
            setState(() {
              wishIsLoading = false;
            });
          }
        });
  }

  Future<void> loadOnHoldList({int offset = 0}) async {
    if (onHoldIsLoading) return;
    setState(() {
      onHoldIsLoading = true;
      onHoldQueryTimeout = false;
    });
    favoritesController
        .queryBangumiFavoriteOnHoldByName(name: name, offset: offset)
        .then((_) {
          if (favoritesController.onHoldList.isEmpty && mounted) {
            setState(() {
              onHoldIsLoading = false;
              onHoldQueryTimeout = true;
            });
          }
          if (favoritesController.onHoldList.isNotEmpty && mounted) {
            setState(() {
              onHoldIsLoading = false;
            });
          }
        });
  }

  Future<void> loadDroppedList({int offset = 0}) async {
    if (droppedIsLoading) return;
    setState(() {
      droppedIsLoading = true;
      droppedQueryTimeout = false;
    });
    favoritesController
        .queryBangumiFavoriteDroppedByName(name: name, offset: offset)
        .then((_) {
          if (favoritesController.droppedList.isEmpty && mounted) {
            setState(() {
              droppedIsLoading = false;
              droppedQueryTimeout = true;
            });
          }
          if (favoritesController.droppedList.isNotEmpty && mounted) {
            setState(() {
              droppedIsLoading = false;
            });
          }
        });
  }

  Widget _bangumiListSliver(List<BangumiItem> bangumiItems) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        var bangumi = useBriefMode
            ? BangumiWidget.buildBriefMode(
                context,
                bangumiItems[index],
                'favorite',
                showPlaceholder: false,
              )
            : BangumiWidget.buildDetailedMode(
                context,
                bangumiItems[index],
                'favorite',
              );
        return bangumi;
      }, childCount: bangumiItems.length),
      gridDelegate: SliverGridDelegateWithBangumiItems(useBriefMode),
    );
  }

  Widget get doingListBody {
    return Observer(
      builder: (context) {
        final doingList = favoritesController.doingList;
        return Builder(
          builder: (BuildContext context) {
            return NotificationListener<ScrollEndNotification>(
              onNotification: (scrollEnd) {
                final metrics = scrollEnd.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                  if (name.isNotEmpty) {
                    loadDoingList(offset: doingList.length);
                  }
                }
                return true;
              },
              child: CustomScrollView(
                scrollBehavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                key: const PageStorageKey<String>('doing'),
                slivers: <Widget>[
                  doingList.isEmpty
                      ? (useBriefMode
                            ? BangumiWidget.bangumiSkeletonSliverBrief()
                            : BangumiWidget.bangumiSkeletonSliverDetailed())
                      : _bangumiListSliver(doingList),
                  if (doingIsLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: MiscComponents.placeholder(
                            context,
                            40,
                            40,
                            Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget get collectListBody {
    return Observer(
      builder: (context) {
        final collectList = favoritesController.collectList;
        return Builder(
          builder: (BuildContext context) {
            return NotificationListener<ScrollEndNotification>(
              onNotification: (scrollEnd) {
                final metrics = scrollEnd.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                  if (name.isNotEmpty) {
                    loadCollectList(offset: collectList.length);
                  }
                }
                return true;
              },
              child: CustomScrollView(
                scrollBehavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                key: PageStorageKey<String>('collect'),
                slivers: <Widget>[
                  collectList.isEmpty
                      ? (useBriefMode
                            ? BangumiWidget.bangumiSkeletonSliverBrief()
                            : BangumiWidget.bangumiSkeletonSliverDetailed())
                      : _bangumiListSliver(collectList),
                  if (collectIsLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: MiscComponents.placeholder(
                            context,
                            40,
                            40,
                            Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget get wishListBody {
    return Observer(
      builder: (context) {
        final wishList = favoritesController.wishList;
        return Builder(
          builder: (BuildContext context) {
            return NotificationListener<ScrollEndNotification>(
              onNotification: (scrollEnd) {
                final metrics = scrollEnd.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                  if (name.isNotEmpty) {
                    loadWishList(offset: wishList.length);
                  }
                }
                return true;
              },
              child: CustomScrollView(
                scrollBehavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                key: PageStorageKey<String>('wish'),
                slivers: <Widget>[
                  wishList.isEmpty
                      ? (useBriefMode
                            ? BangumiWidget.bangumiSkeletonSliverBrief()
                            : BangumiWidget.bangumiSkeletonSliverDetailed())
                      : _bangumiListSliver(wishList),
                  if (wishIsLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: MiscComponents.placeholder(
                            context,
                            40,
                            40,
                            Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget get onHoldListBody {
    return Observer(
      builder: (context) {
        final onHoldList = favoritesController.onHoldList;
        return Builder(
          builder: (BuildContext context) {
            return NotificationListener<ScrollEndNotification>(
              onNotification: (scrollEnd) {
                final metrics = scrollEnd.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                  if (name.isNotEmpty) {
                    loadOnHoldList(offset: onHoldList.length);
                  }
                }
                return true;
              },
              child: CustomScrollView(
                scrollBehavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                key: PageStorageKey<String>('onHold'),
                slivers: <Widget>[
                  onHoldList.isEmpty
                      ? (useBriefMode
                            ? BangumiWidget.bangumiSkeletonSliverBrief()
                            : BangumiWidget.bangumiSkeletonSliverDetailed())
                      : _bangumiListSliver(onHoldList),
                  if (onHoldIsLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: MiscComponents.placeholder(
                            context,
                            40,
                            40,
                            Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget get droppedListBody {
    return Observer(
      builder: (context) {
        final droppedList = favoritesController.droppedList;
        return Builder(
          builder: (BuildContext context) {
            return NotificationListener<ScrollEndNotification>(
              onNotification: (scrollEnd) {
                final metrics = scrollEnd.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 200) {
                  if (name.isNotEmpty) {
                    loadDroppedList(offset: droppedList.length);
                  }
                }
                return true;
              },
              child: CustomScrollView(
                scrollBehavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                key: PageStorageKey<String>('dropped'),
                slivers: <Widget>[
                  droppedList.isEmpty
                      ? (useBriefMode
                            ? BangumiWidget.bangumiSkeletonSliverBrief()
                            : BangumiWidget.bangumiSkeletonSliverDetailed())
                      : _bangumiListSliver(droppedList),
                  if (droppedIsLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: MiscComponents.placeholder(
                            context,
                            40,
                            40,
                            Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
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
        bottom: TabBar(
          tabs: tab.map((title) => Tab(text: title)).toList(),
          controller: controller,
          tabAlignment: TabAlignment.center,
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          droppedListBody,
          wishListBody,
          doingListBody,
          onHoldListBody,
          collectListBody,
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
