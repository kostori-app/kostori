import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../../foundation/app.dart';
import '../../utils/utils.dart';

class DialogueImagePainter extends CustomPainter {
  final List<ui.Image> images;
  final List<double> cropHeights;
  final bool showOuterBorder;
  final Color outerBorderColor;
  final double outerBorderWidth;
  final double outerBorderRadius;
  final bool showInnerBorders;
  final Color innerBorderColor;
  final double innerBorderWidth;

  DialogueImagePainter({
    required this.images,
    required this.cropHeights,
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
    // 计算内容区域尺寸（考虑外边框）
    final contentWidth =
        showOuterBorder ? size.width - 2 * outerBorderWidth : size.width;

    final contentHeight =
        showOuterBorder ? size.height - 2 * outerBorderWidth : size.height;

    // 计算内容区域偏移
    final contentOffset = showOuterBorder
        ? Offset(outerBorderWidth, outerBorderWidth)
        : Offset.zero;

    final paint = Paint();

    // 1. 绘制外边框（如果有）
    if (showOuterBorder) {
      final borderRect = Rect.fromLTWH(0, 0, size.width, size.height);
      final borderRRect = RRect.fromRectAndRadius(
        borderRect,
        Radius.circular(outerBorderRadius),
      );
      paint
        ..color = outerBorderColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(borderRRect, paint);
    }

    // 2. 设置内容裁剪区域（防止内容溢出）
    final contentRect = Rect.fromLTWH(
      contentOffset.dx,
      contentOffset.dy,
      contentWidth,
      contentHeight,
    );
    final contentRRect = RRect.fromRectAndRadius(
      contentRect,
      Radius.circular(showOuterBorder ? outerBorderRadius : 0),
    );
    canvas.save();
    canvas.clipRRect(contentRRect);

    // 3. 绘制图片内容
    double currentY = contentOffset.dy;
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final cropHeight = cropHeights[i];

      // 计算图片缩放比例和裁剪区域
      final scale = contentWidth / image.width;
      final cropSrcHeight = cropHeight / scale;
      final srcTop = i == 0 ? 0.0 : image.height - cropSrcHeight;
      final safeSrcTop = srcTop.clamp(0.0, image.height.toDouble());
      final safeCropSrcHeight = cropSrcHeight.clamp(
        0.0,
        image.height.toDouble() - safeSrcTop,
      );

      // 绘制图片
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, safeSrcTop, image.width.toDouble(), safeCropSrcHeight),
        Rect.fromLTWH(contentOffset.dx, currentY, contentWidth, cropHeight),
        paint,
      );

      currentY += cropHeight;

      // 4. 绘制内部分隔线（如果有）
      if (showInnerBorders && i < images.length - 1) {
        final borderRect = Rect.fromLTRB(
          contentOffset.dx,
          currentY,
          contentOffset.dx + contentWidth,
          currentY + innerBorderWidth,
        );
        paint.color = innerBorderColor;
        canvas.drawRect(borderRect, paint);

        currentY += innerBorderWidth;
      }
    }

    canvas.restore(); // 释放裁剪区域
  }

  @override
  bool shouldRepaint(covariant DialogueImagePainter oldDelegate) => true;
}

class RenderDialogueComposePage extends ConsumerStatefulWidget {
  final List<File> images;

  const RenderDialogueComposePage({super.key, required this.images});

  @override
  ConsumerState<RenderDialogueComposePage> createState() =>
      _RenderDialogueComposePageState();
}

class _RenderDialogueComposePageState
    extends ConsumerState<RenderDialogueComposePage> {
  late List<double> cropHeights;
  late List<File> imageList;
  bool isReorderMode = false;
  bool isCroppingMode = false;

  final showOuterBorderProvider = StateProvider<bool>((ref) => false);
  final outerBorderColorProvider = StateProvider<Color>((ref) => Colors.black);
  final outerBorderWidthProvider = StateProvider<double>((ref) => 3.0);
  final outerBorderRadiusProvider = StateProvider<double>((ref) => 12.0);
  final bottomCropHeightProvider = StateProvider<double>((ref) => 60.0);
  final showInnerBordersProvider = StateProvider<bool>((ref) => false);
  final innerBorderColorProvider = StateProvider<Color>((ref) => Colors.black);
  final innerBorderWidthProvider = StateProvider<double>((ref) => 1.0);

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    imageList = List.of(widget.images);
    cropHeights =
        List.generate(imageList.length, (index) => index == 0 ? 380.0 : 60.0);
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
      final showOuterBorder = ref.read(showOuterBorderProvider);

      final showInnerBorders = ref.read(showInnerBordersProvider);
      final innerBorderColor = ref.read(innerBorderColorProvider);
      final innerBorderWidth = ref.read(innerBorderWidthProvider);

      final images = <ui.Image>[];
      for (File file in imageList) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        images.add(frame.image);
      }

      if (images.isEmpty) return;

      // 宽度与 UI 保持一致（最大宽度为 650）
      const maxWidth = 650.0;

      double totalCropHeight = cropHeights.fold(0.0, (sum, h) => sum + h);

      if (showInnerBorders && images.length > 1) {
        totalCropHeight += innerBorderWidth * (images.length - 1);
      }

      if (showOuterBorder) {
        totalCropHeight += 2 * outerBorderWidth;
      }

      final totalWidth =
          maxWidth + (showOuterBorder ? 2 * outerBorderWidth : 0);

      final fullSize = Size(
        totalWidth,
        totalCropHeight,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final painter = DialogueImagePainter(
        images: images,
        cropHeights: cropHeights,
        showOuterBorder: showOuterBorder,
        outerBorderColor: outerBorderColor,
        outerBorderWidth: outerBorderWidth,
        outerBorderRadius: outerBorderRadius,
        showInnerBorders: showInnerBorders,
        innerBorderColor: innerBorderColor,
        innerBorderWidth: innerBorderWidth,
      );

      painter.paint(canvas, fullSize);
      final picture = recorder.endRecording();

      final image = await picture.toImage(
        fullSize.width.ceil(),
        fullSize.height.ceil(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("生成图片数据失败");

      final bytes = byteData.buffer.asUint8List();
      await Utils.saveLongImage(context, bytes);

      App.rootContext.showMessage(message: '保存成功');
    } catch (e, st) {
      debugPrint('保存长图异常: $e\n$st');
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.file(
                imageList[i],
                fit: BoxFit.fitWidth,
              ),
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
                      _buildSlider("外边框粗细", outerBorderWidth, 0, 40, (v) {
                        ref.read(outerBorderWidthProvider.notifier).state = v;
                        setModalState(() {});
                      }),
                      _buildSlider("外边框圆角", outerBorderRadius, 0, 40, (v) {
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
                      _buildSlider("内边框粗细", innerBorderWidth, 0, 60, (v) {
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

  Widget _buildCropListView() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: ListView.builder(
        itemCount: imageList.length,
        itemBuilder: (context, index) {
          final image = imageList[index];
          final imageHeight = cropHeights[index].clamp(0, 1080);
          final sliderMax = max(300.0, imageHeight);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Image.file(image),
                          Container(
                            color: Colors.black45,
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            child: Text(
                              "裁剪高度：${cropHeights[index].toStringAsFixed(0)} px",
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 竖直进度条
                    Container(
                      width: 20,
                      height: 300, // 你可以用固定高度或者动态根据图片高度
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            height: cropHeights[index], // 按比例映射高度
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
                Slider(
                  min: 0,
                  max: sliderMax.toDouble(),
                  value: cropHeights[index].clamp(0.0, sliderMax).toDouble(),
                  onChanged: (value) {
                    setState(() {
                      cropHeights[index] = value;
                    });
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainCanvasPreview() {
    const maxWidth = 650.0;

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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("没有图片"));
        }

        final images = snapshot.data!;

        // ✅ 根据 cropHeights 计算 totalHeight
        double totalCropHeight = cropHeights.fold(0.0, (sum, h) => sum + h);

        if (showInnerBorders && images.length > 1) {
          totalCropHeight += innerBorderWidth * (images.length - 1);
        }

        if (showOuterBorder) {
          totalCropHeight += 2 * outerBorderWidth;
        }

        final totalWidth =
            maxWidth + (showOuterBorder ? 2 * outerBorderWidth : 0);

        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: totalWidth),
              child: SizedBox(
                width: totalWidth,
                height: totalCropHeight,
                child: CustomPaint(
                  painter: DialogueImagePainter(
                    images: images,
                    cropHeights: cropHeights,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("拼台词")),
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: isReorderMode
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 650),
                      child: _buildReorderView(),
                    )
                  : isCroppingMode
                      ? ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: _buildCropListView(),
                        )
                      : _buildMainCanvasPreview(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.toOpacity(0.35),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SingleChildScrollView(
                // 👈 添加横向滑动
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!isReorderMode && !isCroppingMode)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.color_lens),
                        label: const Text("边框颜色"),
                        onPressed: _showBorderSettings,
                      ),
                    const SizedBox(width: 20),
                    if (!isCroppingMode)
                      ElevatedButton.icon(
                        icon: Icon(isReorderMode ? Icons.check : Icons.sort),
                        label: Text(isReorderMode ? "完成排序" : "排序图片"),
                        onPressed: () {
                          setState(() {
                            isReorderMode = !isReorderMode;
                          });
                        },
                      ),
                    const SizedBox(width: 20),
                    if (!isReorderMode)
                      ElevatedButton.icon(
                        icon: Icon(isCroppingMode ? Icons.check : Icons.crop),
                        label: Text(isCroppingMode ? "完成裁剪" : "裁剪图片"),
                        onPressed: () {
                          setState(() {
                            isCroppingMode = !isCroppingMode;
                          });
                        },
                      ),
                    const SizedBox(width: 20),
                    if (!isReorderMode && !isCroppingMode)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text("保存长图"),
                        onPressed: () => _captureAndSaveLongImage(context),
                      ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
