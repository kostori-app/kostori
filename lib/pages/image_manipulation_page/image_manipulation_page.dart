import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/image_manipulation_page/render_dialogue_compose_page.dart';
import 'package:kostori/pages/image_manipulation_page/render_horizontal_pic_page.dart';
import 'package:kostori/pages/image_manipulation_page/render_long_pic_page.dart';
import 'package:kostori/utils/translations.dart';
import 'package:path_provider/path_provider.dart';

import '../../components/bangumi_widget.dart';
import '../../components/components.dart';
import '../../foundation/consts.dart';
import '../../foundation/log.dart';
import '../../utils/io.dart';

final imagesProvider = StateNotifierProvider<ImagesNotifier, List<File>>((ref) {
  return ImagesNotifier();
});

class ImagesNotifier extends StateNotifier<List<File>> {
  ImagesNotifier() : super([]);

  void setImages(List<File> imgs) => state = imgs;

  Future<void> loadImages() async {
    // 调用你那个加载图片文件夹的方法
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

  void deleteIndexes(List<int> indexes) {
    final newList = [...state];
    // 从大到小删除，防止索引错乱
    indexes.sort((a, b) => b.compareTo(a));
    for (var i in indexes) {
      try {
        newList[i].deleteSync();
        newList.removeAt(i);
      } catch (e) {
        // 处理异常或打印日志
      }
    }
    state = newList;
  }
}

final multiSelectModeProvider = StateProvider<bool>((ref) => false);
final selectedIndexesProvider = StateProvider<Set<int>>((ref) => {});

class ImageManipulationPage extends ConsumerStatefulWidget {
  final List<File> initialImages;

  const ImageManipulationPage({required this.initialImages, super.key});

  @override
  ConsumerState<ImageManipulationPage> createState() =>
      _ImageManipulationPageState();
}

class _ImageManipulationPageState extends ConsumerState<ImageManipulationPage> {
  @override
  void initState() {
    super.initState();
    // 初始化图片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imagesProvider.notifier).setImages(widget.initialImages);
    });
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
      BangumiWidget.showImagePreview(
        context,
        file.path,
        App.isAndroid ? file.path.split('/').last : file.path.split('\\').last,
        App.isAndroid ? file.path.split('/').last : file.path.split('\\').last,
        allUrls: images,
        initialIndex: index,
      );
    }
  }

  void _onLongPressImage(int index) {
    if (!ref.read(multiSelectModeProvider)) {
      ref.read(multiSelectModeProvider.notifier).state = true;
      ref.read(selectedIndexesProvider.notifier).state = {index};
    }
  }

  void _deleteSelected() {
    final selected = ref.read(selectedIndexesProvider).toList();
    ref.read(imagesProvider.notifier).deleteIndexes(selected);
    ref.read(selectedIndexesProvider.notifier).state = {};
    ref.read(multiSelectModeProvider.notifier).state = false;
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
    final multiSelect = ref.watch(multiSelectModeProvider);
    final selectedIndexes = ref.watch(selectedIndexesProvider);

    if (images.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: App.isAndroid ? 4 : 5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final file = images[index];
            final isSelected = selectedIndexes.contains(index);

            return GestureDetector(
              onTap: () => _onTapImage(index),
              onLongPress: () => _onLongPressImage(index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: App.isAndroid
                        ? file.path.split('/').last
                        : file.path.split('\\').last,
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                  if (multiSelect)
                    Container(
                        color: isSelected ? Colors.black45 : Colors.black26),
                  if (multiSelect)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.greenAccent : Colors.white70,
                      ),
                    ),
                ],
              ),
            );
          },
          childCount: images.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiSelect = ref.watch(multiSelectModeProvider);
    final selectedIndexes = ref.watch(selectedIndexesProvider);
    final images = ref.watch(imagesProvider);

    var widget = SmoothCustomScrollView(slivers: [
      SliverAppbar(
        title: multiSelect
            ? Text('${selectedIndexes.length} 张已选')
            : Text('图片操作(${images.length})'),
        actions: [
          if (multiSelect) ...[
            TextButton.icon(
              onPressed: () {
                ref.read(multiSelectModeProvider.notifier).state = false;
                ref.read(selectedIndexesProvider.notifier).state = {};
              },
              icon: const Icon(Icons.clear),
              label: Text('Cancel'.tl),
            ),
            TextButton.icon(
              onPressed: () {
                showConfirmDialog(
                  context: App.rootContext,
                  title: "Delete".tl,
                  content: '删除${selectedIndexes.length}张图片',
                  btnColor: context.colorScheme.error,
                  onConfirm: () {
                    _deleteSelected();
                  },
                );
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: Text('Delete'.tl, style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.photo,
          title: '拼长图',
          onTap: () {
            context.to(() => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(() => RenderLongPicPage(images: selectedImages));
                }));
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.image,
          title: '拼横图',
          onTap: () {
            context.to(() => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(
                      () => RenderHorizontalPicPage(images: selectedImages));
                }));
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.extension,
          title: '拼台词',
          onTap: () {
            context.to(() => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(
                      () => RenderDialogueComposePage(images: selectedImages));
                }));
          },
        ),
      ),
      _buildGrid()
    ]);
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

typedef OnImagesSelected = void Function(List<File> selectedImages);

class SelectImagesPage extends StatefulWidget {
  final int maxSelection;
  final OnImagesSelected onSelected;
  final Directory? initialDirectory;
  final bool Function(File file)? filter;

  const SelectImagesPage({
    super.key,
    this.maxSelection = 9,
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
        Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
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
        title: const Text('选择图片'),
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
                Positioned.fill(
                  child: Image.file(image, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor:
                        isSelected ? Colors.blue : Colors.transparent,
                    radius: 14,
                    child: isSelected
                        ? Text('${selectedIndex + 1}',
                            style: const TextStyle(color: Colors.white))
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
