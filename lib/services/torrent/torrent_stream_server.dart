import 'dart:async';
import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:mime/mime.dart';

/// 基于 [TorrentTask] 的本地 HTTP Range 服务：一边下载一边播放。
///
/// 不用包内置的 `StreamingServer`（未导出、端口固定、多文件路径匹配依赖
/// `Platform.pathSeparator`，在 Windows 上会找不到文件），改为直接使用
/// `DownloadFile.createStream`，并按请求范围提升对应分片优先级。
class TorrentStreamServer {
  TorrentStreamServer(this.task);

  final TorrentTask task;

  HttpServer? _server;

  /// start() 的在途 Future：并发调用共享同一次绑定。
  ///
  /// 之前 `_server` 只在 await 之后才赋值，两个并发 `streamUrl` 会各自
  /// bind 一个端口，后一次赋值把前一个 server 直接丢掉 —— 端口一直被占用
  /// 且再也无法关闭。
  Future<void>? _starting;

  int get port => _server?.port ?? 0;

  bool get running => _server != null;

  Future<void> start() {
    if (_server != null) return Future.value();
    return _starting ??= _bind().whenComplete(() => _starting = null);
  }

  Future<void> _bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    // 等在途的 bind 结束再关，否则可能在 bind 完成后立刻又冒出一个端口
    await _starting;
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  Uri urlFor(TorrentFileEntry file) => urlForPath(
    port,
    file.path,
  ).replace(queryParameters: {'fileIndex': '${file.index}'});

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

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
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
          start = (total - e).clamp(0, total - 1);
          end = total - 1;
        } else {
          start = (s ?? 0).clamp(0, total - 1);
          if (e != null) end = e.clamp(start, total - 1);
        }
      }
      if (start > end) {
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

      // 提升请求范围对应分片的下载优先级（边下边播）
      final pieceLength = model.pieceLength;
      final pieceCount = model.pieces?.length;
      if (pieceLength > 0 && pieceCount != null && pieceCount > 0) {
        final sp = (file.offset + start) ~/ pieceLength;
        final ep = (file.offset + end) ~/ pieceLength;
        task.pieceManager?.pieceSelector.setPriorityPieces({
          // 末尾字节可能落在不存在的下一片上，钳制到有效范围
          for (var i = sp; i <= ep && i < pieceCount; i++) i,
        });
      }

      // 必须先拿到 stream 再写响应头：Content-Length 一旦提交就不能再改成
      // 503/500，之前「设了长度再降级状态码」会让 mpv/libcurl
      // 干等一个不会到来的响应体或直接报协议错误。
      Stream<List<int>>? stream;
      if (req.method != 'HEAD') {
        // 已完整落盘的文件不需要再经过 dtorrent 的分片请求队列。恢复任务
        // 或本地重命名后，分片状态可能尚未重新挂载，createStream 会返回
        // 空流，mpv 就只报 Failed to open；直接读取磁盘文件能稳定支持
        // Range 播放，同时保留未完成文件的边下边播路径。
        final local = File(file.filePath);
        final piecesComplete =
            file.pieces.isNotEmpty &&
            file.pieces.every((piece) => piece.isCompletelyWritten);
        if ((file.downloadedBytes >= total || piecesComplete) &&
            await local.exists()) {
          stream = local.openRead(start, end + 1);
        }
        stream ??= file.createStream(start, end + 1);
      }
      if (req.method != 'HEAD' && stream == null) {
        res.statusCode = HttpStatus.serviceUnavailable;
        res.headers.contentLength = 0;
        await res.close();
        return;
      }
      res.headers.set(HttpHeaders.contentLengthHeader, '$length');
      if (stream == null) {
        await res.close();
        return;
      }
      await res.addStream(stream);
      await res.close();
    } catch (error, stack) {
      Log.error('种子本地串流失败', '$error\n$stack');
      try {
        // 响应头可能已提交，这里只能尽力收尾
        await res.close();
      } catch (_) {}
    }
  }
}
