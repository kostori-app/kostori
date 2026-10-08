import 'package:dtorrent_task_v2/dtorrent_task_v2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/torrent/torrent_job.dart';
import 'package:kostori/services/torrent/torrent_manager.dart';

TorrentJob _completedJob() => TorrentJob(
  id: 'completed',
  name: 'completed-video',
  magnet: '',
  torrentPath: '',
  savePath: '',
  createdAt: 0,
  hasMetadata: true,
  status: TorrentJobStatus.completed,
  progress: 1,
  totalDone: 4,
  totalWanted: 4,
);

void main() {
  test('legacy completed and paused jobs migrate without resuming seeding', () {
    final json = _completedJob().toJson()
      ..['status'] = 'paused'
      ..remove('seedingPaused');
    final restored = TorrentJob.fromJson(json);
    expect(restored.status, TorrentJobStatus.completed);
    expect(restored.seedingPaused, isTrue);
    expect(TorrentJob.fromJson(restored.toJson()).seedingPaused, isTrue);

    json['totalDone'] = 2;
    json['progress'] = 0.5;
    expect(TorrentJob.fromJson(json).status, TorrentJobStatus.paused);
    json['progress'] = 1;
    expect(TorrentJob.fromJson(json).status, TorrentJobStatus.paused);
    json['totalWanted'] = 0;
    json['selectedFiles'] = [kTorrentNoFile];
    expect(TorrentJob.fromJson(json).status, TorrentJobStatus.paused);
  });

  test('an incomplete torrent never rounds its percentage up to 100', () {
    expect(torrentProgressPercent(1363 / 1364), '99.9');
    expect(torrentProgressPercent(0.99999), '99.9');
    expect(torrentProgressPercent(1), '100.0');
  });

  test('completed content remains completed when seeding is stopped', () {
    final job = _completedJob()..seedingPaused = true;
    expect(job.isFinished, isTrue);
    expect(job.hasCompletedDownload, isTrue);
    expect(TorrentManager.needsKeepAlive(job, TaskState.paused), isFalse);
    expect(TorrentManager.needsKeepAlive(job, TaskState.running), isFalse);
    job.seedingPaused = false;
    expect(TorrentManager.needsKeepAlive(job, TaskState.running), isTrue);
  });

  test('incomplete paused content remains in the paused category', () {
    final job = TorrentJob(
      id: 'partial',
      magnet: '',
      torrentPath: '',
      savePath: '',
      createdAt: 0,
      hasMetadata: true,
      status: TorrentJobStatus.paused,
      progress: 0.5,
      totalDone: 2,
      totalWanted: 4,
    );
    expect(job.isFinished, isFalse);
    expect(job.hasCompletedDownload, isFalse);
    expect(job.seedingPaused, isFalse);
  });
}
