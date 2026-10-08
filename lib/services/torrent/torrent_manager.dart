import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset/charset.dart' show gbk;
import 'package:crypto/crypto.dart' show sha1;
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/download_database.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/download/download_keep_alive.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/torrent/dht_client.dart';
import 'package:kostori/services/torrent/http_metadata_tracker_client.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/services/torrent/mobile_metadata_downloader.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_network.dart';
import 'package:kostori/services/torrent/torrent_stream_server.dart';
import 'package:path/path.dart' as p;

// 设置 key
const String kTorrentTrackers = 'torrentTrackers';
const String kTorrentTrackerAutoAdd = 'torrentTrackerAutoAdd';
const String kTorrentTrackerUrl = 'torrentTrackerUrl';
const String kTorrentDownloadLimit = 'torrentDownloadLimit';
const String kTorrentUploadLimit = 'torrentUploadLimit';
const String kTorrentStopSeed = 'torrentStopSeed';
const String kTorrentSeedRatioLimit = 'torrentSeedRatioLimit';
const String kTorrentSeedTimeLimit = 'torrentSeedTimeLimit';
const String kTorrentCustomNodes = 'torrentCustomNodes';
const String kTorrentDownloadDir = 'torrentDownloadDir';

/// `selectedFiles` 哨兵：表示「一个文件都不选」。空列表仍表示「全部」（兼容旧数据）。
const int kTorrentNoFile = -1;

/// 元数据发现失败。网络发现本身采用退避重试，不用固定总时长截断。
class TorrentMetadataTimeout implements Exception {
  const TorrentMetadataTimeout({this.vpnActive = false});

  final bool vpnActive;

  @override
  String toString() => 'torrent metadata timeout';
}

/// 内置公共 tracker；与磁力自带、用户在「种子设置」里配置的列表合并去重后使用。
const List<String> kDefaultTrackers = [
  'http://1337.abcvg.info:80/announce',
  'http://bt1.archive.org:6969/announce',
  'http://bt2.archive.org:6969/announce',
  'http://ipv4announce.sktorrent.eu:6969/announce',
  'http://nyaa.tracker.wf:7777/announce',
  'http://torrentsmd.com:8080/announce',
  'http://tracker.bt4g.com:2095/announce',
  'http://tracker.dhitechnical.com:6969/announce',
  'http://tracker.mywaifu.best:6969/announce',
  'http://tracker.renfei.net:8080/announce',
  'http://tracker.waaa.moe:6969/announce',
  'http://tracker810.xyz:11450/announce',
  'http://www.wareztorrent.com:80/announce',
  'https://004430.xyz:443/announce',
  'https://1337.abcvg.info:443/announce',
  'https://ht.therarbg.to:443/announce',
  'https://t.213891.xyz:443/announce',
  'https://tr.abiir.top:443/announce',
  'https://tr.abir.ga:443/announce',
  'https://tr.zukizuki.org:443/announce',
  'https://tracker.7471.top:443/announce',
  'https://tracker.bt4g.com:443/announce',
  'https://tracker.foreverpirates.co:443/announce',
  'https://tracker.gcrenwp.top:443/announce',
  'https://tracker.kuroy.me:443/announce',
  'https://tracker.leechshield.link:443/announce',
  'https://tracker.linvk.com:443/announce',
  'https://tracker.nekomi.cn:443/announce',
  'https://tracker.pmman.tech:443/announce',
  'https://tracker.yemekyedim.com:443/announce',
  'https://tracker.zhuqiy.com:443/announce',
  'https://tracker1.520.jp:443/announce',
  'udp://bittorrent-tracker.e-n-c-r-y-p-t.net:1337/announce',
  'udp://evan.im:6969/announce',
  'udp://explodie.org:6969/announce',
  'udp://ipv6.govt.hu:6969/announce',
  'udp://mail.segso.net:6969/announce',
  'udp://martin-gebhardt.eu:25/announce',
  'udp://ns575949.ip-51-222-82.net:6969/announce',
  'udp://obey.torrentonline.cc:42069/announce',
  'udp://open.demonii.com:1337/announce',
  'udp://open.ftorrent.com:443/announce',
  'udp://open.stealth.si:80/announce',
  'udp://open.tracker.ink:6969/announce',
  'udp://opentor.org:2710/announce',
  'udp://p4p.arenabg.com:1337/announce',
  'udp://retracker.hotplug.ru:2710/announce',
  'udp://t.overflow.biz:6969/announce',
  'udp://torrent.tracker.durukanbal.com:6969/announce',
  'udp://torrentclub.online:1984/announce',
  'udp://torrentclub.online:54123/announce',
  'udp://tr.btube3.com:2010/announce',
  'udp://tr3.ysagin.top:2715/announce',
  'udp://tracker-udp.gbitt.info:80/announce',
  'udp://tracker.0x7c0.com:6969/announce',
  'udp://tracker.aruku.ovh:8081/announce',
  'udp://tracker.auctor.tv:6969/announce',
  'udp://tracker.breizh.pm:6969/announce',
  'udp://tracker.cn.nyaa.net:6969/announce',
  'udp://tracker.corpscorp.online:80/announce',
  'udp://tracker.cynma.tv:6969/announce',
  'udp://tracker.dler.com:6969/announce',
  'udp://tracker.dler.org:6969/announce',
  'udp://tracker.farted.net:6969/announce',
  'udp://tracker.gmi.gd:6969/announce',
  'udp://tracker.ilibr.org:6969/announce',
  'udp://tracker.k.vu:6969/announce',
  'udp://tracker.nexusstream.eu:6969/announce',
  'udp://tracker.nyaa.net:6969/announce',
  'udp://tracker.opentrackr.com:6969/announce',
  'udp://tracker.opentrackr.org:1337/announce',
  'udp://tracker.peerfect.org:6969/announce',
  'udp://tracker.publictracker.xyz:6969/announce',
  'udp://tracker.qu.ax:6969/announce',
  'udp://tracker.skyts.net:6969/announce',
  'udp://tracker.teambelgium.net:6969/announce',
  'udp://tracker.torrent.eu.org:451/announce',
  'udp://whybother.torrentonline.cc:42069/announce',
  'udp://zer0day.ch:1337/announce',
  'wss://tracker.openwebtorrent.com:443/announce',
];

/// 内置公共 DHT 引导节点。
///
/// 库自带的 [StandaloneDHT] 存在响应解码缺陷，元数据抓取改用 [DhtClient]
/// （BEP 5），节点列表需自行剔除已下线的主机。
const List<String> kDefaultDhtNodes = [
  'udp://dht.transmissionbt.com:6881',
  'udp://router.bittorrent.com:6881',
  'udp://dht.libtorrent.org:25401',
  'udp://dht.vuze.com:6881',
  'udp://router.utorrent.com:6881',
];

/// 视频/音频扩展名，用于判断是否可播放。
const _streamableExt = {
  'mp4',
  'mkv',
  'avi',
  'mov',
  'm4v',
  'webm',
  'ts',
  'flv',
  'wmv',
  'rmvb',
  'rm',
  'mpg',
  'mpeg',
  'mp3',
  'flac',
  'aac',
  'm4a',
};

bool _isStreamableName(String name) {
  final i = name.lastIndexOf('.');
  if (i < 0) return false;
  return _streamableExt.contains(name.substring(i + 1).toLowerCase());
}

/// 种子管理器对外暴露的不可变状态快照：每次变更都会换新实例，
/// 驱动 Riverpod `ref.watch` 重建。
class TorrentState {
  const TorrentState(this.jobs);
  final List<TorrentJob> jobs;
}

/// 用户主动停止导致元数据抓取被取消（不是失败）。
class TorrentFetchCancelled implements Exception {
  const TorrentFetchCancelled();

  @override
  String toString() => 'torrent metadata fetch cancelled';
}

/// 修改种子下载目录后的迁移结果。
class TorrentPathMigrationResult {
  const TorrentPathMigrationResult({this.migrated = 0, this.failed = 0});

  final int migrated;
  final int failed;
}

/// 移动网络下不要把磁力里的全部 tracker 一次交给元数据引擎。
/// 按协议各取少量候选，既保留 HTTPS/HTTP/UDP 的可用路径，也避免几十个
/// 失效 tracker 同时创建 socket，拖慢真正有 peer 的 tracker。
List<Uri> _mobileMetadataTrackers(Iterable<Uri> trackers) {
  const maxTrackers = 16;
  const perScheme = 4;
  final groups = <String, List<Uri>>{
    'https': [],
    'wss': [],
    'http': [],
    'ws': [],
    'udp': [],
  };
  final other = <Uri>[];
  final seen = <String>{};
  for (final tracker in trackers) {
    if (!seen.add(tracker.toString())) continue;
    final scheme = tracker.scheme.toLowerCase();
    (groups[scheme] ?? other).add(tracker);
  }

  final selected = <Uri>[];
  for (final scheme in const ['https', 'wss', 'http', 'ws', 'udp']) {
    selected.addAll(groups[scheme]!.take(perScheme));
  }
  for (final scheme in const ['https', 'wss', 'http', 'ws', 'udp']) {
    for (final tracker in groups[scheme]!.skip(perScheme)) {
      if (selected.length >= maxTrackers) break;
      selected.add(tracker);
    }
    if (selected.length >= maxTrackers) break;
  }
  for (final tracker in other) {
    if (selected.length >= maxTrackers) break;
    selected.add(tracker);
  }
  return selected.take(maxTrackers).toList(growable: false);
}

/// Limit the tracker clients created by the download engine.
///
/// The complete tracker list remains available to the UI, but starting one
/// client for every URL in a large torrent can create hundreds of sockets and
/// retry timers on a phone. Keep a small sample from each protocol and then
/// fill the remaining slots in the original order so private/custom trackers
/// near the front of the list keep their priority.
List<Uri> _activeTorrentTrackers(Iterable<Uri> trackers, {required int limit}) {
  if (limit <= 0) return const [];
  final groups = <String, List<Uri>>{
    'https': [],
    'wss': [],
    'http': [],
    'ws': [],
    'udp': [],
  };
  final all = <Uri>[];
  final seen = <String>{};
  for (final tracker in trackers) {
    if (!seen.add(tracker.toString())) continue;
    all.add(tracker);
    (groups[tracker.scheme.toLowerCase()] ??= []).add(tracker);
  }
  if (all.length <= limit) return all;

  final selected = <Uri>[];
  final selectedKeys = <String>{};
  final perScheme = (limit ~/ groups.length).clamp(1, limit).toInt();
  for (final scheme in const ['https', 'wss', 'http', 'ws', 'udp']) {
    for (final tracker in groups[scheme]!.take(perScheme)) {
      if (selected.length >= limit) break;
      if (selectedKeys.add(tracker.toString())) selected.add(tracker);
    }
  }
  for (final tracker in all) {
    if (selected.length >= limit) break;
    if (selectedKeys.add(tracker.toString())) selected.add(tracker);
  }
  return selected;
}

/// 种子任务管理器（基于纯 Dart 的 dtorrent_task_v2，Riverpod Notifier）。
///
/// 引擎实例只在需要时创建/启动；重启后只加载已持久化的 `.torrent`，
/// 不会自动下载，等用户手动开始。
class TorrentManager extends Notifier<TorrentState> {
  /// Maximum number of tracker clients allowed for one running task.
  /// Mobile relay connections are more expensive, so keep their fan-out lower.
  static int get activeTrackerLimit =>
      Platform.isAndroid || Platform.isIOS ? 6 : 32;

  /// Maximum number of connected peers retained per running task.
  ///
  /// The engine's hard-coded limit is 50 and counts idle sockets too. A lower
  /// app-level cap keeps mobile downloads responsive when several tasks run at
  /// once; low-activity peers are released when the cap is exceeded.
  static int get activePeerLimit =>
      Platform.isAndroid || Platform.isIOS ? 12 : 24;

  /// Combines recent download and upload rates for peer admission decisions.
  /// Rates are in KiB/s and invalid values are treated as idle.
  static double peerTransferScore({
    required double downloadRate,
    required double uploadRate,
  }) {
    final download = downloadRate.isFinite && downloadRate > 0
        ? downloadRate
        : 0.0;
    final upload = uploadRate.isFinite && uploadRate > 0 ? uploadRate : 0.0;
    return download + upload;
  }

  /// Public pure helper for tests and callers that need the same engine limit.
  static List<Uri> limitActiveTrackerUris(
    Iterable<Uri> trackers, {
    int? limit,
  }) => _activeTorrentTrackers(trackers, limit: limit ?? activeTrackerLimit);

  @override
  TorrentState build() {
    ref.onDispose(_disposeInternal);
    // 初始化包含磁盘读写；保留在微任务中，但不能让异常变成未处理的
    // unhandled Future（启动时数据库暂时不可用时尤其容易发生）。
    Future.microtask(
      () => init().catchError((e, s) {
        Log.error('种子管理器初始化失败', '$e\n$s');
      }),
    );
    return const TorrentState([]);
  }

  List<TorrentJob> get jobs => state.jobs;

  /// 兼容旧 UI 命名。
  List<TorrentJob> get tasks => jobs;

  void _emit() {
    state = TorrentState(List.unmodifiable(_jobs));
    _syncKeepAlive();
  }

  bool _initialized = false;
  Future<void>? _initializing;
  Future<void>? _loadingJobs;
  bool _jobsLoaded = false;

  final List<TorrentJob> _jobs = [];

  final Map<String, TorrentTask> _engines = {};
  final Map<String, TorrentModel> _models = {};
  final Map<String, TorrentStreamServer> _servers = {};
  final Map<String, DateTime> _uploadSamples = {};
  final Map<String, ({DateTime at, int uploaded})> _peerUploadSamples = {};
  final Set<String> _peerTrimPending = {};
  final Set<String> _started = {};
  final Set<String> _starting = {};

  /// 记录用户主动暂停的任务，阻止后台恢复流程在同一进程内重新启动。
  final Set<String> _pausedByUser = {};

  /// 已完成任务切换到只上传模式后，避免每次轮询重复写入优先级。
  final Set<String> _downloadBlockedAfterCompletion = {};
  final Set<String> _fileMutations = {};
  final Set<String> _refetching = {};
  final Set<String> _wantStart = {};

  /// 每个任务已自动重试抓取元数据的次数，防止「抓到但解析不出来」时无限循环。
  final Map<String, int> _refetchAttempts = {};

  /// 正在进行的元数据抓取与其取消信号，用户按「暂停」时立刻中止网络动作。
  final Map<String, Completer<void>> _fetchCancels = {};
  final Map<String, Future<void>> _resumeOperations = {};
  final Map<String, Future<void>> _prepareOperations = {};

  /// 元数据发现失败后的固定重试间隔。
  static const Duration _metadataRetryInterval = Duration(seconds: 60);

  /// 自动重试抓取元数据的次数上限，超过即判定为不可用。
  static const int _maxMetadataAttempts = 3;

  /// 元数据发现重试的最长间隔（秒）。
  static int get metadataRetryCeilingSeconds =>
      _metadataRetryInterval.inSeconds;

  /// 兼容旧调用；现在表示单次发现重试的上限，不是整个抓取总时长。
  static int get metadataTimeoutSeconds => metadataRetryCeilingSeconds;

  /// 对外暴露的自动重试次数上限。
  static int get maxMetadataAttempts => _maxMetadataAttempts;

  Directory? _torrentDir;
  int _persistTick = 0;
  String _lastSyncSig = '';
  DateTime? _lastKeepAlive;
  static int _jobIdSeq = 0;

  static String _newJobId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_jobIdSeq++}';
  Future<void> _writeChain = Future.value();
  Timer? _syncTimer;

  /// 普通下载使用的目录（未设置种子专用目录时也是种子的兼容目录）。
  static String get downloadDir {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return p.join(App.dataPath, 'downloads');
  }

  /// 种子专用下载目录。
  ///
  /// 没有该设置时继续使用旧的公共下载目录，保证升级后旧任务和新任务
  /// 都沿用原来的位置；只有用户主动选择目录后才启用独立路径。
  static String get torrentDownloadDir {
    final dir = appdata.implicitData[kTorrentDownloadDir] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return downloadDir;
  }

  /// 固定客户端前缀；旧配置不能覆盖标识。
  static const String torrentPeerIdPrefix = idPrefix;

  /// 设置种子专用目录，并把已有任务的文件和状态一并迁移过去。
  ///
  /// 任务自己的 [TorrentJob.savePath] 仍然是最终依据。迁移失败时保留旧
  /// 路径，任务不会因为设置变更而消失；新任务从下一次添加开始使用新目录。
  Future<TorrentPathMigrationResult> setTorrentDownloadDir(String value) async {
    await init();
    final target = value.trim();
    if (target.isEmpty) return const TorrentPathMigrationResult();
    final previous = torrentDownloadDir;
    if (p.equals(previous, target)) {
      appdata.implicitData[kTorrentDownloadDir] = target;
      appdata.writeImplicitData();
      return const TorrentPathMigrationResult();
    }

    appdata.implicitData[kTorrentDownloadDir] = target;
    appdata.writeImplicitData();
    var migrated = 0;
    var failed = 0;
    for (final job in List<TorrentJob>.from(_jobs)) {
      if (job.savePath.isNotEmpty && p.equals(job.savePath, target)) {
        continue;
      }
      // 元数据还没拿到时没有实际文件，直接更新任务的未来保存目录；
      // 旧任务有引擎时则必须先搬文件和状态文件再改 savePath。
      if (_engines[job.id] == null && _models[job.id] == null) {
        job.savePath = target;
        migrated++;
        continue;
      }
      try {
        if (await _migrateTorrentJob(job, target)) {
          migrated++;
        } else {
          failed++;
        }
      } catch (error, stack) {
        failed++;
        Log.error('迁移种子目录失败', '${job.name}: $error\n$stack');
      }
    }
    _persist();
    _emit();
    return TorrentPathMigrationResult(migrated: migrated, failed: failed);
  }

  // ── 设置 ──────────────────────────────────────────────────────────────────
  static String _readList(Map<String, dynamic> m, String key) {
    final raw = m[key];
    if (raw is List) return raw.map((e) => e.toString()).join('\n');
    if (raw is String) return raw;
    return '';
  }

  List<String> get trackers => _readList(
    appdata.implicitData,
    kTorrentTrackers,
  ).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void setTrackers(List<String> list) {
    appdata.implicitData[kTorrentTrackers] = list
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    appdata.writeImplicitData();
    // 只对已启动的任务补发 announce（未启动的还没绑定端口）
    for (final job in _jobs) {
      if (!_started.contains(job.id)) continue;
      final engine = _engines[job.id];
      final model = _models[job.id];
      if (engine == null || model == null) continue;
      final configured = _parseTrackers(
        _readList(appdata.implicitData, kTorrentTrackers).split('\n'),
      );
      for (final tr in limitActiveTrackerUris(configured)) {
        try {
          engine.startAnnounceUrl(
            tr,
            model.v1InfoHash ?? model.truncatedInfoHash,
          );
        } catch (_) {}
      }
    }
    _emit();
  }

  bool get trackerAutoAdd =>
      (appdata.implicitData[kTorrentTrackerAutoAdd] as bool?) ?? true;

  void setTrackerAutoAdd(bool v) {
    appdata.implicitData[kTorrentTrackerAutoAdd] = v;
    appdata.writeImplicitData();
    _emit();
  }

  String get trackerUrl =>
      (appdata.implicitData[kTorrentTrackerUrl] as String?) ?? '';

  void setTrackerUrl(String v) {
    appdata.implicitData[kTorrentTrackerUrl] = v;
    appdata.writeImplicitData();
  }

  /// 从 [trackerUrl] 拉取 tracker 列表并保存。
  Future<void> fetchTrackers() async {
    final url = trackerUrl.trim();
    if (url.isEmpty) return;
    final client = TorrentNetwork.createHttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(const SystemEncoding().decoder).join();
      final list =
          body
              .split(RegExp(r'\s+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s.contains('://'))
              .toSet()
              .toList()
            ..sort();
      if (list.isNotEmpty) setTrackers(list);
    } catch (_) {
      // ignore: empty_catches
    } finally {
      client.close(force: true);
    }
  }

  int get downloadLimitKb =>
      (appdata.implicitData[kTorrentDownloadLimit] as int?) ?? 0;

  set downloadLimitKb(int v) {
    appdata.implicitData[kTorrentDownloadLimit] = v;
    appdata.writeImplicitData();
    _applyLimitsToAll();
    _emit();
  }

  int get uploadLimitKb =>
      (appdata.implicitData[kTorrentUploadLimit] as int?) ?? 0;

  set uploadLimitKb(int v) {
    appdata.implicitData[kTorrentUploadLimit] = v;
    appdata.writeImplicitData();
    _applyLimitsToAll();
    _emit();
  }

  bool get stopSeedAfterComplete =>
      (appdata.implicitData[kTorrentStopSeed] as bool?) ?? false;

  set stopSeedAfterComplete(bool v) {
    if (stopSeedAfterComplete == v) return;
    appdata.implicitData[kTorrentStopSeed] = v;
    appdata.writeImplicitData();
    if (v) _stopCompletedSeeding();
    _syncKeepAlive(force: true);
    _persist();
    _emit();
  }

  /// 分享率上限（0 表示不限）。
  double get seedRatioLimit =>
      ((appdata.implicitData[kTorrentSeedRatioLimit] as num?)?.toDouble() ?? 0)
          .clamp(0, 1000)
          .toDouble();

  set seedRatioLimit(double value) {
    final next = value.clamp(0, 1000).toDouble();
    appdata.implicitData[kTorrentSeedRatioLimit] = next;
    appdata.writeImplicitData();
    _applySeedLimitsToAll();
    _emit();
  }

  /// 做种时长上限，单位分钟（0 表示不限）。
  int get seedTimeLimitMinutes =>
      ((appdata.implicitData[kTorrentSeedTimeLimit] as num?)?.toInt() ?? 0)
          .clamp(0, 365 * 24 * 60);

  set seedTimeLimitMinutes(int value) {
    final next = value.clamp(0, 365 * 24 * 60);
    appdata.implicitData[kTorrentSeedTimeLimit] = next;
    appdata.writeImplicitData();
    _applySeedLimitsToAll();
    _emit();
  }

  bool _seedLimitReached(TorrentJob job) {
    if (!job.isFinished && job.progress < 1.0) return false;
    final ratioLimit = seedRatioLimit;
    if (ratioLimit > 0 && job.totalWanted > 0) {
      if (job.uploadedBytes / job.totalWanted >= ratioLimit) return true;
    }
    final timeLimit = seedTimeLimitMinutes;
    if (timeLimit > 0 && job.seedingStartedAt != null) {
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - job.seedingStartedAt!;
      if (elapsed >= timeLimit * Duration.millisecondsPerMinute) return true;
    }
    return false;
  }

  void _applySeedLimitsToAll() {
    var changed = false;
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null || engine.state != TaskState.running) continue;
      if (!_seedLimitReached(job)) continue;
      try {
        engine.pause();
        _pauseTransfer(job);
        changed = true;
      } catch (_) {}
    }
    if (changed) {
      _syncKeepAlive(force: true);
      _persist();
    }
  }

  void _stopCompletedSeeding() {
    var changed = false;
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null || engine.state != TaskState.running) continue;
      if (job.status != TorrentJobStatus.completed && job.progress < 1.0) {
        continue;
      }
      try {
        engine.pause();
        _pauseTransfer(job);
        changed = true;
      } catch (_) {}
    }
    if (changed) _syncKeepAlive(force: true);
  }

  /// 自定义 DHT 引导节点。`host:port` 会被补成 `udp://host:port`，
  /// 否则被 [\_parseTrackers] 当成无效条目丢掉。
  List<String> get customNodes => _readList(
    appdata.implicitData,
    kTorrentCustomNodes,
  ).split('\n').map(normalizeDhtNode).where((e) => e.isNotEmpty).toList();

  static String normalizeDhtNode(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    if (!s.contains('://')) s = 'udp://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return '';
    return uri.port == 0 ? 'udp://${uri.host}:6881' : s;
  }

  void setCustomNodes(List<String> list) {
    final nodes = list
        .map(normalizeDhtNode)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    appdata.implicitData[kTorrentCustomNodes] = nodes;
    appdata.writeImplicitData();
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null) continue;
      for (final n in _parseTrackers(nodes)) {
        try {
          engine.addDHTNode(n);
        } catch (_) {}
      }
    }
    _emit();
  }

  void _applyLimitsToAll() {
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null) continue;
      _applyLimits(engine);
    }
  }

  static const _limitWindowId = 'global-limit';

  void _applyLimits(TorrentTask task) {
    final d = downloadLimitKb * 1024;
    final u = uploadLimitKb * 1024;
    try {
      if (d <= 0 && u <= 0) {
        task.removeScheduleWindow(_limitWindowId);
        task.stopScheduling();
        return;
      }
      task.addScheduleWindow(
        ScheduleWindow(
          id: _limitWindowId,
          weekdays: const {1, 2, 3, 4, 5, 6, 7},
          start: Duration.zero,
          end: const Duration(hours: 23, minutes: 59, seconds: 59),
          maxDownloadRate: d > 0 ? d : null,
          maxUploadRate: u > 0 ? u : null,
          pauseOutsideWindow: false,
        ),
      );
      task.startScheduling(tick: const Duration(seconds: 20));
    } catch (_) {}
  }

  static List<Uri> _parseTrackers(List<String> raw) {
    final out = <Uri>[];
    for (final line in raw) {
      for (final part in line.split(RegExp(r'[\s,]+'))) {
        final t = part.trim();
        if (t.isEmpty || !t.contains('://')) continue;
        final uri = Uri.tryParse(t);
        if (uri != null) out.add(uri);
      }
    }
    return out;
  }

  // ── 初始化 ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final future = _initInternal();
    _initializing = future;
    try {
      await future;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }
  }

  Future<void> _initInternal() async {
    await _ensureJobsLoaded();
    // Publish the restored list before preparing every engine. The preparation
    // can involve piece and file state recovery; the first frame must remain
    // interactive while that work is in progress.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sync());
    _initialized = true;
    _emit();
    for (final job in _jobs) {
      // refetch: false —— 仅恢复本地状态；元数据抓取是网络动作，
      // 进程重启后不自动重试。
      await _prepareEngine(job, start: false, refetch: false);
    }
    _emit();
  }

  void _disposeInternal() {
    _initialized = false;
    _jobsLoaded = false;
    _loadingJobs = null;
    for (final cancel in _fetchCancels.values) {
      if (!cancel.isCompleted) cancel.complete();
    }
    _fetchCancels.clear();
    _resumeOperations.clear();
    _prepareOperations.clear();
    _wantStart.clear();
    _starting.clear();
    _pausedByUser.clear();
    _downloadBlockedAfterCompletion.clear();
    _fileMutations.clear();
    _syncTimer?.cancel();
    _syncTimer = null;
    for (final server in _servers.values) {
      unawaited(server.stop());
    }
    _servers.clear();
    _uploadSamples.clear();
    _peerUploadSamples.clear();
    _peerTrimPending.clear();
    for (final engine in _engines.values) {
      try {
        unawaited(engine.dispose());
      } catch (_) {}
    }
    _engines.clear();
    unawaited(DownloadKeepAlive.detach(DownloadKeepAlive.ownerTorrent));
  }

  Future<void> _loadJobs() async {
    try {
      final jsons = await DownloadDatabase.instance.loadJobJson();
      for (final j in jsons) {
        try {
          final e = jsonDecode(j);
          if (e is Map<String, dynamic>) _jobs.add(TorrentJob.fromJson(e));
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _ensureJobsLoaded() {
    if (_jobsLoaded) return Future<void>.value();
    final pending = _loadingJobs;
    if (pending != null) return pending;
    final future = () async {
      _torrentDir = Directory(p.join(App.dataPath, 'torrent_meta'));
      if (!await _torrentDir!.exists()) {
        await _torrentDir!.create(recursive: true);
      }
      await _loadJobs();
      _jobsLoaded = true;
    }();
    _loadingJobs = future;
    return future.whenComplete(() {
      if (identical(_loadingJobs, future)) _loadingJobs = null;
    });
  }

  void _persist() {
    final jsons = _jobs.map((j) => jsonEncode(j.toJson())).toList();
    _writeChain = _writeChain
        .then((_) => DownloadDatabase.instance.saveJobJson(jsons))
        .catchError((_) {});
  }

  // ── 添加 ──────────────────────────────────────────────────────────────────
  Future<TorrentJob> add(
    String magnet, {
    TorrentStopPolicy stopAfter = TorrentStopPolicy.none,
  }) async {
    await _ensureReadyForOperation();
    // 支持直接粘裸 infohash（BT 客户端「复制 info hash」得到的即是此格式）
    final normalized = normalizeMagnet(magnet);
    // 同 infohash 的任务直接复用：元数据已在则返回，否则补一次后台抓取。
    final ih = _infoHashOf(normalized);
    if (ih != null) {
      for (final j in _jobs) {
        if (_infoHashOf(j.magnet) != ih) continue;
        if (_models.containsKey(j.id)) return j;
        if (_refetching.add(j.id)) unawaited(_refetchMetadata(j));
        return j;
      }
    }
    final id = _newJobId();
    final effectiveMagnet = _augmentTrackers(normalized);
    final job = TorrentJob(
      id: id,
      magnet: effectiveMagnet,
      torrentPath: p.join(_torrentDir!.path, '$id.torrent'),
      savePath: torrentDownloadDir,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: TorrentJobStatus.metadata,
      stopAfter: stopAfter,
      // 拿到元数据后在 _prepareEngine 里确定默认选择（首选最大的视频文件）
      selectionInitialized: false,
    );
    _jobs.insert(0, job);
    _persist();
    _emit();

    try {
      final bytes = await _fetchMetadata(effectiveMagnet, jobId: job.id);
      if (!_jobs.contains(job)) return job;
      await File(job.torrentPath).writeAsBytes(bytes, flush: true);
      if (!_jobs.contains(job)) return job;
      await _prepareEngine(
        job,
        start: stopAfter != TorrentStopPolicy.afterMetadata,
      );
      if (job.status == TorrentJobStatus.failed) {
        App.rootContext.showMessage(
          message: '${t.downloadFailed}: ${job.error ?? ''}',
        );
      }
    } on TorrentFetchCancelled {
      job.status = TorrentJobStatus.paused;
    } catch (e) {
      job.status = TorrentJobStatus.failed;
      job.error = e.toString();
      App.rootContext.showMessage(message: '${t.downloadFailed}: $e');
    }
    _persist();
    _emit();
    return job;
  }

  /// 从 `.torrent` 文件字节导入任务：元数据已随文件提供，无需网络抓取。
  /// 解析失败返回 null（已提示）。
  Future<TorrentJob?> addTorrentFile(
    Uint8List bytes, {
    TorrentStopPolicy stopAfter = TorrentStopPolicy.none,
  }) async {
    await _ensureReadyForOperation();
    final TorrentModel model;
    try {
      // The pinned engine's parseBytes() currently compares the encoded key
      // (`4:info`) with the decoded text (`info`) and rejects every complete
      // .torrent file. Extract the original info dictionary here, then use the
      // parser path intended for BEP 09 payloads; it preserves the exact bytes
      // needed for the info hash.
      final infoBytes = _extractInfoDictionary(bytes);
      if (infoBytes == null) {
        throw const FormatException('missing info dictionary');
      }
      model = TorrentParser.parseFromInfoBytes(
        infoBytes,
        announces: _extractAnnounces(bytes),
      );
    } catch (e) {
      App.rootContext.showMessage(message: '${t.downloadFailed}: $e');
      return null;
    }
    final infoHash = model.infoHash;
    for (final j in _jobs) {
      if (j.magnet.isEmpty || _infoHashOf(j.magnet) != infoHash) continue;
      if (_models.containsKey(j.id)) return j;
      if (_refetching.add(j.id)) unawaited(_refetchMetadata(j));
      return j;
    }
    final id = _newJobId();
    final job = TorrentJob(
      id: id,
      magnet: _magnetOfModel(model),
      torrentPath: p.join(_torrentDir!.path, '$id.torrent'),
      savePath: torrentDownloadDir,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: TorrentJobStatus.metadata,
      stopAfter: stopAfter,
      selectionInitialized: false,
    );
    _jobs.insert(0, job);
    _persist();
    _emit();

    try {
      final infoBytes = model.infoDictBytes;
      if (infoBytes == null) {
        throw const FormatException('missing info dictionary');
      }
      await File(job.torrentPath).writeAsBytes(infoBytes, flush: true);
      await _prepareEngine(
        job,
        start: stopAfter != TorrentStopPolicy.afterMetadata,
      );
      if (job.status == TorrentJobStatus.failed) {
        App.rootContext.showMessage(
          message: '${t.downloadFailed}: ${job.error ?? ''}',
        );
      }
    } catch (e) {
      job.status = TorrentJobStatus.failed;
      job.error = e.toString();
      App.rootContext.showMessage(message: '${t.downloadFailed}: $e');
    }
    _persist();
    _emit();
    return job;
  }

  /// Extract the raw bencoded `info` value from a complete metainfo file.
  ///
  /// Hashing a decoded and re-encoded map is not equivalent for torrent files:
  /// byte strings such as `pieces` must remain byte-for-byte identical.
  static Uint8List? _extractInfoDictionary(Uint8List bytes) {
    try {
      if (bytes.isEmpty || bytes[0] != 0x64) return null; // `d`
      var offset = 1;
      while (offset < bytes.length && bytes[offset] != 0x65) {
        final keyStart = offset;
        offset = _skipBencoded(bytes, offset);
        final key = String.fromCharCodes(bytes.sublist(keyStart, offset));
        final valueStart = offset;
        offset = _skipBencoded(bytes, offset);
        if (key == '4:info') {
          return Uint8List.sublistView(bytes, valueStart, offset);
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Read the root-level `announce` value without re-encoding the metainfo.
  /// The first announce is enough to retain private/special trackers when a
  /// complete torrent is imported; the global tracker fallback fills gaps.
  static List<Uri> _extractAnnounces(Uint8List bytes) {
    try {
      if (bytes.isEmpty || bytes[0] != 0x64) return const [];
      var offset = 1;
      while (offset < bytes.length && bytes[offset] != 0x65) {
        final keyStart = offset;
        offset = _skipBencoded(bytes, offset);
        final key = String.fromCharCodes(bytes.sublist(keyStart, offset));
        final valueStart = offset;
        final valueEnd = _skipBencoded(bytes, offset);
        if (key == '8:announce') {
          final value = _readBencodedString(bytes, valueStart, valueEnd);
          final uri = value == null ? null : Uri.tryParse(value);
          return uri == null ? const [] : [uri];
        }
        offset = valueEnd;
      }
    } catch (_) {}
    return const [];
  }

  static String? _readBencodedString(Uint8List bytes, int start, int end) {
    final colon = bytes.indexOf(0x3a, start);
    if (colon <= start || colon >= end) return null;
    final length = int.tryParse(
      String.fromCharCodes(bytes.sublist(start, colon)),
    );
    if (length == null || colon + 1 + length != end) return null;
    return utf8.decode(bytes.sublist(colon + 1, end), allowMalformed: true);
  }

  /// Return the offset immediately after one bencoded value.
  static int _skipBencoded(Uint8List bytes, int offset) {
    if (offset < 0 || offset >= bytes.length) {
      throw const FormatException('truncated bencode');
    }
    final marker = bytes[offset];
    if (marker == 0x64 || marker == 0x6c) {
      var i = offset + 1;
      while (i < bytes.length && bytes[i] != 0x65) {
        i = _skipBencoded(bytes, i);
        if (marker == 0x64) i = _skipBencoded(bytes, i);
      }
      if (i >= bytes.length) {
        throw const FormatException('unterminated bencode');
      }
      return i + 1;
    }
    if (marker == 0x69) {
      final end = bytes.indexOf(0x65, offset + 1);
      if (end < 0) throw const FormatException('unterminated integer');
      return end + 1;
    }
    final colon = bytes.indexOf(0x3a, offset);
    if (colon <= offset) throw const FormatException('invalid byte string');
    final length = int.tryParse(
      String.fromCharCodes(bytes.sublist(offset, colon)),
    );
    if (length == null || length < 0 || colon + 1 + length > bytes.length) {
      throw const FormatException('invalid byte string length');
    }
    return colon + 1 + length;
  }

  /// 由已解析的种子模型生成 magnet（infohash + 自带 tracker），
  /// 用于去重，并把原种子的 tracker 传给引擎。
  static String _magnetOfModel(TorrentModel model) {
    final sb = StringBuffer('magnet:?xt=urn:btih:${model.infoHash}');
    for (final a in model.announces) {
      sb.write('&tr=${Uri.encodeComponent(a.toString())}');
    }
    return sb.toString();
  }

  /// 取出磁力的 infohash（用于去重复用已有任务）。
  static String? _infoHashOf(String magnet) {
    final hash = parseInfoHash(normalizeMagnet(magnet));
    return hash?.toLowerCase();
  }

  /// 给磁力补 tracker：合并「磁力自带 + 用户配置 + 内置公共」并去重。
  /// 搜索结果里的磁力常常没带 tracker，自己也没配置时也能找到 peer。
  String _augmentTrackers(String magnet) {
    final existing = <String>{
      ...?Uri.tryParse(magnet)?.queryParametersAll['tr'],
    };
    // MetadataDownloader starts one tracker client per URL. A long public list
    // delays DHT startup and creates many failing sockets before the first
    // useful peer arrives, so keep the magnet lightweight. The full list is
    // still applied to the actual torrent task in [_applyEndpoints].
    const maxAddedTrackers = 16;
    final merged = <String>[];
    final seen = <String>{...existing};
    void add(Iterable<String> values) {
      for (final tracker in values) {
        if (merged.length >= maxAddedTrackers) return;
        if (seen.add(tracker)) merged.add(tracker);
      }
    }

    if (trackerAutoAdd) add(trackers);
    if (Platform.isAndroid || Platform.isIOS) {
      // Android may reject cleartext tracker requests on a custom ROM, and iOS
      // ATS rejects them by default. Prefer endpoints that can work on both.
      add(kDefaultTrackers.where(_isSecureTracker));
      add(kDefaultTrackers.where((tracker) => !_isSecureTracker(tracker)));
    } else {
      add(kDefaultTrackers);
    }
    if (merged.isEmpty) return magnet;
    final sb = StringBuffer(magnet);
    for (final t in merged) {
      sb.write('&tr=${Uri.encodeComponent(t)}');
    }
    return sb.toString();
  }

  static bool _isSecureTracker(String tracker) =>
      tracker.startsWith('https://') || tracker.startsWith('wss://');

  /// 下载 magnet 元数据，返回**原始 info 字典字节**（BEP 09）。
  ///
  /// 必须保留原始字节：重新编码会改变字节（如 pieces），导致 info hash
  /// 与 magnet 不一致，tracker 拿不到 peer。
  Future<Uint8List> _fetchMetadata(String magnet, {String? jobId}) =>
      TorrentNetwork.run(() => _fetchMetadataDirect(magnet, jobId: jobId));

  Future<Uint8List> _fetchMetadataDirect(String magnet, {String? jobId}) async {
    final link = _tryParseMagnet(magnet);
    final downloader = (Platform.isAndroid || Platform.isIOS) && link != null
        ? MobileMetadataDownloader(
            link.infoHashString,
            trackers: _mobileMetadataTrackers(link.trackers)
                .where((uri) => uri.scheme == 'udp')
                .toList(),
          )
        : MetadataDownloader.fromMagnet(magnet);
    final httpClient = HttpMetadataTrackerClient(
      onLog: (message) => Log.info('元数据 HTTP tracker', message),
    );
    final completer = Completer<Uint8List>();
    // MetadataDownloader drops peers received before startDownload() has
    // finished initializing its internal peer manager. DHT responses can win
    // that race, so queue them until the downloader is ready.
    var downloaderReady = false;
    var finished = false;
    final pendingPeers = <({CompactAddress peer, PeerSource source})>[];
    final trackerRetryTimers = <Timer, Completer<void>>{};
    DhtClient? dht;

    Future<void> waitForTrackerRetry(Duration delay) {
      final waiter = Completer<void>();
      late final Timer timer;
      timer = Timer(delay, () {
        trackerRetryTimers.remove(timer);
        if (!waiter.isCompleted) waiter.complete();
      });
      trackerRetryTimers[timer] = waiter;
      return waiter.future;
    }

    void flushPendingPeers() {
      if (finished) return;
      downloaderReady = true;
      for (final item in pendingPeers) {
        try {
          downloader.addNewPeerAddress(item.peer, item.source);
        } catch (_) {}
      }
      pendingPeers.clear();
    }

    void addPeer(CompactAddress peer, PeerSource source) {
      if (finished) return;
      if (!downloaderReady) {
        // A malformed DHT response must not be able to grow this queue forever.
        if (pendingPeers.length < 1024) {
          pendingPeers.add((peer: peer, source: source));
        }
        return;
      }
      try {
        downloader.addNewPeerAddress(peer, source);
      } catch (_) {}
    }

    void addDhtPeer(InternetAddress ip, int port) =>
        addPeer(CompactAddress(ip, port), PeerSource.dht);

    // pause() 通过它提前结束等待
    final cancel = jobId == null
        ? null
        : (_fetchCancels[jobId] = Completer<void>());
    downloader.createListener()
      ..on<MetaDataDownloadComplete>((event) {
        if (completer.isCompleted) return;
        final data = Uint8List.fromList(event.data);
        // The dependency verifies this too, but checking at the boundary keeps
        // a stale/corrupt cache or a future engine regression from being saved
        // under the requested magnet's path.
        final expected = _infoHashOf(magnet);
        if (expected != null && sha1.convert(data).toString() != expected) {
          completer.completeError(
            const FormatException('metadata info hash mismatch'),
          );
          return;
        }
        completer.complete(data);
      })
      ..on<MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) completer.completeError(event.error);
      });
    // startDownload() performs tracker/DHT setup asynchronously and may fail
    // before emitting an event. Always route that error into the same Future
    // watched below; otherwise the UI waits until timeout while the real cause
    // is reported as an unhandled asynchronous exception.
    unawaited(() async {
      try {
        await downloader.startDownload();
        flushPendingPeers();
      } catch (error, stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      }
    }());

    // 内置 DHT 有解码缺陷、永远处理不了响应（trackerless 磁力因此找不到
    // peer）。这里用自己的 DHT 迭代查询，把找到的 peer 注入 downloader。
    //
    // infohash 优先用解析结果；解析失败（MagnetParser 不支持 base32、
    // v2 磁力等）时退回自己从磁力串里提取，否则这里会静默跳过 DHT，
    // trackerless 磁力就只能干等超时。
    final infoHash = _infoHashBytes(link?.infoHash, magnet);
    if (infoHash != null) {
      dht = DhtClient(
        infoHash: infoHash,
        bootstrapNodes: [...dhtNodes]
            .map(Uri.tryParse)
            .whereType<Uri>()
            .toList(),
        onPeer: addDhtPeer,
      );
      unawaited(dht.start());

      // HTTP(S) 独立于 UDP/DHT。每个 tracker 完成后立即注入，不能等最慢
      // 请求结束才开始连接；同时使用引擎的真实 20 字节 peer ID。
      if ((Platform.isAndroid || Platform.isIOS) && link != null) {
        final httpTrackers = _mobileMetadataTrackers(link.trackers)
            .where((uri) => uri.scheme == 'http' || uri.scheme == 'https');
        for (final tracker in httpTrackers) {
          unawaited(() async {
            while (!finished) {
              try {
                final options = await downloader.getOptions(
                  tracker,
                  link.infoHashString,
                );
                final peers = await httpClient.announce(
                  tracker,
                  infoHash,
                  peerId: options['peerId'] as String,
                );
                if (finished) return;
                for (final peer in peers) {
                  addPeer(peer, PeerSource.tracker);
                }
              } catch (_) {}
              await waitForTrackerRetry(_metadataRetryInterval);
              if (finished) return;
            }
          }());
        }
      }
    } else {
      Log.info('元数据', '无法解析 infohash，跳过 DHT：${_infoHashOf(magnet)}');
    }
    try {
      final Future<Uint8List> raced = cancel == null
          ? completer.future
          : Future.any<Uint8List>([
              completer.future,
              cancel.future.then(
                (_) => Future<Uint8List>.error(const TorrentFetchCancelled()),
              ),
            ]);
      return await raced;
    } on TorrentFetchCancelled {
      rethrow;
    } finally {
      finished = true;
      for (final entry in trackerRetryTimers.entries.toList()) {
        entry.key.cancel();
        if (!entry.value.isCompleted) entry.value.complete();
      }
      trackerRetryTimers.clear();
      httpClient.close();
      pendingPeers.clear();
      if (jobId != null && identical(_fetchCancels[jobId], cancel)) {
        _fetchCancels.remove(jobId);
      }
      await dht?.stop();
      try {
        await downloader.stop();
      } catch (_) {}
    }
  }

  /// `MagnetParser.parse` 可能抛异常（畸形磁力、不支持的编码）。
  MagnetLink? _tryParseMagnet(String magnet) {
    try {
      return MagnetParser.parse(magnet);
    } catch (e) {
      Log.info('磁力解析失败', '$e');
      return null;
    }
  }

  /// 取出 20 字节 infohash：优先用解析结果，否则从磁力串自行提取。
  ///
  /// 支持 40 位 hex 与 32 位 base32；v2（`urn:btmh:`）返回 null，
  /// 因为自定义 DHT 是 BEP 5（v1）实现。
  static Uint8List? _infoHashBytes(Uint8List? parsed, String magnet) {
    if (parsed != null && parsed.length == 20) return parsed;
    return infoHashBytesOf(magnet);
  }

  /// 仅从磁力串里提取 20 字节 infohash（不依赖 [MagnetParser]）。
  ///
  /// `MagnetParser.parse` 对 base32、畸形磁力会抛异常或返回空 infoHash，
  /// 此时若直接跳过 DHT，trackerless 磁力就只能干等到超时。
  static Uint8List? infoHashBytesOf(String magnet) {
    final hex = _infoHashOf(normalizeMagnet(magnet));
    if (hex == null || hex.length != 40) return null;
    final out = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }

  // ── 引擎准备 ──────────────────────────────────────────────────────────────
  Future<void> _ensureReadyForOperation() async {
    await _ensureJobsLoaded();
    if (_initialized) return;
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sync());
    _initialized = true;
    _emit();
    unawaited(_prepareRestoredJobs());
  }

  Future<void> _prepareRestoredJobs() async {
    for (final job in List<TorrentJob>.of(_jobs)) {
      await _prepareEngine(job, start: false, refetch: false);
    }
  }

  ///
  /// [refetch] 为 false（重启恢复路径）时保持持久化下来的状态，不自动重抓元数据。
  Future<void> _prepareEngine(
    TorrentJob job, {
    required bool start,
    bool refetch = true,
  }) {
    final pending = _prepareOperations[job.id];
    if (pending != null) return pending;
    final operation = TorrentNetwork.run(
      () => _prepareEngineDirect(job, start: start, refetch: refetch),
    );
    _prepareOperations[job.id] = operation;
    return operation.whenComplete(() {
      if (identical(_prepareOperations[job.id], operation)) {
        _prepareOperations.remove(job.id);
      }
    });
  }

  Future<void> _prepareEngineDirect(
    TorrentJob job, {
    required bool start,
    bool refetch = true,
  }) async {
    if (_engines.containsKey(job.id)) return;
    TorrentTask? createdTask;
    try {
      final magnet = _tryParseMagnet(job.magnet);
      final loaded = await _loadModel(job, magnet);
      if (!_jobs.contains(job)) return;
      final model = loaded == null ? null : _sanitizeModelPaths(loaded);
      if (model == null) {
        // 元数据缺失或为旧的完整 .torrent 格式（hash 不对）。
        if (!refetch) {
          // 恢复路径保留持久化状态：不重置为 metadata，也不触发重抓。
          // 上次退出时处于 metadata 的任务转为 paused，由用户决定是否重试。
          if (job.status == TorrentJobStatus.metadata) {
            job.status = TorrentJobStatus.paused;
            job.error ??= t.torrentMetadataInterrupted;
          }
          job.hasMetadata = false;
          _emit();
          return;
        }
        job.hasMetadata = false;
        job.error = null;
        job.status = TorrentJobStatus.metadata;
        if (start) _wantStart.add(job.id);
        // 必须有重试预算：抓到了但仍然解析不出来时，
        // 「抓取 → 解析失败 → 再抓取」会形成 180 秒一轮的死循环，
        // 用户看到的就是「获取元数据半天了没获取成功」。
        final attempts = _refetchAttempts[job.id] ?? 0;
        if (attempts >= _maxMetadataAttempts) {
          job.status = TorrentJobStatus.failed;
          job.error = t.torrentMetadataParseFailed;
          _refetchAttempts.remove(job.id);
          _wantStart.remove(job.id);
          Log.error('元数据', '连续 $attempts 次抓取后仍无法解析，放弃');
        } else if (_refetching.add(job.id)) {
          _refetchAttempts[job.id] = attempts + 1;
          unawaited(_refetchMetadata(job));
        }
        _emit();
        return;
      }
      // 解析成功：清空重试预算
      _refetchAttempts.remove(job.id);
      _models[job.id] = model;
      final metadataWasKnown = job.hasMetadata;
      job.hasMetadata = true;
      // 元数据重新加载成功后，清掉此前抓取失败留下的错误；否则已经
      // 完成的任务打开概览仍会显示旧的“获取元数据超时”红字。
      job.error = null;
      job.name = job.name.isEmpty ? model.name : _fixEncoding(job.name);
      // 首次拿到元数据：默认只选中最大的视频文件（不全部勾选，但「开始」有内容可下）
      if (!job.selectionInitialized) {
        job.selectedFiles = _defaultSelection(model);
        job.selectionInitialized = true;
      }
      job.totalWanted = _wantedBytes(job, model);
      if (job.totalDone > job.totalWanted) job.totalDone = job.totalWanted;

      await _migrateSingleFileLayout(job, model);
      if (!_jobs.contains(job)) return;

      // 首次拿到元数据时，即使这次准备是由用户在重启后手动触发的，
      // 也必须先暂停。只有用户再次点击开始，才清除这个待处理策略。
      final pauseAfterMetadata =
          job.stopAfter == TorrentStopPolicy.afterMetadata && !metadataWasKnown;

      // Keep the complete announce list in [_models] for the tracker tab, but
      // hand the engine a bounded list. TorrentTask starts every URL in its
      // model before [_applyEndpoints] runs, so limiting only the latter still
      // allows a large torrent to create hundreds of clients on startup.
      final engineModel = _modelForEngine(model);
      final task = TorrentTask.newTask(
        engineModel,
        _engineSavePath(job, model),
        true,
        (magnet != null && magnet.webSeeds.isNotEmpty) ? magnet.webSeeds : null,
        (magnet != null && magnet.acceptableSources.isNotEmpty)
            ? magnet.acceptableSources
            : null,
        SequentialConfig.forVideoStreaming(),
        null, // proxyConfig
        // partialSeedingEnabled：只勾选部分文件时 isAllComplete 永远为 false，
        // tracker 收不到 completed 通告、做种比例恶化。开启后改发 event=paused。
        true,
        null, // sslConfig
        null, // encryptionConfig
        null, // peerId
        TorrentManager.torrentPeerIdPrefix,
        activePeerLimit,
      );
      createdTask = task;
      _engines[job.id] = task;
      // Android 的引擎 DHT 使用 RawDatagramSocket，不能经过 BT 直连中继。
      // 移动端元数据阶段已经由直连 DHT/HTTP tracker 发现节点；清空引导
      // 节点可避免点击继续下载时等待 VPN 接管的 DHT 重试。
      if (Platform.isAndroid) task.dht?.clearBootstrapNodes();
      final shouldStart =
          start && !_pausedByUser.contains(job.id) && !pauseAfterMetadata;
      if (shouldStart) {
        await task.start();
        if (!_jobs.contains(job)) {
          try {
            await task.stop();
          } catch (_) {}
          _engines.remove(job.id);
          return;
        }
        _started.add(job.id);
        _applyEndpoints(task, job, model);
        if (_pausedByUser.contains(job.id)) {
          _pauseTransfer(job);
        }
      } else {
        // 加载状态文件，让暂停中的任务也能显示单文件进度
        await task.prepare();
        if (!_jobs.contains(job)) {
          try {
            await task.stop();
          } catch (_) {}
          _engines.remove(job.id);
          return;
        }
      }
      // 必须在 start/prepare 之后：此时 fileManager/pieceManager 才就绪，
      // 否则 setFilePriority / applySelectedFiles 会被静默忽略
      _applySelection(task, job, model);
      _refreshProgress(job, model);
      _updateTransferStatus(job, running: task.state == TaskState.running);
      if (job.isFinished && task.state == TaskState.running) {
        if (job.stopAfter == TorrentStopPolicy.afterDownload ||
            stopSeedAfterComplete ||
            _seedLimitReached(job)) {
          _pauseTransfer(job);
        } else {
          _blockCompletedDownloads(job, task, model);
        }
      }
      if (pauseAfterMetadata) _persist();
    } catch (e) {
      if (createdTask != null && identical(_engines[job.id], createdTask)) {
        _engines.remove(job.id);
        try {
          await createdTask.stop();
        } catch (_) {
          try {
            await createdTask.dispose();
          } catch (_) {}
        }
      }
      job.status = TorrentJobStatus.failed;
      job.error = e.toString();
    }
  }

  /// 引擎保存目录：单文件种子也单独建一个以种子名命名的文件夹，
  /// 多文件种子本身就会带一层种子名目录。
  String _engineSavePath(TorrentJob job, TorrentModel model) {
    final base = job.savePath.isNotEmpty ? job.savePath : downloadDir;
    return _engineSavePathForBase(base, model);
  }

  String _engineSavePathForBase(String base, TorrentModel model) {
    if (model.isSingleFile) {
      return p.join(base, _sanitizeName(model.name));
    }
    return base;
  }

  /// 把一个已加载的任务迁移到新的种子目录。文件由引擎自身移动，
  /// 这样改名文件的映射会写入 state 文件；随后复制 state 文件并重建
  /// 引擎，重启后仍能找到同一批分片，旧目录也保留回滚副本。
  Future<bool> _migrateTorrentJob(TorrentJob job, String targetBase) async {
    final task = _engines[job.id];
    final model = _models[job.id];
    if (task == null || model == null || task.fileManager == null) {
      // 没有可用引擎时保留原 savePath，避免把磁盘上的任务目录改成孤儿。
      return false;
    }

    final oldBase = job.savePath.isNotEmpty ? job.savePath : downloadDir;
    final oldRoot = _engineSavePathForBase(oldBase, model);
    final newRoot = _engineSavePathForBase(targetBase, model);
    if (p.equals(oldRoot, newRoot)) {
      job.savePath = targetBase;
      return true;
    }

    final files = [
      for (final file in task.fileManager!.files)
        (torrentPath: file.torrentFilePath, localPath: file.filePath),
    ];
    final moves = <({String torrentPath, String source, String target})>[];
    for (final file in files) {
      // 曾经被用户移到任务目录外的文件继续留在原位置，state 文件中的
      // 绝对路径映射会随任务一起迁移，无需强行拉回新目录。
      if (!p.isWithin(oldRoot, file.localPath)) continue;
      final relative = p.relative(file.localPath, from: oldRoot);
      final target = p.join(newRoot, relative);
      if (p.equals(file.localPath, target)) continue;
      final targetFile = File(target);
      if (await targetFile.exists() && await File(file.localPath).exists()) {
        throw FileSystemException('目标文件已存在', target);
      }
      moves.add((
        torrentPath: file.torrentPath,
        source: file.localPath,
        target: target,
      ));
    }

    await stopStreams(job);
    final wasRunning = task.state == TaskState.running;
    if (wasRunning) task.pause();
    final completedMoves =
        <({String torrentPath, String source, String target})>[];
    try {
      for (final move in moves) {
        final moved = await task.moveDownloadedFile(
          move.torrentPath,
          move.target,
          validateAfterMove: false,
        );
        if (!moved) throw FileSystemException('文件移动失败', move.source);
        completedMoves.add(move);
      }

      await task.stop();
      _engines.remove(job.id);
      _started.remove(job.id);

      await _copyTorrentStateFiles(model.infoHash, oldRoot, newRoot);
      final oldPath = job.savePath;
      job.savePath = targetBase;
      await _prepareEngine(job, start: wasRunning, refetch: false);
      if (_engines[job.id] == null) {
        job.savePath = oldPath;
        return false;
      }
      return true;
    } catch (_) {
      // 如果还没 stop，尽量把已经移动的文件放回去；失败时保留旧任务
      // 路径和 state 文件，至少不会把任务从列表中隐藏。
      if (_engines[job.id] == task && completedMoves.isNotEmpty) {
        for (final move in completedMoves.reversed) {
          try {
            await task.moveDownloadedFile(
              move.torrentPath,
              move.source,
              validateAfterMove: false,
            );
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  Future<void> _copyTorrentStateFiles(
    String infoHash,
    String oldRoot,
    String newRoot,
  ) async {
    if (p.equals(oldRoot, newRoot) || infoHash.isEmpty) return;
    await Directory(newRoot).create(recursive: true);
    for (final suffix in ['$infoHash.bt.state', '$infoHash.bt.paths.json']) {
      final source = File(p.join(oldRoot, suffix));
      if (!await source.exists()) continue;
      final target = File(p.join(newRoot, suffix));
      // 保留旧目录的状态副本：如果新引擎重建失败，旧 savePath 仍能
      // 通过其中的绝对路径映射恢复，避免设置变更造成任务丢失。
      await source.copy(target.path);
    }
  }

  String _sanitizeName(String name) {
    // 复用下载模块的净化规则（控制字符、Windows 保留名、尾点、长度上限），
    // 避免在 Windows 上因为种子名是 CON / 带控制字符而创建失败。
    final cleaned = DownloadManager.sanitizeFileName(name, fallback: 'torrent');
    // 种子名会作为目录的一层，必须保证不含路径分隔符与 `.`/`..`
    return cleaned.replaceAll(RegExp(r'[\\/]'), '_');
  }

  /// 净化种子内每个文件的相对路径，防目录穿越。
  ///
  /// 引擎用字符串拼接构造落盘路径（`directory + torrentPath`），
  /// 完全不校验 `..`。恶意种子可以用 `files: [{path: ["..","..","x.sh"]}]`
  /// 把文件写到下载目录之外。这里在交给引擎之前就把危险段消掉。
  static String _sanitizeTorrentFilePath(String path) {
    final cleaned = DownloadManager.sanitizeGroupName(
      path.replaceAll('\\', '/'),
    );
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  static String _sanitizeTorrentFileSegment(String segment) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw const FormatException('torrent file tree contains an unsafe path');
    }
    if (segment.contains('/') || segment.contains('\\')) {
      throw const FormatException(
        'torrent file tree contains a path separator',
      );
    }
    return DownloadManager.sanitizeFileName(segment, fallback: 'file');
  }

  static bool _sameStringList(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static List<String>? _sanitizeSymlinkPath(List<String>? target) {
    if (target == null) return null;
    final result = <String>[];
    for (final segment in target) {
      if (segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          segment.contains('/') ||
          segment.contains('\\') ||
          segment.contains(':')) {
        throw const FormatException(
          'torrent contains an unsafe symlink target',
        );
      }
      result.add(DownloadManager.sanitizeFileName(segment, fallback: 'link'));
    }
    return result.isEmpty ? null : result;
  }

  static ({Map<String, FileTreeEntry> tree, bool changed}) _sanitizeFileTree(
    Map<String, FileTreeEntry> tree,
  ) {
    final result = <String, FileTreeEntry>{};
    var changed = false;
    for (final entry in tree.entries) {
      final key = _sanitizeTorrentFileSegment(entry.key);
      if (result.containsKey(key)) {
        throw const FormatException(
          'torrent file tree contains duplicate paths after sanitization',
        );
      }
      if (key != entry.key) changed = true;

      final value = entry.value;
      final children = value.children;
      if (children != null) {
        final nested = _sanitizeFileTree(children);
        changed = changed || nested.changed;
        result[key] = FileTreeEntry.directory(nested.tree);
        continue;
      }

      final symlinkPath = _sanitizeSymlinkPath(value.symlinkPath);
      if (!_sameStringList(symlinkPath, value.symlinkPath)) {
        changed = true;
      }
      result[key] = FileTreeEntry(
        length: value.length,
        piecesRoot: value.piecesRoot,
        attributes: value.attributes,
        symlinkPath: symlinkPath,
      );
    }
    return (tree: result, changed: changed);
  }

  TorrentModel _modelForEngine(TorrentModel model) {
    final announces = limitActiveTrackerUris(model.announces);
    if (announces.length == model.announces.length &&
        announces.every((uri) => model.announces.contains(uri))) {
      return model;
    }
    return TorrentModel(
      name: model.name,
      files: model.files,
      infoHashBuffer: model.infoHashBuffer,
      pieceLength: model.pieceLength,
      pieces: model.pieces,
      announces: announces,
      nodes: model.nodes,
      length: model.length,
      version: model.version,
      metaVersion: model.metaVersion,
      fileTree: model.fileTree,
      pieceLayers: model.pieceLayers,
      rootHash: model.rootHash,
      infoDictBytes: model.infoDictBytes,
      rawData: model.rawData,
    );
  }

  /// 逐个净化种子内的文件路径，返回新模型（不修改原模型）。
  TorrentModel _sanitizeModelPaths(TorrentModel model) {
    var changed = false;
    final files = <TorrentFileModel>[];
    final seenPaths = <String>{};
    for (final f in model.files) {
      final safe = _sanitizeTorrentFilePath(f.path);
      final key = Platform.isWindows ? safe.toLowerCase() : safe;
      if (!seenPaths.add(key)) {
        throw const FormatException(
          'torrent contains duplicate paths after sanitization',
        );
      }
      if (safe == f.path) {
        files.add(f);
      } else {
        changed = true;
        files.add(
          TorrentFileModel(
            path: safe,
            length: f.length,
            offset: f.offset,
            attributes: f.attributes,
            symlinkPath: _sanitizeSymlinkPath(f.symlinkPath),
            isPaddingFile: f.isPaddingFile,
          ),
        );
      }
    }
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final symlinkPath = _sanitizeSymlinkPath(file.symlinkPath);
      if (!_sameStringList(symlinkPath, file.symlinkPath)) {
        changed = true;
        files[i] = TorrentFileModel(
          path: file.path,
          length: file.length,
          offset: file.offset,
          attributes: file.attributes,
          symlinkPath: symlinkPath,
          isPaddingFile: file.isPaddingFile,
        );
      }
    }
    final treeResult = model.fileTree == null
        ? null
        : _sanitizeFileTree(model.fileTree!);
    changed = changed || (treeResult?.changed ?? false);
    if (!changed) return model;

    final safeName = _sanitizeName(model.name);
    Log.info('种子路径净化', '${model.name} → $safeName（${files.length} 个文件）');
    return TorrentModel(
      name: safeName,
      files: files,
      infoHashBuffer: model.infoHashBuffer,
      pieceLength: model.pieceLength,
      pieces: model.pieces,
      announces: model.announces,
      nodes: model.nodes,
      length: model.length,
      version: model.version,
      metaVersion: model.metaVersion,
      fileTree: treeResult?.tree ?? model.fileTree,
      pieceLayers: model.pieceLayers,
      rootHash: model.rootHash,
      infoDictBytes: model.infoDictBytes,
      rawData: model.rawData,
    );
  }

  /// 兼容旧布局：单文件曾直接放在下载根目录，现在放进同名文件夹。
  /// 若根目录已存在同名文件/状态文件，迁移到新文件夹中，避免
  /// 「创建目录时发现同名文件」导致的 PathExistsException。
  Future<void> _migrateSingleFileLayout(
    TorrentJob job,
    TorrentModel model,
  ) async {
    if (!model.isSingleFile) return;
    final base = job.savePath.isNotEmpty ? job.savePath : downloadDir;
    final mediaName = model.files.first.name;
    final folder = p.join(base, _sanitizeName(model.name));
    final folderDir = Directory(folder);

    if (!await folderDir.exists()) {
      final flat = File(p.join(base, mediaName));
      final atFolder = File(folder);
      File? media;
      if (await atFolder.exists()) {
        media = atFolder;
      } else if (await flat.exists()) {
        media = flat;
      }
      if (media != null) {
        final tmp = '$folder.__migrating__';
        try {
          await media.rename(tmp);
        } catch (_) {}
        await folderDir.create(recursive: true);
        final tmpFile = File(tmp);
        final dest = p.join(folder, mediaName);
        if (await tmpFile.exists() && !await File(dest).exists()) {
          try {
            await tmpFile.rename(dest);
          } catch (_) {}
        }
      } else {
        await folderDir.create(recursive: true);
      }
    }

    // 迁移旧的 resume 状态文件
    final hash = model.infoHash;
    if (hash.isEmpty) return;
    for (final suffix in ['$hash.bt.state', '$hash.bt.paths.json']) {
      final old = File(p.join(base, suffix));
      if (!await old.exists()) continue;
      final dest = File(p.join(folder, suffix));
      if (await dest.exists()) continue;
      try {
        await old.rename(dest.path);
      } catch (_) {}
    }
  }

  /// 读取持久化的 **原始 info 字典字节** 构建模型。
  /// 旧版本存的是完整 `.torrent`（info 被重新编码，hash 不对），
  /// 解析会失败 → 返回 null，由调用方重新抓取（重抓会覆盖旧文件）。
  Future<TorrentModel?> _loadModel(TorrentJob job, MagnetLink? magnet) async {
    // 旧任务可能没有 torrentPath：按稳定目录自愈，保证离线也能用
    var path = job.torrentPath;
    if (path.isEmpty) {
      path = p.join(_torrentDir!.path, '${job.id}.torrent');
    }
    final f = File(path);
    if (!await f.exists()) return null;
    if (job.torrentPath != path) job.torrentPath = path;
    final bytes = await f.readAsBytes();
    try {
      final model = TorrentParser.parseFromInfoBytes(
        bytes,
        announces: magnet?.trackers ?? const [],
      );
      final expected = _infoHashOf(job.magnet);
      if (expected != null && model.infoHash.toLowerCase() != expected) {
        Log.error(
          '元数据校验失败',
          '任务 ${job.id} 期望 $expected，文件实际为 ${model.infoHash}',
        );
        return null;
      }
      return _fixModelEncoding(model);
    } catch (_) {
      return null;
    }
  }

  /// 库用 `String.fromCharCodes` 按 Latin-1 解码 torrent 名称/文件路径，
  /// UTF-8（或 GBK）中文会变乱码。这里拿回原始字节按 UTF-8 → GBK 回退重解。
  String _fixEncoding(String s) {
    if (s.isEmpty) return s;
    var allAscii = true;
    for (final c in s.codeUnits) {
      if (c > 0xff) return s; // 已是正常 Unicode，无需处理
      if (c > 0x7f) allAscii = false;
    }
    if (allAscii) return s;
    final bytes = latin1.encode(s);
    try {
      return utf8.decode(bytes);
    } catch (_) {}
    try {
      return gbk.decode(bytes);
    } catch (_) {}
    return s;
  }

  TorrentModel _fixModelEncoding(TorrentModel m) {
    try {
      return TorrentModel(
        name: _fixEncoding(m.name),
        files: [
          for (final f in m.files)
            TorrentFileModel(
              path: _fixEncoding(f.path),
              length: f.length,
              offset: f.offset,
              attributes: f.attributes,
              symlinkPath: f.symlinkPath?.map(_fixEncoding).toList(),
              isPaddingFile: f.isPaddingFile,
            ),
        ],
        infoHashBuffer: m.infoHashBuffer,
        pieceLength: m.pieceLength,
        pieces: m.pieces,
        announces: m.announces,
        nodes: m.nodes,
        length: m.length,
        version: m.version,
        metaVersion: m.metaVersion,
        fileTree: m.fileTree,
        pieceLayers: m.pieceLayers,
        rootHash: m.rootHash,
        infoDictBytes: m.infoDictBytes,
        rawData: m.rawData,
      );
    } catch (_) {
      // 修正编码失败就用原模型，绝不因此丢弃元数据
      return m;
    }
  }

  Future<void> _refetchMetadata(TorrentJob job) async {
    try {
      final bytes = await _fetchMetadata(job.magnet, jobId: job.id);
      if (!_jobs.contains(job)) return;
      final file = File(job.torrentPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      if (!_jobs.contains(job)) return;
      final start = _wantStart.remove(job.id);
      await _prepareEngine(job, start: start);
    } on TorrentFetchCancelled {
      job.status = TorrentJobStatus.paused;
      _wantStart.remove(job.id);
      Log.info('元数据', '抓取已被取消：${job.id}');
    } on TorrentMetadataTimeout catch (error) {
      job.status = TorrentJobStatus.failed;
      job.error = error.vpnActive
          ? t.torrentVpnMetadataTimeout
          : t.torrentMetadataTimeout;
      _wantStart.remove(job.id);
      Log.info('元数据', '抓取超时：${job.magnet}');
    } catch (e, s) {
      job.status = TorrentJobStatus.failed;
      job.error = e.toString();
      _wantStart.remove(job.id);
      Log.error('元数据抓取失败', '$e\n$s');
    } finally {
      _refetching.remove(job.id);
    }
    _persist();
    _emit();
  }

  /// 应用用户选择的文件：未选中的设为 skip。
  void _applySelection(TorrentTask task, TorrentJob job, TorrentModel model) {
    final selected = job.selectedFiles;
    final none = _isNoneSelected(selected);
    final sel = none ? const <int>{} : selected.toSet();
    final priorities = <int, FilePriority>{};
    for (var i = 0; i < model.files.length; i++) {
      try {
        final saved = job.filePriorities[i];
        final priority = saved == null
            ? (selected.isEmpty || sel.contains(i)
                  ? FilePriority.normal
                  : FilePriority.skip)
            : FilePriority.values[saved.clamp(0, 3)];
        priorities[i] = priority;
      } catch (_) {}
    }
    if (priorities.isNotEmpty) task.setFilePriorities(priorities);
    if (!none && selected.isNotEmpty) task.applySelectedFiles(selected);
  }

  static bool _isNoneSelected(List<int> sel) =>
      sel.length == 1 && sel.first == kTorrentNoFile;

  /// 应用 Tracker / DHT 节点 / 限速 到任务。
  void _applyEndpoints(TorrentTask task, TorrentJob job, TorrentModel model) {
    final trackersForTask = limitActiveTrackerUris(
      _parseTrackers(trackersOf(job)),
    );
    for (final tr in trackersForTask) {
      try {
        task.startAnnounceUrl(tr, model.v1InfoHash ?? model.truncatedInfoHash);
      } catch (_) {}
    }
    if (!Platform.isAndroid) {
      for (final n in _parseTrackers(dhtNodes)) {
        try {
          task.addDHTNode(n);
        } catch (_) {}
      }
    }
    _applyLimits(task);
  }

  /// 任务可用的 announce 地址（去重、保序）：模型 announce → 磁力 `tr`
  /// → 用户 tracker → 内置公共。UI 保留完整列表；引擎通过
  /// [limitActiveTrackerUris] 限制实际同时运行的 tracker 数量。
  List<String> trackersOf(TorrentJob job) {
    final model = _models[job.id];
    final out = <String>[];
    final seen = <String>{};
    void addAll(Iterable<String> values) {
      for (final v in values) {
        final s = v.trim();
        if (s.isEmpty || !s.contains('://')) continue;
        if (seen.add(s)) out.add(s);
      }
    }

    if (model != null) addAll(model.announces.map((e) => e.toString()));
    if (job.magnet.isNotEmpty) {
      addAll(Uri.tryParse(job.magnet)?.queryParametersAll['tr'] ?? const []);
    }
    if (trackerAutoAdd) addAll(trackers);
    addAll(kDefaultTrackers);
    return out;
  }

  /// 实际使用的 DHT 引导节点：内置 + 用户自定义。
  List<String> get dhtNodes => [...kDefaultDhtNodes, ...customNodes];

  int _wantedBytes(TorrentJob job, TorrentModel model) {
    if (job.selectedFiles.isEmpty) return model.totalSize;
    if (_isNoneSelected(job.selectedFiles)) return 0;
    var sum = 0;
    for (final i in job.selectedFiles) {
      if (i >= 0 && i < model.files.length) sum += model.files[i].length;
    }
    return sum;
  }

  /// 汇总「已选文件」中已下载的字节数。
  ///
  /// 引擎的 `downloaded` / `progress` 都是整包口径（`downloaded / totalSize`），
  /// 但未选中的文件会被 `setSkippedPieces` 跳过、永远下不满。拿整包口径判断完成，
  /// 会让「只勾了部分文件」的任务卡在 downloading 永不完成，做种与
  /// 「下载完停止」策略都不触发；tracker 也收不到 completed 通告
  /// （引擎内部同样以 isAllComplete 为准），做种比例直接归零。
  ///
  /// 纯函数，便于单测覆盖关键场景。
  /// [selectedFiles] 为空表示全部选中；含 [kTorrentNoFile] 表示全不选。
  static int selectedDoneBytes(
    List<TorrentFileEntry> files,
    List<int> selectedFiles,
  ) {
    if (_isNoneSelected(selectedFiles)) return 0;
    if (selectedFiles.isEmpty) {
      var sum = 0;
      for (final f in files) {
        sum += f.downloaded;
      }
      return sum;
    }
    final selected = selectedFiles.toSet();
    var sum = 0;
    for (final f in files) {
      if (selected.contains(f.index)) sum += f.downloaded;
    }
    return sum;
  }

  /// 从引擎的文件状态直接计算已选字节，避免同步轮询时反复创建 UI 文件模型。
  int _selectedDoneBytesFromEngine(TorrentJob job) {
    final engineFiles = _engines[job.id]?.fileManager?.files;
    if (engineFiles == null) {
      return selectedDoneBytes(filesOf(job), job.selectedFiles);
    }
    if (_isNoneSelected(job.selectedFiles)) return 0;
    if (job.selectedFiles.isEmpty) {
      var sum = 0;
      for (final file in engineFiles) {
        sum += file.downloadedBytes;
      }
      return sum;
    }
    final selected = job.selectedFiles.toSet();
    var sum = 0;
    for (var index = 0; index < engineFiles.length; index++) {
      if (selected.contains(index)) sum += engineFiles[index].downloadedBytes;
    }
    return sum;
  }

  /// 按「已选文件」重算 [TorrentJob.totalDone] / [totalWanted] / [progress]。
  ///
  /// 三者口径保持一致（都是已选文件），UI 上的 `progress * totalWanted`
  /// 才等于真实已下载字节数（原因见 [selectedDoneBytes]）。
  void _refreshProgress(TorrentJob job, TorrentModel model) {
    final wanted = _wantedBytes(job, model);
    job.totalWanted = wanted;

    if (wanted <= 0) {
      // 「全不选」：没有要下的内容，进度恒为 0，不要退回整包大小
      job.totalDone = 0;
      job.progress = 0;
      return;
    }

    final done = _selectedDoneBytesFromEngine(job);
    job.totalDone = done;
    job.progress = (done / wanted).clamp(0.0, 1.0).toDouble();
  }

  /// 默认选择：最大的可播放视频；没有视频则最大文件；再不行「全不选」。
  List<int> _defaultSelection(TorrentModel model) {
    var videoIndex = -1;
    var videoSize = 0;
    var anyIndex = -1;
    var anySize = 0;
    for (var i = 0; i < model.files.length; i++) {
      final f = model.files[i];
      if (f.isPaddingFile) continue;
      if (f.length > anySize) {
        anySize = f.length;
        anyIndex = i;
      }
      if (_isStreamableName(f.name) && f.length > videoSize) {
        videoSize = f.length;
        videoIndex = i;
      }
    }
    final index = videoIndex >= 0 ? videoIndex : anyIndex;
    return index >= 0 ? [index] : const [kTorrentNoFile];
  }

  // ── 操作 ──────────────────────────────────────────────────────────────────
  void _updateTransferStatus(TorrentJob job, {required bool running}) {
    final completed = job.hasCompletedDownload;
    job.status = completed
        ? TorrentJobStatus.completed
        : running
        ? TorrentJobStatus.downloading
        : TorrentJobStatus.paused;
    job.seedingPaused = completed && !running;
    if (completed) {
      job.progress = 1;
      job.error = null;
    }
    if (!running) {
      job.downloadRate = 0;
      job.uploadRate = 0;
    }
  }

  void _pauseTransfer(TorrentJob job) {
    final completed = job.isFinished || job.hasCompletedDownload;
    final engine = _engines[job.id];
    if (engine != null && engine.state == TaskState.running) engine.pause();
    try {
      engine?.stopScheduling();
    } catch (_) {}
    _uploadSamples.remove(job.id);
    _updateTransferStatus(job, running: false);
    if (completed) {
      job.status = TorrentJobStatus.completed;
      job.seedingPaused = true;
      job.progress = 1;
      job.error = null;
    }
  }

  void pause(TorrentJob job) {
    _pausedByUser.add(job.id);
    // 中止进行中的元数据抓取，避免其在超时后覆盖 pause 设置的状态
    _cancelFetch(job);
    final model = _models[job.id];
    if (_engines[job.id]?.fileManager != null && model != null) {
      _refreshProgress(job, model);
    }
    _pauseTransfer(job);
    _persist();
    _emit();
  }

  /// 中止该任务正在进行的元数据抓取。
  void _cancelFetch(TorrentJob job) {
    final cancel = _fetchCancels.remove(job.id);
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _refetching.remove(job.id);
    _refetchAttempts.remove(job.id);
    _wantStart.remove(job.id);
  }

  /// 恢复任务；[isRetry] 为 true 时（用户手动点重试）重置元数据重试预算。
  Future<void> resume(TorrentJob job, {bool isRetry = false}) {
    _pausedByUser.remove(job.id);
    job.seedingPaused = false;
    final pending = _resumeOperations[job.id];
    if (pending != null) return pending;
    if (job.hasMetadata && job.status == TorrentJobStatus.paused) {
      // 先反馈用户操作，再等待引擎恢复文件状态和网络连接。
      _updateTransferStatus(job, running: true);
      _emit();
    }
    final operation = TorrentNetwork.run(
      () => _resumeDirect(job, isRetry: isRetry),
    );
    _resumeOperations[job.id] = operation;
    return operation.whenComplete(() {
      if (identical(_resumeOperations[job.id], operation)) {
        _resumeOperations.remove(job.id);
      }
    });
  }

  Future<void> _resumeDirect(TorrentJob job, {bool isRetry = false}) async {
    await _ensureReadyForOperation();
    // 任务首次取得元数据后会按策略暂停；这次 resume 是用户明确的继续
    // 操作，因此清除待处理标记，避免下一次恢复再次拦截启动。
    if (job.hasMetadata && job.stopAfter == TorrentStopPolicy.afterMetadata) {
      job.stopAfter = TorrentStopPolicy.none;
      _persist();
    }
    if ((job.hasCompletedDownload &&
            (stopSeedAfterComplete ||
                job.stopAfter == TorrentStopPolicy.afterDownload)) ||
        _seedLimitReached(job)) {
      _pauseTransfer(job);
      _persist();
      _emit();
      return;
    }
    // 库的 start() 非幂等（server socket 已被监听会抛 "Stream was already
    // listened to"），并发 resume 也会重复 start，这里串行化并容错。
    if (!_starting.add(job.id)) return;
    try {
      if (isRetry) {
        _refetchAttempts.remove(job.id);
        job.error = null;
        if (job.status == TorrentJobStatus.failed) {
          job.status = TorrentJobStatus.metadata;
        }
      }
      var engine = _engines[job.id];
      if (engine == null) {
        await _prepareEngine(job, start: true);
        engine = _engines[job.id];
      }
      if (engine == null) {
        // 恢复流程可能刚以 refetch=false 检查过旧任务。若用户此时点了
        // 开始，第二次准备必须允许触发元数据抓取，不能把空引擎当成启动异常。
        if (!job.hasMetadata) {
          await _prepareEngine(job, start: true, refetch: true);
          engine = _engines[job.id];
        }
      }
      if (engine == null) {
        // 元数据抓取已经在后台运行，等待完成后会由 _refetchMetadata 创建引擎。
        // 失败状态也由任务卡片展示具体原因，不再弹出误导性的引擎未就绪。
        if (job.isFetchingMeta || job.status == TorrentJobStatus.failed) {
          _persist();
          _emit();
          return;
        }
        throw StateError('torrent engine is not ready');
      }
      if (_pausedByUser.contains(job.id)) {
        _pauseTransfer(job);
        _persist();
        _emit();
        return;
      }
      final model = _models[job.id];
      if (model != null) {
        _refreshProgress(job, model);
        if (job.hasCompletedDownload) {
          _blockCompletedDownloads(job, engine, model);
        }
      }
      if (engine.state == TaskState.paused &&
          engine.fileManager != null &&
          engine.peersManager != null) {
        engine.resume();
        _applyLimits(engine);
        _updateTransferStatus(job, running: true);
      } else if (engine.state != TaskState.running) {
        // stopped：首次启动或 stop() 之后；start() 非幂等，容错重复启动
        try {
          await engine.start();
        } catch (error, stack) {
          // TorrentTask 会在异步初始化前先把 state 设为 running。只检查
          // state 会吞掉真正的启动异常，导致用户反复点击却没有任何动作。
          Log.error('恢复种子失败', '$error\n$stack');
          try {
            await engine.stop();
          } catch (_) {
            try {
              await engine.dispose();
            } catch (_) {}
          }
          _engines.remove(job.id);
          await _prepareEngine(job, start: true);
          if (_engines[job.id] == null) rethrow;
          _sync();
          _persist();
          _emit();
          return;
        }
        if (_pausedByUser.contains(job.id)) {
          _pauseTransfer(job);
          _persist();
          _emit();
          return;
        }
        _started.add(job.id);
        final model = _models[job.id];
        if (model != null) _applyEndpoints(engine, job, model);
        _updateTransferStatus(job, running: true);
      }
      _sync();
      _persist();
      _emit();
    } finally {
      _starting.remove(job.id);
    }
  }

  Future<void> remove(TorrentJob job, {bool deleteFiles = true}) async {
    // 删除时必须取消元数据抓取。否则抓取完成后会重新给已删除的 job
    // 创建引擎，留下后台 socket/定时器和不可见的下载任务。
    _cancelFetch(job);
    final server = _servers.remove(job.id);
    if (server != null) await server.stop();
    final engine = _engines[job.id];
    final model =
        _models[job.id] ??
        engine?.metaInfo ??
        (deleteFiles
            ? await _loadModel(job, _tryParseMagnet(job.magnet))
            : null);
    // 引擎停止后会清空 fileManager，必须先保存真实路径（包括改名文件）。
    final filePaths = <String>{
      ...?engine?.fileManager?.files.map((file) => file.filePath),
    };
    final base = job.savePath.isNotEmpty ? job.savePath : downloadDir;
    final roots = <String>{
      base,
      if (model != null) _engineSavePath(job, model),
    };
    final statePaths = <String>{};
    if (deleteFiles && model != null) {
      final movedPaths = <String, String>{};
      for (final root in roots) {
        final pathsFile = File(p.join(root, '${model.infoHash}.bt.paths.json'));
        statePaths.addAll([
          pathsFile.path,
          p.join(root, '${model.infoHash}.bt.state'),
        ]);
        if (!await pathsFile.exists()) continue;
        try {
          final decoded = jsonDecode(await pathsFile.readAsString());
          if (decoded is! Map<String, dynamic>) continue;
          for (final entry in decoded.entries) {
            if (entry.value is String) movedPaths[entry.key] = entry.value;
          }
        } on FormatException catch (error) {
          Log.warning('种子路径记录损坏', '$error');
        }
      }
      if (engine?.fileManager == null) {
        final root = _engineSavePath(job, model);
        for (final file in model.files) {
          filePaths.add(movedPaths[file.path] ?? p.join(root, file.path));
        }
      }
    }
    _started.remove(job.id);
    _starting.remove(job.id);
    _pausedByUser.remove(job.id);
    _wantStart.remove(job.id);
    _refetching.remove(job.id);
    _refetchAttempts.remove(job.id);
    if (engine != null) {
      try {
        // stop() 已包含 dispose()，成功时不能再调一次
        await engine.stop();
      } catch (e) {
        Log.error('停止种子任务失败', '$e');
        try {
          await engine.dispose();
        } catch (_) {}
      }
    }
    _engines.remove(job.id);
    if (deleteFiles) {
      try {
        // DownloadFile.delete() 只删除内部缓存的 _file，恢复任务未读写过
        // 的文件没有这个缓存。先停止写入、关闭句柄，再按真实路径删除。
        for (final path in filePaths) {
          await _deleteTorrentFile(path);
        }
        await _pruneTorrentDirectories(base, {...filePaths, ...statePaths});
        for (final path in statePaths) {
          await _deleteTorrentFile(path);
        }
        await _pruneTorrentDirectories(base, statePaths);
      } catch (error, stack) {
        // 文件清理失败时保留任务和元数据，让用户能够重试删除。
        job.status = TorrentJobStatus.paused;
        job.downloadRate = 0;
        job.uploadRate = 0;
        _persist();
        _emit();
        Log.error('删除种子文件失败', '$error\n$stack');
        rethrow;
      }
    }
    try {
      final f = File(job.torrentPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _models.remove(job.id);
    _jobs.remove(job);
    _persist();
    _emit();
  }

  Future<void> _deleteTorrentFile(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.link) {
      await Link(path).delete();
    } else if (type != FileSystemEntityType.notFound) {
      throw FileSystemException('Expected torrent file', path);
    }
  }

  Future<void> _pruneTorrentDirectories(
    String base,
    Set<String> deletedPaths,
  ) async {
    final boundary = p.normalize(p.absolute(base));
    for (final path in deletedPaths) {
      var parent = p.normalize(p.dirname(p.absolute(path)));
      // 只删除任务文件上方的空目录；公共下载目录和其他文件始终保留。
      while (p.isWithin(boundary, parent)) {
        final directory = Directory(parent);
        if (await FileSystemEntity.type(parent, followLinks: false) !=
            FileSystemEntityType.directory) {
          break;
        }
        if (!await directory.list().isEmpty) break;
        await directory.delete();
        parent = p.dirname(parent);
      }
    }
  }

  void setSelectedFiles(TorrentJob job, List<int> indices) {
    _downloadBlockedAfterCompletion.remove(job.id);
    job.selectedFiles = List<int>.from(indices);
    job.selectionInitialized = true;
    final engine = _engines[job.id];
    final model = _models[job.id];
    if (engine != null && model != null) {
      _applySelection(engine, job, model);
      _refreshProgress(job, model);
      _updateTransferStatus(job, running: engine.state == TaskState.running);
    }
    if (model != null) job.totalWanted = _wantedBytes(job, model);
    _persist();
    _emit();
  }

  /// 删除选中的内容文件，并使对应 pieces 重新进入可下载状态。
  /// 删除后文件默认标记为 skip，避免用户只是清理磁盘却立刻被重新下载。
  Future<void> deleteFiles(TorrentJob job, Iterable<int> indices) async {
    if (!_fileMutations.add(job.id)) {
      throw StateError('torrent file operation already in progress');
    }
    var wasRunning = false;
    TorrentTask? task;
    try {
      task = _engines[job.id];
      final model = _models[job.id];
      final fileManager = task?.fileManager;
      if (task == null || model == null || fileManager == null) {
        throw StateError('torrent files are not ready');
      }
      final valid = indices
          .where((index) => index >= 0 && index < fileManager.files.length)
          .toSet();
      if (valid.isEmpty) return;

      await stopStreams(job);
      wasRunning = task.state == TaskState.running;
      if (wasRunning) task.pause();
      final pieces = <int>{
        for (final index in valid)
          for (final piece in fileManager.files[index].pieces) piece.index,
      };
      final deletedPaths = <String>{};
      for (final index in valid) {
        final path = fileManager.files[index].filePath;
        deletedPaths.add(path);
        await fileManager.files[index].delete();
        // DownloadFile.delete() only knows about its lazily opened handle.
        // A restored task may have no handle even though the file is present.
        await _deleteTorrentFile(path);
        if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          throw FileSystemException('torrent file was not deleted', path);
        }
      }
      await _pruneTorrentDirectories(job.savePath, deletedPaths);
      for (final pieceIndex in pieces) {
        final piece = task.pieceManager?[pieceIndex];
        if (piece == null) continue;
        // A flushed piece keeps its completion markers and _flushed flag even
        // after individual sub-pieces are returned. Reset the whole piece so
        // a deleted file is reported as empty and can be downloaded again.
        piece.reset();
        await fileManager.updateBitfield(pieceIndex, false);
      }

      for (final file in fileManager.files) {
        file.recalculateDownloadedBytes();
      }
      for (final index in valid) {
        job.filePriorities[index] = FilePriority.skip.index;
      }

      final all = {for (var i = 0; i < model.files.length; i++) i};
      final selected = job.selectedFiles.isEmpty
          ? all
          : _isNoneSelected(job.selectedFiles)
          ? <int>{}
          : job.selectedFiles.toSet();
      selected.removeAll(valid);
      job.selectedFiles = selected.length == all.length
          ? <int>[]
          : selected.isEmpty
          ? <int>[kTorrentNoFile]
          : (selected.toList()..sort());
      job.selectionInitialized = true;
      job.totalWanted = _wantedBytes(job, model);
      _downloadBlockedAfterCompletion.remove(job.id);
      _applySelection(task, job, model);
      _refreshProgress(job, model);
      if (_isNoneSelected(job.selectedFiles)) {
        job.status = TorrentJobStatus.paused;
        job.downloadRate = 0;
        job.uploadRate = 0;
      } else if (wasRunning) {
        task.resume();
      }
      _updateTransferStatus(job, running: task.state == TaskState.running);
      _persist();
      _emit();
    } catch (_) {
      if (wasRunning && !_pausedByUser.contains(job.id)) {
        try {
          task?.resume();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _fileMutations.remove(job.id);
    }
  }

  /// 设置选中文件的优先级，并同步任务选择状态与状态文件。
  void setFilePriority(
    TorrentJob job,
    Iterable<int> indices,
    FilePriority priority,
  ) {
    final model = _models[job.id];
    final engine = _engines[job.id];
    final valid = indices
        .where(
          (index) =>
              model == null || (index >= 0 && index < model.files.length),
        )
        .toSet();
    if (valid.isEmpty) return;
    if (priority != FilePriority.skip) {
      _downloadBlockedAfterCompletion.remove(job.id);
    }
    for (final index in valid) {
      job.filePriorities[index] = priority.index;
    }
    if (engine != null) {
      try {
        engine.setFilePriorities({for (final index in valid) index: priority});
      } catch (_) {}
    }
    if (model != null) {
      final all = {for (var i = 0; i < model.files.length; i++) i};
      final selected = job.selectedFiles.isEmpty
          ? all
          : _isNoneSelected(job.selectedFiles)
          ? <int>{}
          : job.selectedFiles.toSet();
      if (priority == FilePriority.skip) {
        selected.removeAll(valid);
      } else {
        selected.addAll(valid);
      }
      job.selectedFiles = selected.length == all.length
          ? <int>[]
          : selected.isEmpty
          ? <int>[kTorrentNoFile]
          : (selected.toList()..sort());
      job.selectionInitialized = true;
      job.totalWanted = _wantedBytes(job, model);
    }
    _persist();
    _emit();
  }

  /// 播放某文件前确保它被选中（默认「全不选」时自动勾上该文件）。
  void _ensureFileSelected(TorrentJob job, int index) {
    final sel = job.selectedFiles;
    if (sel.isEmpty) return; // 全部
    if (sel.contains(index)) return;
    // 点击播放代表用户明确要下载该文件；清除此前的「不下载」优先级，
    // 否则 setSelectedFiles 后引擎仍会把它标记为 skip，播放器拿不到数据。
    job.filePriorities.remove(index);
    final next = _isNoneSelected(sel)
        ? <int>[index]
        : (<int>[...sel, index]..sort());
    setSelectedFiles(job, next);
  }

  // ── 文件列表 ──────────────────────────────────────────────────────────────
  List<TorrentFileEntry> filesOf(TorrentJob job) {
    final engine = _engines[job.id];
    final fm = engine?.fileManager;
    if (fm != null && fm.files.isNotEmpty) {
      return [
        for (var i = 0; i < fm.files.length; i++)
          TorrentFileEntry(
            index: i,
            name: _lastSegment(fm.files[i].filePath),
            path: fm.files[i].torrentFilePath,
            size: fm.files[i].length,
            downloaded: fm.files[i].downloadedBytes,
            isStreamable: _isStreamableName(fm.files[i].torrentFilePath),
            localPath: fm.files[i].filePath,
          ),
      ];
    }
    final model = _models[job.id];
    if (model != null) {
      return [
        for (var i = 0; i < model.files.length; i++)
          TorrentFileEntry(
            index: i,
            name: model.files[i].name,
            path: model.files[i].path,
            size: model.files[i].length,
            downloaded: 0,
            isStreamable: _isStreamableName(model.files[i].name),
          ),
      ];
    }
    return const [];
  }

  static String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final i = normalized.lastIndexOf('/');
    return i < 0 ? normalized : normalized.substring(i + 1);
  }

  static bool isValidFileName(String name) {
    if (name.trim().isEmpty || name == '.' || name == '..') return false;
    if (name.endsWith('.') || name.endsWith(' ')) return false;
    if (RegExp(r'[\x00-\x1f<>:"/\\|?*]').hasMatch(name)) return false;
    return !RegExp(
      r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
      caseSensitive: false,
    ).hasMatch(name);
  }

  /// 只修改磁盘路径，保留种子内路径、info hash 和分片/文件下标。
  Future<void> renameFile(TorrentJob job, int index, String name) async {
    if (!isValidFileName(name)) throw ArgumentError.value(name);
    final task = _engines[job.id];
    final files = task?.fileManager?.files;
    if (task == null || files == null || index < 0 || index >= files.length) {
      throw StateError('torrent file not ready');
    }
    final file = files[index];
    final destination = p.join(p.dirname(file.filePath), name);
    if (p.equals(destination, file.filePath)) return;
    if (files.any((f) => p.equals(f.filePath, destination)) ||
        await FileSystemEntity.type(destination) !=
            FileSystemEntityType.notFound) {
      throw const FileSystemException('destination already exists');
    }
    await stopStreams(job);
    final moved = await task.moveDownloadedFile(
      file.torrentFilePath,
      destination,
      validateAfterMove: false,
    );
    if (!moved) throw const FileSystemException('file move failed');
    _emit();
  }

  TorrentTask? engineOf(TorrentJob job) => _engines[job.id];
  TorrentModel? modelOf(TorrentJob job) => _models[job.id];

  bool isSeeding(TorrentJob job) =>
      job.isFinished &&
      !job.seedingPaused &&
      _engines[job.id]?.state == TaskState.running;

  List<String> httpSourcesOf(TorrentJob job) {
    final magnet = _tryParseMagnet(job.magnet);
    return {
      ...?magnet?.webSeeds.map((uri) => uri.toString()),
      ...?magnet?.acceptableSources.map((uri) => uri.toString()),
    }.toList();
  }

  // ── 播放 ──────────────────────────────────────────────────────────────────
  bool isStreaming(TorrentJob job) => _servers[job.id]?.running ?? false;

  /// 开始/复用本地串流服务，返回某文件的播放 URL。
  Future<String> streamUrl(TorrentJob job, int fileIndex) async {
    _ensureFileSelected(job, fileIndex);
    if (job.status == TorrentJobStatus.completed) {
      await _ensureReadyForOperation();
      await _prepareEngine(job, start: false, refetch: false);
    } else {
      await resume(job);
    }
    // 等引擎的 fileManager 就绪
    for (var i = 0; i < 50 && _engines[job.id]?.fileManager == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final engine = _engines[job.id];
    if (engine == null || engine.fileManager == null) {
      throw StateError('torrent engine not ready');
    }
    final entries = filesOf(job);
    if (fileIndex < 0 || fileIndex >= entries.length) {
      throw StateError('invalid file index');
    }
    // 已完整落盘的文件不需要再经过本地 HTTP Range 服务。直接返回真实
    // 磁盘路径可以绕过旧播放地址、重命名后的路径匹配和播放器的 HEAD 探测。
    final localFile = engine.fileManager!.files[fileIndex];
    final piecesComplete =
        localFile.pieces.isNotEmpty &&
        localFile.pieces.every((piece) => piece.isCompletelyWritten);
    final fileContentComplete = localFile.isRangeWritten(0, localFile.length);
    final local = File(localFile.filePath);
    if ((job.status == TorrentJobStatus.completed ||
            localFile.completed ||
            piecesComplete ||
            fileContentComplete) &&
        await local.exists() &&
        await local.length() >= localFile.length) {
      return localFile.filePath;
    }
    var server = _servers[job.id];
    if (server == null || !server.running) {
      final model = _models[job.id];
      server = TorrentStreamServer(
        engine,
        onIdle: model == null
            ? null
            : () {
                try {
                  // 播放窗口结束后恢复用户设置的文件优先级；否则串流窗口
                  // 的临时 priority 集合会一直覆盖“正常/高/最高”选择。
                  if (_downloadBlockedAfterCompletion.contains(job.id)) {
                    engine.setFilePriorities({
                      for (var i = 0; i < model.files.length; i++)
                        i: FilePriority.skip,
                    });
                  } else {
                    _applySelection(engine, job, model);
                  }
                } catch (_) {}
              },
      );
      await server.start();
      _servers[job.id] = server;
    }
    return server.urlFor(entries[fileIndex]).toString();
  }

  /// 串流打开失败时，为已完成文件提供磁盘路径回退。
  Future<String?> localPlaybackPath(TorrentJob job, int fileIndex) async {
    final files = _engines[job.id]?.fileManager?.files;
    if (files == null || fileIndex < 0 || fileIndex >= files.length) {
      return null;
    }
    final file = files[fileIndex];
    final local = File(file.filePath);
    final contentComplete =
        job.status == TorrentJobStatus.completed ||
        file.completed ||
        file.isRangeWritten(0, file.length);
    if (!contentComplete || file.length <= 0 || !await local.exists()) {
      return null;
    }
    if (await local.length() < file.length) return null;
    return file.filePath;
  }

  Future<void> stopStreams(TorrentJob job) async {
    final server = _servers.remove(job.id);
    if (server != null) await server.stop();
    _emit();
  }

  // ── 轮询同步 ──────────────────────────────────────────────────────────────
  String _syncSignature() {
    final b = StringBuffer();
    for (final job in _jobs) {
      b
        ..write(job.id)
        ..write('|')
        ..write(job.status.name)
        ..write('|')
        ..write(job.downloadRate)
        ..write('|')
        ..write(job.uploadRate)
        ..write('|')
        ..write(job.uploadedBytes)
        ..write('|')
        ..write(job.seedingStartedAt)
        ..write('|')
        ..write(job.seedingPaused)
        ..write('|')
        ..write(job.numPeers)
        ..write('|')
        ..write(job.numSeeds)
        ..write('|')
        ..write((job.progress * 1000).round())
        ..write('|')
        ..write(job.totalDone)
        ..write(';');
    }
    return b.toString();
  }

  void _sync() {
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null) continue;
      // start/prepare 尚未结束时引擎暂时为 stopped，不能把仍在启动的任务
      // 改成 paused，否则会让保活通知停止后立即重启。
      if (_starting.contains(job.id) ||
          _prepareOperations.containsKey(job.id) ||
          job.status == TorrentJobStatus.metadata) {
        continue;
      }
      final model = _models[job.id];
      if (_downloadBlockedAfterCompletion.contains(job.id)) {
        _clearBlockedPeerSuggestions(engine);
      }
      void refreshProgress() {
        if (model != null) _refreshProgress(job, model);
      }

      // 暂停是用户的明确操作。即使某个恢复回调或引擎内部状态晚到，
      // 轮询也不能把任务重新标记为下载中。
      if ((_pausedByUser.contains(job.id) ||
              (job.isFinished && job.seedingPaused)) &&
          engine.state == TaskState.running) {
        try {
          engine.pause();
        } catch (_) {}
        refreshProgress();
        _pauseTransfer(job);
        continue;
      }

      // 以引擎实际状态为准：_started 是内存态，可能与引擎不同步，
      // 之前用它判定会把已恢复的任务每秒强制打回「已暂停」
      if (engine.state == TaskState.stopped) {
        job.downloadRate = 0;
        job.uploadRate = 0;
        job.numPeers = 0;
        job.numSeeds = 0;
        job.numDownloaders = 0;
        // prepare() 后 fileManager 可用：读回状态，保证外层与内容进度一致
        if (engine.fileManager != null) {
          refreshProgress();
        }
        if (job.status != TorrentJobStatus.failed) {
          _updateTransferStatus(job, running: false);
        }
        continue;
      }
      final now = DateTime.now();
      final previousUploadSample = _uploadSamples[job.id];
      if (previousUploadSample != null) {
        final elapsed = now.difference(previousUploadSample).inMilliseconds;
        if (elapsed > 0 && elapsed <= 10000) {
          job.uploadedBytes += (engine.uploadSpeed * 1024 * elapsed / 1000)
              .round();
        }
      }
      _uploadSamples[job.id] = now;
      // dtorrent_task_v2 reports both values in KiB/s; the shared formatter
      // and persisted job fields use bytes/s.
      job.downloadRate = (engine.currentDownloadSpeed * 1024).round();
      job.uploadRate = (engine.uploadSpeed * 1024).round();
      job.numPeers = engine.connectedPeersNumber;
      job.numSeeds = engine.seederNumber;
      job.numDownloaders = engine.trackerDownloaders ?? 0;
      refreshProgress();
      _updateTransferStatus(job, running: engine.state == TaskState.running);
      if (job.isFinished && engine.state == TaskState.running) {
        job.seedingStartedAt ??= now.millisecondsSinceEpoch;
        // 完成后的做种/停止策略
        if (job.stopAfter == TorrentStopPolicy.afterDownload ||
            stopSeedAfterComplete ||
            _seedLimitReached(job)) {
          _pauseTransfer(job);
        }
      }
      if (job.progress < 1.0 || job.status != TorrentJobStatus.completed) {
        _downloadBlockedAfterCompletion.remove(job.id);
      } else if (engine.state == TaskState.running) {
        _blockCompletedDownloads(job, engine, model);
      }
      if (engine.state == TaskState.running) {
        _trimActivePeers(job, engine, now);
      }
    }
    _syncKeepAlive();
    final sig = _syncSignature();
    if (sig != _lastSyncSig) {
      _lastSyncSig = sig;
      _emit();
    }
    if (++_persistTick >= 5) {
      _persistTick = 0;
      _persist();
    }
  }

  void _blockCompletedDownloads(
    TorrentJob job,
    TorrentTask engine,
    TorrentModel? model,
  ) {
    if (model == null || !_downloadBlockedAfterCompletion.add(job.id)) return;
    try {
      engine.setFilePriorities({
        for (var index = 0; index < model.files.length; index++)
          index: FilePriority.skip,
      });
      _clearBlockedPeerSuggestions(engine);
    } catch (_) {
      _downloadBlockedAfterCompletion.remove(job.id);
    }
  }

  void _clearBlockedPeerSuggestions(TorrentTask engine) {
    for (final peer in engine.activePeers ?? const <Peer>[]) {
      if (!peer.isDisposed) peer.remoteSuggestPieces.clear();
    }
  }

  void _trimActivePeers(TorrentJob job, TorrentTask engine, DateTime now) {
    final peers = engine.activePeers
        ?.where((peer) => !peer.isDisposed)
        .toList();
    if (peers == null || peers.isEmpty) return;

    final scored = <({Peer peer, double score, String key})>[];
    final liveKeys = <String>{};
    for (final peer in peers) {
      final key = '${job.id}:${peer.id}';
      liveKeys.add(key);
      final previous = _peerUploadSamples[key];
      final uploaded = peer.uploaded;
      var uploadRate = 0.0;
      if (previous != null) {
        final elapsed = now.difference(previous.at).inMilliseconds;
        final delta = uploaded - previous.uploaded;
        if (elapsed > 0 && delta > 0) {
          uploadRate = delta * 1000 / elapsed / 1024;
        }
      }
      _peerUploadSamples[key] = (at: now, uploaded: uploaded);
      scored.add((
        peer: peer,
        score: peerTransferScore(
          downloadRate: peer.currentDownloadSpeed,
          uploadRate: uploadRate,
        ),
        key: key,
      ));
    }

    _peerUploadSamples.removeWhere(
      (key, _) => key.startsWith('${job.id}:') && !liveKeys.contains(key),
    );
    _peerTrimPending.removeWhere(
      (key) => key.startsWith('${job.id}:') && !liveKeys.contains(key),
    );

    final overflow = scored.length - activePeerLimit;
    if (overflow <= 0) return;
    scored.sort((a, b) {
      final byActivity = a.score.compareTo(b.score);
      if (byActivity != 0) return byActivity;
      return a.key.compareTo(b.key);
    });
    for (final candidate in scored.take(overflow)) {
      if (!_peerTrimPending.add(candidate.key)) continue;
      unawaited(
        (engine.peersManager?.disconnectPeer(
                  candidate.peer,
                  BadException('peer connection limit'),
                ) ??
                Future<void>.value())
            .catchError((_) {}),
      );
    }
  }

  /// 把正在传输 / 做种的种子登记到 Android 前台服务。
  ///
  /// 之前只有普通下载会登记，种子在后台做种时没有任何保活，
  /// Android 会直接杀掉进程，做种完全无效。
  /// 仅文件下载和实际做种时保活；抓取元数据不发布下载通知。
  static bool needsKeepAlive(TorrentJob job, TaskState? engineState) =>
      job.hasMetadata &&
      !job.seedingPaused &&
      engineState == TaskState.running &&
      (job.status == TorrentJobStatus.downloading ||
          job.status == TorrentJobStatus.completed);

  void _syncKeepAlive({bool force = false}) {
    if (!Platform.isAndroid || !_initialized) return;
    final active = _jobs
        .where((j) => needsKeepAlive(j, _engines[j.id]?.state))
        .toList();
    if (active.isEmpty) {
      _lastKeepAlive = null;
      unawaited(DownloadKeepAlive.detach(DownloadKeepAlive.ownerTorrent));
      return;
    }
    final now = DateTime.now();
    if (!force &&
        _lastKeepAlive != null &&
        now.difference(_lastKeepAlive!).inSeconds < 1) {
      return;
    }
    _lastKeepAlive = now;
    unawaited(
      DownloadKeepAlive.attach(
        DownloadKeepAlive.ownerTorrent,
        [
          for (final j in active)
            (
              title: j.name.isEmpty ? j.id : j.name,
              progress: j.progress.clamp(0.0, 1.0).toDouble(),
            ),
        ],
        remaining: _jobs
            .where(
              (j) => j.hasMetadata && j.status != TorrentJobStatus.completed,
            )
            .length,
      ),
    );
  }
}

/// 全局种子管理器（Riverpod）：`ref.watch(torrentManagerProvider)` 取状态，
/// `ref.read(torrentManagerProvider.notifier)` 执行操作。
final torrentManagerProvider = NotifierProvider<TorrentManager, TorrentState>(
  TorrentManager.new,
);
