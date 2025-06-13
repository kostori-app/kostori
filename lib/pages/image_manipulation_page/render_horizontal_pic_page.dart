import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../foundation/app.dart';
import '../../utils/utils.dart';

class HorizontalImagePainter extends CustomPainter {
  final List<ui.Image> images;
  final bool showOuterBorder;
  final Color outerBorderColor;
  final double outerBorderWidth;
  final double outerBorderRadius;

  final bool showInnerBorders;
  final Color innerBorderColor;
  final double innerBorderWidth;

  HorizontalImagePainter({
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
    final contentHeight =
        size.height - (showOuterBorder ? 2 * outerBorderWidth : 0);
    double dx = showOuterBorder ? outerBorderWidth : 0;

    // 画外边框
    if (showOuterBorder) {
      final outerPaint = Paint()..color = outerBorderColor;
      final outerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(outerBorderRadius),
      );
      canvas.drawRRect(outerRect, outerPaint);
    }

    // 按contentHeight固定缩放图片，宽度随比例变化，允许横向超出size.width
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final scale = contentHeight / img.height;
      final targetWidth = img.width * scale;

      final dstRect = Rect.fromLTWH(
        dx,
        showOuterBorder ? outerBorderWidth : 0,
        targetWidth,
        contentHeight,
      );

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dstRect,
        Paint(),
      );

      dx += targetWidth;

      // 内边框
      if (showInnerBorders && i < images.length - 1) {
        final innerPaint = Paint()
          ..color = innerBorderColor
          ..style = PaintingStyle.fill;

        final left = dx;
        final right = dx + innerBorderWidth;
        double top = showOuterBorder ? outerBorderWidth : 0;
        final bottom = top + contentHeight;

        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), innerPaint);

        dx += innerBorderWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HorizontalImagePainter oldDelegate) {
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

class RenderHorizontalPicPage extends ConsumerStatefulWidget {
  final List<File> images;

  const RenderHorizontalPicPage({super.key, required this.images});

  @override
  ConsumerState<RenderHorizontalPicPage> createState() =>
      _RenderHorizontalPicPageState();
}

class _RenderHorizontalPicPageState
    extends ConsumerState<RenderHorizontalPicPage> {
  late List<File> imageList;

  final showOuterBorderProvider = StateProvider<bool>((ref) => false);
  final outerBorderColorProvider = StateProvider<Color>((ref) => Colors.black);
  final outerBorderWidthProvider = StateProvider<double>((ref) => 2.0);
  final outerBorderRadiusProvider = StateProvider<double>((ref) => 8.0);
  final showInnerBordersProvider = StateProvider<bool>((ref) => false);
  final innerBorderColorProvider = StateProvider<Color>((ref) => Colors.black);
  final innerBorderWidthProvider = StateProvider<double>((ref) => 1.0);

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

      // 计算 contentHeight（图片高度最小值）
      final contentHeight = images
          .map((img) => img.height)
          .reduce((a, b) => a < b ? a : b)
          .toDouble();

      // 计算每张图片按contentHeight缩放后的宽度列表
      final contentWidths = images
          .map((img) => img.width * (contentHeight / img.height))
          .toList();

      // 计算总宽度（所有图片宽 + 内边框总和）
      final totalInnerBorders =
          showInnerBorders ? (images.length - 1) * innerBorderWidth : 0.0;

      final totalWidth =
          contentWidths.fold(0.0, (a, b) => a + b) + totalInnerBorders;

      // 总宽高考虑外边框
      final fullWidth =
          showOuterBorder ? totalWidth + outerBorderWidth * 2 : totalWidth;
      final fullHeight = showOuterBorder
          ? contentHeight + outerBorderWidth * 2
          : contentHeight;

      // 创建PictureRecorder和Canvas
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 用HorizontalImagePainter绘制
      final painter = HorizontalImagePainter(
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
        App.rootContext.showMessage(message: '保存成功');
      }
    } catch (e) {
      App.rootContext.showMessage(message: '保存失败: $e');
    }
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
                      _buildSlider("外边框粗细", outerBorderWidth, 0, 60, (v) {
                        ref.read(outerBorderWidthProvider.notifier).state = v;
                        setModalState(() {});
                      }),
                      _buildSlider("外边框圆角", outerBorderRadius, 0, 60, (v) {
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

  Widget _buildPreview() {
    return FutureBuilder<List<ui.Image>>(
      future: _loadUiImages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return const Center(child: Text('加载图片失败或没有图片'));
        }

        final images = snapshot.data!;

        final showOuterBorder = ref.watch(showOuterBorderProvider);
        final outerBorderWidth = ref.watch(outerBorderWidthProvider);
        final outerBorderRadius = ref.watch(outerBorderRadiusProvider);
        final showInnerBorders = ref.watch(showInnerBordersProvider);
        final innerBorderWidth = ref.watch(innerBorderWidthProvider);

        final maxHeight = 300.0;

        final contentHeight =
            maxHeight - (showOuterBorder ? 2 * outerBorderWidth : 0);

        double totalWidth = 0;
        for (var img in images) {
          final scale = contentHeight / img.height;
          totalWidth += img.width * scale;
        }

        if (showInnerBorders && images.length > 1) {
          totalWidth += innerBorderWidth * (images.length - 1);
        }

        if (showOuterBorder) {
          totalWidth += 2 * outerBorderWidth;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SizedBox(
              width: totalWidth,
              // height: fullHeight.toDouble(),
              child: CustomPaint(
                painter: HorizontalImagePainter(
                  images: images,
                  showOuterBorder: showOuterBorder,
                  outerBorderColor: ref.read(outerBorderColorProvider),
                  outerBorderWidth: outerBorderWidth,
                  outerBorderRadius: outerBorderRadius,
                  showInnerBorders: showInnerBorders,
                  innerBorderColor: ref.read(innerBorderColorProvider),
                  innerBorderWidth: innerBorderWidth,
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
      child: Container(
        color: Colors.black.toOpacity(0.5),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _showBorderSettings,
              child: const Text('边框颜色'),
            ),
            ElevatedButton(
              onPressed: () => _captureAndSaveLongImage(context),
              child: const Text('保存长图'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('水平拼接长图渲染'),
        ),
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 300.0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildPreview(),
                    )
                  ],
                ),
              ),
            ),
            _buildBottomButtons()
          ],
        ));
  }
}
