import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/image_manipulation_page/render_dialogue_compose_page.dart';
import 'package:kostori/pages/image_manipulation_page/render_horizontal_pic_page.dart';
import 'package:kostori/pages/image_manipulation_page/render_long_pic_page.dart';
import 'package:path_provider/path_provider.dart';

import '../../components/components.dart';
import '../../foundation/consts.dart';
import '../../foundation/log.dart';
import '../../utils/io.dart';

class ImageManipulationPage extends StatefulWidget {
  const ImageManipulationPage({super.key});

  @override
  State<ImageManipulationPage> createState() => _ImageManipulationPageState();
}

class _ImageManipulationPageState extends State<ImageManipulationPage> {
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

  @override
  Widget build(BuildContext context) {
    var widget = SmoothCustomScrollView(slivers: [
      SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
      SliverAppbar(title: Text('图片操作')),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.photo,
          title: '拼长图',
          onTap: () {
            context.to((() => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to((() => RenderLongPicPage(images: selectedImages)));
                })));
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.image,
          title: '拼横图',
          onTap: () {
            context.to((() => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to(
                      (() => RenderHorizontalPicPage(images: selectedImages)));
                })));
          },
        ),
      ),
      SliverToBoxAdapter(
        child: _buildCard(
          icon: Icons.extension,
          title: '拼台词',
          onTap: () {
            context.to((() => SelectImagesPage(
                maxSelection: 9,
                onSelected: (selectedImages) {
                  context.to((() =>
                      RenderDialogueComposePage(images: selectedImages)));
                })));
          },
        ),
      ),
      // SliverToBoxAdapter(
      //   child: _buildCard(
      //     icon: Icons.grid_view,
      //     title: '拼网格',
      //     onTap: () {},
      //   ),
      // ),
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
      appBar: AppBar(
        title: const Text('选择图片'),
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
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
