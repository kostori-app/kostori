import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/mirror_store.dart';
import 'package:kostori/network/cache.dart';
import 'package:kostori/network/cloudflare.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/network/dns_resolver.dart';
import 'package:kostori/network/domain_rules.dart';
import 'package:kostori/network/hosts_probe.dart';
import 'package:kostori/network/proxy.dart';
import 'package:rhttp/rhttp.dart' as rhttp;

export 'package:dio/dio.dart';

/// 标记该失败已由 [MyLogInterceptor] 记入网络日志（挂在 `RequestOptions.extra`）。
/// 上层（如番剧源 parser）据此跳过重复记录，避免日志里出现两条同名「Network」错误。
const loggedKey = '__netLogged';

/// 该异常是否已被 [MyLogInterceptor] 记录过。
bool isNetworkErrorLogged(Object? error) =>
    error is DioException && error.requestOptions.extra[loggedKey] == true;

class MyLogInterceptor extends Interceptor {
  /// 隐私脱敏：敏感请求/响应头的值打码；cookie 只保留名字（便于排查又不泄露）。
  static String _redactHeaders(Map<dynamic, dynamic> headers) {
    bool sensitive(String lower) =>
        lower == 'authorization' ||
        lower == 'proxy-authorization' ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('api-key') ||
        lower.contains('apikey') ||
        lower.contains('auth');
    final out = <String, String>{};
    headers.forEach((k, v) {
      final key = k.toString();
      final lower = key.toLowerCase();
      if (lower == 'cookie' || lower == 'set-cookie') {
        final names = v
            .toString()
            .split(';')
            .map((p) => p.split('=').first.trim())
            .where((n) => n.isNotEmpty)
            .toSet();
        out[key] = '<${names.length} cookie(s): ${names.join(', ')}>';
      } else if (sensitive(lower)) {
        out[key] = '<redacted>';
      } else {
        out[key] = v.toString();
      }
    });
    return out.toString();
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 标注 noLog 的请求（如 HLS 分片，动辄上千条）不记录，避免刷屏
    if (err.requestOptions.extra['noLog'] == true) {
      handler.next(err);
      return;
    }
    // 请求失败一律记录（错误日志不需要正文），概要模式下也只记一行；
    // 带上脱敏后的请求头，便于定位问题
    NetLog.error(
      "Network",
      NetLog.metaOnly
          ? '${err.requestOptions.method} ${err.requestOptions.uri} → ${err.response?.statusCode ?? err.type.name}'
          : "${err.requestOptions.method} ${err.requestOptions.path}\n"
                "request headers:\n${_redactHeaders(err.requestOptions.headers)}\n"
                "$err\n${err.response?.data.toString()}",
    );
    err.requestOptions.extra[loggedKey] = true;
    switch (err.type) {
      case DioExceptionType.badResponse:
        var statusCode = err.response?.statusCode;
        if (statusCode != null) {
          err = err.copyWith(
            message:
                "Invalid Status Code: $statusCode. "
                "${_getStatusCodeInfo(statusCode)}",
          );
        }
      case DioExceptionType.connectionTimeout:
        err = err.copyWith(message: t.connectionTimeout);
      case DioExceptionType.receiveTimeout:
        err = err.copyWith(message: t.receiveTimeout);
      case DioExceptionType.unknown:
        final detail = '${err.error} ${err.message}';
        if (detail.contains('Connection terminated during handshake') ||
            detail.contains('handshake')) {
          err = err.copyWith(message: t.connectionTerminatedDuringHandshake);
        } else if (detail.contains('Connection reset by peer') ||
            detail.contains('ConnectionReset')) {
          err = err.copyWith(message: t.connectionResetByPeer);
        }
      default:
        {}
    }
    handler.next(err);
  }

  static const errorMessages = <int, String>{
    400: "The Request is invalid.",
    401: "The Request is unauthorized.",
    403: "No permission to access the resource. Check your account or network.",
    404: "Not found.",
    429: "Too many requests. Please try again later.",
  };

  String _getStatusCodeInfo(int? statusCode) {
    if (statusCode != null && statusCode >= 500) {
      return "This is server-side error, please try again later. "
          "Do not report this issue.";
    } else {
      return errorMessages[statusCode] ?? "";
    }
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // 标注 noLog 的请求（如 HLS 分片）不记录
    if (response.requestOptions.extra['noLog'] == true) {
      handler.next(response);
      return;
    }
    if (!NetLog.enabled) {
      handler.next(response);
      return;
    }
    // 二进制响应（图片/文件下载）成功时静默：量大且基本是缩略图，只有失败才需要日志
    if (response.data is List<int> && (response.statusCode ?? 0) < 400) {
      handler.next(response);
      return;
    }
    final startedMs = response.requestOptions.extra['__logStartMs'];
    final costMs = startedMs is int
        ? DateTime.now().millisecondsSinceEpoch - startedMs
        : null;
    if (NetLog.metaOnly) {
      // 概要模式：一行记录「状态/大小/耗时」，不含头与正文
      final len =
          response.headers.value('content-length') ??
          (response.data is List<int>
              ? '${(response.data as List<int>).length}'
              : '');
      NetLog.log(
        (response.statusCode != null && response.statusCode! < 400)
            ? LogLevel.info
            : LogLevel.error,
        '← Network',
        '${response.statusCode} ${response.realUri}'
            '${len.isNotEmpty ? ' · $len B' : ''}'
            '${costMs != null ? ' · ${costMs}ms' : ''}',
      );
      handler.next(response);
      return;
    }
    var headers = response.headers.map.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        value.length == 1 ? value.first : value.toString(),
      ),
    );
    // 日志正文限长：大响应（大 JSON/HTML、二进制）只记长度/前缀，
    // 避免构造并持有 MB 级字符串（内存与卡顿的主要来源）
    const logBodyLimit = 32768;
    String content;
    if (response.data is List<int>) {
      final bytes = response.data as List<int>;
      if (bytes.length > logBodyLimit) {
        content = "<Bytes>\nlength:${bytes.length} (body omitted)";
      } else {
        try {
          content = utf8.decode(bytes, allowMalformed: false);
        } catch (e) {
          content = "<Bytes>\nlength:${bytes.length}";
        }
      }
    } else {
      final s = response.data.toString();
      content = s.length > logBodyLimit
          ? '${s.substring(0, logBodyLimit)}…(omitted ${s.length - logBodyLimit} chars)'
          : s;
    }

    NetLog.log(
      (response.statusCode != null && response.statusCode! < 400)
          ? LogLevel.info
          : LogLevel.error,
      "Network",
      "Response ${response.realUri.toString()} ${response.statusCode}\n"
          "headers:\n${_redactHeaders(headers)}\n$content",
    );

    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 计时：概要模式用
    options.extra['__logStartMs'] = DateTime.now().millisecondsSinceEpoch;
    // 默认超时须在日志开关判断前套用，否则默认（NetLog 关闭）时超时失效；
    // 流式 / noLog / bytes 请求由调用方自行管理超时，不覆盖。
    if (options.extra['noLog'] != true &&
        options.extra['streaming'] != true &&
        options.responseType != ResponseType.bytes) {
      options.connectTimeout ??= const Duration(seconds: 15);
      options.receiveTimeout ??= const Duration(seconds: 15);
      options.sendTimeout ??= const Duration(seconds: 15);
    }
    // 标注 noLog 的请求（如 HLS 分片，动辄上千条）不记录，避免刷屏
    if (options.extra['noLog'] == true) {
      handler.next(options);
      return;
    }
    if (!NetLog.enabled) {
      handler.next(options);
      return;
    }
    if (NetLog.metaOnly) {
      // 概要模式：一行摘要 + 脱敏请求头（失败时靠它定位是哪个头不对）
      if (options.responseType != ResponseType.bytes) {
        NetLog.info(
          "→ Network",
          '${options.method} ${options.uri}\n'
              'headers:\n${_redactHeaders(options.headers)}',
        );
      }
      handler.next(options);
      return;
    }
    if (options.responseType == ResponseType.bytes) {
      handler.next(options);
      return;
    }
    // 请求体同样限长（base64 图片上传等可能很大）
    final rawData = options.data?.toString() ?? '';
    const reqLimit = 16384;
    final data = rawData.length > reqLimit
        ? '${rawData.substring(0, reqLimit)}…(omitted ${rawData.length - reqLimit} chars)'
        : rawData;
    NetLog.info(
      "Network",
      "${options.method} ${options.uri}\n"
          "headers:\n${_redactHeaders(options.headers)}\n"
          "data:\n$data",
    );
    handler.next(options);
  }
}

/// 把网络异常转成给用户看的简短信息：错误类型 + 状态码 + 访问地址。
/// 不再原样输出 DioException / 底层库的长串。
String networkErrorMessage(Object? error) {
  // 保持 Cloudflare 标记原样：NetworkError 靠它识别并给出验证按钮
  if (error is CloudflareException) return error.toString();
  if (error is DioException) {
    final status = error.response?.statusCode;
    final typeText = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => t.connectionTimedOut,
      DioExceptionType.cancel => t.cancel,
      DioExceptionType.badResponse => t.requestFailed,
      DioExceptionType.badCertificate ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => t.connectionFailed,
    };
    final statusPart = status != null ? ' · HTTP $status' : '';
    return '$typeText$statusPart\n${error.requestOptions.uri}';
  }
  final text = error?.toString() ?? 'Unknown error';
  // 有些路径把 DioException 变成了字符串（经 JS 引擎/包装），这里兜底再缩短一次：
  // 提取地址 + 判断连接类错误，避免把整段 Rhttp/hyper 长串直接丢给用户。
  if (text.contains('DioException') ||
      text.contains('Rhttp') ||
      text.contains('Connection error')) {
    final url = RegExp(r'https?://[^\s)\]"，,]+').firstMatch(text)?.group(0);
    return url == null ? t.connectionFailed : '${t.connectionFailed}\n$url';
  }
  return text;
}

class AppDio with DioMixin {
  /// 是否打印请求/响应/错误日志。静默模式用于图片缩略图、
  /// 后台轮询等失败属正常场景的请求，避免 error 日志刷屏。
  final bool verboseLog;

  AppDio([
    // ignore: prefer_initializing_formals
    BaseOptions? options,
    bool verboseLog = true,
  ]) : verboseLog = verboseLog {
    this.options = options ?? BaseOptions();
    httpClientAdapter = RHttpAdapter();
    if (App.isInitialized) {
      interceptors.add(CookieManagerSql());
      interceptors.add(NetworkCacheManager());
      interceptors.add(CloudflareInterceptor());
      interceptors.add(BangumiMirrorInterceptor());
      interceptors.add(GithubMirrorInterceptor());
      // 图片缩略图等高频、可恢复的请求不打 error 日志，避免刷屏
      if (verboseLog) {
        interceptors.add(MyLogInterceptor());
      }
    }
  }

  /// 静默模式：不打印请求/响应/错误日志。
  AppDio.quiet([BaseOptions? options]) : this(options, false);
}

class RHttpAdapter implements HttpClientAdapter {
  /// 构造出来的解析器缓存：配置内容没变就复用同一个。
  static String? _dnsSettingsSignature;
  static rhttp.DnsSettings? _dnsSettingsCache;

  /// 已记录过的 hosts 覆写（每个「域名 -> IP」每进程只记一次，避免高频请求刷日志）
  static final Set<String> _loggedHostsOverrides = {};

  Future<rhttp.ClientSettings> settings(RequestOptions options) async {
    final proxy = await getProxy();

    final rules = loadDomainRules();

    final isNoProxy =
        noProxyOverridesEnabled && shouldBypassProxy(rules, options.uri.host);

    // 尊重 dio 的重定向设置：maxRedirects:0 / followRedirects:false 时不跟随，
    // 便于登录/授权等流程拦截 302（chii_auth、location 等关键信息在 302 响应里）
    final redirectSettings =
        options.followRedirects == false || options.maxRedirects <= 0
        ? const rhttp.RedirectSettings.none()
        : rhttp.RedirectSettings.limited(options.maxRedirects);

    // 下载等场景强制 HTTP/1.1：部分 CDN（moedet/CCDN 等）对
    // reqwest 默认协商出的 HTTP/2 请求返回 400，而 curl/浏览器（HTTP/1.1）正常
    final httpVersionPref = options.extra['httpVersion11'] == true
        ? rhttp.HttpVersionPref.http1_1
        : rhttp.HttpVersionPref.all;

    // 显式传 noProxy() 会连带关掉 reqwest 的环境变量代理，故 system 模式传 null
    final rhttp.ProxySettings? proxySettings;
    if (isNoProxy || appdata.settings['proxy'] == "direct") {
      proxySettings = const rhttp.ProxySettings.noProxy();
    } else if (proxy != null) {
      proxySettings = rhttp.ProxySettings.proxy(proxy);
    } else {
      proxySettings = null;
    }

    return rhttp.ClientSettings(
      httpVersionPref: httpVersionPref,
      proxySettings: proxySettings,
      redirectSettings: redirectSettings,
      timeoutSettings: const rhttp.TimeoutSettings(
        connectTimeout: Duration(seconds: 15),
        keepAliveTimeout: Duration(seconds: 60),
        keepAlivePing: Duration(seconds: 30),
      ),
      throwOnStatusCode: false,
      dnsSettings: _buildDnsSettings(rules),
      tlsSettings: rhttp.TlsSettings(
        sni: appdata.settings['sni'] != false,
        verifyCertificates: appdata.settings['ignoreBadCertificate'] != true,
      ),
    );
  }

  /// 有「指定 DNS」规则时切到动态解析器（由 [DnsResolver] 并发查询多个
  /// 上游、取最快返回的地址，并处理 hosts 规则）；否则用静态 hosts 表。
  static rhttp.DnsSettings _buildDnsSettings(List<DomainRule> rules) {
    final signature =
        '${dnsOverridesEnabled && hasDnsServerRules(rules) ? 'dynamic' : 'static'}'
        '|${dnsOverridesEnabled ? _hostsSignature(rules) : ''}';
    final cached = _dnsSettingsCache;
    if (_dnsSettingsSignature == signature && cached != null) return cached;

    final rhttp.DnsSettings settings;
    if (signature.startsWith('dynamic')) {
      settings = rhttp.DnsSettings.dynamic(resolver: _resolveHost);
    } else {
      settings = rhttp.DnsSettings.static(overrides: _hostsOverrides(rules));
    }
    // 规则变了，之前探测出的「最快 IP」也跟着失效
    _fastestIpCache.clear();
    _dnsSettingsSignature = signature;
    _dnsSettingsCache = settings;
    return settings;
  }

  /// 动态解析入口：先看命中规则的 hosts IP / 指定 DNS，都没有就用系统解析。
  static Future<List<String>> _resolveHost(String host) async {
    if (dnsOverridesEnabled) {
      final rule = matchDnsRule(loadDomainRules(), host);
      if (rule != null) {
        if (rule.dnsMode == DnsRuleMode.hosts) {
          final ips = hostsIpsOf(rule);
          if (ips.isNotEmpty) return ips;
        } else if (rule.dnsMode == DnsRuleMode.servers) {
          return DnsResolver.resolve(host, buildDnsPlan(rule));
        }
      }
    }
    return DnsResolver.resolve(host, buildDnsPlan(null));
  }

  static Map<String, List<String>> _hostsOverrides(List<DomainRule> rules) =>
      dnsOverridesEnabled
      ? buildHostsOverrides(rules)
      : const <String, List<String>>{};

  static String _hostsSignature(List<DomainRule> rules) =>
      _hostsOverrides(rules).entries
          .map((e) => '${e.key}:${e.value.join(',')}')
          .join('|');

  /// 命中 [host]（含子域名）的 hosts 规则里可直接使用的 IP。
  ///
  /// 全局 hosts 表按规则域名精确匹配，所以先取精确命中的条目；
  /// 没有精确条目时按「第一条带地址来源的规则」匹配，匹配到 hosts 规则
  /// 后由调用方补一条本次请求的覆写。
  static List<String>? _matchedHostsIps(
    String host,
    List<DomainRule> rules,
    Map<String, List<String>> overrides,
  ) {
    if (!dnsOverridesEnabled || host.isEmpty) return null;
    final exact = overrides[host];
    if (exact != null && exact.isNotEmpty) return exact;
    final rule = matchDnsRule(rules, host);
    if (rule == null || rule.dnsMode != DnsRuleMode.hosts) return null;
    final ips = hostsIpsOf(rule);
    return ips.isEmpty ? null : ips;
  }

  /// hosts 覆写能否在代理链路上生效。
  ///
  /// HTTP 代理由代理自己解析目标域名，钉的 IP 会被忽略；只有直连
  /// 或本地解析的 SOCKS5（socks5://，不是 socks5h://）才用得上覆写。
  static bool _proxyKeepsHostsOverride(rhttp.ProxySettings? settings) {
    if (settings == null || settings is! rhttp.CustomProxy) return true;
    return settings is rhttp.StaticProxy &&
        settings.url.toLowerCase().startsWith('socks5://');
  }

  static rhttp.HttpHeaders _rhttpHeaders(RequestOptions options) =>
      rhttp.HttpHeaders.rawMap(
        Map.fromEntries(
          options.headers.entries.map(
            (e) => MapEntry(e.key, e.value.toString().trim()),
          ),
        ),
      );

  ResponseBody _responseBody(
    RequestOptions options,
    rhttp.HttpStreamResponse res,
  ) {
    final headers = <String, List<String>>{};
    for (final entry in res.headers) {
      final key = entry.$1.toLowerCase();
      headers[key] ??= [];
      headers[key]!.add(entry.$2);
    }
    return ResponseBody(
      _guardBody(options, res.body),
      res.statusCode,
      statusMessage: _getStatusMessage(res.statusCode),
      isRedirect: false,
      headers: headers,
    );
  }

  /// 多 IP 时先并发 TCP 探测，挑最先连上的 IP 作为本次请求的目标；
  /// 结果按「域名|端口|IP 列表」缓存 2 分钟，失败时清掉重探。
  static final Map<String, (String ip, DateTime expire)> _fastestIpCache = {};

  /// 返回 `(选中的 IP, 缓存 key)`；全部连不上时返回 null。
  static Future<(String, String)?> _pickFastestIp(
    String host,
    List<String> ips,
    int port,
  ) async {
    final key = '$host|$port|${ips.join(',')}';
    final cached = _fastestIpCache[key];
    if (cached != null && cached.$2.isAfter(DateTime.now())) {
      return (cached.$1, key);
    }
    final winner = await HostsProbe.firstReachable(
      ips,
      port: port,
      timeout: const Duration(seconds: 3),
    );
    if (winner == null) return null;
    _fastestIpCache[key] = (
      winner,
      DateTime.now().add(const Duration(minutes: 2)),
    );
    return (winner, key);
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['User-Agent'] == null &&
        options.headers['user-agent'] == null) {
      options.headers['User-Agent'] =
          "kostori/v${App.version} (Android) (https://github.com/kostori-app/kostori)";
    }

    final rules = loadDomainRules();
    var clientSettings = await settings(options);
    final overrides = _hostsOverrides(rules);

    // hosts 规则命中的域名按请求把地址钉死（子域名规则也能生效）：
    // 单个 IP 直接用，多个 IP 先并发探测出最快的。
    final hostsIps = _matchedHostsIps(options.uri.host, rules, overrides);
    String? fastestIpKey;
    if (hostsIps != null) {
      if (NetLog.enabled &&
          _loggedHostsOverrides.add(
            '${options.uri.host}|${hostsIps.join(',')}',
          )) {
        NetLog.info(
          'DNS',
          'hosts 覆写生效：${options.uri.host} → ${hostsIps.join(', ')}',
        );
      }
      var requestIps = hostsIps;
      if (hostsIps.length > 1 &&
          _proxyKeepsHostsOverride(clientSettings.proxySettings)) {
        final port = options.uri.hasPort
            ? options.uri.port
            : (options.uri.scheme == 'https' ? 443 : 80);
        final picked = await _pickFastestIp(options.uri.host, hostsIps, port);
        if (picked != null) {
          requestIps = [picked.$1];
          fastestIpKey = picked.$2;
        }
      }
      // 子域名命中或选出了最快 IP 时补一条本次请求的覆写
      if (!overrides.containsKey(options.uri.host) ||
          requestIps.length != hostsIps.length) {
        clientSettings = clientSettings.copyWith(
          dnsSettings: rhttp.DnsSettings.static(
            overrides: {...overrides, options.uri.host: requestIps},
          ),
        );
      }
    }

    // 将 dio 的取消信号转发给 rhttp，真正中断正在进行的（流式）请求
    final rhttpCancelToken = cancelFuture == null ? null : rhttp.CancelToken();
    if (rhttpCancelToken != null) {
      unawaited(cancelFuture!.then((_) => rhttpCancelToken.cancel()));
    }

    Future<ResponseBody> doRequest() async {
      final res = await rhttp.Rhttp.request(
        method: rhttp.HttpMethod(options.method),
        url: options.uri.toString(),
        settings: clientSettings,
        expectBody: rhttp.HttpExpectBody.stream,
        body: requestStream == null
            ? null
            : rhttp.HttpBody.stream(requestStream),
        headers: _rhttpHeaders(options),
        cancelToken: rhttpCancelToken,
      );
      if (res is! rhttp.HttpStreamResponse) {
        throw Exception("Invalid response type: ${res.runtimeType}");
      }
      return _responseBody(options, res);
    }

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await doRequest();
      } catch (e, s) {
        // 移动网络下 TLS 握手中断、连接重置属于瞬时故障，重连一次
        // （可能换到另一个 IP / CDN 节点）通常即可成功。
        if (attempt < _maxAttempts &&
            _isReplayable(options, requestStream) &&
            _isConnectionError(e)) {
          NetLog.info(
            'Network',
            '连接失败，重试 ${attempt + 1}/$_maxAttempts: ${options.method} '
                '${options.uri} ($e)',
          );
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
          continue;
        }
        // 选出的最快 IP 失效：清缓存并回退到完整列表（底层依次尝试）
        final key = fastestIpKey;
        if (key == null || e is rhttp.RhttpCancelException) {
          Error.throwWithStackTrace(e, s);
        }
        _fastestIpCache.remove(key);
        // 只回退一次：否则对端持续不可用时会一直循环
        fastestIpKey = null;
        clientSettings = clientSettings.copyWith(
          dnsSettings: rhttp.DnsSettings.static(
            overrides: {...overrides, options.uri.host: hostsIps!},
          ),
        );
      }
    }
  }

  /// 连接类错误的最大尝试次数（含首次）。
  static const int _maxAttempts = 3;

  /// 只重试可安全重放的请求：幂等方法且没有请求体流（流无法重放）。
  static bool _isReplayable(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
  ) {
    if (requestStream != null) return false;
    const idempotent = {'GET', 'HEAD', 'OPTIONS'};
    return idempotent.contains(options.method.toUpperCase());
  }

  /// rhttp 抛的是 flutter_rust_bridge 异常，没有稳定类型，只能按文本判定。
  /// 用户主动取消不算连接故障。
  static bool _isConnectionError(Object e) {
    if (e is rhttp.RhttpCancelException) return false;
    if (e is DioException) {
      return switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => true,
        _ => false,
      };
    }
    final text = e.toString();
    return text.contains('RhttpConnection') ||
        text.contains('Connection error') ||
        text.contains('tls handshake') ||
        text.contains('Connection reset');
  }

  /// 把响应体流的错误统一转成 [DioException]。
  ///
  /// rhttp/reqwest 在响应体解码失败时（压缩编码不支持、连接中途断开等）抛的是
  /// `AnyhowException`，既不是 [DioException] 也可能没挂到 dio 的错误管线，
  /// 会以裸露的 flutter_rust_bridge 异常出现在界面上。
  Stream<Uint8List> _guardBody(
    RequestOptions options,
    Stream<Uint8List> body,
  ) async* {
    try {
      yield* body;
    } catch (e, s) {
      NetLog.error('Network', '${options.method} ${options.uri} 响应体读取失败: $e');
      Error.throwWithStackTrace(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          error: e,
          message: t.networkRequestFailed,
        ),
        s,
      );
    }
  }

  static String _getStatusMessage(int statusCode) {
    return switch (statusCode) {
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      204 => "No Content",
      206 => "Partial Content",
      301 => "Moved Permanently",
      302 => "Found",
      400 => "Invalid Status Code 400: The Request is invalid.",
      401 => "Invalid Status Code 401: The Request is unauthorized.",
      403 => "Invalid Status Code 403: No permission to access the resource. Check your account or network.",
      404 => "Invalid Status Code 404: Not found.",
      429 =>
        "Invalid Status Code 429: Too many requests. Please try again later.",
      _ => "Invalid Status Code $statusCode",
    };
  }
}

/// WebDAV 专用适配器：在 [RHttpAdapter] 基础上强制 HTTP/1.1 且声明不接受压缩响应，
/// 规避部分 WebDAV 服务器 / 反代返回无法解码的响应体
/// （reqwest 报 "error decoding response body"）。
class WebdavRHttpAdapter extends RHttpAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    options.headers['Accept-Encoding'] = 'identity';
    options.extra['httpVersion11'] = true;
    return super.fetch(options, requestStream, cancelFuture);
  }
}

/// 把 Bangumi 官方接口主机（api.bgm.tv）、p1 接口主机（next.bgm.tv）、图片主机
/// （lain.bgm.tv）分别改写为用户对应选中的镜像，其余请求原样放行。三个镜像在
/// 「网络设置」里分别维护。
class BangumiMirrorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final original = options.uri.toString();
    // 图片：只用图片镜像（通常只反代 lain.bgm.tv）
    final imageMirrored = applyBangumiImageMirror(original);
    if (imageMirrored != original) {
      _applyMirroredUrl(options, imageMirrored);
      handler.next(options);
      return;
    }
    // p1 接口：用 p1 镜像
    final p1Mirrored = applyBangumiP1Mirror(original);
    if (p1Mirrored != original) {
      _applyMirroredUrl(options, p1Mirrored);
      _stripAuthFromMirror(options);
      handler.next(options);
      return;
    }
    // 主接口：用主接口镜像
    final mirrored = applyBangumiMirror(original);
    if (mirrored != original) {
      _applyMirroredUrl(options, mirrored);
      _stripAuthFromMirror(options);
    }
    handler.next(options);
  }

  /// 镜像地址要拆回 path + query，否则 queryParameters 会被拼两次
  void _applyMirroredUrl(RequestOptions options, String mirrored) {
    final uri = Uri.parse(mirrored);
    options.path = uri.origin.isEmpty
        ? '${uri.scheme}://${uri.host}${uri.path}'
        : uri.origin + uri.path;
    options.queryParameters = Map.of(uri.queryParameters);
  }

  /// 默认不把登录鉴权/凭证交给镜像；仅当用户显式开启时才带上
  void _stripAuthFromMirror(RequestOptions options) {
    if (bangumiMirrorSendAuth) return;
    options.headers.remove('authorization');
    options.headers.remove('Authorization');
    options.headers.remove('cookie');
    options.headers.remove('Cookie');
  }
}

/// 把 GitHub / jsDelivr 请求改写为用户选中的镜像。
/// `extra['noGithubMirror'] == true` 可让单个请求跳过（如「官方下载」按钮）。
class GithubMirrorInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra['noGithubMirror'] == true) {
      handler.next(options);
      return;
    }
    final original = options.uri.toString();
    final mirrored = applyGithubMirror(
      original,
      largeFile: options.extra['githubLargeFile'] == true,
    );
    if (mirrored != original) {
      final uri = Uri.parse(mirrored);
      options.path = uri.origin.isEmpty
          ? '${uri.scheme}://${uri.host}${uri.path}'
          : uri.origin + uri.path;
      options.queryParameters = Map.of(uri.queryParameters);
    }
    handler.next(options);
  }
}
