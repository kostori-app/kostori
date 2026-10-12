import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/database/download_database.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'blocks shared-piece deletion but permits files with independent pieces',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'kostori_torrent_delete_',
      );
      App.dataPath = root.path;
      const payload = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
      final info = Uint8List.fromList([
        ...ascii.encode(
          'd5:filesld6:lengthi2e4:pathl8:note.txteed6:lengthi6e'
          '4:pathl9:video.mp4eed6:lengthi4e4:pathl10:unused.txteee'
          '4:name4:pack12:piece lengthi4e6:pieces60:',
        ),
        ...sha1.convert(payload.sublist(0, 4)).bytes,
        ...sha1.convert(payload.sublist(4, 8)).bytes,
        ...sha1.convert(payload.sublist(8)).bytes,
        101,
      ]);
      final model = TorrentParser.parseFromInfoBytes(info);
      final note = File(p.join(root.path, 'pack', 'note.txt'));
      final video = File(p.join(root.path, 'pack', 'video.mp4'));
      final unused = File(p.join(root.path, 'pack', 'unused.txt'));
      await note.parent.create(recursive: true);
      await note.writeAsBytes(payload.sublist(0, 2));
      await video.writeAsBytes(payload.sublist(2, 8));
      await unused.writeAsBytes(payload.sublist(8));
      final state = await StateFileV2.getStateFile(root.path, model);
      await state.updateBitfield(0);
      await state.updateBitfield(1);
      await state.updateBitfield(2);
      await state.close();

      final job = TorrentJob(
        id: 'shared-piece-delete',
        magnet: 'magnet:?xt=urn:btih:${model.infoHash}',
        torrentPath: p.join(root.path, 'metadata.torrent'),
        savePath: root.path,
        createdAt: 0,
        hasMetadata: true,
        selectedFiles: [1],
        status: TorrentJobStatus.completed,
        totalDone: 6,
        totalWanted: 6,
        progress: 1,
      );
      await File(job.torrentPath).writeAsBytes(info);
      await DownloadDatabase.instance.saveJobJson([jsonEncode(job.toJson())]);
      final container = ProviderContainer();
      final manager = container.read(torrentManagerProvider.notifier);
      try {
        await manager.init();
        final restored = manager.jobs.single;

        await expectLater(
          manager.deleteFiles(restored, [0]),
          throwsA(isA<TorrentSharedPieceDeletionException>()),
        );

        expect(await note.exists(), isTrue);
        expect(await video.exists(), isTrue);
        expect(restored.totalDone, 6);
        expect(restored.progress, 1);
        expect(
          manager
              .engineOf(restored)!
              .fileManager!
              .localBitfield
              .completedPieces,
          [0, 1, 2],
        );

        await manager.deleteFiles(restored, [2]);
        expect(await unused.exists(), isFalse);
        expect(restored.totalDone, 6);
        expect(restored.progress, 1);
        await manager.remove(restored);
      } finally {
        container.dispose();
        await DownloadDatabase.instance.close();
        await root.delete(recursive: true);
      }
    },
  );
}
