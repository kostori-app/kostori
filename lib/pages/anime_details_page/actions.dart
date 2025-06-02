// ignore_for_file: use_build_context_synchronously

part of 'anime_page.dart';

abstract mixin class _AnimePageActions {
  final InfoController infoController = InfoController();

  void update();

  AnimeDetails get anime;

  AnimeSource get animeSource => AnimeSource.find(anime.sourceKey)!;

  History? history;

  BangumiItem? bangumiBindInfo;

  bool isLiking = false;

  bool isLiked = false;

  bool isAddToLocalFav = false;

  bool isFavorite = false;

  FavoriteItem _toFavoriteItem() {
    var tags = <String>[];
    for (var e in anime.tags.entries) {
      tags.addAll(e.value.map((tag) => '${e.key}:$tag'));
    }
    return FavoriteItem(
      id: anime.id,
      name: anime.title,
      coverPath: anime.cover,
      author: anime.subTitle ?? anime.uploader ?? '',
      type: anime.animeType,
      tags: tags,
    );
  }

  void openFavPanel() {
    _FavoriteDialog.show(
      cid: anime.id,
      type: anime.animeType,
      isFavorite: isFavorite,
      onFavorite: (local) {
        isFavorite = isFavorite;
        isAddToLocalFav = local ?? isAddToLocalFav;
        update();
      },
      favoriteItem: _toFavoriteItem(),
      context: App.rootContext,
    );
  }

  void quickFavorite() {
    var folder = appdata.settings['quickFavorite'];
    if (folder is! String) {
      return;
    }
    LocalFavoritesManager().addAnime(
      folder,
      _toFavoriteItem(),
    );
    isAddToLocalFav = true;
    update();
    App.rootContext.showMessage(message: "Added".tl);
  }

  Future<void> bangumiBottomInfo(BuildContext context) async {
    var bangumiId = history!.bangumiId;
    showModalBottomSheet(
      isScrollControlled: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4, // 设置最大高度
        maxWidth: MediaQuery.of(context).size.width <= 600
            ? MediaQuery.of(context).size.width
            : (App.isDesktop)
                ? MediaQuery.of(context).size.width * 9 / 16 // 设置最大宽度
                : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 自定义顶部区域
            Container(
              padding:
                  EdgeInsets.only(left: 20, top: 12, right: 20, bottom: 12),
              height: 60, // 自定义顶部区域高度
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)), // 圆角效果
              ),
              child: Row(children: [
                const Image(
                  image: AssetImage("images/app_icon.png"),
                  filterQuality: FilterQuality.medium,
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    bangumiBottomInfoSelect(context);
                  }, // 按钮点击事件
                  child: Text('Match Bangumi ID'.tl), // 按钮文本
                ),
              ]),
            ),
            // 下面是 BottomInfo 内容
            Expanded(
                child: BottomInfo(
              bangumiId: bangumiId,
              infoController: infoController,
            )),
          ],
        );
      },
    );
  }

  // 显示 BottomSheet，并允许选择一个项目
  Future<void> bangumiBottomInfoSelect(BuildContext context) async {
    var res = await Bangumi.combinedBangumiSearch(anime.title);
    // 如果 res 是 null 或者数据不正确，显示检索失败提示
    if (res.isEmpty) {
      showCenter(
          seconds: 3,
          icon: Gif(
            image: AssetImage('assets/img/warning.gif'),
            height: 64,
            fps: 120,
            // color: Theme.of(context).colorScheme.primary,
            autostart: Autostart.once,
          ),
          message: '检索失败',
          context: context);
    }

    // 显示 BottomSheet
    final selectedItem = await showModalBottomSheet<BangumiItem>(
      isScrollControlled: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4, // 设置最大高度
        maxWidth: (App.isDesktop)
            ? MediaQuery.of(context).size.width * 9 / 16 // 设置最大宽度
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        // 使用 StatefulBuilder 实现搜索框和动态搜索功能
        return StatefulBuilder(
          builder: (context, setState) {
            // 更新搜索结果的函数
            Future<void> fetchSearchResults(String query) async {
              if (query.isEmpty) {
                // 如果搜索框为空，则默认展示初始数据
                res = await Bangumi.combinedBangumiSearch(anime.title);
              } else {
                // 否则根据用户输入重新搜索
                res = await Bangumi.combinedBangumiSearch(query);
              }

              // 如果搜索结果为空，提示用户
              if (res.isEmpty) {
                showCenter(
                    seconds: 3,
                    icon: Gif(
                      image: AssetImage('assets/img/warning.gif'),
                      height: 64,
                      fps: 120,
                      autostart: Autostart.once,
                    ),
                    message: '未找到相关结果，请尝试其他关键字',
                    context: context);
              }

              // 更新状态
              setState(() {});
            }

            return Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // 固定在顶部的搜索框
                  SliverAppBar(
                    pinned: true,
                    floating: true,
                    snap: true,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                            color: context.colorScheme.surface.toOpacity(0.22)),
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    title: TextField(
                      decoration: InputDecoration(
                        labelText: anime.title,
                        hintText: '请输入关键字进行搜索',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                      ),
                      onSubmitted: fetchSearchResults,
                      onChanged: (value) => value,
                    ),
                  ),
                ],
                body: _buildResultsList(context, res, fetchSearchResults),
              ),
            );
          },
        );
      },
    );
    // 如果用户选择了某个项，执行相关操作
    if (selectedItem != null) {
      await handleSelection(context, selectedItem);
    }
  }

  Widget _buildResultsList(BuildContext context, List<BangumiItem> items,
      Function(String) onSearch) {
    if (items.isEmpty) {
      return Center(child: Text('暂无搜索结果'));
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 16), // 给顶部留出空间
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            Navigator.pop(context, item); // 返回选中的项
          },
          splashColor:
              Theme.of(context).colorScheme.secondaryContainer.toOpacity(0.72),
          highlightColor:
              Theme.of(context).colorScheme.secondaryContainer.toOpacity(0.72),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double height = constraints.maxWidth *
                    (App.isDesktop
                        ? (constraints.maxWidth > 1024 ? 6 / 16 : 10 / 16)
                        : 10 / 16);
                double width = height * 0.72;

                return SizedBox(
                  width: constraints.maxWidth,
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BangumiWidget.kostoriImage(
                            context, item.images['large']!,
                            width: width, height: height),
                      ),
                      SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bangumi ID: ${item.id}',
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.nameCn,
                              style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 14.0,
                              ),
                            ),
                            Text(
                              '放送日期: ${item.airDate}',
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text(
                              item.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '${item.score}',
                                    style: TextStyle(
                                      fontSize: 32.0,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Container(
                                    padding: EdgeInsets.all(2.0), // 可选，设置内边距
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(8), // 设置圆角半径
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .toOpacity(0.72),
                                        width: 2.0, // 设置边框宽度
                                      ),
                                    ),
                                    child: Text(
                                      Utils.getRatingLabel(item.score),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 4,
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end, // 右对齐
                                    children: [
                                      RatingBarIndicator(
                                        itemCount: 5,
                                        rating: item.score.toDouble() / 2,
                                        itemBuilder: (context, index) =>
                                            const Icon(
                                          Icons.star_rounded,
                                        ),
                                        itemSize: 20.0,
                                      ),
                                      Text(
                                        '${item.total} 人评 | #${item.rank}',
                                        style: TextStyle(fontSize: 12),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 处理选择后的操作
  Future<void> handleSelection(BuildContext context, BangumiItem item) async {
    // 模拟延迟操作，可以替换成其他操作（如网络请求等）
    // await Future.delayed(Duration(seconds: 1));
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Determine the binding: @a ?'.tlParams({
            "a": item.name,
          })),
          content: Text(item.airDate),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  if (history != null) {
                    history!.bangumiId = item.id;
                    HistoryManager().addHistoryAsync(history!);
                    WatcherState.currentState!.bangumiId = item.id;
                    infoController.bangumiId = item.id;
                    BottomInfoState.currentState?.queryBangumiInfoByID(item.id);
                    BottomInfoState.currentState
                        ?.queryBangumiEpisodeByID(item.id);
                  }
                } catch (e) {
                  Log.addLog(LogLevel.error, "绑定bangumiId", "$e");
                }
                App.rootContext.showMessage(message: '绑定bangumiId成功');
                Navigator.pop(context);
              },
              child: Text('Ok'.tl),
            ),
            TextButton(
              onPressed: () => {Navigator.pop(context)},
              child: Text('Close'.tl),
            ),
          ],
        );
      },
    );
  }

  Future<void> share() async {
    shareImage();
  }

  final GlobalKey _repaintKey = GlobalKey();

  void shareImage() {
    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(builder: (context, setState) {
        if (history!.bangumiId == null) {
          return PopUpWidgetScaffold(
            title: anime.title,
            body: Column(
              children: [
                RepaintBoundary(
                  key: _repaintKey,
                  child: Padding(
                    padding:
                        EdgeInsets.only(bottom: context.padding.bottom + 16),
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(width: 16),
                                //封面
                                Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          context.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    height: 256,
                                    width: 256 * 0.72,
                                    clipBehavior: Clip.antiAlias,
                                    child: AnimatedImage(
                                      image: CachedImageProvider(
                                        anime.cover,
                                        sourceKey: anime.sourceKey,
                                      ),
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        //标题
                                        Text(
                                          anime.title,
                                          style: ts.s20,
                                        ),
                                        if (anime.subTitle != null)
                                          SelectableText(anime.subTitle!,
                                              style: ts.s14),
                                        //源名称
                                        Text(
                                          (AnimeSource.find(anime.sourceKey)
                                                  ?.name) ??
                                              '',
                                          style: ts.s12,
                                        ),
                                        const SizedBox(height: 16),
                                        if (history?.bangumiId == null)
                                          Text(
                                            anime.tags.entries.map((entry) {
                                              // 对每个键值对，创建一个字符串表示形式
                                              return '${entry.key}: ${entry.value.join(', ')}';
                                            }).join('\n'), // 用换行符分隔每个键值对
                                            style: ts.s12,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                              ],
                            ),
                          ),
                          Text(
                            '简介',
                            style: ts.s18,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                            child: SelectableText(anime.description!)
                                .fixWidth(double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Spacer(), // 使用 Spacer 将按钮区域移至弹出框外
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Spacer(),
                      FilledButton(
                        onPressed: () {
                          _captureAndSave();
                          App.rootContext.pop();
                        },
                        child: Text('Share'.tl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<dynamic>>(
          future: Future.wait([
            BangumiManager().bindFind(history?.bangumiId as int),
            // Future 1
            Bangumi.getBangumiEpisodeAllByID(history?.bangumiId as int),
            // Future 2, // Future 3
          ]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return PopUpWidgetScaffold(
                title: anime.title,
                body: Center(
                    child: MiscComponents.placeholder(context, 100, 100,
                        Colors.transparent)), // Loading state
              );
            }

            final bangumiItem = snapshot.data?[0];
            final allEpisodes = snapshot.data?[1] as List<EpisodeInfo>;

            // 获取当前周的剧集
            final currentWeekEp =
                Utils.findCurrentWeekEpisode(allEpisodes, bangumiItem);

            // 判断是否已全部播出（检查是否是最后一项）
            final isCompleted = currentWeekEp != null &&
                allEpisodes.isNotEmpty &&
                currentWeekEp == allEpisodes.last;

            return PopUpWidgetScaffold(
              title: anime.title,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _repaintKey,
                      child: Padding(
                        padding: EdgeInsets.only(
                            bottom: context.padding.bottom + 16),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: Column(
                            children: [
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: LayoutBuilder(
                                      builder: (context, constraints) {
                                    double height = constraints.maxWidth / 2;
                                    double width = height * 0.72;
                                    return Container(
                                      width: constraints.maxWidth,
                                      height: height,
                                      padding: EdgeInsets.all(2),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(width: 16),
                                          //封面
                                          Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: context.colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              height: height,
                                              width: width,
                                              clipBehavior: Clip.antiAlias,
                                              child: AnimatedImage(
                                                image: CachedImageProvider(
                                                  anime.cover,
                                                  sourceKey: anime.sourceKey,
                                                ),
                                                width: double.infinity,
                                                height: double.infinity,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  //标题
                                                  Text(
                                                    anime.title,
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Text(bangumiItem.name,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        )),
                                                  const SizedBox(height: 16),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Container(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              8, 5, 8, 5),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                        border: Border.all(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .primary
                                                              .toOpacity(0.72),
                                                          width: 1.0,
                                                        ),
                                                      ),
                                                      child: Text(
                                                          bangumiItem.airDate),
                                                    ),
                                                  SizedBox(height: 12.0),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    (currentWeekEp?.sort !=
                                                            null)
                                                        ? Text(
                                                            isCompleted
                                                                ? '全 ${bangumiItem.totalEpisodes} 话'
                                                                : '连载至 ${currentWeekEp?.sort} • 预定全 ${bangumiItem.totalEpisodes} 话',
                                                            style: TextStyle(
                                                              fontSize: 12.0,
                                                            ),
                                                          )
                                                        : Text(
                                                            '未开播',
                                                            style: TextStyle(
                                                                fontSize: 12.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                  Spacer(),
                                                  if (history?.bangumiId !=
                                                          null &&
                                                      bangumiItem != null)
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            '${bangumiItem.score}',
                                                            style: TextStyle(
                                                              fontSize: 32.0,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: 5,
                                                          ),
                                                          Container(
                                                            padding: EdgeInsets
                                                                .fromLTRB(
                                                                    8, 5, 8, 5),
                                                            // 可选，设置内边距
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              // 设置圆角半径
                                                              border:
                                                                  Border.all(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .primary
                                                                    .toOpacity(
                                                                        0.72),
                                                                width:
                                                                    1.0, // 设置边框宽度
                                                              ),
                                                            ),
                                                            child: Text(
                                                              Utils.getRatingLabel(
                                                                  bangumiItem
                                                                      .score),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: 4,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end, // 右对齐
                                                            children: [
                                                              RatingBarIndicator(
                                                                itemCount: 5,
                                                                rating: bangumiItem
                                                                        .score
                                                                        .toDouble() /
                                                                    2,
                                                                itemBuilder: (context,
                                                                        index) =>
                                                                    const Icon(
                                                                  Icons
                                                                      .star_rounded,
                                                                ),
                                                                itemSize: 20.0,
                                                              ),
                                                              Text(
                                                                '${bangumiItem.total} 人评 | #${bangumiItem.rank}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12),
                                                              )
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2, horizontal: 16),
                                  child: Align(
                                    child: Row(
                                      children: [
                                        Text(
                                            '${bangumiItem.collection?['doing']} 在看',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            )),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['collect']} 看过',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['wish']} 想看',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueAccent)),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['on_hold']} 搁置',
                                            style: TextStyle(fontSize: 12)),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection?['dropped']} 抛弃',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            )),
                                        Text(' / '),
                                        Text(
                                            '${bangumiItem.collection!['doing']! + bangumiItem.collection!['collect']! + bangumiItem.collection!['wish']! + bangumiItem.collection!['on_hold']! + bangumiItem.collection!['dropped']!} 总计数',
                                            style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(
                                child: Divider(),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '简介',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 16),
                                  child: SelectableText(bangumiItem.summary)
                                      .fixWidth(double.infinity),
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              SizedBox(
                                child: Divider(),
                              ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '标签',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16, horizontal: 16),
                                  child: Wrap(
                                      spacing: 8.0,
                                      runSpacing: App.isDesktop ? 8 : 0,
                                      children: List<Widget>.generate(
                                          bangumiItem.tags.length, (int index) {
                                        return Chip(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                  '${bangumiItem.tags[index].name} '),
                                              Text(
                                                '${bangumiItem.tags[index].count}',
                                                style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList()),
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              SizedBox(
                                child: Divider(),
                              ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '评分统计图',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                SizedBox(
                                  height: 12,
                                ),
                              if (history?.bangumiId != null &&
                                  bangumiItem != null)
                                LineChatPage(
                                  bangumiItem: bangumiItem,
                                ),
                              SizedBox(
                                child: Divider(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 20,
                    ),
                    // Spacer(), // 使用 Spacer 将按钮区域移至弹出框外
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Spacer(),
                          FilledButton(
                            onPressed: () {
                              _captureAndSave();
                              App.rootContext.pop();
                            },
                            child: Text('Share'.tl),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // 截取图像并保存
  Future<void> _captureAndSave() async {
    try {
      RenderRepaintBoundary boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary;

      // 获取截图数据
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List uint8List = byteData!.buffer.asUint8List();

      // 保存文件
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/popup_image.png');
      await file.writeAsBytes(uint8List);
      //     // 使用 shareFile 函数分享文件
      Uint8List data = await file.readAsBytes();
      Share.shareFile(data: data, filename: 'image.jpg', mime: 'image/jpeg');
      Log.addLog(LogLevel.info, '截图保存', file.path);
    } catch (e) {
      Log.addLog(LogLevel.error, '截图失败', '$e');
    }
  }

  void watch([int? ep, int? road]) {
    WatcherState.currentState!.loadInfo(ep!, road!); // 传递集数
  }

  void onTapTag(String tag, String namespace) {
    var config = animeSource.handleClickTagEvent?.call(namespace, tag) ??
        {
          'action': 'search',
          'keyword': tag,
        };
    var context = App.mainNavigatorKey!.currentContext!;
    if (config['action'] == 'search') {
      context.to(() => SearchResultPage(
            text: config['keyword'] ?? '',
            sourceKey: animeSource.key,
            options: const [],
          ));
    }
  }
}
