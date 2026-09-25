import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/mirror_store.dart';

/// 通用镜像管理页：列出某类镜像（[store]），可添加/编辑/删除并选择当前使用的一个。
/// Bangumi 镜像与 GitHub 镜像共用。
class MirrorManagerPage extends StatefulWidget {
  const MirrorManagerPage({
    super.key,
    required this.store,
    required this.title,
    required this.description,
    required this.addressHint,
    this.footer,
  });

  final MirrorStore store;
  final String title;
  final String description;
  final String addressHint;

  /// 额外设置项（如 Bangumi 的「镜像使用鉴权」开关）
  final Widget? footer;

  @override
  State<MirrorManagerPage> createState() => _MirrorManagerPageState();
}

class _MirrorManagerPageState extends State<MirrorManagerPage> {
  late List<MirrorEntry> _entries = List.of(widget.store.entries);

  void _persist() {
    widget.store.save(_entries);
    setState(() {});
  }

  void _select(String url) {
    widget.store.select(url);
    setState(() {});
  }

  Future<void> _edit({MirrorEntry? initial}) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final urlCtrl = TextEditingController(text: initial?.url ?? '');
    await ContentDialog.show(
      context: context,
      title: initial == null ? t.add : t.edit,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(labelText: t.name),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: t.mirrorAddress,
              hintText: widget.addressHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => App.rootContext.pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: () {
            final url = urlCtrl.text.trim();
            if (url.isEmpty) return;
            final name = nameCtrl.text.trim();
            final entry = MirrorEntry(
              name: name.isEmpty ? url : name,
              url: url,
            );
            if (initial == null) {
              _entries.add(entry);
            } else {
              final i = _entries.indexOf(initial);
              if (i >= 0) _entries[i] = entry;
              if (widget.store.selectedUrl == initial.url) {
                widget.store.select(entry.url);
              }
            }
            _persist();
            App.rootContext.pop();
          },
          child: Text(t.save),
        ),
      ],
    );
  }

  void _delete(MirrorEntry entry) {
    _entries.remove(entry);
    if (widget.store.selectedUrl == entry.url) {
      widget.store.select('');
    }
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.store.selectedUrl;
    return PopUpWidgetScaffold(
      title: widget.title,
      tailing: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: t.add,
          onPressed: () => _edit(),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (widget.footer != null) widget.footer!,
          const SizedBox(height: 8),
          SelectCard(
            title: t.mirrorOfficial,
            selected: selected.isEmpty,
            onChanged: (_) => _select(''),
          ),
          if (_entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t.mirrorEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          for (final m in _entries)
            SelectCard(
              title: m.name,
              subtitle: m.url,
              selected: selected == m.url,
              onChanged: (_) => _select(m.url),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: t.edit,
                    onPressed: () => _edit(initial: m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: t.delete,
                    onPressed: () => _delete(m),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
