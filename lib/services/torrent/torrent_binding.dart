import 'package:kostori/database/download_database.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';

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
  final m = RegExp(r'^\s*(?:【\s*([^】]+)\s*】|\[([^\]]+)\])').firstMatch(title);
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

/// 某一集绑定的种子播放资源（指向某个种子任务的某个文件）。
///
/// 只存 jobId + 文件相对路径，播放时再向 TorrentManager 换取 loopback URL
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

/// BT 线路 / 绑定 / 开关的持久化：放在 download 数据库（`download.db`），
/// 不放进 implicitData（后者会被整体读写、且体积随记录增长）。
class _BindingStore {
  static final Map<String, dynamic> lines = {};
  static final Map<String, dynamic> active = {};
  static final Map<String, dynamic> bindings = {};
  static bool _loaded = false;

  /// 在途的加载 Future：并发调用共享同一次加载。
  ///
  /// 之前在第一条 await **之前**就置 `_loaded = true`，第二个并发调用会直接
  /// 返回，拿到空的 lines/active/bindings（表现为「线路都没了」）。
  static Future<void>? _loading;

  static Future<void> writeChain = Future.value();

  static Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  static Future<void> _load() async {
    try {
      _merge(lines, await DownloadDatabase.instance.loadLines());
      _merge(active, await DownloadDatabase.instance.loadActive());
      _merge(bindings, await DownloadDatabase.instance.loadBindings());
    } catch (e) {
      // 之前是 catch (_) {}，一行坏数据导致整份配置静默丢失且毫无痕迹
      Log.error('BT 线路加载失败', '$e');
    }
    // 迁移：早期版本存在 implicitData 里
    final legacy = <String, dynamic>{};
    for (final key in const ['btLines', 'btActive', 'torrentBindings']) {
      final v = appdata.implicitData[key];
      if (v is Map) {
        _merge(
          key == 'btLines'
              ? lines
              : key == 'btActive'
              ? active
              : bindings,
          v,
        );
        legacy[key] = v;
      }
    }
    _loaded = true;
    if (legacy.isNotEmpty) {
      _persist();
      for (final key in legacy.keys) {
        appdata.implicitData.remove(key);
      }
      appdata.writeImplicitData();
    }
  }

  static void _merge(Map<String, dynamic> into, Object? src) {
    if (src is Map) into.addAll(src.cast<String, dynamic>());
  }

  static void _persist() {
    final l = Map<String, dynamic>.from(lines);
    final a = Map<String, dynamic>.from(active);
    final b = Map<String, dynamic>.from(bindings);
    writeChain = writeChain
        .then((_) async {
          await DownloadDatabase.instance.replaceLines(l);
          await DownloadDatabase.instance.replaceActive(a);
          await DownloadDatabase.instance.replaceBindings(b);
        })
        .catchError((_) {});
  }
}

/// BT 线路选择 + 当前是否走 BT 线（内容级）。
class BtLineStore {
  BtLineStore._();

  static Future<void> ensureLoaded() => _BindingStore.ensureLoaded();

  static BtLine? line(String contentKey) =>
      BtLine.fromJson(_BindingStore.lines[contentKey]);

  static void setLine(String contentKey, BtLine? line) {
    if (line == null) {
      _BindingStore.lines.remove(contentKey);
    } else {
      _BindingStore.lines[contentKey] = line.toJson();
    }
    _BindingStore._persist();
  }

  static bool isActive(String contentKey) =>
      _BindingStore.active[contentKey] == true;

  static void setActive(String contentKey, bool active) {
    if (active) {
      _BindingStore.active[contentKey] = true;
    } else {
      _BindingStore.active.remove(contentKey);
    }
    _BindingStore._persist();
  }
}

/// 「内容 + 线路 + 集」→ 绑定的种子资源。
class TorrentBindingStore {
  TorrentBindingStore._();

  static Future<void> ensureLoaded() => _BindingStore.ensureLoaded();

  static String _key(String contentKey, int road, int episodeIndex) =>
      '$contentKey|$road|$episodeIndex';

  static TorrentBinding? get(String contentKey, int road, int episodeIndex) =>
      TorrentBinding.fromJson(
        _BindingStore.bindings[_key(contentKey, road, episodeIndex)],
      );

  static void set(
    String contentKey,
    int road,
    int episodeIndex,
    TorrentBinding binding,
  ) {
    _BindingStore.bindings[_key(contentKey, road, episodeIndex)] = binding
        .toJson();
    _BindingStore._persist();
  }

  static void remove(String contentKey, int road, int episodeIndex) {
    _BindingStore.bindings.remove(_key(contentKey, road, episodeIndex));
    _BindingStore._persist();
  }

  /// 某内容下所有绑定：`road|episode` → binding。
  static Map<String, TorrentBinding> forContent(String contentKey) {
    final prefix = '$contentKey|';
    final out = <String, TorrentBinding>{};
    _BindingStore.bindings.forEach((k, v) {
      if (!k.startsWith(prefix)) return;
      final b = TorrentBinding.fromJson(v);
      if (b != null) out[k.substring(prefix.length)] = b;
    });
    return out;
  }
}
