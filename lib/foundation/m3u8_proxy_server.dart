import 'dart:io';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/m3u8_ad_rule.dart';

class M3u8ProxyServer {
  static M3u8ProxyServer? _instance;

  static M3u8ProxyServer get instance => _instance ??= M3u8ProxyServer._();

  M3u8ProxyServer._();

  HttpServer? _server;
  int _port = 0;

  String? _currentM3u8Url;
  Map<String, String>? _headers;

  final _dio = AppDio();

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _serve();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<String> proxyUrl(String m3u8Url, Map<String, String>? headers) async {
    await start();
    _currentM3u8Url = m3u8Url;
    _headers = headers;
    return 'http://127.0.0.1:$_port/playlist.m3u8';
  }

  /// Get current proxy URL if server is running
  String? get currentProxyUrl {
    if (_server == null || _currentM3u8Url == null) return null;
    return 'http://127.0.0.1:$_port/playlist.m3u8';
  }

  void _serve() {
    _server!.listen((request) async {
      try {
        if (request.uri.path == '/playlist.m3u8') {
          final cleaned = await _fetchAndFilter(_currentM3u8Url!, _headers);
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType(
              'application',
              'vnd.apple.mpegurl',
            )
            ..write(cleaned)
            ..close();
        } else if (request.uri.path == '/proxy') {
          // 代理分片 / KEY / init 分片请求
          final segUrl = request.uri.queryParameters['url'];
          if (segUrl != null) {
            final isPlaylist =
                Uri.tryParse(segUrl)?.path.endsWith('.m3u8') == true ||
                segUrl.contains('mpegurl');
            if (isPlaylist) {
              // 变体/嵌套播放列表：递归过滤后再返回
              final cleaned = await _fetchAndFilter(segUrl, _headers);
              request.response
                ..statusCode = 200
                ..headers.contentType = ContentType(
                  'application',
                  'vnd.apple.mpegurl',
                )
                ..write(cleaned)
                ..close();
            } else {
              final resp = await _dio.get<List<int>>(
                segUrl,
                options: Options(
                  responseType: ResponseType.bytes,
                  headers: _headers,
                ),
              );
              final bytes = resp.data ?? const <int>[];
              request.response
                ..statusCode = 200
                ..headers.contentType = _contentTypeFor(segUrl, bytes)
                ..add(bytes)
                ..close();
            }
          } else {
            request.response
              ..statusCode = 400
              ..close();
          }
        } else {
          request.response
            ..statusCode = 404
            ..close();
        }
      } catch (e) {
        request.response
          ..statusCode = 500
          ..close();
      }
    });
  }

  ContentType _contentTypeFor(String url, List<int> bytes) {
    final path = Uri.tryParse(url)?.path ?? url;
    final lower = path.toLowerCase();
    if (lower.endsWith('.key') || lower.endsWith('.bin')) {
      return ContentType('application', 'octet-stream');
    }
    if (lower.endsWith('.m4s') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.cmfv') ||
        lower.endsWith('.cmfs')) {
      return ContentType('video', 'mp4');
    }
    if (lower.endsWith('.ts') || lower.endsWith('.m2ts')) {
      return ContentType('video', 'MP2T');
    }
    // 回退：按字节嗅探（分片多以 0x47 同步字节开头）
    if (bytes.isNotEmpty && bytes.first == 0x47) {
      return ContentType('video', 'MP2T');
    }
    return ContentType('application', 'octet-stream');
  }

  Future<String> _fetchAndFilter(
    String url,
    Map<String, String>? headers,
  ) async {
    final resp = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain, headers: headers),
    );
    var content = resp.data ?? '';

    if (content.contains('#EXT-X-STREAM-INF')) {
      final subUrl = _parseMasterFirst(url, content);
      if (subUrl != null) return _fetchAndFilter(subUrl, headers);
    }

    // 先过滤广告（此时分片仍是原始 URL，域名/正则规则能正确匹配），
    // 再把剩余分片重写为本地代理地址。
    if (appdata.settings['m3u8AdFilterEnabled'] == true) {
      content = _filterAds(url, content);
    }
    return _convertToProxyUrls(url, content);
  }

  /// 将 m3u8 中的相对路径转换为代理 URL。
  /// 除分片外，还会重写 `#EXT-X-KEY` / `#EXT-X-MAP` 的 URI，
  /// 否则 AES-128 加密流 / fMP4 的 KEY 与 init 分片会按本地相对路径请求而失败。
  String _convertToProxyUrls(String baseUrl, String content) {
    final basePath = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);

    String proxyFor(String uri) {
      final resolved = uri.startsWith('http')
          ? uri
          : Uri.parse(basePath).resolve(uri).toString();
      final proxy = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: _port,
        path: '/proxy',
        queryParameters: {'url': resolved},
      );
      return proxy.toString();
    }

    final lines = content.split('\n');
    final output = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        output.add(line);
        continue;
      }

      // 重写 KEY / MAP 标签里的 URI="..."
      if (trimmed.startsWith('#EXT-X-KEY:') ||
          trimmed.startsWith('#EXT-X-MAP:')) {
        final uriMatch = RegExp(r'URI="([^"]+)"').firstMatch(trimmed);
        if (uriMatch != null) {
          final proxy = proxyFor(uriMatch.group(1)!);
          output.add(
            trimmed.replaceFirst(RegExp(r'URI="([^"]+)"'), 'URI="$proxy"'),
          );
          continue;
        }
      }

      // 其他 tag 行或空行原样保留
      if (trimmed.startsWith('#')) {
        output.add(line);
        continue;
      }

      // 分片 URI
      output.add(proxyFor(trimmed));
    }

    return output.join('\n');
  }

  String _filterAds(String baseUrl, String content) {
    final rules = M3u8AdRuleStore.rules;
    final tagRules = rules
        .where(
          (r) =>
              r.enabled && r.type == M3u8RuleType.tagPresent && r.tag != null,
        )
        .map((r) => r.tag!)
        .toList();

    final lines = content.split('\n');
    final output = <String>[];
    final mainHost = Uri.parse(baseUrl).host;
    bool inAdBlock = false;
    // 处理 SCTE-35 续播标签：进入广告后 CUE-OUT-CONT 继续停留广告区
    bool inCueOutCont = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // tag 规则：匹配到对应 tag 则进入广告块
      if (tagRules.any((tag) => line.startsWith(tag))) {
        inAdBlock = true;
        inCueOutCont = line.startsWith('#EXT-X-CUE-OUT-CONT');
        continue;
      }
      if (line == '#EXT-X-CUE-IN') {
        inAdBlock = false;
        inCueOutCont = false;
        continue;
      }

      // 广告标签的独立处理（不含 CUE-OUT 本身，避免重复标记）
      if (inCueOutCont && line == '#EXT-X-CUE-OUT-CONT') {
        inAdBlock = true;
        continue;
      }

      // DISCONTINUITY + 域名变化
      if (line == '#EXT-X-DISCONTINUITY') {
        final nextUri = _peekNextUri(lines, i + 1);
        if (nextUri != null) {
          final nextHost =
              Uri.tryParse(_resolveUrl(baseUrl, nextUri))?.host ?? '';
          if (nextHost.isNotEmpty && nextHost != mainHost) {
            inAdBlock = true;
            continue;
          } else if (inAdBlock) {
            inAdBlock = false;
            continue;
          }
        }
      }

      // 分片 URI
      if (!line.startsWith('#') && line.isNotEmpty) {
        if (inAdBlock) continue;

        final resolved = _resolveUrl(baseUrl, line);
        final duration = _parseDuration(i > 0 ? lines[i - 1].trim() : '');

        // 跑自定义规则
        if (_isAdSegmentByRules(resolved, duration, rules)) {
          if (output.isNotEmpty && output.last.startsWith('#EXTINF')) {
            output.removeLast();
          }
          continue;
        }

        output.add(resolved);
        continue;
      }

      if (!inAdBlock) output.add(line);
    }

    return output.join('\n');
  }

  String? _parseMasterFirst(String baseUrl, String content) {
    final lines = content.split('\n');
    String? best;
    int bestBandwidth = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
        // 尽量选带宽最高的画质，避免选中 4K 超清流
        int? bw;
        final bwMatch = RegExp(
          r'BANDWIDTH=(\d+)',
          caseSensitive: false,
        ).firstMatch(lines[i]);
        if (bwMatch != null) bw = int.tryParse(bwMatch.group(1)!);
        final url = _resolveUrl(baseUrl, lines[i + 1].trim());
        if (bw != null && bw > bestBandwidth) {
          bestBandwidth = bw;
          best = url;
        } else {
          best ??= url;
        }
      }
    }
    return best;
  }

  String? _peekNextUri(List<String> lines, int from) {
    for (int i = from; i < lines.length; i++) {
      final l = lines[i].trim();
      if (!l.startsWith('#') && l.isNotEmpty) return l;
    }
    return null;
  }

  double _parseDuration(String extinf) {
    if (!extinf.startsWith('#EXTINF:')) return 0;
    return double.tryParse(extinf.substring(8).split(',').first) ?? 0;
  }

  String _resolveUrl(String base, String relative) {
    if (relative.startsWith('http')) return relative;
    return Uri.parse(base).resolve(relative).toString();
  }

  bool _isAdSegmentByRules(
    String segUri,
    double duration,
    List<M3u8AdRule> rules,
  ) {
    for (final rule in rules) {
      if (!rule.enabled) continue;
      if (rule.matches(segUri, duration)) return true;
    }
    return false;
  }
}
