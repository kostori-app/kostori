import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';

/// 链接解析页：输入一段文本，列出所有能解析它的番剧源并跳转 AnimePage
class LinkResolvePage extends StatefulWidget {
  const LinkResolvePage({super.key, this.initialText = ''});

  /// 长按“用解析打开”等场景可直接带入文本
  final String initialText;

  @override
  State<LinkResolvePage> createState() => _LinkResolvePageState();
}

class _LinkResolvePageState extends State<LinkResolvePage> {
  final TextEditingController _ctrl = TextEditingController();
  List<ResolvedLinkCandidate> _candidates = const [];
  bool _loading = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialText;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      App.rootContext.showMessage(message: t.thisFieldCannotBeEmpty);
      return;
    }
    setState(() {
      _loading = true;
      _resolved = true;
      _candidates = const [];
    });
    final results = await AnimeSourceManager().resolveLinkCandidates(text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _candidates = results;
    });
  }

  void _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null) return;
    setState(() => _ctrl.text = data!.text!.trim());
  }

  void _open(ResolvedLinkCandidate c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimePage(id: c.id, sourceKey: c.sourceKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: Appbar(title: Text(t.resolveLink)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: t.resolveLinkHint,
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  tooltip: t.paste,
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste,
                ),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: Button.filled(
                isLoading: _loading,
                onPressed: _resolve,
                child: Text(t.resolveLink),
              ),
            ),
          ),
          Expanded(child: _body(cs)),
        ],
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) {
      return const Center(child: PolygonRefreshIndicator(size: 24));
    }
    if (!_resolved) {
      return Center(
        child: Text(
          t.resolveLinkHint,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    if (_candidates.isEmpty) {
      return Center(
        child: Text(
          t.noResolvableLink,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final c in _candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.movie_outlined, color: cs.primary),
                title: Text(c.sourceName),
                subtitle: Text(c.id),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => _open(c),
              ),
            ),
          ),
      ],
    );
  }
}
