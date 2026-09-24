/// 种子任务状态
enum TorrentTaskStatus { metadata, downloading, paused, completed, failed }

/// 种子任务模型（可持久化）。一个任务 = 一个种子，整体下载。
class TorrentTask {
  final String id;
  final String magnet;
  String name;

  TorrentTaskStatus status;
  double progress;
  int downloadRate;
  int uploadRate;
  int numPeers;
  int numSeeds;
  int totalDone;
  int totalWanted;
  bool hasMetadata;

  /// 引擎内部分配的 id（重启会变，不持久化）
  int? engineId;

  final int createdAt;
  String? error;

  TorrentTask({
    required this.id,
    required this.magnet,
    this.name = '',
    this.status = TorrentTaskStatus.metadata,
    this.progress = 0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.hasMetadata = false,
    this.engineId,
    required this.createdAt,
    this.error,
  });

  bool get isFinished => status == TorrentTaskStatus.completed;

  /// 从 magnet 提取 btih 信息哈希
  String get infoHash {
    final m = RegExp(r'urn:btih:([^&]+)', caseSensitive: false).firstMatch(magnet);
    return m?.group(1) ?? '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'magnet': magnet,
    'name': name,
    'status': status.name,
    'progress': progress,
    'hasMetadata': hasMetadata,
    'totalDone': totalDone,
    'totalWanted': totalWanted,
    'createdAt': createdAt,
    'error': error,
  };

  factory TorrentTask.fromJson(Map<String, dynamic> j) => TorrentTask(
    id: j['id'] as String,
    magnet: j['magnet'] as String,
    name: (j['name'] as String?) ?? '',
    status: TorrentTaskStatus.values.firstWhere(
      (e) => e.name == j['status'],
      orElse: () => TorrentTaskStatus.metadata,
    ),
    progress: (j['progress'] as num?)?.toDouble() ?? 0,
    hasMetadata: (j['hasMetadata'] as bool?) ?? false,
    totalDone: (j['totalDone'] as num?)?.toInt() ?? 0,
    totalWanted: (j['totalWanted'] as num?)?.toInt() ?? 0,
    createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
    error: j['error'] as String?,
  );
}
