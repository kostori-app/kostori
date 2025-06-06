import 'package:flutter/material.dart';

class MiscComponents {
  MiscComponents._();

  static Widget placeholder(BuildContext context, double? width, double? height,
      [Color? color]) {
    final effectiveColor = color ??
        Theme.of(context).colorScheme.onInverseSurface.withValues(alpha: 0.4);

    return Container(
      width: width ?? 100.0,
      height: height ?? 100.0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: effectiveColor,
      ),
      child: Center(
        child: Image.asset(
          'assets/img/image_loading.gif',
          width: (width ?? 100.0) > 100 ? 100 : width,
          height: (height ?? 100.0) > 100 ? 100 : height,
          // cacheWidth: ((width > 100 ? 100 : width) / 2).cacheSize(context),
          // cacheHeight: ((height > 100 ? 100 : height) / 2).cacheSize(context),
        ),
      ),
    );
  }
}
