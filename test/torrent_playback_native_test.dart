import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/pages/download/local_player_controller.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_stream_server.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  final library = Platform.environment['KOSTORI_MPV_LIBRARY'];
  final fixture = Platform.environment['KOSTORI_VIDEO_FIXTURE'];

  test(
    'mpv opens an incomplete video when the first piece arrives after 7 seconds',
    () async {
      MediaKit.ensureInitialized(libmpv: library);
      NativePlayer.test = true;
      final payload = await File(fixture!).readAsBytes();
      const pieceLength = 32768;
      final pieceCount = (payload.length + pieceLength - 1) ~/ pieceLength;
      expect(pieceCount, greaterThan(32));
      final directory = await Directory.systemTemp.createTemp('kostori_mpv_');
      final info = Uint8List.fromList([
        ...ascii.encode(
          'd6:lengthi${payload.length}e4:name9:video.mp412:piece lengthi${pieceLength}e'
          '6:pieces${pieceCount * 20}:',
        ),
        ...List<int>.filled(pieceCount * 20, 0),
        101,
      ]);
      final task = TorrentTask.newTask(
        TorrentParser.parseFromInfoBytes(info),
        directory.path,
        true,
      );
      await task.prepare();
      final file = task.fileManager!.files.single;
      await File(file.filePath).writeAsBytes(payload);
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

      for (var index = 1; index < pieceCount; index++) {
        if (index != pieceCount ~/ 2) completePiece(index);
      }
      final server = TorrentStreamServer(task);
      await server.start();
      final url = server
          .urlFor(
            TorrentFileEntry(
              index: 0,
              name: 'video.mp4',
              path: 'video.mp4',
              size: payload.length,
              downloaded: file.downloadedBytes,
              isStreamable: true,
            ),
          )
          .toString();
      final player = Player(
        configuration: const PlayerConfiguration(logLevel: MPVLogLevel.v),
      );
      final logs = <String>[];
      final errors = <String>[];
      final logSubscription = player.stream.log.listen(
        (log) => logs.add('${log.prefix}: ${log.text}'),
      );
      final errorSubscription = player.stream.error.listen(errors.add);
      final timer = Timer(const Duration(seconds: 7), () => completePiece(0));
      final watch = Stopwatch()..start();
      try {
        final native = player.platform as NativePlayer;
        for (final entry in localPlaybackNetworkProperties(url).entries) {
          await native.setProperty(entry.key, entry.value);
        }
        final duration = player.stream.duration.firstWhere(
          (value) => value > Duration.zero,
        );
        final playing = player.stream.position.firstWhere(
          (value) => value > const Duration(milliseconds: 200),
        );
        await player.open(Media(url), play: true);
        await duration.timeout(const Duration(seconds: 20));
        await playing.timeout(const Duration(seconds: 10));
        expect(watch.elapsed, greaterThan(const Duration(seconds: 6)));
        expect(file.completed, isFalse);
        expect(errors, isEmpty, reason: logs.join('\n'));
      } finally {
        timer.cancel();
        await player.dispose();
        await logSubscription.cancel();
        await errorSubscription.cancel();
        await server.stop();
        await task.dispose();
        await directory.delete(recursive: true);
        NativePlayer.test = false;
      }
    },
    skip: library == null || fixture == null
        ? 'Set KOSTORI_MPV_LIBRARY and KOSTORI_VIDEO_FIXTURE to run native playback.'
        : false,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
