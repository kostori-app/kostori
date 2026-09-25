part of 'image_manipulation_page.dart';

/// 九宫格列数：少于 3 张时按实际张数排一行，其余固定 3 列。
int nineGridColumns(int count) => count < 3 ? count : 3;

/// 单元格逻辑边长：取所有图片较长边的最大值，并限制上限避免导出过大。
double nineGridCellSize(List<ui.Image> images) {
  final maxDim = images
      .map((img) => math.max(img.width, img.height))
      .reduce(math.max)
      .toDouble();
  return math.min(maxDim, 1080.0);
}

class NineGridPainter extends CollagePainter {
  NineGridPainter({
    required this.images,
    required this.cellSize,
    required this.columns,
    required super.border,
  });

  final List<ui.Image> images;
  final double cellSize;
  final int columns;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = border.showOuterBorder ? border.outerBorderWidth : 0.0;

    // 1. 外边框
    if (border.showOuterBorder) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(border.outerBorderRadius),
        ),
        Paint()..color = border.outerBorderColor,
      );
    }

    // 2. 裁剪内容区域（圆角）
    final contentRect = Rect.fromLTWH(
      outer,
      outer,
      size.width - outer * 2,
      size.height - outer * 2,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        contentRect,
        Radius.circular(border.showOuterBorder ? border.outerBorderRadius : 0),
      ),
    );

    final gap = border.showInnerBorders ? border.innerBorderWidth : 0.0;
    // 先铺内边框色，单元格之间的空隙与不满行的留白都会显示该色
    if (border.showInnerBorders) {
      canvas.drawRect(contentRect, Paint()..color = border.innerBorderColor);
    }

    final contentWidth = columns * cellSize + (columns - 1) * gap;

    for (int i = 0; i < images.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      // 不满一行的居中排布
      final rowCount = math.min(columns, images.length - row * columns);
      final rowWidth = rowCount * cellSize + (rowCount - 1) * gap;
      final rowStartX = contentRect.left + (contentWidth - rowWidth) / 2;

      final dst = Rect.fromLTWH(
        rowStartX + col * (cellSize + gap),
        contentRect.top + row * (cellSize + gap),
        cellSize,
        cellSize,
      );
      _drawCover(canvas, images[i], dst);
    }

    canvas.restore();
  }

  /// 以 cover 方式把图片居中裁切铺满 [dst]（保持比例，不拉伸）。
  void _drawCover(Canvas canvas, ui.Image image, Rect dst) {
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    final dstAspect = dst.width / dst.height;
    final srcAspect = iw / ih;

    final Rect src;
    if (srcAspect > dstAspect) {
      final w = ih * dstAspect;
      src = Rect.fromLTWH((iw - w) / 2, 0, w, ih);
    } else {
      final h = iw / dstAspect;
      src = Rect.fromLTWH(0, (ih - h) / 2, iw, h);
    }
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool contentChanged(covariant NineGridPainter oldDelegate) =>
      oldDelegate.images != images ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.columns != columns;
}

class RenderNineGridPage extends CollageEditorPage {
  const RenderNineGridPage({super.key, required super.images});

  @override
  ConsumerState<RenderNineGridPage> createState() => _RenderNineGridPageState();
}

class _RenderNineGridPageState extends CollageEditorState<RenderNineGridPage> {
  @override
  String get title => t.stitchNineGrid;

  @override
  CustomPainter buildPainter(
    List<ui.Image> images,
    CollageBorderStyle border,
  ) => NineGridPainter(
    images: images,
    cellSize: nineGridCellSize(images),
    columns: nineGridColumns(images.length),
    border: border,
  );

  @override
  Size computeCanvasSize(List<ui.Image> images, CollageBorderStyle border) {
    final columns = nineGridColumns(images.length);
    final cell = nineGridCellSize(images);
    final gap = border.showInnerBorders ? border.innerBorderWidth : 0.0;
    final rows = (images.length / columns).ceil();
    final outer = border.showOuterBorder ? border.outerBorderWidth * 2 : 0.0;

    return Size(
      columns * cell + (columns - 1) * gap + outer,
      rows * cell + (rows - 1) * gap + outer,
    );
  }
}
