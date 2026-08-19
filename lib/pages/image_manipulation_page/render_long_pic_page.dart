part of 'image_manipulation_page.dart';

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

        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), innerPaint);

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

  /// 解码后的图片缓存：避免每次 build 都重新解码（性能关键）
  List<ui.Image>? _uiImages;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    imageList = List.of(widget.images);
    _ensureImages().then((_) {
      if (mounted) setState(() {});
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

  Future<List<ui.Image>> _ensureImages() async {
    var images = _uiImages;
    if (images == null) {
      images = await _loadUiImages();
      _uiImages = images;
    }
    return images;
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
    });
  }

  void _removeImage(int index) {
    if (index < 0 || index >= imageList.length) return;
    setState(() {
      imageList.removeAt(index);
      _uiImages?.removeAt(index);
    });
  }

  /// 渲染并导出长图为 PNG 字节
  Future<Uint8List?> _renderLongBytes() async {
    final outerBorderColor = ref.read(outerBorderColorProvider);
    final outerBorderWidth = ref.read(outerBorderWidthProvider);
    final outerBorderRadius = ref.read(outerBorderRadiusProvider);

    final innerBorderColor = ref.read(innerBorderColorProvider);
    final innerBorderWidth = ref.read(innerBorderWidthProvider);
    final showInnerBorders = ref.read(showInnerBordersProvider);
    final showOuterBorder = ref.read(showOuterBorderProvider);

    final images = await _ensureImages();
    if (images.isEmpty) return null;

    // 计算 contentWidth（图片宽度最小值）
    final contentWidth = images
        .map((img) => img.width)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();

    // 计算每张图片按contentWidth缩放后的高度列表
    final contentHeights = images
        .map((img) => img.height * (contentWidth / img.width))
        .toList();

    // 计算总高度（所有图片高 + 内边框总和）
    final totalInnerBorders = showInnerBorders
        ? (images.length - 1) * innerBorderWidth
        : 0.0;

    final totalHeight =
        contentHeights.fold(0.0, (a, b) => a + b) + totalInnerBorders;

    // 总宽高考虑外边框
    final fullWidth = showOuterBorder
        ? contentWidth + outerBorderWidth * 2
        : contentWidth;
    final fullHeight = showOuterBorder
        ? totalHeight + outerBorderWidth * 2
        : totalHeight;

    return composePainterToPng(
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
      size: Size(fullWidth, fullHeight),
      dpr: MediaQuery.of(context).devicePixelRatio,
    );
  }

  Future<void> _copyOrShareLongImage() async {
    try {
      final bytes = await _renderLongBytes();
      if (bytes == null) return;
      await ImageSaver.saveOrShareImage(
        bytes: bytes,
        filename: '拼图_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await ref.read(imagesProvider.notifier).loadImages();
    } catch (e) {
      App.rootContext.showMessage(message: t.saveFailedE(e: e.toString()));
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
      return Center(child: Text(t.failedToLoadImagesOrNoImages));
    }

    // 原地计算尺寸逻辑（与 _renderLongBytes 相同）
    final contentWidth = images
        .map((img) => img.width)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    final contentHeights = images
        .map((img) => img.height * (contentWidth / img.width))
        .toList();
    final totalInnerBorders = showInnerBorders
        ? (images.length - 1) * innerBorderWidth
        : 0.0;
    final totalHeight =
        contentHeights.fold(0.0, (a, b) => a + b) + totalInnerBorders;

    final fullWidth = showOuterBorder
        ? contentWidth + outerBorderWidth * 2
        : contentWidth;
    final fullHeight = showOuterBorder
        ? totalHeight + outerBorderWidth * 2
        : totalHeight;

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
        else ...[
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
            icon: Icons.save_alt,
            tooltip: t.saveAndShare,
            onPressed: _copyOrShareLongImage,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isReorderMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isReorderMode) {
          setState(() => isReorderMode = false);
        }
      },
      child: Scaffold(
        appBar: Appbar(
          title: Text(t.stitchLongImage),
          backgroundColor: Colors.transparent,
          leading: _ModeAwareBackButton(
            reorderMode: isReorderMode,
            cropMode: false,
            onExitMode: () => setState(() => isReorderMode = false),
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
              Positioned.fill(child: _buildMainCanvasPreview()),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }
}
