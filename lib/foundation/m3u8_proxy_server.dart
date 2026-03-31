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
          // 代理 ts 片断请求
          final segUrl = request.uri.queryParameters['url'];
          if (segUrl != null) {
            final resp = await _dio.get<List<int>>(
              segUrl,
              options: Options(
                responseType: ResponseType.bytes,
                headers: _headers,
              ),
            );
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType('video', 'MP2T')
              ..add(resp.data!)
              ..close();
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

    // 转换相对路径为代理路径
    content = _convertToProxyUrls(url, content);

    if (appdata.settings['m3u8AdFilterEnabled'] != true) {
      return content;
    }

    return _filterAds(url, content);
  }

  /// 将 m3u8 中的相对路径转换为代理 URL
  String _convertToProxyUrls(String baseUrl, String content) {
    final basePath = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);

    final lines = content.split('\n');
    final output = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      // 跳过空行和 tag 行
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        output.add(line);
        continue;
      }

      // 处理相对路径
      Uri segmentUri;
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        segmentUri = Uri.parse(trimmed);
      } else {
        // 相对路径
        segmentUri = Uri.parse(basePath + trimmed);
      }

      // 转换为代理 URL - 使用本地代理
      final proxySegUrl = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: _port,
        path: '/proxy',
        queryParameters: {'url': segmentUri.toString()},
      );

      output.add(proxySegUrl.toString());
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

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // tag 规则：匹配到对应 tag 则进入广告块
      if (tagRules.any((tag) => line.startsWith(tag))) {
        inAdBlock = true;
        continue;
      }
      if (line == '#EXT-X-CUE-IN') {
        inAdBlock = false;
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
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
        return _resolveUrl(baseUrl, lines[i + 1].trim());
      }
    }
    return null;
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
      switch (rule.type) {
        case M3u8RuleType.urlPattern:
          if (rule.pattern != null) {
            final reg = RegExp(rule.pattern!, caseSensitive: false);
            if (reg.hasMatch(segUri)) return true;
          }
        case M3u8RuleType.domainBlock:
          final host = Uri.tryParse(segUri)?.host ?? '';
          if (rule.blockedDomains?.any(
                (d) => host == d || host.endsWith('.$d'),
              ) ??
              false) {
            return true;
          }
        case M3u8RuleType.maxDuration:
          if (rule.maxDuration != null &&
              duration > 0 &&
              duration < rule.maxDuration!) {
            return true;
          }
        case M3u8RuleType.tagPresent:
          break;
      }
    }
    return false;
  }
}
