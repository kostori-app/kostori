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
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/services/torrent/dht_client.dart';
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

/// 内置公共 DHT 引导节点。库自带只有 3 个且只查询一轮，trackerless 磁力
/// 常常因此找不到 peer；这里补入社区常用节点，配合周期重查扩大覆盖。
const List<String> kDefaultDhtNodes = [
  'udp://router.bittorrent.com:6881',
  'udp://router.utorrent.com:6881',
  'udp://dht.transmissionbt.com:6881',
  'udp://dht.libtorrent.org:25401',
  'udp://dht.aelitis.com:6881',
  'udp://router.silotis.us:6881',
  'udp://router.bitcomet.com:6881',
  'udp://dht.bitcomet.com:6881',
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

  Directory? _torrentDir;
  int _persistTick = 0;
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
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(const SystemEncoding().decoder).join();
      client.close(force: true);
      final list =
          body
              .split(RegExp(r'\s+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty && s.contains('://'))
              .toSet()
              .toList()
            ..sort();
      if (list.isNotEmpty) setTrackers(list);
    } catch (_) {}
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

  List<String> get customNodes => _readList(
    appdata.implicitData,
    kTorrentCustomNodes,
  ).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  void setCustomNodes(List<String> list) {
    appdata.implicitData[kTorrentCustomNodes] = list
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    appdata.writeImplicitData();
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null) continue;
      for (final n in _parseTrackers(list)) {
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
      await _prepareEngine(job, start: false);
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
    // 已有同种任务：直接复用。有元数据就直接返回（免重新抓取，离线可用），
    // 没有则确保后台抓取，由调用方轮询 filesOf。
    final ih = _infoHashOf(magnet);
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
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final effectiveMagnet = _augmentTrackers(magnet);
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
      final bytes = await _fetchMetadata(effectiveMagnet);
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
    final id = '${DateTime.now().millisecondsSinceEpoch}';
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
    final m = RegExp(
      r'urn:btih:([^&]+)',
      caseSensitive: false,
    ).firstMatch(magnet);
    return m?.group(1)?.toLowerCase();
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
  Future<Uint8List> _fetchMetadata(String magnet) async {
    final link = MagnetParser.parse(magnet);
    final downloader = MetadataDownloader.fromMagnet(magnet);

    final completer = Completer<Uint8List>();
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
    final infoHash = link?.infoHash;
    DhtClient? dht;
    if (infoHash != null && infoHash.length == 20) {
      dht = DhtClient(
        infoHash: infoHash,
        bootstrapNodes: [
          ...kDefaultDhtNodes,
          ...customNodes,
        ].map(Uri.tryParse).whereType<Uri>().toList(),
        onPeer: (ip, port) {
          try {
            downloader.addNewPeerAddress(
              CompactAddress(ip, port),
              PeerSource.dht,
            );
          } catch (_) {}
        },
      );
      unawaited(dht.start());
    }

    try {
      return await completer.future.timeout(const Duration(seconds: 180));
    } finally {
      await dht?.stop();
      try {
        await downloader.stop();
      } catch (_) {}
    }
  }

  // ── 引擎准备 ──────────────────────────────────────────────────────────────
  Future<void> _prepareEngine(TorrentJob job, {required bool start}) async {
    if (_engines.containsKey(job.id)) return;
    try {
      final magnet = MagnetParser.parse(job.magnet);
      final model = await _loadModel(job, magnet);
      if (model == null) {
        // 元数据缺失或为旧的完整 .torrent 格式（hash 不对）：后台重新抓取。
        job.hasMetadata = false;
        job.error = null;
        job.status = TorrentJobStatus.metadata;
        if (start) _wantStart.add(job.id);
        if (_refetching.add(job.id)) {
          unawaited(_refetchMetadata(job));
        }
        _emit();
        return;
      }
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
      );
      _engines[job.id] = task;
      if (start) {
        await task.start();
        _started.add(job.id);
        _applyEndpoints(task, model);
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
    final s = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return s.isEmpty ? 'torrent' : s;
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
      final bytes = await _fetchMetadata(job.magnet);
      await File(job.torrentPath).writeAsBytes(bytes, flush: true);
      final start = _wantStart.remove(job.id);
      await _prepareEngine(job, start: start);
    } catch (e) {
      job.status = TorrentJobStatus.failed;
      job.error = e.toString();
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
  void _applyEndpoints(TorrentTask task, TorrentModel model) {
    for (final tr in _parseTrackers(trackers)) {
      try {
        task.startAnnounceUrl(tr, model.infoHashBuffer);
      } catch (_) {}
    }
    for (final n in _parseTrackers([...kDefaultDhtNodes, ...customNodes])) {
      try {
        task.addDHTNode(n);
      } catch (_) {}
    }
    _applyLimits(task);
  }

  int _wantedBytes(TorrentJob job, TorrentModel model) {
    if (job.selectedFiles.isEmpty) return model.totalSize;
    if (_isNoneSelected(job.selectedFiles)) return 0;
    var sum = 0;
    for (final i in job.selectedFiles) {
      if (i >= 0 && i < model.files.length) sum += model.files[i].length;
    }
    return sum;
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

  Future<void> resume(TorrentJob job) async {
    if (job.status == TorrentJobStatus.completed) return;
    // 库的 start() 非幂等（server socket 已被监听会抛 "Stream was already
    // listened to"），并发 resume 也会重复 start，这里串行化并容错。
    if (!_starting.add(job.id)) return;
    try {
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
        if (model != null) _applyEndpoints(engine, model);
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
    if (engine != null) {
      try {
        await engine.stop();
      } catch (_) {}
      if (deleteFiles) {
        try {
          await engine.fileManager?.delete();
        } catch (_) {}
      }
      try {
        await engine.dispose();
      } catch (_) {}
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
  void _sync() {
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null) continue;
      final noneSelected = _isNoneSelected(job.selectedFiles);
      // 以引擎实际状态为准：_started 是内存态，可能与引擎不同步，
      // 之前用它判定会把已恢复的任务每秒强制打回「已暂停」
      if (engine.state == TaskState.stopped) {
        job.downloadRate = 0;
        job.uploadRate = 0;
        job.numPeers = 0;
        job.numSeeds = 0;
        // prepare() 后 fileManager 可用：读回状态，保证外层与内容进度一致
        if (engine.fileManager != null) {
          final d = engine.downloaded;
          if (d != null) job.totalDone = d;
          if (job.totalWanted <= 0) {
            job.totalWanted = engine.metaInfo.totalSize;
          }
          job.progress = noneSelected ? 0.0 : engine.progress.clamp(0.0, 1.0);
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
      final done = engine.downloaded;
      if (done != null) job.totalDone = done;
      if (job.totalWanted <= 0) {
        job.totalWanted = engine.metaInfo.totalSize;
      }
      job.progress = noneSelected ? 0.0 : engine.progress.clamp(0.0, 1.0);
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
    _emit();
    if (++_persistTick >= 5) {
      _persistTick = 0;
      _persist();
    }
  }
}

/// 全局种子管理器（Riverpod）：`ref.watch(torrentManagerProvider)` 取状态，
/// `ref.read(torrentManagerProvider.notifier)` 执行操作。
final torrentManagerProvider = NotifierProvider<TorrentManager, TorrentState>(
  TorrentManager.new,
);
