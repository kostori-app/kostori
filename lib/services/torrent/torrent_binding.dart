import 'package:kostori/foundation/appdata.dart';

/// 内容标识：有 bangumiId 用它（跨源共享），否则用「源 + 条目 id」。
String playbackContentKey({
  int? bangumiId,
  required String sourceKey,
  required String animeId,
}) => (bangumiId != null && bangumiId > 0)
    ? 'bgm:$bangumiId'
    : '$sourceKey:$animeId';

/// 从种子标题抽取「组」（开头 `【...】` 或 `[...]`），无则空。
String btGroupOf(String title) {
  final m = RegExp(
    r'^\s*(?:【\s*([^】]+)\s*】|\[([^\]]+)\])',
  ).firstMatch(title);
  return (m?.group(1) ?? m?.group(2) ?? '').trim();
}

/// 从种子标题/文件名抽取集号（`[01]` / `E01` / `第01话` / `- 01`），无则 0。
int btEpisodeOf(String title) {
  final patterns = [
    RegExp(r'\[(\d{1,4})(?:v\d)?\]'),
    RegExp(r'(?:E|EP|Episode)\s*(\d{1,4})', caseSensitive: false),
    RegExp(r'第\s*(\d{1,4})\s*[话話集]'),
    RegExp(r'-\s*(\d{1,4})(?:\s|\[|$)'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(title);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null) return n;
    }
  }
  return 0;
}

/// 内容级选定的 BT 线路：某个 BT 站 + 某个组（字幕组/发布组，空 = 不限）。
/// 选定后该内容的每一集都在此「站 + 组」里自动检索。
class BtLine {
  final String siteKey;
  final String siteName;
  final String group;

  const BtLine({
    required this.siteKey,
    required this.siteName,
    this.group = '',
  });

  Map<String, dynamic> toJson() => {
    'siteKey': siteKey,
    'siteName': siteName,
    'group': group,
  };

  static BtLine? fromJson(Object? v) {
    if (v is! Map) return null;
    final siteKey = v['siteKey']?.toString();
    if (siteKey == null || siteKey.isEmpty) return null;
    return BtLine(
      siteKey: siteKey,
      siteName: v['siteName']?.toString() ?? siteKey,
      group: v['group']?.toString() ?? '',
    );
  }

  String get label => group.isEmpty ? siteName : '$siteName · [$group]';
}

/// BT 线路选择 + 当前是否走 BT 线（内容级，持久化）。
class BtLineStore {
  BtLineStore._();

  static Map<String, dynamic> _lines() {
    final raw = appdata.implicitData['btLines'];
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static BtLine? line(String contentKey) =>
      BtLine.fromJson(_lines()[contentKey]);

  static void setLine(String contentKey, BtLine? line) {
    final all = _lines();
    if (line == null) {
      all.remove(contentKey);
    } else {
      all[contentKey] = line.toJson();
    }
    appdata.implicitData['btLines'] = all;
    appdata.writeImplicitData();
  }

  static bool _isActive(String contentKey) =>
      appdata.implicitData['btActive'] is Map &&
      (appdata.implicitData['btActive'] as Map)[contentKey] == true;

  /// 该内容当前是否走 BT 线
  static bool isActive(String contentKey) => _isActive(contentKey);

  static void setActive(String contentKey, bool active) {
    final raw = appdata.implicitData['btActive'];
    final all = raw is Map ? raw.cast<String, dynamic>() : <String, dynamic>{};
    if (active) {
      all[contentKey] = true;
    } else {
      all.remove(contentKey);
    }
    appdata.implicitData['btActive'] = all;
    appdata.writeImplicitData();
  }
}

/// 某一集绑定的种子播放资源（指向某个种子任务的某个文件）。
///
/// 只存 jobId + 文件相对路径，播放时再向 [TorrentManager] 换取 loopback URL
/// （端口每次启动都变，不能持久化 URL）。
class TorrentBinding {
  final String jobId;
  final String filePath;
  final String label;

  const TorrentBinding({
    required this.jobId,
    required this.filePath,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
    'jobId': jobId,
    'filePath': filePath,
    'label': label,
  };

  static TorrentBinding? fromJson(Object? v) {
    if (v is! Map) return null;
    final jobId = v['jobId']?.toString();
    final filePath = v['filePath']?.toString();
    if (jobId == null ||
        jobId.isEmpty ||
        filePath == null ||
        filePath.isEmpty) {
      return null;
    }
    return TorrentBinding(
      jobId: jobId,
      filePath: filePath,
      label: v['label']?.toString() ?? '',
    );
  }
}

/// 「内容 + 线路 + 集」→ 绑定的种子资源。持久化在 `implicitData['torrentBindings']`。
class TorrentBindingStore {
  TorrentBindingStore._();

  static Map<String, dynamic> _all() {
    final raw = appdata.implicitData['torrentBindings'];
    if (raw is Map) return raw.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static void _save(Map<String, dynamic> all) {
    appdata.implicitData['torrentBindings'] = all;
    appdata.writeImplicitData();
  }

  static String _key(String contentKey, int road, int episodeIndex) =>
      '$contentKey|$road|$episodeIndex';

  static TorrentBinding? get(String contentKey, int road, int episodeIndex) =>
      TorrentBinding.fromJson(_all()[_key(contentKey, road, episodeIndex)]);

  static void set(
    String contentKey,
    int road,
    int episodeIndex,
    TorrentBinding binding,
  ) {
    final all = _all();
    all[_key(contentKey, road, episodeIndex)] = binding.toJson();
    _save(all);
  }

  static void remove(String contentKey, int road, int episodeIndex) {
    final all = _all();
    all.remove(_key(contentKey, road, episodeIndex));
    _save(all);
  }

  /// 某内容下所有绑定：`road|episode` → binding。
  static Map<String, TorrentBinding> forContent(String contentKey) {
    final prefix = '$contentKey|';
    final out = <String, TorrentBinding>{};
    _all().forEach((k, v) {
      if (!k.startsWith(prefix)) return;
      final b = TorrentBinding.fromJson(v);
      if (b != null) out[k.substring(prefix.length)] = b;
    });
    return out;
  }
}
