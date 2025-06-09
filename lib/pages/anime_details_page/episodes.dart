part of 'anime_page.dart';

class _AnimeEpisodes extends StatefulWidget {
  const _AnimeEpisodes({this.history});

  final History? history;

  @override
  State<_AnimeEpisodes> createState() => _AnimeEpisodesState();
}

class _AnimeEpisodesState extends State<_AnimeEpisodes> {
  late _AnimePageState state;
  late History? history;

  // 当前播放列表的索引，默认为0
  int playList = 0;
  Map<String, String> currentEps = {};
  int length = 0;
  bool reverse = false;
  bool showAll = false;

  @override
  void initState() {
    super.initState();
    history = widget.history;
    if (history != null) {
      playList = history!.lastRoad;
    }
  }

  @override
  void didChangeDependencies() {
    state = context.findAncestorStateOfType<_AnimePageState>()!;
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant _AnimeEpisodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      history = widget.history;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 获取所有播放列表（例如，ep1, ep2, ep3...）
    // state.anime.episode?.keys.toList();
    final episodeValues = state.anime.episode?.values.elementAt(playList);

    currentEps = episodeValues!;
    length = currentEps.length;

    if (!showAll) {
      length = math.min(length, 24); // 限制显示的集数
    }

    int currentLength = length;

    return SliverMainAxisGroup(
      slivers: [
        // 显示标题和切换顺序的按钮
        SliverToBoxAdapter(
          child: ListTile(
            title: Row(
              children: [
                Text("Playlist".tl),
                const SizedBox(width: 5),
                SizedBox(
                  height: 34,
                  child: TextButton(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text('Playlist'.tl),
                              content: StatefulBuilder(builder:
                                  (BuildContext context,
                                      StateSetter innerSetState) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  children: [
                                    for (int i = 0;
                                        i < state.anime.episode!.keys.length;
                                        i++) ...<Widget>[
                                      if (i == playList) ...<Widget>[
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            setState(() {
                                              playList = i;
                                            });
                                          },
                                          child: Text(state.anime.episode!.keys
                                              .elementAt(i)),
                                        ),
                                      ] else ...[
                                        FilledButton.tonal(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            setState(() {
                                              playList = i;
                                            });
                                          },
                                          child: Text(state.anime.episode!.keys
                                              .elementAt(i)),
                                        ),
                                      ]
                                    ]
                                  ],
                                );
                              }),
                            );
                          });
                    },
                    child: Text(
                      state.anime.episode!.keys.elementAt(playList),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                Spacer(),
              ],
            ),
            trailing: Tooltip(
              message: "Order".tl,
              child: IconButton(
                icon: Icon(reverse
                    ? Icons.vertical_align_top
                    : Icons.vertical_align_bottom_outlined),
                onPressed: () {
                  setState(() {
                    reverse = !reverse; // 切换顺序
                  });
                },
              ),
            ),
          ),
        ),

        // 显示播放列表内容的网格
        SliverGrid(
          key: ValueKey(playList),
          delegate: SliverChildBuilderDelegate(
            childCount: currentLength, // 使用更新后的 length
            (context, i) {
              if (i >= currentEps.length) {
                return Container(); // 防止越界
              }

              if (reverse) {
                i = currentEps.length - i - 1; // 反向排序
              }

              var key = currentEps.keys.elementAt(i); // 获取集数名称
              var value = currentEps[key]!; // 获取集数内容
              bool visited =
                  (history?.watchEpisode ?? const {}).contains(i + 1);

              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Material(
                  color: !visited
                      ? context.colorScheme.surfaceContainer
                      : Theme.of(context).colorScheme.primary.toOpacity(0.3),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: InkWell(
                    onTap: () => state.watch(i + 1, playList),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Center(
                        child: Text(
                          value,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: visited ? context.colorScheme.outline : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          gridDelegate: const SliverGridDelegateWithFixedHeight(
              maxCrossAxisExtent: 200, itemHeight: 48),
        ),

        // 显示更多按钮
        if (currentEps.length > 24 && !showAll)
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: () {
                  setState(() {
                    showAll = true;
                  });
                },
                label: Text("${"Show all".tl} (${currentEps.length})"),
              ).paddingTop(12),
            ),
          ),

        const SliverToBoxAdapter(child: Divider()), // 添加分割线
      ],
    );
  }
}
