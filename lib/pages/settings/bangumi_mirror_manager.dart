part of 'settings_page.dart';

/// Bangumi 镜像管理：一个滚动页面里分 v0 / p1 / 图片 三个栏目，
/// 每个栏目单选一个镜像，未选的栏目默认官方。
class BangumiMirrorManagerPage extends StatefulWidget {
  const BangumiMirrorManagerPage({super.key});

  @override
  State<BangumiMirrorManagerPage> createState() =>
      _BangumiMirrorManagerPageState();
}

class _BangumiMirrorManagerPageState extends State<BangumiMirrorManagerPage> {
  late final List<BangumiMirrorEntry> _entries = List.of(
    bangumiMirrorEntries(),
  );

  static String _typeLabel(BangumiMirrorType type) => switch (type) {
    BangumiMirrorType.v0 => t.bangumiMirrorV0,
    BangumiMirrorType.p1 => t.bangumiMirrorP1,
    BangumiMirrorType.img => t.bangumiMirrorImage,
  };

  void _persist() {
    saveBangumiMirrorEntries(_entries);
    setState(() {});
  }

  Future<void> _edit({
    BangumiMirrorEntry? initial,
    required BangumiMirrorType defaultType,
  }) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final urlCtrl = TextEditingController(text: initial?.url ?? '');
    var type = initial?.type ?? defaultType;
    await ContentDialog.show(
      context: context,
      title: initial == null ? t.add : t.edit,
      content: StatefulBuilder(
        builder: (context, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                hintText: 'https://axlmly.com.cn',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.bangumiMirrorType,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CapsuleOptions(
              wrap: true,
              alignment: WrapAlignment.start,
              children: [
                for (final s in BangumiMirrorType.values)
                  CapsuleOption(
                    text: _typeLabel(s),
                    isSelected: type == s,
                    onTap: () => setLocal(() => type = s),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            final url = urlCtrl.text.trim();
            if (url.isEmpty) return;
            final name = nameCtrl.text.trim();
            final entry = BangumiMirrorEntry(
              name: name.isEmpty ? url : name,
              url: url,
              type: type,
            );
            if (initial == null) {
              _entries.add(entry);
            } else {
              final i = _entries.indexOf(initial);
              if (i >= 0) _entries[i] = entry;
              // 类型/地址变化时同步选中项
              if (bangumiMirrorSelectedUrl(initial.type) == initial.url) {
                selectBangumiMirror(initial.type, '');
                selectBangumiMirror(entry.type, entry.url);
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

  void _delete(BangumiMirrorEntry entry) {
    _entries.remove(entry);
    if (bangumiMirrorSelectedUrl(entry.type) == entry.url) {
      selectBangumiMirror(entry.type, '');
    }
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.bangumiMirror,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              t.bangumiMirrorDesc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _SwitchSetting(
            title: t.bangumiMirrorSendAuth,
            subtitle: t.bangumiMirrorSendAuthDesc,
            settingKey: 'bangumiMirrorSendAuth',
            dataSource: SwitchDataSource.implicit,
          ),
          for (final type in BangumiMirrorType.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  Text(
                    _typeLabel(type),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: t.add,
                    onPressed: () => _edit(defaultType: type),
                  ),
                ],
              ),
            ),
            SelectCard(
              title: t.mirrorOfficial,
              selected: bangumiMirrorSelectedUrl(type).isEmpty,
              onChanged: (_) => setState(() => selectBangumiMirror(type, '')),
            ),
            for (final e in _entries.where((e) => e.type == type))
              SelectCard(
                title: e.name,
                subtitle: e.url,
                selected: bangumiMirrorSelectedUrl(type) == e.url,
                onChanged: (_) =>
                    setState(() => selectBangumiMirror(type, e.url)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: t.edit,
                      onPressed: () => _edit(initial: e, defaultType: type),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: t.delete,
                      onPressed: () => _delete(e),
                    ),
                  ],
                ),
              ),
            if (!_entries.any((e) => e.type == type))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(t.mirrorEmpty, style: TextStyle(color: cs.outline)),
              ),
          ],
        ],
      ),
    );
  }
}
