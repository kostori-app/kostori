import 'package:flutter_test/flutter_test.dart';
import 'package:kostori/utils/ffmpeg_progress.dart';

void main() {
  test('Windows 日志把时长和时间戳拆成任意数据块时仍能计算进度', () {
    final tracker = FfmpegProgressTracker(totalMs: 0, inferDuration: true);
    for (final char in 'Duration: 00:10:00.00, start: 0.0\n'.split('')) {
      tracker.addLog(char);
    }
    for (final char in 'frame=1 time=00:02:30.00 bitrate=1000\r'.split('')) {
      tracker.addLog(char);
    }
    expect(tracker.progress, 0.25);
  });

  test('同一个日志块含多条统计时使用最新时间', () {
    final tracker = FfmpegProgressTracker(totalMs: 0, inferDuration: true);
    tracker.addLog(
      'Duration: 00:10:00.00, start: 0.0\n'
      'time=00:01:00.00 bitrate=1000\r'
      'time=00:05:00.00 bitrate=1000\r',
    );
    expect(tracker.progress, 0.5);
  });

  test('播放列表已经给出总时长时，FFmpeg 报 N/A 也有百分比', () {
    final tracker = FfmpegProgressTracker(totalMs: 600000, inferDuration: true);
    tracker.addLog('Duration: N/A, start: 0.0\n');
    tracker.updateTime(150000);
    expect(tracker.progress, 0.25);
  });

  test('移动端统计先于总时长日志到达时保留已接收的时间', () {
    final tracker = FfmpegProgressTracker(totalMs: 0, inferDuration: true);
    tracker.updateTime(150000);
    expect(tracker.progress, isNull);
    tracker.addLog('Duration: 00:10:00.00, start: 0.0\n');
    expect(tracker.progress, 0.25);
  });

  test('没有总时长时不生成虚假的百分比', () {
    final tracker = FfmpegProgressTracker(totalMs: 0, inferDuration: true);
    tracker.addLog(
      'Duration: N/A, start: 0.0\n'
      'time=00:02:30.00 bitrate=1000\r',
    );
    expect(tracker.progress, isNull);
  });

  test('读取很长的日志后仍能拼接跨数据块的时长', () {
    final tracker = FfmpegProgressTracker(totalMs: 0, inferDuration: true);
    tracker.addLog('${List.filled(10000, 'x').join()}\nDura');
    tracker.addLog('tion: 00:10:00.00, start: 0.0\n');
    tracker.updateTime(150000);
    expect(tracker.progress, 0.25);
  });

  test('统计时间回退或非法时进度不倒退', () {
    final tracker = FfmpegProgressTracker(totalMs: 600000, inferDuration: true);
    tracker.updateTime(150000);
    for (final time in [100000.0, -1.0, double.nan, double.infinity]) {
      tracker.updateTime(time);
    }
    expect(tracker.progress, 0.25);
  });

  test('编码截取窗口使用指定时长，完整输入时长不覆盖窗口', () {
    final tracker = FfmpegProgressTracker(totalMs: 30000, inferDuration: false);
    tracker.addLog(
      'Duration: 00:10:00.00, start: 0.0\n'
      'time=00:00:15.00 bitrate=1000\r',
    );
    expect(tracker.progress, 0.5);
  });
}
