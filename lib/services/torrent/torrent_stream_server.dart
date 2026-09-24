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

  int get port => _server?.port ?? 0;

  bool get running => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle, onError: (_) {});
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
  }

  Uri urlFor(TorrentFileEntry file) =>
      Uri.parse('http://127.0.0.1:$port/${Uri.encodeComponent(file.path)}');

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final raw = Uri.decodeComponent(req.uri.path);
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
        lookupMimeType(file.originalFileName) ?? 'application/octet-stream',
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

      // 提升请求范围对应分片的下载优先级（边下边播）
      final pieceLength = model.pieceLength;
      if (pieceLength > 0) {
        final sp = (file.offset + start) ~/ pieceLength;
        final ep = (file.offset + end) ~/ pieceLength;
        task.pieceManager?.pieceSelector.setPriorityPieces(
          {for (var i = sp; i <= ep; i++) i},
        );
      }

      final stream = file.createStream(start, end + 1);
      if (stream == null) {
        res.statusCode = HttpStatus.serviceUnavailable;
        await res.close();
        return;
      }
      await res.addStream(stream);
      await res.close();
    } catch (_) {
      try {
        await res.close();
      } catch (_) {}
    }
  }
}
