/// 拼接 FFmpeg 日志，并结合输入时长或移动端统计计算进度。
class FfmpegProgressTracker {
  FfmpegProgressTracker({required int totalMs, required bool inferDuration})
    : this._(totalMs, inferDuration);

  FfmpegProgressTracker._(this._totalMs, this.inferDuration);

  final bool inferDuration;
  int _totalMs;
  double _timeMs = 0;
  String _pending = '';

  static final _durationPattern = RegExp(
    r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)(?=[,\s])',
  );
  static final _timePattern = RegExp(
    r'time=\s*(\d+):(\d+):(\d+(?:\.\d+)?)(?=[,\s])',
  );

  double? get progress => _totalMs > 0 && _timeMs > 0
      ? (_timeMs / _totalMs).clamp(0.0, 0.99)
      : null;

  void addLog(String text) {
    _pending += text;
    if (inferDuration && _totalMs <= 0) {
      for (final duration in _durationPattern.allMatches(_pending)) {
        final milliseconds = _timestampMs(duration);
        if (milliseconds.isFinite && milliseconds > 0) {
          _totalMs = milliseconds.round();
          break;
        }
      }
    }
    // 一次读取可能包含多条统计；取最新的媒体时间，避免一直读到第一条。
    for (final time in _timePattern.allMatches(_pending)) {
      updateTime(_timestampMs(time));
    }
    // 只保留最近的日志尾部，用于拼接跨数据块的时间戳。
    if (_pending.length > 4096) {
      _pending = _pending.substring(_pending.length - 4096);
    }
  }

  void updateTime(double milliseconds) {
    if (milliseconds.isFinite && milliseconds > _timeMs) {
      _timeMs = milliseconds;
    }
  }

  static double _timestampMs(RegExpMatch match) =>
      int.parse(match.group(1)!) * 3600000 +
      int.parse(match.group(2)!) * 60000 +
      double.parse(match.group(3)!) * 1000;
}
