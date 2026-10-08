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
    'restores lost completion bits and rechecks renamed selected files',
    () async {
      final root = await Directory.systemTemp.createTemp('kostori_recheck_');
      App.dataPath = root.path;
      const payload = [1, 2, 3, 4, 5, 6, 7, 8];
      final info = Uint8List.fromList([
        ...ascii.encode(
          'd5:filesld6:lengthi2e4:pathl8:note.txteed6:lengthi6e'
          '4:pathl9:video.mp4eee4:name4:pack12:piece lengthi4e6:pieces40:',
        ),
        ...sha1.convert(payload.sublist(0, 4)).bytes,
        ...sha1.convert(payload.sublist(4)).bytes,
        101,
      ]);
      final model = TorrentParser.parseFromInfoBytes(info);
      final note = File(p.join(root.path, 'pack', 'note.txt'));
      final video = File(p.join(root.path, 'pack', 'renamed.mp4'));
      await note.parent.create(recursive: true);
      await note.writeAsBytes(payload.sublist(0, 2));
      await video.writeAsBytes(payload.sublist(2));
      await File(p.join(root.path, '${model.infoHash}.bt.paths.json'))
          .writeAsString(jsonEncode({model.files[1].path: video.path}));
      final state = await StateFileV2.getStateFile(root.path, model);
      await state.updateBitfield(0);
      await state.close();
      final job = TorrentJob(
        id: 'completed',
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
        seedingPaused: true,
      );
      await File(job.torrentPath).writeAsBytes(info);
      await DownloadDatabase.instance.saveJobJson([jsonEncode(job.toJson())]);
      final container = ProviderContainer();
      final manager = container.read(torrentManagerProvider.notifier);
      try {
        await manager.init();
        final restored = manager.jobs.single;
        expect(restored.hasCompletedDownload, isTrue);
        expect(
          manager
              .engineOf(restored)!
              .fileManager!
              .localBitfield
              .completedPieces,
          [0, 1],
        );
        expect(manager.filesOf(restored)[1].localPath, video.path);
        expect(restored.status, TorrentJobStatus.completed);
        expect(restored.seedingPaused, isTrue);

        await video.writeAsBytes([3, 4, 99, 6, 7, 8]);
        await manager.recheck(restored);
        expect(restored.totalDone, 2);
        expect(restored.hasCompletedDownload, isFalse);
        expect(restored.status, TorrentJobStatus.paused);
        manager.pause(restored);
        expect(restored.progress, lessThan(1));
        expect(restored.isChecking, isFalse);
        await manager.remove(restored);
      } finally {
        container.dispose();
        await DownloadDatabase.instance.close();
        await root.delete(recursive: true);
      }
    },
  );
}
