import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:mime/mime.dart';

/// 按文件索引提供支持并发 Range 请求的本地种子串流。
class TorrentStreamServer {
  TorrentStreamServer(this.task, {this.onIdle});

  final TorrentTask task;
  final void Function()? onIdle;

  HttpServer? _server;

  Future<void>? _starting;

  bool _stopRequested = false;
  int _nextRequestId = 0;
  final Map<int, Set<int>> _activePriorities = {};
  final Set<Completer<void>> _requests = {};

  int get port => _server?.port ?? 0;

  bool get running => _server != null;

  Future<void> start() {
    if (_server != null) return Future.value();
    _stopRequested = false;
    return _starting ??= _bind().whenComplete(() => _starting = null);
  }

  Future<void> _bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    if (_stopRequested) {
      await server.close(force: true);
      return;
    }
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    _stopRequested = true;
    final server = _server;
    _server = null;
    for (final request in _requests) {
      if (!request.isCompleted) request.complete();
    }
    await _starting;
    try {
      await server?.close(force: true);
    } catch (_) {}
    _activePriorities.clear();
    onIdle?.call();
  }

  /// 文件索引不受重命名、路径编码和名称长度影响。
  Uri urlFor(TorrentFileEntry file) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: port,
    path: '/stream',
    queryParameters: {'fileIndex': '${file.index}'},
  );

  static Uri urlForPath(int port, String filePath) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: port,
    // 让 Uri 负责编码空格、中文等字符，同时保留种子路径中的 '/'。
    pathSegments: filePath
        .replaceAll('\\', '/')
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(),
  );

  /// 比较 HTTP 请求路径和种子/本地文件路径。
  ///
  /// 种子路径有时包含根目录，有时只有文件相对路径；重命名后本地路径
  /// 也可能变成绝对路径。允许一端作为另一端的路径后缀，才能覆盖这几种
  /// 布局，同时仍然要求完整的路径段边界，避免同名文件误匹配。
  static bool pathMatches(String requestPath, String candidatePath) {
    String normalize(String value) {
      var result = value.replaceAll('\\', '/');
      while (result.startsWith('/')) {
        result = result.substring(1);
      }
      while (result.endsWith('/')) {
        result = result.substring(0, result.length - 1);
      }
      return result;
    }

    final request = normalize(requestPath);
    final candidate = normalize(candidatePath);
    if (request.isEmpty || candidate.isEmpty) return false;
    return request == candidate ||
        request.endsWith('/$candidate') ||
        candidate.endsWith('/$request');
  }

  /// 取引用文件名的最后一段。
  ///
  /// 引擎的 `DownloadFile.originalFileName` 用 `Platform.pathSeparator` 切分，
  /// 在 Windows 上是 `\` 而种子路径是 `/`，结果是返回**整条路径**，
  /// `lookupMimeType` 匹配不到、Content-Type 退化成 octet-stream。
  static String _lastSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    final i = normalized.lastIndexOf('/');
    return i < 0 ? normalized : normalized.substring(i + 1);
  }

  static String _parentPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final i = normalized.lastIndexOf('/');
    return i < 0 ? '' : normalized.substring(0, i);
  }

  static String _extension(String path) {
    final name = _lastSegment(path).toLowerCase();
    final i = name.lastIndexOf('.');
    return i <= 0 ? '' : name.substring(i);
  }

  Future<bool> _waitForRange(
    DownloadFile file,
    int start,
    int end,
    Completer<void> cancelled,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!file.isRangeWritten(start, end)) {
      if (cancelled.isCompleted) return false;
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('waiting for verified bytes $start-$end');
      }
      await Future.any([
        cancelled.future,
        Future<void>.delayed(const Duration(milliseconds: 100)),
      ]);
    }
    return !cancelled.isCompleted;
  }

  // createStream() 在依赖中只有一套游标和控制器，不能服务并发请求。
  // 每个请求独立读盘，且只读取已校验写入的分片，避免读到预分配的空洞。
  Stream<List<int>> _readReadyRange(
    DownloadFile file,
    int start,
    int end,
    int requestId,
    Completer<void> cancelled,
  ) async* {
    RandomAccessFile? access;
    var position = start;
    var lastPiece = -1;
    try {
      while (position < end) {
        final index = (file.offset + position) ~/ task.metaInfo.pieceLength;
        final piece = task.pieceManager?.pieces[index];
        if (piece == null || piece.end <= file.offset + position) {
          throw StateError('no torrent piece covering byte $position');
        }
        if (lastPiece != index) {
          _setRequestPriority(requestId, file, position, end);
          lastPiece = index;
        }
        final subpieceEnd = math.min(
          math.min(
            piece.offset +
                (((file.offset + position - piece.offset) ~/
                            piece.subPieceSize) +
                        1) *
                    piece.subPieceSize -
                file.offset,
            end,
          ),
          piece.end - file.offset,
        );
        if (!await _waitForRange(file, position, subpieceEnd, cancelled)) {
          return;
        }
        final chunkEnd = math.min(
          math.min(position + 128 * 1024, end),
          piece.end - file.offset,
        );
        final next = file.isRangeWritten(position, chunkEnd)
            ? chunkEnd
            : subpieceEnd;
        if (access == null) {
          access = await File(file.filePath).open(mode: FileMode.read);
          await access.setPosition(position);
        }
        final bytes = await access.read(next - position);
        if (bytes.length != next - position) {
          throw FileSystemException(
            'short read at $position: ${bytes.length}/${next - position}',
            file.filePath,
          );
        }
        position += bytes.length;
        yield bytes;
      }
    } finally {
      await access?.close();
    }
  }

  void _setRequestPriority(
    int requestId,
    DownloadFile file,
    int start,
    int end,
  ) {
    final pieceLength = task.metaInfo.pieceLength;
    final pieceCount = task.pieceManager?.pieces.length ?? 0;
    if (pieceLength <= 0 || pieceCount == 0) return;
    final first = (file.offset + start) ~/ pieceLength;
    final last = (file.offset + end - 1) ~/ pieceLength;
    final selected = <int>{};
    final fileFirst = file.offset ~/ pieceLength;
    final fileLast = (file.offset + file.length - 1) ~/ pieceLength;
    // 视频头和尾部索引应提前下载，不能等播放器探测到那里才排队。
    for (
      var i = fileFirst;
      i <= fileLast && i < fileFirst + 16 && i < pieceCount;
      i++
    ) {
      if (i >= 0 &&
          task.pieceManager?.pieces[i]?.isCompletelyWritten == false) {
        selected.add(i);
      }
    }
    for (
      var i = math.max(fileFirst, fileLast - 3);
      i <= fileLast && i < pieceCount;
      i++
    ) {
      if (i >= 0 &&
          task.pieceManager?.pieces[i]?.isCompletelyWritten == false) {
        selected.add(i);
      }
    }
    for (var i = first; i <= last && i < first + 16 && i < pieceCount; i++) {
      if (i >= 0 &&
          task.pieceManager?.pieces[i]?.isCompletelyWritten == false) {
        selected.add(i);
      }
    }
    for (var i = math.max(first, last - 3); i <= last && i < pieceCount; i++) {
      if (i >= 0 &&
          task.pieceManager?.pieces[i]?.isCompletelyWritten == false) {
        selected.add(i);
      }
    }
    _activePriorities[requestId] = selected;
    final union = <int>{for (final value in _activePriorities.values) ...value};
    task.pieceManager?.pieceSelector.setPriorityPieces(union);
  }

  void _releaseRequestPriority(int requestId) {
    if (_activePriorities.remove(requestId) == null) return;
    final union = <int>{for (final value in _activePriorities.values) ...value};
    task.pieceManager?.pieceSelector.setPriorityPieces(union);
    if (_activePriorities.isEmpty) onIdle?.call();
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final requestId = ++_nextRequestId;
    final cancelled = Completer<void>();
    _requests.add(cancelled);
    void cancel() {
      if (!cancelled.isCompleted) cancelled.complete();
    }

    unawaited(res.done.then((_) => cancel(), onError: (Object _) => cancel()));
    DownloadFile? servingFile;
    var headersSent = false;
    try {
      if (req.method != 'GET' && req.method != 'HEAD') {
        res.statusCode = HttpStatus.methodNotAllowed;
        res.headers.set(HttpHeaders.allowHeader, 'GET, HEAD');
        await res.close();
        return;
      }
      // HttpRequest.uri.path 保留了百分号编码（例如 %40），而种子元数据
      // 保存的是解码后的文件名。用 pathSegments 比较，避免视频 URL 404。
      final rel = req.uri.pathSegments.join('/');
      final model = task.metaInfo;
      var fm = task.fileManager;
      // streamUrl 只需等待 fileManager 非空即可返回，但恢复任务的文件
      // 列表可能还在异步建立；给 HTTP 首个 HEAD/GET 一个短暂窗口，避免
      // 播放器刚拿到地址就撞上临时 404。
      for (var i = 0; i < 20 && (fm == null || fm.files.isEmpty); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        fm = task.fileManager;
      }
      // URL 带有 fileIndex 时直接按引擎文件索引取文件。索引不受本地改名
      // 影响，因此新旧路径都能播放；没有索引的旧 URL 继续走路径匹配。
      var index =
          int.tryParse(req.uri.queryParameters['fileIndex'] ?? '') ?? -1;
      if (req.uri.queryParameters.containsKey('fileIndex') &&
          (index < 0 || fm == null || index >= fm.files.length)) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      if (index < 0 || fm == null || index >= fm.files.length) {
        index = -1;
      }
      if (index < 0 && fm != null) {
        // 先按引擎文件查找：torrentFilePath 不会因本地改名而改变，
        // filePath 则指向改名后的真实磁盘文件。
        for (var i = 0; i < fm.files.length; i++) {
          final file = fm.files[i];
          if (pathMatches(rel, file.torrentFilePath) ||
              pathMatches(rel, file.filePath) ||
              pathMatches(rel, _lastSegment(file.originalFileName))) {
            index = i;
            break;
          }
        }
      }
      if (index < 0) {
        index = model.files.indexWhere(
          (f) => pathMatches(rel, f.path) || pathMatches(rel, f.name),
        );
      }
      if (index < 0 && fm != null) {
        // 旧版本生成的 URL 没有 fileIndex，且 URL 中仍是原始文件名。
        // 文件改名后无法再按完整路径匹配；用目录后缀和扩展名做一次
        // 唯一候选回退，兼容已经被播放器缓存的旧地址。多个同扩展名
        // 文件时不猜，要求新 URL 的 fileIndex 来避免播错文件。
        final requestParent = _parentPath(rel);
        final requestExtension = _extension(rel);
        final candidates = <int>[];
        for (var i = 0; i < fm.files.length; i++) {
          final file = fm.files[i];
          if (requestExtension.isEmpty ||
              _extension(file.torrentFilePath) != requestExtension) {
            continue;
          }
          final parents = [
            _parentPath(file.torrentFilePath),
            _parentPath(file.filePath),
            _parentPath(file.originalFileName),
          ];
          if (parents.any((parent) => pathMatches(requestParent, parent))) {
            candidates.add(i);
          }
        }
        if (candidates.length == 1) index = candidates.single;
      }
      if (index < 0 || fm == null || index >= fm.files.length) {
        res.statusCode = HttpStatus.notFound;
        await res.close();
        return;
      }
      final file = fm.files[index];
      servingFile = file;
      final total = file.length;
      if (total <= 0) {
        res.statusCode = HttpStatus.serviceUnavailable;
        await res.close();
        return;
      }

      var start = 0;
      var end = total - 1;
      var partial = false;
      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        partial = true;
        final spec = rangeHeader.substring(6).split(',').first.trim();
        final dash = spec.indexOf('-');
        final s = dash > 0 ? int.tryParse(spec.substring(0, dash)) : null;
        final e = dash >= 0 && dash < spec.length - 1
            ? int.tryParse(spec.substring(dash + 1))
            : null;
        if (s == null && e != null) {
          if (e <= 0) {
            start = 1;
            end = 0;
          } else {
            start = math.max(0, total - e);
            end = total - 1;
          }
        } else if (s != null) {
          start = s;
          end = e == null ? total - 1 : math.min(e, total - 1);
        } else {
          start = 1;
          end = 0;
        }
      }
      if (start > end) {
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await res.close();
        return;
      }
      if (start < 0 || start >= total) {
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        res.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await res.close();
        return;
      }

      final length = end - start + 1;
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      res.headers.set(
        HttpHeaders.contentTypeHeader,
        lookupMimeType(_lastSegment(file.originalFileName)) ??
            'application/octet-stream',
      );
      if (partial) {
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$total',
        );
      }

      res.headers.set(HttpHeaders.contentLengthHeader, '$length');
      if (req.method == 'HEAD') {
        await res.close();
        return;
      }

      _setRequestPriority(requestId, file, start, end + 1);
      headersSent = true;
      await res.flush();
      await res.addStream(
        _readReadyRange(file, start, end + 1, requestId, cancelled),
      );
      await res.close();
    } catch (error, stack) {
      final readFailure =
          error is FileSystemException ||
          error is StateError ||
          error is TimeoutException;
      if (!_stopRequested && (readFailure || !cancelled.isCompleted)) {
        Log.error(
          '种子本地串流失败',
          '${req.method} ${req.uri}, range=${req.headers.value(HttpHeaders.rangeHeader)}, '
              'state=${task.state}, path=${servingFile?.filePath}, '
              'downloaded=${servingFile?.downloadedBytes}/${servingFile?.length}\n'
              '$error\n$stack',
        );
      }
      try {
        if (!headersSent) {
          res.statusCode = HttpStatus.internalServerError;
          res.contentLength = 0;
        }
        await res.close();
      } catch (_) {}
    } finally {
      cancel();
      _requests.remove(cancelled);
      _releaseRequestPriority(requestId);
    }
  }
}
