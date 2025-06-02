import 'package:flutter/material.dart';
import 'package:kostori/utils/extension.dart';

class MiscComponents {
  MiscComponents._();

  static Widget placeholder(BuildContext context, double width, double height,
      [Color? color]) {
    final effectiveColor = color ??
        Theme.of(context).colorScheme.onInverseSurface.withValues(alpha: 0.4);

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: effectiveColor,
      ),
      child: Center(
        child: Image.asset(
          'assets/img/image_loading.gif',
          width: width,
          height: height,
          cacheWidth: (width / 2).cacheSize(context),
          cacheHeight: (height / 2).cacheSize(context),
        ),
      ),
    );
  }
}
