part of 'package:kostori/foundation/hub_services/services.dart';

/// 路由级中间件：返回 null 表示继续，返回 Response 表示短路。
typedef MiddlewareHandler = FutureOr<shelf.Response?> Function(
  shelf.Request request,
);

HttpConnectionInfo? _connectionInfo(shelf.Request request) =>
    request.context['shelf.io.connection_info'] as HttpConnectionInfo?;

String _remoteAddress(shelf.Request request) =>
    _connectionInfo(request)?.remoteAddress.address ?? '';

shelf.Response _jsonResponse(Object? data, {int status = HttpStatus.ok}) =>
    shelf.Response(
      status,
      body: jsonEncode(data),
      headers: {'content-type': 'application/json'},
    );

/// 请求体超限。由 [Middleware.readBodyCapped] 抛出，`BaseHttpService._dispatch` 统一转 413。
class BodyTooLarge implements Exception {
  final int maxBytes;
  const BodyTooLarge(this.maxBytes);

  @override
  String toString() => 'BodyTooLarge(maxBytes: $maxBytes)';
}

class Middleware {
  // ─────────────────────────────────────────
  // 鉴权：支持 Bearer token
  // ─────────────────────────────────────────

  /// 提取令牌：Authorization: Bearer > X-Api-Key > ?token= > ?api_key=
  /// （后两者是无头模式启动横幅对外公布的调用方式）
  static String? readToken(shelf.Request request) {
    final header = request.headers['authorization'];
    if (header != null && header.startsWith('Bearer ')) {
      final bearer = header.substring(7);
      if (bearer.isNotEmpty) return bearer;
    }
    final apiKeyHeader = request.headers['x-api-key'];
    if (apiKeyHeader != null && apiKeyHeader.isNotEmpty) return apiKeyHeader;
    final params = request.requestedUri.queryParameters;
    final query = params['token'] ?? params['api_key'];
    if (query != null && query.isNotEmpty) return query;
    return null;
  }

  /// 从 Authorization header 或 query 参数取 Key 校验
  static MiddlewareHandler auth({bool admin = false}) {
    return (shelf.Request request) {
      final token = readToken(request);

      final valid =
          token != null &&
          (admin
              // 管理接口：只接受管理层 Key
              ? ApiKeyManager().validateAdmin(token)
              // 普通接口：既接受用户层 Key，也接受管理层 Key
              : (ApiKeyManager().validate(token) ||
                    ApiKeyManager().validateAdmin(token)));

      if (!valid) {
        return _jsonResponse({
          'error': 'Unauthorized',
          'message': token == null
              ? 'Missing token (Authorization: Bearer <key>, X-Api-Key: <key>, '
                    '?token= or ?api_key=)'
              : 'Invalid token',
        }, status: HttpStatus.unauthorized);
      }

      return null;
    };
  }

  // ─────────────────────────────────────────
  // 本地免鉴权
  // ─────────────────────────────────────────

  /// Origin 是否指向本机。必须精确比对 host：`startsWith('http://localhost')`
  /// 会被 `localhost.evil.com` 这类可注册域名绕过。
  /// 也不能改用请求的 Host 头比对——DNS rebinding 下 Host 同样由攻击者控制。
  static bool _isSameMachineOrigin(String? origin) {
    if (origin == null || origin.isEmpty) return true; // 非浏览器请求
    final host = Uri.tryParse(origin)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  static MiddlewareHandler localBypass(MiddlewareHandler next) {
    return (shelf.Request request) {
      final ip = _remoteAddress(request);
      final isLocal =
          ip == '127.0.0.1' || ip == '::1' || ip == '0:0:0:0:0:0:0:1';
      // 浏览器发起的跨源请求即使来自本机也要求鉴权，
      // 防止恶意网页对 localhost 服务做 CSRF / DNS-rebinding 攻击。
      if (isLocal && _isSameMachineOrigin(request.headers['origin'])) {
        return null;
      }
      return next(request);
    };
  }

  // ─────────────────────────────────────────
  // 限流
  // ─────────────────────────────────────────

  static MiddlewareHandler rateLimit({
    int maxRequests = 60,
    Duration window = const Duration(minutes: 1),
  }) {
    final counts = <String, List<DateTime>>{};
    // 顺带清掉已静默的 IP，避免 IP 轮换导致 map 无限增长
    const sweepThreshold = 256;

    return (shelf.Request request) {
      final ip = _remoteAddress(request);
      final now = DateTime.now();
      final windowStart = now.subtract(window);

      if (counts.length > sweepThreshold) {
        counts.removeWhere((_, times) => times.last.isBefore(windowStart));
      }

      final hits = (counts[ip] ?? const <DateTime>[])
          .where((t) => t.isAfter(windowStart))
          .toList();

      if (hits.length >= maxRequests) {
        return shelf.Response(
          429,
          body: jsonEncode({
            'error': 'Too Many Requests',
            'message': '请求过于频繁，请稍后再试',
            'retryAfter': 60,
          }),
          headers: {'content-type': 'application/json', 'Retry-After': '60'},
        );
      }

      hits.add(now);
      counts[ip] = hits;
      return null;
    };
  }

  // ─────────────────────────────────────────
  // CORS（shelf 管道中间件，作用于所有响应）
  // ─────────────────────────────────────────

  static shelf.Middleware cors({
    String allowOrigin = '*',
    String allowMethods = 'GET, POST, PUT, DELETE, OPTIONS',
    String allowHeaders = 'Content-Type, Authorization',
  }) {
    final corsHeaders = {
      'Access-Control-Allow-Origin': allowOrigin,
      'Access-Control-Allow-Methods': allowMethods,
      'Access-Control-Allow-Headers': allowHeaders,
    };
    return (shelf.Handler inner) {
      return (shelf.Request request) async {
        if (request.method == 'OPTIONS') {
          return shelf.Response(HttpStatus.noContent, headers: corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: {...corsHeaders, ...response.headers});
      };
    };
  }

  // ─────────────────────────────────────────
  // Body 大小限制
  // ─────────────────────────────────────────

  /// 单个请求体允许的最大字节数（跟随上传配置）。
  static const int defaultMaxRequestBodyBytes = 5 * 1024 * 1024;

  /// 只取 maxSizeBytes 字段，不走 HubUploadConfig.fromJson（每请求都会调用）。
  static int get maxRequestBodyBytes {
    final raw = appdata.implicitData['hub_upload_config'];
    if (raw is Map) {
      final value = raw['maxSizeBytes'];
      if (value is num && value > 0) return value.toInt();
    }
    return defaultMaxRequestBodyBytes;
  }

  /// 带上限的请求体字节流。超限后不再 `yield`，但**继续消费**剩余 body：
  /// dart:io 要求请求体读完才会写响应，中途抛异常会让连接在响应前被拆掉，
  /// 客户端只看到 connection reset 而不是 413。消费即丢弃，不占内存。
  ///
  /// 超过 [drainCapBytes] 说明客户端在无限推流，直接放弃让连接断开。
  static Stream<List<int>> readBodyCapped(
    shelf.Request request, {
    int? maxBytes,
    int? drainCapBytes,
  }) async* {
    final limit = maxBytes ?? maxRequestBodyBytes;
    final drainCap = drainCapBytes ?? limit * 4;
    var total = 0;
    var discarded = 0;
    var overflowed = false;
    await for (final chunk in request.read()) {
      if (overflowed) {
        discarded += chunk.length;
        if (discarded > drainCap) throw BodyTooLarge(limit);
        continue;
      }
      total += chunk.length;
      if (total > limit) {
        overflowed = true;
        continue;
      }
      yield chunk;
    }
    if (overflowed) throw BodyTooLarge(limit);
  }

  /// 带上限的请求体文本。
  static Future<String> readBodyStringCapped(
    shelf.Request request, {
    int? maxBytes,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in readBodyCapped(request, maxBytes: maxBytes)) {
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  /// 只查 `content-length` 的快路径，省掉一次无谓的流读取。
  /// 真正的强制点在 [readBodyCapped]（chunked 请求没有 content-length）。
  static MiddlewareHandler bodySizeLimit() {
    return (shelf.Request request) {
      final contentLength = int.tryParse(
        request.headers['content-length'] ?? '',
      );
      final maxBytes = maxRequestBodyBytes;
      if (contentLength != null && contentLength > maxBytes) {
        return _tooLarge(maxBytes, contentLength);
      }
      return null;
    };
  }

  static shelf.Response _tooLarge(int maxBytes, int? received) =>
      _jsonResponse({
        'error': 'Request Entity Too Large',
        'maxBytes': maxBytes,
        if (received != null) 'receivedBytes': received,
      }, status: HttpStatus.requestEntityTooLarge);

  // ─────────────────────────────────────────
  // IP 白名单
  // ─────────────────────────────────────────

  static MiddlewareHandler ipWhitelist(List<String> allowedIps) {
    return (shelf.Request request) {
      final ip = _remoteAddress(request);

      // 本地永远放行
      final isLocal = ip == '127.0.0.1' || ip == '::1';
      if (isLocal) return null;

      if (!allowedIps.contains(ip)) {
        return _jsonResponse({
          'error': 'Forbidden',
          'message': 'IP $ip is not allowed',
        }, status: HttpStatus.forbidden);
      }

      return null;
    };
  }
}
