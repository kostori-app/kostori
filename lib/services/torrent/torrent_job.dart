/// 种子任务状态
enum TorrentJobStatus { metadata, downloading, paused, completed, failed }

/// base32 infohash（32 位）→ 40 位小写 hex；不是合法 base32 返回 null。
String? base32ToInfoHashHex(String s) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var bits = 0;
  var value = 0;
  final bytes = <int>[];
  for (final ch in s.toUpperCase().codeUnits) {
    final idx = alphabet.indexOf(String.fromCharCode(ch));
    if (idx < 0) return null;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bytes.add((value >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  if (bytes.length != 20) return null;
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// 种子识别码：40 位大写 hex infohash（兼容裸 hash 与 base32 磁力）。
///
/// base32 也转成 hex，保证复制出去的内容能被其它客户端识别。
String? parseInfoHash(String magnet) {
  final raw = magnet.trim();
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.scheme.toLowerCase() == 'magnet') {
    for (final entry in uri.queryParametersAll.entries) {
      if (entry.key.toLowerCase() != 'xt') continue;
      for (final value in entry.value) {
        final lower = value.toLowerCase();
        const prefix = 'urn:btih:';
        if (!lower.startsWith(prefix)) continue;
        final hash = value.substring(prefix.length);
        if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(hash)) {
          return hash.toUpperCase();
        }
        if (RegExp(r'^[A-Z2-7]{32}$', caseSensitive: false).hasMatch(hash)) {
          return base32ToInfoHashHex(hash)?.toUpperCase();
        }
      }
    }
  }

  // Keep a permissive fallback for magnets with malformed non-essential query
  // parameters, which Uri.parse may reject even though xt itself is usable.
  final xt = RegExp(
    r'xt=urn:btih:([0-9a-z]{40}|[a-z2-7]{32})(?:&|$)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (xt != null) {
    final hash = xt.group(1)!;
    if (hash.length == 40) return hash.toUpperCase();
    return base32ToInfoHashHex(hash)?.toUpperCase();
  }

  if (!raw.toLowerCase().contains('xt=urn:btih:')) {
    final bare = raw.toUpperCase();
    if (RegExp(r'^[0-9A-F]{40}$').hasMatch(bare)) return bare;
    if (RegExp(r'^[A-Z2-7]{32}$').hasMatch(bare)) {
      return base32ToInfoHashHex(bare)?.toUpperCase();
    }
    return null;
  }
  return null;
}

/// 由识别码拼出最小磁力链（[normalizeMagnet] 的逆向补全）。
String magnetFromInfoHash(String infoHash) =>
    'magnet:?xt=urn:btih:${infoHash.toUpperCase()}';

/// 添加种子后的停止策略
enum TorrentStopPolicy { none, afterMetadata, afterDownload }

/// 种子任务的可持久化模型（引擎对象由 TorrentManager 持有，不在此处）。
class TorrentJob {
  final String id;
  final String magnet;
  String name;

  TorrentJobStatus status;

  /// 0..1
  double progress;
  int downloadRate;
  int uploadRate;
  int numPeers;
  int numSeeds;

  /// 全站做种数（Tracker scrape 结果，运行期统计，不持久化）
  int numDownloaders;

  /// 已下载字节
  int totalDone;

  /// 需要下载的总字节（选中文件的总量）
  int totalWanted;

  /// 累计上传字节，用于分享率做种限制。
  int uploadedBytes;

  /// 开始做种的时间戳（毫秒）。
  int? seedingStartedAt;

  bool hasMetadata;

  final int createdAt;
  String? error;

  /// 持久化的元数据文件路径（原始 info 字典字节；重启直接加载）
  String torrentPath;

  /// 本地保存目录（下载根目录）
  String savePath;

  /// 已选择的文件下标；空表示全部，[ -1 ]（kTorrentNoFile）表示一个都不选
  List<int> selectedFiles;

  /// 是否已确定过文件选择（首次拿到元数据时给出默认选择，此后尊重用户设置）
  bool selectionInitialized;

  /// 用户为文件设置的优先级：0=不下载，1=高，2=正常，3=最高。
  /// 使用整数保存，避免让持久化模型依赖引擎的 enum 实现。
  Map<int, int> filePriorities;

  /// 添加后的停止策略
  TorrentStopPolicy stopAfter;

  TorrentJob({
    required this.id,
    required this.magnet,
    required this.torrentPath,
    required this.savePath,
    required this.createdAt,
    this.name = '',
    this.status = TorrentJobStatus.metadata,
    this.progress = 0,
    this.downloadRate = 0,
    this.uploadRate = 0,
    this.numPeers = 0,
    this.numSeeds = 0,
    this.numDownloaders = 0,
    this.totalDone = 0,
    this.totalWanted = 0,
    this.uploadedBytes = 0,
    this.seedingStartedAt,
    this.hasMetadata = false,
    this.error,
    this.selectedFiles = const [],
    this.selectionInitialized = true,
    this.filePriorities = const {},
    this.stopAfter = TorrentStopPolicy.none,
  });

  bool get isFinished => status == TorrentJobStatus.completed;

  /// 是否处于抓取元数据阶段（进度未知，进度条需用不确定动画）。
  ///
  /// 失败与暂停的条目同样没有元数据，仅凭 [hasMetadata] 判定会让进度条持续动画化。
  bool get isFetchingMeta =>
      status == TorrentJobStatus.metadata && !hasMetadata;

  /// 种子识别码：40 位大写 hex infohash（兼容裸 hash 与 base32 磁力）。
  String get infoHash => parseInfoHash(magnet) ?? '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'magnet': magnet,
    'name': name,
    'status': status.name,
    'progress': progress,
    'hasMetadata': hasMetadata,
    'totalDone': totalDone,
    'totalWanted': totalWanted,
    'uploadedBytes': uploadedBytes,
    'seedingStartedAt': seedingStartedAt,
    'createdAt': createdAt,
    'error': error,
    'torrentPath': torrentPath,
    'savePath': savePath,
    'selectedFiles': selectedFiles,
    'selectionInitialized': selectionInitialized,
    'filePriorities': {
      for (final entry in filePriorities.entries) '${entry.key}': entry.value,
    },
    'stopAfter': stopAfter.name,
  };

  factory TorrentJob.fromJson(Map<String, dynamic> j) {
    final selected =
        (j['selectedFiles'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        const <int>[];
    final priorities = <int, int>{};
    final rawPriorities = j['filePriorities'];
    if (rawPriorities is Map) {
      for (final entry in rawPriorities.entries) {
        final index = int.tryParse('${entry.key}');
        final value = (entry.value as num?)?.toInt();
        if (index != null && value != null && value >= 0 && value <= 3) {
          priorities[index] = value;
        }
      }
    }
    return TorrentJob(
      id: j['id'] as String,
      magnet: j['magnet'] as String? ?? '',
      torrentPath: j['torrentPath'] as String? ?? '',
      savePath: j['savePath'] as String? ?? '',
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      name: (j['name'] as String?) ?? '',
      status: TorrentJobStatus.values.firstWhere(
        (e) => e.name == j['status'],
        orElse: () => TorrentJobStatus.paused,
      ),
      progress: (j['progress'] as num?)?.toDouble() ?? 0,
      hasMetadata: (j['hasMetadata'] as bool?) ?? false,
      totalDone: (j['totalDone'] as num?)?.toInt() ?? 0,
      totalWanted: (j['totalWanted'] as num?)?.toInt() ?? 0,
      uploadedBytes: (j['uploadedBytes'] as num?)?.toInt() ?? 0,
      seedingStartedAt: (j['seedingStartedAt'] as num?)?.toInt(),
      error: j['error'] as String?,
      selectedFiles: selected,
      // 旧任务没有该字段：除「全不选」哨兵（-1）外都视为已初始化，尊重已有选择
      selectionInitialized:
          (j['selectionInitialized'] as bool?) ??
          !(selected.length == 1 && selected.first == -1),
      filePriorities: priorities,
      stopAfter: TorrentStopPolicy.values.firstWhere(
        (e) => e.name == j['stopAfter'],
        orElse: () => TorrentStopPolicy.none,
      ),
    );
  }
}

/// 供 UI 使用的种子内文件条目。
class TorrentFileEntry {
  final int index;
  final String name;
  final String path;
  final int size;
  final int downloaded;
  final bool isStreamable;
  final String? localPath;

  const TorrentFileEntry({
    required this.index,
    required this.name,
    required this.path,
    required this.size,
    required this.downloaded,
    required this.isStreamable,
    this.localPath,
  });

  double get progress =>
      size <= 0 ? 0 : (downloaded / size).clamp(0.0, 1.0).toDouble();

  bool get completed => size > 0 && downloaded >= size;

  /// 正在下载（已有部分数据但未完成）
  bool get isDownloading => !completed && downloaded > 0;
}
