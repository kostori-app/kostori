import 'dart:convert';
import 'dart:typed_data';

import 'package:kostori/network/app_dio.dart';
import 'package:media_kit/media_kit.dart';

/// 视频地址类型（按响应头 / 响应体特征 / 扩展名推断）
enum VideoUrlKind {
  hls,
  dash,
  mp4,
  webm,
  mkv,
  flv,
  mpegts,
  audio,
  image,
  html,
  unknown,
}

extension VideoUrlKindX on VideoUrlKind {
  String get label => switch (this) {
    VideoUrlKind.hls => 'HLS (m3u8)',
    VideoUrlKind.dash => 'DASH (mpd)',
    VideoUrlKind.mp4 => 'MP4',
    VideoUrlKind.webm => 'WebM',
    VideoUrlKind.mkv => 'Matroska (mkv)',
    VideoUrlKind.flv => 'FLV',
    VideoUrlKind.mpegts => 'MPEG-TS',
    VideoUrlKind.audio => 'Audio',
    VideoUrlKind.image => 'Image',
    VideoUrlKind.html => 'HTML',
    VideoUrlKind.unknown => 'Unknown',
  };

  /// 是否是可播放的视频类型（播放列表也算）
  bool get playable => switch (this) {
    VideoUrlKind.hls ||
    VideoUrlKind.dash ||
    VideoUrlKind.mp4 ||
    VideoUrlKind.webm ||
    VideoUrlKind.mkv ||
    VideoUrlKind.flv ||
    VideoUrlKind.mpegts => true,
    _ => false,
  };

  /// 是否是播放列表（需要再解析才能拿到真实分片）
  bool get playlist =>
      this == VideoUrlKind.hls || this == VideoUrlKind.dash;
}

/// 地址探测结果：只回答「能不能拿到、是不是视频、是什么类型」这类调试问题，
/// 不做完整下载（只取前若干字节）。
class VideoProbeResult {
  const VideoProbeResult({
    required this.url,
    this.finalUrl = '',
    this.redirects = const [],
    this.statusCode,
    this.statusMessage,
    this.contentType,
    this.contentLength,
    this.acceptRanges,
    this.elapsedMs = 0,
    this.sample,
    this.error,
    this.kind = VideoUrlKind.unknown,
  });

  /// 原始地址
  final String url;

  /// 经过重定向后的最终地址
  final String finalUrl;

  /// 重定向链（含原始地址）
  final List<String> redirects;

  final int? statusCode;
  final String? statusMessage;
  final String? contentType;
  final int? contentLength;
  final String? acceptRanges;
  final int elapsedMs;

  /// 响应体前若干字节（用于类型判断与预览）
  final Uint8List? sample;

  final String? error;
  final VideoUrlKind kind;

  /// 请求是否发出并拿到响应
  bool get reachable => error == null && statusCode != null;

  /// 是否 2xx/3xx
  bool get ok => reachable && statusCode! >= 200 && statusCode! < 400;

  /// 是否支持分段（拖动进度条的关键）
  bool get supportsRange =>
      (acceptRanges ?? '').toLowerCase().contains('bytes');

  /// 是否是 HTML（通常意味着被拦截、需要 Referer/Cookie 或地址已失效）
  bool get looksLikeHtml => kind == VideoUrlKind.html;

  String get contentTypeLabel =>
      (contentType == null || contentType!.isEmpty) ? '-' : contentType!;

  String get sizeLabel {
    final len = contentLength;
    if (len == null || len <= 0) return '-';
    final units = ['B', 'KB', 'MB', 'GB'];
    var value = len.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  /// 响应体文本预览（仅用于播放列表 / HTML 之类文本响应）
  String get textPreview {
    final bytes = sample;
    if (bytes == null || bytes.isEmpty) return '';
    final head = bytes.length > 400 ? bytes.sublist(0, 400) : bytes;
    try {
      return utf8.decode(head, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }
}

/// 探测一个播放地址：是否可获取、是不是视频、是什么类型。
///
/// 通过 `Range: bytes=0-N` 只取前若干字节，避免把整个视频拉下来。
/// 默认不自动跟随重定向，以便把重定向链也记录下来（最多手动跟 4 跳）。
Future<VideoProbeResult> probeVideoUrl(
  String url, {
  Map<String, String>? headers,
  int sampleBytes = 2048,
  int maxRedirects = 4,
}) async {
  final raw = url.trim();
  if (raw.isEmpty) {
    return const VideoProbeResult(url: '', error: 'empty url');
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) {
    return VideoProbeResult(url: raw, error: 'invalid url');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return VideoProbeResult(
      url: raw,
      error: 'unsupported scheme: ${uri.scheme}',
    );
  }

  final sw = Stopwatch()..start();
  final chain = <String>[raw];
  var current = raw;
  Response<List<int>>? res;
  Object? failure;

  for (var hop = 0; hop <= maxRedirects; hop++) {
    try {
      res = await AppDio().get<List<int>>(
        current,
        options: Options(
          method: 'GET',
          responseType: ResponseType.bytes,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            if (headers != null && headers.isNotEmpty) ...headers,
            'Range': 'bytes=0-$sampleBytes',
          },
        ),
      );
    } catch (e) {
      failure = e;
      break;
    }
    final code = res.statusCode ?? 0;
    final location = res.headers.value('location');
    if (code >= 300 && code < 400 && location != null && location.isNotEmpty) {
      final next = res.realUri.resolve(location).toString();
      if (chain.contains(next)) break;
      chain.add(next);
      current = next;
      res = null;
      continue;
    }
    break;
  }
  sw.stop();

  if (failure != null) {
    final message = failure is DioException
        ? (failure.response?.data?.toString() ??
              failure.message ??
              failure.type.name)
        : failure.toString();
    return VideoProbeResult(
      url: raw,
      redirects: chain,
      finalUrl: current,
      elapsedMs: sw.elapsedMilliseconds,
      error: message,
    );
  }

  final response = res!;
  final bytes = response.data == null
      ? null
      : Uint8List.fromList(response.data!);
  final contentType = response.headers.value('content-type');
  return VideoProbeResult(
    url: raw,
    finalUrl: response.realUri.toString(),
    redirects: chain,
    statusCode: response.statusCode,
    statusMessage: response.statusMessage,
    contentType: contentType,
    contentLength:
        int.tryParse(response.headers.value('content-length') ?? '') ??
        bytes?.length,
    acceptRanges: response.headers.value('accept-ranges'),
    elapsedMs: sw.elapsedMilliseconds,
    sample: bytes,
    kind: classifyVideoUrl(
      url: response.realUri.toString(),
      contentType: contentType,
      sample: bytes,
    ),
  );
}

/// 根据 URL 扩展名、响应头 content-type 与响应体头部字节推断地址类型。
VideoUrlKind classifyVideoUrl({
  required String url,
  String? contentType,
  Uint8List? sample,
}) {
  final ct = (contentType ?? '').toLowerCase();

  // 1) 响应头
  if (ct.contains('mpegurl') || ct.contains('vnd.apple.mpegurl')) {
    return VideoUrlKind.hls;
  }
  if (ct.contains('dash+xml')) return VideoUrlKind.dash;
  if (ct.startsWith('image/')) return VideoUrlKind.image;
  if (ct.startsWith('audio/')) return VideoUrlKind.audio;
  if (ct.startsWith('video/')) {
    if (ct.contains('mp4')) return VideoUrlKind.mp4;
    if (ct.contains('webm')) return VideoUrlKind.webm;
    if (ct.contains('matroska')) return VideoUrlKind.mkv;
    if (ct.contains('flv')) return VideoUrlKind.flv;
    if (ct.contains('mp2t')) return VideoUrlKind.mpegts;
    return VideoUrlKind.mp4;
  }
  if (ct.contains('text/html') || ct.contains('application/xhtml')) {
    return VideoUrlKind.html;
  }

  // 2) 响应体头部字节
  final magic = _classifySample(sample);
  if (magic != VideoUrlKind.unknown) return magic;

  // 3) URL 扩展名兜底
  final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  if (path.endsWith('.m3u8') || path.endsWith('.m3u')) return VideoUrlKind.hls;
  if (path.endsWith('.mpd')) return VideoUrlKind.dash;
  if (path.endsWith('.mp4') || path.endsWith('.m4v')) return VideoUrlKind.mp4;
  if (path.endsWith('.webm')) return VideoUrlKind.webm;
  if (path.endsWith('.mkv')) return VideoUrlKind.mkv;
  if (path.endsWith('.flv')) return VideoUrlKind.flv;
  if (path.endsWith('.ts')) return VideoUrlKind.mpegts;
  if (path.endsWith('.mp3') ||
      path.endsWith('.m4a') ||
      path.endsWith('.aac') ||
      path.endsWith('.flac') ||
      path.endsWith('.wav')) {
    return VideoUrlKind.audio;
  }
  if (path.endsWith('.jpg') ||
      path.endsWith('.jpeg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp') ||
      path.endsWith('.gif')) {
    return VideoUrlKind.image;
  }
  return VideoUrlKind.unknown;
}

VideoUrlKind _classifySample(Uint8List? bytes) {
  if (bytes == null || bytes.length < 4) return VideoUrlKind.unknown;

  bool startsWith(List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  final head = String.fromCharCodes(
    bytes.length > 512 ? bytes.sublist(0, 512) : bytes,
  );

  if (head.startsWith('#EXTM3U')) return VideoUrlKind.hls;
  if (head.contains('<MPD') || head.contains('urn:mpeg:dash:schema')) {
    return VideoUrlKind.dash;
  }
  final lower = head.toLowerCase();
  if (lower.contains('<!doctype html') || lower.contains('<html')) {
    return VideoUrlKind.html;
  }
  if (bytes.length >= 8 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
    return VideoUrlKind.mp4;
  }
  if (startsWith([0x1A, 0x45, 0xDF, 0xA3])) return VideoUrlKind.mkv;
  if (startsWith([0x46, 0x4C, 0x56])) return VideoUrlKind.flv;
  if (bytes[0] == 0x47) return VideoUrlKind.mpegts;
  if (startsWith([0x89, 0x50, 0x4E, 0x47]) ||
      startsWith([0xFF, 0xD8, 0xFF])) {
    return VideoUrlKind.image;
  }
  if (head.startsWith('ID3') || (bytes[0] == 0xFF && bytes[1] == 0xFB)) {
    return VideoUrlKind.audio;
  }
  return VideoUrlKind.unknown;
}

/// 需要读取的 mpv 属性（调试用，读不到的会被跳过）。
const kMpvDebugProperties = <String>[
  'filename',
  'media-title',
  'file-format',
  'file-size',
  'duration',
  'demuxer',
  'video-codec',
  'video-format',
  'width',
  'height',
  'container-fps',
  'estimated-vf-fps',
  'video-bitrate',
  'video-params/pixelformat',
  'video-params/aspect',
  'video-params/colormatrix',
  'video-params/primaries',
  'video-params/gamma',
  'hwdec-current',
  'audio-codec',
  'audio-params/format',
  'audio-params/samplerate',
  'audio-params/channel-count',
  'audio-bitrate',
  'track-list/count',
  'frame-drop-count',
  'decoder-frame-drop-count',
];

/// 读取媒体属性；非原生播放器（如 web）返回空表。
///
/// 注意：mpv 只在开始播放 / 解析出媒体后才有这些属性，未播放时为「不可用」。
Future<Map<String, String>> readMpvProperties(Player player) async {
  final platform = player.platform;
  if (platform is! NativePlayer) return const {};
  final result = <String, String>{};
  for (final property in kMpvDebugProperties) {
    try {
      final value = await platform.getProperty(property);
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      result[property] = trimmed;
    } catch (_) {
      // 属性不存在（未加载媒体 / 该版本 mpv 不支持）时忽略
    }
  }
  return result;
}
