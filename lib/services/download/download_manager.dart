import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/services/download/download_keep_alive.dart';
import 'package:kostori/services/download/download_task.dart';
import 'package:kostori/utils/ffmpeg_encoder.dart';
import 'package:path/path.dart' as p;

/// 视频下载管理器：任务队列 + 并发控制 + 进度通知 + 本地持久化。
///
/// 下载走 FFmpeg（`FfmpegEncoder.download`），支持 mp4 直链与 m3u8/HLS，
/// 默认转封装为 mp4（流复制，不重编码）。
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

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  int get _activeCount =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).length;

  static String get _downloadDir {
    final dir = appdata.implicitData['downloadDir'] as String?;
    if (dir != null && dir.isNotEmpty) return dir;
    return p.join(App.dataPath, 'downloads');
  }

  static String get _persistFile =>
      p.join(App.dataPath, 'download_tasks.json');

  bool _loaded = false;

  DateTime? _lastKeepAlive;
  bool _keepAliveStarted = false;

  /// 同步前台服务通知（节流 1s）：有下载任务时保活，无任务时停止
  void _syncKeepAlive({bool force = false}) {
    if (!Platform.isAndroid) return;
    final active = _tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .toList();
    if (active.isEmpty) {
      if (_keepAliveStarted) {
        _keepAliveStarted = false;
        DownloadKeepAlive.stop();
      }
      return;
    }
    if (!_keepAliveStarted) {
      _keepAliveStarted = true;
      DownloadKeepAlive.start();
    }
    final now = DateTime.now();
    if (!force &&
        _lastKeepAlive != null &&
        now.difference(_lastKeepAlive!).inSeconds < 1) {
      return;
    }
    _lastKeepAlive = now;
    DownloadKeepAlive.update(
      tasks: active
          .map((t) => (title: t.title, progress: t.progress))
          .toList(),
    );
  }

  /// 仅 WiFi：非 WiFi 网络时轮询等待，直到 WiFi 或取消
  Future<void> _waitForWifiIfNeeded(FfmpegCancelToken cancelToken) async {
    final wifiOnly = appdata.implicitData['downloadWifiOnly'] as bool? ?? false;
    if (!wifiOnly || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      while (!cancelToken.isCancelled) {
        final results = await Connectivity().checkConnectivity();
        final wifi = results.any(
          (r) => r == ConnectivityResult.wifi,
        );
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
      final f = File(_persistFile);
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        for (final e in list) {
          try {
            _tasks.add(DownloadTask.fromJson(Map<String, dynamic>.from(e as Map)));
          } catch (_) {}
        }
      }
      // 重启后未完成的任务标记为失败（ffmpeg 无断点续传，需重新下载）
      for (final t in _tasks) {
        if (t.isActive) {
          t.status = DownloadStatus.failed;
          t.error = 'interrupted';
        }
      }
      Directory(_downloadDir).createSync(recursive: true);
      _persist();
      notifyListeners();
    } catch (e, s) {
      Log.error('DownloadManager.init', '$e\n$s');
    }
  }

  /// 创建下载任务（自动进入队列）
  Future<DownloadTask?> enqueue({
    required String url,
    String? title,
    String? subtitle,
    String? cover,
    String? sourceKey,
    String? animeId,
    String? animeTitle,
    String? episode,
    String? author,
    String? resolution,
    Map<String, String> headers = const {},
  }) async {
    if (url.isEmpty) return null;
    if (url.startsWith('blob:')) return null;
    // 无 UA 时补浏览器 UA：缺省会被 rhttp 填成 "kostori/..."，
    // 部分 CDN（moedot 等）拒绝该 UA 返回 400，而浏览器可直下
    var effectiveHeaders = Map<String, String>.from(headers);
    if (effectiveHeaders['User-Agent'] == null &&
        effectiveHeaders['user-agent'] == null) {
      effectiveHeaders['User-Agent'] = _browserUA;
    }
    final task = DownloadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}',
      title: title ?? url,
      subtitle: subtitle,
      cover: cover,
      url: url,
      sourceKey: sourceKey,
      animeId: animeId,
      animeTitle: animeTitle,
      episode: episode,
      author: author,
      resolution: resolution,
      headers: effectiveHeaders,
      createdAt: DateTime.now(),
    );
    _tasks.insert(0, task);
    _persist();
    notifyListeners();
    _schedule();
    return task;
  }

  void _schedule() {
    for (final t in _tasks) {
      if (t.status == DownloadStatus.queued &&
          _activeCount < _maxConcurrent) {
        unawaited(_runTask(t));
      }
    }
  }

  Future<void> _runTask(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.progress = 0;
    _runningIds.add(task.id);
    final cancelToken = FfmpegCancelToken();
    _cancelTokens[task.id] = cancelToken;
    notifyListeners();
    _syncKeepAlive(force: true);

    // 仅 WiFi：非 WiFi 网络时等待
    try {
      await _waitForWifiIfNeeded(cancelToken);
    } on FfmpegCancelledException {
      return;
    }

    // 每个任务一个目录：mp4 断点临时文件 / m3u8 分片都在目录内
    final safeName = _safeTaskName(task);
    final taskDir = p.join(_downloadDir, safeName);
    await Directory(taskDir).create(recursive: true);
    final tmpPath = p.join(taskDir, 'video.mp4');
    final finalPath = p.join(taskDir, '$safeName.mp4');

    try {
      if (task.isHls) {
        await _downloadHls(task, cancelToken, taskDir, tmpPath);
      } else {
        await _downloadDirect(task, cancelToken, tmpPath);
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
      task.status = DownloadStatus.completed;
      task.progress = 1;
      task.error = null;
      await _writeRecord(task);
      try {
        App.rootContext.showMessage(
          message: '${t.downloadCompleted}: ${task.title}',
        );
      } catch (_) {}
    } catch (e, s) {
      // 被暂停/取消时不标记失败
      if (cancelToken.isCancelled) {
        if (_tasks.contains(task) && task.status != DownloadStatus.paused) {
          task.status = DownloadStatus.failed;
          task.error = 'cancelled';
        }
      } else {
        Log.error('DownloadManager', '下载失败 ${task.title}: $e\n$s');
        if (_tasks.contains(task)) {
          task.status = DownloadStatus.failed;
          task.error = e.toString();
        }
      }
    } finally {
      _runningIds.remove(task.id);
      _cancelTokens.remove(task.id);
      _persist();
      notifyListeners();
      _syncKeepAlive(force: true);
      _schedule();
    }
  }

  /// mp4 直链：dart:io HttpClient 流式下载（断点续传 + 取消）。
  ///
  /// 不用 dio/rhttp：部分 CDN（moedet 等）拒绝 reqwest 的请求特征
  /// （默认头/HTTP2 等），但 curl/浏览器（dart:io 与之一致）可正常下载。
  Future<void> _downloadDirect(
    DownloadTask task,
    FfmpegCancelToken cancelToken,
    String tmpPath,
  ) async {
    final tmp = File(tmpPath);
    final downloaded = await tmp.exists() ? await tmp.length() : 0;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    var received = 0;
    int? total;
    try {
      final request = await client.getUrl(Uri.parse(task.url));
      request.headers.set(
        'User-Agent',
        task.headers['User-Agent'] ??
            task.headers['user-agent'] ??
            _browserUA,
      );
      // 始终带 Range（首次 bytes=0-）
      request.headers.set('Range', 'bytes=$downloaded-');
      task.headers.forEach((k, v) {
        final lk = k.toLowerCase();
        if (lk != 'user-agent' && lk != 'range') {
          request.headers.set(k, v);
        }
      });
      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode}');
      }
      total = response.contentLength;
      final sink = tmp.openWrite(mode: FileMode.append);
      try {
        await for (final chunk in response) {
          if (cancelToken.isCancelled) {
            await sink.close();
            throw FfmpegCancelledException();
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            task.progress = ((downloaded + received) / (downloaded + total))
                .clamp(0.0, 1.0);
            notifyListeners();
            _syncKeepAlive();
          }
        }
        await sink.close();
      } catch (e) {
        try {
          await sink.close();
        } catch (_) {}
        rethrow;
      }
      if (cancelToken.isCancelled) throw FfmpegCancelledException();
      task.progress = 1;
      notifyListeners();
    } finally {
      client.close(force: true);
    }
  }

  /// m3u8：dio 并发下载分片（已下载跳过实现断点），ffmpeg 合并转 mp4
  Future<void> _downloadHls(
    DownloadTask task,
    FfmpegCancelToken cancelToken,
    String taskDir,
    String tmpPath,
  ) async {
    final dio = AppDio();
    final segDir = p.join(taskDir, 'segments');
    await Directory(segDir).create(recursive: true);

    // 1. 解析 m3u8（含变体选择）
    final segUrls = await _resolveHlsSegments(dio, task);

    // 2. 并发下载分片（信号量限流；已存在的跳过实现断点）
    final sem = _SimpleSemaphore(_segmentConcurrent);
    final segPaths = List<String>.filled(segUrls.length, '');
    var completed = 0;
    final errors = <String>[];
    await Future.wait(
      List.generate(segUrls.length, (i) async {
        await sem.acquire();
        try {
          if (cancelToken.isCancelled) return;
          final segFile = File(
            p.join(segDir, 'seg_${i.toString().padLeft(6, '0')}.ts'),
          );
          if (await segFile.exists() && await segFile.length() > 0) {
            segPaths[i] = segFile.path;
            completed++;
          } else {
            final resp = await dio.get<List<int>>(
              segUrls[i],
              options: Options(
                headers: task.headers,
                responseType: ResponseType.bytes,
                extra: const {'httpVersion11': true},
              ),
            );
            if (resp.data == null || resp.data!.isEmpty) {
              throw Exception('分片 $i 下载为空');
            }
            await segFile.writeAsBytes(resp.data!, flush: true);
            segPaths[i] = segFile.path;
            completed++;
          }
          task.progress = segUrls.isEmpty
              ? 1
              : completed / segUrls.length;
          notifyListeners();
          _syncKeepAlive();
        } catch (e) {
          errors.add('分片 $i: $e');
        } finally {
          sem.release();
        }
      }),
    );

    if (cancelToken.isCancelled) throw FfmpegCancelledException();
    if (errors.isNotEmpty) {
      throw Exception('部分分片下载失败：${errors.length} 个');
    }

    // 3. ffmpeg 合并 ts → mp4
    await FfmpegEncoder.mergeTs(
      tsPaths: segPaths.where((p) => p.isNotEmpty).toList(),
      outputPath: tmpPath,
      cancelToken: cancelToken,
    );
  }

  /// 分片下载并发数（设置可调）
  int get _segmentConcurrent {
    final v = appdata.implicitData['downloadSegmentConcurrent'] as int?;
    return (v != null && v > 0) ? v : 4;
  }

  /// 解析 m3u8：选择最高码率变体，返回分片 URL 列表
  Future<List<String>> _resolveHlsSegments(Dio dio, DownloadTask task) async {
    String content;
    String targetUrl = task.url;
    final root = await dio.get<String>(
      task.url,
      options: Options(
        headers: task.headers,
        responseType: ResponseType.plain,
        extra: const {'httpVersion11': true},
      ),
    );
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
        final v = await dio.get<String>(
          targetUrl,
          options: Options(
            headers: task.headers,
            responseType: ResponseType.plain,
            extra: const {'httpVersion11': true},
          ),
        );
        content = v.data ?? '';
      }
    }

    final segBase = _baseOf(targetUrl);
    final segs = <String>[];
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

  /// 暂停下载（终止 ffmpeg 进程；恢复时从头重新下载）
  Future<void> pause(String id) async {
    final t = _tasks.where((e) => e.id == id).firstOrNull;
    if (t == null || t.status != DownloadStatus.downloading) return;
    _cancelTokens[id]?.cancel();
    t.status = DownloadStatus.paused;
    t.error = null;
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
    t.progress = 0;
    t.error = null;
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
        t.progress = 0;
        t.error = null;
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
        t.progress = 0;
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
    final file = File(p.join(App.dataPath, 'download_records.json'));
    if (!await file.exists()) return;
    try {
      final records = jsonDecode(await file.readAsString()) as List;
      records.removeWhere((e) => e is Map && e['filePath'] == filePath);
      await file.writeAsString(jsonEncode(records));
    } catch (_) {}
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
    if (t.filePath != null) {
      await _deleteQuiet(File(t.filePath!));
    }
    final safeName = '${_sanitize(t.title)}_${t.id}';
    final dir = Directory(p.join(_downloadDir, safeName));
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

  /// 从 download_records.json 移除某任务的记录
  Future<void> _removeRecord(DownloadTask task) async {
    if (task.animeId == null && task.sourceKey == null) return;
    final file = File(p.join(App.dataPath, 'download_records.json'));
    if (!await file.exists()) return;
    try {
      final records = jsonDecode(await file.readAsString()) as List;
      records.removeWhere(
        (e) =>
            e is Map &&
            e['animeId'] == task.animeId &&
            e['episode'] == task.episode &&
            e['sourceKey'] == task.sourceKey,
      );
      await file.writeAsString(jsonEncode(records));
    } catch (e, s) {
      Log.error('DownloadManager.removeRecord', '$e\n$s');
    }
  }

  /// 清空已完成/失败任务
  Future<void> clearFinished() async {
    final finished = _tasks
        .where((t) => !t.isActive)
        .map((t) => t.id)
        .toList();
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

  static String _sanitize(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    return cleaned.isEmpty ? 'video' : cleaned;
  }

  /// 每源标题格式：源配置覆盖 → 全局默认 → 内置默认
  String _formatFor(String? sourceKey) {
    final per = (appdata.implicitData['downloadTitleFormats'] as Map?)?[sourceKey];
    if (per is String && per.isNotEmpty) return per;
    final global = appdata.implicitData['downloadTitleFormat'] as String?;
    if (global != null && global.isNotEmpty) return global;
    return '{title} {episode}';
  }

  /// 按标题格式模板生成安全文件名
  String _safeTaskName(DownloadTask task) {
    final format = _formatFor(task.sourceKey);
    var name = format
        .replaceAll('{title}', task.animeTitle ?? task.title)
        .replaceAll('{episode}', task.episode ?? '')
        .replaceAll('{author}', task.author ?? '')
        .replaceAll('{resolution}', task.resolution ?? '')
        .replaceAll('{source}', task.sourceKey ?? '')
        .replaceAll('{year}', DateTime.now().year.toString())
        .trim();
    name = _sanitize(name);
    if (name.isEmpty) name = 'video';
    return '${name}_${task.id}'.replaceAll(' ', '_');
  }

  /// 下载记录：完成时写入 download_records.json
  Future<void> _writeRecord(DownloadTask task) async {
    if (task.filePath == null) return;
    if (task.animeId == null && task.sourceKey == null) return;
    final file = File(p.join(App.dataPath, 'download_records.json'));
    List records = [];
    if (await file.exists()) {
      try {
        records = jsonDecode(await file.readAsString()) as List;
      } catch (_) {}
    }
    records.removeWhere(
      (e) =>
          e is Map &&
          e['animeId'] == task.animeId &&
          e['episode'] == task.episode &&
          e['sourceKey'] == task.sourceKey,
    );
    records.insert(
      0,
      {
        'animeId': task.animeId,
        'sourceKey': task.sourceKey,
        'title': task.title,
        'episode': task.episode,
        'filePath': task.filePath,
        'time': DateTime.now().toIso8601String(),
      },
    );
    try {
      await file.writeAsString(jsonEncode(records));
    } catch (e, s) {
      Log.error('DownloadManager.record', '$e\n$s');
    }
  }

  /// 查询某番剧的下载记录（按 animeId + sourceKey）
  static Future<List<Map<String, dynamic>>> recordsFor(
    String animeId,
    String sourceKey,
  ) async {
    final file = File(p.join(App.dataPath, 'download_records.json'));
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      final results = <Map<String, dynamic>>[];
      for (final e in list.whereType<Map>()) {
        if (e['animeId'] != animeId || e['sourceKey'] != sourceKey) continue;
        // 文件已不存在的记录视为已删除，不返回（详情页"已下载"据此判断）
        final fp = e['filePath'] as String?;
        if (fp == null || fp.isEmpty) continue;
        if (!await File(fp).exists()) continue;
        results.add(Map<String, dynamic>.from(e));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 查询全部下载记录（含文件已丢失的，供"下载记录"页标记"已删除"）
  static Future<List<Map<String, dynamic>>> allRecords() async {
    final file = File(p.join(App.dataPath, 'download_records.json'));
    if (!await file.exists()) return [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return list
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    try {
      final f = File(_persistFile);
      await f.create(recursive: true);
      await f.writeAsString(
        jsonEncode(_tasks.map((t) => t.toJson()).toList()),
      );
    } catch (e, s) {
      Log.error('DownloadManager.persist', '$e\n$s');
    }
  }
}

/// 简单信号量：限制并发数量
class _SimpleSemaphore {
  final int _max;
  int _used = 0;
  final List<Completer<void>> _waiters = [];

  _SimpleSemaphore(this._max);

  Future<void> acquire() async {
    if (_used < _max) {
      _used++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
    _used++;
  }

  void release() {
    _used--;
    if (_waiters.isNotEmpty) {
      final c = _waiters.removeAt(0);
      c.complete();
    }
  }
}
