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
    App.rootContext.showMessage(message: 'Saving'.tl);
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
      final image = await picture.toImage(
        fullWidth.toInt(),
        fullHeight.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await Utils.saveLongImage(context, bytes);
        final notifier = ref.read(imagesProvider.notifier);
        await notifier.loadImages();
        App.rootContext.showMessage(message: 'Save Successful'.tl);
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: 'Save Failed: @e'.tlParams({'e': e}),
      );
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
    return FutureBuilder<List<ui.Image>>(
      future: _loadUiImages(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return Center(child: Text('Failed to load images or no images'.tl));
        }

        final images = snapshot.data!;
        if (images.isEmpty) return const SizedBox();

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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _showBorderSettings,
                    child: Text('Border Color'.tl),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () => _captureAndSaveLongImage(context),
                    child: Text('Save Long Image'.tl),
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
        title: Text('Stitch Horizontal Image'.tl),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMainCanvasPreview()),
          _buildBottomButtons(),
        ],
      ),
    );
  }
}
