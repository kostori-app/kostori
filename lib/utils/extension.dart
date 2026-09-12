import 'package:flutter/material.dart';

extension ImageExtension on num {
  int cacheSize(BuildContext context) {
    return (this * MediaQuery.devicePixelRatioOf(context)).round();
  }
}

