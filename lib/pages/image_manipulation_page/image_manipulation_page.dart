library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/io.dart';
import 'package:kostori/utils/translations.dart';
import 'package:kostori/utils/utils.dart';
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
        Log.addLog(LogLevel.info, '创建截图文件夹成功', folderPath);
      }
      directory = folder;
    }

    if (!await directory.exists()) {
      return [];
    }

    final files = directory.listSync(recursive: false).whereType<File>().where((
      file,
    ) {
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

    indexes.sort((a, b) => b.compareTo(a));
    for (var i in indexes) {
      try {
        newList[i].deleteSync();
        newList.removeAt(i);
      } catch (e) {
        Log.addLog(LogLevel.error, 'deleteIndexes', e.toString());
      }
    }
    state = newList;
  }
}

final multiSelectModeProvider = StateProvider<bool>((ref) => false);
final selectedIndexesProvider = StateProvider<Set<int>>((ref) => {});
final lastSelectedIndexProvider = StateProvider<int?>((ref) => null);

class ImageManipulationPage extends ConsumerStatefulWidget {
  final List<File>? initialImages;

  const ImageManipulationPage({this.initialImages, super.key});

  @override
  ConsumerState<ImageManipulationPage> createState() =>
      _ImageManipulationPageState();
}

class _ImageManipulationPageState extends ConsumerState<ImageManipulationPage> {
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
                        child: Image.file(file, fit: BoxFit.cover),
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

    var widget = SmoothCustomScrollView(
      slivers: [
        SliverAppbar(
          title: multiSelect
              ? Text('@s selected'.tlParams({"s": selectedIndexes.length}))
              : Text('Image Operations (@i)'.tlParams({"i": images.length})),
          actions: [
            if (multiSelect) ...[
              TextButton.icon(
                onPressed: () {
                  final allIndexes = Set<int>.from(
                    List.generate(images.length, (i) => i),
                  );
                  ref.read(selectedIndexesProvider.notifier).state = allIndexes;
                },
                icon: const Icon(Icons.select_all),
                label: Text('Select All'.tl),
              ),
              TextButton.icon(
                onPressed: () {
                  final images = ref.read(imagesProvider);
                  final current = ref.read(selectedIndexesProvider);
                  final toggled = <int>{};

                  for (int i = 0; i < images.length; i++) {
                    if (!current.contains(i)) {
                      toggled.add(i);
                    }
                  }

                  if (toggled.isEmpty) {
                    ref.read(multiSelectModeProvider.notifier).state = false;
                  }

                  ref.read(selectedIndexesProvider.notifier).state = toggled;
                },
                icon: const Icon(Icons.flip),
                label: Text('Invert Selection'.tl),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(multiSelectModeProvider.notifier).state = false;
                  ref.read(selectedIndexesProvider.notifier).state = {};
                },
                icon: const Icon(Icons.deselect),
                label: Text('Deselect'.tl),
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
            title: 'Stitch Long Image'.tl,
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
            title: 'Stitch Horizontal Image'.tl,
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
            title: 'Stitch Subtitles'.tl,
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
      ],
    );
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
              'Border Settings'.tl,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            /// 外边框设置
            SwitchListTile(
              title: Text("Show Outer Border".tl),
              value: showOuterBorder,
              onChanged: (v) =>
                  ref.read(showOuterBorderProvider.notifier).state = v,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: showOuterBorder
                  ? Column(
                      children: [
                        _buildColorPicker(
                          "Outer Border Color".tl,
                          outerBorderColor,
                          (c) =>
                              ref
                                      .read(outerBorderColorProvider.notifier)
                                      .state =
                                  c,
                        ),
                        _buildSlider(
                          "Outer Border Width".tl,
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
                          "Outer Border Radius".tl,
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
            SwitchListTile(
              title: Text("Show Image Borders".tl),
              value: showInnerBorders,
              onChanged: (v) =>
                  ref.read(showInnerBordersProvider.notifier).state = v,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: showInnerBorders
                  ? Column(
                      children: [
                        _buildColorPicker(
                          "Inner Border Color".tl,
                          innerBorderColor,
                          (c) =>
                              ref
                                      .read(innerBorderColorProvider.notifier)
                                      .state =
                                  c,
                        ),
                        _buildSlider(
                          "Inner Border Width".tl,
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
                child: Text('Apply'.tl),
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
                labelText: 'Enter hex color code, e.g. #FF000000'.tl,
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
