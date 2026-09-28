import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/services/torrent/torrent_binding.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';

String _fmtSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}

String _cleanTitle(String title) {
  var s = title.trim();
  s = s.replaceFirst(RegExp(r'^\s*(?:【[^】]*】|\[[^\]]*\])\s*'), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? title : s;
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

/// 选择一条 BT 线路（站 + 组）：选定后该内容的每一集都在此线路内自动检索。
Future<BtLine?> showTorrentResourcePicker(
  BuildContext context, {
  String? initialKeyword,
  int? episode,
  BtLine? currentLine,
}) async {
  await BtSources.ensureLoaded();
  await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(torrentManagerProvider.notifier).init();
  return showModalBottomSheet<BtLine>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Sheet(
      title: episode != null
          ? '${t.torrentStream} · ${t.episodeN(n: episode)}'
          : t.torrentStream,
      icon: Icons.podcasts_outlined,
      builder: (_, sc) => _BtLineSheet(
        scroll: sc,
        initialKeyword: initialKeyword,
        episode: episode,
        currentLine: currentLine,
      ),
    ),
  );
}

class _BtLineSheet extends StatefulWidget {
  const _BtLineSheet({
    required this.scroll,
    this.initialKeyword,
    this.episode,
    this.currentLine,
  });

  final ScrollController scroll;
  final String? initialKeyword;
  final int? episode;

  /// 当前已选中的线路（用于标出“当前”）
  final BtLine? currentLine;

  @override
  State<_BtLineSheet> createState() => _BtLineSheetState();
}

class _BtLineSheetState extends State<_BtLineSheet> {
  late final TextEditingController _keyword = TextEditingController(
    text: widget.initialKeyword ?? '',
  );
  late final Set<String> _sites = BtIndexers.enabled()
      .map((e) => e.key)
      .toSet();

  bool _searching = false;
  bool _searched = false;
  List<BtSearchResult> _results = const [];
  final Set<String> _collapsed = {};

  static final Map<String, List<BtSearchResult>> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const _cacheTtl = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _keyword.text.trim().isNotEmpty) _search();
    });
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  String _cacheKey(String kw, List<BtIndexer> sites) {
    final keys = sites.map((e) => e.key).toList()..sort();
    return '$kw\u0000${keys.join(',')}';
  }

  Future<void> _search() async {
    final kw = _keyword.text.trim();
    if (kw.isEmpty || _searching) return;
    final sites = BtIndexers.all.where((e) => _sites.contains(e.key)).toList();
    final key = _cacheKey(kw, sites);
    final cached = _cache[key];
    final at = _cacheTime[key];
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheTtl) {
      setState(() {
        _results = List.of(cached);
        _searched = true;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
      _results = const [];
    });
    await Future.wait(
      sites.map((s) async {
        List<BtSearchResult> r = const [];
        try {
          r = await s.search(kw);
        } catch (_) {}
        if (!mounted || r.isEmpty) return;
        setState(() => _results = [..._results, ...r]);
        _cache[key] = List.of(_results);
        _cacheTime[key] = DateTime.now();
      }),
    );
    if (mounted) setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyword,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.search,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              Button.filled(
                isLoading: _searching,
                onPressed: _search,
                child: Text(t.search),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: CapsuleChipGroup(
            alignment: WrapAlignment.start,
            children: [
              for (final s in BtIndexers.all)
                CapsuleChip(
                  text: s.name,
                  isSelected: _sites.contains(s.key),
                  onTap: () => setState(() {
                    if (_sites.contains(s.key)) {
                      _sites.remove(s.key);
                    } else {
                      _sites.add(s.key);
                    }
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: _buildResults()),
      ],
    );
  }

  /// 选一条线路后返回（watcher 会在该线路内自动检索每一集）
  void _select(BtSearchResult r) {
    Navigator.pop(
      context,
      BtLine(
        siteKey: r.sourceKey,
        siteName: r.source,
        group: (r.fansub ?? '').trim().isNotEmpty
            ? r.fansub!.trim()
            : btGroupOf(r.title),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: color)),
  );

  Widget _buildResults() {
    final target = widget.episode ?? 0;
    final filtered = target <= 0
        ? _results
        : _results.where((r) {
            final ep = btEpisodeOf(r.title);
            return ep == 0 || ep == target;
          }).toList();
    final list = filtered.isNotEmpty ? filtered : _results;

    if (list.isEmpty) {
      if (_searching) {
        return const Center(child: PolygonRefreshIndicator(size: 60));
      }
      return Center(child: Text(_searched ? t.torrentEmpty : t.search));
    }

    // 按「站 + 组」分组（组即线路）
    final groups = <String, List<BtSearchResult>>{};
    for (final r in list) {
      final group = (r.fansub ?? '').trim().isNotEmpty
          ? r.fansub!.trim()
          : btGroupOf(r.title);
      groups
          .putIfAbsent('${r.sourceKey}\u0000${r.source}\u0000$group', () => [])
          .add(r);
    }
    final sourceOrder = {
      for (var i = 0; i < BtIndexers.all.length; i++) BtIndexers.all[i].key: i,
    };
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final pa = a.split('\u0000');
        final pb = b.split('\u0000');
        final sa = sourceOrder[pa[0]] ?? 99;
        final sb = sourceOrder[pb[0]] ?? 99;
        if (sa != sb) return sa.compareTo(sb);
        return pb[2].compareTo(pa[2]);
      });

    // 已有种子任务（按 infohash），用于标出「已添加/已完成」，避免重复下载
    final existing = <String, TorrentJobStatus>{};
    final jobs = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(torrentManagerProvider).jobs;
    for (final j in jobs) {
      final h = btInfoHashOfMagnet(j.magnet);
      if (h != null) existing[h] = j.status;
    }

    final children = <Widget>[];
    for (final key in keys) {
      final parts = key.split('\u0000');
      final groupList = groups[key]!
        ..sort((a, b) {
          final da = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final db = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return db.compareTo(da);
        });
      final collapsed = _collapsed.contains(key);
      final line = widget.currentLine;
      final isCurrent =
          line != null && line.siteKey == parts[0] && line.group == parts[2];
      TorrentJobStatus? existingStatus;
      for (final r in groupList) {
        final h = btInfoHashOfMagnet(r.magnet);
        final s = h == null ? null : existing[h];
        if (s == TorrentJobStatus.completed) {
          existingStatus = s;
          break;
        }
        existingStatus ??= s;
      }
      final cs = Theme.of(context).colorScheme;
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    collapsed ? Icons.chevron_right : Icons.expand_more,
                    color: cs.primary,
                  ),
                  title: Text(
                    parts[2].isEmpty ? parts[1] : '${parts[1]} · [${parts[2]}]',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Text('${groupList.length}'),
                      const SizedBox(width: 8),
                      if (isCurrent) _chip(t.torrentLineCurrent, cs.primary),
                      if (existingStatus != null)
                        _chip(
                          existingStatus == TorrentJobStatus.completed
                              ? t.completed
                              : t.torrentAdded,
                          existingStatus == TorrentJobStatus.completed
                              ? Colors.green
                              : cs.primary,
                        ),
                    ],
                  ),
                  trailing: TextButton(
                    onPressed: () => _select(groupList.first),
                    child: Text(t.apply),
                  ),
                  onTap: () => setState(() {
                    if (collapsed) {
                      _collapsed.remove(key);
                    } else {
                      _collapsed.add(key);
                    }
                  }),
                ),
                if (!collapsed)
                  for (final r in groupList)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(
                        left: 56,
                        right: 16,
                      ),
                      title: Text(
                        _cleanTitle(r.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (r.size > 0) _fmtSize(r.size),
                          if (r.createdAt != null) _fmtDate(r.createdAt),
                        ].join(' · '),
                      ),
                      onTap: () => _select(r),
                    ),
              ],
            ),
          ),
        ),
      );
    }
    if (_searching) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: PolygonRefreshIndicator(size: 36)),
        ),
      );
    }
    return ListView(controller: widget.scroll, children: children);
  }
}
