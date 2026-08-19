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

  /// 解码后的图片缓存：避免每次 build 都重新解码（性能关键）
  List<ui.Image>? _uiImages;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    imageList = List.of(widget.images);
    // 先给默认值，避免异步加载尺寸前被访问导致 late 初始化异常
    imageSizes = List.generate(imageList.length, (_) => const Size(0, 0));
    cropHeights = List.filled(imageList.length, 125);
    _loadImagesInfo();
    _ensureImages().then((_) {
      if (mounted) setState(() {});
    });
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

  Future<List<ui.Image>> _ensureImages() async {
    var images = _uiImages;
    if (images == null) {
      images = await _loadUiImages();
      _uiImages = images;
    }
    return images;
  }

  /// 确保 cropHeights / imageSizes 与 imageList 同步（重排、移除后调用）
  void _syncIndexedData() {
    if (cropHeights.length > imageList.length) {
      cropHeights = List.of(cropHeights.take(imageList.length));
    }
    if (imageSizes.length > imageList.length) {
      imageSizes = List.of(imageSizes.take(imageList.length));
    }
    if (cropHeights.isNotEmpty && imageSizes.isNotEmpty) {
      // 首位角色裁剪高度为新首图全高
      cropHeights[0] = imageSizes[0].height;
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex--;
      final item = imageList.removeAt(oldIndex);
      imageList.insert(newIndex, item);
      final images = _uiImages;
      if (images != null) {
        final img = images.removeAt(oldIndex);
        images.insert(newIndex, img);
      }
      if (oldIndex < imageSizes.length) {
        final size = imageSizes.removeAt(oldIndex);
        imageSizes.insert(newIndex, size);
      }
      if (oldIndex < cropHeights.length) {
        final crop = cropHeights.removeAt(oldIndex);
        cropHeights.insert(newIndex, crop);
      }
      _syncIndexedData();
    });
  }

  void _removeImage(int index) {
    if (index < 0 || index >= imageList.length) return;
    setState(() {
      imageList.removeAt(index);
      _uiImages?.removeAt(index);
      if (index < imageSizes.length) imageSizes.removeAt(index);
      if (index < cropHeights.length) cropHeights.removeAt(index);
      _syncIndexedData();
    });
  }

  /// 渲染并导出对话长图为 PNG 字节（保留原始高分辨率导出）
  Future<Uint8List?> _renderDialogueBytes(BuildContext context) async {
    // 读取配置项
    final outerBorderColor = ref.read(outerBorderColorProvider);
    final outerBorderWidth = ref.read(outerBorderWidthProvider);
    final outerBorderRadius = ref.read(outerBorderRadiusProvider);
    final showOuterBorder = ref.read(showOuterBorderProvider);

    final showInnerBorders = ref.read(showInnerBordersProvider);
    final innerBorderColor = ref.read(innerBorderColorProvider);
    final innerBorderWidth = ref.read(innerBorderWidthProvider);

    final images = await _ensureImages();
    if (images.isEmpty) return null;

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

    final totalWidth = maxWidth + (showOuterBorder ? 2 * outerBorderWidth : 0);
    final fullSize = Size(totalWidth, totalCropHeight);

    // 获取设备像素比，缩放画布保证清晰度
    final dpr = MediaQuery.of(context).devicePixelRatio;

    return composePainterToPng(
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
      size: fullSize,
      dpr: dpr,
    );
  }

  /// 复制到剪贴板（桌面）或分享（移动端），同时保存一份到 Kostori 文件夹
  Future<void> _copyOrShareDialogueImage() async {
    try {
      final bytes = await _renderDialogueBytes(context);
      if (bytes == null) return;
      await ImageSaver.saveOrShareImage(
        bytes: bytes,
        filename: '拼图_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await ref.read(imagesProvider.notifier).loadImages();
    } catch (e, st) {
      debugPrint('复制/分享长图异常: $e\n$st');
      App.rootContext.showMessage(
        message: t.saveFailedWithError(e: e.toString()),
      );
    }
  }

  Widget _buildReorderView() {
    return ReorderableListView(
      onReorderItem: _onReorder,
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
              child: Stack(
                children: [
                  Image.file(imageList[i], fit: BoxFit.fitWidth),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
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
      builder: (_) => const BorderSettingsSheet(),
    );
  }

  Widget _buildCropListView() {
    const double baseDisplayWidth = 650;

    // 尺寸尚未加载完成时先显示加载态，避免越界
    if (imageSizes.length != imageList.length ||
        cropHeights.length != imageList.length) {
      return const Center(child: PolygonRefreshIndicator());
    }

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
                    if (index != 0)
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
                                t.cropHeightCPx(c: crop.toStringAsFixed(0)),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (index == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      t.firstImageFullHeight,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
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

    final images = _uiImages;
    if (images == null) {
      return const Center(child: PolygonRefreshIndicator());
    }
    if (images.isEmpty) {
      return Center(child: Text(t.noImages));
    }

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

    final totalWidth = maxWidth + (showOuterBorder ? 2 * outerBorderWidth : 0);

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
  }

  /// 统一高度设置对话框
  void _showUniformHeightDialog() {
    double targetHeight = cropHeights.length > 1 ? cropHeights[1] : 120.0;
    final controller = TextEditingController(
      text: targetHeight.toStringAsFixed(0),
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: t.setUniformHeight,
      barrierColor: Colors.black.toOpacity(0.3),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.black.toOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 650,
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                  builder: (context, setStates) {
                    void updateHeight(double value) {
                      targetHeight = value.clamp(0.0, 5000.0);
                      final newText = targetHeight.toStringAsFixed(0);
                      if (controller.text != newText) {
                        controller.text = newText;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: newText.length),
                        );
                      }
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.setUniformHeight,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          min: 10.0,
                          max: 1080.0,
                          value: targetHeight.clamp(50.0, 1080.0),
                          onChanged: (value) {
                            setStates(() => updateHeight(value));
                          },
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: t.heightPx,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) {
                            final parsed = double.tryParse(value);
                            if (parsed != null) {
                              setStates(() => updateHeight(parsed));
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              child: Text(t.cancel),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            ElevatedButton(
                              child: Text(t.apply),
                              onPressed: () {
                                for (int i = 1; i < cropHeights.length; i++) {
                                  cropHeights[i] = targetHeight;
                                }
                                setState(() {});
                                Navigator.of(context).pop();
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
  }

  Widget _buildBottomButtons() {
    return _FrostedBottomBar(
      children: [
        if (isReorderMode)
          _BottomIconAction(
            icon: Icons.check,
            tooltip: t.finishSorting,
            onPressed: () => setState(() => isReorderMode = false),
          )
        else if (isCroppingMode) ...[
          _BottomIconAction(
            icon: Icons.vertical_align_center,
            tooltip: t.uniformHeight,
            onPressed: _showUniformHeightDialog,
          ),
          _BottomIconAction(
            icon: Icons.check,
            tooltip: t.finishCropping,
            onPressed: () => setState(() => isCroppingMode = false),
          ),
        ] else ...[
          _BottomIconAction(
            icon: Icons.color_lens,
            tooltip: t.borderColor,
            onPressed: _showBorderSettings,
          ),
          _BottomIconAction(
            icon: Icons.sort,
            tooltip: t.sortImages,
            onPressed: () => setState(() => isReorderMode = true),
          ),
          _BottomIconAction(
            icon: Icons.crop,
            tooltip: t.cropImage,
            onPressed: () => setState(() => isCroppingMode = true),
          ),
          _BottomIconAction(
            icon: Icons.save_alt,
            tooltip: t.saveAndShare,
            onPressed: _copyOrShareDialogueImage,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isReorderMode && !isCroppingMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() {
            if (isReorderMode) {
              isReorderMode = false;
            } else if (isCroppingMode) {
              isCroppingMode = false;
            }
          });
        }
      },
      child: Scaffold(
        appBar: Appbar(
          title: Text(t.stitchSubtitles),
          backgroundColor: Colors.transparent,
          leading: _ModeAwareBackButton(
            reorderMode: isReorderMode,
            cropMode: isCroppingMode,
            onExitMode: () => setState(() {
              if (isReorderMode) {
                isReorderMode = false;
              } else if (isCroppingMode) {
                isCroppingMode = false;
              }
            }),
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
      ),
    );
  }
}
