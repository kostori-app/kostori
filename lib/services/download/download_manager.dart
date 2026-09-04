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
import 'package:kostori/network/cookie_jar.dart';
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

  /// 速度采样（任务 id → 上次采样时间/字节数）
  final Map<String, DateTime> _speedSampleTime = {};
  final Map<String, int> _speedSampleBytes = {};

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
  Future<void> _cleanupOrphanSegments() async {
    try {
      final dir = Directory(_downloadDir);
      if (!await dir.exists()) return;
      final keepDirs = <String>{
        for (final t in _tasks)
          if (t.status == DownloadStatus.queued ||
              t.status == DownloadStatus.downloading ||
              t.status == DownloadStatus.paused ||
              t.status == DownloadStatus.failed)
            p.join(_downloadDir, _safeTaskName(t)),
      };
      await for (final entry in dir.list()) {
        if (entry is! Directory) continue;
        // 清理残留的半成品 video.mp4（合并中断遗留；正常流程已被 rename 走）
        await _deleteQuiet(File(p.join(entry.path, 'video.mp4')));
        if (keepDirs.contains(entry.path)) continue;
        final segDir = Directory(p.join(entry.path, 'segments'));
        if (!await segDir.exists()) continue;
        try {
          await segDir.delete(recursive: true);
        } catch (_) {}
      }
    } catch (e) {
      Log.error('DownloadManager.cleanupOrphanSegments', '$e');
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
    String? episodeNo,
    String? resolution,
    Map<String, String> headers = const {},
  }) async {
    if (url.isEmpty) return null;
    if (url.startsWith('blob:')) return null;
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
    // 附加 cookie jar 匹配该域名的 cookie，与播放端一致（否则校验会话的源会 403/410）
    final dlUri = Uri.tryParse(url);
    if (dlUri != null && (dlUri.scheme == 'http' || dlUri.scheme == 'https')) {
      try {
        final cookieHeader = await SingleInstanceCookieJar.instance
            ?.loadForRequestCookieHeader(dlUri);
        if (cookieHeader != null && cookieHeader.isNotEmpty) {
          effectiveHeaders['Cookie'] = cookieHeader;
        }
      } catch (_) {}
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
      episodeNo: episodeNo,
      author: author,
      resolution: resolution,
      headers: effectiveHeaders,
      createdAt: DateTime.now(),
    );
    _tasks.add(task);
    _persist();
    notifyListeners();
    _schedule();
    return task;
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
    for (final t in _tasks) {
      if (t.status == DownloadStatus.queued &&
          _activeCount < _maxConcurrent) {
        unawaited(_runTask(t));
      }
    }
  }

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
    // 最终文件名用标题基名（不带唯一 id 数字后缀），目录仍按 taskDir 隔离
    final finalPath = p.join(taskDir, '${_fileBaseName(task)}.mp4');

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
      // 补全实际文件大小（m3u8 下载时无法预知总大小，合并后取真实值）
      task.totalBytes = await File(finalPath).length();
      task.status = DownloadStatus.completed;
      task.progress = 1;
      task.error = null;
      await _writeRecord(task);
      // 合并完成即清理分片，避免 TS 切片残留占用体积
      await _cleanupSegments(taskDir);
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
      } else if (_isTransient(e)) {
        // 临时性失败（断线/超时）：自动重新排队续传，避免用户反复手动重试
        final n = (_autoRetryCounts[task.id] ?? 0) + 1;
        if (n <= _maxAutoRetries && _tasks.contains(task)) {
          _autoRetryCounts[task.id] = n;
          task.status = DownloadStatus.queued;
          task.error = null;
          task.progress = task.progress.clamp(0.0, 1.0);
          _persist();
          notifyListeners();
          // 指数退避后回到队列（有并发位则自动开始，未占满立即续传）
          unawaited(() async {
            await Future.delayed(Duration(seconds: n * 3));
            if (_tasks.contains(task) &&
                task.status == DownloadStatus.queued) {
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
      _persist();
      notifyListeners();
      _syncKeepAlive(force: true);
      _schedule();
    }
  }

  /// 计算并上报下载进度（含速度采样，500ms 间隔平滑）。
  /// 依赖 [DownloadTask.downloadedBytes] 已更新。
  void _updateDownloadProgress(DownloadTask task) {
    final now = DateTime.now();
    final lastTime = _speedSampleTime[task.id];
    final lastBytes = _speedSampleBytes[task.id];
    if (lastTime != null && lastBytes != null) {
      final dt = now.difference(lastTime).inMilliseconds;
      final db = task.downloadedBytes - lastBytes;
      if (dt >= 500 && db >= 0) {
        task.downloadSpeed = db / (dt / 1000);
        _speedSampleTime[task.id] = now;
        _speedSampleBytes[task.id] = task.downloadedBytes;
      }
    } else {
      _speedSampleTime[task.id] = now;
      _speedSampleBytes[task.id] = task.downloadedBytes;
    }
    notifyListeners();
    _syncKeepAlive();
  }

  /// 永久失败时提示原因（签名过期/网络/403 等），便于用户判断
  void _notifyDownloadFailed(DownloadTask task, Object e) {
    try {
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
  }

  /// mp4 直链：dart:io HttpClient 流式下载（断点续传 + 取消 + 连接中断重试）。
  ///
  /// 不用 dio/rhttp：部分 CDN（moedet 等）拒绝 reqwest 的请求特征
  /// （默认头/HTTP2 等），但 curl/浏览器（dart:io 与之一致）可正常下载。
  /// 大文件传输中连接被服务端断开（HttpException: Connection closed）较常见，
  /// 失败后基于已写入字节用 Range 续传，避免整个重下。
  Future<void> _downloadDirect(
    DownloadTask task,
    FfmpegCancelToken cancelToken,
    String tmpPath,
  ) async {
    final tmp = File(tmpPath);
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (cancelToken.isCancelled) throw FfmpegCancelledException();
      final downloaded = await tmp.exists() ? await tmp.length() : 0;
      task.downloadedBytes = downloaded;
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      var received = 0;
      int total = -1;
      var interrupted = false;
      try {
        final request = await client.getUrl(Uri.parse(task.url));
        request.headers.set(
          'User-Agent',
          task.headers['User-Agent'] ??
              task.headers['user-agent'] ??
              _browserUA,
        );
        // 始终带 Range（首次 bytes=0-，续传从已下载处继续）
        request.headers.set('Range', 'bytes=$downloaded-');
        task.headers.forEach((k, v) {
          final lk = k.toLowerCase();
          if (lk != 'user-agent' && lk != 'range') {
            request.headers.set(k, v);
          }
        });
        final response = await request.close();
        if (response.statusCode != 200 && response.statusCode != 206) {
          // 4xx/5xx（含 410 链接失效）不可通过 Range 续传恢复，直接失败不重试
          throw _DownloadHttpError(response.statusCode);
        }
        total = response.contentLength;
        if (downloaded == 0 && total >= 0) {
          task.totalBytes = total;
        }
        final sink = tmp.openWrite(mode: FileMode.append);
        try {
          await for (final chunk in response) {
            if (cancelToken.isCancelled) {
              await sink.close();
              throw FfmpegCancelledException();
            }
            sink.add(chunk);
            received += chunk.length;
            task.downloadedBytes = downloaded + received;
            if (total > 0) {
              task.progress = ((downloaded + received) / (downloaded + total))
                  .clamp(0.0, 1.0);
            }
            _updateDownloadProgress(task);
          }
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
          interrupted = true;
        }
        if (interrupted) {
          if (attempt >= maxAttempts) {
            throw Exception('下载中断：连接多次断开，请重试');
          }
          // 短暂等待后续传（已下载部分保留在临时文件）
          await Future.delayed(Duration(seconds: attempt));
          continue;
        }
        if (cancelToken.isCancelled) throw FfmpegCancelledException();
        task.progress = 1;
        break;
      } finally {
        client.close(force: true);
      }
    }
    notifyListeners();
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

    // 断点续传：已有分片字节计入已下载（避免重复统计）
    var existingBytes = 0;
    await for (final f in Directory(segDir).list()) {
      existingBytes += await File(f.path).length();
    }
    task.downloadedBytes = existingBytes;

    // 1. 解析 m3u8（含变体选择）
    final segUrls = await _resolveHlsSegments(dio, task);
    task.segTotal = segUrls.length;
    task.segDone = 0;

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
            // 分片下载带重试：签名 CDN（如 beeg）偶发 403/断连，重试可缓解
            List<int>? data;
            for (var attempt = 0; attempt < 3; attempt++) {
              try {
                final resp = await dio.get<List<int>>(
                  segUrls[i],
                  options: Options(
                    headers: task.headers,
                    responseType: ResponseType.bytes,
                    extra: const {'httpVersion11': true},
                  ),
                );
                data = resp.data;
                if (data != null && data.isNotEmpty) break;
              } catch (e) {
                if (attempt >= 2) rethrow;
              }
              if (attempt < 2) {
                await Future.delayed(const Duration(seconds: 1));
              }
            }
            if (data == null || data.isEmpty) {
              throw Exception('分片 $i 下载为空');
            }
            await segFile.writeAsBytes(data, flush: true);
            segPaths[i] = segFile.path;
            task.downloadedBytes += data.length;
            completed++;
          }
          task.progress = segUrls.isEmpty
              ? 1
              : completed / segUrls.length;
          task.segDone = completed;
          _updateDownloadProgress(task);
        } catch (e) {
          errors.add('分片 $i: $e');
        } finally {
          sem.release();
        }
      }),
    );

    if (cancelToken.isCancelled) throw FfmpegCancelledException();
    if (errors.isNotEmpty) {
      // 带上首个失败分片的原因，便于用户判断（签名过期/网络/403 等）
      final first = errors.first.split('\n').first.trim();
      final reason = first.length > 80 ? '${first.substring(0, 80)}...' : first;
      throw Exception('部分分片下载失败：${errors.length} 个（$reason）');
    }

    // 3. ffmpeg 合并 ts → mp4（合并进度实时反映到 task.progress）
    task.isMerging = true;
    task.progress = 0;
    task.error = null;
    notifyListeners();
    try {
      await FfmpegEncoder.mergeTs(
        tsPaths: segPaths.where((p) => p.isNotEmpty).toList(),
        outputPath: tmpPath,
        cancelToken: cancelToken,
        onProgress: (p) {
          task.progress = p.clamp(0.0, 1.0);
          notifyListeners();
        },
      );
    } finally {
      task.isMerging = false;
      notifyListeners();
    }
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
    final safeName = _safeTaskName(task);
    final taskDir = p.join(_downloadDir, safeName);
    final segDir = p.join(taskDir, 'segments');
    if (!await Directory(segDir).exists()) {
      App.rootContext.showMessage(message: t.downloadFailed);
      return;
    }
    final segPaths = Directory(segDir)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ts') && f.lengthSync() > 0)
        .map((f) => f.path)
        .toList()
      ..sort();
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
      await FfmpegEncoder.mergeTs(
        tsPaths: segPaths,
        outputPath: tmpPath,
        cancelToken: cancelToken,
        onProgress: (p) {
          task.progress = p.clamp(0.0, 1.0);
          notifyListeners();
        },
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
      _persist();
      notifyListeners();
      try {
        App.rootContext.showMessage(
          message: '${t.downloadCompleted}: ${task.title}',
        );
      } catch (_) {}
    } catch (e, s) {
      Log.error('DownloadManager.forceMerge', '$e\n$s');
      // 合并失败/取消：回到 failed 状态（保留分片供重试），清理半成品临时文件
      task.status = DownloadStatus.failed;
      task.isMerging = false;
      task.error = e.toString();
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
    t.error = null;
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
    // 用与创建一致的目录名（_safeTaskName），否则删不到残留目录
    final safeName = _safeTaskName(t);
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

  /// 按标题格式模板生成文件名基名（不含唯一 id 后缀）
  String _fileBaseName(DownloadTask task) {
    final format = _formatFor(task.sourceKey);
    // “不使用集标题”时优先用纯集号（部分源集标题是无意义的 1/视频 等）
    final ignoreTitle = appdata.implicitData['downloadIgnoreEpisodeTitle'] ==
        true;
    final episodeText = ignoreTitle && (task.episodeNo?.isNotEmpty ?? false)
        ? task.episodeNo!
        : (task.episode ?? '');
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
    // 文件名过长会导致创建文件失败（文件系统路径/名称长度限制），
    // 截断到安全长度（UTF-16 码元，Android ext4 文件名上限 255 字节内）
    if (name.length > 100) {
      name = name.substring(0, 100);
    }
    return name;
  }

  /// 任务目录名（含唯一 id，保证同名任务隔离）
  String _safeTaskName(DownloadTask task) =>
      '${_fileBaseName(task)}_${task.id}'.replaceAll(' ', '_');

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
        'resolution': task.resolution,
        'filePath': task.filePath,
        'totalBytes': task.totalBytes,
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
