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

/// 选中文本的菜单：默认项 + 翻译 + 搜索
///
/// [selectedText] 延迟到点击时才取值，避免菜单构建时选中内容尚未同步。
Widget appSelectionContextMenu(
  BuildContext context,
  SelectableRegionState state,
  String Function() selectedText,
) {
  final items = state.contextMenuButtonItems;
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
    ],
  );
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

  final items = state.contextMenuButtonItems;
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
