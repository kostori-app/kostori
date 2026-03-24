import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app_page_route.dart';
import 'package:kostori/foundation/blur_fade_route.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';

extension Navigation on BuildContext {
  void pop<T>([T? result]) {
    if (mounted) {
      Navigator.of(this).pop(result);
    }
  }

  bool canPop() {
    return Navigator.of(this).canPop();
  }

  Future<T?> to<T>(Widget Function() builder) {
    return Navigator.of(
      this,
    ).push<T>(AppPageRoute(builder: (context) => builder()));
  }

  Future<void> toReplacement<T>(Widget Function() builder) {
    return Navigator.of(
      this,
    ).pushReplacement(AppPageRoute(builder: (context) => builder()));
  }

  Future<T?> toBlurFade<T>(Widget Function() builder) {
    return Navigator.of(
      this,
    ).push<T>(BlurFadeRoute(builder: (context) => builder()));
  }

  double get width => MediaQuery.of(this).size.width;

  double get height => MediaQuery.of(this).size.height;

  EdgeInsets get padding => MediaQuery.of(this).padding;

  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  Brightness get brightness => Theme.of(this).brightness;

  bool get isDarkMode => brightness == Brightness.dark;

  void showMessage({
    required String message,
    Widget? icon,
    Widget? trailing,
    int? seconds,
    LogLevel level = LogLevel.info,
    ToastStyle style = ToastStyle.bottom,
  }) {
    ToastManager.show(
      message: message,
      context: this,
      icon: icon,
      trailing: trailing,
      seconds: seconds,
      level: level,
      style: style,
    );
  }

  Color useBackgroundColor(MaterialColor color) {
    return color[brightness == Brightness.light ? 100 : 800]!;
  }

  Color useTextColor(MaterialColor color) {
    return color[brightness == Brightness.light ? 800 : 100]!;
  }
}

extension ContextI18n on BuildContext {
  Translations get t => Translations.of(this);
}
