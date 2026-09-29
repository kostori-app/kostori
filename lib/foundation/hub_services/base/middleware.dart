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

class Middleware {
  // ─────────────────────────────────────────
  // 鉴权：支持 Bearer token
  // ─────────────────────────────────────────

  /// 从 Authorization header 或 query 参数取 Key 校验
  static MiddlewareHandler auth({bool admin = false}) {
    return (shelf.Request request) {
      final header = request.headers['authorization'];
      final bearerToken = header != null && header.startsWith('Bearer ')
          ? header.substring(7)
          : null;
      final queryToken = request.requestedUri.queryParameters['token'];
      final token = bearerToken ?? queryToken;

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
              ? 'Missing token (Authorization: Bearer <key> or ?token=)'
              : 'Invalid token',
        }, status: HttpStatus.unauthorized);
      }

      return null;
    };
  }

  // ─────────────────────────────────────────
  // 本地免鉴权
  // ─────────────────────────────────────────

  static MiddlewareHandler localBypass(MiddlewareHandler next) {
    return (shelf.Request request) {
      final ip = _remoteAddress(request);
      final isLocal =
          ip == '127.0.0.1' || ip == '::1' || ip == '0:0:0:0:0:0:0:1';
      // 浏览器发起的跨源请求（带 Origin 头且非本站）即使来自本机也要求鉴权，
      // 防止恶意网页对 localhost 服务做 CSRF / DNS-rebinding 攻击。
      final origin = request.headers['origin'];
      final isCrossOriginBrowserRequest =
          origin != null && !origin.startsWith('http://localhost');
      if (isLocal && !isCrossOriginBrowserRequest) return null;
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

    return (shelf.Request request) {
      final ip = _remoteAddress(request).isEmpty
          ? 'unknown'
          : _remoteAddress(request);
      final now = DateTime.now();
      final windowStart = now.subtract(window);

      counts[ip] = (counts[ip] ?? [])
          .where((t) => t.isAfter(windowStart))
          .toList();

      if (counts[ip]!.length >= maxRequests) {
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

      counts[ip]!.add(now);
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

  static MiddlewareHandler bodySizeLimit() {
    final raw = appdata.implicitData['hub_upload_config'];
    final config = raw is Map<String, dynamic>
        ? HubUploadConfig.fromJson(raw)
        : const HubUploadConfig();
    final maxBytes = config.maxSizeBytes;

    return (shelf.Request request) {
      final contentLength = int.tryParse(
        request.headers['content-length'] ?? '',
      );
      if (contentLength != null && contentLength > maxBytes) {
        return _jsonResponse({
          'error': 'Request Entity Too Large',
          'maxBytes': maxBytes,
          'receivedBytes': contentLength,
        }, status: HttpStatus.requestEntityTooLarge);
      }
      return null;
    };
  }

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
