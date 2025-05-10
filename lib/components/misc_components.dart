import 'package:flutter/material.dart';
import 'package:kostori/utils/extension.dart';

class MiscComponents {
  MiscComponents._();

  static Widget placeholder(BuildContext context, double width, double height) {
    return Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onInverseSurface
              .withValues(alpha: 0.4),
        ),
        child: Center(
          child: Image.asset(
            'assets/image_loading.gif',
            width: width,
            height: height,
            cacheWidth: width.cacheSize(context),
            cacheHeight: height.cacheSize(context),
          ),
        ));
  }
}
