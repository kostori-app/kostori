import 'package:kostori/foundation/appdata.dart';

/// 一条用户自定义镜像（名称 + 地址）。
class MirrorEntry {
  final String name;
  final String url;

  const MirrorEntry({required this.name, required this.url});

  factory MirrorEntry.fromJson(Map json) => MirrorEntry(
    name: json['name']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'url': url};
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
      (appdata.implicitData[selectedKey] as String?) ?? '';

  void select(String url) {
    appdata.implicitData[selectedKey] = url;
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

/// 会被镜像替换的官方 Bangumi 接口主机
const _bangumiMirrorableHosts = {'api.bgm.tv', 'next.bgm.tv'};

/// 把官方 Bangumi 接口地址改写为当前选中的镜像地址（保留 path 与 query）。
String applyBangumiMirror(String url) {
  final mirror = bangumiMirrorStore.selectedUrl;
  if (mirror.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null || !_bangumiMirrorableHosts.contains(uri.host)) return url;
  final base = mirror.endsWith('/')
      ? mirror.substring(0, mirror.length - 1)
      : mirror;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return '$base$path${uri.hasQuery ? '?${uri.query}' : ''}';
}

/// 前缀式/替换式镜像可加速的 GitHub 主机
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

/// jsDelivr 只能服务 GitHub 仓库内容（raw 或它自己的地址）
bool _jsdelivrCanServe(Uri uri) =>
    uri.host == 'raw.githubusercontent.com' || _isJsdelivrHost(uri.host);

/// 选中的 GitHub 镜像；jsDelivr 服务不了时（大文件 / 非仓库主机如 api.github.com）
/// 回退到列表中第一个非 jsDelivr 镜像。
MirrorEntry? _effectiveGithubMirror(Uri uri, {required bool largeFile}) {
  final selected = githubMirrorStore.selected;
  if (selected == null) return null;
  final host = Uri.tryParse(selected.url)?.host ?? '';
  if (!_isJsdelivrHost(host)) return selected;
  if (!largeFile && _jsdelivrCanServe(uri)) return selected;
  for (final e in githubMirrorStore.entries) {
    final h = Uri.tryParse(e.url)?.host ?? '';
    if (!_isJsdelivrHost(h)) return e;
  }
  return null;
}

/// 按选中的 GitHub 镜像改写地址：
/// - jsDelivr 式镜像：`raw.githubusercontent.com/用户/仓库/分支/路径` →
///   `/gh/用户/仓库@分支/路径`；已是 jsDelivr 的地址则替换镜像主机；
/// - 前缀式镜像：镜像地址 + 原始 URL；
/// jsDelivr 服务不了的请求（大文件、api.github.com 等非仓库主机）会回退到
/// 列表中第一个非 jsDelivr 镜像，没有则走官方。
String applyGithubMirror(String url, {bool largeFile = false}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;

  final large = largeFile || _isLargeGithubDownload(uri);
  final mirror = _effectiveGithubMirror(uri, largeFile: large);
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
