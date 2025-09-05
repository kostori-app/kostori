import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';

class KostoriDialog {
  static Future<T?> show<T>({
    BuildContext? context,
    bool? clickMaskDismiss,
    VoidCallback? onDismiss,
    required WidgetBuilder builder,
  }) async {
    final ctx = context ?? App.rootContext;
    if (ctx.mounted) {
      try {
        final result = await showDialog<T>(
          context: ctx,
          barrierDismissible: clickMaskDismiss ?? true,
          builder: builder,
          routeSettings: const RouteSettings(name: 'KostoriDialog'),
        );
        onDismiss?.call();
        return result;
      } catch (e) {
        Log.addLog(LogLevel.error, 'Dialog Error', '$e');
        return null;
      }
    } else {
      Log.addLog(
        LogLevel.error,
        'Dialog Error',
        'Dialog Error: No context available to show the dialog',
      );
      return null;
    }
  }
}
