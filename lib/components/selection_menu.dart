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
            showSelectionTranslationSheet(text);
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

/// 翻译选中文本：底部弹层展示译文
Future<void> showSelectionTranslationSheet(String text) {
  return showModalBottomSheet<void>(
    context: App.rootContext,
    isScrollControlled: true,
    builder: (_) => _SelectionTranslationSheet(source: text),
  );
}

class _SelectionTranslationSheet extends StatefulWidget {
  const _SelectionTranslationSheet({required this.source});

  final String source;

  @override
  State<_SelectionTranslationSheet> createState() =>
      _SelectionTranslationSheetState();
}

class _SelectionTranslationSheetState
    extends State<_SelectionTranslationSheet> {
  String? _result;
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
    });
    if (!res.success) {
      App.rootContext.showMessage(
        message: '${t.translationFailed}: ${res.errorMessage}',
        level: LogLevel.warning,
      );
    }
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
    return Sheet(
      title: '${t.translate} · ${TranslationService.getPoweredName()}',
      icon: Icons.translate,
      initialSize: 0.6,
      headerTrailing: _result == null
          ? null
          : IconButton(
              tooltip: t.copy,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: _copy,
            ),
      builder: (context, _) {
        if (_loading) {
          return const Center(child: PolygonRefreshIndicator());
        }
        final result = _result;
        if (result == null || result.isEmpty) {
          return Center(
            child: Text(
              t.translationFailed,
              style: TextStyle(color: scheme.error),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SelectableText(
            result,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        );
      },
    );
  }
}
