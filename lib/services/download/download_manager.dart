import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/database/download_database.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/m3u8_proxy_server.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/cloudflare.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/services/download/download_file_writer.dart';
import 'package:kostori/services/download/download_keep_alive.dart';
import 'package:kostori/services/download/download_task.dart';
import 'package:kostori/utils/ffmpeg_encoder.dart';
import 'package:path/path.dart' as p;

/// 下载直链的永久性 HTTP 错误（403/404/410 等）：地址失效，重试无意义。
class _DownloadHttpError implements Exception {
  final int code;
  const _DownloadHttpError(this.code);

  @override
  String toString() => 'HTTP $code';
}

/// 解析下载响应头，得到本次响应的起始偏移与文件完整大小。
///
/// - `start`：响应内容的起始字节偏移；无法确认时为 -1。
/// - `total`：文件完整大小（206 取 `Content-Range` 的 `/total`）；
///   未知时为 -1，此时无法校验下载是否完整。
({int start, int total}) parseDownloadRange({
  required int status,
  required String? contentRange,
  required int contentLength,
}) {
  if (status == 206 && contentRange != null) {
    final match = RegExp(r'bytes\s+(\d+)-(\d+)\s*/\s*(\d+|\*)')
        .firstMatch(contentRange);
    if (match != null) {
      return (
        start: int.tryParse(match.group(1) ?? '') ?? -1,
        total: int.tryParse(match.group(3) ?? '') ?? -1,
      );
    }
  }
  if (status == 200 && contentLength > 0) {
    return (start: 0, total: contentLength);
  }
  return (start: -1, total: -1);
}

/// m3u8 播放列表是否被截断：VOD 列表按规范以 `#EXT-X-ENDLIST` 结尾，
/// 缺少它说明响应体被提前断流（否则会漏掉尾部分片）。
bool isTruncatedHlsPlaylist(String content) {
  if (!RegExp(r'#EXT-X-PLAYLIST-TYPE:\s*VOD').hasMatch(content)) {
    return false;
  }
  return !content.contains('#EXT-X-ENDLIST');
}

/// 视频下载管理器：任务队列 + 并发控制 + 进度通知 + 本地持久化。
///
/// 支持 mp4 直链（dio 流式写入，Range 断点续传，完成后校验字节数）
/// 与 m3u8/HLS（分片下载后用 FFmpeg 转封装为 mp4，流复制不重编码）。
class DownloadManager extends ChangeNotifier {
  DownloadManager._internal();

  static final DownloadManager instance = DownloadManager._internal();

  /// 下载兜底浏览器 UA（移动端：moedet 等手机源仅对移动 UA 放行，桌面 UA 会 400）
  static const String _browserUA =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// 同时下载的任务数（设置可调）
  int get _maxConcurrent {
    final v = appdata.implicitData['downloadConcurrent'] as int?;
    return (v != null && v > 0) ? v : 2;
  }

  final List<DownloadTask> _tasks = [];
  final List<String> _runningIds = [];

  /// 进行中任务的取消句柄
  final Map<String, FfmpegCancelToken> _cancelTokens = {};

  /// 速度采样（任务 id → 上次采样时间/字节数）
  final Map<String, DateTime> _speedSampleTime = {};
  final Map<String, int> _speedSampleBytes = {};

  /// 进度通知节流：task.id → 上次 notify 时间
  final Map<String, DateTime> _lastProgressNotify = {};

  /// 全局进度通知节流：把多任务/多来源的通知统一为半秒一次。
  static const _progressNotifyInterval = Duration(milliseconds: 500);

  DateTime? _lastProgressNotifyAll;
  Timer? _progressNotifyTimer;

  /// 下载记录变化（完成/删除/移动/重命名）时触发，供卡片下载角标刷新
  final StreamController<void> _recordsChanged =
      StreamController<void>.broadcast();

  Stream<void> get recordsChanged => _recordsChanged.stream;

  /// `animeId|sourceKey` → 有下载记录（同步缓存，供列表卡片角标）
  Set<String> _downloadedKeys = {};

  bool isDownloaded(String? animeId, String? sourceKey) {
    if (animeId == null || animeId.isEmpty || sourceKey == null) return false;
    return _downloadedKeys.contains('$animeId|$sourceKey');
  }

  Future<void> _refreshDownloadedKeys() async {
    List records;
    try {
      records = await allRecords();
    } catch (_) {
      return;
    }
    // 只看是否存在下载记录，不校验文件是否还在：卡片「已下载」角标据此点亮，
    // 避免用户以为没下过而重复下载同一条目。
    final keys = <String>{};
    for (final r in records.whereType<Map>()) {
      final aid = r['animeId']?.toString() ?? '';
      if (aid.isEmpty) continue;
      keys.add('$aid|${r['sourceKey']}');
    }
    _downloadedKeys = keys;
    if (!_recordsChanged.isClosed) _recordsChanged.add(null);
  }

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  int get _activeCount =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).length;

  static String get _downloadDir {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return p.join(App.dataPath, 'downloads');
  }

  /// 分组对应的下载目录（空分组 = 根下载目录）
  static String groupDir(String group) =>
      group.isEmpty ? _downloadDir : p.join(_downloadDir, group);

  String _taskDirPath(DownloadTask task) =>
      p.join(groupDir(task.group), _safeTaskName(task));

  bool _loaded = false;
  Future<void> _persistChain = Future.value();

  DateTime? _lastKeepAlive;

  // 总任务进度（按任务完成数计数，失败也计入；单条双色）。
  // - 初始为 0 时不显示；完成后继续显示，直到用户手动关闭或应用退出。
  // - 意外退出（崩溃/杀进程）且还有未完成任务时，下次启动恢复显示。
  // - 计数用 done/failed 两个 id 集合维护，任务可在两态间迁移
  //   （失败后重试成功 = failed→done），避免出现既不算完成也不算失败、
  //   进度条永远差一截的灰色。
  // - 全部逻辑 try/catch 包底：计数绝不能把下载主流程搞崩。
  static const _batchPersistKey = 'downloadBatchProgress';
  int batchTotal = 0;
  int batchDone = 0;
  int batchFailed = 0;
  bool _batchVisible = false;
  bool get batchVisible => _batchVisible && batchTotal > 0;
  final Set<String> _batchDoneIds = {};
  final Set<String> _batchFailedIds = {};

  int get batchDoneView => batchDone.clamp(0, batchTotal);
  int get batchFailedView =>
      batchFailed.clamp(0, (batchTotal - batchDoneView).clamp(0, batchTotal));

  void _saveBatch() {
    try {
      final unfinished = _tasks
          .where((t) => t.status != DownloadStatus.completed)
          .length;
      // 已全部完成：横幅只活在内存（手动关闭/退出即消失），不落盘
      if (unfinished == 0 && batchDoneView + batchFailedView >= batchTotal) {
        appdata.implicitData.remove(_batchPersistKey);
      } else {
        appdata.implicitData[_batchPersistKey] = {
          'total': batchTotal,
          'done': batchDone,
          'failed': batchFailed,
          'doneIds': _batchDoneIds.toList(),
          'failedIds': _batchFailedIds.toList(),
          'visible': _batchVisible,
        };
      }
      appdata.writeImplicitData();
    } catch (_) {}
  }

  void _loadBatch() {
    try {
      batchTotal = 0;
      batchDone = 0;
      batchFailed = 0;
      _batchVisible = false;
      _batchDoneIds.clear();
      _batchFailedIds.clear();
      final raw = appdata.implicitData[_batchPersistKey];
      if (raw is Map) {
        batchTotal = (raw['total'] as num?)?.toInt() ?? 0;
        batchDone = (raw['done'] as num?)?.toInt() ?? 0;
        batchFailed = (raw['failed'] as num?)?.toInt() ?? 0;
        _batchVisible = raw['visible'] == true;
        final doneIds = raw['doneIds'];
        if (doneIds is List) {
          _batchDoneIds.addAll(doneIds.map((e) => e.toString()));
        }
        final failedIds = raw['failedIds'];
        if (failedIds is List) {
          _batchFailedIds.addAll(failedIds.map((e) => e.toString()));
        }
      }
      final unfinished = _tasks
          .where((t) => t.status != DownloadStatus.completed)
          .length;
      if (unfinished > 0) {
        // 有未完成任务但计数丢了（如崩溃时没落盘），按未完成数重建
        if (batchTotal <= 0) {
          batchTotal = unfinished;
          batchDone = 0;
          batchFailed = 0;
          _saveBatch();
        }
        // 只要有未完成任务就必定显示：持久化的 visible 可能过期，
        // 否则会出现 batchTotal>0 但进度条永不出现的情况
        _batchVisible = true;
      } else {
        // 无未完成任务：退出后不保留已完成的横幅
        _batchVisible = false;
        batchTotal = 0;
        batchDone = 0;
        batchFailed = 0;
        _batchDoneIds.clear();
        _batchFailedIds.clear();
      }
    } catch (_) {
      // 保底：读坏了就隐藏，绝不影响下载列表
      _batchVisible = false;
    }
  }

  void _batchAdd() {
    try {
      batchTotal++;
      // 只要还在一轮里（有新任务入队）就必须显示，不能依赖 batchTotal==1
      _batchVisible = true;
      if (batchDoneView + batchFailedView > batchTotal) {
        batchFailed = (batchTotal - batchDoneView).clamp(0, batchTotal);
      }
      _saveBatch();
    } catch (_) {}
  }

  /// 任务完成：若此前算作失败则迁移到完成，避免任务从失败转成功后
  /// 因去重而两边都不计数（进度条永远差一截灰色）
  void _batchDone(DownloadTask task) {
    try {
      if (_batchFailedIds.remove(task.id)) {
        batchFailed = (batchFailed - 1).clamp(0, batchTotal);
      }
      if (_batchDoneIds.add(task.id)) {
        if (batchTotal <= 0) batchTotal = 1;
        batchDone++;
      }
      _batchVisible = true;
      _saveBatch();
    } catch (_) {}
  }

  /// 任务失败：若此前算作完成则迁移到失败
  void _batchFailed(DownloadTask task) {
    try {
      if (_batchDoneIds.remove(task.id)) {
        batchDone = (batchDone - 1).clamp(0, batchTotal);
      }
      if (_batchFailedIds.add(task.id)) {
        if (batchTotal <= 0) batchTotal = 1;
        batchFailed++;
      }
      _batchVisible = true;
      _saveBatch();
    } catch (_) {}
  }

  /// 失败任务被重新排队：取消之前的失败计数（任务仍在总数里）
  void _batchUncount(DownloadTask task) {
    try {
      if (_batchFailedIds.remove(task.id)) {
        batchFailed = (batchFailed - 1).clamp(0, batchTotal);
        _saveBatch();
      }
    } catch (_) {}
  }

  /// 任务被删除/取消：从总数中剔除（已计数的同步扣减）
  void _batchRemove(DownloadTask task) {
    try {
      if (_batchFailedIds.remove(task.id)) {
        batchFailed = (batchFailed - 1).clamp(0, batchTotal);
      } else if (_batchDoneIds.remove(task.id)) {
        batchDone = (batchDone - 1).clamp(0, batchTotal);
      }
      batchTotal = (batchTotal - 1).clamp(0, 1 << 30);
      if (batchTotal <= 0) {
        batchTotal = 0;
        batchDone = 0;
        batchFailed = 0;
        _batchVisible = false;
        _batchDoneIds.clear();
        _batchFailedIds.clear();
      }
      _saveBatch();
    } catch (_) {}
  }

  /// 用户手动关闭总进度条
  void dismissBatch() {
    try {
      _batchVisible = false;
      batchTotal = 0;
      batchDone = 0;
      batchFailed = 0;
      _batchDoneIds.clear();
      _batchFailedIds.clear();
      _saveBatch();
      notifyListeners();
    } catch (_) {}
  }

  /// 同步前台服务通知（节流 1s）：有下载任务时保活，无任务时停止
  void _syncKeepAlive({bool force = false}) {
    if (!Platform.isAndroid) return;
    final active = _tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .toList();
    if (active.isEmpty) {
      // 只注销自己这一个来源：BT 种子可能仍在做种，不能把整个前台服务停掉
      DownloadKeepAlive.detach(DownloadKeepAlive.ownerHttp);
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
        DownloadKeepAlive.ownerHttp,
        active.map((t) => (title: t.title, progress: t.progress)).toList(),
        remaining: active.length,
      ),
    );
  }

  /// 仅 WiFi：非 WiFi 网络时轮询等待，直到 WiFi 或取消
  Future<void> _waitForWifiIfNeeded(FfmpegCancelToken cancelToken) async {
    final wifiOnly = appdata.implicitData['downloadWifiOnly'] as bool? ?? false;
    if (!wifiOnly || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      while (!cancelToken.isCancelled) {
        final results = await Connectivity().checkConnectivity();
        final wifi = results.any((r) => r == ConnectivityResult.wifi);
        if (wifi) return;
        await Future.delayed(const Duration(seconds: 3));
      }
    } catch (_) {}
    if (cancelToken.isCancelled) throw FfmpegCancelledException();
  }

  /// 初始化：加载持久化任务。应用启动时调用。
  Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final jsons = await DownloadDatabase.instance.loadTaskJson();
      for (final j in jsons) {
        try {
          _tasks.add(
            DownloadTask.fromJson(Map<String, dynamic>.from(jsonDecode(j))),
          );
        } catch (_) {}
      }
      // 重启后中断的任务置为“已暂停”：保留断点文件，由用户手动点继续续传
      for (final t in _tasks) {
        if (t.isActive) {
          t.status = DownloadStatus.paused;
          t.error = null;
        }
      }
      Directory(_downloadDir).createSync(recursive: true);
      _persist();
      // 恢复总进度计数（崩溃/杀进程后有未完成任务时重建显示）
      _loadBatch();
      // 老版本任务补序号
      _backfillTaskSeq();
      notifyListeners();
      unawaited(_refreshDownloadedKeys());
      // 兜底：清理残留分片（已完成/失败/孤儿任务的分片目录），
      // 避免旧版本未清理的 TS 切片占用体积越来越大
      unawaited(_cleanupOrphanSegments());
    } catch (e, s) {
      Log.error('DownloadManager.init', '$e\n$s');
    }
  }

  /// 清理非进行中任务目录下的 segments 分片。
  /// 保留 queued/downloading/paused 任务的切片（断点续传用），
  /// 清理孤儿残留：非可恢复任务（completed/无任务对应）的分片目录 +
  /// 各目录残留的 video.mp4 半成品（合并中断/强关遗留，避免损坏与占空间）。
  /// 保留 queued/downloading/paused/failed 任务的切片（断点续传 / 重新合并用）。
  /// 分组后目录是 `downloads/<分组>/<任务目录>`，这里递归一层处理分组目录。
  Future<void> _cleanupOrphanSegments() async {
    try {
      final root = Directory(_downloadDir);
      if (!await root.exists()) return;
      final resumable = [
        for (final t in _tasks)
          if (t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.paused ||
              t.status == DownloadStatus.failed)
            t,
      ];
      final keepDirs = <String>{for (final t in resumable) _taskDirPath(t)};
      final keepIds = <String>{for (final t in resumable) t.id};
      // 遍历整个下载目录（含分组）可能很多，放后台 isolate，避免启动瞬间卡 UI
      final rootPath = root.path;
      await Isolate.run(
        _cleanupOrphanSegmentsRunner(rootPath, keepDirs, keepIds),
      );
    } catch (e) {
      Log.error('DownloadManager.cleanupOrphanSegments', '$e');
    }
  }

  /// 创建下载任务（自动进入队列）
  ///
  /// 同一内容去重：url + 清晰度 + 分组一致且旧任务未完成（queued/downloading/
  /// paused/failed）时直接复用旧任务（paused/failed 顺手 resume），
  /// 避免重复点击/规则变化/重进弹窗建出无限多的同集任务。
  /// 不同清晰度视为不同任务，不去重。
  Future<DownloadTask?> enqueue({
    required String url,
    String? title,
    String? subtitle,
    String? cover,
    String? sourceKey,
    String? animeId,
    String? animeTitle,
    String? episode,
    String? episodeRaw,
    String? author,
    String? episodeNo,
    String? resolution,
    String? group,
    Map<String, String> headers = const {},
  }) async {
    if (url.isEmpty) return null;
    if (url.startsWith('blob:')) return null;
    final groupKey = group ?? '';
    for (final t in _tasks) {
      if (t.url == url &&
          (t.resolution ?? '') == (resolution ?? '') &&
          t.group == groupKey &&
          t.status != DownloadStatus.completed) {
        if (t.status == DownloadStatus.paused ||
            t.status == DownloadStatus.failed) {
          await resume(t.id);
        }
        return t;
      }
    }
    // 无 UA 时补浏览器 UA：优先用播放时 WebView 记录的真实 UA
    // （签名 CDN 如 beeg 会校验 UA，与播放不一致会导致 403 Wrong key），
    // 再回落固定浏览器 UA；缺省会被 rhttp 填成 "kostori/..."，
    // 部分 CDN（moedot 等）拒绝该 UA 返回 400，而浏览器可直下
    var effectiveHeaders = Map<String, String>.from(headers);
    if (effectiveHeaders['User-Agent'] == null &&
        effectiveHeaders['user-agent'] == null) {
      effectiveHeaders['User-Agent'] =
          appdata.implicitData['ua'] as String? ?? _browserUA;
    }
    // 附加 cookie jar 的 cookie，与播放端一致（否则校验会话的源会 403/410）。
    // 很多 CDN 只认主站下发的 cookie：按下载地址域名取不到时，
    // 退回 Referer（源站）域名的 cookie —— 与播放端的 _cookieHeaderFor 同逻辑
    final dlUri = Uri.tryParse(url);
    if (dlUri != null && (dlUri.scheme == 'http' || dlUri.scheme == 'https')) {
      try {
        final jar = SingleInstanceCookieJar.instance;
        var cookieHeader = await jar?.loadForRequestCookieHeader(dlUri) ?? '';
        if (cookieHeader.isEmpty) {
          final referer =
              effectiveHeaders['Referer'] ?? effectiveHeaders['referer'];
          final refUri = referer == null ? null : Uri.tryParse(referer);
          if (refUri != null &&
              refUri.host.isNotEmpty &&
              refUri.host != dlUri.host) {
            cookieHeader = await jar?.loadForRequestCookieHeader(refUri) ?? '';
          }
        }
        if (cookieHeader.isNotEmpty) {
          effectiveHeaders['Cookie'] = cookieHeader;
        }
      } catch (_) {}
    }
    final task = DownloadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_taskIdSeq++}_${url.hashCode}',
      title: title ?? url,
      subtitle: subtitle,
      cover: cover,
      url: url,
      sourceKey: sourceKey,
      animeId: animeId,
      animeTitle: animeTitle,
      episode: episode,
      episodeRaw: episodeRaw,
      episodeNo: episodeNo,
      author: author,
      resolution: resolution,
      group: group ?? '',
      headers: effectiveHeaders,
      createdAt: DateTime.now(),
      // 序号：没有未完成任务时从 1 重排（新一轮），否则续上最大序号；
      // 已完成任务保留在列表里但不参与，保证中途完成不重置、
      // 清空后新任务又从 1 开始
      seq: _nextTaskSeq(),
    );
    _tasks.add(task);
    _batchAdd();
    _persist();
    notifyListeners();
    _schedule();
    return task;
  }

  /// 下一个任务序号：只看未完成任务；空列表从 1 开始
  int _nextTaskSeq() {
    var maxSeq = 0;
    var hasUnfinished = false;
    for (final t in _tasks) {
      if (t.status == DownloadStatus.completed) continue;
      hasUnfinished = true;
      if (t.seq > maxSeq) maxSeq = t.seq;
    }
    return hasUnfinished ? maxSeq + 1 : 1;
  }

  /// 老版本持久化任务无 seq：按创建时间补上（只补未完成），保持显示稳定
  void _backfillTaskSeq() {
    try {
      final pending =
          _tasks
              .where((t) => t.status != DownloadStatus.completed && t.seq <= 0)
              .toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (pending.isEmpty) return;
      var maxSeq = 0;
      for (final t in _tasks) {
        if (t.status != DownloadStatus.completed && t.seq > maxSeq) {
          maxSeq = t.seq;
        }
      }
      for (final t in pending) {
        t.seq = ++maxSeq;
      }
      _persist();
    } catch (_) {}
  }

  /// 把某个刚恢复的任务提升到队首（正在下载之后），
  /// 使其在下一个空闲并发位优先开始（用于单任务“重试/继续”）
  void _prioritizeQueued(DownloadTask task) {
    final i = _tasks.indexOf(task);
    if (i <= 0) return;
    _tasks.removeAt(i);
    final afterRunning = _tasks.lastIndexWhere(
      (t) => t.status == DownloadStatus.downloading,
    );
    _tasks.insert(afterRunning + 1, task);
  }

  /// 每个任务的“自动续传”次数（临时性错误失败后自动重新排队）
  final Map<String, int> _autoRetryCounts = {};

  static const int _maxAutoRetries = 3;

  /// 自动续传退避截止时间：在此之前 _schedule 不启动该任务，
  /// 避免 finally 里的补调度把指数退避抵消成“立即重试”
  final Map<String, DateTime> _pendingRetryAt = {};

  /// 临时性错误（连接中断/超时/握手失败等）值得自动续传；
  /// 永久性错误（HTTP 403/404/410、ffmpeg 失败等）需人工重新解析
  bool _isTransient(Object e) {
    final s = e.toString();
    if (e is _DownloadHttpError) return false;
    if (s.contains('HTTP ')) return false;
    if (s.contains('中断') ||
        s.contains('Connection closed') ||
        s.contains('SocketException') ||
        s.contains('HandshakeException') ||
        s.contains('connectionError') ||
        s.contains('connectionTimeout') ||
        s.contains('receiveTimeout') ||
        s.contains('sendTimeout')) {
      return true;
    }
    return false;
  }

  void _schedule() {
    final now = DateTime.now();
    for (final t in _tasks) {
      if (t.status != DownloadStatus.queued) continue;
      final notBefore = _pendingRetryAt[t.id];
      if (notBefore != null) {
        if (now.isBefore(notBefore)) continue;
        _pendingRetryAt.remove(t.id);
      }
      if (_activeCount < _maxConcurrent) {
        unawaited(_runTask(t));
      }
    }
  }

  /// 并发数等设置变化后补调度（调大立即补起排队任务；调小不杀已跑任务，
  /// 自然收敛）。设置页改完直接调，不用等下一次 enqueue。
  void poke() => _schedule();

  Future<void> _runTask(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    // 断点恢复时先按已下载量还原进度，避免进度条瞬间跳到 0 再恢复
    if (task.totalBytes > 0 &&
        task.downloadedBytes > 0 &&
        task.downloadedBytes <= task.totalBytes) {
      task.progress = (task.downloadedBytes / task.totalBytes).clamp(0.0, 1.0);
    } else {
      task.progress = 0;
    }
    _runningIds.add(task.id);
    final cancelToken = FfmpegCancelToken();
    _cancelTokens[task.id] = cancelToken;
    notifyListeners();
    _syncKeepAlive(force: true);

    try {
      // 取消/异常统一走下方 finally 清理并发槽与取消令牌
      await _waitForWifiIfNeeded(cancelToken);

      // 每个任务一个目录（含分组子目录）：mp4 断点临时文件 / m3u8 分片都在目录内
      final taskDir = _taskDirPath(task);
      await Directory(taskDir).create(recursive: true);
      final tmpPath = p.join(taskDir, 'video.mp4');
      // 最终文件名用标题基名（不带唯一 id 数字后缀），目录仍按 taskDir 隔离
      final finalPath = p.join(taskDir, '${_fileBaseName(task)}.mp4');

      try {
        if (task.isHls) {
          await _downloadHls(task, cancelToken, taskDir, tmpPath);
        } else {
          await _downloadDirect(task, cancelToken, tmpPath);
        }
      } on CloudflareException {
        // HTTP/1.1 被 CF 拦：改用 HTTP/2 重试（头不变），仍失败回退本地代理
        try {
          if (task.isHls) {
            await _downloadHls(
              task,
              cancelToken,
              taskDir,
              tmpPath,
              useHttp2: true,
            );
          } else {
            await _downloadDirect(task, cancelToken, tmpPath, useHttp2: true);
          }
        } on FfmpegCancelledException {
          rethrow;
        } catch (_) {
          await _downloadViaFfmpeg(task, cancelToken, tmpPath);
        }
      } on DioException catch (e) {
        // 连接层失败（无 HTTP 响应）：回退本地代理
        if (e.type == DioExceptionType.cancel || cancelToken.isCancelled) {
          rethrow;
        }
        await _downloadViaFfmpeg(task, cancelToken, tmpPath);
      }

      final tmp = File(tmpPath);
      if (!await tmp.exists() || await tmp.length() == 0) {
        throw Exception('下载结果为空');
      }
      if (!_tasks.contains(task)) {
        await _deleteQuiet(tmp);
        return;
      }
      // 覆盖已有同名文件
      final dst = File(finalPath);
      if (await dst.exists()) await _deleteQuiet(dst);
      await tmp.rename(finalPath);
      task.filePath = finalPath;
      // 补全实际文件大小（m3u8 下载时无法预知总大小，合并后取真实值）
      task.totalBytes = await File(finalPath).length();
      task.downloadedBytes = task.totalBytes;
      task.status = DownloadStatus.completed;
      // 与 completed 同一帧刷掉合并态（finally 里统一 notify），
      // 避免合并条先变回下载条再消失
      task.isMerging = false;
      task.progress = 1;
      task.error = null;
      await _writeRecord(task);
      // 合并完成即清理分片，避免 TS 切片残留占用体积
      await _cleanupSegments(taskDir);
      _batchDone(task);
      try {
        // 下载完成的提示固定显示在顶部
        App.rootContext.showMessage(
          message: '${t.downloadCompleted}: ${task.title}',
          style: ToastStyle.top,
        );
      } catch (_) {}
    } catch (e, s) {
      // 被暂停/取消时不标记失败
      if (cancelToken.isCancelled) {
        if (_tasks.contains(task) && task.status != DownloadStatus.paused) {
          task.status = DownloadStatus.failed;
          task.error = 'cancelled';
        }
      } else if (_isTransient(e)) {
        // 临时性失败（断线/超时）：自动重新排队续传，避免用户反复手动重试
        final n = (_autoRetryCounts[task.id] ?? 0) + 1;
        if (n <= _maxAutoRetries && _tasks.contains(task)) {
          _autoRetryCounts[task.id] = n;
          _pendingRetryAt[task.id] = DateTime.now().add(
            Duration(seconds: n * 3),
          );
          task.status = DownloadStatus.queued;
          task.error = null;
          task.progress = task.progress.clamp(0.0, 1.0);
          _persist();
          notifyListeners();
          // 指数退避后回到队列（有并发位则自动开始，未占满立即续传）
          unawaited(() async {
            await Future.delayed(Duration(seconds: n * 3));
            if (_tasks.contains(task) && task.status == DownloadStatus.queued) {
              _schedule();
            }
          }());
          Log.warning('DownloadManager', '自动续传 ${task.title} (第$n次)');
          return;
        }
        if (_tasks.contains(task)) {
          task.status = DownloadStatus.failed;
          task.error = e.toString();
        }
        Log.error('DownloadManager', '下载重试失败 ${task.title}: $e\n$s');
        _notifyDownloadFailed(task, e);
      } else {
        Log.error('DownloadManager', '下载失败 ${task.title}: $e\n$s');
        if (_tasks.contains(task)) {
          task.status = DownloadStatus.failed;
          task.error = e.toString();
        }
        _notifyDownloadFailed(task, e);
      }
    } finally {
      _runningIds.remove(task.id);
      _cancelTokens.remove(task.id);
      _clearSpeedSamples(task.id);
      // 结束即清零：否则卡片残留最后一次速度（停滞看门狗只管 downloading 态）
      task.downloadSpeed = 0;
      _persist();
      notifyListeners();
      _syncKeepAlive(force: true);
      _schedule();
    }
  }

  /// 速度停滞看门狗：停住（无数据块）时 _updateDownloadProgress 不会被调用，
  /// 卡片就会一直显示上一次的速度。1s 巡检一次，超过 1.5s 没进展的
  /// downloading 任务速度置 0；无下载任务时自动停表，不空转。
  Timer? _speedTick;

  void _ensureSpeedTick() {
    if (_speedTick != null) return;
    _speedTick = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      var changed = false;
      var anyDownloading = false;
      for (final t in _tasks) {
        if (t.status != DownloadStatus.downloading || t.isMerging) continue;
        anyDownloading = true;
        if (t.downloadSpeed == 0) continue;
        final last = _speedSampleTime[t.id];
        if (last == null || now.difference(last).inMilliseconds > 1500) {
          t.downloadSpeed = 0;
          changed = true;
        }
      }
      if (!anyDownloading) {
        _speedTick?.cancel();
        _speedTick = null;
        return;
      }
      if (changed) notifyListeners();
    });
  }

  /// 全局限流进度通知：半秒内至多 notifyListeners 一次，避免多任务
  /// 并发时频繁重建 UI。
  void _notifyProgress() {
    final now = DateTime.now();
    final last = _lastProgressNotifyAll;
    if (last == null || now.difference(last) >= _progressNotifyInterval) {
      _lastProgressNotifyAll = now;
      notifyListeners();
      return;
    }
    _progressNotifyTimer ??= Timer(_progressNotifyInterval, () {
      _progressNotifyTimer = null;
      _lastProgressNotifyAll = DateTime.now();
      notifyListeners();
    });
  }

  /// 计算并上报下载进度（含速度采样，500ms 间隔平滑）。
  /// 依赖 [DownloadTask.downloadedBytes] 已更新。
  void _updateDownloadProgress(DownloadTask task) {
    _ensureSpeedTick();
    final now = DateTime.now();
    // 快路径：距上次通知不足半秒直接返回（字段已在调用处更新），省去每个
    // 数据块的采样、保活和通知开销。
    final lastNotify = _lastProgressNotify[task.id];
    if (lastNotify != null &&
        now.difference(lastNotify) < _progressNotifyInterval) {
      return;
    }
    _lastProgressNotify[task.id] = now;
    _notifyProgress();
    final lastTime = _speedSampleTime[task.id];
    final lastBytes = _speedSampleBytes[task.id];
    if (lastTime != null && lastBytes != null) {
      final dt = now.difference(lastTime).inMilliseconds;
      final db = task.downloadedBytes - lastBytes;
      if (db < 0 || dt >= 500) {
        task.downloadSpeed = db < 0 ? 0 : db / (dt / 1000);
        _speedSampleTime[task.id] = now;
        _speedSampleBytes[task.id] = task.downloadedBytes;
      }
    } else {
      _speedSampleTime[task.id] = now;
      _speedSampleBytes[task.id] = task.downloadedBytes;
    }
    _syncKeepAlive();
  }

  /// 永久失败时提示原因（签名过期/网络/403 等），便于用户判断
  void _notifyDownloadFailed(DownloadTask task, Object e) {
    _batchFailed(task);
    try {
      // 410 耗尽重试仍失败：链接（签名）已失效，提示重新解析而不是盲重试
      if (e.toString().contains('410')) {
        App.rootContext.showMessage(
          message: '${t.downloadLinkExpired}：${task.title}',
          level: LogLevel.error,
        );
        return;
      }
      var reason = e.toString().replaceFirst('Exception: ', '');
      reason = reason.split('\n').first.trim();
      if (reason.length > 60) reason = '${reason.substring(0, 60)}...';
      App.rootContext.showMessage(
        message: '${t.downloadFailed}: $reason',
        level: LogLevel.error,
      );
    } catch (_) {}
  }

  void _clearSpeedSamples(String id) {
    _speedSampleTime.remove(id);
    _speedSampleBytes.remove(id);
    _lastProgressNotify.remove(id);
  }

  /// 每次请求前用 jar 里最新的 cookie 刷新任务头：
  /// 入队时冻结的 Cookie（会话/签名）可能在排队期间过期，
  /// 第二个任务开始时拿着旧 cookie 就会 403/410，而过会 jar 被播放等
  /// 行为刷新后重试又能下。jar 里有更新的值就覆盖（内存 + 落盘），
  /// 没有则保持原样。与入队时同逻辑（含 Referer 源站兜底）。
  Future<void> _refreshTaskCookie(DownloadTask task) async {
    try {
      final jar = SingleInstanceCookieJar.instance;
      if (jar == null) return;
      final dlUri = Uri.tryParse(task.url);
      if (dlUri == null ||
          dlUri.host.isEmpty ||
          (dlUri.scheme != 'http' && dlUri.scheme != 'https')) {
        return;
      }
      var cookie = await jar.loadForRequestCookieHeader(dlUri);
      if (cookie.isEmpty) {
        final referer = task.headers['Referer'] ?? task.headers['referer'];
        final refUri = referer == null ? null : Uri.tryParse(referer);
        if (refUri != null &&
            refUri.host.isNotEmpty &&
            refUri.host != dlUri.host) {
          cookie = await jar.loadForRequestCookieHeader(refUri);
        }
      }
      if (cookie.isNotEmpty && task.headers['Cookie'] != cookie) {
        task.headers['Cookie'] = cookie;
        _persist();
      }
    } catch (_) {}
  }

  /// 403/429/503 视为被 Cloudflare 拦，转成 [CloudflareException] 交给上层兜底。
  void _throwIfCloudflare(DioException e) {
    final status = e.response?.statusCode;
    if (status == 403 || status == 429 || status == 503) {
      throw CloudflareException(e.requestOptions.uri.toString());
    }
  }

  /// 回退：借本地 m3u8 代理中转。rhttp 直连被 CF 拒的源，播放走
  /// [M3u8ProxyServer] 能过；这里让 ffmpeg 只读本地代理，由代理带任务头拉上游。
  Future<void> _downloadViaFfmpeg(
    DownloadTask task,
    FfmpegCancelToken cancelToken,
    String tmpPath,
  ) async {
    await _refreshTaskCookie(task);
    var input = task.url;
    var headers = task.headers;
    if (task.isHls) {
      input = await M3u8ProxyServer.instance.proxyUrl(task.url, task.headers);
      headers = const {};
    }
    task.progress = 0;
    task.downloadedBytes = 0;
    task.downloadSpeed = 0;
    _clearSpeedSamples(task.id);
    final output = File(tmpPath);
    if (await output.exists()) await output.delete();
    notifyListeners();
    Future<void>? sampling;
    Future<void> sampleOutput() async {
      try {
        if (!await output.exists()) return;
        final bytes = await output.length();
        if (cancelToken.isCancelled || !_tasks.contains(task)) return;
        task.downloadedBytes = bytes;
        if (task.totalBytes > 0) {
          final progress = (bytes / task.totalBytes).clamp(0.0, 0.99);
          if (progress > task.progress) task.progress = progress;
        }
        _updateDownloadProgress(task);
      } on FileSystemException {
        // FFmpeg 初始化输出时，文件可能暂时不可用。
      }
    }

    final timer = Timer.periodic(_progressNotifyInterval, (_) {
      sampling ??= sampleOutput().whenComplete(() => sampling = null);
    });
    try {
      await FfmpegEncoder.download(
        FfmpegDownloadArgs(
          inputUrl: input,
          outputPath: tmpPath,
          headers: headers,
          outputFormat: 'mp4',
          cancelToken: cancelToken,
          onProgress: (progress) {
            if (cancelToken.isCancelled || !_tasks.contains(task)) return;
            if (progress > task.progress) {
              task.progress = progress.clamp(0.0, 0.99);
              _notifyProgress();
            }
          },
        ),
      );
    } finally {
      timer.cancel();
      await sampling;
      await sampleOutput();
    }
  }

  /// 打开写盘 sink：优先后台写盘 isolate，失败则回退 ISOink 直写。
  Future<DownloadSink> _openSink(
    DownloadFileWriter? writer,
    String path, {
    bool append = false,
  }) async {
    if (writer != null) {
      try {
        return await writer.open(path, append: append);
      } catch (_) {}
    }
    return DirectDownloadSink(
      File(path).openWrite(mode: append ? FileMode.append : FileMode.write),
    );
  }

  /// mp4 直链：AppDio（rhttp/reqwest）流式下载（断点续传 + 取消 + 连接中断重试）。
  ///
  /// 用 `extra['httpVersion11']` 强制 HTTP/1.1：部分 CDN（moedet 等）对
  /// reqwest 默认协商出的 HTTP/2 请求返回 400，HTTP/1.1 可正常下载。
  /// 大文件传输中连接被服务端断开较常见，失败后基于已写入字节用 Range 续传。
  Future<void> _downloadDirect(
    DownloadTask task,
    FfmpegCancelToken cancelToken,
    String tmpPath, {
    bool useHttp2 = false,
  }) async {
    final tmp = File(tmpPath);
    const maxAttempts = 5;
    final dio = AppDio();
    // 后台写盘 isolate（不可用则为 null，走直写兜底）
    final writer = await DownloadFileWriter.instance();
    // 410 回退标记：续传 Range 被拒时只回退整段重下一次，
    // 避免死循环删进度
    var retriedFull = false;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (cancelToken.isCancelled) throw FfmpegCancelledException();
      // 排队久了 cookie 可能已过期，每次请求前刷新一次
      await _refreshTaskCookie(task);
      var downloaded = await tmp.exists() ? await tmp.length() : 0;
      task.downloadedBytes = downloaded;
      var received = 0;
      var total = -1;
      // 服务端给出的完整文件大小；-1 表示未知（无法校验完整性）
      var expectedFull = -1;
      var interrupted = false;
      // 把 FfmpegCancelToken 的取消转发给 dio，及时中断正在进行的请求
      final dioCancel = CancelToken();
      final watch = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (cancelToken.isCancelled && !dioCancel.isCancelled) {
          dioCancel.cancel();
        }
      });
      try {
        final headers = <String, dynamic>{
          'User-Agent':
              task.headers['User-Agent'] ??
              task.headers['user-agent'] ??
              _browserUA,
          // 始终带 Range（首次 bytes=0-，续传从已下载处继续）
          'Range': 'bytes=$downloaded-',
          // 绕过网络缓存，避免 Range 与缓存冲突
          'cache-time': 'no',
        };
        task.headers.forEach((k, v) {
          final lk = k.toLowerCase();
          if (lk != 'user-agent' && lk != 'range') {
            headers[k] = v;
          }
        });
        Response<ResponseBody> res;
        try {
          res = await dio.get<ResponseBody>(
            task.url,
            options: Options(
              responseType: ResponseType.stream,
              headers: headers,
              followRedirects: true,
              receiveTimeout: null,
              extra: useHttp2
                  ? {'streaming': true, 'noLog': true}
                  : {'httpVersion11': true, 'streaming': true, 'noLog': true},
            ),
            cancelToken: dioCancel,
          );
        } on DioException catch (e) {
          if (CancelToken.isCancel(e) || cancelToken.isCancelled) {
            throw FfmpegCancelledException();
          }
          // 连接层错误（无 HTTP 响应）：可能是服务器只支持 HTTP/2，
          // 去掉强制 HTTP/1.1 用 HTTP/2 再试一次；有状态码的交给外层处理
          if (e.response?.statusCode != null) rethrow;
          res = await dio.get<ResponseBody>(
            task.url,
            options: Options(
              responseType: ResponseType.stream,
              headers: headers,
              followRedirects: true,
              receiveTimeout: null,
              extra: {'streaming': true, 'noLog': true},
            ),
            cancelToken: dioCancel,
          );
        }
        final status = res.statusCode ?? 0;
        if (status != 200 && status != 206) {
          // 410（签名/续传区间失效）与 429（限流）经常是暂时的：
          // 第一次下没事、第二次 410、过会又能下就是这个特征。
          // 续传请求被拒时先回退整段重试一次；仍失败则退避重试，
          // 耗尽才报链接失效（不再像以前直接判死）
          if ((status == 410 || status == 429) &&
              downloaded > 0 &&
              !retriedFull) {
            retriedFull = true;
            await _deleteQuiet(tmp);
            task.downloadedBytes = 0;
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          if (status == 410 || status == 429) {
            if (attempt >= maxAttempts) throw _DownloadHttpError(status);
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          // 403/503：交给上层兜底，不当作永久失效
          if (status == 403 || status == 503) {
            throw CloudflareException(task.url);
          }
          // 其余 4xx/5xx 不可通过续传/重试恢复，直接失败不重试
          throw _DownloadHttpError(status);
        }
        final contentLength =
            int.tryParse(res.headers.value('content-length') ?? '') ?? -1;
        // 服务端返回的断点区间与本地已下载字节不一致时，续传会让文件错位，
        // 这里清空断点重新下载
        final range = parseDownloadRange(
          status: status,
          contentRange: res.headers.value('content-range'),
          contentLength: contentLength,
        );
        if (range.start > 0 && range.start != downloaded) {
          await _deleteQuiet(tmp);
          downloaded = 0;
          task.downloadedBytes = 0;
          if (attempt >= maxAttempts) {
            throw Exception('下载失败：服务端断点范围异常，请重试');
          }
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        // 服务端忽略 Range 直接返回整段（200）：清空断点文件后重写，
        // 否则会在旧内容后追加造成文件损坏
        if (status == 200 && downloaded > 0) {
          await _deleteQuiet(tmp);
          downloaded = 0;
          task.downloadedBytes = 0;
        }
        expectedFull = range.total > 0
            ? range.total
            : (status == 200 && contentLength > 0 ? contentLength : -1);
        total = contentLength;
        if (expectedFull > 0) {
          task.totalBytes = expectedFull;
        }
        final stream = res.data!.stream;
        final sink = await _openSink(writer, tmpPath, append: true);
        try {
          await for (final chunk in stream.timeout(_kDirectStallTimeout)) {
            if (cancelToken.isCancelled) {
              await sink.close();
              throw FfmpegCancelledException();
            }
            final backpressure = sink.add(chunk);
            received += chunk.length;
            task.downloadedBytes = downloaded + received;
            if (total > 0) {
              task.progress = ((downloaded + received) / (downloaded + total))
                  .clamp(0.0, 1.0);
            }
            _updateDownloadProgress(task);
            if (backpressure != null) await backpressure;
          }
          await sink.flush();
          await sink.close();
        } catch (e) {
          try {
            await sink.close();
          } catch (_) {}
          // 取消不重试；其余（连接中断等）走断点续传
          if (cancelToken.isCancelled || e is FfmpegCancelledException) {
            rethrow;
          }
          // 永久性 HTTP 错误（403/404/410 地址失效）不当作断线重试
          if (e is _DownloadHttpError) rethrow;
          // 连接停滞：主动取消本次请求（释放连接），基于已写入字节续传
          if (e is TimeoutException && !dioCancel.isCancelled) {
            dioCancel.cancel();
          }
          interrupted = true;
        }
        if (interrupted) {
          if (attempt >= maxAttempts) {
            throw Exception('下载中断：连接多次断开，请重试');
          }
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        if (cancelToken.isCancelled) throw FfmpegCancelledException();
        // 流「正常结束」也可能是服务端/代理提前断流（不抛异常），
        // 必须核对落盘字节数：残缺文件继续断点续传，不能当成下载完成
        final written = await tmp.exists() ? await tmp.length() : 0;
        task.downloadedBytes = written;
        if (expectedFull > 0 && written < expectedFull) {
          Log.warning(
            'DownloadManager',
            '下载不完整 ${task.title}: $written/$expectedFull，继续续传',
          );
          if (attempt >= maxAttempts) {
            throw Exception('下载中断：文件不完整（$written/$expectedFull），请重试');
          }
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        if (written > 0) task.totalBytes = written;
        task.progress = 1;
        break;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e) || cancelToken.isCancelled) {
          throw FfmpegCancelledException();
        }
        final code = e.response?.statusCode;
        if (code != null && code != 200 && code != 206) {
          // 与上面同理：410/429 可重试，耗尽才判死
          if ((code == 410 || code == 429) && attempt < maxAttempts) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw _DownloadHttpError(code);
        }
        if (attempt >= maxAttempts) {
          throw Exception('下载中断：连接多次断开，请重试');
        }
        await Future.delayed(Duration(seconds: attempt));
        continue;
      } finally {
        watch.cancel();
      }
    }
    notifyListeners();
  }

  /// m3u8：dio 并发下载分片（已下载跳过实现断点），ffmpeg 合并转 mp4
  Future<void> _downloadHls(
    DownloadTask task,
    FfmpegCancelToken cancelToken,
    String taskDir,
    String tmpPath, {
    bool useHttp2 = false,
  }) async {
    final dio = AppDio();
    // 后台写盘 isolate（分片落盘同样移出 UI 线程；不可用则为 null 直写兜底）
    final writer = await DownloadFileWriter.instance();
    final segDir = p.join(taskDir, 'segments');
    await Directory(segDir).create(recursive: true);
    // m3u8 解析与分片同样用任务头：先刷新过期 cookie
    await _refreshTaskCookie(task);

    // 断点续传：已有分片字节计入已下载（避免重复统计）。
    // 上千分片逐个 await File.length() 会霸占 UI isolate，改到后台 isolate 统计
    final existingBytes = await Isolate.run(_segDirBytesRunner(segDir));
    task.downloadedBytes = existingBytes;

    // 1. 解析 m3u8（含变体选择）
    final segUrls = await _resolveHlsSegments(dio, task, useHttp2: useHttp2);
    task.segTotal = segUrls.length;
    task.segDone = 0;

    // 2. 并发下载分片（固定 worker 池；已存在的跳过实现断点）。相比「每分片一个
    //    Future + 信号量」，worker 池不会一次性创建上千个 Future/闭包。
    final total = segUrls.length;
    final segPaths = List<String>.filled(total, '');
    var completed = 0;
    final errors = <String>[];
    var nextIndex = 0;
    final workerCount = total == 0 ? 0 : _segmentConcurrent.clamp(1, total);
    Future<void> worker() async {
      // 取消/无更多分片即退出；每个 worker 串行领取下一个下标
      while (!cancelToken.isCancelled) {
        final i = nextIndex++;
        if (i >= total) return;
        try {
          final segFile = File(
            p.join(segDir, 'seg_${i.toString().padLeft(6, '0')}.ts'),
          );
          if (await segFile.exists() && await segFile.length() > 0) {
            segPaths[i] = segFile.path;
            completed++;
          } else {
            final partial = File('${segFile.path}.part');
            if (await segFile.exists()) await _deleteQuiet(segFile);
            // 分片下载带重试：签名 CDN（如 beeg）偶发 403/断连，重试可缓解。
            // 部分 CDN 会把分片连接挂住（不发数据也不断开），rhttp 不认 dio 的
            // receiveTimeout；对「请求」和「取块」都套 stall 超时主动判停并重试。
            var received = 0;
            for (var attempt = 0; attempt < 3; attempt++) {
              if (attempt > 0) {
                await Future.delayed(Duration(seconds: attempt));
              }
              if (cancelToken.isCancelled) throw FfmpegCancelledException();
              final segCancel = CancelToken();
              // 全局暂停/取消转发到本段请求，保证能及时中断
              final forward = Timer.periodic(
                const Duration(milliseconds: 300),
                (_) {
                  if (cancelToken.isCancelled && !segCancel.isCancelled) {
                    segCancel.cancel();
                  }
                },
              );
              var got = 0;
              var accepted = false;
              try {
                final resp = await dio
                    .get<ResponseBody>(
                      segUrls[i],
                      options: Options(
                        headers: task.headers,
                        responseType: ResponseType.stream,
                        // 兼容其它 adapter；rhttp 实际靠下面的 .timeout 兜底
                        sendTimeout: const Duration(seconds: 30),
                        receiveTimeout: const Duration(seconds: 30),
                        // noLog：分片动辄上千，不逐条记录（失败由下载器统一汇总上报）
                        extra: useHttp2
                            ? const {'noLog': true}
                            : const {'httpVersion11': true, 'noLog': true},
                      ),
                      cancelToken: segCancel,
                    )
                    .timeout(_kHlsStallTimeout);
                final expect =
                    int.tryParse(resp.headers.value('content-length') ?? '') ??
                    -1;
                final sink = await _openSink(
                  writer,
                  partial.path,
                  append: false,
                );
                try {
                  await for (final chunk in resp.data!.stream.timeout(
                    _kHlsStallTimeout,
                  )) {
                    if (cancelToken.isCancelled) {
                      throw FfmpegCancelledException();
                    }
                    final backpressure = sink.add(chunk);
                    got += chunk.length;
                    task.downloadedBytes += chunk.length;
                    _updateDownloadProgress(task);
                    if (backpressure != null) await backpressure;
                  }
                  await sink.flush();
                } catch (_) {
                  try {
                    await sink.close();
                  } catch (_) {}
                  rethrow;
                }
                await sink.close();
                // dio 流提前断开不抛错，靠长度校验发现，
                // 否则合并出的视频会在断点处卡住
                if (got == 0) continue;
                if (expect > 0 && got < expect) {
                  if (attempt >= 2) {
                    throw Exception('分片 $i 不完整（$got/$expect）');
                  }
                  continue;
                }
                // 落盘校验：close 后文件元数据即准确，对不上说明写入丢了
                //（无 fsync，崩溃/断电可能丢尾），重试而非将坏片送去合并
                if (await partial.length() != got) continue;
                await partial.rename(segFile.path);
                received = got;
                accepted = true;
                break;
              } on TimeoutException {
                segCancel.cancel();
                if (cancelToken.isCancelled) throw FfmpegCancelledException();
                // 停滞：前两次直接重试，最后一次抛「中断」类错误，
                // 让上层 _runTask 自动续传（重跑只会补缺失分片）
                if (attempt >= 2) {
                  throw Exception('下载中断：分片 $i 连接停滞超时');
                }
              } catch (e) {
                if (cancelToken.isCancelled) throw FfmpegCancelledException();
                if (e is FfmpegCancelledException) rethrow;
                if (e is DioException) _throwIfCloudflare(e);
                if (attempt >= 2) rethrow;
              } finally {
                forward.cancel();
                if (!accepted) {
                  task.downloadedBytes -= got;
                  await _deleteQuiet(partial);
                  _updateDownloadProgress(task);
                }
              }
            }
            if (received <= 0) {
              throw Exception('分片 $i 下载为空');
            }
            segPaths[i] = segFile.path;
            completed++;
          }
          task.progress = segUrls.isEmpty ? 1 : completed / segUrls.length;
          task.segDone = completed;
          _updateDownloadProgress(task);
        } catch (e) {
          if (e is CloudflareException) rethrow;
          errors.add('分片 $i: $e');
        }
      }
    }

    if (workerCount > 0) {
      await Future.wait(List.generate(workerCount, (_) => worker()));
    }

    if (cancelToken.isCancelled) throw FfmpegCancelledException();
    if (errors.isNotEmpty) {
      // 完整列出每个失败分片的编号与原因，便于定位（不省略、不截断）
      throw Exception('部分分片下载失败（${errors.length} 个）：\n${errors.join('\n')}');
    }
    // 下载计数不一致时拒绝合并，避免生成缺片的视频并显示成功。
    if (completed != segUrls.length) {
      throw Exception('分片计数异常（$completed/${segUrls.length}），请重试');
    }

    // 3. ffmpeg 合并 ts → mp4（合并进度实时反映到 task.progress）。
    // 成功时保持 isMerging=true 直到外层落盘+记录+清理全部完成、
    // 一次性切 completed：否则 finally 先刷一次“非合并下载态”，
    // 卡片会“合并条→下载条→消失”闪一下（中间的文件操作要几秒）
    task.isMerging = true;
    task.progress = 0;
    task.error = null;
    notifyListeners();
    try {
      await _mergeTsWithProgress(
        task: task,
        tsPaths: segPaths.where((p) => p.isNotEmpty).toList(),
        outputPath: tmpPath,
        cancelToken: cancelToken,
      );
    } catch (_) {
      task.isMerging = false;
      notifyListeners();
      rethrow;
    }
  }

  /// 合并 TS → MP4 进度：ffmpeg concat -c copy 不提供 time= 进度（totalMs=0），
  /// 这里按「输出文件大小 / 输入分片总大小」轮询估算，避免进度只有 0/100。
  Future<void> _mergeTsWithProgress({
    required DownloadTask task,
    required List<String> tsPaths,
    required String outputPath,
    FfmpegCancelToken? cancelToken,
  }) async {
    // 分片可能上千：逐个 await length() 会卡 UI，改到后台 isolate 统计
    final expected = await Isolate.run(_filesTotalBytesRunner(tsPaths));
    Timer? timer;
    double last = 0;
    if (expected > 0) {
      timer = Timer.periodic(const Duration(milliseconds: 250), (_) async {
        try {
          final f = File(outputPath);
          if (!await f.exists()) return;
          final size = await f.length();
          final double p = (size / expected).clamp(0.0, 1.0).toDouble();
          if (p > last + 0.01) {
            last = p;
            task.progress = p;
            _notifyProgress();
          }
        } catch (_) {}
      });
    }
    try {
      await FfmpegEncoder.mergeTs(
        tsPaths: tsPaths,
        outputPath: outputPath,
        cancelToken: cancelToken,
      );
    } finally {
      timer?.cancel();
    }
  }

  /// 分片下载并发数（设置可调）
  int get _segmentConcurrent {
    final v = appdata.implicitData['downloadSegmentConcurrent'] as int?;
    return (v != null && v > 0) ? v : 4;
  }

  /// HLS 分片停滞超时：请求或取块超过该时长即判挂死并重试（rhttp 不认
  /// dio 的 receiveTimeout，只能主动判停）。
  static const Duration _kHlsStallTimeout = Duration(seconds: 20);

  /// 直链下载停滞超时：两块数据之间超过该时长即判为断流，走 Range 续传。
  static const Duration _kDirectStallTimeout = Duration(seconds: 30);

  /// 解析 m3u8：选择最高码率变体，返回分片 URL 列表
  Future<List<String>> _resolveHlsSegments(
    Dio dio,
    DownloadTask task, {
    bool useHttp2 = false,
  }) async {
    String content;
    String targetUrl = task.url;
    final Map<String, dynamic> versionExtra = useHttp2
        ? const {'noLog': true}
        : const {'httpVersion11': true, 'noLog': true};
    Response<String> root;
    try {
      root = await dio.get<String>(
        task.url,
        options: Options(
          headers: task.headers,
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          extra: versionExtra,
        ),
      );
    } on DioException catch (e) {
      _throwIfCloudflare(e);
      rethrow;
    }
    content = root.data ?? '';

    if (content.contains('#EXT-X-STREAM-INF')) {
      final base = _baseOf(targetUrl);
      String? bestVariant;
      var bestBandwidth = -1;
      final lines = content.split('\n');
      for (var i = 0; i < lines.length - 1; i++) {
        final l = lines[i].trim();
        if (l.startsWith('#EXT-X-STREAM-INF')) {
          final m = RegExp(r'BANDWIDTH=(\d+)').firstMatch(l);
          final bw = m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
          final next = lines[i + 1].trim();
          if (next.isNotEmpty && !next.startsWith('#') && bw > bestBandwidth) {
            bestBandwidth = bw;
            bestVariant = next.startsWith('http') ? next : '$base$next';
          }
        }
      }
      if (bestVariant != null) {
        targetUrl = bestVariant;
        Response<String> v;
        try {
          v = await dio.get<String>(
            targetUrl,
            options: Options(
              headers: task.headers,
              responseType: ResponseType.plain,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 15),
              extra: versionExtra,
            ),
          );
        } on DioException catch (e) {
          _throwIfCloudflare(e);
          rethrow;
        }
        content = v.data ?? '';
      }
    }

    // 播放列表被截断时不能直接按现有分片下载，否则合并出的视频中途截断
    if (isTruncatedHlsPlaylist(content)) {
      throw Exception('m3u8 播放列表下载中断（缺少 #EXT-X-ENDLIST），请重试');
    }

    final segBase = _baseOf(targetUrl);
    final segs = <String>[];
    // fMP4（av1/hevc）流的 init segment：由 #EXT-X-MAP 提供 moov，
    // 必须放在分片最前面，否则合并时缺初始化信息无法解析
    final mapMatch = RegExp(r'#EXT-X-MAP:URI="([^"]+)"').firstMatch(content);
    if (mapMatch != null) {
      final initUri = mapMatch.group(1)!;
      segs.add(initUri.startsWith('http') ? initUri : '$segBase$initUri');
    }
    for (final line in content.split('\n')) {
      final l = line.trim();
      if (l.isNotEmpty && !l.startsWith('#')) {
        segs.add(l.startsWith('http') ? l : '$segBase$l');
      }
    }
    if (segs.isEmpty) throw Exception('m3u8 没有可用分片');
    return segs;
  }

  static String _baseOf(String url) {
    final idx = url.lastIndexOf('/');
    return idx >= 0 ? url.substring(0, idx + 1) : '$url/';
  }

  /// 强行合并已成功下载的分片（跳过失败分片）。
  /// 仅适用于 m3u8 任务：缺失分片不参与合并，合并后可播放但对应内容缺失。
  /// 合并进度实时写入 task.progress（卡片进度条显示，不弹窗）。
  Future<void> forceMerge(String id) async {
    final task = _tasks.where((e) => e.id == id).firstOrNull;
    if (task == null || task.status != DownloadStatus.failed) return;
    if (!task.isHls) {
      App.rootContext.showMessage(message: t.downloadFailed);
      return;
    }
    final taskDir = _taskDirPath(task);
    final segDir = p.join(taskDir, 'segments');
    if (!await Directory(segDir).exists()) {
      App.rootContext.showMessage(message: t.downloadFailed);
      return;
    }
    final segPaths = await Isolate.run(_segmentPathsRunner(segDir));
    if (segPaths.isEmpty) {
      App.rootContext.showMessage(message: t.downloadFailed);
      return;
    }
    final tmpPath = p.join(taskDir, 'video.mp4');
    final finalPath = p.join(taskDir, '${_fileBaseName(task)}.mp4');
    final cancelToken = FfmpegCancelToken();
    _cancelTokens[id] = cancelToken;
    // 进入合并中状态：卡片进度条驱动显示
    task.status = DownloadStatus.downloading;
    task.isMerging = true;
    task.progress = 0;
    task.error = null;
    _persist();
    notifyListeners();
    try {
      await _mergeTsWithProgress(
        task: task,
        tsPaths: segPaths,
        outputPath: tmpPath,
        cancelToken: cancelToken,
      );
      final tmp = File(tmpPath);
      if (!await tmp.exists() || await tmp.length() == 0) {
        throw Exception('合并结果为空');
      }
      final dst = File(finalPath);
      if (await dst.exists()) await _deleteQuiet(dst);
      await tmp.rename(finalPath);
      task.filePath = finalPath;
      task.totalBytes = await File(finalPath).length();
      task.status = DownloadStatus.completed;
      task.isMerging = false;
      task.progress = 1;
      task.error = null;
      await _writeRecord(task);
      // 强合完成后同样清理分片
      await _cleanupSegments(taskDir);
      _batchDone(task);
      _persist();
      notifyListeners();
      try {
        App.rootContext.showMessage(
          message: '${t.downloadCompleted}: ${task.title}',
          style: ToastStyle.top,
        );
      } catch (_) {}
    } catch (e, s) {
      Log.error('DownloadManager.forceMerge', '$e\n$s');
      // 合并失败/取消：回到 failed 状态（保留分片供重试），清理半成品临时文件
      task.status = DownloadStatus.failed;
      task.isMerging = false;
      task.error = e.toString();
      _batchFailed(task);
      await _deleteQuiet(File(tmpPath));
      _persist();
      notifyListeners();
      if (!cancelToken.isCancelled) {
        try {
          App.rootContext.showMessage(
            message: '${t.downloadFailed}: $e',
            level: LogLevel.error,
          );
        } catch (_) {}
      }
    } finally {
      _cancelTokens.remove(id);
    }
  }

  /// 暂停下载（终止 ffmpeg 进程；恢复时从头重新下载）
  Future<void> pause(String id) async {
    final t = _tasks.where((e) => e.id == id).firstOrNull;
    if (t == null || t.status != DownloadStatus.downloading) return;
    _pendingRetryAt.remove(id);
    _cancelTokens[id]?.cancel();
    t.status = DownloadStatus.paused;
    t.error = null;
    t.downloadSpeed = 0;
    _persist();
    notifyListeners();
  }

  /// 继续下载（重新排队；paused 与 failed 均可重试）
  Future<void> resume(String id) async {
    final t = _tasks.where((e) => e.id == id).firstOrNull;
    if (t == null ||
        (t.status != DownloadStatus.paused &&
            t.status != DownloadStatus.failed)) {
      return;
    }
    t.status = DownloadStatus.queued;
    t.error = null;
    _pendingRetryAt.remove(t.id);
    _prioritizeQueued(t);
    _persist();
    notifyListeners();
    _schedule();
  }

  /// 取消下载（终止进程并删除任务与临时文件）
  Future<void> cancel(String id) async {
    _cancelTokens[id]?.cancel();
    await delete(id);
  }

  /// 重新下载失败的（failed → queued）
  Future<void> retryFailed() async {
    var changed = false;
    for (final t in _tasks) {
      if (t.status == DownloadStatus.failed) {
        t.status = DownloadStatus.queued;
        t.error = null;
        _batchUncount(t);
        changed = true;
      }
    }
    if (!changed) return;
    _persist();
    notifyListeners();
    _schedule();
  }

  /// 全部开始（暂停的继续排队）
  Future<void> resumeAll() async {
    var changed = false;
    for (final t in _tasks) {
      if (t.status == DownloadStatus.paused) {
        t.status = DownloadStatus.queued;
        t.error = null;
        changed = true;
      }
    }
    if (!changed) return;
    _persist();
    notifyListeners();
    _schedule();
  }

  /// 全部暂停（进行中/排队中的任务暂停）
  Future<void> pauseAll() async {
    var changed = false;
    for (final t in _tasks) {
      if (t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.queued) {
        _cancelTokens[t.id]?.cancel();
        t.status = DownloadStatus.paused;
        t.error = null;
        changed = true;
      }
    }
    if (!changed) return;
    _persist();
    notifyListeners();
  }

  /// 全部取消（删除所有未完成任务，含文件；保留已完成）
  Future<void> cancelAll() async {
    final ids = _tasks
        .where((t) => t.status != DownloadStatus.completed)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      _cancelTokens[id]?.cancel();
      await delete(id);
    }
  }

  /// 删除一条下载记录（删文件 + 对应任务 + 记录）
  Future<void> deleteRecord(String filePath) async {
    final t = _tasks.where((e) => e.filePath == filePath).firstOrNull;
    if (t != null) {
      await cancel(t.id);
      return;
    }
    await _deleteQuiet(File(filePath));
    await DownloadDatabase.instance.deleteRecordByPath(filePath);
    await _refreshDownloadedKeys();
  }

  /// 已完成任务占用的总字节数
  Future<int> get totalDownloadedBytes async {
    var total = 0;
    for (final t in _tasks) {
      if (t.filePath != null) {
        final f = File(t.filePath!);
        if (await f.exists()) {
          total += await f.length();
        }
      }
    }
    return total;
  }

  /// 删除任务（同时清理已下载文件/分片/临时文件）
  Future<void> delete(String id) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks.removeAt(idx);
    _pendingRetryAt.remove(id);
    _batchRemove(t);
    if (t.filePath != null) {
      await _deleteQuiet(File(t.filePath!));
    }
    // 用与创建一致的目录路径（含分组），否则删不到残留目录
    final dir = Directory(_taskDirPath(t));
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
    _persist();
    notifyListeners();
    // 同步删除下载记录，否则详情页仍显示"已下载"
    await _removeRecord(t);
  }

  /// 从下载记录中移除某任务的记录
  Future<void> _removeRecord(DownloadTask task) async {
    if (task.animeId == null && task.sourceKey == null) return;
    try {
      await DownloadDatabase.instance.deleteRecordByEpisode(
        animeId: task.animeId,
        episode: task.episode,
        sourceKey: task.sourceKey,
      );
    } catch (e, s) {
      Log.error('DownloadManager.removeRecord', '$e\n$s');
    }
    await _refreshDownloadedKeys();
  }

  /// 清空已完成/失败任务
  Future<void> clearFinished() async {
    final finished = _tasks.where((t) => !t.isActive).map((t) => t.id).toList();
    for (final id in finished) {
      await delete(id);
    }
  }

  /// 静默删除文件（忽略不存在/权限错误）
  static Future<void> _deleteQuiet(File file) async {
    try {
      await file.delete();
    } catch (_) {}
  }

  /// 删除任务目录下的分片目录（segments），合并完成后清理，避免 TS 切片残留
  static Future<void> _cleanupSegments(String taskDir) async {
    final segDir = Directory(p.join(taskDir, 'segments'));
    try {
      if (await segDir.exists()) {
        await segDir.delete(recursive: true);
      }
    } catch (_) {}
    // 顺带清理已重命名的临时文件（video.mp4 已被 rename，若有残留则删除）
    await _deleteQuiet(File(p.join(taskDir, 'video.mp4')));
  }

  static String _sanitize(String name) => sanitizeFileName(name);

  /// 净化单个文件名（不含扩展名时也可）。
  ///
  /// Windows 保留名检查要连扩展名一起看：`CON`/`CON.mp4` 都无法创建，
  /// 而调用方普遍是「先净化基名、再拼 `.mp4`」，只在净化基名时检查会漏掉。
  static String sanitizeFileName(String name, {String fallback = 'video'}) {
    var cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    // Windows：尾点尾空格非法，直接砍掉
    cleaned = _trimTrailingDotsAndSpaces(cleaned);
    if (cleaned.isEmpty) return fallback;
    cleaned = _escapeReservedName(cleaned);
    // 按 UTF-8 字节截断到 200（ext4 上限 255 字节，留分组/_id 后缀余量），
    // 且不在代理对/字符中间切断（此前 substring 按 UTF-16 码元）
    final bytes = utf8.encode(cleaned);
    if (bytes.length > 200) {
      final buf = StringBuffer();
      var len = 0;
      for (final r in cleaned.runes) {
        final rl = utf8.encode(String.fromCharCode(r)).length;
        if (len + rl > 200) break;
        buf.writeCharCode(r);
        len += rl;
      }
      cleaned = buf.toString();
      if (cleaned.isEmpty) return fallback;
    } else if (cleaned.length > 100) {
      // 纯 ASCII 长名同样收敛到 100 字符（与此前行为一致）
      cleaned = cleaned.substring(0, 100);
    }
    return _escapeReservedName(cleaned);
  }

  static String _trimTrailingDotsAndSpaces(String value) {
    var out = value;
    while (out.endsWith('.') || out.endsWith(' ')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// Windows 保留名：`CON` / `CON.mp4` / `con.txt` 都无法创建。
  static String _escapeReservedName(String name) {
    final dot = name.indexOf('.');
    final stem = (dot < 0 ? name : name.substring(0, dot)).toUpperCase();
    if (dot >= 0 && name.substring(dot).trim().isEmpty) return name;
    if (_windowsReservedNames.contains(stem)) return '_$name';
    return name;
  }

  static const _windowsReservedNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };

  /// 分组名按段净化：分组支持 `/` 子层级，只能净化每一段；
  /// `.`/`..`/空段丢弃（防 `../` 穿越），非法字符规则与 [_sanitize] 一致
  static String sanitizeGroupName(String name) {
    final segs = <String>[];
    for (var s in name.split('/')) {
      var out = s.replaceAll(RegExp(r'[\\:*?"<>|\x00-\x1F]'), '_').trim();
      out = _trimTrailingDotsAndSpaces(out);
      // `.` / `..` / 空段直接丢弃：这是防止 `../` 目录穿越的关键
      if (out.isEmpty || out == '.' || out == '..') continue;
      out = _escapeReservedName(out);
      segs.add(out);
    }
    return segs.join('/');
  }

  /// 每源标题格式：源配置覆盖 → 全局默认 → 内置默认
  String _formatFor(String? sourceKey) {
    final per =
        (appdata.implicitData['downloadTitleFormats'] as Map?)?[sourceKey];
    if (per is String && per.isNotEmpty) return per;
    final global = appdata.implicitData['downloadTitleFormat'] as String?;
    if (global != null && global.isNotEmpty) return global;
    return '{title} {episode}';
  }

  /// 按标题格式模板生成文件名基名（不含唯一 id 后缀）
  String _fileBaseName(DownloadTask task) {
    final format = _formatFor(task.sourceKey);
    // “不使用集标题”：直接不在文件名中使用集标题（含集号），不做额外检测
    final ignoreTitle =
        appdata.implicitData['downloadIgnoreEpisodeTitle'] == true;
    final episodeText = ignoreTitle ? '' : (task.episode ?? '');
    var name = format
        .replaceAll('{title}', task.animeTitle ?? task.title)
        .replaceAll('{episode}', episodeText)
        .replaceAll('{author}', task.author ?? '')
        .replaceAll('{resolution}', task.resolution ?? '')
        .replaceAll('{source}', task.sourceKey ?? '')
        .replaceAll('{year}', DateTime.now().year.toString())
        .trim();
    name = _sanitize(name);
    if (name.isEmpty) return 'video';
    return name;
  }

  /// 任务目录名（含唯一 id，保证同名任务隔离）
  String _safeTaskName(DownloadTask task) =>
      '${_fileBaseName(task)}_${task.id}'.replaceAll(' ', '_');

  /// 下载记录：完成时写入 download_record（按文件路径去重）
  Future<void> _writeRecord(DownloadTask task) async {
    if (task.filePath == null) return;
    if (task.animeId == null && task.sourceKey == null) return;
    // 只按文件路径去重：同一集名（重名集/系列同名条目）下载到不同文件时
    // 各自的记录都要保留，不能按 (animeId, episode, sourceKey) 互相覆盖
    try {
      await DownloadDatabase.instance.upsertRecord({
        'animeId': task.animeId,
        'sourceKey': task.sourceKey,
        'title': task.title,
        'episode': task.episode,
        'episodeRaw': task.episodeRaw,
        'resolution': task.resolution,
        'group': task.group,
        'filePath': task.filePath,
        'totalBytes': task.totalBytes,
        'time': DateTime.now().toIso8601String(),
      });
    } catch (e, s) {
      Log.error('DownloadManager.record', '$e\n$s');
    }
    await _refreshDownloadedKeys();
  }

  /// 查询某番剧的下载记录（按 animeId + sourceKey）
  static Future<List<Map<String, dynamic>>> recordsFor(
    String animeId,
    String sourceKey,
  ) async {
    try {
      final list = await DownloadDatabase.instance.recordsForAnime(animeId);
      final results = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e['sourceKey'] != sourceKey) continue;
        // 文件已不存在的记录视为已删除，不返回（详情页"已下载"据此判断）
        final fp = e['filePath'] as String?;
        if (fp == null || fp.isEmpty) continue;
        if (!await File(fp).exists()) continue;
        results.add(e);
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 某源下载记录里的 `animeId|episode` → 文件路径（同源）。
  /// [requireExisting] 为 true 时只保留文件仍存在的记录（供本地播放）；
  /// 为 false 时只看记录（供「已下载」标记，文件被删/移动后仍命中）。
  /// 一条记录登记两个键（规则套用后名 + 原始名）：规则开关/手动改名后
  /// 任意一边都能命中，不再因改名误判未下载而重复下载。
  static Future<Map<String, String>> _downloadedFilesFor(
    String sourceKey, {
    required bool requireExisting,
  }) async {
    try {
      final list = await DownloadDatabase.instance.recordsForSource(sourceKey);
      final out = <String, String>{};
      for (final e in list) {
        final fp = e['filePath'] as String?;
        if (fp == null || fp.isEmpty) continue;
        // 同名集可能有多份（不同标题/文件）：保留最新的一条（记录为倒序）
        if (requireExisting && !await File(fp).exists()) continue;
        final animeId = e['animeId'];
        for (final ep in {e['episode'], e['episodeRaw']}) {
          if (ep == null || (ep as String).isEmpty) continue;
          out.putIfAbsent('$animeId|$ep', () => fp);
        }
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  /// 已下载且文件仍存在的 `animeId|episode` → 本地文件路径（同源）。
  /// 供详情页/下载面板播放本地文件；文件已删除的记录不返回。
  static Future<Map<String, String>> downloadedFilesFor(String sourceKey) =>
      _downloadedFilesFor(sourceKey, requireExisting: true);

  /// 已下载的 `animeId|episode` 集合（同源；只看下载记录，不校验文件是否还在）。
  /// 与卡片「已下载」角标口径一致：文件被删/移动后仍标记已下载，
  /// 避免用户以为没下过而重复下载。供详情页剧集列表/下载选择器标记用。
  static Future<Set<String>> downloadedEpisodeKeys(String sourceKey) async =>
      (await _downloadedFilesFor(
        sourceKey,
        requireExisting: false,
      )).keys.toSet();

  /// 查询全部下载记录（含文件已丢失的，供"下载记录"页标记"已删除"）
  static Future<List<Map<String, dynamic>>> allRecords() async {
    try {
      return await DownloadDatabase.instance.allRecords();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() {
    final jsons = _tasks.map((t) => jsonEncode(t.toJson())).toList();
    _persistChain = _persistChain
        .then((_) => DownloadDatabase.instance.saveTaskJson(jsons))
        .catchError((_) {});
    return _persistChain;
  }

  // ── 分组（= 下载目录）────────────────────────

  static const String groupsKey = 'downloadGroups';

  /// 子组分隔符：分组名用路径形式（`父/子`），磁盘上即嵌套目录
  static const String groupSeparator = '/';

  /// 是否是子组（含分隔符）
  static bool isSubGroup(String name) => name.contains(groupSeparator);

  /// 拼出 [parent] 下的 [leaf]；[parent] 为空时即顶层
  static String childName(String parent, String leaf) =>
      parent.isEmpty ? leaf : '$parent$groupSeparator$leaf';

  /// 顶层分组（不含子组），保持登记顺序
  static List<String> rootGroups() =>
      groups().where((g) => !isSubGroup(g)).toList();

  /// [parent] 的直接子分组，保持登记顺序
  static List<String> subGroupsOf(String parent) {
    final prefix = '$parent$groupSeparator';
    return groups().where((g) {
      if (!g.startsWith(prefix)) return false;
      return !g.substring(prefix.length).contains(groupSeparator);
    }).toList();
  }

  static bool hasSubGroups(String parent) => subGroupsOf(parent).isNotEmpty;

  /// 层级顺序的扁平列表：每个顶层分组紧跟其直接子组（登记顺序），
  /// 供分组列表/选择器统一展示（父组始终在子组上方）。
  static List<String> hierarchicalGroups() {
    final out = <String>[];
    for (final g in rootGroups()) {
      out.add(g);
      out.addAll(subGroupsOf(g));
    }
    for (final g in groups()) {
      if (!out.contains(g)) out.add(g);
    }
    return out;
  }

  /// 分组名的最后一段（子组对外的显示名）
  static String leafOf(String name) {
    final i = name.lastIndexOf(groupSeparator);
    return i < 0 ? name : name.substring(i + 1);
  }

  /// 分组及其所有子孙分组
  static List<String> groupWithDescendants(String name) {
    final prefix = '$name$groupSeparator';
    return groups().where((g) => g == name || g.startsWith(prefix)).toList();
  }

  /// 任务 id 自增序号：避免「同一毫秒 + 同一 URL」时 id 冲突
  /// （系列里同名条目并发下载会因此互相覆盖）
  static int _taskIdSeq = 0;

  static List<String> groups() {
    final raw = appdata.implicitData[groupsKey];
    if (raw is List) return raw.whereType<String>().toList();
    return [];
  }

  static void _saveGroups(List<String> list) {
    appdata.implicitData[groupsKey] = list;
    appdata.writeImplicitData();
  }

  /// 新建分组：登记名称并创建目录
  static Future<void> createGroup(String name) async {
    // 入口即净化：`../` 穿越、非法字符、保留名在此统一处理
    final g = sanitizeGroupName(name.trim());
    if (g.isEmpty) return;
    final list = groups();
    if (!list.contains(g)) {
      list.add(g);
      _saveGroups(list);
    }
    await Directory(groupDir(g)).create(recursive: true);
  }

  /// 调整分组顺序（[groups] 的顺序即显示顺序）；
  /// [newIndex] 为移除后的目标位置（与 ReorderableListView.onReorderItem 一致）
  static void reorderGroups(int oldIndex, int newIndex) {
    final list = groups();
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), item);
    _saveGroups(list);
  }

  /// 按给定顺序保存分组（用于带子组的层级列表拖拽后回写）
  static void setGroupOrder(List<String> ordered) {
    final known = groups();
    final out = <String>[];
    for (final g in ordered) {
      if (known.contains(g) && !out.contains(g)) out.add(g);
    }
    for (final g in known) {
      if (!out.contains(g)) out.add(g);
    }
    _saveGroups(out);
  }

  /// 重命名分组：重命名目录 + 更新任务/记录；子组（`from/xxx`）一并跟着改名
  Future<void> renameGroup(String from, String to) async {
    final name = sanitizeGroupName(to.trim());
    if (from == name || name.isEmpty) return;
    final originalGroups = List<String>.from(groups());
    // 前缀映射：from → name，from/子 → name/子
    final mapping = <String, String>{
      for (final g in groupWithDescendants(from))
        g: g == from ? name : '$name${g.substring(from.length)}',
    };
    final list = groups();
    final idx = list.indexOf(from);
    if (idx >= 0) {
      list[idx] = name;
    } else {
      list.add(name);
    }
    for (final g in mapping.keys) {
      if (g == from) continue;
      final i = list.indexOf(g);
      if (i >= 0) list[i] = mapping[g]!;
    }
    final dedup = <String>[];
    for (final g in list) {
      if (!dedup.contains(g)) dedup.add(g);
    }
    _saveGroups(dedup);

    final oldDir = Directory(groupDir(from));
    final newDir = Directory(groupDir(name));
    if (await oldDir.exists()) {
      try {
        await newDir.parent.create(recursive: true);
        await oldDir.rename(newDir.path);
      } catch (e) {
        Log.error('DownloadManager.renameGroup', '重命名目录失败: $e');
        _saveGroups(originalGroups);
        return;
      }
    }
    for (final t in _tasks) {
      final m = mapping[t.group];
      if (m != null) t.group = m;
    }
    _persist();
    await _rewriteRecordGroups(mapping);
    notifyListeners();
  }

  /// 迁移分组到 [newParent] 下（[newParent] 为空 = 移到顶层）。
  /// 返回新分组名；冲突/无变化时返回 null。
  Future<String?> migrateGroup(String from, String? newParent) async {
    final parent = (newParent ?? '').trim();
    if (parent == from || parent.startsWith('$from$groupSeparator')) {
      return null; // 不能迁移到自己或自己的子组下
    }
    // 只支持两层：父组 / 子组，子组下不再嵌套
    if (isSubGroup(parent)) return null;
    final target = childName(parent, leafOf(from));
    if (target == from) return null;
    if (groups().contains(target)) return null;
    await createGroup(parent);
    await renameGroup(from, target);
    return target;
  }

  /// 删除分组：移除分组名（含子组）；组内条目回到未分组（磁盘目录/文件保留）
  Future<void> deleteGroup(String name) async {
    final removed = groupWithDescendants(name).toSet();
    final list = groups()..removeWhere((g) => removed.contains(g));
    _saveGroups(list);
    for (final t in _tasks) {
      if (removed.contains(t.group)) t.group = '';
    }
    _persist();
    await _rewriteRecordGroups({for (final g in removed) g: ''});
    notifyListeners();
  }

  /// 设置任务分组（会移动磁盘上的目录/文件）
  ///
  /// 移动失败时抛出的异常在此吞掉并记日志：分组元数据保持原值，
  /// 不出现“记录已改组、文件还在原地”的分叉（此前失败也照改）。
  Future<void> setTaskGroup(String id, String group) async {
    final t = _tasks.where((e) => e.id == id).firstOrNull;
    final g = sanitizeGroupName(group.trim());
    if (t == null || t.group == g) return;
    final oldPath = t.filePath;
    String? newPath;
    try {
      newPath = await _moveTaskDir(t, g);
    } catch (e) {
      Log.error('DownloadManager', 'setTaskGroup 移动失败，已保持原分组：$e');
      return;
    }
    t.group = g;
    if (newPath != null) t.filePath = newPath;
    _persist();
    if (oldPath != null) {
      await _updateRecordPath(oldPath, t.filePath ?? oldPath, g);
    }
    notifyListeners();
  }

  /// 设置记录分组（会移动磁盘文件）
  Future<void> setRecordGroup(String filePath, String group) async {
    final records = await allRecords();
    final record = records.where((r) => r['filePath'] == filePath).firstOrNull;
    if (record == null) return;
    final g = sanitizeGroupName(group.trim());
    if ((record['group']?.toString() ?? '') == g) return;
    final task = _tasks.where((e) => e.filePath == filePath).firstOrNull;
    if (task != null) {
      await setTaskGroup(task.id, g);
      return;
    }
    String? newPath;
    try {
      newPath = await _moveFileToGroup(filePath, g);
    } catch (e) {
      Log.error('DownloadManager', 'setRecordGroup 移动失败，已保持原分组：$e');
      return;
    }
    await _updateRecordPath(filePath, newPath ?? filePath, g);
    notifyListeners();
  }

  /// 重命名某条下载记录对应的文件：改磁盘文件名 + 记录里的 title/filePath。
  /// 会保留原文件名里除标题外的部分（集数/分辨率等）。
  Future<void> renameRecord(String filePath, String newTitle) async {
    final name = newTitle.trim();
    if (name.isEmpty) return;
    final records = await DownloadDatabase.instance.allRecords();
    final rec = records.where((e) => e['filePath'] == filePath).firstOrNull;
    if (rec == null) return;

    final oldTitle = rec['title']?.toString() ?? '';
    final dir = p.dirname(filePath);
    final ext = p.extension(filePath);
    final oldBase = p.basenameWithoutExtension(filePath);
    // 保留文件名里除标题外的部分（如集数/分辨率），只替换标题
    final newBase = (oldTitle.isNotEmpty && oldBase.contains(oldTitle))
        ? oldBase.replaceFirst(oldTitle, name)
        : name;
    final newPath = p.join(dir, '${_sanitize(newBase)}$ext');
    if (newPath != filePath) {
      final f = File(filePath);
      if (await f.exists()) {
        try {
          await f.rename(newPath);
        } catch (_) {}
      }
    }
    try {
      await DownloadDatabase.instance.updateRecordTitle(
        filePath,
        name,
        newPath,
      );
    } catch (_) {}
    notifyListeners();
  }

  /// 移动任务目录到新分组，返回新的文件路径；无批量可移返回 null。
  /// 移动失败直接抛（调用方保持原分组元数据，不与其分叉）。
  Future<String?> _moveTaskDir(DownloadTask task, String newGroup) async {
    final oldDir = Directory(_taskDirPath(task));
    final newDir = Directory(p.join(groupDir(newGroup), _safeTaskName(task)));
    if (oldDir.path == newDir.path) return null;
    if (await oldDir.exists()) {
      await newDir.parent.create(recursive: true);
      await oldDir.rename(newDir.path);
      if (task.filePath != null) {
        return p.join(newDir.path, p.basename(task.filePath!));
      }
      return null;
    }
    if (task.filePath != null) {
      return _moveFileToGroup(task.filePath!, newGroup);
    }
    return null;
  }

  /// 移动记录文件（连同其所在任务目录）到新分组，返回新路径；
  /// 无需移动返回 null，失败直接抛。
  Future<String?> _moveFileToGroup(String filePath, String group) async {
    final f = File(filePath);
    if (!await f.exists()) return null;
    final srcDir = Directory(p.dirname(filePath));
    final dstBase = Directory(groupDir(group));
    final dstDir = Directory(p.join(dstBase.path, p.basename(srcDir.path)));
    if (srcDir.path == dstDir.path) return null;
    await dstBase.create(recursive: true);
    if (await srcDir.exists()) {
      await srcDir.rename(dstDir.path);
      return p.join(dstDir.path, p.basename(filePath));
    }
    await f.rename(p.join(dstBase.path, p.basename(filePath)));
    return p.join(dstBase.path, p.basename(filePath));
  }

  Future<void> _updateRecordPath(
    String oldPath,
    String newPath,
    String group,
  ) async {
    try {
      await DownloadDatabase.instance.updateRecordPath(
        oldPath,
        newPath,
        group: group,
      );
    } catch (_) {}
    await _refreshDownloadedKeys();
  }

  Future<void> _rewriteRecordGroups(Map<String, String> mapping) async {
    try {
      final records = await DownloadDatabase.instance.allRecords();
      var changed = false;
      for (final e in records) {
        final g = e['group']?.toString() ?? '';
        if (!mapping.containsKey(g)) continue;
        final newG = mapping[g] ?? '';
        e['group'] = newG;
        final fp = e['filePath']?.toString() ?? '';
        // 仅“重命名到非空分组”时改路径（删除分组不改，文件留在原目录）
        if (fp.isNotEmpty && g.isNotEmpty && newG.isNotEmpty) {
          final from = groupDir(g);
          // 历史/被外部移动过的记录，filePath 可能根本不在该分组目录下；
          // 此时 p.relative 会产出 `../../..`，拼回去就把路径指到下载根之外了。
          if (!p.isWithin(from, fp) && p.normalize(fp) != p.normalize(from)) {
            changed = true;
            continue;
          }
          final rel = p.relative(fp, from: from);
          e['filePath'] = p.join(groupDir(newG), rel);
        }
        changed = true;
      }
      if (changed) {
        await DownloadDatabase.instance.replaceAllRecords(records);
      }
    } catch (_) {}
    await _refreshDownloadedKeys();
  }
}

/// 下载记录变化时通知列表卡片刷新下载角标
final downloadsChangedProvider = StreamProvider<void>((ref) {
  return DownloadManager.instance.recordsChanged;
});

// ── 后台 isolate 使用的顶层工具（只接收可发送的基本类型）────────────────────
// 注意：Isolate.run 的入口闭包必须在这里生成。写在实例方法里会连带捕获 `this`
// （DownloadManager 持有 isolate 端口等不可发送对象），spawn 时抛 unsendable。

/// 生成 [_segDirBytesSync] 的 isolate 入口。
int Function() _segDirBytesRunner(String dir) =>
    () => _segDirBytesSync(dir);

/// 生成 [_filesTotalBytesSync] 的 isolate 入口。
int Function() _filesTotalBytesRunner(List<String> paths) =>
    () => _filesTotalBytesSync(paths);

List<String> Function() _segmentPathsRunner(String dir) =>
    () => _segmentPathsSync(dir);

/// 生成 [_cleanupOrphanSegmentsSync] 的 isolate 入口。
void Function() _cleanupOrphanSegmentsRunner(
  String rootPath,
  Set<String> keepDirs,
  Set<String> keepIds,
) =>
    () => _cleanupOrphanSegmentsSync(rootPath, keepDirs, keepIds);

/// 只统计已完成分片，排除中断后遗留的临时文件。
int _segDirBytesSync(String dir) {
  var total = 0;
  try {
    for (final f in Directory(dir).listSync()) {
      if (f is! File || !f.path.endsWith('.ts')) continue;
      try {
        total += f.lengthSync();
      } catch (_) {}
    }
  } catch (_) {}
  return total;
}

/// 统计一组文件的字节数（后台 isolate 执行）。
int _filesTotalBytesSync(List<String> paths) {
  var total = 0;
  for (final path in paths) {
    try {
      total += File(path).lengthSync();
    } catch (_) {}
  }
  return total;
}

List<String> _segmentPathsSync(String dir) {
  try {
    return Directory(dir)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.ts') && file.lengthSync() > 0)
        .map((file) => file.path)
        .toList()
      ..sort();
  } catch (_) {
    return const [];
  }
}

/// 清理非保留任务目录里的 segments 分片与 video.mp4 半成品（后台 isolate 执行）。
/// 下载根目录下可能有分组子目录，递归一层处理。
void _cleanupOrphanSegmentsSync(
  String rootPath,
  Set<String> keepDirs,
  Set<String> keepIds,
) {
  bool isKeep(String path) {
    if (keepDirs.contains(path)) return true;
    final base = p.basename(path);
    for (final id in keepIds) {
      if (base.endsWith('_$id')) return true;
    }
    return false;
  }

  void cleanTaskDir(Directory dir) {
    try {
      final video = File(p.join(dir.path, 'video.mp4'));
      if (video.existsSync()) video.deleteSync();
    } catch (_) {}
    final segDir = Directory(p.join(dir.path, 'segments'));
    if (segDir.existsSync()) {
      try {
        segDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  try {
    final root = Directory(rootPath);
    if (!root.existsSync()) return;
    for (final entry in root.listSync()) {
      if (entry is! Directory) continue;
      if (isKeep(entry.path)) continue;
      final hasSeg = Directory(p.join(entry.path, 'segments')).existsSync();
      final hasVideo = File(p.join(entry.path, 'video.mp4')).existsSync();
      if (hasSeg || hasVideo) {
        cleanTaskDir(entry);
      } else {
        // 可能是分组目录：递归清理其下的任务目录
        for (final sub in entry.listSync()) {
          if (sub is! Directory) continue;
          if (isKeep(sub.path)) continue;
          cleanTaskDir(sub);
        }
      }
    }
  } catch (_) {}
}
