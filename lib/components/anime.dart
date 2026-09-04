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

/// 每源独立显示模式作用域（探索页按源包裹）。
/// mode 为 null 时使用全局设置（appdata.settings['animeDisplayMode']）。
class AnimeDisplayModeScope extends InheritedWidget {
  const AnimeDisplayModeScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final String? mode;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AnimeDisplayModeScope>()?.mode;

  @override
  bool updateShouldNotify(AnimeDisplayModeScope oldWidget) =>
      mode != oldWidget.mode;
}

/// 每源显示模式覆盖的存储 key（implicitData）。
const String sourceDisplayModesKey = 'animeSourceDisplayModes';

/// 读取某源显示模式覆盖，支持子维度（如 `sourceKey:search`、`sourceKey:category:国漫`）：
/// 子覆盖 > 源级覆盖 > null（跟随全局默认）。
String? sourceDisplayModeOf(String sourceKey, [String? subKey]) {
  final v = appdata.implicitData[sourceDisplayModesKey];
  if (v is! Map) return null;
  if (subKey != null) {
    final sub = v['$sourceKey:$subKey'];
    if (sub is String && sub.isNotEmpty) return sub;
  }
  final root = v[sourceKey];
  return root is String ? root : null;
}

/// 设置某源显示模式覆盖；mode 为 null 清除覆盖（恢复源级/全局默认）。
void setSourceDisplayMode(String sourceKey, String? mode, [String? subKey]) {
  final v = appdata.implicitData[sourceDisplayModesKey];
  final m = Map<String, dynamic>.from(v is Map ? v : <String, dynamic>{});
  final sk = subKey == null ? sourceKey : '$sourceKey:$subKey';
  if (mode == null || mode.isEmpty) {
    m.remove(sk);
  } else {
    m[sk] = mode;
  }
  appdata.implicitData[sourceDisplayModesKey] = m;
  appdata.writeImplicitData();
  App.forceRebuild();
}

/// 二级页面顶部布局切换菜单：可单独覆盖该页面的显示模式，
/// 未覆盖时跟随源级/全局默认。
class AnimeSourceLayoutMenu extends StatelessWidget {
  const AnimeSourceLayoutMenu({
    super.key,
    required this.sourceKey,
    this.subKey,
  });

  final String sourceKey;

  final String? subKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final current =
        sourceDisplayModeOf(sourceKey, subKey) ??
        appdata.settings['animeDisplayMode'];
    final modes = [
      ('brief', t.brief),
      ('detailed', t.detailed),
      ('masonry', t.masonry),
      ('poster', t.poster),
    ];
    return PopupMenuButton<String>(
      tooltip: t.displayModeOfAnimeTile,
      icon: const Icon(Icons.grid_view_outlined),
      onSelected: (v) =>
          setSourceDisplayMode(sourceKey, v == '_default' ? null : v, subKey),
      itemBuilder: (_) => [
        for (final (key, label) in modes)
          PopupMenuItem(
            value: key,
            child: Row(
              children: [
                Icon(
                  key == current ? Icons.check : Icons.circle_outlined,
                  size: 18,
                  color: key == current ? colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: '_default',
          child: Text(subKey != null ? t.followSourceDefault : t.sortByDefault),
        ),
      ],
    );
  }
}

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
    this.heroTag,
    this.masonryFactor,
    this.displayMode,
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

  /// 瀑布流模式：非 null 时封面高度 = 卡片宽 × 系数（错落高度），
  /// null 时用网格模式的等高布局
  final double? masonryFactor;

  /// 显式指定显示模式（brief/detailed/masonry/poster），优先于 scope/全局设置。
  /// 如水平布局强制用简洁卡。
  final String? displayMode;

  /// 唯一 Hero tag（跨列表避免 "multiple heroes share the same tag"）；
  /// 为空时回退 `cover$heroID`
  final String? heroTag;

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
          heroTag: heroTag,
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
          heroTag: heroTag,
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
  void _onLongPressed(BuildContext context, WidgetRef ref, Offset position) {
    if (onLongPressed != null) {
      onLongPressed!();
      return;
    }
    _onLongPress(position, context, ref);
  }

  void _onLongPress(Offset location, BuildContext context, WidgetRef ref) {
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
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(App.rootContext).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
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
                          final displayText = "${e.$1}: ${e.$2}";
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onLongPress: () {
                              final copyValue = e.$2 ?? '';
                              Clipboard.setData(ClipboardData(text: copyValue));
                              App.rootContext.showMessage(
                                message: t.copiedField(x: e.$1),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Text(displayText),
                            ),
                          );
                        }).toList(),
                  ),
                ),
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
    final type =
        displayMode ??
        AnimeDisplayModeScope.of(context) ??
        appdata.settings['animeDisplayMode'];

    final isFavorite = appdata.settings['showFavoriteStatusOnTile']
        ? ref.watch(
            favoritesChangedProvider.select(
              (_) => LocalFavoritesManager().isExist(anime.id, _animeType),
            ),
          )
        : false;

    final history = appdata.settings['showHistoryStatusOnTile']
        ? ref.watch(
            historyAllProvider.select((_) {
              // 只监听集数（稳定字符串）；lastWatchTime 每秒变但无需每秒刷新卡片
              final h = HistoryManager().find(anime.id, _animeType);
              if (h == null) return null;
              return '${h.lastWatchEpisode} / ${h.allEpisode}';
            }),
          )
        : null;

    // 显示模式：详细 / 瀑布流（错落封面）/ 简洁 / 海报（横向宽卡）
    Widget child = switch (type) {
      'detailed' => _buildDetailedMode(context, ref),
      'poster' => _buildPosterMode(context, ref),
      // 瀑布流需要封面高度系数（由瀑布流网格传入）；无系数时回退简洁布局
      'masonry' =>
        masonryFactor != null
            ? _buildMasonryMode(context, ref)
            : _buildBriefMode(context, ref),
      _ => _buildBriefMode(context, ref),
    };

    if (!isFavorite && history == null) {
      return child;
    }

    // 卡片作为非 Positioned 子：Stack 尺寸由卡片决定。
    // 规整网格里有界约束下卡片填满；瀑布流（主轴无界）下 Stack 尺寸 = 卡片内容，
    // 避免 "A Stack requires bounded constraints"
    return Stack(
      children: [
        Material(color: Colors.transparent, child: child),
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
                        history,
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
                          history,
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
      // 以 Ink.image 渲染，使外层 InkWell 的波纹能显示在图片之上
      ink: true,
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
          image = Hero(tag: heroTag ?? "cover$heroID", child: image);
        }

        Offset pressPosition = Offset.zero;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onTap(ref),
          onTapDown: (detail) => pressPosition = detail.globalPosition,
          onLongPress: enableLongPressed
              ? () => _onLongPressed(context, ref, pressPosition)
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

  /// brief 模式：封面右下角的描述覆盖层（描述优先，副标题兜底，逐行徽章展示）。
  /// description 支持 String（`|`/换行）或 List（可携带每行颜色）
  Widget _buildOverlayDescription(BoxConstraints constraints) {
    final lines = _overlayLines();
    if (lines == null) return const SizedBox();

    // 按卡片宽度分级：小卡片更紧凑
    final compact = constraints.maxWidth < 80;
    final small = constraints.maxWidth < 150;
    final fontSize = compact ? 8.0 : (small ? 10.0 : 12.0);
    final padH = compact ? 3.0 : (small ? 4.0 : 5.0);
    final padV = compact ? 1.0 : 2.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (text, color) in lines)
          Container(
            margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
            padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.toOpacity(0.5),
            ),
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
                color: color ?? Colors.white,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// 取覆盖层的行列表 `(文本, 颜色?)`：
  /// 有结构化 descriptionLines 时用它们（支持每行颜色），
  /// 否则从 description 字符串（`|`/换行分隔）解析，副标题兜底
  List<(String, Color?)>? _overlayLines() {
    final structured = anime.descriptionLines;
    if (structured != null && structured.isNotEmpty) {
      return [for (final l in structured) (l.text, _parseColor(l.color))];
    }
    final subtitle = anime.subtitle?.replaceAll('\n', '').trim();
    final text = anime.description.isNotEmpty
        ? anime.description.split('|').join('\n')
        : (subtitle?.isNotEmpty == true ? subtitle : null);
    if (text == null) return null;
    return [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) (line, null),
    ];
  }

  /// 解析颜色：`#RGB` / `#RRGGBB` / `#AARRGGBB` 或常见颜色名
  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    final s = colorStr.trim();
    if (s.startsWith('#')) {
      try {
        var hex = s.substring(1);
        if (hex.length == 3) {
          hex = hex.split('').map((c) => '$c$c').join();
        }
        if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
        if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return null;
      }
    }
    return switch (s.toLowerCase()) {
      'white' => Colors.white,
      'black' => Colors.black,
      'red' => Colors.redAccent,
      'yellow' => Colors.yellow,
      'green' => Colors.greenAccent,
      'orange' => Colors.orangeAccent,
      'cyan' => Colors.cyanAccent,
      'blue' => Colors.blueAccent,
      'purple' => Colors.purpleAccent,
      'pink' => Colors.pinkAccent,
      'grey' || 'gray' => Colors.grey,
      _ => null,
    };
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
            image = Hero(tag: heroTag ?? "cover$heroID", child: image);
          }

          final title = anime.title.replaceAll('\n', '');
          const style = TextStyle(fontWeight: FontWeight.w500);

          final textPainter = TextPainter(
            text: TextSpan(text: title, style: style),
            maxLines: 1,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: constraints.maxWidth);

          final shouldScroll = textPainter.width >= constraints.maxWidth - 20;

          Offset pressPosition = Offset.zero;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTap(ref),
            onTapDown: (detail) => pressPosition = detail.globalPosition,
            onLongPress: enableLongPressed
                ? () => _onLongPressed(context, ref, pressPosition)
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
                        child: _buildOverlayDescription(constraints),
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

  /// 瀑布流模式（独立于 brief/detailed）：封面高度 = 卡片宽 × 系数，错落排列
  Widget _buildMasonryMode(BuildContext context, WidgetRef ref) {
    final factor = masonryFactor!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget image = Material(
            color: context.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: Colors.black.toOpacity(0.2),
            clipBehavior: Clip.antiAlias,
            child: buildImage(context),
          );

          if (heroID != null) {
            image = Hero(tag: heroTag ?? "cover$heroID", child: image);
          }

          final title = anime.title.replaceAll('\n', '');
          const style = TextStyle(fontWeight: FontWeight.w500);

          Offset pressPosition = Offset.zero;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTap(ref),
            onTapDown: (detail) => pressPosition = detail.globalPosition,
            onLongPress: enableLongPressed
                ? () => _onLongPressed(context, ref, pressPosition)
                : null,
            onSecondaryTapDown: (detail) =>
                _onSecondaryTap(detail, context, ref),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: constraints.maxWidth * factor,
                  child: Stack(
                    children: [
                      Positioned.fill(child: image),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: _buildOverlayDescription(constraints),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  // 瀑布流卡片高：标题不限制行数，按内容自然换行完整显示
                  child: Text(title, style: style, textAlign: TextAlign.center),
                ),
              ],
            ).paddingHorizontal(2).paddingVertical(2),
          );
        },
      ),
    );
  }

  /// 海报模式（横向宽卡）：圆角矩形，上半为图片（底部叠加左右信息条），
  /// 下半为标题（最多两行）、作者名、底部左右分开的信息。
  Widget _buildPosterMode(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          Widget image = Material(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            shadowColor: Colors.black.toOpacity(0.2),
            clipBehavior: Clip.antiAlias,
            child: buildImage(context),
          );

          if (heroID != null) {
            image = Hero(tag: heroTag ?? "cover$heroID", child: image);
          }

          final title = anime.title.replaceAll('\n', '');
          final lines = anime.descriptionLines;
          final structured = lines != null && lines.isNotEmpty;
          // 结构化行约定：[0] 时长, [1] 观看数, [2] 过去时间；subtitle = 作者
          final durationText = structured && lines.isNotEmpty
              ? lines[0].text.trim()
              : null;
          final viewsText = structured && lines.length > 1
              ? lines[1].text.trim()
              : null;
          final timeText = structured && lines.length > 2
              ? lines[2].text.trim()
              : null;

          // 作者位：subtitle（结构化时约定为作者），否则 description 首段
          String? authorText = anime.subtitle?.trim();
          if (authorText == null || authorText.isEmpty) {
            if (anime.description.isNotEmpty) {
              authorText = anime.description.split('|').first.trim();
            }
          }

          // 图片底部条：左 = 观看数（降级副标题），右 = 时长（降级徽章/语言）
          final barLeft = viewsText ?? anime.subtitle?.trim();
          final barRight = durationText ?? badge ?? anime.language;

          // 底部行：左 = 点赞率（stars 换算百分比），右 = 过去时间（降级 ★ 评分）
          final hasStars = anime.stars != null && anime.stars! > 0;
          final bottomLeft = hasStars
              ? '↑ ${(anime.stars! / 5 * 100).round()}%'
              : (anime.tags != null && anime.tags!.isNotEmpty
                    ? anime.tags!.first
                    : anime.language);
          final bottomRight =
              timeText ??
              (hasStars ? '★ ${anime.stars!.toStringAsFixed(1)}' : '');

          Offset pressPosition = Offset.zero;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTap(ref),
            onTapDown: (detail) => pressPosition = detail.globalPosition,
            onLongPress: enableLongPressed
                ? () => _onLongPressed(context, ref, pressPosition)
                : null,
            onSecondaryTapDown: (detail) =>
                _onSecondaryTap(detail, context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          // 渐变区更高，底部文字更清晰
                          padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.78),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              if (barLeft != null && barLeft.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    barLeft,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (barRight != null && barRight.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    barRight,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
                  // 标题固定占两行高度（fontSize 13 × height 1.2 × 2 行），
                  // 避免标题行数变化挤压图片空间
                  child: SizedBox(
                    height: 13 * 2 * 1.2,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (authorText != null && authorText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 1, 6, 0),
                    child: Text(
                      authorText,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bottomLeft ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bottomRight.isNotEmpty)
                        Text(
                          bottomRight,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
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
    this.minCrossAxisCount,
    this.horizontal = false,
    this.disableMasonry = false,
    this.controller,
  });

  final List<Anime> animes;

  /// 屏蔽瀑布流：某些容器（如 SliverAnimatedSwitcher 内）与
  /// SliverMasonryGrid 布局不兼容，此时即使全局是瀑布流也回退普通网格
  final bool disableMasonry;

  /// 非 sliver 网格的滚动控制器（如收藏页按 tab 提供，让外层滚动条可驱动）
  final ScrollController? controller;

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

  /// 最小列数（自适应时至少显示这么多列）
  final int? minCrossAxisCount;

  final bool horizontal;

  @override
  ConsumerState<SliverGridAnimes> createState() => _SliverGridAnimesState();
}

/// 瀑布流网格：卡片封面高度按系数错落（探索页等使用）。
/// 封面采用 brief 卡片样式，标题在底部，卡片高度 = 宽 × 系数
class SliverMasonryAnimes extends ConsumerStatefulWidget {
  const SliverMasonryAnimes({
    super.key,
    required this.animes,
    this.columns,
    this.isRecommend = false,
    this.enableFavorite = true,
    this.enableHistory = false,
    this.badgeBuilder,
    this.menuBuilder,
    this.onTap,
    this.onLongPressed,
    this.onLastItemBuild,
    this.selection,
  });

  /// 选中集合（多选模式），与普通网格一致：命中的卡片高亮背景
  final Map<Anime, bool>? selection;

  final List<Anime> animes;

  /// 固定列数（null 时按屏幕宽度自适应）
  final int? columns;

  final bool isRecommend;

  final bool enableFavorite;

  final bool enableHistory;

  final String? Function(Anime)? badgeBuilder;

  final List<MenuEntry> Function(Anime)? menuBuilder;

  final void Function(Anime, int heroID)? onTap;

  final void Function(Anime, int heroID)? onLongPressed;

  /// 触底加载回调：瀑布流滑到最后一个 item 构建时触发
  final void Function()? onLastItemBuild;

  static int _heroSeedCounter = 0;

  @override
  ConsumerState<SliverMasonryAnimes> createState() =>
      _SliverMasonryAnimesState();
}

class _SliverMasonryAnimesState extends ConsumerState<SliverMasonryAnimes> {
  /// 本列表实例的 Hero 唯一种子，避免同路由多个列表 Hero tag 冲突
  late final int _heroSeed = SliverMasonryAnimes._heroSeedCounter++;

  @override
  Widget build(BuildContext context) {
    final animes = widget.animes;
    final count = widget.columns ?? _resolveColumns(context);
    return SliverMasonryGrid.count(
      crossAxisCount: count,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childCount: animes.length,
      itemBuilder: (context, index) {
        if (index == animes.length - 1) {
          widget.onLastItemBuild?.call();
        }
        final anime = animes[index];
        final isSelected = widget.selection == null
            ? false
            : (widget.selection![anime] ?? false);
        Widget card = AnimeTile(
          anime: anime,
          isRecommend: widget.isRecommend,
          enableFavorite: widget.enableFavorite,
          enableHistory: widget.enableHistory,
          badge: widget.badgeBuilder?.call(anime),
          menuOptions: widget.menuBuilder?.call(anime),
          onTap: widget.onTap == null
              ? null
              : () => widget.onTap!(anime, _SliverGridAnimes.heroIDOf(anime)),
          onLongPressed: widget.onLongPressed == null
              ? null
              : () =>
                    widget.onLongPressed!(anime, _SliverGridAnimes.heroIDOf(anime)),
          heroID: _SliverGridAnimes.heroIDOf(anime),
          heroTag: "cover${_heroSeed}_h${_SliverGridAnimes.heroIDOf(anime)}",
          // 统一封面比例（与简洁布局接近，不再错落排列），
          // 避免瀑布流图片高低参差
          masonryFactor: 1.35,
        );
        if (widget.selection == null) return card;
        return AnimatedContainer(
          key: ValueKey(anime.id),
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.secondaryContainer.toOpacity(
                    0.72,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: card,
        );
      },
    );
  }

  int _resolveColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // 按每列最小宽度动态计算：窄屏少列，宽屏多列
    const minColWidth = 140.0;
    final cols = (width / minColWidth).floor();
    return cols.clamp(2, 6);
  }
}

class _SliverGridAnimesState extends ConsumerState<SliverGridAnimes> {
  List<Anime> animes = [];

  static int _nextHeroSeed = 0;

  /// 本列表实例的 Hero 唯一种子，避免同路由多个列表 Hero tag 冲突
  late final int _heroSeed = _nextHeroSeed++;

  /// 过滤屏蔽项并按 Hero 标识去重（同 id@sourceKey 只保留首个），
  /// 避免同一路由出现重复 Hero tag 导致 "multiple heroes share the same tag"
  List<Anime> _buildAnimes() {
    final seen = <int>{};
    final result = <Anime>[];
    for (var anime in widget.animes) {
      if (isBlocked(anime) != null) continue;
      final hero = _SliverGridAnimes.heroIDOf(anime);
      if (!seen.add(hero)) continue;
      result.add(anime);
    }
    return result;
  }

  @override
  void didUpdateWidget(covariant SliverGridAnimes oldWidget) {
    if (!oldWidget.animes.isEqualTo(widget.animes)) {
      animes = _buildAnimes();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    animes = _buildAnimes();
    super.initState();
  }

  /// 仅由"屏蔽"等低频操作调用刷新列表；不再监听 HistoryManager
  void update() {
    setState(() {
      animes = _buildAnimes();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode =
        AnimeDisplayModeScope.of(context) ??
        appdata.settings['animeDisplayMode'];
    // 瀑布流模式：sliver 场景委托瀑布流网格（错落封面）
    if (widget.asSliver &&
        !widget.horizontal &&
        !widget.disableMasonry &&
        mode == 'masonry') {
      // 列表排序/数据变化时用签名 key 强制重建瀑布流布局缓存，
      // 避免 SliverMasonryGrid 复用过期的行列估算导致空白/单列错乱
      final sig = animes
          .map((a) => _SliverGridAnimes.heroIDOf(a))
          .fold<int>(0, (acc, id) => acc ^ (id * 31 + 7) & 0x7fffffff);
      return SliverMasonryAnimes(
        key: ValueKey('masonry-$sig'),
        animes: animes,
        isRecommend: widget.isRecommend ?? false,
        enableFavorite: widget.enableFavorite ?? true,
        enableHistory: widget.enableHistory ?? false,
        badgeBuilder: widget.badgeBuilder,
        menuBuilder: widget.menuBuilder,
        selection: widget.selections,
        onTap: widget.onTap,
        onLongPressed: widget.onLongPressed,
        onLastItemBuild: widget.onLastItemBuild,
      );
    }
    return _SliverGridAnimes(
      animes: animes,
      heroSeed: _heroSeed,
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
      minCrossAxisCount: widget.minCrossAxisCount,
      horizontal: widget.horizontal,
      displayMode: mode,
      controller: widget.controller,
    );
  }
}

class _SliverGridAnimes extends StatelessWidget {
  /// 稳定 Hero 标识（id@sourceKey），与详情页/源页一致，实时计算避免首帧时序问题
  static int heroIDOf(Anime a) =>
      '${a.id}@${a.sourceKey}'.hashCode & 0x7fffffff;

  const _SliverGridAnimes({
    required this.animes,
    required this.heroSeed,
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
    this.minCrossAxisCount,
    this.horizontal = false,
    this.displayMode,
    this.controller,
  });

  final List<Anime> animes;

  /// 列表实例唯一种子（避免同路由多个列表 Hero tag 冲突）
  final int heroSeed;

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

  final int? minCrossAxisCount;

  final bool horizontal;

  /// 显示模式（brief/detailed/masonry），null 时用全局设置
  final String? displayMode;

  /// 非 sliver 网格的滚动控制器（外层滚动条/滚到顶部驱动用）
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    // 水平布局模式
    if (horizontal) {
      const height = 240.0;
      // 按显示模式决定横向卡片宽度：
      // brief/masonry 竖卡，detailed 宽卡，poster 横卡
      final mode = displayMode;
      final double width = switch (mode) {
        'detailed' => 380.0,
        'poster' => height * 1.25,
        _ => height * 0.68,
      };
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
                displayMode: mode,
                onTap: onTap != null
                    ? () => onTap!(
                        animes[index],
                        _SliverGridAnimes.heroIDOf(animes[index]),
                      )
                    : null,
                onLongPressed: onLongPressed != null
                    ? () => onLongPressed!(
                        animes[index],
                        _SliverGridAnimes.heroIDOf(animes[index]),
                      )
                    : null,
                heroID: _SliverGridAnimes.heroIDOf(animes[index]),
                // 用列表实例种子（而非索引），避免多个水平列表 hero tag 冲突
                heroTag:
                    "cover${_SliverGridAnimes.heroIDOf(animes[index])}_$heroSeed",
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
                ? () => onTap!(
                    animes[index],
                    _SliverGridAnimes.heroIDOf(animes[index]),
                  )
                : null,
            onLongPressed: onLongPressed != null
                ? () => onLongPressed!(
                    animes[index],
                    _SliverGridAnimes.heroIDOf(animes[index]),
                  )
                : null,
            heroID: _SliverGridAnimes.heroIDOf(animes[index]),
            heroTag:
                "cover${_SliverGridAnimes.heroIDOf(animes[index])}_$heroSeed",
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
          minCrossAxisCount: minCrossAxisCount,
          displayMode: displayMode,
        ),
      );
    } else {
      return GridView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        controller: controller,
        itemCount: animes.length,
        gridDelegate: SliverGridDelegateWithAnimes(
          fixedCrossAxisCount: crossAxisCount,
          minCrossAxisCount: minCrossAxisCount,
          displayMode: displayMode,
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
                ? () => onTap!(
                    animes[index],
                    _SliverGridAnimes.heroIDOf(animes[index]),
                  )
                : null,
            onLongPressed: onLongPressed != null
                ? () => onLongPressed!(
                    animes[index],
                    _SliverGridAnimes.heroIDOf(animes[index]),
                  )
                : null,
            heroID: _SliverGridAnimes.heroIDOf(animes[index]),
            heroTag:
                "cover${_SliverGridAnimes.heroIDOf(animes[index])}_$heroSeed",
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
