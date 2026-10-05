import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart' show gbk;
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/database/download_database.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/download/download_keep_alive.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/torrent/dht_client.dart';
import 'package:kostori/services/torrent/indexer/bt_indexer.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_stream_server.dart';
import 'package:path/path.dart' as p;

// 设置 key
const String kTorrentTrackers = 'torrentTrackers';
const String kTorrentTrackerAutoAdd = 'torrentTrackerAutoAdd';
const String kTorrentTrackerUrl = 'torrentTrackerUrl';
const String kTorrentDownloadLimit = 'torrentDownloadLimit';
const String kTorrentUploadLimit = 'torrentUploadLimit';
const String kTorrentStopSeed = 'torrentStopSeed';
const String kTorrentCustomNodes = 'torrentCustomNodes';

/// `selectedFiles` 哨兵：表示「一个文件都不选」。空列表仍表示「全部」（兼容旧数据）。
const int kTorrentNoFile = -1;

/// 元数据抓取超时（[TorrentManager._metadataTimeout]）。
///
/// 引擎在找不到 peer 时不会自己失败，只能由上层超时兜底，
/// 单独定义异常类型是为了把它和真正的解析/网络错误区分开，
/// 避免把 `TimeoutException after 0:03:00.000000: Future not completed`
/// 这种原始文本暴露到界面。
class TorrentMetadataTimeout implements Exception {
  const TorrentMetadataTimeout();

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
///（BEP 5），引导节点需自行维护：`router.bitcomet.com` / `dht.bitcomet.com`
/// 已 NXDOMAIN，`router.silotis.us` 仅剩 AAAA 记录，均已移除。
const List<String> kDefaultDhtNodes = [
  'udp://dht.transmissionbt.com:6881',
  'udp://router.bittorrent.com:6881',
  'udp://dht.libtorrent.org:25401',
  'udp://dht.aelitis.com:6881',
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

/// 种子任务管理器（基于纯 Dart 的 dtorrent_task_v2，Riverpod Notifier）。
///
/// 引擎实例只在需要时创建/启动；重启后只加载已持久化的 `.torrent`，
/// 不会自动下载，等用户手动开始。
class TorrentManager extends Notifier<TorrentState> {
  @override
  TorrentState build() {
    ref.onDispose(_disposeInternal);
    Future.microtask(init);
    return const TorrentState([]);
  }

  List<TorrentJob> get jobs => state.jobs;

  /// 兼容旧 UI 命名。
  List<TorrentJob> get tasks => jobs;

  void _emit() => state = TorrentState(List.unmodifiable(_jobs));

  bool _initialized = false;

  final List<TorrentJob> _jobs = [];

  final Map<String, TorrentTask> _engines = {};
  final Map<String, TorrentModel> _models = {};
  final Map<String, TorrentStreamServer> _servers = {};
  final Set<String> _started = {};
  final Set<String> _starting = {};
  final Set<String> _refetching = {};
  final Set<String> _wantStart = {};

  /// 每个任务已自动重试抓取元数据的次数，防止「抓到但解析不出来」时无限循环。
  final Map<String, int> _refetchAttempts = {};

  /// 正在进行的元数据抓取与其取消信号，用户按「暂停」时立刻中止网络动作。
  final Map<String, Completer<void>> _fetchCancels = {};

  /// 元数据抓取超时。
  ///
  /// 引擎在「一个 peer 都找不到」时既不成功也不失败（只在 hash 不匹配时抛
  /// `MetaDataDownloadFailed`），只能靠这里兜底。原来的 180 秒太长，
  /// 用户体感就是「卡住半天」；有 peer 时通常 1~10 秒就能拿到。
  static const Duration _metadataTimeout = Duration(seconds: 45);

  /// 自动重试抓取元数据的次数上限，超过即判定为不可用。
  static const int _maxMetadataAttempts = 3;

  /// 对外暴露的元数据抓取超时（秒），便于测试与设置项读取。
  static int get metadataTimeoutSeconds => _metadataTimeout.inSeconds;

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

  /// 与普通下载相同的目录
  static String get downloadDir {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return p.join(App.dataPath, 'downloads');
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
      for (final tr in _parseTrackers(
        _readList(appdata.implicitData, kTorrentTrackers).split('\n'),
      )) {
        try {
          engine.startAnnounceUrl(tr, model.infoHashBuffer);
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
    final client = HttpClient()
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
    appdata.implicitData[kTorrentStopSeed] = v;
    appdata.writeImplicitData();
    _emit();
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
    _initialized = true;
    _torrentDir = Directory(p.join(App.dataPath, 'torrent_meta'));
    if (!await _torrentDir!.exists()) {
      await _torrentDir!.create(recursive: true);
    }
    await _loadJobs();
    for (final job in _jobs) {
      // refetch: false —— 仅恢复本地状态；元数据抓取是网络动作，
      // 进程重启后不自动重试。
      await _prepareEngine(job, start: false, refetch: false);
    }
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) => _sync());
    _emit();
  }

  void _disposeInternal() {
    _syncTimer?.cancel();
    _syncTimer = null;
    for (final server in _servers.values) {
      unawaited(server.stop());
    }
    _servers.clear();
    for (final engine in _engines.values) {
      try {
        unawaited(engine.dispose());
      } catch (_) {}
    }
    _engines.clear();
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
    await init();
    // 支持直接粘裸 infohash（BT 客户端「复制 info hash」得到的即是此格式）
    final normalized = normalizeMagnet(magnet);
    // 已有同种任务：直接复用。有元数据就直接返回（免重新抓取，离线可用），
    // 没有则确保后台抓取，由调用方轮询 filesOf。
    final ih = _infoHashOf(normalized);
    if (ih != null) {
      for (final j in _jobs) {
        if (_infoHashOf(j.magnet) != ih) continue;
        // 元数据已就绪：直接复用（离线可用）
        if (_models.containsKey(j.id)) return j;
        // 否则确保后台抓取，由调用方轮询 filesOf
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
      savePath: downloadDir,
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
      await File(job.torrentPath).writeAsBytes(bytes, flush: true);
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
    await init();
    final TorrentModel model;
    try {
      model = TorrentParser.parseBytes(bytes);
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
      savePath: downloadDir,
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
    final merged = <String>{
      if (trackerAutoAdd) ...trackers,
      ...kDefaultTrackers,
    }..removeWhere(existing.contains);
    if (merged.isEmpty) return magnet;
    final sb = StringBuffer(magnet);
    for (final t in merged) {
      sb.write('&tr=${Uri.encodeComponent(t)}');
    }
    return sb.toString();
  }

  /// 下载 magnet 元数据，返回**原始 info 字典字节**（BEP 09）。
  ///
  /// 必须保留原始字节：重新编码会改变字节（如 pieces），导致 info hash
  /// 与 magnet 不一致，tracker 拿不到 peer。
  Future<Uint8List> _fetchMetadata(String magnet, {String? jobId}) async {
    final link = _tryParseMagnet(magnet);
    final downloader = MetadataDownloader.fromMagnet(magnet);
    final completer = Completer<Uint8List>();
    // pause() 通过它提前结束等待
    final cancel = jobId == null
        ? null
        : (_fetchCancels[jobId] = Completer<void>());
    downloader.createListener()
      ..on<MetaDataDownloadComplete>((event) {
        if (!completer.isCompleted) {
          completer.complete(Uint8List.fromList(event.data));
        }
      })
      ..on<MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) completer.completeError(event.error);
      });
    unawaited(downloader.startDownload());

    // 内置 DHT 有解码缺陷、永远处理不了响应（trackerless 磁力因此找不到
    // peer）。这里用自己的 DHT 迭代查询，把找到的 peer 注入 downloader。
    //
    // infohash 优先用解析结果；解析失败（MagnetParser 不支持 base32、
    // v2 磁力等）时退回自己从磁力串里提取，否则这里会静默跳过 DHT，
    // trackerless 磁力就只能干等超时。
    final infoHash = _infoHashBytes(link?.infoHash, magnet);
    DhtClient? dht;
    if (infoHash != null) {
      dht = DhtClient(
        infoHash: infoHash,
        bootstrapNodes: [...dhtNodes]
            .map(Uri.tryParse)
            .whereType<Uri>()
            .toList(),
        onPeer: (ip, port) {
          try {
            downloader.addNewPeerAddress(
              CompactAddress(ip, port),
              PeerSource.dht,
            );
          } catch (_) {}
        },
        onLog: (m) => Log.info('DHT', m),
      );
      unawaited(dht.start());
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
      return await raced.timeout(_metadataTimeout);
    } on TorrentFetchCancelled {
      rethrow;
    } on TimeoutException {
      // 引擎在「找不到 peer」时不会发 MetaDataDownloadFailed，
      // 只能靠这里的超时兜底。给出可读原因，别把原始异常文本抛给 UI。
      throw const TorrentMetadataTimeout();
    } finally {
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
  ///
  /// [refetch] 为 false（重启恢复路径）时保持持久化下来的状态，不自动重抓元数据。
  Future<void> _prepareEngine(
    TorrentJob job, {
    required bool start,
    bool refetch = true,
  }) async {
    if (_engines.containsKey(job.id)) return;
    try {
      final magnet = _tryParseMagnet(job.magnet);
      final loaded = await _loadModel(job, magnet);
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
      job.hasMetadata = true;
      job.name = job.name.isEmpty ? model.name : _fixEncoding(job.name);
      // 首次拿到元数据：默认只选中最大的视频文件（不全部勾选，但「开始」有内容可下）
      if (!job.selectionInitialized) {
        job.selectedFiles = _defaultSelection(model);
        job.selectionInitialized = true;
      }
      job.totalWanted = _wantedBytes(job, model);
      if (job.totalDone > job.totalWanted) job.totalDone = job.totalWanted;

      await _migrateSingleFileLayout(job, model);

      final task = TorrentTask.newTask(
        model,
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
      );
      _engines[job.id] = task;
      if (start) {
        await task.start();
        _started.add(job.id);
        _applyEndpoints(task, job, model);
        job.status = TorrentJobStatus.downloading;
      } else {
        // 加载状态文件，让暂停中的任务也能显示单文件进度
        await task.prepare();
        job.status = TorrentJobStatus.paused;
      }
      // 必须在 start/prepare 之后：此时 fileManager/pieceManager 才就绪，
      // 否则 setFilePriority / applySelectedFiles 会被静默忽略
      _applySelection(task, job, model);
    } catch (e) {
      job.status = TorrentJobStatus.failed;
      job.error = e.toString();
    }
  }

  /// 引擎保存目录：单文件种子也单独建一个以种子名命名的文件夹，
  /// 多文件种子本身就会带一层种子名目录。
  String _engineSavePath(TorrentJob job, TorrentModel model) {
    final base = job.savePath.isNotEmpty ? job.savePath : downloadDir;
    if (model.isSingleFile) {
      return p.join(base, _sanitizeName(model.name));
    }
    return base;
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

  /// 逐个净化种子内的文件路径，返回新模型（不修改原模型）。
  TorrentModel _sanitizeModelPaths(TorrentModel model) {
    var changed = false;
    final files = <TorrentFileModel>[];
    for (final f in model.files) {
      final safe = _sanitizeTorrentFilePath(f.path);
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
            symlinkPath: f.symlinkPath,
            isPaddingFile: f.isPaddingFile,
          ),
        );
      }
    }
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
      fileTree: model.fileTree,
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
      await File(job.torrentPath).writeAsBytes(bytes, flush: true);
      final start = _wantStart.remove(job.id);
      await _prepareEngine(job, start: start);
    } on TorrentFetchCancelled {
      job.status = TorrentJobStatus.paused;
      _wantStart.remove(job.id);
      Log.info('元数据', '抓取已被取消：${job.id}');
    } on TorrentMetadataTimeout {
      job.status = TorrentJobStatus.failed;
      job.error = t.torrentMetadataTimeout;
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
    if (selected.isEmpty) return; // 空 = 全部
    final none = _isNoneSelected(selected);
    final sel = none ? const <int>{} : selected.toSet();
    for (var i = 0; i < model.files.length; i++) {
      try {
        task.setFilePriority(
          i,
          sel.contains(i) ? FilePriority.normal : FilePriority.skip,
        );
      } catch (_) {}
    }
    if (!none) task.applySelectedFiles(selected);
  }

  static bool _isNoneSelected(List<int> sel) =>
      sel.length == 1 && sel.first == kTorrentNoFile;

  /// 应用 Tracker / DHT 节点 / 限速 到任务。
  void _applyEndpoints(TorrentTask task, TorrentJob job, TorrentModel model) {
    for (final tr in _parseTrackers(trackersOf(job))) {
      try {
        task.startAnnounceUrl(tr, model.infoHashBuffer);
      } catch (_) {}
    }
    for (final n in _parseTrackers(dhtNodes)) {
      try {
        task.addDHTNode(n);
      } catch (_) {}
    }
    _applyLimits(task);
  }

  /// 任务实际会 announce 的地址（去重、保序）：模型 announce → 磁力 `tr`
  /// → 用户 tracker → 内置公共。UI 与 [_applyEndpoints] 共用该集合，
  /// 保证展示与实际 announce 一致。
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

    final done = selectedDoneBytes(filesOf(job), job.selectedFiles);
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
  void pause(TorrentJob job) {
    // 中止进行中的元数据抓取，避免其在超时后覆盖 pause 设置的状态
    _cancelFetch(job);
    final engine = _engines[job.id];
    if (engine != null && engine.state == TaskState.running) {
      engine.pause();
    }
    job.downloadRate = 0;
    job.uploadRate = 0;
    job.status = TorrentJobStatus.paused;
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
  Future<void> resume(TorrentJob job, {bool isRetry = false}) async {
    if (job.status == TorrentJobStatus.completed) return;
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
      final engine = _engines[job.id];
      if (engine == null) {
        await _prepareEngine(job, start: true);
      } else if (engine.state == TaskState.paused) {
        engine.resume();
        job.status = TorrentJobStatus.downloading;
      } else if (engine.state != TaskState.running) {
        // stopped：首次启动或 stop() 之后；start() 非幂等，容错重复启动
        try {
          await engine.start();
        } catch (e) {
          if (engine.state != TaskState.running) rethrow;
        }
        _started.add(job.id);
        final model = _models[job.id];
        if (model != null) _applyEndpoints(engine, job, model);
        job.status = TorrentJobStatus.downloading;
      }
      _sync();
      _persist();
      _emit();
    } finally {
      _starting.remove(job.id);
    }
  }

  Future<void> remove(TorrentJob job, {bool deleteFiles = true}) async {
    final server = _servers.remove(job.id);
    if (server != null) await server.stop();
    final engine = _engines.remove(job.id);
    _models.remove(job.id);
    _started.remove(job.id);
    _starting.remove(job.id);
    _wantStart.remove(job.id);
    _refetching.remove(job.id);
    _refetchAttempts.remove(job.id);
    if (engine != null) {
      // 顺序很关键：引擎的 stop() 内部会 dispose()，把 _fileManager 置为 null，
      // 之后再调 fileManager?.delete() 就是空操作，文件永远删不掉。
      if (deleteFiles) {
        try {
          await engine.fileManager?.delete();
        } catch (e) {
          Log.error('删除种子文件失败', '$e');
        }
      }
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
    try {
      final f = File(job.torrentPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _jobs.remove(job);
    _persist();
    _emit();
  }

  void setSelectedFiles(TorrentJob job, List<int> indices) {
    job.selectedFiles = List<int>.from(indices);
    job.selectionInitialized = true;
    final engine = _engines[job.id];
    final model = _models[job.id];
    if (engine != null && model != null) {
      _applySelection(engine, job, model);
    }
    if (model != null) job.totalWanted = _wantedBytes(job, model);
    _persist();
    _emit();
  }

  /// 播放某文件前确保它被选中（默认「全不选」时自动勾上该文件）。
  void _ensureFileSelected(TorrentJob job, int index) {
    final sel = job.selectedFiles;
    if (sel.isEmpty) return; // 全部
    if (sel.contains(index)) return;
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
            name: _lastSegment(fm.files[i].torrentFilePath),
            path: fm.files[i].torrentFilePath,
            size: fm.files[i].length,
            downloaded: fm.files[i].downloadedBytes,
            isStreamable: _isStreamableName(fm.files[i].torrentFilePath),
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

  // ── 播放 ──────────────────────────────────────────────────────────────────
  bool isStreaming(TorrentJob job) => _servers[job.id]?.running ?? false;

  /// 开始/复用本地串流服务，返回某文件的播放 URL。
  Future<String> streamUrl(TorrentJob job, int fileIndex) async {
    _ensureFileSelected(job, fileIndex);
    await resume(job);
    // 等引擎的 fileManager 就绪
    for (var i = 0; i < 50 && _engines[job.id]?.fileManager == null; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final engine = _engines[job.id];
    if (engine == null || engine.fileManager == null) {
      throw StateError('torrent engine not ready');
    }
    var server = _servers[job.id];
    if (server == null || !server.running) {
      server = TorrentStreamServer(engine);
      await server.start();
      _servers[job.id] = server;
    }
    final entries = filesOf(job);
    if (fileIndex < 0 || fileIndex >= entries.length) {
      throw StateError('invalid file index');
    }
    return server.urlFor(entries[fileIndex]).toString();
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
      final noneSelected = _isNoneSelected(job.selectedFiles);
      final model = _models[job.id];
      void refreshProgress() {
        if (model != null) _refreshProgress(job, model);
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
        if (!noneSelected && job.progress >= 0.999) {
          job.status = TorrentJobStatus.completed;
        } else if (job.status != TorrentJobStatus.completed &&
            job.status != TorrentJobStatus.failed) {
          job.status = TorrentJobStatus.paused;
        }
        continue;
      }
      job.downloadRate = engine.currentDownloadSpeed.round();
      job.uploadRate = engine.uploadSpeed.round();
      job.numPeers = engine.connectedPeersNumber;
      job.numSeeds = engine.seederNumber;
      job.numDownloaders = engine.trackerDownloaders ?? 0;
      refreshProgress();
      if (engine.state == TaskState.paused) {
        job.status = TorrentJobStatus.paused;
      } else if (!noneSelected && job.progress >= 0.999) {
        job.status = TorrentJobStatus.completed;
        // 完成后的做种/停止策略
        if (job.stopAfter == TorrentStopPolicy.afterDownload ||
            stopSeedAfterComplete) {
          try {
            engine.pause();
          } catch (_) {}
          job.status = TorrentJobStatus.paused;
        }
      } else {
        job.status = TorrentJobStatus.downloading;
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

  /// 把正在传输 / 做种的种子登记到 Android 前台服务。
  ///
  /// 之前只有普通下载会登记，种子在后台做种时没有任何保活，
  /// Android 会直接杀掉进程，做种完全无效。
  /// 完成 / 暂停 / 失败的任务不计入（不再传输就不需要保活）。
  void _syncKeepAlive({bool force = false}) {
    if (!Platform.isAndroid) return;
    final active = _jobs
        .where(
          (j) =>
              j.status == TorrentJobStatus.downloading ||
              j.status == TorrentJobStatus.completed,
        )
        .toList();
    if (active.isEmpty) {
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
            .where((j) => j.status != TorrentJobStatus.completed)
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
