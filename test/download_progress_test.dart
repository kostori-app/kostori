import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/download/download_manager.dart';
import 'package:kostori/services/download/download_task.dart';

DownloadTask _task({String url = 'https://example.com/video.mp4'}) =>
    DownloadTask(
      id: 'progress-test',
      title: 'Video',
      url: url,
      status: DownloadStatus.downloading,
      createdAt: DateTime(2026, 10, 9),
    );

void main() {
  test('206 缺少 Content-Length 时仍按 Content-Range 总大小计算进度', () {
    final range = parseDownloadRange(
      status: 206,
      contentRange: 'bytes 0-9999/10000',
      contentLength: -1,
    );
    final task = _task()..totalBytes = range.total;

    task.downloadedBytes = 2450;
    expect(task.byteProgress, closeTo(0.245, 0.000001));
    expect(task.hasKnownProgress, isTrue);

    task.downloadedBytes = 5000;
    expect(task.byteProgress, 0.5);
  });

  test('分段 Range 响应的长度不能替代完整文件大小', () {
    final range = parseDownloadRange(
      status: 206,
      contentRange: 'bytes 2000-4999/10000',
      contentLength: 3000,
    );
    final task = _task()
      ..totalBytes = range.total
      ..downloadedBytes = range.start + 1500;

    expect(task.byteProgress, 0.35);
    task.downloadedBytes = range.start + 3000;
    expect(task.byteProgress, 0.5);
  });

  test('续传响应没有长度时可使用之前确认的完整大小', () {
    final task = DownloadTask.fromJson((_task()..totalBytes = 10000).toJson())
      ..downloadedBytes = 6000;

    expect(task.byteProgress, 0.6);
    expect(task.hasKnownProgress, isTrue);
  });

  test('仅有已下载字节时进度未知，确认总大小后变为可计算', () {
    final task = _task()..downloadedBytes = 245500000;

    expect(task.byteProgress, isNull);
    expect(task.hasKnownProgress, isFalse);

    task.totalBytes = 500000000;
    expect(task.byteProgress, 0.491);
    expect(task.hasKnownProgress, isTrue);
  });

  test('HLS 可以用分片数确定进度，无需总字节数', () {
    final task = _task(url: 'https://example.com/index.m3u8')
      ..segTotal = 100
      ..segDone = 0;

    expect(task.byteProgress, isNull);
    expect(task.hasKnownProgress, isTrue);
  });

  test('FFmpeg 按媒体时间更新后，即使大小未知也显示百分比', () {
    final task = _task()..progress = 0.25;

    expect(task.byteProgress, isNull);
    expect(task.hasKnownProgress, isTrue);
  });
  test('HLS 时长可用于 FFmpeg 回退，持久化后仍保留', () {
    final task = _task(url: 'https://example.com/index.m3u8')
      ..mediaDurationMs = 600000;
    final restored = DownloadTask.fromJson(task.toJson());

    expect(task.hasKnownProgress, isTrue);
    expect(restored.mediaDurationMs, 600000);
    expect(restored.hasKnownProgress, isTrue);
    expect(restored.byteProgress, isNull);
  });
}
