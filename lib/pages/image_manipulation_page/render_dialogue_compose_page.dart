part of 'image_manipulation_page.dart';

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
    final contentWidth = showOuterBorder
        ? size.width - 2 * outerBorderWidth
        : size.width;

    final contentHeight = showOuterBorder
        ? size.height - 2 * outerBorderWidth
        : size.height;

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
      // final scale = contentWidth / image.width;

      final firstImage = images[0];
      final originalWidth = firstImage.width.toDouble();
      final originalHeight = firstImage.height.toDouble();
      final scale = contentWidth / originalWidth;
      final scaledHeight = originalHeight * scale;

      // 如果是第一张图片，则绘制整张高度，否则按裁剪高度绘制
      final cropSrcHeight = cropHeight / scale;
      final srcTop = i == 0 ? 0.0 : image.height - cropSrcHeight;
      final safeSrcTop = srcTop.clamp(0.0, image.height.toDouble());
      final safeCropSrcHeight = cropSrcHeight.clamp(
        0.0,
        image.height.toDouble() - safeSrcTop,
      );

      // 然后绘制
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

      if (i == 0) {
        currentY += originalHeight;
      } else {
        currentY += cropHeight;
      }

      // 绘制内部分隔线（如果有）
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
  late List<Size> imageSizes;
  bool isReorderMode = false;
  bool isCroppingMode = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    imageList = List.of(widget.images);
    _initCropHeights();
    _loadImagesInfo();
  }

  Future<void> _loadImagesInfo() async {
    imageSizes = await getImageSizes(imageList);
    cropHeights = List.generate(imageList.length, (index) {
      final height = imageSizes[index].height;
      return index == 0 ? height : 125;
    });
    setState(() {}); // 更新 UI
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
        Log.addLog(LogLevel.warning, 'getImageSizes', e.toString());
        sizes.add(const Size(0, 0)); // 失败时添加默认尺寸避免崩溃
      }
    }

    return sizes;
  }

  Future<void> _initCropHeights() async {
    double firstImageHeight = 380.0;

    if (imageList.isNotEmpty) {
      try {
        final bytes = await imageList.first.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        firstImageHeight = frame.image.height.toDouble();
      } catch (e) {
        Log.addLog(LogLevel.warning, '_initCropHeights', e.toString());
      }
    }

    setState(() {
      Log.addLog(
        LogLevel.info,
        'firstImageHeight',
        firstImageHeight.toString(),
      );
      cropHeights = List.generate(
        imageList.length,
        (index) => index == 0 ? firstImageHeight : 125.0,
      );
    });
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
      // 读取配置项
      final outerBorderColor = ref.read(outerBorderColorProvider);
      final outerBorderWidth = ref.read(outerBorderWidthProvider);
      final outerBorderRadius = ref.read(outerBorderRadiusProvider);
      final showOuterBorder = ref.read(showOuterBorderProvider);

      final showInnerBorders = ref.read(showInnerBordersProvider);
      final innerBorderColor = ref.read(innerBorderColorProvider);
      final innerBorderWidth = ref.read(innerBorderWidthProvider);

      // 加载图片
      final images = <ui.Image>[];
      for (File file in imageList) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        images.add(frame.image);
      }

      if (images.isEmpty) return;

      // 计算逻辑大小
      final maxWidth = images.first.width.toDouble();
      double totalCropHeight = 0.0;

      if (cropHeights.isNotEmpty && images.isNotEmpty) {
        // 先把第一张图片的高度赋值（单位是逻辑像素）
        totalCropHeight = images.first.height.toDouble();

        // 累加 cropHeights 中除了第一个之外的其他高度
        for (int i = 1; i < cropHeights.length; i++) {
          totalCropHeight += cropHeights[i];
        }
      } else {
        // 如果没有数据，仍然累加所有cropHeights
        totalCropHeight = cropHeights.fold(0.0, (sum, h) => sum + h);
      }

      if (showInnerBorders && images.length > 1) {
        totalCropHeight += innerBorderWidth * (images.length - 1);
      }

      if (showOuterBorder) {
        totalCropHeight += 2 * outerBorderWidth;
      }

      final totalWidth =
          maxWidth + (showOuterBorder ? 2 * outerBorderWidth : 0);
      final fullSize = Size(totalWidth, totalCropHeight);

      // 获取设备像素比
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final scaledSize = Size(fullSize.width * dpr, fullSize.height * dpr);

      // 创建高分辨率画布
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(dpr); // 缩放 Canvas，保证清晰度

      // 绘制
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

      // 导出图片
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        scaledSize.width.ceil(),
        scaledSize.height.ceil(),
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("生成图片数据失败");

      final bytes = byteData.buffer.asUint8List();
      await Utils.saveLongImage(context, bytes);

      // 刷新图片列表（使用 Riverpod）
      final notifier = ref.read(imagesProvider.notifier);
      await notifier.loadImages();

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
              child: Image.file(imageList[i], fit: BoxFit.fitWidth),
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
      builder: (_) => const BorderSettingsSheet(),
    );
  }

  Widget _buildCropListView() {
    const double baseDisplayWidth = 650;

    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: ListView.builder(
        itemCount: imageList.length,
        itemBuilder: (context, index) {
          final image = imageList[index];
          final imageSize = imageSizes[index]; // 原图尺寸
          final crop = cropHeights[index].clamp(0.0, imageSize.height);

          // 按原图比例缩放到基准宽度
          final scale = baseDisplayWidth / imageSize.width;
          final displayHeight = imageSize.height * scale;
          final cropDisplayHeight = crop * scale;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      width: baseDisplayWidth,
                      height: displayHeight,
                      child: Image.file(image, fit: BoxFit.fill),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: cropDisplayHeight,
                      child: Container(
                        color: Colors.black26,
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            color: Colors.black54,
                            child: Text(
                              'Crop Height: @c px'.tlParams({
                                "c": crop.toStringAsFixed(0),
                              }),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  min: 0,
                  max: imageSize.height,
                  value: crop,
                  onChanged: (value) {
                    setState(() {
                      cropHeights[index] = value;
                    });
                  },
                ),
              ],
            ),
          );
        },
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
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return Center(child: Text("No Images".tl));
        }

        final images = snapshot.data!;

        final maxWidth = images.first.width.toDouble();
        double totalCropHeight = 0.0;

        if (cropHeights.isNotEmpty && images.isNotEmpty) {
          totalCropHeight = images.first.height.toDouble();

          for (int i = 1; i < cropHeights.length; i++) {
            totalCropHeight += cropHeights[i];
          }
        } else {
          totalCropHeight = cropHeights.fold(0.0, (sum, h) => sum + h);
        }

        if (showInnerBorders && images.length > 1) {
          totalCropHeight += innerBorderWidth * (images.length - 1);
        }

        if (showOuterBorder) {
          totalCropHeight += 2 * outerBorderWidth;
        }

        final totalWidth =
            maxWidth + (showOuterBorder ? 2 * outerBorderWidth : 0);

        final fullSize = Size(totalWidth, totalCropHeight);

        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: totalWidth / 2),
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: CustomPaint(
                  size: fullSize,
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

  Widget _buildBottomButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.toOpacity(0.35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isReorderMode && !isCroppingMode) ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.color_lens),
                      label: Text("Border Color".tl),
                      onPressed: _showBorderSettings,
                    ),
                    const SizedBox(width: 20),
                  ],
                  if (!isCroppingMode)
                    ElevatedButton.icon(
                      icon: Icon(isReorderMode ? Icons.check : Icons.sort),
                      label: Text(
                        isReorderMode ? "Finish Sorting".tl : "Sort Images".tl,
                      ),
                      onPressed: () {
                        setState(() {
                          isReorderMode = !isReorderMode;
                        });
                      },
                    ),
                  if (!isReorderMode && !isCroppingMode)
                    const SizedBox(width: 20),
                  if (!isReorderMode) ...[
                    ElevatedButton.icon(
                      icon: Icon(isCroppingMode ? Icons.check : Icons.crop),
                      label: Text(
                        isCroppingMode ? "Finish Cropping".tl : "Crop Image".tl,
                      ),
                      onPressed: () {
                        setState(() {
                          isCroppingMode = !isCroppingMode;
                        });
                      },
                    ),
                  ],
                  if (isCroppingMode) ...[
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.vertical_align_center),
                      label: Text("Uniform Height".tl),
                      onPressed: () {
                        double targetHeight = cropHeights.length > 1
                            ? cropHeights[1]
                            : 120.0;
                        final controller = TextEditingController(
                          text: targetHeight.toStringAsFixed(0),
                        );

                        showGeneralDialog(
                          context: context,
                          barrierDismissible: true,
                          barrierLabel: 'Set Uniform Height'.tl,
                          barrierColor: Colors.black.toOpacity(0.3),
                          pageBuilder:
                              (context, animation, secondaryAnimation) {
                                return Center(
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                      sigmaX: 8,
                                      sigmaY: 8,
                                    ),
                                    child: Material(
                                      color: Colors.black.toOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 650,
                                        padding: const EdgeInsets.all(16),
                                        child: StatefulBuilder(
                                          builder: (context, setStates) {
                                            void updateHeight(double value) {
                                              targetHeight = value.clamp(
                                                0.0,
                                                5000.0,
                                              );

                                              final newText = targetHeight
                                                  .toStringAsFixed(0);

                                              if (controller.text != newText) {
                                                controller.text = newText;
                                                controller.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset: newText.length,
                                                      ),
                                                    );
                                              }
                                            }

                                            return Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  "Set Uniform Height".tl,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleLarge,
                                                ),
                                                const SizedBox(height: 16),
                                                Slider(
                                                  min: 10.0,
                                                  max: 1080.0,
                                                  value: targetHeight.clamp(
                                                    50.0,
                                                    1080.0,
                                                  ),
                                                  onChanged: (value) {
                                                    setStates(
                                                      () => updateHeight(value),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 20),
                                                TextField(
                                                  controller: controller,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration: InputDecoration(
                                                    labelText: 'Height(px)'.tl,
                                                    border:
                                                        OutlineInputBorder(),
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                  onChanged: (value) {
                                                    final parsed =
                                                        double.tryParse(value);
                                                    if (parsed != null) {
                                                      setStates(
                                                        () => updateHeight(
                                                          parsed,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                                const SizedBox(height: 24),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    TextButton(
                                                      child: Text("Cancel".tl),
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(),
                                                    ),
                                                    ElevatedButton(
                                                      child: Text("Apply".tl),
                                                      onPressed: () {
                                                        for (
                                                          int i = 1;
                                                          i <
                                                              cropHeights
                                                                  .length;
                                                          i++
                                                        ) {
                                                          cropHeights[i] =
                                                              targetHeight;
                                                        }
                                                        setState(() {});
                                                        Navigator.of(
                                                          context,
                                                        ).pop();
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                        );
                      },
                    ),
                  ],
                  if (!isReorderMode && !isCroppingMode) ...[
                    const SizedBox(width: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text("Save Long Image".tl),
                      onPressed: () => _captureAndSaveLongImage(context),
                    ),
                  ],
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
        title: Text("Stitch Subtitles".tl),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
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
                      constraints: BoxConstraints(maxWidth: 650),
                      child: _buildCropListView(),
                    )
                  : _buildMainCanvasPreview(),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }
}
