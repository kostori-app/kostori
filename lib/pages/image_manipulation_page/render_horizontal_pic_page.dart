part of 'image_manipulation_page.dart';

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

  /// 渲染并导出横图为 PNG 字节
  Future<Uint8List?> _renderHorizontalBytes() async {
    final outerBorderColor = ref.read(outerBorderColorProvider);
    final outerBorderWidth = ref.read(outerBorderWidthProvider);
    final outerBorderRadius = ref.read(outerBorderRadiusProvider);

    final innerBorderColor = ref.read(innerBorderColorProvider);
    final innerBorderWidth = ref.read(innerBorderWidthProvider);
    final showInnerBorders = ref.read(showInnerBordersProvider);
    final showOuterBorder = ref.read(showOuterBorderProvider);

    final images = await _ensureImages();
    if (images.isEmpty) return null;

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
    final totalInnerBorders = showInnerBorders
        ? (images.length - 1) * innerBorderWidth
        : 0.0;

    final totalWidth =
        contentWidths.fold(0.0, (a, b) => a + b) + totalInnerBorders;

    // 总宽高考虑外边框
    final fullWidth = showOuterBorder
        ? totalWidth + outerBorderWidth * 2
        : totalWidth;
    final fullHeight = showOuterBorder
        ? contentHeight + outerBorderWidth * 2
        : contentHeight;

    return composePainterToPng(
      painter: HorizontalImagePainter(
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

  /// 复制到剪贴板（桌面）或分享（移动端），同时保存一份到 Kostori 文件夹
  Future<void> _copyOrShareHorizontalImage() async {
    try {
      final bytes = await _renderHorizontalBytes();
      if (bytes == null) return;
      await ImageSaver.saveOrShareImage(
        bytes: bytes,
        filename: '拼图_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await ref.read(imagesProvider.notifier).loadImages();
    } catch (e) {
      App.rootContext.showMessage(message: t.saveFailedE(e: e));
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

    final contentHeight = images
        .map((img) => img.height)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();

    final contentWidths = images
        .map((img) => img.width * (contentHeight / img.height))
        .toList();

    final totalInnerBorders = showInnerBorders && images.length > 1
        ? (images.length - 1) * innerBorderWidth
        : 0.0;

    final totalWidth =
        contentWidths.fold(0.0, (sum, w) => sum + w) + totalInnerBorders;

    final fullWidth = showOuterBorder
        ? totalWidth + 2 * outerBorderWidth
        : totalWidth;
    final fullHeight = showOuterBorder
        ? contentHeight + 2 * outerBorderWidth
        : contentHeight;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: totalWidth / 4),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: fullWidth,
              height: fullHeight,
              child: CustomPaint(
                size: Size(fullWidth, fullHeight),
                painter: HorizontalImagePainter(
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
            onPressed: _copyOrShareHorizontalImage,
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
          title: Text(t.stitchHorizontalImage),
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
