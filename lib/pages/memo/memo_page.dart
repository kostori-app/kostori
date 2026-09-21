import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/memo_store.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 备忘录页（剪贴板）：新增 / 编辑 / 复制 / 删除。
/// 数据存 `history.db` 的 `memos` 表，随历史同步。
class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

String _fmtMemoTime(int ms) {
  if (ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
      '${two(dt.hour)}:${two(dt.minute)}';
}

class _MemoPageState extends State<MemoPage> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    MemoStore.instance.load();
    MemoStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    MemoStore.instance.removeListener(_onChange);
    _ctrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final id = await MemoStore.instance.add(_ctrl.text);
    if (id != null && mounted) _ctrl.clear();
  }

  Future<void> _edit(Memo memo) async {
    final ctrl = TextEditingController(text: memo.content);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.edit,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: t.memoHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          Button.filled(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    final text = ctrl.text;
    ctrl.dispose();
    if (ok == true && text.trim().isNotEmpty) {
      await MemoStore.instance.update(memo.id, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final memos = MemoStore.instance.memos;
    return Scaffold(
      appBar: Appbar(title: Text(t.memo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    maxLines: null,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      hintText: t.memoHint,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                CapsuleButton(
                  primary: true,
                  leading: const Icon(Icons.add),
                  text: t.add,
                  onTap: () => _add(),
                ),
              ],
            ),
          ),
          Expanded(
            child: memos.isEmpty
                ? Center(
                    child: Text(
                      t.memoEmpty,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: memos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final memo = memos[i];
                      return Material(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _edit(memo),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSelectableText(
                                  memo.content,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _fmtMemoTime(memo.updatedAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: t.copy,
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 18,
                                      icon: const Icon(Icons.copy_outlined),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: memo.content),
                                        );
                                        App.rootContext.showMessage(
                                          message: t.copySuccess,
                                        );
                                      },
                                    ),
                                    IconButton(
                                      tooltip: t.delete,
                                      visualDensity: VisualDensity.compact,
                                      iconSize: 18,
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: cs.error,
                                      ),
                                      onPressed: () =>
                                          MemoStore.instance.remove(memo.id),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
