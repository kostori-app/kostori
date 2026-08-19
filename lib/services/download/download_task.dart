/// 视频下载任务模型。
library;

/// 下载状态
enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
}

/// 单个视频下载任务（mp4 直链或 m3u8/HLS）
class DownloadTask {
  final String id;

  final String title;

  final String? subtitle;

  final String? cover;

  final String url;

  final Map<String, String> headers;

  /// 所属源 key（用于每源标题格式）
  final String? sourceKey;

  /// 番剧 id（下载记录关联）
  final String? animeId;

  /// 剧名/作者（标题格式占位符用）
  final String? animeTitle;

  final String? episode;

  final String? author;

  final String? resolution;

  DownloadStatus status;

  /// 进度 0~1
  double progress;

  /// 下载完成后的文件路径
  String? filePath;

  String? error;

  final DateTime createdAt;

  DownloadTask({
    required this.id,
    required this.title,
    this.subtitle,
    this.cover,
    required this.url,
    this.headers = const {},
    this.sourceKey,
    this.animeId,
    this.animeTitle,
    this.episode,
    this.author,
    this.resolution,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.filePath,
    this.error,
    required this.createdAt,
  });

  bool get isHls {
    final lower = url.toLowerCase();
    return lower.contains('.m3u8') || lower.contains('m3u8');
  }

  bool get isActive =>
      status == DownloadStatus.queued ||
      status == DownloadStatus.downloading;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'cover': cover,
    'url': url,
    'headers': headers,
    'sourceKey': sourceKey,
    'animeId': animeId,
    'animeTitle': animeTitle,
    'episode': episode,
    'author': author,
    'resolution': resolution,
    'status': status.name,
    'progress': progress,
    'filePath': filePath,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String?,
    cover: json['cover'] as String?,
    url: json['url'] as String? ?? '',
    headers: (json['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ) ??
        const {},
    sourceKey: json['sourceKey'] as String?,
    animeId: json['animeId'] as String?,
    animeTitle: json['animeTitle'] as String?,
    episode: json['episode'] as String?,
    author: json['author'] as String?,
    resolution: json['resolution'] as String?,
    status: DownloadStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DownloadStatus.failed,
    ),
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    filePath: json['filePath'] as String?,
    error: json['error'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}
