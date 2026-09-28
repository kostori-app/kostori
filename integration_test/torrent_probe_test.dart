import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// 私人磁力不入库：通过 --dart-define=TORRENT_MAGNET=... 传入，未提供则跳过。
const String _magnet = String.fromEnvironment('TORRENT_MAGNET');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('probe: magnet metadata + correct infohash + download', (
    tester,
  ) async {
    if (_magnet.isEmpty) {
      print('probe: TORRENT_MAGNET not provided, skipping');
      return;
    }
    final dir = Directory.systemTemp.createTempSync('torrent_probe');

    final downloader = MetadataDownloader.fromMagnet(_magnet);
    final completer = Completer<Uint8List>();
    downloader.createListener()
      ..on<MetaDataDownloadComplete>((event) {
        completer.complete(Uint8List.fromList(event.data));
      })
      ..on<MetaDataDownloadFailed>((event) {
        if (!completer.isCompleted) completer.completeError(event.error);
      });
    unawaited(downloader.startDownload());

    final infoBytes = await completer.future.timeout(
      const Duration(minutes: 3),
    );
    await downloader.stop();

    final magnet = MagnetParser.parse(_magnet);
    final model = TorrentParser.parseFromInfoBytes(
      infoBytes,
      announces: magnet?.trackers ?? const [],
    );
    print('probe: name=${model.name} files=${model.files.length}');
    print(
      'probe: infohash magnet=${magnet?.infoHashString} model=${model.infoHash}',
    );

    final task = TorrentTask.newTask(
      model,
      dir.path,
      true,
      null,
      null,
      SequentialConfig.forVideoStreaming(),
    );
    await task.start();
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(const Duration(seconds: 4));
      final files = task.fileManager?.files ?? const [];
      print(
        'probe[$i]: peers=${task.connectedPeersNumber} '
        'seeds=${task.seederNumber} '
        'downloaded=${task.downloaded} '
        'prog=${(task.progress * 100).toStringAsFixed(1)}%',
      );
      if (files.isNotEmpty) {
        final f = files.first;
        print(
          '  ${f.torrentFilePath} '
          '${f.downloadedBytes}/${f.length} '
          '(${f.downloadProgress.toStringAsFixed(1)}%)',
        );
      }
      if (task.progress > 0) break;
    }
    await task.stop();
    await task.dispose();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
