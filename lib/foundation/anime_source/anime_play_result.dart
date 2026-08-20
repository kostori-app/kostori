/// 源脚本 loadAnimePages 返回的结构化播放结果。
///
/// 兼容旧协议：源脚本可返回 String（纯 URL），也可返回该结构
/// （URL + 播放请求头 + 媒体信息：音轨/字幕/视频流/清晰度）。
library;

import 'package:kostori/i18n/strings.g.dart';

class AnimePlayResult {
  final String url;

  /// 播放请求头（如 emby 的 X-Emby-Token 等鉴权头）
  final Map<String, String>? headers;

  /// 音轨列表
  final List<MediaTrackInfo> audioTracks;

  /// 字幕列表
  final List<MediaTrackInfo> subtitleTracks;

  /// 视频流列表（多清晰度 / 编码）
  final List<VideoStreamInfo>? videoStreams;

  /// 容器格式（mp4 / mkv / ts ...）
  final String? container;

  /// 转码会话 id（emby 等）
  final String? playSessionId;

  /// 是否有可选择的音轨/字幕/清晰度
  bool get hasTrackOptions =>
      audioTracks.length > 1 ||
      subtitleTracks.isNotEmpty ||
      (videoStreams != null && videoStreams!.length > 1);

  const AnimePlayResult({
    required this.url,
    this.headers,
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.videoStreams,
    this.container,
    this.playSessionId,
  });

  factory AnimePlayResult.fromJson(Map<String, dynamic> json) {
    return AnimePlayResult(
      url: json['url'] as String? ?? '',
      headers: (json['headers'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      audioTracks: ((json['audioTracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MediaTrackInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      subtitleTracks: ((json['subtitleTracks'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MediaTrackInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      videoStreams: ((json['videoStreams'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => VideoStreamInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      container: json['container'] as String?,
      playSessionId: json['playSessionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (headers != null) 'headers': headers,
    'audioTracks': audioTracks.map((e) => e.toJson()).toList(),
    'subtitleTracks': subtitleTracks.map((e) => e.toJson()).toList(),
    if (videoStreams != null)
      'videoStreams': videoStreams!.map((e) => e.toJson()).toList(),
    if (container != null) 'container': container,
    if (playSessionId != null) 'playSessionId': playSessionId,
  };
}

/// 音轨 / 字幕流信息
class MediaTrackInfo {
  final int index;

  final String? language;
  final String? title;
  final String? codec;

  /// 声道数（音轨）
  final int? channels;

  const MediaTrackInfo({
    required this.index,
    this.language,
    this.title,
    this.codec,
    this.channels,
  });

  String get displayTitle {
    final parts = <String>[
      if (title != null && title!.isNotEmpty) title!,
      if (language != null && language!.isNotEmpty)
        '$language${codec != null && codec!.isNotEmpty ? ' · $codec' : ''}',
      if (channels != null && channels! > 0) '${channels}ch',
    ];
    return parts.isEmpty ? t.trackN(n: index) : parts.join(' ');
  }

  factory MediaTrackInfo.fromJson(Map<String, dynamic> json) {
    return MediaTrackInfo(
      index: json['index'] as int? ?? 0,
      language: json['language'] as String?,
      title: json['title'] as String?,
      codec: json['codec'] as String?,
      channels: json['channels'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    if (language != null) 'language': language,
    if (title != null) 'title': title,
    if (codec != null) 'codec': codec,
    if (channels != null) 'channels': channels,
  };
}

/// 视频流信息（清晰度 / 编码）
class VideoStreamInfo {
  final int index;

  final int? width;
  final int? height;

  /// bitrate（bps）
  final int? bitrate;

  final String? codec;
  final String? name;

  /// 该清晰度的播放地址（源提供时可直接切换播放）
  final String? url;

  const VideoStreamInfo({
    required this.index,
    this.width,
    this.height,
    this.bitrate,
    this.codec,
    this.name,
    this.url,
  });

  /// 清晰度标签，如 1080p / 4K
  String get label {
    final h = height ?? 0;
    if (h >= 2160) return '4K';
    if (h >= 1440) return '1440p';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 480) return '480p';
    return name ?? '${h}p';
  }

  factory VideoStreamInfo.fromJson(Map<String, dynamic> json) {
    return VideoStreamInfo(
      index: json['index'] as int? ?? 0,
      width: json['width'] as int?,
      height: json['height'] as int?,
      bitrate: json['bitrate'] as int?,
      codec: json['codec'] as String?,
      name: json['name'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (bitrate != null) 'bitrate': bitrate,
    if (codec != null) 'codec': codec,
    if (name != null) 'name': name,
    if (url != null) 'url': url,
  };
}
