import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
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

/// 种子任务管理器（基于纯 Dart 的 dtorrent_task_v2）。
///
/// 引擎实例只在需要时创建/启动；重启后只加载已持久化的 `.torrent`，
/// 不会自动下载，等用户手动开始。
class TorrentManager extends ChangeNotifier {
  TorrentManager._();
  static final TorrentManager instance = TorrentManager._();

  bool _initialized = false;

  final List<TorrentJob> _jobs = [];
  List<TorrentJob> get jobs => List.unmodifiable(_jobs);

  /// 兼容旧 UI 命名。
  List<TorrentJob> get tasks => jobs;

  final Map<String, TorrentTask> _engines = {};
  final Map<String, TorrentModel> _models = {};
  final Map<String, TorrentStreamServer> _servers = {};
  final Set<String> _started = {};
  final Set<String> _refetching = {};
  final Set<String> _wantStart = {};

  File? _storeFile;
  Directory? _torrentDir;
  int _persistTick = 0;

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

  List<String> get trackers => _readList(appdata.implicitData, kTorrentTrackers)
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void setTrackers(List<String> list) {
    appdata.implicitData[kTorrentTrackers] = list
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    appdata.writeImplicitData();
    // 对已在运行的任务补发 announce
    for (final job in _jobs) {
      final engine = _engines[job.id];
      final model = _models[job.id];
      if (engine == null || model == null) continue;
      for (final tr in _parseTrackers(_readList(appdata.implicitData, kTorrentTrackers).split('\n'))) {
        try {
          engine.startAnnounceUrl(tr, model.infoHashBuffer);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  bool get trackerAutoAdd =>
      (appdata.implicitData[kTorrentTrackerAutoAdd] as bool?) ?? true;

  void setTrackerAutoAdd(bool v) {
    appdata.implicitData[kTorrentTrackerAutoAdd] = v;
    appdata.writeImplicitData();
    notifyListeners();
  }

  String get trackerUrl =>
      (appdata.implicitData[kTorrentTrackerUrl] as String?) ??
      'https://cf.trackerslist.com/all.txt';

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
      final list = body
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
    notifyListeners();
  }

  int get uploadLimitKb =>
      (appdata.implicitData[kTorrentUploadLimit] as int?) ?? 0;

  set uploadLimitKb(int v) {
    appdata.implicitData[kTorrentUploadLimit] = v;
    appdata.writeImplicitData();
    _applyLimitsToAll();
    notifyListeners();
  }

  bool get stopSeedAfterComplete =>
      (appdata.implicitData[kTorrentStopSeed] as bool?) ?? false;

  set stopSeedAfterComplete(bool v) {
    appdata.implicitData[kTorrentStopSeed] = v;
    appdata.writeImplicitData();
    notifyListeners();
  }

  List<String> get customNodes => _readList(appdata.implicitData, kTorrentCustomNodes)
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

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
    notifyListeners();
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
    _storeFile = File(p.join(App.dataPath, 'torrent_jobs.json'));
    _torrentDir = Directory(p.join(App.dataPath, 'torrent_meta'));
    if (!await _torrentDir!.exists()) {
      await _torrentDir!.create(recursive: true);
    }
    await _loadJobs();
    for (final job in _jobs) {
      await _prepareEngine(job, start: false);
    }
    Timer.periodic(const Duration(seconds: 1), (_) => _sync());
    notifyListeners();
  }

  Future<void> _loadJobs() async {
    try {
      final f = _storeFile;
      if (f == null || !await f.exists()) return;
      final data = jsonDecode(await f.readAsString());
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) _jobs.add(TorrentJob.fromJson(e));
        }
      }
    } catch (_) {}
  }

  void _persist() {
    final f = _storeFile;
    if (f == null) return;
    try {
      f.writeAsStringSync(
        jsonEncode(_jobs.map((j) => j.toJson()).toList()),
      );
    } catch (_) {}
  }

  // ── 添加 ──────────────────────────────────────────────────────────────────
  Future<TorrentJob> add(
    String magnet, {
    TorrentStopPolicy stopAfter = TorrentStopPolicy.none,
  }) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final job = TorrentJob(
      id: id,
      magnet: magnet,
      torrentPath: p.join(_torrentDir!.path, '$id.torrent'),
      savePath: downloadDir,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      status: TorrentJobStatus.metadata,
      stopAfter: stopAfter,
    );
    _jobs.insert(0, job);
    _persist();
    notifyListeners();

    try {
      final bytes = await _fetchMetadata(magnet);
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
    notifyListeners();
    return job;
  }

  /// 下载 magnet 元数据，返回**原始 info 字典字节**（BEP 09）。
  ///
  /// 必须保留原始字节：重新编码会改变字节（如 pieces），导致 info hash
  /// 与 magnet 不一致，tracker 拿不到 peer。
  Future<Uint8List> _fetchMetadata(String magnet) async {
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
    try {
      return await completer.future.timeout(const Duration(seconds: 180));
    } finally {
      try {
        await downloader.stop();
      } catch (_) {}
    }
  }

  // ── 引擎准备 ──────────────────────────────────────────────────────────────
  Future<void> _prepareEngine(
    TorrentJob job, {
    required bool start,
  }) async {
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
        notifyListeners();
        return;
      }
      _models[job.id] = model;
      job.hasMetadata = true;
      if (job.name.isEmpty) job.name = model.name;
      job.totalWanted = _wantedBytes(job, model);
      if (job.totalDone > job.totalWanted) job.totalDone = job.totalWanted;

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
      _applySelection(task, job, model);
      if (start) {
        await task.start();
        _started.add(job.id);
        _applyEndpoints(task, model);
        job.status = TorrentJobStatus.downloading;
      } else {
        job.status = TorrentJobStatus.paused;
      }
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

  /// 读取持久化的 **原始 info 字典字节** 构建模型。
  /// 旧版本存的是完整 `.torrent`（info 被重新编码，hash 不对），
  /// 解析会失败 → 删除并返回 null，由调用方重新抓取元数据。
  Future<TorrentModel?> _loadModel(
    TorrentJob job,
    MagnetLink? magnet,
  ) async {
    final f = File(job.torrentPath);
    if (job.torrentPath.isEmpty || !await f.exists()) return null;
    final bytes = await f.readAsBytes();
    try {
      return TorrentParser.parseFromInfoBytes(
        bytes,
        announces: magnet?.trackers ?? const [],
      );
    } catch (_) {
      try {
        await f.delete();
      } catch (_) {}
      return null;
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
    notifyListeners();
  }

  /// 应用用户选择的文件：未选中的设为 skip。
  void _applySelection(TorrentTask task, TorrentJob job, TorrentModel model) {
    final selected = job.selectedFiles;
    if (selected.isEmpty) return; // 空 = 全部
    final sel = selected.toSet();
    for (var i = 0; i < model.files.length; i++) {
      try {
        task.setFilePriority(
          i,
          sel.contains(i) ? FilePriority.normal : FilePriority.skip,
        );
      } catch (_) {}
    }
    task.applySelectedFiles(selected);
  }

  /// 应用 Tracker / DHT 节点 / 限速 到任务。
  void _applyEndpoints(TorrentTask task, TorrentModel model) {
    for (final tr in _parseTrackers(trackers)) {
      try {
        task.startAnnounceUrl(tr, model.infoHashBuffer);
      } catch (_) {}
    }
    for (final n in _parseTrackers(customNodes)) {
      try {
        task.addDHTNode(n);
      } catch (_) {}
    }
    _applyLimits(task);
  }

  int _wantedBytes(TorrentJob job, TorrentModel model) {
    if (job.selectedFiles.isEmpty) return model.totalSize;
    var sum = 0;
    for (final i in job.selectedFiles) {
      if (i >= 0 && i < model.files.length) sum += model.files[i].length;
    }
    return sum > 0 ? sum : model.totalSize;
  }

  // ── 操作 ──────────────────────────────────────────────────────────────────
  void pause(TorrentJob job) {
    final engine = _engines[job.id];
    if (engine != null && _started.contains(job.id)) {
      engine.pause();
    }
    job.downloadRate = 0;
    job.uploadRate = 0;
    job.status = TorrentJobStatus.paused;
    _persist();
    notifyListeners();
  }

  Future<void> resume(TorrentJob job) async {
    if (job.status == TorrentJobStatus.completed) return;
    final engine = _engines[job.id];
    if (engine == null) {
      await _prepareEngine(job, start: true);
    } else if (!_started.contains(job.id) ||
        engine.state == TaskState.stopped) {
      await engine.start();
      _started.add(job.id);
      final model = _models[job.id];
      if (model != null) _applyEndpoints(engine, model);
      job.status = TorrentJobStatus.downloading;
    } else if (engine.state == TaskState.paused) {
      engine.resume();
      job.status = TorrentJobStatus.downloading;
    }
    _sync();
    _persist();
    notifyListeners();
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
    notifyListeners();
  }

  void setSelectedFiles(TorrentJob job, List<int> indices) {
    job.selectedFiles = List<int>.from(indices);
    final engine = _engines[job.id];
    final model = _models[job.id];
    if (engine != null && model != null) {
      _applySelection(engine, job, model);
    }
    if (model != null) job.totalWanted = _wantedBytes(job, model);
    _persist();
    notifyListeners();
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
    notifyListeners();
  }

  // ── 轮询同步 ──────────────────────────────────────────────────────────────
  void _sync() {
    for (final job in _jobs) {
      final engine = _engines[job.id];
      if (engine == null) continue;
      if (!_started.contains(job.id)) {
        job.downloadRate = 0;
        job.uploadRate = 0;
        job.numPeers = 0;
        job.numSeeds = 0;
        if (job.status != TorrentJobStatus.completed &&
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
      if (job.totalWanted <= 0) job.totalWanted = engine.metaInfo.totalSize;
      job.progress = engine.progress.clamp(0.0, 1.0);
      if (engine.state == TaskState.paused) {
        job.status = TorrentJobStatus.paused;
      } else if (job.progress >= 0.999) {
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
    notifyListeners();
    if (++_persistTick >= 5) {
      _persistTick = 0;
      _persist();
    }
  }
}
