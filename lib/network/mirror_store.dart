import 'package:kostori/foundation/appdata.dart';

/// 规范化镜像地址：补全 scheme（用户常只填 `github.akams.cn` 这类裸域名，
/// 缺省会被解析成无 host 而静默失效）。
String normalizeMirrorUrl(String url) {
  var u = url.trim();
  if (u.isEmpty) return '';
  if (!u.contains('://')) u = 'https://$u';
  return u;
}

/// 镜像用途：决定一个镜像能承接哪些请求。
/// 前缀式代理可「通用」；jsDelivr / ghfast 这类不支持 api.github.com，应标「仅主站点/文件」。
enum MirrorScope {
  all('all'),
  site('site'),
  api('api');

  const MirrorScope(this.value);

  final String value;

  static MirrorScope parse(String? v) => switch (v) {
    'site' => site,
    'api' => api,
    _ => all,
  };
}

/// 一条用户自定义镜像（名称 + 地址 + 用途）。
class MirrorEntry {
  final String name;
  final String url;
  final MirrorScope scope;

  const MirrorEntry({
    required this.name,
    required this.url,
    this.scope = MirrorScope.all,
  });

  factory MirrorEntry.fromJson(Map json) => MirrorEntry(
    name: json['name']?.toString() ?? '',
    url: normalizeMirrorUrl(json['url']?.toString() ?? ''),
    scope: MirrorScope.parse(json['scope']?.toString()),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': normalizeMirrorUrl(url),
    'scope': scope.value,
  };
}

/// 某类镜像的存取（列表 + 当前选中），数据存在 implicitData。
class MirrorStore {
  const MirrorStore(this.listKey, this.selectedKey);

  final String listKey;
  final String selectedKey;

  List<MirrorEntry> get entries {
    final raw = appdata.implicitData[listKey];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map(MirrorEntry.fromJson)
        .where((e) => e.url.isNotEmpty)
        .toList();
  }

  void save(List<MirrorEntry> list) {
    appdata.implicitData[listKey] = list.map((e) => e.toJson()).toList();
    appdata.writeImplicitData();
  }

  /// 当前选中的镜像地址；空字符串表示不使用镜像
  String get selectedUrl =>
      normalizeMirrorUrl((appdata.implicitData[selectedKey] as String?) ?? '');

  void select(String url) {
    appdata.implicitData[selectedKey] = normalizeMirrorUrl(url);
    appdata.writeImplicitData();
  }

  MirrorEntry? get selected {
    final url = selectedUrl;
    if (url.isEmpty) return null;
    for (final e in entries) {
      if (e.url == url) return e;
    }
    return null;
  }
}

final bangumiMirrorStore = MirrorStore('bangumiMirrors', 'bangumiMirror');
final githubMirrorStore = MirrorStore('githubMirrors', 'githubMirror');

/// Bangumi p1 接口镜像（next.bgm.tv）：与主接口镜像分开维护。
final bangumiP1MirrorStore = MirrorStore('bangumiP1Mirrors', 'bangumiP1Mirror');

/// Bangumi 图片镜像：与接口镜像分开维护（图片镜像通常只反代 lain.bgm.tv）。
final bangumiImageMirrorStore = MirrorStore(
  'bangumiImageMirrors',
  'bangumiImageMirror',
);

/// 会被镜像替换的官方 Bangumi 主接口主机（v0，api.bgm.tv）
const _bangumiMirrorableHosts = {'api.bgm.tv'};

/// 会被镜像替换的 Bangumi p1 接口主机（next.bgm.tv）
const _bangumiP1MirrorableHosts = {'next.bgm.tv'};

/// 会被镜像替换的 Bangumi 图片主机（封面、剧照等）
const _bangumiImageMirrorableHosts = {'lain.bgm.tv'};

String _applyMirror(String url, MirrorStore store, Set<String> hosts) {
  final mirror = store.selectedUrl;
  if (mirror.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || !hosts.contains(uri.host)) return url;
  final base = mirror.endsWith('/')
      ? mirror.substring(0, mirror.length - 1)
      : mirror;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return '$base$path${uri.hasQuery ? '?${uri.query}' : ''}';
}

/// 把官方 Bangumi 主接口（api.bgm.tv）地址改写为当前选中的镜像地址。
String applyBangumiMirror(String url) =>
    _applyMirror(url, bangumiMirrorStore, _bangumiMirrorableHosts);

/// 把 Bangumi p1 接口（next.bgm.tv）地址改写为当前选中的 p1 镜像地址。
String applyBangumiP1Mirror(String url) =>
    _applyMirror(url, bangumiP1MirrorStore, _bangumiP1MirrorableHosts);

/// 把 Bangumi 图片地址改写为当前选中的图片镜像地址（保留 path 与 query）。
String applyBangumiImageMirror(String url) =>
    _applyMirror(url, bangumiImageMirrorStore, _bangumiImageMirrorableHosts);

/// 前缀式/替换式镜像可加速的 GitHub 主机（真正的前缀代理对 API 与文件下载都有效）。
const _githubHosts = {
  'github.com',
  'api.github.com',
  'raw.githubusercontent.com',
  'objects.githubusercontent.com',
  'codeload.github.com',
  'gist.githubusercontent.com',
  'gist.github.com',
};

bool _isJsdelivrHost(String host) =>
    host == 'jsdelivr.net' || host.endsWith('.jsdelivr.net');

bool _isLargeGithubDownload(Uri uri) {
  if (uri.host == 'objects.githubusercontent.com' ||
      uri.host == 'codeload.github.com') {
    return true;
  }
  return uri.path.contains('/releases/download/');
}

bool _scopeCanServe(MirrorScope scope, {required bool needApi}) =>
    scope == MirrorScope.all ||
    (needApi ? scope == MirrorScope.api : scope == MirrorScope.site);

/// 按「用途」标签挑选可承接该请求的镜像：优先当前选中的（若其用途匹配），
/// 否则取第一个用途匹配的；都不匹配或显式选择「官方」时则不走镜像。
MirrorEntry? _effectiveGithubMirror({required bool needApi}) {
  if (githubMirrorStore.selectedUrl.isEmpty) return null;
  final selected = githubMirrorStore.selected;
  if (selected != null && _scopeCanServe(selected.scope, needApi: needApi)) {
    return selected;
  }
  for (final e in githubMirrorStore.entries) {
    if (_scopeCanServe(e.scope, needApi: needApi)) return e;
  }
  return null;
}

/// 按选中的 GitHub 镜像改写地址：
/// - jsDelivr 式镜像：`raw.githubusercontent.com/用户/仓库/分支/路径` →
///   `/gh/用户/仓库@分支/路径`；已是 jsDelivr 的地址则替换镜像主机；
/// - 前缀式镜像：镜像地址 + 原始 URL。
/// 镜像能否承接 API/大文件由条目的「用途」标签决定（`仅主站点/文件` 的镜像
/// 不会被用于 api.github.com 或 release 大文件）。
String applyGithubMirror(String url, {bool largeFile = false}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  final needApi =
      largeFile || uri.host == 'api.github.com' || _isLargeGithubDownload(uri);
  final mirror = _effectiveGithubMirror(needApi: needApi);
  if (mirror == null) return url;

  final mirrorUri = Uri.tryParse(mirror.url);
  if (mirrorUri == null || mirrorUri.host.isEmpty) return url;
  final query = uri.hasQuery ? '?${uri.query}' : '';

  if (_isJsdelivrHost(mirrorUri.host)) {
    // jsDelivr 只服务于 GitHub 仓库内容
    if (uri.host == 'raw.githubusercontent.com') {
      final seg = uri.pathSegments;
      // 支持 .../<owner>/<repo>/<branch>/<path> 与 .../refs/heads/<branch>/<path>
      int branchIndex = 2;
      if (seg.length >= 5 && seg[2] == 'refs' && seg[3] == 'heads') {
        branchIndex = 4;
      }
      if (seg.length > branchIndex + 1) {
        final owner = seg[0];
        final repo = seg[1];
        final branch = seg[branchIndex];
        final path = seg.sublist(branchIndex + 1).join('/');
        return '${mirrorUri.origin}/gh/$owner/$repo@$branch/$path$query';
      }
      return url;
    }
    // 源地址本身就是 jsDelivr：只替换镜像主机
    if (_isJsdelivrHost(uri.host)) {
      return '${mirrorUri.origin}${uri.path}$query';
    }
    return url;
  }

  // 前缀式镜像
  if (_githubHosts.contains(uri.host)) {
    final base = mirror.url.endsWith('/') ? mirror.url : '${mirror.url}/';
    return '$base$url';
  }
  return url;
}

const _kSendAuth = 'bangumiMirrorSendAuth';

/// 是否把登录鉴权（Authorization 等凭证）发给镜像。
/// 默认关闭，避免把账号令牌交给第三方镜像。
bool get bangumiMirrorSendAuth => appdata.implicitData[_kSendAuth] == true;
