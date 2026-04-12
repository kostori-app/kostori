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

// ── Providers ────────────────────────────────────────────────────────────────

final favoritesVersion = StateProvider<int>((ref) => 0);
final historyVersion = StateProvider<int>((ref) => 0);

// ── AnimeTile ─────────────────────────────────────────────────────────────────

class AnimeTile extends ConsumerWidget {
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

  AnimeType get _animeType => AnimeType(anime.sourceKey.hashCode);

  void _onTap(WidgetRef ref) {
    if (onTap != null) {
      onTap!();
      return;
    }
    if (isRecommend) {
      App.mainNavigatorKey?.currentContext?.toReplacement(
        () => AnimePage(
          id: anime.id,
          sourceKey: anime.sourceKey,
          cover: anime.cover,
          title: anime.title,
          heroID: heroID,
        ),
      );
    } else if (anime.viewMore != null && anime.viewMore?.attributes != null) {
      var context = App.mainNavigatorKey!.currentContext!;
      anime.viewMore!.jump(context);
    } else {
      App.mainNavigatorKey?.currentContext?.to(
        () => AnimePage(
          id: anime.id,
          sourceKey: anime.sourceKey,
          cover: anime.cover,
          title: anime.title,
          heroID: heroID,
        ),
      );
    }

    final stats = StatsManager();
    if (!stats.isExist(anime.id, _animeType)) {
      try {
        stats.addStats(
          stats.createStatsData(
            id: anime.id,
            title: anime.title,
            cover: anime.cover,
            type: anime.sourceKey.hashCode,
          ),
        );
      } catch (e) {
        StatsLog.error('addStats', e.toString());
      }
    }

    LocalFavoritesManager().updateRecentlyWatched(anime.id, _animeType);
  }

  // ignore: strict_top_level_inference
  void _onLongPressed(BuildContext context, WidgetRef ref) {
    if (onLongPressed != null) {
      onLongPressed!();
      return;
    }
    _onLongPress(context, ref);
  }

  void _onLongPress(BuildContext context, WidgetRef ref) {
    // 从上下文获取位置用于上下文菜单
    final renderBox = context.findRenderObject() as RenderBox?;
    final Offset location =
        renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    _showMenu(location, context, ref);
  }

  void _onSecondaryTap(
    TapDownDetails details,
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _showMenu(details.globalPosition, context, ref);
  }

  Future<void> _showMenu(
    Offset location,
    BuildContext context,
    WidgetRef ref,
  ) async {
    // 确保远程控制服务已启动
    if (!LanControlService.instance.isListening &&
        LanControlService.instance.connectionCount == 0) {
      try {
        final port =
            appdata.implicitData['lan_discovery_port'] as int? ?? 42183;
        await LanControlService.instance.start(port);
      } catch (e) {
        DebugLog.warning('AnimeTile', '启动远程控制服务失败: $e');
      }
    }

    // 检查是否有远程连接
    // isListening: 当前设备作为被控端是否正在监听
    // connectionCount: 当前设备作为被控端有多少客户端连接
    // isConnected: 当前设备作为控制端是否已连接到其他设备
    final isRemoteConnected = LanControlClient.instance.isConnected;

    // 检查是否已收藏
    final isFavorited = LocalFavoritesManager().isExist(anime.id, _animeType);

    final menuEntries = <MenuEntry>[
      MenuEntry(
        icon: Icons.copy,
        text: t.copyTitle,
        onClick: () {
          Clipboard.setData(ClipboardData(text: anime.title));
          App.rootContext.showMessage(message: t.titleCopied);
        },
      ),
    ];

    // 收藏按钮：根据是否已收藏显示不同选项
    if (isFavorited) {
      menuEntries.add(
        MenuEntry(
          icon: Icons.star,
          text: t.removeFromFavorites,
          onClick: () {
            // 从所有文件夹中移除收藏
            final folders = LocalFavoritesManager().find(anime.id, _animeType);
            for (final folder in folders) {
              LocalFavoritesManager().deleteAnimeWithId(
                folder,
                anime.id,
                _animeType,
              );
            }
            ref.read(favoritesVersion.notifier).state++;
          },
        ),
      );
    } else {
      // 未收藏时显示两个选项：添加到收藏夹 / 添加到默认
      menuEntries.add(
        MenuEntry(
          icon: Icons.stars_outlined,
          text: t.addToFavorites,
          onClick: () {
            addFavorite(anime);
            ref.read(favoritesVersion.notifier).state++;
          },
        ),
      );
      menuEntries.add(
        MenuEntry(
          icon: Icons.add_circle_outline,
          text: t.addToDefault,
          onClick: () {
            if (!LocalFavoritesManager().isExist(anime.id, _animeType)) {
              defaultFavorite(anime);
              ref.read(favoritesVersion.notifier).state++;
              App.rootContext.showMessage(message: t.addToFavoritesSuccess);
            }
          },
        ),
      );
    }
    final settingKey = 'debugInfo';

    bool enabled = appdata.settings[settingKey] as bool? ?? false;

    if (kDebugMode || enabled) {
      menuEntries.add(
        MenuEntry(
          icon: Icons.info_outline_rounded,
          text: t.debugInfo,
          onClick: () {
            ContentDialog.show(
              context: App.rootContext,
              title: t.debugInfo,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    [
                      ("title", anime.title),
                      ("id", anime.id),
                      ("sourceKey", anime.sourceKey),
                      ("cover", anime.cover),
                      ("subtitle", anime.subtitle),
                      ("language", anime.language),
                      ("stars", anime.stars?.toString()),
                      ("favoriteId", anime.favoriteId),
                      ("tags", anime.tags?.join(', ')),
                      ("description", anime.description),
                      (
                        "viewMore",
                        "${anime.viewMore?.page} / ${anime.viewMore?.attributes}",
                      ),
                    ].map((e) {
                      final text = "${e.$1}: ${e.$2}";
                      return InkWell(
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: text));
                          App.rootContext.showMessage(message: "已复制: ${e.$1}");
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(text),
                        ),
                      );
                    }).toList(),
              ),
            );
          },
        ),
      );
    }

    if (isRemoteConnected) {
      final connectedDevice = LanControlClient.instance.connectedDevice;

      menuEntries.add(
        MenuEntry(
          icon: Icons.cast,
          text: t.lanRemoteControl,
          onClick: () {
            if (connectedDevice == null) {
              // 理论上不会发生（isConnected == true 时 connectedDevice 一定有值）
              DebugLog.warning(
                'AnimeTile',
                'isConnected=true 但 connectedDevice=null，不应出现',
              );
              return;
            }

            DebugLog.info(
              'AnimeTile',
              'Cast → ${connectedDevice.name} (${connectedDevice.ip})',
            );

            // 先跳转到遥控页面，由用户在页面内选择操作
            App.rootContext.to(
              () => RemoteControlPage(device: connectedDevice),
            );
            _castAnimeToRemote();
          },
        ),
      );
    }

    if (menuOptions != null) {
      menuEntries.addAll(menuOptions!);
    }

    showMenuX(App.rootContext, location, menuEntries);
  }

  Future<void> _castAnimeToRemote() async {
    final device = LanControlClient.instance.connectedDevice;
    if (device == null || !LanControlClient.instance.isConnected) {
      DebugLog.warning('AnimeTile', '无可用的远程连接');
      return;
    }

    try {
      // 发送 animeAction，让对端打开并播放这部动漫
      await LanControlClient.instance.sendAnimeAction(
        anime.id.toString(),
        anime.sourceKey,
        AnimeActionType.play,
      );
      DebugLog.info('AnimeTile', 'Cast 成功: ${anime.title} → ${device.name}');
    } catch (e) {
      DebugLog.warning('AnimeTile', 'Cast 失败: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = appdata.settings['animeDisplayMode'];

    final isFavorite = appdata.settings['showFavoriteStatusOnTile']
        ? ref.watch(
            favoritesChangedProvider.select(
              (_) => LocalFavoritesManager().isExist(anime.id, _animeType),
            ),
          )
        : false;

    final history = appdata.settings['showHistoryStatusOnTile']
        ? ref.watch(
            historyAllProvider.select(
              (_) => HistoryManager().find(anime.id, _animeType),
            ),
          )
        : null;

    Widget child = type == 'detailed'
        ? _buildDetailedMode(context, ref)
        : _buildBriefMode(context, ref);

    if (!isFavorite && history == null) {
      return child;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Material(color: Colors.transparent, child: child),
        ),
        Positioned(
          left: type == 'detailed' ? 16 : 6,
          top: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              height: 24,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  if (isFavorite && enableFavorite)
                    Container(
                      height: 24,
                      width: 24,
                      color: Colors.redAccent,
                      child: const Icon(
                        Icons.star_rounded,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
                child: Row(
                  children: [
                    if (history != null)
                      Container(
                        height: 24,
                        color: Colors.black.toOpacity(0.5),
                        constraints: const BoxConstraints(minWidth: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${history.lastWatchEpisode} / ${history.allEpisode}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildImage(BuildContext context) {
    var image = _findImageProvider(anime);
    if (anime.cover.isEmpty) return const SizedBox();
    if (image == null) return const SizedBox();

    return AnimatedImage(
      image: image,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildDetailedMode(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constrains) {
        final height = constrains.maxHeight - 16;

        Widget image = Container(
          width: height * 0.68,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
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
          image = Hero(tag: "cover$heroID", child: image);
        }

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onTap(ref),
          onLongPress: enableLongPressed
              ? () => _onLongPressed(context, ref)
              : null,
          onSecondaryTapDown: (detail) => _onSecondaryTap(detail, context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
            child: Row(
              children: [
                image,
                SizedBox.fromSize(size: const Size(16, 5)),
                Expanded(
                  child: _AnimeDescription(
                    title: anime.title.replaceAll("\n", ""),
                    subtitle: anime.subtitle ?? '',
                    description: anime.description,
                    badge: badge ?? anime.language,
                    tags: anime.tags,
                    maxLines: 2,
                    enableTranslate:
                        AnimeSource.find(
                          anime.sourceKey,
                        )?.enableTagsTranslate ??
                        false,
                    rating: anime.stars,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBriefMode(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useMarquee = appdata.settings['tileTitleMarquee'] == true;
          Widget image = Material(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: Colors.black.toOpacity(0.2),
            clipBehavior: Clip.antiAlias,
            child: buildImage(context),
          );

          if (heroID != null) {
            image = Hero(tag: "cover$heroID", child: image);
          }

          final title = anime.title.replaceAll('\n', '');
          const style = TextStyle(fontWeight: FontWeight.w500);

          final textPainter = TextPainter(
            text: TextSpan(text: title, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          final shouldScroll = textPainter.width >= constraints.maxWidth - 20;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTap(ref),
            onLongPress: enableLongPressed
                ? () => _onLongPressed(context, ref)
                : null,
            onSecondaryTapDown: (detail) =>
                _onSecondaryTap(detail, context, ref),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: image),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: (() {
                          final subtitle = anime.subtitle
                              ?.replaceAll('\n', '')
                              .trim();
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

                          if (text == null) return const SizedBox();

                          var children = <Widget>[];
                          for (var line in text.split('\n')) {
                            children.add(
                              Container(
                                margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
                                padding: constraints.maxWidth < 80
                                    ? const EdgeInsets.fromLTRB(3, 1, 3, 1)
                                    : constraints.maxWidth < 150
                                    ? const EdgeInsets.fromLTRB(4, 2, 4, 2)
                                    : const EdgeInsets.fromLTRB(5, 2, 5, 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
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
                              ),
                            );
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
                  child: SizedBox(
                    height: 20,
                    child: ClipRect(
                      child: useMarquee && shouldScroll
                          ? Marquee(
                              text: title,
                              style: style,
                              scrollAxis: Axis.horizontal,
                              blankSpace: 10.0,
                              velocity: 40.0,
                              pauseAfterRound: Duration.zero,
                              accelerationDuration: Duration.zero,
                              decelerationDuration: Duration.zero,
                            )
                          : Text(
                              title,
                              style: style,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ),
              ],
            ).paddingHorizontal(2).paddingVertical(2),
          );
        },
      ),
    );
  }

  List<String> _splitText(String text) {
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

  void block(BuildContext animeTileContext, WidgetRef ref) {
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
        return StatefulBuilder(
          builder: (context, setState) {
            return ContentDialog(
              title: t.block,
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
                    context.showMessage(message: t.blocked);
                    animeTileContext
                        .findAncestorStateOfType<_SliverGridAnimesState>()!
                        .update();
                  },
                  child: Text(t.block),
                ),
              ],
            );
          },
        );
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
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.0),
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
        if (subtitle != "")
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.0,
              color: context.colorScheme.onSurface.toOpacity(0.7),
            ),
            maxLines: 1,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        if (tags != null && tags!.isNotEmpty)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                                : Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(8),
                            ),
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              s.split(':').last,
                              style: const TextStyle(fontSize: 12),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ).toAlign(Alignment.topCenter);
              },
            ),
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
                    style: const TextStyle(fontSize: 12.0),
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
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class SliverGridAnimes extends ConsumerStatefulWidget {
  const SliverGridAnimes({
    super.key,
    required this.animes,
    this.onLastItemBuild,
    this.badgeBuilder,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
    this.selections,
    this.enableFavorite,
    this.enableHistory,
    this.isRecommend,
    this.asSliver = true,
    this.shrinkWrap = false,
    this.crossAxisCount,
    this.horizontal = false,
  });

  final List<Anime> animes;

  final Map<Anime, bool>? selections;

  final void Function()? onLastItemBuild;

  final String? Function(Anime)? badgeBuilder;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final void Function(Anime, int heroID)? onTap;

  final void Function(Anime, int heroID)? onLongPressed;

  final bool? enableFavorite;

  final bool? enableHistory;

  final bool? isRecommend;

  final bool asSliver;

  final bool shrinkWrap;

  final int? crossAxisCount;

  final bool horizontal;

  @override
  ConsumerState<SliverGridAnimes> createState() => _SliverGridAnimesState();
}

class _SliverGridAnimesState extends ConsumerState<SliverGridAnimes> {
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
      asSliver: widget.asSliver,
      shrinkWrap: widget.shrinkWrap,
      crossAxisCount: widget.crossAxisCount,
      horizontal: widget.horizontal,
    );
  }
}

class _SliverGridAnimes extends StatelessWidget {
  const _SliverGridAnimes({
    required this.animes,
    required this.heroIDs,
    this.onLastItemBuild,
    this.badgeBuilder,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
    this.selection,
    this.enableFavorite,
    this.enableHistory,
    this.isRecommend,
    this.asSliver = true,
    this.shrinkWrap = false,
    this.crossAxisCount,
    this.horizontal = false,
  });

  final List<Anime> animes;

  final List<int> heroIDs;

  final Map<Anime, bool>? selection;

  final void Function()? onLastItemBuild;

  final String? Function(Anime)? badgeBuilder;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final void Function(Anime, int heroID)? onTap;

  final void Function(Anime, int heroID)? onLongPressed;

  final bool? enableFavorite;

  final bool? enableHistory;

  final bool? isRecommend;

  final bool asSliver;

  final bool shrinkWrap;

  final int? crossAxisCount;

  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    // 水平布局模式
    if (horizontal) {
      const height = 240.0;
      const aspectRatio = 0.68;
      final width = height * aspectRatio;
      return SliverToBoxAdapter(
        child: SizedBox(
          height: animes.isEmpty ? 0.0 : height,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: animes.length,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            itemBuilder: (context, index) {
              if (index == animes.length - 1) {
                onLastItemBuild?.call();
              }
              var badge = badgeBuilder?.call(animes[index]);
              var isSelected = selection == null
                  ? false
                  : selection![animes[index]] ?? false;
              var anime = AnimeTile(
                anime: animes[index],
                isRecommend: isRecommend ?? false,
                enableFavorite: enableFavorite ?? true,
                enableHistory: enableHistory ?? false,
                badge: badge,
                menuOptions: menuBuilder?.call(animes[index]),
                onTap: onTap != null
                    ? () => onTap!(animes[index], heroIDs[index])
                    : null,
                onLongPressed: onLongPressed != null
                    ? () => onLongPressed!(animes[index], heroIDs[index])
                    : null,
                heroID: heroIDs[index],
              );
              if (selection == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: SizedBox(width: width, height: height, child: anime),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: AnimatedContainer(
                    key: ValueKey(animes[index].id),
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.secondaryContainer.toOpacity(0.72)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(4),
                    child: anime,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    if (asSliver) {
      return SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == animes.length - 1) {
            onLastItemBuild?.call();
          }
          var badge = badgeBuilder?.call(animes[index]);
          var isSelected = selection == null
              ? false
              : selection![animes[index]] ?? false;
          var anime = AnimeTile(
            anime: animes[index],
            isRecommend: isRecommend ?? false,
            enableFavorite: enableFavorite ?? true,
            enableHistory: enableHistory ?? false,
            badge: badge,
            menuOptions: menuBuilder?.call(animes[index]),
            onTap: onTap != null
                ? () => onTap!(animes[index], heroIDs[index])
                : null,
            onLongPressed: onLongPressed != null
                ? () => onLongPressed!(animes[index], heroIDs[index])
                : null,
            heroID: heroIDs[index],
          );
          if (selection == null) return anime;
          return AnimatedContainer(
            key: ValueKey(animes[index].id),
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.toOpacity(0.72)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(4),
            child: anime,
          );
        }, childCount: animes.length),
        gridDelegate: SliverGridDelegateWithAnimes(
          fixedCrossAxisCount: crossAxisCount,
        ),
      );
    } else {
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: animes.length,
        gridDelegate: SliverGridDelegateWithAnimes(
          fixedCrossAxisCount: crossAxisCount,
        ),
        shrinkWrap: shrinkWrap,
        itemBuilder: (context, index) {
          if (index == animes.length - 1) {
            onLastItemBuild?.call();
          }
          var badge = badgeBuilder?.call(animes[index]);
          var isSelected = selection == null
              ? false
              : selection![animes[index]] ?? false;
          var anime = AnimeTile(
            anime: animes[index],
            isRecommend: isRecommend ?? false,
            enableFavorite: enableFavorite ?? true,
            enableHistory: enableHistory ?? false,
            badge: badge,
            menuOptions: menuBuilder?.call(animes[index]),
            onTap: onTap != null
                ? () => onTap!(animes[index], heroIDs[index])
                : null,
            onLongPressed: onLongPressed != null
                ? () => onLongPressed!(animes[index], heroIDs[index])
                : null,
            heroID: heroIDs[index],
          );
          if (selection == null) return anime;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.secondaryContainer.toOpacity(0.72)
                  : null,
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(4),
            child: anime,
          );
        },
      );
    }
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
    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
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

  const RatingWidget({
    super.key,
    this.maxRating = 10.0,
    this.count = 5,
    this.value = 10.0,
    this.size = 20,
    required this.padding,
    this.selectable = false,
    required this.onRatingUpdate,
  });

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

  void pointValue(double dx) {
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
          value =
              (dx - widget.padding * (i - 1)) /
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
      children.add(
        Icon(
          Icons.star,
          size: widget.size,
          color: context.colorScheme.secondary,
        ),
      );
      if (i < widget.count - 1) {
        children.add(SizedBox(width: widget.padding));
      }
    }
    if (full < widget.count) {
      children.add(
        ClipRect(
          clipper: _SMClipper(rating: star() * widget.size),
          child: Icon(
            Icons.star,
            size: widget.size,
            color: context.colorScheme.secondary,
          ),
        ),
      );
    }

    return children;
  }

  List<Widget> buildNormalRow() {
    List<Widget> children = [];
    for (int i = 0; i < widget.count; i++) {
      children.add(
        Icon(
          Icons.star_border,
          size: widget.size,
          color: context.colorScheme.secondary,
        ),
      );
      if (i < widget.count - 1) {
        children.add(SizedBox(width: widget.padding));
      }
    }
    return children;
  }

  Widget buildRowRating() {
    return Stack(
      children: <Widget>[
        Row(children: buildNormalRow()),
        Row(children: buildRow()),
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
  const SimpleAnimeTile({
    super.key,
    required this.anime,
    this.onTap,
    this.withTitle = false,
    this.heroID,
  });

  final Anime anime;

  final void Function()? onTap;

  final bool withTitle;

  final int? heroID;

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
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

    if (heroID != null) {
      child = Hero(tag: "cover$heroID", child: child);
    }

    child = AnimatedTapRegion(
      borderRadius: 12,
      onTap:
          onTap ??
          () {
            context.to(
              () => AnimePage(
                id: anime.id,
                sourceKey: anime.sourceKey,
                cover: anime.cover,
                title: anime.title,
                heroID: heroID,
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
