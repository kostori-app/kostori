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

  /// 纯集号（如 "5"），用于开启“不使用集标题”时替代无意义的集标题做文件名
  final String? episodeNo;

  final String? author;

  final String? resolution;

  DownloadStatus status;

  /// 进度 0~1
  double progress;

  /// 总大小（字节），未知为 0
  int totalBytes;

  /// 已下载字节（运行时更新，不持久化）
  int downloadedBytes;

  /// 下载速度（字节/秒，运行时更新，不持久化）
  double downloadSpeed;

  /// m3u8 已下载分片数（运行时；非 m3u8 恒为 -1）
  int segDone;

  /// m3u8 总分片数（运行时；非 m3u8 恒为 -1）
  int segTotal;

  /// 下载完成后的文件路径
  String? filePath;

  String? error;

  /// 正在合并分片 / 强制合并中（运行时状态，不持久化）
  bool isMerging = false;

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
    this.episodeNo,
    this.author,
    this.resolution,
    this.status = DownloadStatus.queued,
    this.progress = 0,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.downloadSpeed = 0,
    this.segDone = -1,
    this.segTotal = -1,
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
    'episodeNo': episodeNo,
    'author': author,
    'resolution': resolution,
    'status': status.name,
    'progress': progress,
    'totalBytes': totalBytes,
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
    episodeNo: json['episodeNo'] as String?,
    author: json['author'] as String?,
    resolution: json['resolution'] as String?,
    status: DownloadStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DownloadStatus.failed,
    ),
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
    filePath: json['filePath'] as String?,
    error: json['error'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}
