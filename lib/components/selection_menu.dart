part of 'components.dart';

/// 带项目自定义选中菜单的 [SelectionArea]：
/// 在系统默认项（复制 / 全选 / 分享）之后追加「翻译」与「搜索选中文字」。
class AppSelectionArea extends StatefulWidget {
  const AppSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<AppSelectionArea> createState() => _AppSelectionAreaState();
}

class _AppSelectionAreaState extends State<AppSelectionArea> {
  /// 最近一次选中的文本，供菜单项点击时取用
  String _selectedText = '';

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      onSelectionChanged: (content) =>
          _selectedText = content?.plainText ?? '',
      contextMenuBuilder: (context, state) =>
          appSelectionContextMenu(context, state, () => _selectedText),
      child: widget.child,
    );
  }
}

/// 框架默认项过滤：`state.contextMenuButtonItems` 在 Android 上还会带上
/// 其他 App 注册的 `ACTION_PROCESS_TEXT` 项（如词典/其他客户端的“在XX内打开”），
/// 用户没装过也会觉得莫名其妙。这里只保留系统基础项，其余一律丢掉，
/// 项目自定义项（翻译/搜索/链接）不受影响，照常追加。
List<ContextMenuButtonItem> _frameworkBaseItems(
  List<ContextMenuButtonItem> items,
) {
  const allow = {
    ContextMenuButtonType.cut,
    ContextMenuButtonType.copy,
    ContextMenuButtonType.paste,
    ContextMenuButtonType.selectAll,
    ContextMenuButtonType.share,
  };
  return items.where((e) => allow.contains(e.type)).toList();
}

/// 选中文本的菜单：默认项 + 翻译 + 搜索
///
/// [selectedText] 延迟到点击时才取值，避免菜单构建时选中内容尚未同步。
Widget appSelectionContextMenu(
  BuildContext context,
  SelectableRegionState state,
  String Function() selectedText,
) {
  final items = _frameworkBaseItems(state.contextMenuButtonItems);
  // 有选中内容时（框架给出「复制」项）才追加自定义项
  final hasSelection = items.any(
    (item) => item.type == ContextMenuButtonType.copy,
  );
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: [
      // 复制 / 全选 / 分享（文案与回调由框架按平台给出）
      ...items,
      if (hasSelection)
        ContextMenuButtonItem(
          label: t.translate,
          onPressed: () {
            ContextMenuController.removeAny();
            final text = selectedText().trim();
            if (text.isEmpty) return;
            showTranslationSheet(text);
          },
        ),
      if (hasSelection)
        ContextMenuButtonItem(
          label: t.search,
          onPressed: () {
            ContextMenuController.removeAny();
            final text = selectedText().trim();
            if (text.isEmpty) return;
            App.rootContext.to(() => SearchPage(keyword: text));
          },
        ),
      ...appSelectionLinkItems(selectedText()),
    ],
  );
}

/// 选中文本里包含链接时追加的菜单项：
/// - 「在浏览器打开」：交给系统默认应用（通常是浏览器）；
/// - 「用其他应用打开」：移动端才显示，Android 走「非浏览器应用」意图、
///   iOS 走 Universal Link，可直接跳到 PikPak 这类已注册该链接的 App。
List<ContextMenuButtonItem> appSelectionLinkItems(String selectedText) {
  final url = firstUrlInSelection(selectedText);
  if (url == null) return const [];
  return [
    ContextMenuButtonItem(
      label: t.openInBrowser,
      onPressed: () {
        ContextMenuController.removeAny();
        _openSelectedUrl(url, nonBrowser: false);
      },
    ),
    if (App.isMobile)
      ContextMenuButtonItem(
        label: t.openWithOtherApp,
        onPressed: () {
          ContextMenuController.removeAny();
          _openSelectedUrl(url, nonBrowser: true);
        },
      ),
  ];
}

/// 取文本里第一个 http(s) 链接（去掉结尾常见的标点，避免把中文句号带进去）。
/// 供选中文本菜单判断是否追加「浏览器/其他应用打开」。
String? firstUrlInSelection(String text) {
  final match = RegExp(r'https?://[^\s]+').firstMatch(text.trim());
  if (match == null) return null;
  final url = match.group(0)!.replaceAll(
    // 结尾常见的半角/全角标点（中英文句号、引号、括号等）
    RegExp(r'''[)\]}>）】」』》〉，。；、,.;:!?'"”’]+$'''),
    '',
  );
  // 协议后面必须还有内容，否则视为无效
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return null;
  return url;
}

/// 打开链接。[nonBrowser] 为 true 时优先交给非浏览器的其他应用。
Future<void> _openSelectedUrl(String url, {required bool nonBrowser}) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  var ok = false;
  try {
    if (nonBrowser && App.isAndroid) {
      // Android：只挑「非浏览器」的应用（PikPak 等注册了该链接的 App）
      ok = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      // iOS 走 Universal Link（装了对应 App 会直接进 App，否则落到浏览器），
      // 桌面端交给系统默认应用
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    App.rootContext.showMessage(message: t.failedToOpen, level: LogLevel.warning);
  }
}

/// [SelectableText]（以及任何内部使用 [EditableText] 的组件）用的自定义选中菜单：
/// 默认项（复制 / 全选 / 分享…）之后追加「翻译」与「搜索选中文字」。
///
/// 与 [appSelectionContextMenu] 的区别只是选中文本和锚点的来源不同
/// （[EditableTextState] 里可以同步拿到选区文本）。
Widget appEditableSelectionContextMenu(
  BuildContext context,
  EditableTextState state,
) {
  final value = state.textEditingValue;
  final selection = value.selection;
  final text = selection.isValid && !selection.isCollapsed
      ? selection.textInside(value.text).trim()
      : '';

  final items = _frameworkBaseItems(state.contextMenuButtonItems);
  final hasSelection = items.any(
    (item) => item.type == ContextMenuButtonType.copy,
  );
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: state.contextMenuAnchors,
    buttonItems: [
      ...items,
      if (hasSelection)
        ContextMenuButtonItem(
          label: t.translate,
          onPressed: () {
            ContextMenuController.removeAny();
            if (text.isEmpty) return;
            showTranslationSheet(text);
          },
        ),
      if (hasSelection)
        ContextMenuButtonItem(
          label: t.search,
          onPressed: () {
            ContextMenuController.removeAny();
            if (text.isEmpty) return;
            App.rootContext.to(() => SearchPage(keyword: text));
          },
        ),
      ...appSelectionLinkItems(text),
    ],
  );
}

/// 翻译结果弹层（选中文本菜单的「翻译」与 AI 消息翻译共用）：
/// 上方原文卡片、下方译文；加载中骨架屏，失败可重试，右上角可复制译文。
Future<void> showTranslationSheet(String text) {
  return showModalBottomSheet<void>(
    context: App.rootContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TranslationSheet(source: text),
  );
}

/// 翻译结果弹层：上方原文卡片、下方译文（加载用骨架屏、失败可重试）。
class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({required this.source});

  final String source;

  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  String? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final res = await TranslationService().translate(widget.source);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = res.success ? res.data : null;
      _error = res.success ? null : (res.errorMessage ?? t.translationFailed);
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _result = null;
      _error = null;
    });
    _run();
  }

  void _copy() {
    final result = _result;
    if (result == null || result.isEmpty) return;
    Clipboard.setData(ClipboardData(text: result));
    App.rootContext.showMessage(message: t.copySuccess);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    final hasResult = result != null && result.isNotEmpty;
    return Sheet(
      title: '${t.translate} · ${TranslationService.getPoweredName()}',
      icon: Icons.translate,
      initialSize: 0.55,
      headerTrailing: hasResult
          ? IconButton(
              tooltip: t.copy,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: _copy,
            )
          : null,
      builder: (context, sc) => ListView(
        controller: sc,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // 原文：弱化的卡片，可选中复制
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.toOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.toOpacity(0.6),
                width: 0.6,
              ),
            ),
            child: SelectableText(
              widget.source,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            Skeletonizer.zone(child: Bone.multiText(lines: 4))
          else if (hasResult) ...[
            Row(
              children: [
                Icon(Icons.translate, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  t.translationResult,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              result,
              style: const TextStyle(fontSize: 15, height: 1.7),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer.toOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error ?? t.translationFailed,
                style: TextStyle(fontSize: 13, color: scheme.error),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: CapsuleButton(
                leading: const Icon(Icons.refresh, size: 16),
                text: t.retry,
                onTap: _retry,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
