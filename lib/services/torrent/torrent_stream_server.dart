import 'dart:async';
import 'dart:io';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
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

  Uri urlFor(TorrentFileEntry file) => Uri.parse(
    // 分段编码，保留种子内路径的 '/' 分隔语义
    'http://127.0.0.1:$port/${file.path.split('/').map(Uri.encodeComponent).join('/')}',
  );

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

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      // req.uri.path 已经过 Uri 解析解码，不能再解一次：
      // 路径含 '%'（如 100%.mkv）时二次解码会抛 FormatException，
      // 结果是连接被直接关闭、连 404 都没有。
      final raw = req.uri.path;
      final rel = raw.startsWith('/') ? raw.substring(1) : raw;
      final model = task.metaInfo;
      var index = model.files.indexWhere((f) => f.path == rel);
      if (index < 0) {
        index = model.files.indexWhere((f) => f.name == rel);
      }
      final fm = task.fileManager;
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
      final stream = (req.method == 'HEAD')
          ? null
          : file.createStream(start, end + 1);
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
    } catch (_) {
      try {
        // 响应头可能已提交，这里只能尽力收尾
        await res.close();
      } catch (_) {}
    }
  }
}
