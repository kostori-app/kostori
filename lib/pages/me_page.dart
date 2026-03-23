import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:kostori/pages/ai_hub/ai_hub_page.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/image_manipulation_page/image_manipulation_page.dart';
import 'package:kostori/pages/stats/stats_page.dart';
import 'package:kostori/utils/data_sync.dart';
import 'package:kostori/utils/translations.dart';
import 'package:sliver_tools/sliver_tools.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
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
    Widget widget = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        const _SyncDataWidget(),
        const QrClipboardWidget(),
        const TodayRecommendation(),
        const _ImageManipulation(),
        const AiHubEntry(),
        const _StatsViewPage(),
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

    // 滚动条封装
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

class _SyncDataWidgetState extends ConsumerState<_SyncDataWidget>
    with WidgetsBindingObserver {
  late DateTime lastCheck;

  @override
  void initState() {
    super.initState();
    DataSync().addListener(_update);
    WidgetsBinding.instance.addObserver(this);
    lastCheck = DateTime.now();
  }

  @override
  void dispose() {
    DataSync().removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(lastCheck) > const Duration(minutes: 10)) {
        lastCheck = DateTime.now();
        DataSync().downloadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!DataSync().isEnabled) {
      child = const SliverPadding(padding: EdgeInsets.zero);
    } else if (DataSync().isUploading || DataSync().isDownloading) {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.primary),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Syncing Data'.tl),
            trailing: const CircularProgressIndicator(
              strokeWidth: 2,
            ).fixWidth(18).fixHeight(18),
          ),
        ),
      );
    } else {
      child = SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Sync Data'.tl),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (DataSync().lastError != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      showDialogMessage(
                        App.rootContext,
                        "Error".tl,
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
                          Text('Error'.tl, style: ts.s12),
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
    final doingFolder = appdata.settings['FavoriteTypeDoing'] ?? 'none';

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
                  Text('Today Recommendation'.tl, style: ts.s16),
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

      appdata.implicitData['today_recommendation_ids'] = result
          .map((a) => '${a.id}|${a.type.value}')
          .toList();
      appdata.implicitData['today_recommendation_date'] = today;
      appdata.writeImplicitData();

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
                    Center(child: Text('Image Operations'.tl, style: ts.s16)),
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
