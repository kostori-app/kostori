// ignore_for_file: use_build_context_synchronously

part of "components.dart";

// void showToast({
//   required String message,
//   required BuildContext context,
//   Widget? icon,
//   Widget? trailing,
//   int? seconds,
// }) {
//   var newEntry = OverlayEntry(
//     builder: (context) =>
//         _ToastOverlay(message: message, icon: icon, trailing: trailing),
//   );
//
//   var state = context.findAncestorStateOfType<OverlayWidgetState>();
//
//   state?.addOverlay(newEntry);
//
//   Timer(Duration(seconds: seconds ?? 2), () => state?.remove(newEntry));
// }

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

class _ToastOverlay extends StatelessWidget {
  const _ToastOverlay({
    required this.message,
    this.icon,
    this.trailing,
    required this.position,
  });

  final String message;
  final Widget? icon;
  final Widget? trailing;
  final double position;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: position + MediaQuery.of(context).viewInsets.bottom + 24,
      left: 0,
      right: 0,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Theme.of(
                context,
              ).colorScheme.inverseSurface.toOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              elevation: 2,
              textStyle: ts.withColor(
                Theme.of(context).colorScheme.onInverseSurface,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 16,
                    ),
                    constraints: BoxConstraints(maxWidth: context.width - 32),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) icon!.paddingRight(8),
                        Expanded(
                          child: Text(
                            message,
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
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: context.pop, child: Text("OK".tl))],
    ),
  );
}

Future<void> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required void Function() onConfirm,
  String confirmText = "Confirm",
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
          child: Text(confirmText.tl),
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
                child: Text(cancelButtonText.tl),
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
    this.title, // 如果不传 title 将不会展示
    required this.content,
    this.dismissible = true,
    this.actions = const [],
    this.cancel,
  });

  final String? title;

  final Widget content;

  final List<Widget> actions;

  final bool dismissible;

  final VoidCallback? cancel;

  @override
  Widget build(BuildContext context) {
    var content = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title != null
              ? Padding(
                  padding: const EdgeInsets.only(
                    left: 24.0,
                    top: 24,
                    bottom: 12,
                  ),
                  child: Text(
                    title!,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                )
              : const SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24),
            child: this.content,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const SizedBox(width: 24),
              Button.text(
                onPressed: () {
                  if (cancel != null) {
                    cancel;
                  }
                  Navigator.pop(context);
                },
                child: Text("Cancel".tl),
              ),
              const Spacer(),
              ...actions,
            ],
          ).paddingRight(12),
          const SizedBox(height: 24),
        ],
      ),
    );
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: context.brightness == Brightness.dark
              ? Colors.white.toOpacity(0.1)
              : Colors.black.toOpacity(0.1),
          width: 1.0,
        ),
      ),
      insetPadding: context.width < 400
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 100)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 100),
      elevation: 2,
      shadowColor: context.colorScheme.shadow,
      backgroundColor: context.colorScheme.surface.toOpacity(0.3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            decoration: BoxDecoration(
              color: context.colorScheme.surface.toOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    minWidth: math.min(400, context.width - 16),
                  ),
                  child: MediaQuery.removePadding(
                    removeTop: true,
                    removeBottom: true,
                    context: context,
                    child: content,
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
}) {
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
                child: Text(confirmText.tl),
              ),
            ],
          );
        },
      );
    },
  );
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
          Button.filled(onPressed: context.pop, child: Text(confirmText.tl)),
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
                child: Text('Cancel'.tl),
              ),
              FilledButton(
                onPressed: current == null ? null : context.pop,
                child: Text('Confirm'.tl),
              ),
            ],
          );
        },
      );
    },
  );

  return current;
}

class _ToastEntry {
  late final OverlayEntry overlayEntry;
  final int seconds;
  final VoidCallback onRemove;
  final BuildContext context;
  final String message;
  final Widget? icon;
  final Widget? trailing;

  double position = 0;

  _ToastEntry({
    required this.context,
    required this.message,
    required this.icon,
    required this.trailing,
    required this.seconds,
    required this.onRemove,
  }) {
    overlayEntry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        icon: icon,
        trailing: trailing,
        position: position, // 实时读取位置
      ),
    );
  }

  void startTimer(VoidCallback onTimeout) {
    Future.delayed(Duration(seconds: seconds)).then((_) {
      onTimeout();
      onRemove();
    });
  }

  void updatePosition(int index) {
    position = index * 48.0; // 每个 toast 高度+间距
    overlayEntry.markNeedsBuild();
  }
}

class ToastManager {
  static final List<_ToastEntry> _entries = [];

  static void show({
    required String message,
    required BuildContext context,
    Widget? icon,
    Widget? trailing,
    int? seconds,
  }) {
    final newEntry = _ToastEntry(
      context: context,
      message: message,
      icon: icon,
      trailing: trailing,
      seconds: seconds ?? 2,
      onRemove: _repositionAll,
    );

    var state = context.findAncestorStateOfType<OverlayWidgetState>();
    if (state != null) {
      _entries.add(newEntry);
      state.addOverlay(newEntry.overlayEntry);
      _repositionAll();

      newEntry.startTimer(() {
        _entries.remove(newEntry);
        state.remove(newEntry.overlayEntry);
        _repositionAll();
      });
    }
  }

  static void _repositionAll() {
    const double baseOffset = 40.0;
    const double spacing = 48.0;

    for (int i = 0; i < _entries.length; i++) {
      _entries[i].position = baseOffset + i * spacing;
      _entries[i].overlayEntry.markNeedsBuild();
    }
  }
}
