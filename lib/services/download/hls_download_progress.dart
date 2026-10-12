/// HLS 按完成分片和正在接收的分片比例计算进度。
class HlsDownloadProgress {
  HlsDownloadProgress(this.totalSegments);

  final int totalSegments;
  final Set<int> _completed = {};
  final Map<int, double> _receiving = {};

  int get completedSegments => _completed.length;

  double get progress {
    if (totalSegments <= 0) return 0;
    final partial = _receiving.values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return ((_completed.length + partial) / totalSegments).clamp(0.0, 1.0);
  }

  void updateSegment(
    int index, {
    required int receivedBytes,
    required int totalBytes,
  }) {
    if (_completed.contains(index)) return;
    // 收齐响应还需校验落盘，校验成功前不能计为完成。
    _receiving[index] = totalBytes > 0
        ? (receivedBytes / totalBytes).clamp(0.0, 0.99)
        : 0;
  }

  void completeSegment(int index) {
    _receiving.remove(index);
    _completed.add(index);
  }

  void discardSegment(int index) => _receiving.remove(index);
}

/// 完整 VOD 播放列表的时长；直播窗口或无效时长不能作为总时长。
int hlsPlaylistDurationMs(String content) {
  final lines = content.split('\n').map((line) => line.trim()).toList();
  if (!lines.contains('#EXT-X-ENDLIST')) return 0;
  var seconds = 0.0;
  for (final line in lines) {
    if (!line.startsWith('#EXTINF:')) continue;
    final duration = double.tryParse(line.substring(8).split(',').first.trim());
    if (duration == null || !duration.isFinite || duration <= 0) return 0;
    seconds += duration;
  }
  return seconds.isFinite ? (seconds * 1000).round() : 0;
}
