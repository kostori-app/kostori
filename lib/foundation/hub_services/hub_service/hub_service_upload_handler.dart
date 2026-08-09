// hub_upload_handler.dart
part of 'package:kostori/foundation/hub_services/services.dart';

/// HubService 上传功能扩展
extension HubServiceUploadHandler on HubService {
  // ── 持久化 key ──
  static const _uploadConfigKey = 'hub_upload_config';

  // ── 加载/保存配置 ──

  HubUploadConfig get uploadConfig {
    final raw = appdata.implicitData[_uploadConfigKey];
    if (raw is Map<String, dynamic>) {
      return HubUploadConfig.fromJson(raw);
    }
    return const HubUploadConfig();
  }

  set uploadConfig(HubUploadConfig config) {
    appdata.implicitData[_uploadConfigKey] = config.toJson();
    appdata.writeImplicitData();
  }

  // ── 本地存储目录 ──

  String get _uploadDir {
    final custom = uploadConfig.localStorePath;
    if (custom != null && custom.isNotEmpty) return custom;
    return p.join(App.dataPath, 'hub_uploads');
  }

  Future<void> _ensureUploadDir() async {
    final dir = Directory(_uploadDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  // ── 注册路由 ──

  void registerUploadRoutes() {
    addPost(
      '/hub/upload',
      _handleUpload,
      middlewares: [
        ..._hubAuthMiddleware,
        Middleware.rateLimit(
          maxRequests: 30,
          window: const Duration(minutes: 1),
        ),
      ],
    );
    // 文件读取保持公开：文件名是内容哈希（不可枚举、不可猜测），
    // 且聊天图片由 <img> 加载无法携带 Authorization 头
    addGet('/hub/files/<filename>', _handleServeFile);
    addGet(
      '/hub/upload/config',
      _handleGetUploadConfig,
      middlewares: _hubAuthMiddleware,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  POST /hub/upload
  // ═══════════════════════════════════════════════════════

  Future<void> _handleUpload(HttpRequest request) async {
    try {
      final config = uploadConfig;

      // 客户端直传模式，服务端不接受上传
      if (config.mode == HubUploadMode.clientOss) {
        await sendJson(request, {
          'error': 'Server does not accept uploads in clientOss mode',
        }, status: HttpStatus.badRequest);
        return;
      }

      // 检查 Content-Type
      final contentType = request.headers.contentType;
      if (contentType == null ||
          contentType.primaryType != 'multipart' ||
          contentType.subType != 'form-data') {
        await sendJson(request, {
          'error': 'Expected multipart/form-data',
        }, status: HttpStatus.badRequest);
        return;
      }

      final boundary = contentType.parameters['boundary'];
      if (boundary == null || boundary.isEmpty) {
        await sendJson(request, {
          'error': 'Missing boundary',
        }, status: HttpStatus.badRequest);
        return;
      }

      // 读取全部 body（流式限界，防止超大请求占用内存）
      final Uint8List bodyBytes;
      try {
        bodyBytes = await _collectBytes(
          request,
          maxBytes: config.maxSizeBytes + 4096,
        );
      } on _UploadTooLarge {
        final maxMb = (config.maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
        await sendJson(request, {
          'error': 'File too large (max ${maxMb}MB)',
        }, status: HttpStatus.requestEntityTooLarge);
        return;
      }

      // 大小预检：multipart 总长需含 boundary/header 余量
      if (bodyBytes.length > config.maxSizeBytes + 4096) {
        final maxMb = (config.maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
        await sendJson(request, {
          'error': 'File too large (max ${maxMb}MB)',
        }, status: HttpStatus.requestEntityTooLarge);
        return;
      }

      // 解析 multipart
      final parsed = _parseMultipart(bodyBytes, boundary);
      if (parsed == null || parsed.bytes.isEmpty) {
        await sendJson(request, {
          'error': 'No file found in request',
        }, status: HttpStatus.badRequest);
        return;
      }

      // 仅接受图片类型（防上传非图片文件被存储/分发）
      final allowedMime = _isAllowedImageMime(parsed.mimeType);
      if (!allowedMime) {
        await sendJson(request, {
          'error': 'Only image uploads are allowed',
        }, status: HttpStatus.unsupportedMediaType);
        return;
      }

      // 精确大小检查
      if (parsed.bytes.length > config.maxSizeBytes) {
        final maxMb = (config.maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
        await sendJson(request, {
          'error': 'File too large (max ${maxMb}MB)',
        }, status: HttpStatus.requestEntityTooLarge);
        return;
      }

      // ── 缓存命中直接返回 ──────────────────────────────────────────────
      final hash = md5.convert(parsed.bytes).toString();
      final cached = _uploadCache[hash];
      if (cached != null) {
        HubLog.info('HubUpload', 'cache hit: $hash → $cached');
        await sendJson(request, {'url': cached});
        return;
      }

      // ── 存储 ──────────────────────────────────────────────────────────
      String url;
      switch (config.mode) {
        case HubUploadMode.serverLocal:
          url = await _storeLocal(parsed.filename, parsed.bytes);

        case HubUploadMode.serverOss:
          final oss = config.ossConfig;
          if (oss == null || !oss.isValid) {
            await sendJson(request, {
              'error': 'Server OSS not configured',
            }, status: HttpStatus.internalServerError);
            return;
          }
          url = await _storeOss(
            oss,
            parsed.filename,
            parsed.bytes,
            parsed.mimeType,
          );

        case HubUploadMode.clientOss:
          return; // 不会走到这里
      }

      // ── 写缓存（限量，防内存膨胀） & 返回 ──────────────────────────────
      if (_uploadCache.length >= 500) {
        final oldest = _uploadCache.keys.firstOrNull;
        if (oldest != null) _uploadCache.remove(oldest);
      }
      _uploadCache[hash] = url;
      HubLog.info(
        'HubUpload',
        '✅ ${parsed.filename} (${parsed.bytes.length}B) $hash → $url',
      );
      await sendJson(request, {'url': url});
    } catch (e, st) {
      HubLog.error('HubUpload', 'upload failed: $e\n$st');
      await sendJson(request, {
        'error': 'Upload failed: $e',
      }, status: HttpStatus.internalServerError);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  GET /hub/files/<filename>
  // ═══════════════════════════════════════════════════════

  Future<void> _handleServeFile(HttpRequest request) async {
    final params = request.requestedUri.pathSegments;
    // /hub/files/<filename> → 最后一段
    final filename = params.isNotEmpty ? params.last : '';

    if (filename.isEmpty ||
        filename.contains('..') ||
        filename.contains('/') ||
        filename.contains('\\')) {
      await sendJson(request, {
        'error': 'Invalid filename',
      }, status: HttpStatus.badRequest);
      return;
    }

    final file = File(p.join(_uploadDir, filename));
    if (!await file.exists()) {
      await sendJson(request, {
        'error': 'File not found',
      }, status: HttpStatus.notFound);
      return;
    }

    final mime = _guessMimeType(filename);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Type', mime)
      ..headers.set('X-Content-Type-Options', 'nosniff')
      // SVG 可内联脚本，作为附件下载 + 禁止嗅探，防存储型 XSS
      ..headers.set(
        'Content-Disposition',
        mime == 'image/svg+xml' ? 'attachment' : 'inline',
      )
      ..headers.set('Cache-Control', 'public, max-age=31536000');

    await file.openRead().pipe(request.response);
  }

  // ═══════════════════════════════════════════════════════
  //  GET /hub/upload/config
  // ═══════════════════════════════════════════════════════

  Future<void> _handleGetUploadConfig(HttpRequest request) async {
    final config = uploadConfig;
    // 只返回客户端需要的信息，不泄露密钥
    await sendJson(request, {
      'mode': config.mode.name,
      'maxSizeBytes': config.maxSizeBytes,
    });
  }

  // ═══════════════════════════════════════════════════════
  //  存储实现
  // ═══════════════════════════════════════════════════════

  /// 本地存储
  Future<String> _storeLocal(String filename, Uint8List bytes) async {
    await _ensureUploadDir();
    final ext = _extFromName(filename);
    final hash = md5.convert(bytes).toString();
    final name = '$hash$ext';
    final file = File(p.join(_uploadDir, name));
    if (!await file.exists()) {
      await file.writeAsBytes(bytes);
    }
    return '/hub/files/$name';
  }

  Future<String> _storeOss(
    OssConfig oss,
    String filename,
    Uint8List bytes,
    String contentType,
  ) async {
    final key = oss.buildKey(filename, bytes);
    final date = HttpDate.format(DateTime.now().toUtc());
    final contentMd5 = base64Encode(md5.convert(bytes).bytes);

    final stringToSign =
        'PUT\n$contentMd5\n$contentType\n$date\n/${oss.bucket}/$key';
    final hmac = Hmac(sha1, utf8.encode(oss.accessKeySecret));
    final signature = base64Encode(
      hmac.convert(utf8.encode(stringToSign)).bytes,
    );

    final endpoint = oss.endpoint
        .replaceAll(RegExp(r'^https?://'), '')
        .replaceAll(RegExp(r'/$'), '');
    final putUrl = 'https://${oss.bucket}.$endpoint/$key';

    final response = await AppDio().request(
      putUrl,
      data: bytes,
      options: Options(
        method: 'PUT',
        headers: {
          'Content-Type': contentType,
          'Content-MD5': contentMd5,
          'Content-Length': bytes.length,
          'Date': date,
          'Authorization': 'OSS ${oss.accessKeyId}:$signature',
        },
        responseType: ResponseType.plain,
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw Exception(
        'OSS upload failed: ${response.statusCode} ${response.data}',
      );
    }

    return oss.accessUrl(key);
  }

  // ═══════════════════════════════════════════════════════
  //  Multipart 解析（二进制安全）
  // ═══════════════════════════════════════════════════════

  /// 从 HttpRequest 收集全部字节，超过上限立即抛错，防止内存耗尽。
  Future<Uint8List> _collectBytes(
    HttpRequest request, {
    int maxBytes = 5 * 1024 * 1024 + 4096,
  }) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > maxBytes) {
        throw _UploadTooLarge();
      }
    }
    return builder.takeBytes();
  }

  /// 解析 multipart body，提取第一个带 filename 的 part
  _MultipartFile? _parseMultipart(Uint8List body, String boundary) {
    final boundaryBytes = utf8.encode('--$boundary');
    final crlfCrlf = utf8.encode('\r\n\r\n');

    // 只向前搜索，避免对整块 body 做全量扫描
    var pos = 0;
    // 1) 找首个 boundary（body 开头）
    final firstBoundary = _indexOfSequence(body, boundaryBytes, pos);
    if (firstBoundary < 0) return null;
    pos = firstBoundary + boundaryBytes.length;

    // 2) 跳过 boundary 后的 \r\n
    if (pos + 2 <= body.length && body[pos] == 0x0D && body[pos + 1] == 0x0A) {
      pos += 2;
    }

    // 3) 逐 part 解析，直到遇到结束 boundary（--boundary--）
    while (pos < body.length) {
      // header 与 body 分界
      final headerEndIdx = _indexOfSequence(body, crlfCrlf, pos);
      if (headerEndIdx < 0) return null;

      final headerBytes = body.sublist(pos, headerEndIdx);
      final headerStr = utf8.decode(headerBytes, allowMalformed: true);

      // 该 part 是否带 filename
      final hasFile = headerStr.contains('filename=');

      // body 数据起点
      final dataStart = headerEndIdx + 4;

      // 找下一个 boundary
      final nextBoundary = _indexOfSequence(body, boundaryBytes, dataStart);
      if (nextBoundary < 0) return null;

      if (hasFile) {
        final fnMatch = RegExp(r'filename="([^"]*)"').firstMatch(headerStr);
        final filename = fnMatch?.group(1) ?? 'upload';

        final ctMatch = RegExp(
          r'Content-Type:\s*(.+)',
          caseSensitive: false,
        ).firstMatch(headerStr);
        final mimeType = ctMatch?.group(1)?.trim() ?? _guessMimeType(filename);

        // data：header 之后到 boundary 前（去掉结尾 \r\n）
        var dataEnd = nextBoundary;
        if (dataEnd >= 2 &&
            body[dataEnd - 2] == 0x0D &&
            body[dataEnd - 1] == 0x0A) {
          dataEnd -= 2;
        }

        if (dataStart >= dataEnd) return null;

        return _MultipartFile(
          filename: filename,
          mimeType: mimeType,
          bytes: Uint8List.sublistView(body, dataStart, dataEnd),
        );
      }

      // 无文件的 part（如普通字段），跳到下一个 boundary 后继续
      pos = nextBoundary + boundaryBytes.length;
      if (pos + 2 <= body.length &&
          body[pos] == 0x0D &&
          body[pos + 1] == 0x0A) {
        pos += 2;
      }
    }

    return null;
  }

  /// 在 data 中从 start 开始搜索 pattern 首次出现位置（Boyer-Moore-Horspool）。
  /// 找不到返回 -1。
  int _indexOfSequence(Uint8List data, List<int> pattern, int start) {
    final n = data.length;
    final m = pattern.length;
    if (m == 0 || m > n) return -1;

    // 坏字符跳表
    final badChar = <int, int>{};
    for (var i = 0; i < m - 1; i++) {
      badChar[pattern[i]] = m - 1 - i;
    }

    var i = start + m - 1;
    while (i < n) {
      var k = m - 1;
      while (k >= 0 && data[i - (m - 1 - k)] == pattern[k]) {
        k--;
      }
      if (k < 0) return i - m + 1;
      final shift = badChar[data[i]] ?? m;
      i += shift;
    }
    return -1;
  }

  // ═══════════════════════════════════════════════════════
  //  工具
  // ═══════════════════════════════════════════════════════

  String _extFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.bin';
    return name.substring(dot).toLowerCase();
  }

  String _guessMimeType(String name) {
    final ext = _extFromName(name);
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.gif' => 'image/gif',
      '.webp' => 'image/webp',
      '.svg' => 'image/svg+xml',
      '.bmp' => 'image/bmp',
      _ => 'application/octet-stream',
    };
  }

  static const _allowedImageMimes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/svg+xml',
  };

  bool _isAllowedImageMime(String mime) {
    final normalized = mime.toLowerCase().split(';').first.trim();
    return _allowedImageMimes.contains(normalized);
  }
}

class _MultipartFile {
  final String filename;
  final String mimeType;
  final Uint8List bytes;

  _MultipartFile({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });
}

class _UploadTooLarge implements Exception {}
