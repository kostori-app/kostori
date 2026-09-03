part of 'video_clip_editor.dart';

/// 预览窗口下载器：mp4 / HLS 都只用 ffmpeg 截取目标位置上下 3 分钟窗口，
/// 输出本地 mp4。失败返回 null（调用方回退远程流播）。
///
/// HLS 直接交给 ffmpeg 处理：它能自己下载分片并按 #EXT-X-KEY 解密
/// （手动下载分片会拿到密文，拼接后无法播放），且只拉取窗口所需数据。
class _HlsDownloader {
  /// 下载 [startMs, endMs] 区间到本地 mp4。失败返回 null。
  static Future<String?> downloadWindow({
    required String url,
    required Map<String, String> headers,
    required int startMs,
    required int endMs,
    void Function(double progress, String status)? onProgress,
  }) async {
    try {
      onProgress?.call(0, t.downloadingPreviewClip);
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/kostori_window_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await FfmpegEncoder.cutWindow(
        inputUrl: url,
        outputPath: outPath,
        startMs: startMs,
        endMs: endMs,
        headers: headers,
        proxyUrl: await getProxy(),
        onProgress: (p) => onProgress?.call(p, t.downloadingPreviewClip),
      );
      final f = File(outPath);
      if (await f.exists() && await f.length() > 0) return outPath;
      return null;
    } catch (e, st) {
      Log.error('HlsDownloader', 'window download failed: $e\n$st');
      return null;
    }
  }

  static bool _isHls(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('m3u8');
  }
}