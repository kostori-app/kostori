import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sliver_tools/sliver_tools.dart';

import '../components/components.dart';
import '../foundation/consts.dart';
import '../foundation/log.dart';
import '../utils/data_sync.dart';
import '../utils/io.dart';
import 'image_manipulation_page/image_manipulation_page.dart';

class MePage extends StatefulWidget {
  const MePage({super.key});

  @override
  State<MePage> createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  @override
  Widget build(BuildContext context) {
    var widget = SmoothCustomScrollView(slivers: [
      SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
      const _SyncDataWidget(),
      const _ImageManipulation(),
    ]);
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

class _SyncDataWidget extends StatefulWidget {
  const _SyncDataWidget();

  @override
  State<_SyncDataWidget> createState() => _SyncDataWidgetState();
}

class _SyncDataWidgetState extends State<_SyncDataWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    DataSync().addListener(update);
    WidgetsBinding.instance.addObserver(this);
    lastCheck = DateTime.now();
  }

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    DataSync().removeListener(update);
    WidgetsBinding.instance.removeObserver(this);
  }

  late DateTime lastCheck;

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
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: const Icon(Icons.sync),
            title: Text('Syncing Data'.tl),
            trailing: const CircularProgressIndicator(strokeWidth: 2)
                .fixWidth(18)
                .fixHeight(18),
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

class _ImageManipulation extends ConsumerStatefulWidget {
  const _ImageManipulation();

  @override
  ConsumerState<_ImageManipulation> createState() => _ImageManipulationState();
}

class _ImageManipulationState extends ConsumerState<_ImageManipulation> {
  @override
  void initState() {
    super.initState();
    // 延迟执行避免在构建期间修改provider
    Future.microtask(() async {
      final files = await loadKostoriImages();
      ref.read(imagesProvider.notifier).setImages(files);
    });
  }

  Future<List<File>> loadKostoriImages() async {
    Directory directory;

    if (App.isAndroid) {
      directory = (await KostoriFolder.checkPermissionAndPrepareFolder())!;
    } else {
      final folderDirectory = await getApplicationDocumentsDirectory();
      final folderPath = '${folderDirectory.path}/Kostori';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
        Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
      }
      directory = folder;
    }

    if (!await directory.exists()) {
      return [];
    }

    final files =
        directory.listSync(recursive: false).whereType<File>().where((file) {
      final ext = file.path.toLowerCase();
      return ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.webp') ||
          ext.endsWith('.gif');
    }).toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    return files;
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(imagesProvider);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.to(() => ImageManipulationPage(
                  initialImages: images,
                ));
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  Center(
                    child: Text('图片操作'.tl, style: ts.s18),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
            SizedBox(
              height: 384,
              child: ScrollConfiguration(
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
                  itemCount: images.length > 10 ? 10 : images.length,
                  itemBuilder: (context, index) {
                    final file = images[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Card(
                        margin: const EdgeInsets.all(8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            BangumiWidget.showImagePreview(
                                context,
                                file.path,
                                App.isAndroid
                                    ? file.path.split('/').last
                                    : file.path.split('\\').last,
                                App.isAndroid
                                    ? file.path.split('/').last
                                    : file.path.split('\\').last,
                                allUrls: images,
                                initialIndex: index);
                            // provider管理，不用调用loadImages
                          },
                          child: SizedBox(
                            width: 300 * 1.8,
                            height: 300,
                            child: Hero(
                                tag: App.isAndroid
                                    ? file.path.split('/').last
                                    : file.path.split('\\').last,
                                child: Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                )),
                          ),
                        ),
                      ),
                    );
                  },
                ).paddingHorizontal(8).paddingVertical(16),
              ),
            )
          ]),
        ),
      ),
    );
  }
}
