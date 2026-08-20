part of 'anime_page.dart';

class _AnimeEpisodes extends StatefulWidget {
  const _AnimeEpisodes({this.history, super.key});

  final History? history;

  @override
  State<_AnimeEpisodes> createState() => _AnimeEpisodesState();
}

class _AnimeEpisodesState extends State<_AnimeEpisodes> {
  late _AnimePageState state;
  late History? history;

  int playList = 0;
  Map<String, dynamic> currentEps = {};
  int length = 0;
  bool reverse = false;

  /// 系列列表是否正序（默认 false = 保持源返回的倒序，可切换）
  bool _seriesAsc = false;
  bool showAll = false;

  /// 系列模式：源无分集，加载与剧集平行的系列列表（复用 Anime 结构）
  List<Anime>? _series;

  /// 当前是否为系列模式（episode 为空且源提供 loadSeries）
  bool get _isSeries =>
      (state.anime.episode == null || state.anime.episode!.isEmpty) &&
      AnimeSource.find(state.anime.sourceKey)?.loadSeries != null;

  /// 是否已从历史恢复线路（anime_page 的 history 是异步加载的，
  /// 首次 build 可能为 null，需等它就绪后再恢复一次）
  bool _playListRestored = false;

  @override
  void initState() {
    super.initState();
    history = widget.history;
    if (history != null) {
      playList = history!.lastRoad ?? 0;
      _playListRestored = true;
    }
  }

  @override
  void didChangeDependencies() {
    state = context.findAncestorStateOfType<_AnimePageState>()!;
    if (_isSeries && _series == null) {
      _loadSeries();
    }
    super.didChangeDependencies();
  }

  /// 加载系列列表（仅系列模式）；结果缓存在 anime_page state，避免每次重建重新请求
  Future<void> _loadSeries() async {
    final source = AnimeSource.find(state.anime.sourceKey);
    if (source == null || source.loadSeries == null) return;
    if (state._seriesListCache != null) {
      if (mounted) setState(() => _series = state._seriesListCache);
      return;
    }
    final res = await source.loadSeries!(state.anime);
    final list = res.dataOrNull ?? const <Anime>[];
    state._seriesListCache = list;
    if (mounted) setState(() => _series = list);
  }

  @override
  void didUpdateWidget(covariant _AnimeEpisodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      history = widget.history;
      // history 异步就绪后，把线路恢复到上次播放/选择的位置
      if (!_playListRestored && widget.history != null) {
        playList = widget.history!.lastRoad ?? 0;
        _playListRestored = true;
      }
    });
  }

  /// 系列模式列表：竖向卡片（左图右文），正在播放的用主题色
  Widget _buildSeriesList(BuildContext context) {
    final series = _series;
    if (series == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: KostoriRefreshIndicator()),
      );
    }
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }
    // 排序：优先按标题尾部数字（集序），无数字保持原序
    final items = List<Anime>.from(series)..sort((a, b) {
      final ka = _seriesSortKey(a.title);
      final kb = _seriesSortKey(b.title);
      if (ka == 0 || kb == 0) return 0;
      return _seriesAsc ? ka - kb : kb - ka;
    });
    // 当前播放的条目：按原始索引定位，排序后改用 id 匹配高亮
    final playingIndex = state.playerController.currentEpisoded - 1;
    final playingId = (playingIndex >= 0 && playingIndex < series.length)
        ? series[playingIndex].id
        : null;
    // 当前详情条目（id 与 anime 一致），系列模式下其单集卡片显示在顶部
    final currentIndex = series.indexWhere((a) => a.id == state.anime.id);
    // Observer：监听 playerController 状态，正在播放/暂停切换时实时刷新卡片
    return Observer(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (currentIndex >= 0)
              _buildCurrentEpisodeCard(context, series[currentIndex]),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                t.series,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: _seriesAsc ? t.sortAsc : t.sortDesc,
                icon: Icon(
                  _seriesAsc ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                onPressed: () => setState(() => _seriesAsc = !_seriesAsc),
              ),
            ),
            for (var i = 0; i < items.length; i++)
              _SeriesCard(
                entry: items[i],
                isPlaying:
                    state.playerController.videoUrl.isNotEmpty &&
                    playingId != null &&
                    items[i].id == playingId,
                isPlayingNow: state.playerController.playing,
                onTap: () async {
                  // 播放用原始列表索引，排序不影响播放逻辑
                  final originalIndex = series.indexOf(items[i]);
                  await state.playerController.playEpisode(
                    originalIndex + 1,
                    0,
                  );
                  // 系列条目互相独立：点击时同页切换详情信息为该条目
                  await state._switchToSeriesEntry(items[i]);
                  if (mounted) setState(() {});
                },
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// 当前条目（系列模式单集）卡片：标题 + 播放按钮，点击直接播放该条目
  Widget _buildCurrentEpisodeCard(BuildContext context, Anime entry) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: colorScheme.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final idx = _series!.indexWhere((a) => a.id == entry.id);
            if (idx >= 0) {
              state.playerController.playEpisode(idx + 1, 0);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 134,
                    child: entry.cover.isEmpty
                        ? ColoredBox(
                            color: colorScheme.secondaryContainer,
                            child: Icon(
                              Icons.movie_outlined,
                              color: colorScheme.outline,
                            ),
                          )
                        : AnimatedImage(
                            image: CachedImageProvider(
                              entry.cover,
                              sourceKey: entry.sourceKey,
                            ),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (entry.subtitle != null &&
                          entry.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        t.singleEpisode,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.play_circle_fill,
                  size: 44,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 从标题提取排序数字（如"少女彈珠汽水 7" → 7），无数字返回 0
  int _seriesSortKey(String title) {
    final m = RegExp(r'(\d+)\s*$').firstMatch(title.trim());
    if (m == null) return 0;
    return int.tryParse(m.group(1)!) ?? 0;
  }

  Future<void> showEp({required int ep, required int road}) async {
    final progressFind = await HistoryManager().progressFindAsync(
      state.anime.id,
      AnimeType(state.anime.sourceKey.hashCode),
      ep,
      road,
    );

    if (progressFind == null) {
      showDialog(
        context: App.rootContext,
        builder: (context) {
          return ContentDialog(content: Text(t.noViewingRecord));
        },
      );
      return;
    }

    final p = progressFind;

    String formatHMS(int milliseconds) {
      final totalSeconds = (milliseconds / 1000).round();
      final h = totalSeconds ~/ 3600;
      final m = (totalSeconds % 3600) ~/ 60;
      final s = totalSeconds % 60;

      final parts = <String>[];
      if (h > 0) parts.add('${h}h');
      if (h > 0 || m > 0) parts.add('${m}m');
      parts.add('${s}s');

      return parts.join(' ');
    }

    showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: t.viewingRecord,
          displayButton: false,
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.episodeN(n: p.episode + 1)),
                Text(
                  t.watchDurationLabel(
                    duration: formatHMS(p.progressInMilli),
                  ),
                ),
                Text(
                  t.completedStatus(
                    status: p.isCompleted ? t.yes : t.no,
                  ),
                ),
                if (p.startTime != null)
                  Text(
                    t.startTimeLabel(time: p.startTime.toString()),
                  ),
                if (p.endTime != null)
                  Text(t.endTimeLabel(time: p.endTime.toString())),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 系列模式：与剧集平行的系列列表（竖向卡片）
    if (_isSeries) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_buildTopActions(context), _buildSeriesList(context)],
      );
    }
    final episodeValues = state.anime.episode?.values.elementAt(playList);

    currentEps = episodeValues!;
    length = currentEps.length;

    if (!showAll) {
      length = math.min(length, 24);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopActions(context),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 0,
                ),
                minVerticalPadding: 0,
                title: Row(
                  children: [
                    Text(t.playlist),
                    const SizedBox(width: 5),
                    MenuAnchor(
                      consumeOutsideTap: true,
                      builder: (_, MenuController controller, _) {
                        return TextButton(
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(EdgeInsets.zero),
                          ),
                          onPressed: () {
                            controller.isOpen
                                ? controller.close()
                                : controller.open();
                          },
                          child: Text(
                            state.anime.episode!.keys.elementAt(playList),
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      },
                      menuChildren: List<MenuItemButton>.generate(
                        state.anime.episode!.keys.length,
                        (int i) => MenuItemButton(
                          onPressed: () {
                            setState(() {
                              playList = i;
                            });
                          },
                          child: Container(
                            height: 40,
                            constraints: const BoxConstraints(minWidth: 112),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              state.anime.episode!.keys.elementAt(i),
                              style: TextStyle(
                                color: i == playList
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                fontWeight: i == playList
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Tooltip(
                  message: t.order,
                  child: IconButton(
                    icon: Icon(
                      reverse
                          ? Icons.vertical_align_top
                          : Icons.vertical_align_bottom_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        reverse = !reverse;
                      });
                    },
                  ),
                ),
              ),

              LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final availableWidth =
                      constraints.maxWidth - 16; // subtract horizontal padding
                  final crossAxisCount = screenWidth < 1200 ? 3 : 4;
                  final itemWidth = availableWidth / crossAxisCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: List.generate(length, (i) {
                        int index = i;
                        if (reverse) {
                          index = length - i - 1;
                        }

                        var key = currentEps.keys.elementAt(index);
                        var value = currentEps[key]!;
                        bool visited = (history?.watchEpisode ?? const {})
                            .contains(index + 1);

                        return SizedBox(
                          // 只有一集时占满整行，避免显示成 1/3 宽的小格子
                          width: length == 1 ? availableWidth : itemWidth,
                          height: 84,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            child: Material(
                              color: !visited
                                  ? context.colorScheme.surfaceContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primary.toOpacity(0.3),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () async {
                                  await state.playerController.playEpisode(
                                    index + 1,
                                    playList,
                                  );
                                  if (mounted) setState(() {});
                                },
                                onLongPress: () {
                                  showEp(ep: index, road: playList);
                                },
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Observer(
                                        builder: (context) {
                                          final isCurrent =
                                              state
                                                  .playerController
                                                  .videoUrl
                                                  .isNotEmpty &&
                                              playList ==
                                                  state
                                                      .playerController
                                                      .currentRoad &&
                                              index ==
                                                  state
                                                          .playerController
                                                          .currentEpisoded -
                                                      1;

                                          if (!isCurrent) {
                                            return const SizedBox.shrink();
                                          }

                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              state.playerController.playing
                                                  ? Image.asset(
                                                      'assets/img/playing.gif',
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                      height: 16,
                                                    )
                                                  : Icon(
                                                      Icons.pause,
                                                      size: 16,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                              const SizedBox(width: 6),
                                            ],
                                          );
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          AnimeDetails.episodeTitleOf(value),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: visited
                                                ? (playList ==
                                                              state
                                                                  .playerController
                                                                  .currentRoad &&
                                                          i ==
                                                              state
                                                                      .playerController
                                                                      .currentEpisoded -
                                                                  1)
                                                      ? null
                                                      : context
                                                            .colorScheme
                                                            .outline
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),

              if (currentEps.length > 24 && !showAll)
                TextButton.icon(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    setState(() {
                      showAll = true;
                    });
                  },
                  label: Text("${t.showAll} (${currentEps.length})"),
                ).paddingTop(12),
            ],
          ),
        ),
      ],
    );
  }

  /// 顶层操作按钮行（剧集/系列列表之上，后续可扩展更多按钮）
  Widget _buildTopActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          // 下载（从基本信息 tab 移到此处，与重载并列）
          IconTileButton(
            icon: Icon(
              state.isDownloaded
                  ? Icons.download_done
                  : Icons.download_outlined,
            ),
            label: t.download,
            onTap: () => state._onDownloadTap(),
            onLongPress: () => context.to(() => const DownloadPage()),
            color: state.isDownloaded
                ? Colors.green
                : Theme.of(context).colorScheme.primary,
          ),
          IconTileButton(
            icon: const Icon(Icons.refresh),
            label: t.reloadEpisode,
            onTap: () => state.playerController.reloadCurrent(),
          ),
        ],
      ),
    );
  }
}

/// 系列条目卡片：左图右文（标题 + 其他信息），正在播放时用主题色高亮
class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.entry,
    required this.isPlaying,
    required this.isPlayingNow,
    required this.onTap,
  });

  final Anime entry;

  final bool isPlaying;

  /// 是否正在播放中（区别于 isPlaying：当前集但已暂停）
  final bool isPlayingNow;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: isPlaying
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPlaying
              ? BorderSide(color: colorScheme.primary, width: 1.5)
              : BorderSide(color: colorScheme.outlineVariant, width: 0.6),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // 左侧封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 96,
                    height: 134,
                    child: entry.cover.isEmpty
                        ? ColoredBox(
                            color: colorScheme.secondaryContainer,
                            child: Icon(
                              Icons.movie_outlined,
                              color: colorScheme.outline,
                            ),
                          )
                        : AnimatedImage(
                            image: CachedImageProvider(
                              entry.cover,
                              sourceKey: entry.sourceKey,
                            ),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isPlaying ? colorScheme.primary : null,
                        ),
                      ),
                      if (entry.subtitle != null &&
                          entry.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (entry.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (isPlaying) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPlayingNow)
                              Image.asset(
                                'assets/img/playing.gif',
                                color: colorScheme.primary,
                                height: 14,
                              )
                            else
                              Icon(
                                Icons.pause,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              t.playing,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isPlaying ? Icons.graphic_eq : Icons.play_circle_outline,
                  color: isPlaying ? colorScheme.primary : colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
