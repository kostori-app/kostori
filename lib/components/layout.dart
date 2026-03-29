part of 'components.dart';

class SliverGridViewWithFixedItemHeight extends StatelessWidget {
  const SliverGridViewWithFixedItemHeight({
    required this.delegate,
    required this.maxCrossAxisExtent,
    required this.itemHeight,
    super.key,
  });

  final SliverChildDelegate delegate;

  final double maxCrossAxisExtent;

  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverGrid(
        delegate: delegate,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          childAspectRatio: calcChildAspectRatio(constraints.crossAxisExtent),
        ),
      ),
    );
  }

  double calcChildAspectRatio(double width) {
    var crossItems = width ~/ maxCrossAxisExtent;
    if (width % maxCrossAxisExtent != 0) {
      crossItems += 1;
    }
    final itemWidth = width / crossItems;
    return itemWidth / itemHeight;
  }
}

class SliverGridDelegateWithFixedHeight extends SliverGridDelegate {
  const SliverGridDelegateWithFixedHeight({
    required this.maxCrossAxisExtent,
    required this.itemHeight,
  });

  final double maxCrossAxisExtent;

  final double itemHeight;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final width = constraints.crossAxisExtent;
    var crossItems = width ~/ maxCrossAxisExtent;
    if (width % maxCrossAxisExtent != 0) {
      crossItems += 1;
    }
    return SliverGridRegularTileLayout(
      crossAxisCount: crossItems,
      mainAxisStride: itemHeight,
      crossAxisStride: width / crossItems,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: width / crossItems,
      reverseCrossAxis: false,
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithFixedHeight) return true;
    if (oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.itemHeight != itemHeight) {
      return true;
    }
    return false;
  }
}

class SliverGridDelegateWithAnimes extends SliverGridDelegate {
  SliverGridDelegateWithAnimes({this.fixedCrossAxisCount});

  final int? fixedCrossAxisCount;

  final bool useBriefMode = appdata.settings['animeDisplayMode'] == 'brief';

  final double scale = (appdata.settings['animeTileScale'] as num).toDouble();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (useBriefMode) {
      return getBriefModeLayout(constraints, scale);
    } else {
      return getDetailedModeLayout(constraints, scale);
    }
  }

  SliverGridLayout getDetailedModeLayout(
    SliverConstraints constraints,
    double scale,
  ) {
    const minCrossAxisExtent = 360;
    final itemHeight = 152 * scale;
    final width = constraints.crossAxisExtent;
    int crossItems;
    if (fixedCrossAxisCount != null) {
      crossItems = fixedCrossAxisCount!;
    } else {
      crossItems = width ~/ minCrossAxisExtent;
      crossItems = math.max(1, crossItems);
    }
    return SliverGridRegularTileLayout(
      crossAxisCount: crossItems,
      mainAxisStride: itemHeight,
      crossAxisStride: width / crossItems,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: width / crossItems,
      reverseCrossAxis: false,
    );
  }

  SliverGridLayout getBriefModeLayout(
    SliverConstraints constraints,
    double scale,
  ) {
    int crossAxisCount;
    if (fixedCrossAxisCount != null) {
      crossAxisCount = fixedCrossAxisCount!;
    } else {
      final maxCrossAxisExtent = 192.0 * scale;
      const crossAxisSpacing = 0.0;
      crossAxisCount =
          (constraints.crossAxisExtent /
                  (maxCrossAxisExtent + crossAxisSpacing))
              .ceil();
      crossAxisCount = math.max(1, crossAxisCount);
    }
    const childAspectRatio = 0.68;
    const crossAxisSpacing = 0.0;
    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = childCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithAnimes) return true;
    if (oldDelegate.scale != scale ||
        oldDelegate.useBriefMode != useBriefMode ||
        oldDelegate.fixedCrossAxisCount != fixedCrossAxisCount) {
      return true;
    }
    return false;
  }
}

class SliverLazyToBoxAdapter extends StatelessWidget {
  /// Creates a sliver that contains a single box widget which can be lazy loaded.
  const SliverLazyToBoxAdapter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverList.list(children: [SizedBox(), child]);
  }
}

class SliverGridDelegateWithBangumiItems extends SliverGridDelegate {
  SliverGridDelegateWithBangumiItems(
    this.useBriefMode, {
    this.fixedCrossAxisCount,
  });

  final bool useBriefMode;
  final int? fixedCrossAxisCount;
  final double scale = 1.toDouble();

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    if (useBriefMode) {
      return getBriefModeLayout(constraints, scale);
    } else {
      return getDetailedModeLayout(constraints, scale);
    }
  }

  SliverGridLayout getDetailedModeLayout(
    SliverConstraints constraints,
    double scale,
  ) {
    const minCrossAxisExtent = 360;
    final itemHeight = 192 * scale;

    int crossAxisCount;
    if (fixedCrossAxisCount != null) {
      crossAxisCount = fixedCrossAxisCount!;
    } else {
      crossAxisCount = (constraints.crossAxisExtent / minCrossAxisExtent)
          .floor();
      crossAxisCount = math.min(3, math.max(1, crossAxisCount));
    }

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: itemHeight,
      crossAxisStride: constraints.crossAxisExtent / crossAxisCount,
      childMainAxisExtent: itemHeight,
      childCrossAxisExtent: constraints.crossAxisExtent / crossAxisCount,
      reverseCrossAxis: false,
    );
  }

  SliverGridLayout getBriefModeLayout(
    SliverConstraints constraints,
    double scale,
  ) {
    final maxCrossAxisExtent = 192.0 * scale;
    const childAspectRatio = 0.68;
    const crossAxisSpacing = 0.0;

    int crossAxisCount;
    if (fixedCrossAxisCount != null) {
      crossAxisCount = fixedCrossAxisCount!;
    } else {
      crossAxisCount =
          (constraints.crossAxisExtent /
                  (maxCrossAxisExtent + crossAxisSpacing))
              .ceil();
      crossAxisCount = math.max(1, crossAxisCount);
    }

    final double usableCrossAxisExtent = math.max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = childCrossAxisExtent / childAspectRatio;

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(covariant SliverGridDelegate oldDelegate) {
    if (oldDelegate is! SliverGridDelegateWithBangumiItems) return true;
    if (oldDelegate.scale != scale ||
        oldDelegate.useBriefMode != useBriefMode ||
        oldDelegate.fixedCrossAxisCount != fixedCrossAxisCount) {
      return true;
    }
    return false;
  }
}
