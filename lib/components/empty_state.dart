import 'package:flutter/material.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 访问成功但数据为空时的无条目空态提示。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.retry,
    this.retryText,
  });

  final String message;

  final VoidCallback? retry;

  final String? retryText;

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      icon: Icons.inbox_outlined,
      iconColor: Theme.of(context).colorScheme.outline,
      message: message,
      retry: retry,
      retryText: retryText,
    );
  }
}

/// 访问失败时的错误提示。
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.retry,
    this.retryText,
  });

  final String message;

  final VoidCallback? retry;

  final String? retryText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _CenteredState(
      icon: Icons.error_outline,
      iconColor: scheme.error,
      messageColor: scheme.error,
      message: message,
      retry: retry,
      retryText: retryText,
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.iconColor,
    required this.message,
    this.messageColor,
    this.retry,
    this.retryText,
  });

  final IconData icon;

  final Color iconColor;

  final String message;

  final Color? messageColor;

  final VoidCallback? retry;

  final String? retryText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: messageColor ?? Theme.of(context).textTheme.titleSmall?.color,
              ),
            ),
          ),
          if (retry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: retry,
              child: Text(retryText ?? t.retry),
            ),
          ],
        ],
      ),
    );
  }
}
