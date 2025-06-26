import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/components.dart';
import '../../foundation/app.dart';
import '../../utils/utils.dart';
import 'image_manipulation_page.dart';

class LongImagePainter extends CustomPainter {
  final List<ui.Image> images;
  final bool showOuterBorder;
  final Color outerBorderColor;
  final double outerBorderWidth;
  final double outerBorderRadius;

  final bool showInnerBorders;
  final Color innerBorderColor;
  final double innerBorderWidth;

  LongImagePainter({
    required this.images,
    required this.showOuterBorder,
    required this.outerBorderColor,
    required this.outerBorderWidth,
    required this.outerBorderRadius,
    required this.showInnerBorders,
    required this.innerBorderColor,
    required this.innerBorderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final contentWidth =
        size.width - (showOuterBorder ? 2 * outerBorderWidth : 0);
    double dy = showOuterBorder ? outerBorderWidth : 0;

    // 1. 画外边框
    if (showOuterBorder) {
      final outerPaint = Paint()..color = outerBorderColor;
      final outerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(outerBorderRadius),
      );
      canvas.drawRRect(outerRect, outerPaint);
    }

    // 2. 画图像
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final scale = contentWidth / img.width;
      final targetHeight = img.height * scale;

      final dstRect = Rect.fromLTWH(
        showOuterBorder ? outerBorderWidth : 0,
        dy,
        contentWidth,
        targetHeight,
      );

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dstRect,
        Paint(),
      );

      dy += targetHeight;

      // 在当前图片绘制后（但不增加间距），绘制内边框
      if (showInnerBorders && i < images.length - 1) {
        final innerPaint = Paint()
          ..color = innerBorderColor
          ..style = PaintingStyle.fill;

        // 直接用图片绘制的横坐标和宽度，保证一致
        double left = showOuterBorder ? outerBorderWidth : 0;
        final right = left + contentWidth;
        final top = dy;
        final bottom = dy + innerBorderWidth;

        canvas.drawRect(
          Rect.fromLTRB(left, top, right, bottom),
          innerPaint,
        );

        dy += innerBorderWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant LongImagePainter oldDelegate) {
    return oldDelegate.images != images ||
        oldDelegate.showOuterBorder != showOuterBorder ||
        oldDelegate.outerBorderColor != outerBorderColor ||
        oldDelegate.outerBorderWidth != outerBorderWidth ||
        oldDelegate.outerBorderRadius != outerBorderRadius ||
        oldDelegate.showInnerBorders != showInnerBorders ||
        oldDelegate.innerBorderColor != innerBorderColor ||
        oldDelegate.innerBorderWidth != innerBorderWidth;
  }
}

class RenderLongPicPage extends ConsumerStatefulWidget {
  final List<File> images;

  const RenderLongPicPage({super.key, required this.images});

  @override
  ConsumerState<RenderLongPicPage> createState() => _RenderLongPicPageState();
}

class _RenderLongPicPageState extends ConsumerState<RenderLongPicPage> {
  late List<File> imageList;
  bool isReorderMode = false;

  final showOuterBorderProvider = StateProvider<bool>((ref) => false);
  final outerBorderColorProvider =
      StateProvider<Color>((ref) => Color(0xFF6677ff));
  final outerBorderWidthProvider = StateProvider<double>((ref) => 20.0);
  final outerBorderRadiusProvider = StateProvider<double>((ref) => 20.0);
  final showInnerBordersProvider = StateProvider<bool>((ref) => false);
  final innerBorderColorProvider =
      StateProvider<Color>((ref) => Color(0xFF6677ff));
  final innerBorderWidthProvider = StateProvider<double>((ref) => 20.0);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    imageList = List.of(widget.images);
  }

  Future<List<ui.Image>> _loadUiImages() async {
    final images = <ui.Image>[];
    for (final file in imageList) {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      images.add(frame.image);
    }
    return images;
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final item = imageList.removeAt(oldIndex);
      imageList.insert(newIndex, item);
    });
  }

  Future<void> _captureAndSaveLongImage(BuildContext context) async {
    App.rootContext.showMessage(message: '正在保存');
    try {
      final outerBorderColor = ref.read(outerBorderColorProvider);
      final outerBorderWidth = ref.read(outerBorderWidthProvider);
      final outerBorderRadius = ref.read(outerBorderRadiusProvider);

      final innerBorderColor = ref.read(innerBorderColorProvider);
      final innerBorderWidth = ref.read(innerBorderWidthProvider);
      final showInnerBorders = ref.read(showInnerBordersProvider);
      final showOuterBorder = ref.read(showOuterBorderProvider);

      final images = <ui.Image>[];

      for (File file in imageList) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        images.add(frame.image);
      }

      if (images.isEmpty) return;

      // 计算 contentWidth（图片宽度最小值）
      final contentWidth = images
          .map((img) => img.width)
          .reduce((a, b) => a < b ? a : b)
          .toDouble();

      // 计算每张图片按contentWidth缩放后的高度列表
      final contentHeights =
          images.map((img) => img.height * (contentWidth / img.width)).toList();

      // 计算总高度（所有图片高 + 内边框总和）
      final totalInnerBorders =
          showInnerBorders ? (images.length - 1) * innerBorderWidth : 0.0;

      final totalHeight =
          contentHeights.fold(0.0, (a, b) => a + b) + totalInnerBorders;

      // 总宽高考虑外边框
      final fullWidth =
          showOuterBorder ? contentWidth + outerBorderWidth * 2 : contentWidth;
      final fullHeight =
          showOuterBorder ? totalHeight + outerBorderWidth * 2 : totalHeight;

      // 创建PictureRecorder和Canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 用LongImagePainter绘制
      final painter = LongImagePainter(
        images: images,
        showOuterBorder: showOuterBorder,
        outerBorderColor: outerBorderColor,
        outerBorderWidth: outerBorderWidth,
        outerBorderRadius: outerBorderRadius,
        showInnerBorders: showInnerBorders,
        innerBorderColor: innerBorderColor,
        innerBorderWidth: innerBorderWidth,
      );

      painter.paint(canvas, Size(fullWidth, fullHeight));

      // 结束绘制，生成图片
      final picture = recorder.endRecording();
      final image =
          await picture.toImage(fullWidth.toInt(), fullHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await Utils.saveLongImage(context, bytes);
        final notifier = ref.read(imagesProvider.notifier);
        await notifier.loadImages();
        App.rootContext.showMessage(message: '保存成功');
      }
    } catch (e) {
      App.rootContext.showMessage(message: '保存失败: $e');
    }
  }

  Widget _buildReorderView() {
    return ReorderableListView(
      onReorder: _onReorder,
      buildDefaultDragHandles: false,
      scrollController: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (int i = 0; i < imageList.length; i++)
          ReorderableDragStartListener(
            key: ValueKey(imageList[i].path),
            index: i,
            child: Image.file(
              imageList[i],
              fit: BoxFit.fitWidth,
            ),
          ),
      ],
    );
  }

  void _showBorderSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: MediaQuery.of(context).size.width <= 600
            ? MediaQuery.of(context).size.width
            : (App.isDesktop)
                ? MediaQuery.of(context).size.width * 9 / 16
                : MediaQuery.of(context).size.width,
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    const Text('边框设置',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),

                    const SizedBox(height: 16),

                    /// 外边框设置
                    SwitchListTile(
                      title: const Text("显示外边框"),
                      value: showOuterBorder,
                      onChanged: (v) {
                        ref.read(showOuterBorderProvider.notifier).state = v;
                        setModalState(() {});
                      },
                    ),
                    if (showOuterBorder) ...[
                      _buildColorPicker("外边框颜色", outerBorderColor, (c) {
                        ref.read(outerBorderColorProvider.notifier).state = c;
                        setModalState(() {});
                      }),
                      _buildSlider("外边框粗细", outerBorderWidth, 0, 120, (v) {
                        ref.read(outerBorderWidthProvider.notifier).state = v;
                        setModalState(() {});
                      }),
                      _buildSlider("外边框圆角", outerBorderRadius, 0, 120, (v) {
                        ref.read(outerBorderRadiusProvider.notifier).state = v;
                        setModalState(() {});
                      }),
                    ],

                    const SizedBox(height: 16),

                    /// 内边框设置
                    SwitchListTile(
                      title: const Text("显示图片间边框"),
                      value: showInnerBorders,
                      onChanged: (v) {
                        ref.read(showInnerBordersProvider.notifier).state = v;
                        setModalState(() {});
                      },
                    ),
                    if (showInnerBorders) ...[
                      _buildColorPicker("内边框颜色", innerBorderColor, (c) {
                        ref.read(innerBorderColorProvider.notifier).state = c;
                        setModalState(() {});
                      }),
                      _buildSlider("内边框粗细", innerBorderWidth, 0, 120, (v) {
                        ref.read(innerBorderWidthProvider.notifier).state = v;
                        setModalState(() {});
                      }),
                    ],

                    const SizedBox(height: 16),

                    /// 操作按钮
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColorPicker(
    String title,
    Color currentColor,
    ValueChanged<Color> onChanged,
  ) {
    // 工具函数
    String colorToHex(Color color) => '#${color.toARGB32().toRadixString(16)}';

    final TextEditingController controller =
        TextEditingController(text: colorToHex(currentColor));

    Color pickerColor = currentColor;

    Color? hexToColor(String hex) {
      try {
        hex = hex.toUpperCase().replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex'; // 没透明度自动补FF
        final val = int.parse(hex, radix: 16);
        return Color(val);
      } catch (e) {
        return null;
      }
    }

    return StatefulBuilder(builder: (context, setState) {
      void onTextChanged(String value) {
        final color = hexToColor(value);
        if (color != null) {
          setState(() {
            pickerColor = color;
            controller.text = colorToHex(color);
            controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length));
          });
          onChanged(color);
        }
      }

      void onColorChanged(Color color) {
        setState(() {
          pickerColor = color;
          controller.text = colorToHex(color);
          controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length));
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
            decoration: const InputDecoration(
              labelText: '输入十六进制颜色码，例如 #FF000000',
              border: OutlineInputBorder(),
            ),
            maxLength: 9,
            // # + 6位RGB
            onSubmitted: onTextChanged,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'#[0-9a-fA-F]*')),
            ],
          ),
          const SizedBox(height: 16),
        ],
      );
    });
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
          SizedBox(width: 80, child: Text(label)),
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

  Widget _buildMainCanvasPreview() {
    final showOuterBorder = ref.watch(showOuterBorderProvider);
    final outerBorderColor = ref.watch(outerBorderColorProvider);
    final outerBorderWidth = ref.watch(outerBorderWidthProvider);
    final outerBorderRadius = ref.watch(outerBorderRadiusProvider);

    final showInnerBorders = ref.watch(showInnerBordersProvider);
    final innerBorderColor = ref.watch(innerBorderColorProvider);
    final innerBorderWidth = ref.watch(innerBorderWidthProvider);

    return FutureBuilder<List<ui.Image>>(
      future: _loadUiImages(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final images = snapshot.data!;

        // 原地计算尺寸逻辑（与 _captureAndSaveLongImage 相同）
        final contentWidth = images
            .map((img) => img.width)
            .reduce((a, b) => a < b ? a : b)
            .toDouble();
        final contentHeights = images
            .map((img) => img.height * (contentWidth / img.width))
            .toList();
        final totalInnerBorders =
            showInnerBorders ? (images.length - 1) * innerBorderWidth : 0.0;
        final totalHeight =
            contentHeights.fold(0.0, (a, b) => a + b) + totalInnerBorders;

        final fullWidth = showOuterBorder
            ? contentWidth + outerBorderWidth * 2
            : contentWidth;
        final fullHeight =
            showOuterBorder ? totalHeight + outerBorderWidth * 2 : totalHeight;

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: fullWidth,
                  height: fullHeight,
                  child: CustomPaint(
                    size: Size(fullWidth, fullHeight),
                    painter: LongImagePainter(
                      images: images,
                      showOuterBorder: showOuterBorder,
                      outerBorderColor: outerBorderColor,
                      outerBorderWidth: outerBorderWidth,
                      outerBorderRadius: outerBorderRadius,
                      showInnerBorders: showInnerBorders,
                      innerBorderColor: innerBorderColor,
                      innerBorderWidth: innerBorderWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.toOpacity(0.35),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isReorderMode)
                    ElevatedButton(
                      onPressed: _showBorderSettings,
                      child: const Text('边框颜色'),
                    ),
                  const SizedBox(
                    width: 20,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => isReorderMode = !isReorderMode);
                    },
                    child: Text(isReorderMode ? '完成排序' : '进入排序'),
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  if (!isReorderMode)
                    ElevatedButton(
                      onPressed: () => _captureAndSaveLongImage(context),
                      child: const Text('保存长图'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: const Text('生成长图'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Stack(
        children: [
          if (isReorderMode)
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 650),
                child: _buildReorderView(),
              ),
            ),
          if (!isReorderMode)
            Positioned.fill(
              child: _buildMainCanvasPreview(),
            ),
          _buildBottomButtons(),
        ],
      ),
    );
  }
}
