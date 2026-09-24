import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:kostori/utils/io.dart';

Future<void> showDownloadSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _DownloadSettingsSheet(),
  );
}

class _DownloadSettingsSheet extends StatefulWidget {
  const _DownloadSettingsSheet();

  @override
  State<_DownloadSettingsSheet> createState() => _DownloadSettingsSheetState();
}

class _DownloadSettingsSheetState extends State<_DownloadSettingsSheet>
    with SingleTickerProviderStateMixin {
  final _m = TorrentManager.instance;

  /// 下载 / 种子 两个设置页（可左右滑动切换）
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _m.init();
    _m.addListener(_onChange);
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _m.removeListener(_onChange);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sheet(
      title: t.downloadSettings,
      icon: Icons.settings_outlined,
      initialSize: 0.62,
      builder: (_, _) => Column(
        children: [
          CapsuleTabBar(
            controller: _tabCtrl,
            labels: [t.download, t.torrentTab],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: _downloadSettings(),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  child: _torrentSettings(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 下载 ──────────────────────────────────────────────────────────────────
  Widget _downloadSettings() {
    final concurrent = appdata.implicitData['downloadConcurrent'] as int? ?? 2;
    final segment =
        appdata.implicitData['downloadSegmentConcurrent'] as int? ?? 4;
    final wifiOnly = appdata.implicitData['downloadWifiOnly'] as bool? ?? false;
    final ignoreEpisodeTitle =
        appdata.implicitData['downloadIgnoreEpisodeTitle'] as bool? ?? false;
    return Column(
      children: [
        _capsuleRow(
          label: t.downloadConcurrent,
          values: const [1, 2, 3, 4],
          selected: concurrent,
          labelOf: (v) => '$v',
          onSelected: (v) {
            appdata.implicitData['downloadConcurrent'] = v;
            appdata.writeImplicitData();
            DownloadManager.instance.poke();
            setState(() {});
          },
        ),
        _capsuleRow(
          label: t.downloadSegmentConcurrent,
          values: const [1, 2, 4, 6, 8],
          selected: segment,
          labelOf: (v) => '$v',
          onSelected: (v) {
            appdata.implicitData['downloadSegmentConcurrent'] = v;
            appdata.writeImplicitData();
            setState(() {});
          },
        ),
        ListTile(
          title: Text(t.downloadIgnoreEpisodeTitle),
          subtitle: Text(t.downloadIgnoreEpisodeTitleDesc),
          trailing: CustomSwitch(
            value: ignoreEpisodeTitle,
            onChanged: (v) {
              appdata.implicitData['downloadIgnoreEpisodeTitle'] = v;
              appdata.writeImplicitData();
              setState(() {});
            },
          ),
        ),
        ListTile(
          title: Text(t.downloadWifiOnly),
          trailing: CustomSwitch(
            value: wifiOnly,
            onChanged: (v) {
              appdata.implicitData['downloadWifiOnly'] = v;
              appdata.writeImplicitData();
              setState(() {});
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(t.downloadDir),
          subtitle: Text(
            _downloadDir(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            final dir = await selectDirectory();
            if (dir != null && dir.isNotEmpty) {
              appdata.implicitData['downloadDir'] = dir;
              appdata.writeImplicitData();
              setState(() {});
            }
          },
        ),
      ],
    );
  }

  String _downloadDir() {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return TorrentManager.downloadDir;
  }

  // ── 种子 ──────────────────────────────────────────────────────────────────
  Widget _torrentSettings() => const _TorrentSettings();

  Widget _capsuleRow<T>({
    required String label,
    required List<T> values,
    required T selected,
    required String Function(T) labelOf,
    required ValueChanged<T> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          CapsuleOptions(
            wrap: true,
            alignment: WrapAlignment.center,
            children: [
              for (final v in values)
                CapsuleOption(
                  text: labelOf(v),
                  isSelected: v == selected,
                  onTap: () => onSelected(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 种子设置：限速 / 做种 / Tracker / DHT。
class _TorrentSettings extends StatefulWidget {
  const _TorrentSettings();

  @override
  State<_TorrentSettings> createState() => _TorrentSettingsState();
}

class _TorrentSettingsState extends State<_TorrentSettings> {
  final _m = TorrentManager.instance;
  late final TextEditingController _urlCtrl = TextEditingController(
    text: _m.trackerUrl,
  );
  late final TextEditingController _trackersCtrl = TextEditingController(
    text: _m.trackers.join('\n'),
  );
  late final TextEditingController _nodesCtrl = TextEditingController(
    text: _m.customNodes.join('\n'),
  );
  bool _fetching = false;
  Timer? _debounce;

  static const _speeds = [0, 1024, 2048, 5120, 10240, 20480];
  String _speedLabel(int kb) => kb == 0 ? t.torrentUnlimited : '$kb KB/s';

  void _debounced(void Function() action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), action);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlCtrl.dispose();
    _trackersCtrl.dispose();
    _nodesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _capsuleRow(
          t.torrentDownloadLimit,
          _m.downloadLimitKb,
          (v) => setState(() => _m.downloadLimitKb = v),
        ),
        _capsuleRow(
          t.torrentUploadLimit,
          _m.uploadLimitKb,
          (v) => setState(() => _m.uploadLimitKb = v),
        ),
        ListTile(
          title: Text(t.torrentStopSeed),
          trailing: CustomSwitch(
            value: _m.stopSeedAfterComplete,
            onChanged: (v) => setState(() => _m.stopSeedAfterComplete = v),
          ),
        ),
        const Divider(),
        ListTile(
          title: Text(t.torrentTrackersAuto),
          trailing: CustomSwitch(
            value: _m.trackerAutoAdd,
            onChanged: (v) => setState(() => _m.setTrackerAutoAdd(v)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: t.torrentTrackerUrlHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _m.setTrackerUrl(v.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _fetching
                    ? null
                    : () async {
                        _m.setTrackerUrl(_urlCtrl.text.trim());
                        setState(() => _fetching = true);
                        await _m.fetchTrackers();
                        _trackersCtrl.text = _m.trackers.join('\n');
                        if (mounted) setState(() => _fetching = false);
                      },
                icon: _fetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(t.torrentFetchTrackers),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _trackersCtrl,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(
              hintText: t.torrentTrackersHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _debounced(
              () => _m.setTrackers(
                v
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.hub_outlined),
          title: Text(t.torrentDht),
          subtitle: Text(t.torrentDhtExplain),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextField(
            controller: _nodesCtrl,
            minLines: 3,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: t.torrentNodesHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _debounced(
              () => _m.setCustomNodes(
                v
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _capsuleRow(String label, int selected, ValueChanged<int> onSelected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          CapsuleOptions(
            wrap: true,
            alignment: WrapAlignment.center,
            children: [
              for (final v in _speeds)
                CapsuleOption(
                  text: _speedLabel(v),
                  isSelected: v == selected,
                  onTap: () => onSelected(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
