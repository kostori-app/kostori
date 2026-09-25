part of 'image_manipulation_page.dart';

class LongImagePainter extends CollagePainter {
  LongImagePainter({required this.images, required super.border});

  final List<ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    final contentWidth =
        size.width - (border.showOuterBorder ? 2 * border.outerBorderWidth : 0);
    double dy = border.showOuterBorder ? border.outerBorderWidth : 0;

    // 1. 画外边框
    if (border.showOuterBorder) {
      final outerPaint = Paint()..color = border.outerBorderColor;
      final outerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(border.outerBorderRadius),
      );
      canvas.drawRRect(outerRect, outerPaint);
    }

    // 2. 画图像
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final scale = contentWidth / img.width;
      final targetHeight = img.height * scale;

      final dstRect = Rect.fromLTWH(
        border.showOuterBorder ? border.outerBorderWidth : 0,
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
      if (border.showInnerBorders && i < images.length - 1) {
        final innerPaint = Paint()
          ..color = border.innerBorderColor
          ..style = PaintingStyle.fill;

        final double left = border.showOuterBorder
            ? border.outerBorderWidth
            : 0;
        final right = left + contentWidth;
        final bottom = dy + border.innerBorderWidth;

        canvas.drawRect(Rect.fromLTRB(left, dy, right, bottom), innerPaint);

        dy += border.innerBorderWidth;
      }
    }
  }

  @override
  bool contentChanged(covariant LongImagePainter oldDelegate) =>
      oldDelegate.images != images;
}

class RenderLongPicPage extends CollageEditorPage {
  const RenderLongPicPage({super.key, required super.images});

  @override
  ConsumerState<RenderLongPicPage> createState() => _RenderLongPicPageState();
}

class _RenderLongPicPageState extends CollageEditorState<RenderLongPicPage> {
  @override
  String get title => t.stitchLongImage;

  @override
  CustomPainter buildPainter(
    List<ui.Image> images,
    CollageBorderStyle border,
  ) => LongImagePainter(images: images, border: border);

  @override
  Size computeCanvasSize(List<ui.Image> images, CollageBorderStyle border) {
    // 以最窄图片为内容宽度
    final contentWidth = images
        .map((img) => img.width)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    final contentHeights = images.map(
      (img) => img.height * (contentWidth / img.width),
    );
    final totalInnerBorders = border.showInnerBorders
        ? (images.length - 1) * border.innerBorderWidth
        : 0.0;
    final totalHeight =
        contentHeights.fold(0.0, (a, b) => a + b) + totalInnerBorders;

    return Size(
      border.showOuterBorder
          ? contentWidth + border.outerBorderWidth * 2
          : contentWidth,
      border.showOuterBorder
          ? totalHeight + border.outerBorderWidth * 2
          : totalHeight,
    );
  }
}
