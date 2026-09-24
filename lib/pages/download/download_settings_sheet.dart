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

class _DownloadSettingsSheetState extends State<_DownloadSettingsSheet> {
  int _tab = 0;
  final _m = TorrentManager.instance;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Sheet(
      title: t.downloadSettings,
      icon: Icons.settings_outlined,
      initialSize: 0.62,
      builder: (sheetCtx, sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: CapsuleOptions(
                scrollable: true,
                alignment: WrapAlignment.start,
                children: [
                  CapsuleOption(
                    text: t.download,
                    isSelected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  CapsuleOption(
                    text: t.torrentTab,
                    isSelected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            if (_tab == 0) _downloadSettings() else _torrentSettings(),
          ],
        ),
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
  Widget _torrentSettings() {
    const speeds = [0, 1024, 2048, 5120, 10240, 20480];
    String speedLabel(int kb) => kb == 0 ? t.torrentUnlimited : '$kb KB/s';
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(t.torrentSaveDir),
          subtitle: Text(
            TorrentManager.downloadDir,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _capsuleRow(
          label: t.torrentDownloadLimit,
          values: speeds,
          selected: _m.downloadLimitKb,
          labelOf: speedLabel,
          onSelected: (v) => setState(() => _m.downloadLimitKb = v),
        ),
        _capsuleRow(
          label: t.torrentUploadLimit,
          values: speeds,
          selected: _m.uploadLimitKb,
          labelOf: speedLabel,
          onSelected: (v) => setState(() => _m.uploadLimitKb = v),
        ),
        _switchTile(t.torrentDht, _m.dhtEnabled, _m.setDht),
        _switchTile(t.torrentLsd, _m.lsdEnabled, _m.setLsd),
        _switchTile(t.torrentUpnp, _m.upnpEnabled, _m.setUpnp),
        _switchTile(t.torrentEncrypt, _m.encryptEnabled, _m.setEncrypt),
        _switchTile(t.torrentStopSeed, _m.stopSeedAfterComplete, _m.setStopSeed),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: TrackerEditor(manager: _m),
        ),
      ],
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(title),
      trailing: CustomSwitch(
        value: value,
        onChanged: (v) {
          onChanged(v);
          setState(() {});
        },
      ),
    );
  }

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
            scrollable: true,
            alignment: WrapAlignment.start,
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

/// Tracker 列表编辑（地址 + 获取 + 多行）
class TrackerEditor extends StatefulWidget {
  const TrackerEditor({super.key, required this.manager});

  final TorrentManager manager;

  @override
  State<TrackerEditor> createState() => _TrackerEditorState();
}

class _TrackerEditorState extends State<TrackerEditor> {
  late final TextEditingController _urlCtrl = TextEditingController(
    text: widget.manager.trackerUrl,
  );
  late final TextEditingController _trackersCtrl = TextEditingController(
    text: widget.manager.trackers,
  );
  bool _fetching = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _trackersCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlCtrl,
          decoration: InputDecoration(
            labelText: t.torrentTrackerUrlHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _fetching
                  ? null
                  : () async {
                      widget.manager.setTrackerUrl(_urlCtrl.text.trim());
                      setState(() => _fetching = true);
                      await widget.manager.fetchTrackers();
                      _trackersCtrl.text = widget.manager.trackers;
                      setState(() => _fetching = false);
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
        const SizedBox(height: 8),
        TextField(
          controller: _trackersCtrl,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: t.torrentTrackersHint,
            border: const OutlineInputBorder(),
          ),
          onChanged: widget.manager.setTrackers,
        ),
      ],
    );
  }
}
