import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/grid_speed_dial.dart';
import 'package:kostori/components/qr_clipboard_widget.dart';
import 'package:kostori/components/ui_components.dart';
import 'package:kostori/database/favorites.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/ai_hub/ai_hub_page.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/anime_recognize_page.dart';
import 'package:kostori/pages/hub/hub_page.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/lan_discovery_page.dart';
import 'package:kostori/pages/me_page_plugins.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/stats/stats_page.dart';
import 'package:kostori/pages/video_test_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/utils.dart';
import 'package:sliver_tools/sliver_tools.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 已加入一起看房间：个人页显示浮动按钮打开当前番剧
    final hubState = ref.watch(hubProvider);
    final watchRoom = hubState.currentRoom;
    final inWatchRoom =
        hubState.isConnected &&
        watchRoom != null &&
        watchRoom.roomId != hubState.lobbyRoomId &&
        watchRoom.isWatchRoom &&
        watchRoom.animeId != null &&
        watchRoom.animeSourceKey != null;

    Widget widget = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        const _SyncDataWidget(),
        const QrClipboardWidget(),
        const _ToolEntryGrid(),
        const TodayRecommendation(),
        const _ImageManipulation(),
        const _StatsViewPage(),
        const MePagePluginModules(),
        SliverPadding(
          padding: EdgeInsets.only(top: context.padding.bottom + 56),
        ),
      ],
    );

    widget = Stack(
      children: [
        Positioned.fill(child: widget),
        Positioned(
          bottom: 10,
          right: 10,
          child: FloatingMenu(
            controller: scrollController,
            child: [
              [
                // 已加入一起看：快速跳转到当前一起看房间绑定的播放器页
                if (inWatchRoom)
                  SpeedDialChild(
                    child: const Icon(Icons.play_circle_outline),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
                    onTap: () {
                      context.to(
                        () => AnimePage(
                          id: watchRoom.animeId!,
                          sourceKey: watchRoom.animeSourceKey!,
                          cover: watchRoom.animeCover,
                          title: watchRoom.animeTitle,
                        ),
                      );
                    },
                  ),
                SpeedDialChild(
                  child: const Icon(Icons.vertical_align_top),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer,
                  onTap: () => scrollToTop(),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    widget = AppScrollBar(
      topPadding: 56,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: widget,
      ),
    );

    // 横向间距适配
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

class _SyncDataWidget extends ConsumerStatefulWidget {
  const _SyncDataWidget();

  @override
  ConsumerState<_SyncDataWidget> createState() => _SyncDataWidgetState();
}

class _SyncDataWidgetState extends ConsumerState<_SyncDataWidget> {
  @override
  void initState() {
    super.initState();
    DataSync().addListener(_update);
  }

  @override
  void dispose() {
    DataSync().removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget child;
    if (!DataSync().isEnabled) {
      child = const SliverPadding(padding: EdgeInsets.zero);
    } else if (DataSync().isUploading || DataSync().isDownloading) {
      final progress = DataSync().progress;
      final isUpload = DataSync().isUploading;
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant, width: 0.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.sync),
                title: Text(t.syncingData),
                subtitle: Text(
                  isUpload ? t.uploading : t.downloading,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                trailing: progress != null
                    ? Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : const CircularProgressIndicator(
                        strokeWidth: 2,
                      ).fixWidth(18).fixHeight(18),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant, width: 0.6),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text(t.syncData),
            subtitle: DataSync().lastSyncTime != null
                ? Text(
                    '${t.lastSyncTime}: ${Utils.dateFormat(DataSync().lastSyncTime!.millisecondsSinceEpoch)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (DataSync().lastError != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      showDialogMessage(
                        App.rootContext,
                        t.error,
                        DataSync().lastError!,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(t.error, style: ts.s12),
                        ],
                      ),
                    ),
                  ).paddingRight(4),
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  onPressed: () async {
                    DataSync().uploadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  onPressed: () async {
                    DataSync().downloadData();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverAnimatedPaintExtent(
      duration: const Duration(milliseconds: 200),
      child: child,
    );
  }
}

class TodayRecommendation extends StatelessWidget {
  const TodayRecommendation({super.key});

  @override
  Widget build(BuildContext context) {
    final doingFolder = appdata.settings.s.favoriteTypeDoing;

    if (doingFolder == 'none' ||
        doingFolder.isEmpty ||
        !LocalFavoritesManager().existsFolder(doingFolder)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final animes = LocalFavoritesManager().getAllAnimes(doingFolder);
    if (animes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final recommendations = _getRecommendations(animes);
    final cs = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant, width: 0.6),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(t.todayRecommendation, style: ts.s16),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${recommendations.length}', style: ts.s12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (recommendations.isEmpty)
              const SizedBox(height: 220)
            else
              Container(
                height: 220,
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double totalWidth = constraints.maxWidth;
                    int centerCount;
                    if (totalWidth < 480) {
                      centerCount = 1;
                    } else if (totalWidth < 800) {
                      centerCount = 2;
                    } else if (totalWidth < 1200) {
                      centerCount = 3;
                    } else if (totalWidth < 1600) {
                      centerCount = 4;
                    } else {
                      centerCount = 5;
                    }
                    final double sidePeekWidth = totalWidth < 480 ? 40.0 : 56.0;
                    final double calculatedItemExtent =
                        (totalWidth - (sidePeekWidth * 2)) / centerCount;

                    return CarouselView(
                      itemExtent: calculatedItemExtent,
                      shrinkExtent: sidePeekWidth,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      itemSnapping: true,
                      onTap: (index) {
                        final anime = recommendations[index];
                        context.to(
                          () => AnimePage(
                            id: anime.id,
                            sourceKey: anime.sourceKey,
                          ),
                        );
                      },
                      children: recommendations
                          .map((anime) => _TodayRecCard(anime: anime))
                          .toList(),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<FavoriteItem> _getRecommendations(List<FavoriteItem> animes) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final savedDate =
        appdata.implicitData['today_recommendation_date'] as String?;
    final savedIds =
        appdata.implicitData['today_recommendation_ids'] as List<dynamic>?;

    if (savedDate != today || savedIds == null) {
      final count = animes.length.clamp(1, 10);
      final shuffled = List<FavoriteItem>.from(animes)..shuffle();

      final result = shuffled.take(count).toList();

      // 写入会触发 implicitVersion 通知，不能在 build 阶段执行；
      // 延迟到本帧结束后写盘，避免 "setState called during build"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appdata.implicitData['today_recommendation_ids'] = result
            .map((a) => '${a.id}|${a.type.value}')
            .toList();
        appdata.implicitData['today_recommendation_date'] = today;
        appdata.writeImplicitData();
      });

      return result;
    }

    return savedIds.map((saved) {
      final parts = (saved as String).split('|');
      if (parts.length != 2) return animes.first;

      final id = parts[0];
      final type = int.tryParse(parts[1]);

      return animes.firstWhere(
        (a) => a.id == id && a.type.value == type,
        orElse: () => animes.first,
      );
    }).toList();
  }
}

class _TodayRecCard extends StatelessWidget {
  final FavoriteItem anime;

  const _TodayRecCard({required this.anime});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedImage(
            image: CachedImageProvider(anime.cover, sourceKey: anime.sourceKey),
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            filterQuality: FilterQuality.high,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(0, 0.3),
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withAlpha(204)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Text(
            anime.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ts.s12.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// IconTile: reusable small icon-row tile with optional subtitle
class IconTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const IconTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: cs.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ts.s16),
                  if (subtitle != null)
                    Text(subtitle!, style: ts.s12.copyWith(color: cs.outline)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.outline),
          ],
        ),
      ),
    );
  }
}

class _ToolEntryGrid extends ConsumerWidget {
  const _ToolEntryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final settingKey = 'debugInfo';
    bool enabled = appdata.settings[settingKey] as bool? ?? false;
    final connected = ref.watch(hubProvider).isConnected;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // stretch 让 Wrap 撑满宽度，实现内部左对齐（默认 center 会把整行居中）
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.dashboard, color: cs.primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t.aggregationEntry, style: ts.s16)),
                  // 连接服务器快捷入口（聚合入口右侧）
                  TextButton.icon(
                    onPressed: () =>
                        showPopUpWidget(context, const HubClientDetailPage()),
                    icon: Icon(
                      connected ? Icons.link : Icons.link_off,
                      size: 16,
                      color: connected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    label: Text(t.connectToHub),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // 左对齐 Wrap：按内容尺寸紧凑排列，自动换行
              child: Wrap(
                spacing: 28,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: [
                  _iconBlock(
                    context,
                    Icons.extension,
                    () => context.to(() => const AiHubPage()),
                    t.aiLabel,
                  ),
                  _iconBlock(
                    context,
                    Icons.translate,
                    () => context.to(() => const ManualTranslationPage()),
                    t.translation,
                  ),
                  _iconBlock(
                    context,
                    Icons.image_search,
                    () => context.to(() => const AnimeRecognizePage()),
                    t.animeRecognize,
                  ),
                  _iconBlock(
                    context,
                    Icons.wifi_find,
                    () => context.to(() => const LanDiscoveryPage()),
                    t.lanLabel,
                  ),
                  // 已连接服务器时显示聊天室快捷入口（聚合入口内）
                  if (connected)
                    _iconBlock(
                      context,
                      Icons.chat_bubble_outline,
                      () => showHubDialog(context),
                      t.chatRoom,
                    ),
                  if (kDebugMode || enabled)
                    _iconBlock(
                      context,
                      Icons.play_circle_outline_rounded,
                      () => context.to(() => const VideoTestPage()),
                      t.videoTestLabel,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _iconBlock(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
    String label,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: Icon(icon), color: cs.primary, onPressed: onTap),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ImageManipulation extends ConsumerStatefulWidget {
  const _ImageManipulation();

  @override
  ConsumerState<_ImageManipulation> createState() => _ImageManipulationState();
}

class _ImageManipulationState extends ConsumerState<_ImageManipulation> {
  bool _isLoadingImages = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadImagesIfNeeded);
  }

  Future<void> _loadImagesIfNeeded() async {
    if (_isLoadingImages) return;
    final images = ref.read(imagesProvider);
    if (images.isEmpty) {
      _isLoadingImages = true;
      await ref.read(imagesProvider.notifier).loadImages();
      if (mounted) {
        setState(() => _isLoadingImages = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(imagesProvider);
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.to(() => ImageManipulationPage(initialImages: images));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    Icon(Icons.browse_gallery, color: cs.primary, size: 20),
                    const SizedBox(width: 8),
                    Center(child: Text(t.imageOperations, style: ts.s16)),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${images.length}', style: ts.s12),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_month),
                    const SizedBox(width: 10),
                  ],
                ),
              ).paddingHorizontal(16),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SizedBox(
                height: 220,
                child: _isLoadingImages && images.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          scrollbars: true,
                          dragDevices: {
                            ui.PointerDeviceKind.touch,
                            ui.PointerDeviceKind.mouse,
                            ui.PointerDeviceKind.stylus,
                            ui.PointerDeviceKind.trackpad,
                          },
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.isEmpty
                              ? 0
                              : (images.length > 10 ? 10 : images.length),
                          itemBuilder: (context, index) {
                            final file = images[index];
                            final filename = file.path
                                .split(Platform.pathSeparator)
                                .last;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                clipBehavior: Clip.antiAlias,
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    BangumiWidget.showImagePreview(
                                      context: context,
                                      url: file.path,
                                      title: filename,
                                      heroTag: filename,
                                      allUrls: images,
                                      initialIndex: index,
                                    );
                                  },
                                  child: SizedBox(
                                    width: 200 * (4 / 3),
                                    height: 200,
                                    child: Hero(
                                      tag: filename,
                                      flightShuttleBuilder:
                                          (
                                            flightContext,
                                            animation,
                                            direction,
                                            fromContext,
                                            toContext,
                                          ) {
                                            return direction ==
                                                    HeroFlightDirection.pop
                                                ? (fromContext.widget as Hero)
                                                      .child
                                                : (toContext.widget as Hero)
                                                      .child;
                                          },
                                      child: Image.file(
                                        file,
                                        fit: BoxFit.cover,
                                        cacheWidth: 400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ).paddingVertical(16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsViewPage extends StatelessWidget {
  const _StatsViewPage();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: StatsViewPage());
  }
}
