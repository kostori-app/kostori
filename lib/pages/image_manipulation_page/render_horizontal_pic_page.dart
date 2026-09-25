part of 'image_manipulation_page.dart';

class HorizontalImagePainter extends CollagePainter {
  HorizontalImagePainter({required this.images, required super.border});

  final List<ui.Image> images;

  @override
  void paint(Canvas canvas, Size size) {
    final contentHeight =
        size.height -
        (border.showOuterBorder ? 2 * border.outerBorderWidth : 0);
    double dx = border.showOuterBorder ? border.outerBorderWidth : 0;

    // 画外边框
    if (border.showOuterBorder) {
      final outerPaint = Paint()..color = border.outerBorderColor;
      final outerRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(border.outerBorderRadius),
      );
      canvas.drawRRect(outerRect, outerPaint);
    }

    // 按 contentHeight 固定缩放图片，宽度随比例变化
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final scale = contentHeight / img.height;
      final targetWidth = img.width * scale;

      final dstRect = Rect.fromLTWH(
        dx,
        border.showOuterBorder ? border.outerBorderWidth : 0,
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
      if (border.showInnerBorders && i < images.length - 1) {
        final innerPaint = Paint()
          ..color = border.innerBorderColor
          ..style = PaintingStyle.fill;

        final double top = border.showOuterBorder ? border.outerBorderWidth : 0;
        final bottom = top + contentHeight;

        canvas.drawRect(
          Rect.fromLTRB(dx, top, dx + border.innerBorderWidth, bottom),
          innerPaint,
        );

        dx += border.innerBorderWidth;
      }
    }
  }

  @override
  bool contentChanged(covariant HorizontalImagePainter oldDelegate) =>
      oldDelegate.images != images;
}

class RenderHorizontalPicPage extends CollageEditorPage {
  const RenderHorizontalPicPage({super.key, required super.images});

  @override
  ConsumerState<RenderHorizontalPicPage> createState() =>
      _RenderHorizontalPicPageState();
}

class _RenderHorizontalPicPageState
    extends CollageEditorState<RenderHorizontalPicPage> {
  @override
  String get title => t.stitchHorizontalImage;

  @override
  EdgeInsets get reorderItemPadding => const EdgeInsets.symmetric(vertical: 8);

  @override
  CustomPainter buildPainter(
    List<ui.Image> images,
    CollageBorderStyle border,
  ) => HorizontalImagePainter(images: images, border: border);

  @override
  Size computeCanvasSize(List<ui.Image> images, CollageBorderStyle border) {
    // 以最矮图片为内容高度
    final contentHeight = images
        .map((img) => img.height)
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
    final contentWidths = images.map(
      (img) => img.width * (contentHeight / img.height),
    );
    final totalInnerBorders = border.showInnerBorders
        ? (images.length - 1) * border.innerBorderWidth
        : 0.0;
    final totalWidth =
        contentWidths.fold(0.0, (a, b) => a + b) + totalInnerBorders;

    return Size(
      border.showOuterBorder
          ? totalWidth + border.outerBorderWidth * 2
          : totalWidth,
      border.showOuterBorder
          ? contentHeight + border.outerBorderWidth * 2
          : contentHeight,
    );
  }
}
