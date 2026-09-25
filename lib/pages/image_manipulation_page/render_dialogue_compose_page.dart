part of 'image_manipulation_page.dart';

class DialogueImagePainter extends CollagePainter {
  DialogueImagePainter({
    required this.images,
    required this.cropHeights,
    required this.bottomCropOffsets,
    required super.border,
  });

  final List<ui.Image> images;
  final List<double> cropHeights;

  /// 每张图（除首图）底部裁掉的留白（与 [cropHeights] 同单位）。
  final List<double> bottomCropOffsets;

  @override
  void paint(Canvas canvas, Size size) {
    // 计算内容区域尺寸（考虑外边框）
    final contentWidth = border.showOuterBorder
        ? size.width - 2 * border.outerBorderWidth
        : size.width;

    final contentHeight = border.showOuterBorder
        ? size.height - 2 * border.outerBorderWidth
        : size.height;

    final contentOffset = border.showOuterBorder
        ? Offset(border.outerBorderWidth, border.outerBorderWidth)
        : Offset.zero;

    final paint = Paint();

    // 1. 绘制外边框（如果有）
    if (border.showOuterBorder) {
      final borderRect = Rect.fromLTWH(0, 0, size.width, size.height);
      final borderRRect = RRect.fromRectAndRadius(
        borderRect,
        Radius.circular(border.outerBorderRadius),
      );
      paint
        ..color = border.outerBorderColor
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
      Radius.circular(border.showOuterBorder ? border.outerBorderRadius : 0),
    );
    canvas.save();
    canvas.clipRRect(contentRRect);

    // 3. 绘制图片内容
    double currentY = contentOffset.dy;
    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final cropHeight = cropHeights[i];

      final firstImage = images[0];
      final originalWidth = firstImage.width.toDouble();
      final originalHeight = firstImage.height.toDouble();
      final scale = contentWidth / originalWidth;
      final scaledHeight = originalHeight * scale;

      // 第一张绘制整张高度，其余按 [底部留白, 底部留白+裁剪高度] 的区间绘制
      final cropSrcHeight = cropHeight / scale;
      final bottomSrc = i == 0 ? 0.0 : bottomCropOffsets[i] / scale;
      final srcTop = i == 0 ? 0.0 : image.height - bottomSrc - cropSrcHeight;
      final safeSrcTop = srcTop.clamp(0.0, image.height.toDouble());
      final safeCropSrcHeight = cropSrcHeight.clamp(
        0.0,
        image.height.toDouble() - safeSrcTop,
      );

      if (i == 0) {
        canvas.drawImageRect(
          firstImage,
          Rect.fromLTWH(0, 0, originalWidth, originalHeight),
          Rect.fromLTWH(contentOffset.dx, currentY, contentWidth, scaledHeight),
          paint,
        );
      } else {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            0,
            safeSrcTop,
            image.width.toDouble(),
            safeCropSrcHeight,
          ),
          Rect.fromLTWH(contentOffset.dx, currentY, contentWidth, cropHeight),
          paint,
        );
      }

      currentY += i == 0 ? originalHeight : cropHeight;

      // 内部分隔线（如果有）
      if (border.showInnerBorders && i < images.length - 1) {
        paint.color = border.innerBorderColor;
        canvas.drawRect(
          Rect.fromLTRB(
            contentOffset.dx,
            currentY,
            contentOffset.dx + contentWidth,
            currentY + border.innerBorderWidth,
          ),
          paint,
        );
        currentY += border.innerBorderWidth;
      }
    }

    canvas.restore(); // 释放裁剪区域
  }

  @override
  bool contentChanged(covariant DialogueImagePainter oldDelegate) => true;
}

class RenderDialogueComposePage extends CollageEditorPage {
  const RenderDialogueComposePage({super.key, required super.images});

  @override
  ConsumerState<RenderDialogueComposePage> createState() =>
      _RenderDialogueComposePageState();
}

class _RenderDialogueComposePageState
    extends CollageEditorState<RenderDialogueComposePage> {
  late List<double> cropHeights;

  /// 每张图（除首图）底部裁掉的留白
  late List<double> bottomCropOffsets;
  late List<Size> imageSizes;

  @override
  String get title => t.stitchSubtitles;

  @override
  String get emptyHint => t.noImages;

  @override
  String exportFailureMessage(Object error) =>
      t.saveFailedWithError(e: error.toString());

  @override
  void onInit() {
    // 先给默认值，避免异步加载尺寸前被访问导致 late 初始化异常
    imageSizes = List.generate(imageList.length, (_) => const Size(0, 0));
    cropHeights = List.filled(imageList.length, 125);
    bottomCropOffsets = List.filled(imageList.length, 0);
    _loadImagesInfo();
  }

  Future<void> _loadImagesInfo() async {
    final sizes = await getImageSizes(imageList);
    if (!mounted) return;
    setState(() {
      imageSizes = sizes;
      cropHeights = List.generate(imageList.length, (index) {
        final height = sizes[index].height;
        return index == 0 ? height : 125;
      });
      bottomCropOffsets = List.filled(imageList.length, 0);
    });
  }

  Future<List<Size>> getImageSizes(List<File> imageFiles) async {
    final sizes = <Size>[];
    for (final file in imageFiles) {
      try {
        final data = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(data);
        final frame = await codec.getNextFrame();
        sizes.add(
          Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
        );
      } catch (e) {
        Log.warning('getImageSizes', e.toString());
        sizes.add(const Size(0, 0));
      }
    }
    return sizes;
  }

  /// 确保 cropHeights / bottomCropOffsets / imageSizes 与 imageList 同步
  void _syncIndexedData() {
    if (cropHeights.length > imageList.length) {
      cropHeights = List.of(cropHeights.take(imageList.length));
    }
    if (bottomCropOffsets.length > imageList.length) {
      bottomCropOffsets = List.of(bottomCropOffsets.take(imageList.length));
    }
    if (imageSizes.length > imageList.length) {
      imageSizes = List.of(imageSizes.take(imageList.length));
    }
    if (cropHeights.isNotEmpty && imageSizes.isNotEmpty) {
      // 首位角色裁剪高度为新首图全高，且无底部留白
      cropHeights[0] = imageSizes[0].height;
      bottomCropOffsets[0] = 0;
    }
  }

  @override
  void onReorderExtra(int oldIndex, int newIndex) {
    if (oldIndex < imageSizes.length) {
      imageSizes.insert(newIndex, imageSizes.removeAt(oldIndex));
    }
    if (oldIndex < cropHeights.length) {
      cropHeights.insert(newIndex, cropHeights.removeAt(oldIndex));
    }
    if (oldIndex < bottomCropOffsets.length) {
      bottomCropOffsets.insert(newIndex, bottomCropOffsets.removeAt(oldIndex));
    }
    _syncIndexedData();
  }

  @override
  void onRemoveExtra(int index) {
    if (index < imageSizes.length) imageSizes.removeAt(index);
    if (index < cropHeights.length) cropHeights.removeAt(index);
    if (index < bottomCropOffsets.length) bottomCropOffsets.removeAt(index);
    _syncIndexedData();
  }

  @override
  CustomPainter buildPainter(
    List<ui.Image> images,
    CollageBorderStyle border,
  ) => DialogueImagePainter(
    images: images,
    cropHeights: cropHeights,
    bottomCropOffsets: bottomCropOffsets,
    border: border,
  );

  @override
  Size computeCanvasSize(List<ui.Image> images, CollageBorderStyle border) {
    final maxWidth = images.first.width.toDouble();
    double totalCropHeight;

    if (cropHeights.isNotEmpty) {
      // 第一张按原图全高
      totalCropHeight = images.first.height.toDouble();
      for (int i = 1; i < cropHeights.length && i < images.length; i++) {
        totalCropHeight += cropHeights[i];
      }
    } else {
      totalCropHeight = cropHeights.fold(0.0, (sum, h) => sum + h);
    }

    if (border.showInnerBorders && images.length > 1) {
      totalCropHeight += border.innerBorderWidth * (images.length - 1);
    }
    if (border.showOuterBorder) {
      totalCropHeight += 2 * border.outerBorderWidth;
    }

    final totalWidth =
        maxWidth + (border.showOuterBorder ? 2 * border.outerBorderWidth : 0);
    return Size(totalWidth, totalCropHeight);
  }

  @override
  double previewMaxWidth(Size canvasSize) => canvasSize.width / 2;

  @override
  List<Widget> extraEditorActions() => [
    buildCapsuleAction(
      icon: Icons.crop,
      label: t.cropImage,
      onPressed: () => setState(() => isCroppingMode = true),
    ),
  ];

  @override
  List<Widget> cropModeActions() => [
    buildCapsuleAction(
      icon: Icons.vertical_align_center,
      label: t.uniformHeight,
      onPressed: _showUniformHeightDialog,
    ),
    buildCapsuleAction(
      icon: Icons.check,
      label: t.finishCropping,
      primary: true,
      onPressed: () => setState(() => isCroppingMode = false),
    ),
  ];

  @override
  List<Widget> extraOverlayWidgets() {
    if (!isCroppingMode) return const [];
    final images = uiImages;
    if (images == null || images.isEmpty) return const [];
    final border = CollageBorderStyle.watch(ref);
    return [
      Positioned(
        top: 12,
        right: 12,
        child: IgnorePointer(
          child: _DialogueLivePreview(
            canvasSize: computeCanvasSize(images, border),
            painter: buildPainter(images, border),
          ),
        ),
      ),
    ];
  }

  @override
  Widget buildCropBody() {
    // 尺寸尚未加载完成时先显示加载态，避免越界
    if (imageSizes.length != imageList.length ||
        cropHeights.length != imageList.length ||
        bottomCropOffsets.length != imageList.length) {
      return const Center(child: PolygonRefreshIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 扣除左右各 16 的 padding，避免窄屏溢出导致比例失真
        final displayWidth = constraints.maxWidth - 32;
        return Padding(
          padding: const EdgeInsets.only(bottom: 120),
          child: ListView.builder(
            itemCount: imageList.length,
            itemBuilder: (context, index) {
              final image = imageList[index];
              final imageSize = imageSizes[index];
              final crop = cropHeights[index].clamp(0.0, imageSize.height);
              final bottom = bottomCropOffsets[index].clamp(
                0.0,
                (imageSize.height - crop).clamp(0.0, imageSize.height),
              );

              final scale = imageSize.width > 0
                  ? displayWidth / imageSize.width
                  : 1.0;
              final displayHeight = imageSize.height * scale;
              final bandHeightDisplay = crop * scale;
              final bandBottomDisplay = bottom * scale;
              final bandTopDisplay =
                  (imageSize.height - bottom - crop).clamp(
                    0.0,
                    imageSize.height,
                  ) *
                  scale;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: displayWidth,
                          height: displayHeight,
                          child: Image.file(image, fit: BoxFit.fill),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        // 只压暗裁掉的部分，保留区保持清晰（避免字幕看起来被切一半）
                        if (index != 0) ...[
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: bandTopDisplay,
                            child: const ColoredBox(color: Colors.black45),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: bandBottomDisplay,
                            child: const ColoredBox(color: Colors.black45),
                          ),
                          Positioned(
                            top: bandTopDisplay,
                            left: 0,
                            right: 0,
                            height: bandHeightDisplay,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.symmetric(
                                    horizontal: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: bandTopDisplay + 4,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                t.cropHeightCPx(c: crop.toStringAsFixed(0)),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (index == 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          t.firstImageFullHeight,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      _buildCropSlider(
                        label: t.cropHeightLabel,
                        value: crop,
                        max: imageSize.height - bottom,
                        onChanged: (v) => setState(() {
                          cropHeights[index] = v.clamp(
                            0.0,
                            imageSize.height - bottomCropOffsets[index],
                          );
                        }),
                      ),
                      _buildCropSlider(
                        label: t.cropBottomMargin,
                        value: bottom,
                        // 上边固定：下边距只能移动到当前带的上边
                        // （= 下边距 + 高度），拖动时同步缩减高度
                        max: bottom + crop,
                        onChanged: (v) => setState(() {
                          final prevBottom = bottomCropOffsets[index];
                          final prevHeight = cropHeights[index];
                          final target = v.clamp(0.0, prevBottom + prevHeight);
                          bottomCropOffsets[index] = target;
                          cropHeights[index] =
                              prevHeight - (target - prevBottom);
                        }),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 裁剪数值控制条：步进按钮 + 滑杆 + 数值，方便微调。
  Widget _buildCropSlider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final safeMax = max <= 0 ? 1.0 : max;

    void step(double delta) => onChanged((value + delta).clamp(0.0, safeMax));

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 18),
          tooltip: '-10',
          onPressed: () => step(-10),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: safeMax,
            value: value.clamp(0.0, safeMax),
            label: '${value.toStringAsFixed(0)}px',
            divisions: safeMax > 5 ? (safeMax / 5).ceil() : null,
            onChanged: (v) => onChanged(v.clamp(0.0, safeMax)),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 18),
          tooltip: '+10',
          onPressed: () => step(10),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// 统一高度设置对话框（使用项目的 ContentDialog）。
  void _showUniformHeightDialog() {
    double targetHeight = cropHeights.length > 1 ? cropHeights[1] : 120.0;
    double targetMargin = bottomCropOffsets.length > 1
        ? bottomCropOffsets[1]
        : 0.0;
    final heightController = TextEditingController(
      text: targetHeight.toStringAsFixed(0),
    );
    final marginController = TextEditingController(
      text: targetMargin.toStringAsFixed(0),
    );

    void applyToAll() {
      for (int i = 1; i < cropHeights.length; i++) {
        final maxHeight = imageSizes[i].height;
        final margin = targetMargin.clamp(0.0, maxHeight);
        bottomCropOffsets[i] = margin;
        cropHeights[i] = targetHeight.clamp(
          0.0,
          (maxHeight - margin).clamp(0.0, maxHeight),
        );
      }
      setState(() {});
    }

    ContentDialog.show(
      context: context,
      title: t.setUniformHeight,
      content: StatefulBuilder(
        builder: (context, setStates) {
          void sync(TextEditingController controller, double value) {
            final text = value.toStringAsFixed(0);
            if (controller.text != text) {
              controller.text = text;
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: text.length),
              );
            }
          }

          void updateHeight(double value) {
            targetHeight = value.clamp(0.0, 5000.0);
            sync(heightController, targetHeight);
          }

          void updateMargin(double value) {
            targetMargin = value.clamp(0.0, 5000.0);
            sync(marginController, targetMargin);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _uniformField(
                context: context,
                setStates: setStates,
                label: t.cropHeightLabel,
                fieldLabel: t.heightPx,
                value: targetHeight,
                min: 10,
                max: 1080,
                controller: heightController,
                onUpdate: updateHeight,
              ),
              const SizedBox(height: 24),
              _uniformField(
                context: context,
                setStates: setStates,
                label: t.cropBottomMargin,
                fieldLabel: t.marginPx,
                value: targetMargin,
                min: 0,
                max: 1080,
                controller: marginController,
                onUpdate: updateMargin,
              ),
            ],
          );
        },
      ),
      actions: [
        FilledButton(
          onPressed: () {
            applyToAll();
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(t.apply),
        ),
      ],
      cancel: () {},
    );
  }

  /// 统一设置里的单个「标签 + 滑杆 + 输入框」，滑杆去掉拖动时的外围圆圈。
  Widget _uniformField({
    required BuildContext context,
    required StateSetter setStates,
    required String label,
    required String fieldLabel,
    required double value,
    required double min,
    required double max,
    required TextEditingController controller,
    required ValueChanged<double> onUpdate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            overlayShape: SliderComponentShape.noOverlay,
            trackHeight: 4,
          ),
          child: Slider(
            min: min,
            max: max,
            value: value.clamp(min, max),
            onChanged: (v) => setStates(() => onUpdate(v)),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: fieldLabel,
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (value) {
            final parsed = double.tryParse(value);
            if (parsed != null) setStates(() => onUpdate(parsed));
          },
        ),
      ],
    );
  }
}

/// 裁剪模式下的实时合成预览（固定于右上角，随裁剪参数变化刷新）。
class _DialogueLivePreview extends StatelessWidget {
  const _DialogueLivePreview({required this.canvasSize, required this.painter});

  final Size canvasSize;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.toOpacity(0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.preview, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 88,
                height: 116,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  child: CustomPaint(size: canvasSize, painter: painter),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
