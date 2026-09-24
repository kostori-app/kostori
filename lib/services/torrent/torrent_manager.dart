import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/services/torrent/torrent_task.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 设置 key
const String kTorrentDownloadLimit = 'torrentDownloadLimit'; // KB/s, 0=不限
const String kTorrentUploadLimit = 'torrentUploadLimit'; // KB/s, 0=不限
const String kTorrentDht = 'torrentDht';
const String kTorrentLsd = 'torrentLsd';
const String kTorrentUpnp = 'torrentUpnp';
const String kTorrentEncrypt = 'torrentEncrypt';
const String kTorrentStopSeed = 'torrentStopSeed';
const String kTorrentTrackers = 'torrentTrackers';
const String kTorrentTrackerUrl = 'torrentTrackerUrl';
const String _kDefaultTrackerUrl = 'https://cf.trackerslist.com/all.txt';

/// 种子任务管理器：封装 libtorrent 引擎、任务持久化(JSON)与恢复、全局设置。
/// 保存目录与普通下载一致；任务只是一个「下载并保存」的任务，随时可播放。
class TorrentManager extends ChangeNotifier {
  TorrentManager._();
  static final TorrentManager instance = TorrentManager._();

  bool _initialized = false;
  bool get initialized => _initialized;

  final List<TorrentTask> _tasks = [];
  List<TorrentTask> get tasks => List.unmodifiable(_tasks);

  StreamSubscription<Map<int, TorrentInfo>>? _tSub;
  StreamSubscription<Map<int, StreamInfo>>? _sSub;
  final Map<int, StreamInfo> _streams = {};

  File? _storeFile;
  Timer? _saveTimer;

  /// 与普通下载相同的目录
  static String get downloadDir {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return p.join(App.dataPath, 'downloads');
  }

  TorrentTask? byEngineId(int id) {
    for (final t in _tasks) {
      if (t.engineId == id) return t;
    }
    return null;
  }

  StreamInfo? streamFor(TorrentTask task) {
    final id = task.engineId;
    if (id == null) return null;
    for (final s in _streams.values) {
      if (s.torrentId == id) return s;
    }
    return null;
  }

  // ── 设置 ──────────────────────────────────────────────────────────────────
  int get downloadLimitKb =>
      (appdata.implicitData[kTorrentDownloadLimit] as int?) ?? 0;
  int get uploadLimitKb =>
      (appdata.implicitData[kTorrentUploadLimit] as int?) ?? 0;
  bool get dhtEnabled => (appdata.implicitData[kTorrentDht] as bool?) ?? true;
  bool get lsdEnabled => (appdata.implicitData[kTorrentLsd] as bool?) ?? true;
  bool get upnpEnabled => (appdata.implicitData[kTorrentUpnp] as bool?) ?? true;
  bool get encryptEnabled =>
      (appdata.implicitData[kTorrentEncrypt] as bool?) ?? false;
  bool get stopSeedAfterComplete =>
      (appdata.implicitData[kTorrentStopSeed] as bool?) ?? false;

  set downloadLimitKb(int v) {
    appdata.implicitData[kTorrentDownloadLimit] = v;
    _persistSettings();
  }

  set uploadLimitKb(int v) {
    appdata.implicitData[kTorrentUploadLimit] = v;
    _persistSettings();
  }

  void setDht(bool v) {
    appdata.implicitData[kTorrentDht] = v;
    _persistSettings();
  }

  void setLsd(bool v) {
    appdata.implicitData[kTorrentLsd] = v;
    _persistSettings();
  }

  void setUpnp(bool v) {
    appdata.implicitData[kTorrentUpnp] = v;
    _persistSettings();
  }

  void setEncrypt(bool v) {
    appdata.implicitData[kTorrentEncrypt] = v;
    _persistSettings();
  }

  void setStopSeed(bool v) {
    appdata.implicitData[kTorrentStopSeed] = v;
    _persistSettings();
  }

  void _persistSettings() {
    appdata.writeImplicitData();
    _applyLimits();
  }

  String get trackers =>
      (appdata.implicitData[kTorrentTrackers] as String?) ?? '';
  String get trackerUrl =>
      (appdata.implicitData[kTorrentTrackerUrl] as String?) ??
      _kDefaultTrackerUrl;

  void setTrackers(String v) {
    appdata.implicitData[kTorrentTrackers] = v;
    appdata.writeImplicitData();
    notifyListeners();
  }

  void setTrackerUrl(String v) {
    appdata.implicitData[kTorrentTrackerUrl] = v;
    appdata.writeImplicitData();
    notifyListeners();
  }

  Future<void> fetchTrackers() async {
    final url = trackerUrl.trim();
    if (url.isEmpty) return;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
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
      if (list.isNotEmpty) setTrackers(list.join('\n'));
    } catch (_) {}
  }

  String withTrackers(String magnet) {
    final buf = StringBuffer(magnet);
    for (final line in trackers.split('\n')) {
      final tr = line.trim();
      if (tr.isEmpty || !tr.contains('://')) continue;
      final enc = Uri.encodeComponent(tr);
      if (magnet.contains(enc) || magnet.contains(tr)) continue;
      buf.write('&tr=$enc');
    }
    return buf.toString();
  }

  // ── 初始化 ────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _storeFile = File(p.join(App.dataPath, 'torrent_tasks.json'));
    if (!LibtorrentFlutter.isInitialized) {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/torrent');
      if (!await dir.exists()) await dir.create(recursive: true);
      await LibtorrentFlutter.init(
        fetchTrackers: false,
        defaultSavePath: downloadDir,
      );
      _applyConfig();
    }
    await _loadTasks();
    _tSub = LibtorrentFlutter.instance.torrentUpdates.listen(_onTorrents);
    _sSub = LibtorrentFlutter.instance.streamUpdates.listen(_onStreams);
    await _restoreTasks();
    notifyListeners();
  }

  void _applyConfig() {
    LibtorrentFlutter.instance.configureSession(
      BtConfig(
        disableDht: !dhtEnabled,
        disableUpnp: !upnpEnabled,
        forceEncrypt: encryptEnabled,
      ),
    );
    _applyLimits();
  }

  void _applyLimits() {
    if (!LibtorrentFlutter.isInitialized) return;
    LibtorrentFlutter.instance.setDownloadLimit(downloadLimitKb * 1024);
    LibtorrentFlutter.instance.setUploadLimit(uploadLimitKb * 1024);
  }

  // ── 任务操作 ──────────────────────────────────────────────────────────────
  Future<TorrentTask> add(String magnet) async {
    final task = TorrentTask(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      magnet: magnet,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _tasks.insert(0, task);
    _persist();
    notifyListeners();
    await _startEngine(task);
    return task;
  }

  Future<void> _startEngine(TorrentTask task) async {
    try {
      final dir = Directory(downloadDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final id = LibtorrentFlutter.instance.addMagnet(
        withTrackers(task.magnet),
        downloadDir,
      );
      task.engineId = id;
      notifyListeners();
    } catch (e) {
      task.status = TorrentTaskStatus.failed;
      task.error = e.toString();
      notifyListeners();
    }
  }

  void pause(TorrentTask task) {
    final id = task.engineId;
    if (id != null) LibtorrentFlutter.instance.pauseTorrent(id);
    task.status = TorrentTaskStatus.paused;
    notifyListeners();
  }

  void resume(TorrentTask task) {
    final id = task.engineId;
    if (id != null) {
      LibtorrentFlutter.instance.resumeTorrent(id);
    } else {
      unawaited(_startEngine(task));
    }
    task.status = TorrentTaskStatus.downloading;
    notifyListeners();
  }

  void remove(TorrentTask task) {
    final id = task.engineId;
    if (id != null) {
      try {
        LibtorrentFlutter.instance.disposeTorrent(id);
      } catch (_) {}
    }
    _tasks.remove(task);
    _persist();
    notifyListeners();
  }

  List<FileInfo> filesOf(TorrentTask task) {
    final id = task.engineId;
    if (id == null) return const [];
    try {
      return LibtorrentFlutter.instance.getFiles(id);
    } catch (_) {
      return const [];
    }
  }

  /// 设置任务要下载的文件（空 = 全部）。
  void setSelectedFiles(TorrentTask task, List<int> indices) {
    _applySelected(task);
  }

  void _applySelected(TorrentTask task) {}

  /// 开始流播放：返回本地 HTTP url。
  StreamInfo startStream(TorrentTask task, int fileIndex) {
    final id = task.engineId!;
    for (final s in _streams.values) {
      if (s.torrentId == id && s.fileIndex == fileIndex) return s;
    }
    final stream = LibtorrentFlutter.instance.startStream(
      id,
      fileIndex: fileIndex,
      maxCacheBytes: 256 * 1024 * 1024,
    );
    _streams[stream.id] = stream;
    return stream;
  }

  // ── 状态轮询 ──────────────────────────────────────────────────────────────
  void _onTorrents(Map<int, TorrentInfo> map) {
    var changed = false;
    for (final t in _tasks) {
      final id = t.engineId;
      if (id == null) continue;
      final info = map[id];
      if (info == null) continue;
      t.hasMetadata = info.hasMetadata;
      t.numPeers = info.numPeers;
      t.numSeeds = info.numSeeds;
      t.downloadRate = info.downloadRate;
      t.uploadRate = info.uploadRate;
      t.totalDone = info.totalDone;
      t.totalWanted = info.totalWanted;
      t.progress = info.progress.clamp(0.0, 1.0);
      if (info.name.isNotEmpty) t.name = info.name;
      t.status = _mapStatus(t, info);
      if (t.isFinished && stopSeedAfterComplete) {
        try {
          LibtorrentFlutter.instance.pauseTorrent(id);
        } catch (_) {}
      }
      changed = true;
    }
    if (changed) {
      _persistDebounced();
      notifyListeners();
    }
  }

  TorrentTaskStatus _mapStatus(TorrentTask t, TorrentInfo info) {
    if (info.state == TorrentState.error) return TorrentTaskStatus.failed;
    if (info.isPaused) return TorrentTaskStatus.paused;
    if (t.status == TorrentTaskStatus.paused) return TorrentTaskStatus.paused;
    if (info.state == TorrentState.finished ||
        info.state == TorrentState.seeding) {
      return TorrentTaskStatus.completed;
    }
    if (!info.hasMetadata) return TorrentTaskStatus.metadata;
    return TorrentTaskStatus.downloading;
  }

  void _onStreams(Map<int, StreamInfo> map) {
    _streams
      ..clear()
      ..addAll(map);
    notifyListeners();
  }

  // ── 持久化 ────────────────────────────────────────────────────────────────
  Future<void> _loadTasks() async {
    try {
      if (_storeFile == null || !await _storeFile!.exists()) return;
      final data = jsonDecode(await _storeFile!.readAsString());
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) {
            _tasks.add(TorrentTask.fromJson(e));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _restoreTasks() async {
    // 重新把 magnet 加入引擎，libtorrent 会按下载目录里已有文件续传。
    for (final t in _tasks) {
      if (t.status == TorrentTaskStatus.completed) continue;
      t.status = TorrentTaskStatus.metadata;
      await _startEngine(t);
    }
  }

  void _persistDebounced() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _persist);
  }

  void _persist() {
    final f = _storeFile;
    if (f == null) return;
    try {
      f.writeAsStringSync(jsonEncode(_tasks.map((t) => t.toJson()).toList()));
    } catch (_) {}
  }

  @override
  void dispose() {
    _tSub?.cancel();
    _sSub?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}
