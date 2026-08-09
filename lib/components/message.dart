// ignore_for_file: use_build_context_synchronously

part of "components.dart";

enum ToastStyle { bottom, topRight, topLeft, top }

void showCenter({
  required String message,
  required BuildContext context,
  Widget? icon,
  Widget? trailing,
  int? seconds,
}) {
  var newEntry = OverlayEntry(
    builder: (context) =>
        _CenterOverlay(message: message, icon: icon, trailing: trailing),
  );

  var state = context.findAncestorStateOfType<OverlayWidgetState>();

  state?.addOverlay(newEntry);

  Timer(Duration(seconds: seconds ?? 2), () => state?.remove(newEntry));
}

class _CenterOverlay extends StatelessWidget {
  const _CenterOverlay({required this.message, this.icon, this.trailing});

  final String message;
  final Widget? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0 + MediaQuery.of(context).viewInsets.bottom,
      child: Align(
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.black.toOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              elevation: 2,
              textStyle: ts.withColor(
                Theme.of(context).colorScheme.inverseSurface,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: Theme.of(context).colorScheme.inverseSurface,
                ),
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) icon!.paddingRight(8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trailing != null) trailing!.paddingLeft(8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget(this.child, {super.key});

  final Widget child;

  @override
  State<OverlayWidget> createState() => OverlayWidgetState();
}

class OverlayWidgetState extends State<OverlayWidget> {
  final overlayKey = GlobalKey<OverlayState>();

  var entries = <OverlayEntry>[];

  void addOverlay(OverlayEntry entry) {
    if (overlayKey.currentState != null) {
      overlayKey.currentState!.insert(entry);
      entries.add(entry);
    }
  }

  void remove(OverlayEntry entry) {
    if (entries.remove(entry)) {
      entry.remove();
    }
  }

  void removeAll() {
    for (var entry in entries) {
      entry.remove();
    }
    entries.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      key: overlayKey,
      initialEntries: [OverlayEntry(builder: (context) => widget.child)],
    );
  }
}

void showDialogMessage(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => ContentDialog(
      title: title,
      content: Text(message).paddingHorizontal(16),
      actions: [FilledButton(onPressed: context.pop, child: Text(t.ok))],
    ),
  );
}

Future<void> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required void Function() onConfirm,
  Color? btnColor,
}) {
  return showDialog(
    context: context,
    builder: (context) => ContentDialog(
      title: title,
      content: Text(content).paddingHorizontal(16).paddingVertical(8),
      actions: [
        FilledButton(
          onPressed: () {
            context.pop();
            onConfirm();
          },
          style: FilledButton.styleFrom(backgroundColor: btnColor),
          child: Text(t.confirm),
        ),
      ],
    ),
  );
}

class LoadingDialogController {
  double? _progress;

  String? _message;

  void Function()? _closeDialog;

  void Function(double? value)? _serProgress;

  void Function(String message)? _setMessage;

  bool closed = false;

  void close() {
    if (closed) {
      return;
    }
    closed = true;
    if (_closeDialog == null) {
      Future.microtask(_closeDialog!);
    } else {
      _closeDialog!();
    }
  }

  void setProgress(double? value) {
    if (closed) {
      return;
    }
    _serProgress?.call(value);
  }

  void setMessage(String message) {
    if (closed) {
      return;
    }
    _setMessage?.call(message);
  }
}

LoadingDialogController showLoadingDialog(
  BuildContext context, {
  void Function()? onCancel,
  bool barrierDismissible = true,
  bool allowCancel = true,
  String? message,
  String cancelButtonText = "Cancel",
  bool withProgress = false,
}) {
  var controller = LoadingDialogController();
  controller._message = message;

  if (withProgress) {
    controller._progress = 0;
  }

  var loadingDialogRoute = DialogRoute(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          controller._serProgress = (value) {
            setState(() {
              controller._progress = value;
            });
          };
          controller._setMessage = (message) {
            setState(() {
              controller._message = message;
            });
          };
          return ContentDialog(
            title: controller._message ?? 'Loading',
            content: LinearProgressIndicator(
              value: controller._progress,
              backgroundColor: context.colorScheme.surfaceContainer,
            ).paddingHorizontal(16).paddingVertical(16),
            actions: [
              FilledButton(
                onPressed: allowCancel
                    ? () {
                        controller.close();
                        onCancel?.call();
                      }
                    : null,
                child: Text(cancelButtonText),
              ),
            ],
          );
        },
      );
    },
  );

  var navigator = Navigator.of(context, rootNavigator: true);

  navigator.push(loadingDialogRoute).then((value) => controller.closed = true);

  controller._closeDialog = () {
    navigator.removeRoute(loadingDialogRoute);
  };

  return controller;
}

class ContentDialog extends StatelessWidget {
  const ContentDialog({
    super.key,
    this.title,
    required this.content,
    this.isDismissible = false,
    this.actions = const [],
    this.cancel,
    this.displayButton = true,
    this.titleActions = const [],
  });

  final String? title;
  final Widget content;
  final List<Widget> actions;
  final List<Widget> titleActions;
  final bool isDismissible;
  final VoidCallback? cancel;
  final bool displayButton;

  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    required Widget content,
    bool isDismissible = false,
    List<Widget> actions = const [],
    List<Widget> titleActions = const [],
    VoidCallback? cancel,
    bool displayButton = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.toOpacity(0.36),
      builder: (context) => ContentDialog(
        title: title,
        content: content,
        isDismissible: isDismissible,
        actions: actions,
        titleActions: titleActions,
        cancel: cancel,
        displayButton: displayButton,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    final isDark = context.brightness == Brightness.dark;

    final titleWidget = title != null
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
                if (titleActions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...titleActions,
                ],
              ],
            ),
          )
        : null;

    final contentWidget = Padding(
      padding: EdgeInsets.fromLTRB(20, title != null ? 10 : 20, 20, 0),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface.toOpacity(0.75),
          height: 1.5,
        ),
        child: content,
      ),
    );
    final actionsWidget = displayButton
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () {
                    cancel?.call();
                    if (!isDismissible) context.pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface.toOpacity(0.55),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(t.cancel, style: const TextStyle(fontSize: 14)),
                ),
                const Spacer(),
                ...actions.separated(const SizedBox(width: 8)),
              ],
            ),
          )
        : null;
    final divider = displayButton
        ? Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.toOpacity(0.08)
                : Colors.black.toOpacity(0.07),
          )
        : null;

    return Dialog(
      insetPadding: context.width < 400
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: BlurEffect(
          blur: 18,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? cs.surface.toOpacity(0.55)
                  : cs.surface.toOpacity(0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.toOpacity(0.09)
                    : Colors.black.toOpacity(0.07),
                width: 0.8,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (titleWidget != null) titleWidget,
                  contentWidget,
                  const SizedBox(height: 4),
                  if (divider != null) divider,
                  if (actionsWidget != null) actionsWidget,
                  if (!displayButton) const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _WidgetListSep on List<Widget> {
  List<Widget> separated(Widget separator) {
    if (isEmpty) return this;
    final result = <Widget>[];
    for (var i = 0; i < length; i++) {
      result.add(this[i]);
      if (i < length - 1) result.add(separator);
    }
    return result;
  }
}

Future<void> showInputDialog({
  required BuildContext context,
  required String title,
  String? hintText,
  required FutureOr<Object?> Function(String) onConfirm,
  String? initialValue,
  String confirmText = "Confirm",
  String cancelText = "Cancel",
  RegExp? inputValidator,
  String? image,
  Uint8List? imageData,
}) {
  // 默认按钮文本 i18n（调用方未显式指定时使用）
  confirmText = confirmText == "Confirm" ? t.confirm : confirmText;
  cancelText = cancelText == "Cancel" ? t.cancel : cancelText;

  var controller = TextEditingController(text: initialValue);
  bool isLoading = false;
  String? error;

  return showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: title,
            content: Column(
              children: [
                if (image != null)
                  SizedBox(
                    height: 108,
                    child: Image.network(image, fit: BoxFit.none),
                  ).paddingBottom(8),
                if (image == null && imageData != null)
                  SizedBox(
                    height: 108,
                    child: Image.memory(imageData, fit: BoxFit.none),
                  ).paddingBottom(8),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: const OutlineInputBorder(),
                    errorText: error,
                  ),
                ).paddingHorizontal(12),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(cancelText),
              ),
              Button.filled(
                isLoading: isLoading,
                onPressed: () async {
                  if (inputValidator != null &&
                      !inputValidator.hasMatch(controller.text)) {
                    setState(() => error = "Invalid input");
                    return;
                  }
                  var futureOr = onConfirm(controller.text);
                  Object? result;
                  if (futureOr is Future) {
                    setState(() => isLoading = true);
                    result = await futureOr;
                    setState(() => isLoading = false);
                  } else {
                    result = futureOr;
                  }
                  if (result == null) {
                    context.pop();
                  } else {
                    setState(() => error = result.toString());
                  }
                },
                child: Text(confirmText),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 验证码输入对话框：显示验证码图片 + 手动输入框。
/// [onConfirm] 返回 null 表示通过（对话框关闭并返回输入值），
/// 返回非 null 表示验证失败（显示错误信息并保留对话框）。
/// 取消（内置取消按钮）返回 null。
Future<String?> showCaptchaDialog({
  required BuildContext context,
  required String title,
  required String image,
  String? hintText,
  FutureOr<Object?> Function(String)? onConfirm,
}) {
  final controller = TextEditingController();
  String? inputError;

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: title,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 90,
                  child: image.startsWith('data:')
                      ? Image.memory(
                          _captchaDataBytes(image),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                ).paddingBottom(8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: const OutlineInputBorder(),
                    errorText: inputError,
                  ),
                ).paddingHorizontal(12),
              ],
            ),
            actions: [
              Button.filled(
                onPressed: () async {
                  final v = controller.text.trim();
                  if (onConfirm == null) {
                    Navigator.pop(dialogContext, v);
                    return;
                  }
                  final futureOr = onConfirm(v);
                  Object? result;
                  if (futureOr is Future) {
                    result = await futureOr;
                  } else {
                    result = futureOr;
                  }
                  if (!dialogContext.mounted) return;
                  if (result == null) {
                    Navigator.pop(dialogContext, v);
                  } else {
                    setState(() => inputError = result.toString());
                  }
                },
                child: Text(t.confirm),
              ),
            ],
          );
        },
      );
    },
  );
}

Uint8List _captchaDataBytes(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  return base64Decode(dataUrl.substring(comma + 1));
}

void showInfoDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = "OK",
}) {
  showDialog(
    context: context,
    builder: (context) {
      return ContentDialog(
        title: title,
        content: Text(content).paddingHorizontal(16).paddingVertical(8),
        actions: [
          Button.filled(
            onPressed: context.pop,
            child: Text(t[confirmText] ?? confirmText),
          ),
        ],
      );
    },
  );
}

Future<int?> showSelectDialog({
  required String title,
  required List<String> options,
  int? initialIndex,
}) async {
  int? current = initialIndex;

  await showDialog(
    context: App.rootContext,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return ContentDialog(
            title: title,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Select(
                    current: current == null ? "" : options[current!],
                    values: options,
                    minWidth: 156,
                    onTap: (i) {
                      setState(() {
                        current = i;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  current = null;
                  context.pop();
                },
                child: Text(t.cancel),
              ),
              FilledButton(
                onPressed: current == null ? null : context.pop,
                child: Text(t.confirm),
              ),
            ],
          );
        },
      );
    },
  );

  return current;
}

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    super.key,
    required this.message,
    this.icon,
    this.trailing,
    required this.position,
    this.level = LogLevel.info,
    this.style = ToastStyle.bottom,
  });

  final String message;
  final Widget? icon;
  final Widget? trailing;
  final double position;
  final LogLevel level;
  final ToastStyle style;

  @override
  _ToastOverlayState createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay> {
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isVisible = true);
    });
  }

  void dismiss() {
    if (mounted) setState(() => _isVisible = false);
  }

  bool get _isTop =>
      widget.style == ToastStyle.topRight ||
      widget.style == ToastStyle.topLeft ||
      widget.style == ToastStyle.top;

  Offset get _slideOffset {
    if (_isVisible) return Offset.zero;
    return switch (widget.style) {
      ToastStyle.topRight => const Offset(1.2, 0),
      ToastStyle.topLeft => const Offset(-1.2, 0),
      ToastStyle.top => const Offset(0, -0.5),
      ToastStyle.bottom => const Offset(0, 0.5),
    };
  }

  Color _accentColor(BuildContext context) => switch (widget.level) {
    LogLevel.error => const Color(0xFFFF5449),
    LogLevel.warning => const Color(0xFFFFB800),
    LogLevel.info => Theme.of(context).colorScheme.primary,
  };

  IconData get _levelIcon => switch (widget.level) {
    LogLevel.error => Icons.error_outline_rounded,
    LogLevel.warning => Icons.warning_amber_rounded,
    LogLevel.info => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    const dur = Duration(milliseconds: 320);
    const curve = Curves.easeInOutCubic;
    final cs = Theme.of(context).colorScheme;
    final accent = _accentColor(context);

    final child = _isTop ? _buildBanner(cs, accent) : _buildToast(cs, accent);

    final animated = AnimatedSlide(
      duration: dur,
      curve: curve,
      offset: _slideOffset,
      child: AnimatedOpacity(
        duration: dur,
        curve: curve,
        opacity: _isVisible ? 1.0 : 0.0,
        child: child,
      ),
    );

    final topOffset =
        widget.position + MediaQuery.of(context).viewPadding.top + 16;

    return switch (widget.style) {
      ToastStyle.topRight => Positioned(
        top: topOffset,
        right: 0,
        child: animated,
      ),
      ToastStyle.topLeft => Positioned(
        top: topOffset,
        left: 0,
        child: animated,
      ),
      ToastStyle.top => Positioned(
        top: topOffset,
        left: 0,
        right: 0,
        child: Align(alignment: Alignment.topCenter, child: animated),
      ),
      ToastStyle.bottom => Positioned(
        bottom: widget.position + MediaQuery.of(context).viewInsets.bottom + 24,
        left: 0,
        right: 0,
        child: Align(alignment: Alignment.bottomCenter, child: animated),
      ),
    };
  }

  // ── bottom toast 样式 ──────────────────────────────────────────────────────
  Widget _buildToast(ColorScheme cs, Color accent) {
    return BlurEffect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 32,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainer.toOpacity(0.62),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: IntrinsicWidth(
          child: IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null)
                          IconTheme(
                            data: IconThemeData(color: accent, size: 18),
                            child: widget.icon!.paddingRight(10),
                          )
                        else
                          Icon(
                            _levelIcon,
                            color: accent,
                            size: 18,
                          ).paddingRight(10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.trailing != null)
                          widget.trailing!.paddingLeft(10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── top banner 样式（topRight / topLeft / top）──────────────────────
  Widget _buildBanner(ColorScheme cs, Color accent) {
    final isLeft = widget.style == ToastStyle.topLeft;
    final isCenter = widget.style == ToastStyle.top;

    final borderRadius = isCenter
        ? BorderRadius.circular(12)
        : isLeft
        ? const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            topLeft: Radius.circular(4),
            bottomLeft: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          );

    return BlurEffect(
      borderRadius: borderRadius,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width - 32,
        ),
        margin: isCenter
            ? EdgeInsets.zero
            : EdgeInsets.only(left: isLeft ? 12 : 0, right: isLeft ? 0 : 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainer.toOpacity(0.62),
          borderRadius: borderRadius,
          border: Border.all(color: accent.toOpacity(0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.toOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(-2, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_levelIcon, color: accent, size: 16).paddingRight(8),
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.trailing != null) widget.trailing!.paddingLeft(8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastEntry {
  late final OverlayEntry overlayEntry;
  final int seconds;
  final VoidCallback onRemove;
  final key = GlobalKey<_ToastOverlayState>();

  bool isDismissing = false;
  double position = 0;

  _ToastEntry({
    required String message,
    required Widget? icon,
    required Widget? trailing,
    required this.seconds,
    required this.onRemove,
    LogLevel level = LogLevel.info,
    ToastStyle style = ToastStyle.bottom,
  }) {
    overlayEntry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        key: key,
        message: message,
        icon: icon,
        trailing: trailing,
        position: position,
        level: level,
        style: style,
      ),
    );
  }

  void dismiss(VoidCallback onDismissed) {
    isDismissing = true;
    key.currentState?.dismiss();
    Future.delayed(
      const Duration(milliseconds: 320),
    ).then((_) => onDismissed());
  }

  void startTimer(VoidCallback onTimeout) {
    Timer(Duration(seconds: seconds), onTimeout);
  }

  void updatePosition(double newPosition) {
    position = newPosition;
    overlayEntry.markNeedsBuild();
  }
}

class ToastManager {
  static final List<_ToastEntry> _bottomEntries = [];
  static final List<_ToastEntry> _topRightEntries = [];
  static OverlayWidgetState? _overlayState;

  static void register(OverlayWidgetState state) {
    _overlayState = state;
  }

  static void unregister() {
    _overlayState = null;
  }

  static void show({
    required String message,
    BuildContext? context,
    Widget? icon,
    Widget? trailing,
    int? seconds,
    LogLevel level = LogLevel.info,
    ToastStyle style = ToastStyle.bottom,
  }) {
    final state =
        _overlayState ?? context?.findAncestorStateOfType<OverlayWidgetState>();
    if (state == null) return;

    final entry = _ToastEntry(
      message: message,
      icon: icon,
      trailing: trailing,
      seconds: seconds ?? (style == ToastStyle.topRight ? 4 : 3),
      onRemove: () => _repositionAll(style),
      level: level,
      style: style,
    );

    final list = style == ToastStyle.topRight
        ? _topRightEntries
        : _bottomEntries;
    list.add(entry);
    state.addOverlay(entry.overlayEntry);
    _repositionAll(style);

    entry.startTimer(() {
      entry.dismiss(() {
        list.remove(entry);
        state.remove(entry.overlayEntry);
        _repositionAll(style);
      });
      _repositionAll(style);
    });
  }

  static void _repositionAll(ToastStyle style) {
    if (style == ToastStyle.topRight) {
      final visible = _topRightEntries.where((e) => !e.isDismissing).toList();
      for (int i = 0; i < visible.length; i++) {
        visible[i].updatePosition(i * 52.0);
      }
    } else {
      final visible = _bottomEntries.where((e) => !e.isDismissing).toList();
      for (int i = 0; i < visible.length; i++) {
        visible[i].updatePosition(50.0 + i * 55.0);
      }
    }
  }
}

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.toOpacity(0.2), blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PolygonRefreshIndicator(size: 50),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}
