import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/services/download/hls_download_progress.dart';

void main() {
  test('并发分片尚未完成时，收到的数据也能推进进度', () {
    final progress = HlsDownloadProgress(4);
    progress.updateSegment(0, receivedBytes: 500, totalBytes: 1000);
    progress.updateSegment(1, receivedBytes: 1000, totalBytes: 5000);

    expect(progress.completedSegments, 0);
    expect(progress.progress, closeTo(0.175, 0.000001));
  });

  test('分片重试撤回该片的临时进度，不影响成功分片', () {
    final progress = HlsDownloadProgress(4)..completeSegment(0);
    progress.updateSegment(1, receivedBytes: 700, totalBytes: 1000);
    expect(progress.progress, closeTo(0.425, 0.000001));

    progress.discardSegment(1);
    expect(progress.progress, 0.25);
    progress.updateSegment(1, receivedBytes: 100, totalBytes: 1000);
    expect(progress.progress, closeTo(0.275, 0.000001));
    progress.completeSegment(1);
    expect(progress.progress, 0.5);
  });

  test('断点恢复时已有分片与新分片的进度一起计入', () {
    final progress = HlsDownloadProgress(4)
      ..completeSegment(0)
      ..completeSegment(1);
    progress.updateSegment(2, receivedBytes: 500, totalBytes: 1000);
    expect(progress.completedSegments, 2);
    expect(progress.progress, 0.625);

    progress.completeSegment(1);
    expect(progress.progress, 0.625);
  });

  test('分片长度未知时，仅把验证成功的分片计入进度', () {
    final progress = HlsDownloadProgress(4)..completeSegment(0);
    progress.updateSegment(1, receivedBytes: 1000, totalBytes: -1);
    expect(progress.progress, 0.25);

    progress.completeSegment(1);
    expect(progress.progress, 0.5);
  });

  test('最后一片收齐后仍需落盘校验，成功前进度小于 100%', () {
    final progress = HlsDownloadProgress(2)..completeSegment(0);
    progress.updateSegment(1, receivedBytes: 1000, totalBytes: 1000);
    expect(progress.progress, lessThan(1));
    expect(progress.completedSegments, 1);

    progress.completeSegment(1);
    expect(progress.progress, 1);
    expect(progress.completedSegments, 2);
  });

  test('完整 fMP4 播放列表汇总小数时长，不把初始化分片计入', () {
    const playlist =
        '#EXTM3U\r\n'
        '#EXT-X-MAP:URI="init.mp4"\r\n'
        '#EXTINF:8.25,\r\na.m4s\r\n'
        '#EXTINF:1.125,title\r\nb.m4s\r\n'
        '#EXT-X-ENDLIST\r\n';
    expect(hlsPlaylistDurationMs(playlist), 9375);
  });

  test('直播窗口和主播放列表没有可用的总时长', () {
    expect(hlsPlaylistDurationMs('#EXTM3U\n#EXTINF:10,\na.ts\n'), 0);
    expect(
      hlsPlaylistDurationMs(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000\na.m3u8\n',
      ),
      0,
    );
  });

  test('分片时长非法时不能用部分时长冒充总时长', () {
    for (final duration in ['NaN', 'Infinity', '-1', 'bad']) {
      final playlist =
          '#EXTM3U\n#EXTINF:10,\na.ts\n#EXTINF:$duration,\nb.ts\n#EXT-X-ENDLIST\n';
      expect(hlsPlaylistDurationMs(playlist), 0);
    }
  });
}
