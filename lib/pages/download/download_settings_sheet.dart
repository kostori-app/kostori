import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/context.dart';
import 'package:kostori/foundation/log.dart';
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

class _DownloadSettingsSheet extends ConsumerStatefulWidget {
  const _DownloadSettingsSheet();

  @override
  ConsumerState<_DownloadSettingsSheet> createState() =>
      _DownloadSettingsSheetState();
}

class _DownloadSettingsSheetState extends ConsumerState<_DownloadSettingsSheet>
    with SingleTickerProviderStateMixin {
  TorrentManager get _m => ref.read(torrentManagerProvider.notifier);

  /// 下载 / 种子 两个设置页（可左右滑动切换）
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _m.init();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(torrentManagerProvider);
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
        _downloadDirectoryButton(),
      ],
    );
  }

  Widget _downloadDirectoryButton() {
    return SettingsActionButton(
      icon: Icons.folder_outlined,
      title: t.downloadDir,
      subtitle: _downloadDir(),
      onTap: () async {
        final dir = await selectDirectory();
        if (dir != null && dir.isNotEmpty) {
          appdata.implicitData['downloadDir'] = dir;
          appdata.writeImplicitData();
          setState(() {});
        }
      },
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

/// 种子设置：限速 / 做种 / Tracker / DHT。
class _TorrentSettings extends ConsumerStatefulWidget {
  const _TorrentSettings();

  @override
  ConsumerState<_TorrentSettings> createState() => _TorrentSettingsState();
}

class _TorrentSettingsState extends ConsumerState<_TorrentSettings> {
  TorrentManager get _m => ref.read(torrentManagerProvider.notifier);

  bool _changingPath = false;

  static const _speeds = [0, 1024, 2048, 5120, 10240, 20480];
  String _speedLabel(int kb) => kb == 0 ? t.torrentUnlimited : '$kb KB/s';

  @override
  Widget build(BuildContext context) {
    ref.watch(torrentManagerProvider);
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
        SettingsActionButton(
          icon: Icons.percent_outlined,
          title: t.torrentSeedRatioLimit,
          subtitle: _m.seedRatioLimit <= 0
              ? t.torrentUnlimited
              : _m.seedRatioLimit.toStringAsFixed(2),
          onTap: () => _editSeedRatio(context),
        ),
        SettingsActionButton(
          icon: Icons.badge_outlined,
          title: t.torrentPeerIdPrefix,
          subtitle: TorrentManager.torrentPeerIdPrefix,
          onTap: () => _editPeerIdPrefix(context),
        ),
        SettingsActionButton(
          icon: Icons.timer_outlined,
          title: t.torrentSeedTimeLimit,
          subtitle: _m.seedTimeLimitMinutes <= 0
              ? t.torrentUnlimited
              : '${_m.seedTimeLimitMinutes} ${t.torrentMinutes}',
          onTap: () => _editSeedTime(context),
        ),
        SettingsActionButton(
          icon: Icons.dns_outlined,
          title: t.torrentTrackers,
          subtitle: '${_m.trackers.length}',
          onTap: () => showPopUpWidget(context, const _TrackerEditorPage()),
        ),
        SettingsActionButton(
          icon: Icons.hub_outlined,
          title: t.torrentDht,
          subtitle: '${_m.dhtNodes.length}',
          onTap: () => showPopUpWidget(context, const _DhtNodesEditorPage()),
        ),
        SettingsActionButton(
          icon: Icons.folder_outlined,
          title: t.torrentDownloadDir,
          subtitle: TorrentManager.torrentDownloadDir,
          isLoading: _changingPath,
          onTap: _changingPath ? null : _pickTorrentDirectory,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _pickTorrentDirectory() async {
    final dir = await selectDirectory();
    if (!mounted || dir == null || dir.isEmpty) return;
    if (TorrentManager.torrentDownloadDir == dir) return;
    setState(() => _changingPath = true);
    context.showMessage(message: t.torrentMigrating);
    try {
      final result = await _m.setTorrentDownloadDir(dir);
      if (!mounted) return;
      context.showMessage(
        message: result.failed == 0
            ? t.torrentMigrationDone
            : t.torrentMigrationPartial,
        level: result.failed == 0 ? LogLevel.info : LogLevel.warning,
      );
    } catch (_) {
      if (mounted) {
        context.showMessage(
          message: t.torrentMigrationPartial,
          level: LogLevel.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _changingPath = false);
    }
  }

  Future<void> _editSeedRatio(BuildContext context) async {
    final ctrl = TextEditingController(
      text: _m.seedRatioLimit <= 0 ? '' : _m.seedRatioLimit.toString(),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.torrentSeedRatioLimit,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: t.torrentSeedRatioLimit,
            hintText: t.torrentSeedRatioLimitHint,
          ),
        ),
        actions: [
          Button.text(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          Button.filled(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value.isNaN || value.isNegative) return;
    setState(() => _m.seedRatioLimit = value);
  }

  Future<void> _editPeerIdPrefix(BuildContext context) async {
    final ctrl = TextEditingController(
      text: TorrentManager.torrentPeerIdPrefix,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.torrentPeerIdPrefix,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: t.torrentPeerIdPrefix,
            hintText: t.torrentPeerIdPrefixHint,
          ),
        ),
        actions: [
          Button.text(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          Button.filled(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null) return;
    final prefix = value.trim();
    if (prefix.length != 8 || prefix.codeUnits.any((byte) => byte > 255)) {
      if (mounted) context.showMessage(message: t.torrentPeerIdPrefixHint);
      return;
    }
    TorrentManager.torrentPeerIdPrefix = prefix;
    if (mounted) setState(() {});
  }

  Future<void> _editSeedTime(BuildContext context) async {
    final ctrl = TextEditingController(
      text: _m.seedTimeLimitMinutes <= 0
          ? ''
          : _m.seedTimeLimitMinutes.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.torrentSeedTimeLimit,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: t.torrentSeedTimeLimit,
            hintText: t.torrentSeedTimeLimitHint,
          ),
        ),
        actions: [
          Button.text(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          Button.filled(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: Text(t.confirm),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (value == null || value < 0) return;
    setState(() => _m.seedTimeLimitMinutes = value);
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
            alignment: WrapAlignment.start,
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

/// 二级页面：Tracker 列表编辑
class _TrackerEditorPage extends ConsumerStatefulWidget {
  const _TrackerEditorPage();

  @override
  ConsumerState<_TrackerEditorPage> createState() => _TrackerEditorPageState();
}

class _TrackerEditorPageState extends ConsumerState<_TrackerEditorPage> {
  TorrentManager get _m => ref.read(torrentManagerProvider.notifier);
  late final TextEditingController _urlCtrl = TextEditingController(
    text: _m.trackerUrl,
  );
  late final TextEditingController _trackersCtrl = TextEditingController(
    text: _m.trackers.join('\n'),
  );
  bool _fetching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _urlCtrl.dispose();
    _trackersCtrl.dispose();
    super.dispose();
  }

  void _debounced(void Function() action) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), action);
  }

  static List<String> _lines(String value) => value
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _fetch() async {
    _m.setTrackerUrl(_urlCtrl.text.trim());
    setState(() => _fetching = true);
    await _m.fetchTrackers();
    _trackersCtrl.text = _m.trackers.join('\n');
    if (mounted) setState(() => _fetching = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.torrentTrackers,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _card(
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(t.torrentTrackersAuto),
                  trailing: CustomSwitch(
                    value: _m.trackerAutoAdd,
                    onChanged: (v) => setState(() => _m.setTrackerAutoAdd(v)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _urlCtrl,
                        decoration: InputDecoration(
                          labelText: t.torrentTrackerUrlHint,
                          prefixIcon: const Icon(Icons.link, size: 18),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => _m.setTrackerUrl(v.trim()),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: CapsuleButton(
                          primary: true,
                          enabled: !_fetching,
                          leading: _fetching
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download, size: 18),
                          text: t.torrentFetchTrackers,
                          onTap: _fetch,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.list_alt, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            t.torrentTrackers,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_m.trackers.length}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: TextField(
                        controller: _trackersCtrl,
                        minLines: 8,
                        maxLines: 16,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                        decoration: InputDecoration(
                          hintText: t.torrentTrackersHint,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) =>
                            _debounced(() => _m.setTrackers(_lines(v))),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// 二级页面：DHT 引导节点编辑（内置节点始终生效，这里只追加自定义节点）
class _DhtNodesEditorPage extends ConsumerStatefulWidget {
  const _DhtNodesEditorPage();

  @override
  ConsumerState<_DhtNodesEditorPage> createState() =>
      _DhtNodesEditorPageState();
}

class _DhtNodesEditorPageState extends ConsumerState<_DhtNodesEditorPage> {
  TorrentManager get _m => ref.read(torrentManagerProvider.notifier);
  late final TextEditingController _ctrl = TextEditingController(
    text: _m.customNodes.join('\n'),
  );
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  static List<String> _lines(String value) => value
      .split(RegExp(r'[\s,]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.torrentDht,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                t.torrentDhtExplain,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.hub_outlined, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.torrentDht,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${_m.dhtNodes.length}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: TextField(
                        controller: _ctrl,
                        minLines: 4,
                        maxLines: 12,
                        style: const TextStyle(fontSize: 12, height: 1.4),
                        decoration: InputDecoration(
                          hintText: t.torrentNodesHint,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 700),
                            () {
                              _m.setCustomNodes(_lines(v));
                              if (mounted) setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
