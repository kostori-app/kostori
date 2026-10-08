import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_stream_server.dart';
import 'package:path/path.dart' as p;

void main() {
  const pieceLength = 32768;
  const fileLength = pieceLength * 6 + 18000;
  final payload = Uint8List.fromList(
    List.generate(fileLength, (i) => (i * 31 + 17) % 251),
  );
  late Directory directory;
  late TorrentTask task;
  late TorrentStreamServer server;
  late HttpClient client;
  late Uri url;
  late DownloadFile file;

  void completePiece(int index) {
    final piece = task.pieceManager!.pieces[index]!;
    for (var start = 0; start < piece.byteLength; start += 16384) {
      piece.subPieceReceived(
        start,
        Uint8List(math.min(16384, piece.byteLength - start)),
      );
    }
    piece.writeComplete();
    file.recalculateDownloadedBytes();
  }

  void completeAll() {
    for (final index in task.pieceManager!.pieces.keys) {
      completePiece(index);
    }
  }

  Future<HttpClientResponse> request({
    String? range,
    String method = 'GET',
  }) async {
    final req = await client.openUrl(method, url);
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    return req.close().timeout(const Duration(seconds: 3));
  }

  Future<List<int>> body(HttpClientResponse response) => response
      .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk))
      .timeout(const Duration(seconds: 3));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kostori_stream_');
    // A nonzero, unaligned file offset and a short final piece exercise the
    // boundaries that the dependency's createStream byte calculation mishandles.
    final info = Uint8List.fromList([
      ...ascii.encode(
        'd5:filesld6:lengthi17e4:pathl8:note.txteed6:lengthi${fileLength}e'
        '4:pathl9:video.mp4eee4:name4:pack12:piece lengthi${pieceLength}e'
        '6:pieces${((fileLength + 17 + pieceLength - 1) ~/ pieceLength) * 20}:',
      ),
      ...List<int>.filled(
        ((fileLength + 17 + pieceLength - 1) ~/ pieceLength) * 20,
        0,
      ),
      101,
    ]);
    final model = TorrentParser.parseFromInfoBytes(info);
    task = TorrentTask.newTask(model, directory.path, true);
    await task.prepare();
    file = task.fileManager!.files[1];
    await File(file.filePath).parent.create(recursive: true);
    await File(file.filePath).writeAsBytes(payload);
    server = TorrentStreamServer(task);
    await server.start();
    client = HttpClient()..findProxy = (_) => 'DIRECT';
    url = server.urlFor(
      TorrentFileEntry(
        index: 1,
        name: 'video.mp4',
        path: 'pack/video.mp4',
        size: fileLength,
        downloaded: 0,
        isStreamable: true,
      ),
    );
  });

  tearDown(() async {
    client.close(force: true);
    await server.stop();
    await task.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'HEAD and parallel ranges return exact bytes at offset and tail boundaries',
    () async {
      completeAll();
      final head = await request(method: 'HEAD');
      expect(head.statusCode, HttpStatus.ok);
      expect(head.contentLength, fileLength);
      expect(head.headers.contentType?.mimeType, 'video/mp4');
      expect(await body(head), isEmpty);
      await Future.wait([
        for (final range in [
          (0, 16),
          (32740, 32800),
          (fileLength - 110, fileLength - 1),
        ])
          () async {
            final response = await request(
              range: 'bytes=${range.$1}-${range.$2}',
            );
            expect(response.statusCode, HttpStatus.partialContent);
            expect(
              response.headers.value(HttpHeaders.contentRangeHeader),
              'bytes ${range.$1}-${range.$2}/$fileLength',
            );
            expect(
              await body(response),
              payload.sublist(range.$1, range.$2 + 1),
            );
          }(),
      ]);
      expect(await body(await request()), payload);
      expect(
        await body(await request(range: 'bytes=-110')),
        payload.sublist(fileLength - 110),
      );
    },
  );

  test('waiting for the first piece does not block or cancel a concurrent tail probe', () async {
    completePiece(task.pieceManager!.pieces.keys.last);
    var finished = false;
    final first = request(range: 'bytes=0-127').then(body).then((bytes) {
      finished = true;
      return bytes;
    });
    expect(
      await body(await request(range: 'bytes=${fileLength - 50}-')),
      payload.sublist(fileLength - 50),
    );
    expect(
      finished,
      isFalse,
      reason: 'preallocated bytes are not verified pieces',
    );
    completePiece(0);
    expect(await first, payload.sublist(0, 128));
  });

  test('serves verified file bytes from an incomplete shared piece', () async {
    final piece = task.pieceManager!.pieces[0]!;
    piece.subPieceReceived(0, Uint8List(16384));
    piece.writeComplete();

    expect(piece.isCompletelyWritten, isFalse);
    expect(file.isRangeWritten(0, 1000), isTrue);
    expect(file.isRangeWritten(20000, 21000), isFalse);

    final response = await request(range: 'bytes=0-999');
    expect(response.statusCode, HttpStatus.partialContent);
    expect(await body(response), payload.sublist(0, 1000));
  });

  test(
    'renamed paths work through both the index route and legacy path',
    () async {
      completeAll();
      await file.moveToPath(p.join(directory.path, 'renamed video.mp4'));
      expect(
        await body(await request(range: 'bytes=13-95')),
        payload.sublist(13, 96),
      );
      url = TorrentStreamServer.urlForPath(server.port, file.torrentFilePath);
      expect(
        await body(await request(range: 'bytes=-100')),
        payload.sublist(fileLength - 100),
      );
    },
  );

  test(
    'out of bounds and reversed ranges return 416 instead of clamped bytes',
    () async {
      for (final range in [
        'bytes=$fileLength-',
        'bytes=50-20',
        'bytes=-0',
        'bytes=wrong',
      ]) {
        final response = await request(range: range);
        expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
        expect(
          response.headers.value(HttpHeaders.contentRangeHeader),
          'bytes */$fileLength',
        );
        expect(await body(response), isEmpty);
      }
    },
  );

  test(
    'stop while binding closes the server and does not resurrect a port',
    () async {
      await server.stop();
      final starting = server.start();
      await server.stop();
      await starting;
      expect(server.running, isFalse);
      expect(server.port, 0);
    },
  );

  test('stopping wakes a range waiting for unavailable pieces', () async {
    final read = request(range: 'bytes=0-127').then(body);
    final check = expectLater(read, throwsA(isA<HttpException>()));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await server.stop();
    await check;
  });
}
