// ignore_for_file: use_build_context_synchronously

part of 'anime_page.dart';

Map<String, String> commentDrafts = {};

abstract mixin class _AnimePageActions {
  final InfoController infoController = InfoController();

  final WatcherController watcherController = WatcherController();

  final PlayerController playerController = PlayerController();

  void update();

  AnimeDetails get anime;

  AnimeSource get animeSource => AnimeSource.find(anime.sourceKey)!;

  History? history;

  BangumiItem? bangumiBindInfo;

  StatsDataImpl? statsDataImpl;

  DailyEvent? todayComment;
  PlatformEventRecord? commentRecord;

  DailyEvent? todayClick;
  PlatformEventRecord? clickRecord;

  DailyEvent? todayWatch;
  PlatformEventRecord? watchRecord;

  DailyEvent? todayRating;
  PlatformEventRecord? ratingRecord;

  int? ratingValue;

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
      viewMore: anime.viewMore,
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
    LocalFavoritesManager().addAnime(folder, _toFavoriteItem());
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
            ? MediaQuery.of(context).size.width *
                  9 /
                  16 // 设置最大宽度
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.only(
                left: 20,
                top: 12,
                right: 20,
                bottom: 12,
              ),
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  if (appdata.implicitData['nameAvatar'] == null ||
                      appdata.implicitData['nameAvatar'] == '')
                    const Image(
                      image: AssetImage("images/app_icon.png"),
                      filterQuality: FilterQuality.medium,
                    )
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(
                        appdata.implicitData['nameAvatar'],
                      ),
                      backgroundColor: Colors.transparent,
                    ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      bangumiBottomInfoSelect(context);
                    }, // 按钮点击事件
                    child: Text('Match Bangumi ID'.tl), // 按钮文本
                  ),
                ],
              ),
            ),
            // 下面是 BottomInfo 内容
            Expanded(
              child: bangumiId == null
                  ? MiscComponents.placeholder(
                      context,
                      100,
                      100,
                      Colors.transparent,
                    )
                  : BottomInfo(
                      bangumiId: bangumiId,
                      infoController: infoController,
                    ),
            ),
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
        context: context,
      );
    }

    // 显示 BottomSheet
    final selectedItem = await showModalBottomSheet<BangumiItem>(
      isScrollControlled: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4, // 设置最大高度
        maxWidth: (App.isDesktop)
            ? MediaQuery.of(context).size.width *
                  9 /
                  16 // 设置最大宽度
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: App.rootContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> fetchSearchResults(String query) async {
              FocusScope.of(App.rootContext).unfocus();
              if (query.isEmpty) {
                res = await Bangumi.combinedBangumiSearch(anime.title);
              } else {
                res = await Bangumi.combinedBangumiSearch(query);
              }

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
                  context: context,
                );
              }

              // 更新状态
              setState(() {});
            }

            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                        color: context.colorScheme.surface.toOpacity(0.22),
                      ),
                    ),
                  ),
                  backgroundColor: Colors.transparent,
                  title: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: anime.title,
                          hintText: 'Enter keywords...'.tl,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                        onSubmitted: fetchSearchResults,
                        onChanged: (value) => value,
                      ),
                    ),
                  ),
                ),
              ],
              body: _buildResultsList(res, fetchSearchResults),
            );
          },
        );
      },
    );

    if (selectedItem != null) {
      await handleSelection(context, selectedItem).then((_) {
        Navigator.pop(context);
      });
    }
  }

  Widget _buildResultsList(List<BangumiItem> items, Function(String) onSearch) {
    if (items.isEmpty) {
      return Center(child: Text('暂无搜索结果'));
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            Navigator.pop(context, item);
          },
          splashColor: Theme.of(
            context,
          ).colorScheme.secondaryContainer.toOpacity(0.72),
          highlightColor: Theme.of(
            context,
          ).colorScheme.secondaryContainer.toOpacity(0.72),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double height =
                    constraints.maxWidth *
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
                          context,
                          item.images['large']!,
                          width: width,
                          height: height,
                        ),
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
                            Text(item.name, style: TextStyle(fontSize: 14.0)),
                            Text('放送日期: ${item.airDate}'),
                            const SizedBox(height: 10),
                            Text(
                              item.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
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
                                    style: TextStyle(fontSize: 32.0),
                                  ),
                                  SizedBox(width: 5),
                                  Container(
                                    padding: EdgeInsets.all(2.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        8,
                                      ), // 设置圆角半径
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .toOpacity(0.72),
                                        width: 2.0,
                                      ),
                                    ),
                                    child: Text(
                                      Utils.getRatingLabel(item.score),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      RatingBarIndicator(
                                        itemCount: 5,
                                        rating: item.score.toDouble() / 2,
                                        itemBuilder: (context, index) =>
                                            const Icon(Icons.star_rounded),
                                        itemSize: 20.0,
                                      ),
                                      Text(
                                        '@t reviews | #@r'.tlParams({
                                          'r': item.rank,
                                          't': item.total,
                                        }),
                                        style: TextStyle(fontSize: 12),
                                      ),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Determine the binding: @a ?'.tlParams({"a": item.name})),
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
                    BottomInfoState.currentState?.queryBangumiEpisodeByID(
                      item.id,
                    );
                    StatsManager().updateStats(
                      id: history!.id,
                      type: history!.type.value,
                      bangumiId: item.id,
                    );
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

  void shareImage() {
    showPopUpWidget(
      App.rootContext,
      StatefulBuilder(
        builder: (context, setState) {
          if (history!.bangumiId == null) {
            return ShareWidget(anime: anime);
          }

          return ShareWidget(id: history!.bangumiId as int);
        },
      ),
    );
  }

  void onTapTag(String tag, String namespace) {
    var target = animeSource.handleClickTagEvent?.call(namespace, tag);
    var context = App.mainNavigatorKey!.currentContext!;
    target?.jump(context);
  }

  void liked() {
    StatsManager().updateGroupLiked(
      id: anime.id,
      type: anime.sourceKey.hashCode,
      targetLiked: !isLiked,
    );
  }

  Future<void> showRatingDialog(StatsDataImpl statsDataImpl) async {
    showDialog(
      context: App.rootContext,
      builder: (context) {
        return RatingDialog(statsDataImpl: statsDataImpl);
      },
    );
  }
}

class RatingDialog extends StatefulWidget {
  const RatingDialog({super.key, required this.statsDataImpl});

  final StatsDataImpl statsDataImpl;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  late StatsDataImpl _statsDataImpl;
  late double _rating;
  late bool _showingDraft;
  bool _isLoading = true;
  late TextEditingController _commentController;
  late TodayEventBundle stats;
  final manager = StatsManager();
  TodayEventBundle? bangumiStats;

  @override
  void initState() {
    super.initState();
    _statsDataImpl = widget.statsDataImpl;
    _initializeData();
  }

  void _initializeData() async {
    stats = StatsManager().getOrCreateTodayEvents(
      id: _statsDataImpl.id,
      type: _statsDataImpl.type,
    );

    setState(() {
      bangumiStats = manager.getOrCreateBangumiStats(
        statsDataImpl: stats.statsData,
      );
      final targetStats = bangumiStats ?? stats;
      _rating = (targetStats.ratingRecord.rating ?? 0).toDouble();
      final idKey = targetStats.statsData.id;
      _showingDraft = commentDrafts[idKey]?.isNotEmpty == true;
      if (!_showingDraft) {
        commentDrafts[idKey] = '';
      }
      _commentController = TextEditingController(
        text: _showingDraft
            ? commentDrafts[idKey]
            : (targetStats.commentRecord.comment ?? ''),
      );
      _isLoading = false;
    });
  }

  void _toggleDraftSaved() {
    setState(() {
      final targetStats = bangumiStats ?? stats;
      final idKey = targetStats.statsData.id;
      _showingDraft = !_showingDraft;
      _commentController.text = (_showingDraft
          ? commentDrafts[idKey]
          : (targetStats.commentRecord.comment ?? ''))!;
    });
  }

  void _updateStats() async {
    try {
      final targetStats = bangumiStats ?? stats;
      final newRating = _rating.toInt();
      final newComment = _commentController.text;
      final now = DateTime.now();
      final todayStr = now.yyyymmdd;

      int getTotalWatchDuration() {
        int total = 0;
        for (final dailyEvent in targetStats.statsData.totalWatchDurations) {
          for (final record in dailyEvent.platformEventRecords) {
            total += record.value;
          }
        }
        return total;
      }

      if (targetStats.ratingRecord.rating != newRating) {
        DailyEvent? todayRecord = targetStats.statsData.rating.firstWhereOrNull(
          (dailyEvent) {
            return dailyEvent.date.year == now.year &&
                dailyEvent.date.month == now.month &&
                dailyEvent.date.day == now.day;
          },
        );

        final newRatingRecord = PlatformEventRecord(
          value: todayRecord != null ? targetStats.ratingRecord.value + 1 : 1,
          platform: AppPlatform.current,
          rating: newRating,
          dateStr: now.yyyymmddHHmmss,
          watchDuration:
              getTotalWatchDuration() +
              StatsManager().getOtherBangumiTotalWatch(
                current: targetStats.statsData,
                time: now,
              ),
        );

        if (todayRecord != null) {
          todayRecord.platformEventRecords.add(newRatingRecord);
          todayRecord.platformEventRecords.removeWhere((p) => p.value == 0);
        } else {
          final newDailyEvent = DailyEvent(
            dateStr: todayStr,
            platformEventRecords: [newRatingRecord],
          );
          targetStats.statsData.rating.add(newDailyEvent);
        }
      }

      if (targetStats.commentRecord.comment != newComment) {
        DailyEvent? todayRecord = targetStats.statsData.comment
            .firstWhereOrNull((dailyEvent) {
              return dailyEvent.date.year == now.year &&
                  dailyEvent.date.month == now.month &&
                  dailyEvent.date.day == now.day;
            });

        final newCommentRecord = PlatformEventRecord(
          value: todayRecord != null ? targetStats.commentRecord.value + 1 : 1,
          platform: AppPlatform.current,
          comment: newComment,
          dateStr: now.yyyymmddHHmmss,
          watchDuration:
              getTotalWatchDuration() +
              StatsManager().getOtherBangumiTotalWatch(
                current: targetStats.statsData,
                time: now,
              ),
        );

        if (todayRecord != null) {
          todayRecord.platformEventRecords.add(newCommentRecord);
          todayRecord.platformEventRecords.removeWhere((p) => p.value == 0);
        } else {
          final newDailyEvent = DailyEvent(
            dateStr: todayStr,
            platformEventRecords: [newCommentRecord],
          );
          targetStats.statsData.comment.add(newDailyEvent);
        }
      }

      await StatsManager().updateStats(
        id: targetStats.statsData.id,
        type: targetStats.statsData.type,
        rating: targetStats.statsData.rating,
        comment: targetStats.statsData.comment,
      );

      if (targetStats.commentRecord.comment != newComment ||
          targetStats.ratingRecord.rating != newRating) {
        App.rootContext.showMessage(message: '应用成功');
      } else {
        App.rootContext.showMessage(message: '无改动');
      }
    } catch (e, s) {
      App.rootContext.showMessage(message: '应用失败');
      Log.addLog(LogLevel.error, 'save statsDataImpl', '$e \n $s');
    } finally {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ContentDialog(
      title: "Rating".tl,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Utils.getRatingLabel(_rating),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(' / '),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _rating = 0;
                      _commentController.text = '';
                    });
                  },
                  child: Text(
                    '清除',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            RatingBar.builder(
              initialRating: _rating / 2,
              minRating: 0,
              maxRating: 5,
              allowHalfRating: true,
              itemBuilder: (context, index) => const Icon(Icons.star_rounded),
              itemSize: 30,
              onRatingUpdate: (newRating) {
                setState(() {
                  _rating = newRating * 2;
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        child: TextField(
                          controller: _commentController,
                          maxLines: null,
                          onChanged: (_) => setState(() {
                            final targetStats = bangumiStats ?? stats;
                            commentDrafts[targetStats.statsData.id] =
                                _commentController.text;
                          }),
                          decoration: InputDecoration(
                            hintText: '写下你的评价...'.tl,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(_showingDraft ? '草稿'.tl : '正文'.tl),
                        const SizedBox(width: 4),
                        Text("${_commentController.text.length} 字".tl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(onPressed: _toggleDraftSaved, child: Text('切换'.tl)),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _updateStats, child: Text('Update'.tl)),
      ],
    );
  }
}
