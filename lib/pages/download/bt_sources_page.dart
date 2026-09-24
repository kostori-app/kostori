import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/utils/io.dart';

const String _exampleJson = '''[
  {
    "key": "example-json",
    "name": "Example (JSON API)",
    "type": "json",
    "urlTemplate": "https://api.example.com/search?q={query}&page={page}",
    "jsonPath": "data.list",
    "titleField": "title",
    "magnetField": "magnet",
    "hashField": "infoHash",
    "sizeField": "size",
    "groupField": "team.name",
    "dateField": "publishedAt"
  },
  {
    "key": "example-regex",
    "name": "Example (HTML/RSS)",
    "type": "regex",
    "urlTemplate": "https://example.com/search?q={query}&p={page}",
    "itemRegex": "<item>[\\\\s\\\\S]*?</item>",
    "hashRegex": "<infoHash>([^<]+)</infoHash>",
    "magnetTemplate": "magnet:?xt=urn:btih:{hash}",
    "titleRegex": "<title>([^<]+)</title>",
    "sizeRegex": "([\\\\d.]+\\\\s*[MGK]i?B)",
    "groupRegex": "\\\\[([^\\\\]]+)\\\\]",
    "dateRegex": "<pubDate>([^<]+)</pubDate>"
  }
]''';

/// BT 资源站管理：全部来自 `<dataPath>/bt_source/*.json`（导入式，不内置）。
class BtSourcesPage extends StatefulWidget {
  const BtSourcesPage({super.key});

  @override
  State<BtSourcesPage> createState() => _BtSourcesPageState();
}

class _BtSourcesPageState extends State<BtSourcesPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    await BtSources.reload();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(t.torrentSources)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImportMenu,
        icon: const Icon(Icons.add),
        label: Text(t.import),
      ),
      body: _loading
          ? const Center(child: PolygonRefreshIndicator(size: 60))
          : _buildBody(),
    );
  }

  Future<void> _showImportMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Sheet(
        title: t.import,
        icon: Icons.podcasts_outlined,
        builder: (_, sc) => ListView(
          controller: sc,
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(t.useAConfigFile),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(t.paste),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(t.add),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'file':
        await _importFromFile();
      case 'paste':
        await _importJson();
      case 'manual':
        await _edit(null);
    }
  }

  Future<void> _importFromFile() async {
    try {
      final file = await selectFile(ext: ['json']);
      if (file == null) return;
      final n = await BtSources.importJson(utf8.decode(await file.readAsBytes()));
      if (!mounted) return;
      App.rootContext.showMessage(
        message: n == 0 ? t.switchFailed : '${t.import}: $n',
      );
      setState(() {});
    } catch (e) {
      App.rootContext.showMessage(message: e.toString());
    }
  }

  Widget _buildBody() {
    final list = BtSources.all;
    if (list.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.podcasts_outlined,
                size: 56,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                t.torrentSourcesEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SelectableText(
                BtSources.dir.path,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: cs.primary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      children: [
        for (final c in list)
          ListTile(
            leading: CustomSwitch(
              value: c.enabled,
              onChanged: (v) async {
                await BtSources.setEnabled(c.key, v);
                if (mounted) setState(() {});
              },
            ),
            title: Text(c.name),
            subtitle: Text(
              [c.type, if (c.urlTemplate.isNotEmpty) c.urlTemplate].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await BtSources.remove(c.key);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            onTap: () => _edit(c),
          ),
      ],
    );
  }

  Future<void> _importJson() async {
    final ctrl = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => ContentDialog(
        title: t.import,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.36,
          ),
          child: TextField(
            controller: ctrl,
            minLines: 5,
            maxLines: 8,
            style: const TextStyle(fontSize: 12, height: 1.4),
            decoration: const InputDecoration(
              hintText: 'JSON',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctrl.text = _exampleJson,
            child: Text(t.torrentSourceExample),
          ),
          TextButton(
            onPressed: () async {
              final text = await Clipboard.getData('text/plain').then(
                (d) => d?.text,
              );
              if (text != null && text.isNotEmpty) ctrl.text = text;
            },
            child: Text(t.paste),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (json == null) return;
    final n = await BtSources.importJson(json);
    if (!mounted) return;
    App.rootContext.showMessage(
      message: n == 0 ? t.switchFailed : '${t.import}: $n',
    );
    setState(() {});
  }

  Future<void> _edit(BtSourceConfig? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.urlTemplate ?? '');
    // regex
    final itemCtrl = TextEditingController(text: existing?.itemRegex ?? '');
    final magnetCtrl = TextEditingController(text: existing?.magnetRegex ?? '');
    final hashCtrl = TextEditingController(text: existing?.hashRegex ?? '');
    final tplCtrl = TextEditingController(text: existing?.magnetTemplate ?? '');
    final titleCtrl = TextEditingController(text: existing?.titleRegex ?? '');
    final sizeCtrl = TextEditingController(text: existing?.sizeRegex ?? '');
    final groupCtrl = TextEditingController(text: existing?.groupRegex ?? '');
    final dateCtrl = TextEditingController(text: existing?.dateRegex ?? '');
    // json
    final jsonPathCtrl = TextEditingController(text: existing?.jsonPath ?? '');
    final titleFieldCtrl = TextEditingController(
      text: existing?.titleField ?? '',
    );
    final magnetFieldCtrl = TextEditingController(
      text: existing?.magnetField ?? '',
    );
    final hashFieldCtrl = TextEditingController(
      text: existing?.hashField ?? '',
    );
    final sizeFieldCtrl = TextEditingController(
      text: existing?.sizeField ?? '',
    );
    final groupFieldCtrl = TextEditingController(
      text: existing?.groupField ?? '',
    );
    final dateFieldCtrl = TextEditingController(
      text: existing?.dateField ?? '',
    );
    var type = existing?.type == 'json' ? 'json' : 'regex';

    final result = await showDialog<BtSourceConfig>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Widget field(
            TextEditingController ctrl,
            String label, {
            int lines = 1,
          }) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: ctrl,
              minLines: lines,
              maxLines: lines == 1 ? 1 : 3,
              decoration: InputDecoration(
                isDense: true,
                labelText: label,
                border: const OutlineInputBorder(),
              ),
            ),
          );

          return ContentDialog(
            title: existing == null ? t.torrentSources : existing.name,
            displayButton: false,
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  field(nameCtrl, t.torrentSourceName),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: t.torrentSourceType,
                      border: const OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'regex',
                        child: Text('Regex (HTML/XML/RSS)'),
                      ),
                      DropdownMenuItem(value: 'json', child: Text('JSON API')),
                    ],
                    onChanged: (v) => setDlg(() => type = v ?? 'regex'),
                  ),
                  const SizedBox(height: 10),
                  field(urlCtrl, t.torrentSourceUrl),
                  if (type == 'regex') ...[
                    field(itemCtrl, t.torrentSourceItemRegex, lines: 2),
                    field(magnetCtrl, t.torrentSourceMagnetRegex),
                    field(hashCtrl, t.torrentSourceHashRegex),
                    field(tplCtrl, t.torrentSourceMagnetTemplate),
                    field(titleCtrl, t.torrentSourceTitleRegex),
                    field(sizeCtrl, t.torrentSourceSizeRegex),
                    field(groupCtrl, t.torrentSourceGroupRegex),
                    field(dateCtrl, t.torrentSourceDateRegex),
                  ] else ...[
                    field(jsonPathCtrl, t.torrentSourceJsonPath),
                    field(titleFieldCtrl, t.torrentSourceTitleField),
                    field(magnetFieldCtrl, t.torrentSourceMagnetField),
                    field(hashFieldCtrl, t.torrentSourceHashField),
                    field(sizeFieldCtrl, t.torrentSourceSizeField),
                    field(groupFieldCtrl, t.torrentSourceGroupField),
                    field(dateFieldCtrl, t.torrentSourceDateField),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final key =
                      existing?.key ??
                      'custom_${DateTime.now().millisecondsSinceEpoch}';
                  Navigator.pop(
                    ctx,
                    BtSourceConfig(
                      key: key,
                      name: name,
                      type: type,
                      urlTemplate: urlCtrl.text.trim(),
                      itemRegex: itemCtrl.text.trim(),
                      magnetRegex: magnetCtrl.text.trim(),
                      hashRegex: hashCtrl.text.trim(),
                      magnetTemplate: tplCtrl.text.trim(),
                      titleRegex: titleCtrl.text.trim(),
                      sizeRegex: sizeCtrl.text.trim(),
                      groupRegex: groupCtrl.text.trim(),
                      dateRegex: dateCtrl.text.trim(),
                      jsonPath: jsonPathCtrl.text.trim(),
                      titleField: titleFieldCtrl.text.trim(),
                      magnetField: magnetFieldCtrl.text.trim(),
                      hashField: hashFieldCtrl.text.trim(),
                      sizeField: sizeFieldCtrl.text.trim(),
                      groupField: groupFieldCtrl.text.trim(),
                      dateField: dateFieldCtrl.text.trim(),
                      enabled: existing?.enabled ?? true,
                    ),
                  );
                },
                child: Text(t.confirm),
              ),
            ],
          );
        },
      ),
    );

    for (final c in [
      nameCtrl,
      urlCtrl,
      itemCtrl,
      magnetCtrl,
      hashCtrl,
      tplCtrl,
      titleCtrl,
      sizeCtrl,
      groupCtrl,
      dateCtrl,
      jsonPathCtrl,
      titleFieldCtrl,
      magnetFieldCtrl,
      hashFieldCtrl,
      sizeFieldCtrl,
      groupFieldCtrl,
      dateFieldCtrl,
    ]) {
      c.dispose();
    }

    if (result != null) {
      await BtSources.upsert(result);
      if (mounted) setState(() {});
    }
  }
}
