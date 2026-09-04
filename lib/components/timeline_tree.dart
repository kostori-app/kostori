import 'package:flutter/material.dart';

/// 自绘的树状分支时间线节点（不依赖 timeline_tile，可任意嵌套）。
///
/// 渲染：每个节点左边有一条纵向主线，从上一节点延续到下一节点；
/// 节点头部圆点落在该线上，更深一层的内容往右缩进，形成「年→月→日→记录」分支。
class TimelineTreeNode extends StatelessWidget {
  const TimelineTreeNode({
    super.key,
    required this.title,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
    this.dotSize = 12,
    this.titleIndent = 28,
    this.childrenIndent = 30,
    this.titleHeight,
    this.leadingDot = true,
    this.children = const [],
  });

  /// 节点标题（第一行内容）
  final Widget title;

  /// 圆点颜色
  final Color color;

  /// 是否是父级里的第一个/最后一个节点（决定上下两段线要不要画）
  final bool isFirst;
  final bool isLast;

  /// 圆点直径（竖直主线画在圆点中心位置）
  final double dotSize;

  /// 标题相对左侧主线的缩进
  final double titleIndent;

  /// 子级相对本节点的缩进
  final double childrenIndent;

  /// 标题行固定高度；为 null 时按内容自适应（用于叶子内容较高等情况）
  final double? titleHeight;

  /// 是否绘制左侧圆点与主线（叶子行可为 false，仅缩进展示）
  final bool leadingDot;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final titleRow = leadingDot
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: titleIndent,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Center(
                    child: SizedBox(
                      width: dotSize,
                      height: dotSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: title),
            ],
          )
        : Padding(
            padding: EdgeInsets.only(left: titleIndent),
            child: Align(
              alignment: Alignment.centerLeft,
              child: title,
            ),
          );

    final double dotX = titleIndent / 2;
    final double dotCenterY = dotSize / 2 + 2;

    return Stack(
      children: [
        if (leadingDot)
          Positioned.fill(
            child: CustomPaint(
              painter: _TreeBranchPainter(
                dotX: dotX,
                dotY: dotCenterY,
                dotSize: dotSize,
                dotColor: color,
                lineColor: color.withValues(alpha: 0.35),
                drawTop: !isFirst,
                drawBottom: !isLast,
                thickness: 1.6,
              ),
            ),
          ),
        if (children.isEmpty)
          titleRow
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: children.isEmpty ? 0 : 4),
                child: titleHeight != null
                    ? SizedBox(height: titleHeight, child: titleRow)
                    : titleRow,
              ),
              Padding(
                padding: EdgeInsets.only(left: childrenIndent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 在节点整块高度内绘制竖线：上段（前一个兄弟延续下来）→ 圆点 → 下段（延续到后一个兄弟）
class _TreeBranchPainter extends CustomPainter {
  const _TreeBranchPainter({
    required this.dotX,
    required this.dotY,
    required this.dotSize,
    required this.dotColor,
    required this.lineColor,
    required this.drawTop,
    required this.drawBottom,
    required this.thickness,
  });

  final double dotX;
  final double dotY;
  final double dotSize;
  final Color dotColor;
  final Color lineColor;
  final bool drawTop;
  final bool drawBottom;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    if (drawTop) {
      canvas.drawLine(
        Offset(dotX, 0),
        Offset(dotX, dotY),
        paint,
      );
    }
    if (drawBottom) {
      canvas.drawLine(
        Offset(dotX, dotY),
        Offset(dotX, size.height),
        paint,
      );
    }
    canvas.drawCircle(
      Offset(dotX, dotY),
      dotSize / 2,
      Paint()..color = dotColor,
    );
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) =>
      oldDelegate.dotX != dotX ||
      oldDelegate.dotY != dotY ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.drawTop != drawTop ||
      oldDelegate.drawBottom != drawBottom;
}
