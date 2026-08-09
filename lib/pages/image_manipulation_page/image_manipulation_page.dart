library;

import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/animated.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/utils/io.dart';
import 'package:path_provider/path_provider.dart';

part 'render_dialogue_compose_page.dart';

part 'render_horizontal_pic_page.dart';

part 'render_long_pic_page.dart';

final imagesProvider = StateNotifierProvider<ImagesNotifier, List<File>>((ref) {
  return ImagesNotifier();
});

final showOuterBorderProvider = StateProvider<bool>((ref) => false);
final outerBorderColorProvider = StateProvider<Color>(
  (ref) => Color(0xFF6677ff),
);
final outerBorderWidthProvider = StateProvider<double>((ref) => 20.0);
final outerBorderRadiusProvider = StateProvider<double>((ref) => 20.0);
final bottomCropHeightProvider = StateProvider<double>((ref) => 60.0);
final showInnerBordersProvider = StateProvider<bool>((ref) => false);
final innerBorderColorProvider = StateProvider<Color>(
  (ref) => Color(0xFF6677ff),
);
final innerBorderWidthProvider = StateProvider<double>((ref) => 20.0);

class ImagesNotifier extends StateNotifier<List<File>> {
  ImagesNotifier() : super([]);

  void setImages(List<File> imgs) => state = imgs;

  /// 从图片操作列表移除指定文件（磁盘已删除后调用，立即反馈）
  void removeFile(File file) {
    final newList = [...state]..removeWhere((f) => f.path == file.path);
    if (newList.length != state.length) {
      state = newList;
    }
  }

  Future<void> loadImages() async {
    final files = await loadKostoriImages();
    state = files;
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
        Log.info('创建截图文件夹成功', folderPath);
      }
      directory = folder;
    }

    if (!await directory.exists()) {
      return [];
    }

    final List<File> files = [];
    await for (final entity in directory.list()) {
      if (entity is File) {
        final ext = entity.path.toLowerCase();
        if (ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.png') ||
            ext.endsWith('.webp') ||
            ext.endsWith('.gif')) {
          files.add(entity);
        }
      }
    }

    final fileModTimes = await Future.wait(
      files.map((f) => f.lastModified().then((t) => MapEntry(f, t))),
    );
    fileModTimes.sort((a, b) => b.value.compareTo(a.value));

    return fileModTimes.map((e) => e.key).toList();
  }

  void deleteIndexes(List<int> indexes) {
    final newList = [...state];

    indexes.sort((a, b) => b.compareTo(a));
    for (var i in indexes) {
      try {
        newList[i].deleteSync();
        newList.removeAt(i);
      } catch (e) {
        Log.error('deleteIndexes', e.toString());
      }
    }
    state = newList;
  }
}

final multiSelectModeProvider = StateProvider<bool>((ref) => false);
final selectedIndexesProvider = StateProvider<Set<int>>((ref) => {});
final lastSelectedIndexProvider = StateProvider<int?>((ref) => null);

class ImageManipulationPage extends StatelessWidget {
  final List<File>? initialImages;

  const ImageManipulationPage({this.initialImages, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ImageManipulationBody(initialImages: initialImages));
  }
}

/// 可嵌入的图片操作内容：主页 / 番剧详情页 Tab 均复用此实现。
/// [embedded] 为 true 时不渲染返回按钮，用于嵌入到 Tab 等已有导航结构中。
class ImageManipulationBody extends ConsumerStatefulWidget {
  final List<File>? initialImages;
  final bool embedded;

  const ImageManipulationBody({
    this.initialImages,
    this.embedded = false,
    super.key,
  });

  @override
  ConsumerState<ImageManipulationBody> createState() =>
      _ImageManipulationBodyState();
}

class _ImageManipulationBodyState extends ConsumerState<ImageManipulationBody> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(imagesProvider.notifier);
      if (widget.initialImages != null) {
        notifier.setImages(widget.initialImages!);
      } else {
        await notifier.loadImages();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTapImage(int index) {
    final multiSelect = ref.read(multiSelectModeProvider);
    if (multiSelect) {
      final selected = Set<int>.from(ref.read(selectedIndexesProvider));
      if (selected.contains(index)) {
        selected.remove(index);
        if (selected.isEmpty) {
          ref.read(multiSelectModeProvider.notifier).state = false;
        }
      } else {
        selected.add(index);
      }
      ref.read(selectedIndexesProvider.notifier).state = selected;
    } else {
      final images = ref.read(imagesProvider);
      final file = images[index];
      final filename = file.path.split(Platform.pathSeparator).last;
      BangumiWidget.showImagePreview(
        context: context,
        url: file.path,
        title: filename,
        heroTag: filename,
        allUrls: images,
        initialIndex: index,
      );
    }
  }

  void _onLongPressImage(int index) {
    final isMulti = ref.read(multiSelectModeProvider);
    final selected = ref.read(selectedIndexesProvider);
    final lastIndex = ref.read(lastSelectedIndexProvider);

    if (!isMulti) {
      ref.read(multiSelectModeProvider.notifier).state = true;
      ref.read(selectedIndexesProvider.notifier).state = {index};
      ref.read(lastSelectedIndexProvider.notifier).state = index;
    } else {
      if (lastIndex != null) {
        final selectedSet = Set<int>.from(selected);
        int start = lastIndex;
        int end = index;
        if (start > end) {
          final temp = start;
          start = end;
          end = temp;
        }

        for (int i = start; i <= end; i++) {
          if (selectedSet.contains(i)) {
            selectedSet.remove(i);
          } else {
            selectedSet.add(i);
          }
        }
        if (selectedSet.isEmpty) {
          ref.read(multiSelectModeProvider.notifier).state = false;
        }

        ref.read(selectedIndexesProvider.notifier).state = selectedSet;
      }

      ref.read(lastSelectedIndexProvider.notifier).state = index;
    }
  }

  void _deleteSelected() {
    final selected = ref.read(selectedIndexesProvider).toList();
    ref.read(imagesProvider.notifier).deleteIndexes(selected);
    ref.read(selectedIndexesProvider.notifier).state = {};
    ref.read(multiSelectModeProvider.notifier).state = false;
  }

  /// 从设备导入图片到 Kostori 截图文件夹，随后刷新列表
  Future<void> _importImages() async {
    try {
      final folderPath = await ImageSaver.resolveFolderPath();
      if (folderPath == null) {
        App.rootContext.showMessage(
          message: t.failedToPickImage,
          level: LogLevel.warning,
        );
        return;
      }
      var imported = 0;
      if (App.isDesktop) {
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty) return;
        for (final f in result.files) {
          final bytes = await f.readAsBytes();
          await File('$folderPath/${f.name}').writeAsBytes(bytes);
          imported++;
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickMultiImage(imageQuality: 90);
        for (final f in picked) {
          final bytes = await f.readAsBytes();
          final name = '${DateTime.now().millisecondsSinceEpoch}_${f.name}';
          await File('$folderPath/$name').writeAsBytes(bytes);
          imported++;
        }
      }
      if (imported == 0) return;
      await ref.read(imagesProvider.notifier).loadImages();
      App.rootContext.showMessage(message: t.importedCountI(i: imported));
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.failedToPickImage}: $e',
        level: LogLevel.warning,
      );
    }
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final images = ref.watch(imagesProvider);
    final selectedIndexes = ref.watch(selectedIndexesProvider);

    if (images.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: App.isAndroid ? 4 : 5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final file = images[index];
          final isSelected = selectedIndexes.contains(index);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.outline.toOpacity(0.72)
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _onTapImage(index),
                      onLongPress: () => _onLongPressImage(index),
                      child: Hero(
                        tag: App.isAndroid
                            ? file.path.split('/').last
                            : file.path.split('\\').last,
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }, childCount: images.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiSelect = ref.watch(multiSelectModeProvider);
    final selectedIndexes = ref.watch(selectedIndexesProvider);
    final images = ref.watch(imagesProvider);
    final tabMode = super.widget.embedded;

    final title = multiSelect
        ? Text(t.sSelected(s: selectedIndexes.length))
        : Text(t.imageOperationsI(i: images.length));

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.photo,
          title: t.stitchLongImage,
          onTap: () {
            context.to(
              () => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(() => RenderLongPicPage(images: selectedImages));
                },
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.image,
          title: t.stitchHorizontalImage,
          onTap: () {
            context.to(
              () => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(
                    () => RenderHorizontalPicPage(images: selectedImages),
                  );
                },
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.extension,
          title: t.stitchSubtitles,
          onTap: () {
            context.to(
              () => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(
                    () => RenderDialogueComposePage(images: selectedImages),
                  );
                },
              ),
            );
          },
        ),
      ),
      _buildGrid(),
    ];

    Widget content;
    if (tabMode) {
      // 适配 Tab：用普通头部 + 普通滚动，不套 SliverAppbar，
      // 避免与详情页 NestedScrollView 冲突、避免 SliverAppbar 的
      // topPadding 导致内容被拉出很长距离。
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: title,
                  ),
                ),
                ..._buildActions(context, multiSelect, selectedIndexes),
              ],
            ),
          ),
          Expanded(
            child: AppScrollBar(
              controller: _scrollCtrl,
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: App.isDesktop
                    ? const ClampingScrollPhysics()
                    : const BouncingScrollPhysics(),
                slivers: slivers,
              ),
            ),
          ),
        ],
      );
    } else {
      content = SmoothCustomScrollView(
        slivers: [
          SliverAppbar(
            title: title,
            actions: _buildActions(context, multiSelect, selectedIndexes),
          ),
          ...slivers,
        ],
      );
    }
    return context.width > changePoint ? content.paddingHorizontal(8) : content;
  }

  List<Widget> _buildActions(
    BuildContext context,
    bool multiSelect,
    Set<int> selectedIndexes,
  ) {
    return [
      if (!multiSelect)
        IconButton(
          onPressed: _importImages,
          tooltip: t.addImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
        ),
      if (multiSelect) ...[
        IconButton(
          onPressed: () {
            final allIndexes = Set<int>.from(
              List.generate(ref.read(imagesProvider).length, (i) => i),
            );
            ref.read(selectedIndexesProvider.notifier).state = allIndexes;
          },
          tooltip: t.selectAll,
          icon: const Icon(Icons.select_all),
        ),
        IconButton(
          onPressed: () {
            final images = ref.read(imagesProvider);
            final current = ref.read(selectedIndexesProvider);
            final toggled = {
              for (int i = 0; i < images.length; i++)
                if (!current.contains(i)) i,
            };

            if (toggled.isEmpty) {
              ref.read(multiSelectModeProvider.notifier).state = false;
            }
            ref.read(selectedIndexesProvider.notifier).state = toggled;
          },
          tooltip: t.invertSelection,
          icon: const Icon(Icons.flip),
        ),
        IconButton(
          onPressed: () {
            ref.read(multiSelectModeProvider.notifier).state = false;
            ref.read(selectedIndexesProvider.notifier).state = {};
          },
          tooltip: t.deselect,
          icon: const Icon(Icons.deselect),
        ),
        IconButton(
          onPressed: () {
            showConfirmDialog(
              context: App.rootContext,
              title: t.delete,
              content: t.deleteImagesCount(n: selectedIndexes.length),
              btnColor: context.colorScheme.error,
              onConfirm: _deleteSelected,
            );
          },
          tooltip: t.delete,
          icon: const Icon(Icons.delete, color: Colors.red),
        ),
      ],
    ];
  }
}

typedef OnImagesSelected = void Function(List<File> selectedImages);

/// 底部毛玻璃操作栏（图标按钮 + tooltip）
class _FrostedBottomBar extends StatelessWidget {
  final List<Widget> children;

  const _FrostedBottomBar({required this.children});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.toOpacity(0.35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部操作图标按钮（带 tooltip）
class _BottomIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _BottomIconAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: cs.onSurface),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.toOpacity(0.15),
        ),
      ),
    );
  }
}

/// 进入排序/裁剪模式时，返回优先退出模式而不退出页面
class _ModeAwareBackButton extends StatelessWidget {
  final bool reorderMode;
  final bool cropMode;
  final VoidCallback onExitMode;

  const _ModeAwareBackButton({
    required this.reorderMode,
    required this.cropMode,
    required this.onExitMode,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new),
      onPressed: () {
        if (reorderMode || cropMode) {
          onExitMode();
        } else {
          Navigator.maybePop(context);
        }
      },
    );
  }
}

/// 将 [painter] 绘制到 [size] 画布并导出为 PNG 字节。
/// [dpr] > 1 时先缩放画布再导出，保证高清晰度。
Future<Uint8List> composePainterToPng({
  required CustomPainter painter,
  required Size size,
  double dpr = 1.0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (dpr != 1.0) canvas.scale(dpr);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * dpr).ceil(),
    (size.height * dpr).ceil(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw Exception('生成图片数据失败');
  return byteData.buffer.asUint8List();
}

class SelectImagesPage extends StatefulWidget {
  final int maxSelection;
  final OnImagesSelected onSelected;
  final Directory? initialDirectory;
  final bool Function(File file)? filter;

  const SelectImagesPage({
    super.key,
    this.maxSelection = 16,
    required this.onSelected,
    this.initialDirectory,
    this.filter,
  });

  @override
  State<SelectImagesPage> createState() => _SelectImagesPageState();
}

class _SelectImagesPageState extends State<SelectImagesPage> {
  List<File> allImages = [];
  final List<File> selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    Directory dir;

    if (widget.initialDirectory != null) {
      dir = widget.initialDirectory!;
    } else if (App.isAndroid) {
      dir = (await KostoriFolder.checkPermissionAndPrepareFolder())!;
    } else {
      final folderDirectory = await getApplicationDocumentsDirectory();
      final folderPath = '${folderDirectory.path}/Kostori';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
        Log.info('创建截图文件夹成功', folderPath);
      }
      dir = folder;
    }

    final files = dir.listSync().whereType<File>().toList();

    final filtered = widget.filter != null
        ? files.where(widget.filter!).toList()
        : files
              .where(
                (file) =>
                    file.path.endsWith('.png') || file.path.endsWith('.jpg'),
              )
              .toList();

    filtered.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );

    setState(() {
      allImages = filtered;
    });
  }

  void _toggleSelection(File image) {
    setState(() {
      if (selectedImages.contains(image)) {
        selectedImages.remove(image);
      } else if (selectedImages.length < widget.maxSelection) {
        selectedImages.add(image);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(t.selectImages),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          if (selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                widget.onSelected(selectedImages);
                // Navigator.pop(context);
              },
            ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: App.isAndroid ? 4 : 5,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: allImages.length,
        itemBuilder: (_, index) {
          final image = allImages[index];
          final selectedIndex = selectedImages.indexOf(image);
          final isSelected = selectedIndex != -1;

          return GestureDetector(
            onTap: () => _toggleSelection(image),
            child: Stack(
              children: [
                Positioned.fill(child: Image.file(image, fit: BoxFit.cover)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: isSelected
                        ? Colors.blue
                        : Colors.transparent,
                    radius: 14,
                    child: isSelected
                        ? Text(
                            '${selectedIndex + 1}',
                            style: const TextStyle(color: Colors.white),
                          )
                        : const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.circle_outlined, size: 16),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BorderSettingsSheet extends ConsumerStatefulWidget {
  const BorderSettingsSheet({super.key});

  @override
  ConsumerState<BorderSettingsSheet> createState() =>
      _BorderSettingsSheetState();
}

class _BorderSettingsSheetState extends ConsumerState<BorderSettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final showOuterBorder = ref.watch(showOuterBorderProvider);
    final outerBorderColor = ref.watch(outerBorderColorProvider);
    final outerBorderWidth = ref.watch(outerBorderWidthProvider);
    final outerBorderRadius = ref.watch(outerBorderRadiusProvider);

    final showInnerBorders = ref.watch(showInnerBordersProvider);
    final innerBorderColor = ref.watch(innerBorderColorProvider);
    final innerBorderWidth = ref.watch(innerBorderWidthProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.borderSettings,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            /// 外边框设置
            ListTile(
              title: Text(t.showOuterBorder),
              trailing: CustomSwitch(
                value: showOuterBorder,
                onChanged: (v) =>
                    ref.read(showOuterBorderProvider.notifier).state = v,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: showOuterBorder
                  ? Column(
                      children: [
                        _buildColorPicker(
                          t.outerBorderColor,
                          outerBorderColor,
                          (c) =>
                              ref
                                      .read(outerBorderColorProvider.notifier)
                                      .state =
                                  c,
                        ),
                        _buildSlider(
                          t.outerBorderWidth,
                          outerBorderWidth,
                          0,
                          120,
                          (v) =>
                              ref
                                      .read(outerBorderWidthProvider.notifier)
                                      .state =
                                  v,
                        ),
                        _buildSlider(
                          t.outerBorderRadius,
                          outerBorderRadius,
                          0,
                          120,
                          (v) =>
                              ref
                                      .read(outerBorderRadiusProvider.notifier)
                                      .state =
                                  v,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            /// 内边框设置
            ListTile(
              title: Text(t.showImageBorders),
              trailing: CustomSwitch(
                value: showInnerBorders,
                onChanged: (v) =>
                    ref.read(showInnerBordersProvider.notifier).state = v,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: showInnerBorders
                  ? Column(
                      children: [
                        _buildColorPicker(
                          t.innerBorderColor,
                          innerBorderColor,
                          (c) =>
                              ref
                                      .read(innerBorderColorProvider.notifier)
                                      .state =
                                  c,
                        ),
                        _buildSlider(
                          t.innerBorderWidth,
                          innerBorderWidth,
                          0,
                          120,
                          (v) =>
                              ref
                                      .read(innerBorderWidthProvider.notifier)
                                      .state =
                                  v,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            /// 操作按钮
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.apply),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(
    String title,
    Color currentColor,
    ValueChanged<Color> onChanged,
  ) {
    String colorToHex(Color color) => '#${color.toARGB32().toRadixString(16)}';

    Color fallbackColorIfTooDark(Color color) =>
        color.toARGB32() == 0xFF000000 ? const Color(0xFF6677ff) : color;

    final Color initialColor = fallbackColorIfTooDark(currentColor);
    final controller = TextEditingController(text: colorToHex(initialColor));
    Color pickerColor = initialColor;

    Color? hexToColor(String hex) {
      try {
        hex = hex.toUpperCase().replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return null;
      }
    }

    return StatefulBuilder(
      builder: (context, setState) {
        void onTextChanged(String value) {
          final color = hexToColor(value);
          if (color != null) {
            setState(() {
              pickerColor = color;
              controller.text = colorToHex(color);
            });
            onChanged(color);
          }
        }

        void onColorChanged(Color color) {
          setState(() {
            pickerColor = color;
            controller.text = colorToHex(color);
          });
          onChanged(color);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: onColorChanged,
              enableAlpha: false,
              pickerAreaHeightPercent: 0.3,
              displayThumbColor: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: t.enterHexColorCode,
                border: const OutlineInputBorder(),
              ),
              maxLength: 9,
              onSubmitted: onTextChanged,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'#[0-9a-fA-F]*')),
              ],
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ),
          SizedBox(width: 40, child: Text(value.toStringAsFixed(1))),
        ],
      ),
    );
  }
}
