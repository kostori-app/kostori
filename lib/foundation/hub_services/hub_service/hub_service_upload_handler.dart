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

  // ── 本地存储目录（固定写死，不随配置更改）──

  String get _uploadDir => p.join(App.dataPath, 'hub_uploads');

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
    addGet('/hub/files/:filename', _handleServeFile);
    addGet(
      '/hub/upload/config',
      _handleGetUploadConfig,
      middlewares: _hubAuthMiddleware,
    );
  }

  /// Satori 适配层使用：解析 multipart 请求体中的首个文件
  Future<_MultipartFile?> parseMultipartFile(Uint8List body, String boundary) =>
      _parseMultipart(Stream.value(body), boundary);

  /// Satori 适配层使用：收集请求体原始字节
  Future<Uint8List> collectRequestBodyBytes(shelf.Request request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request.read()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Satori 适配层使用：按当前上传配置存储文件并返回可访问 URL
  Future<String> storeUploadedFile(_MultipartFile parsed) async {
    switch (uploadConfig.mode) {
      case HubUploadMode.serverLocal:
        return _storeLocal(parsed.filename, parsed.bytes);
      case HubUploadMode.serverOss:
        final oss = uploadConfig.ossConfig;
        if (oss == null || !oss.isValid) {
          throw StateError('Server OSS not configured');
        }
        return _storeOss(oss, parsed.filename, parsed.bytes, parsed.mimeType);
      case HubUploadMode.clientOss:
        throw StateError('Server does not accept uploads in clientOss mode');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  POST /hub/upload
  // ═══════════════════════════════════════════════════════

  Future<shelf.Response> _handleUpload(
    shelf.Request request,
    Map<String, String> params,
  ) async {
    try {
      final config = uploadConfig;

      // 客户端直传模式，服务端不接受上传
      if (config.mode == HubUploadMode.clientOss) {
        return sendJson(request, {
          'error': 'Server does not accept uploads in clientOss mode',
        }, status: HttpStatus.badRequest);
      }

      // 检查 Content-Type
      final rawContentType = request.headers['content-type'];
      final contentType = rawContentType == null
          ? null
          : ContentType.parse(rawContentType);
      if (contentType == null ||
          contentType.primaryType != 'multipart' ||
          contentType.subType != 'form-data') {
        return sendJson(request, {
          'error': 'Expected multipart/form-data',
        }, status: HttpStatus.badRequest);
      }

      final boundary = contentType.parameters['boundary'];
      if (boundary == null || boundary.isEmpty) {
        return sendJson(request, {
          'error': 'Missing boundary',
        }, status: HttpStatus.badRequest);
      }

      // 流式解析 multipart，超过上限立即中止，避免超大请求占满内存
      _MultipartFile? parsed;
      try {
        parsed = await _parseMultipart(
          request.read(),
          boundary,
          maxBytes: config.maxSizeBytes,
        );
      } on _UploadTooLarge {
        final maxMb = (config.maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
        return sendJson(request, {
          'error': 'File too large (max ${maxMb}MB)',
        }, status: HttpStatus.requestEntityTooLarge);
      }
      if (parsed == null || parsed.bytes.isEmpty) {
        return sendJson(request, {
          'error': 'No file found in request',
        }, status: HttpStatus.badRequest);
      }

      // 仅接受图片类型（防上传非图片文件被存储/分发）
      final allowedMime = _isAllowedImageMime(parsed.mimeType);
      if (!allowedMime) {
        return sendJson(request, {
          'error': 'Only image uploads are allowed',
        }, status: HttpStatus.unsupportedMediaType);
      }

      // ── 缓存命中直接返回 ──────────────────────────────────────────────
      final hash = md5.convert(parsed.bytes).toString();
      final cached = _uploadCache[hash];
      if (cached != null) {
        HubLog.info('HubUpload', 'cache hit: $hash → $cached');
        return sendJson(request, {'url': cached});
      }

      // ── 存储 ──────────────────────────────────────────────────────────
      final String url;
      switch (config.mode) {
        case HubUploadMode.serverLocal:
          url = await _storeLocal(parsed.filename, parsed.bytes);

        case HubUploadMode.serverOss:
          final oss = config.ossConfig;
          if (oss == null || !oss.isValid) {
            return sendJson(request, {
              'error': 'Server OSS not configured',
            }, status: HttpStatus.internalServerError);
          }
          url = await _storeOss(
            oss,
            parsed.filename,
            parsed.bytes,
            parsed.mimeType,
          );

        case HubUploadMode.clientOss:
          return sendJson(request, {
            'error': 'Server does not accept uploads in clientOss mode',
          }, status: HttpStatus.badRequest);
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
      return sendJson(request, {'url': url});
    } catch (e, st) {
      HubLog.error('HubUpload', 'upload failed: $e\n$st');
      return sendJson(request, {
        'error': 'Upload failed: $e',
      }, status: HttpStatus.internalServerError);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  GET /hub/files/<filename>
  // ═══════════════════════════════════════════════════════

  Future<shelf.Response> _handleServeFile(
    shelf.Request request,
    Map<String, String> params,
  ) async {
    final filename = params['filename'] ?? '';

    if (filename.isEmpty ||
        filename.contains('..') ||
        filename.contains('/') ||
        filename.contains('\\')) {
      return sendJson(request, {
        'error': 'Invalid filename',
      }, status: HttpStatus.badRequest);
    }

    final file = File(p.join(_uploadDir, filename));
    if (!await file.exists()) {
      return sendJson(request, {
        'error': 'File not found',
      }, status: HttpStatus.notFound);
    }

    final mime = _guessMimeType(filename);

    return shelf.Response(
      HttpStatus.ok,
      body: file.openRead(),
      headers: {
        'content-type': mime,
        'x-content-type-options': 'nosniff',
        // SVG 可内联脚本，作为附件下载 + 禁止嗅探，防存储型 XSS
        'content-disposition': mime == 'image/svg+xml'
            ? 'attachment'
            : 'inline',
        'cache-control': 'public, max-age=31536000',
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  GET /hub/upload/config
  // ═══════════════════════════════════════════════════════

  Future<shelf.Response> _handleGetUploadConfig(
    shelf.Request request,
    Map<String, String> params,
  ) async {
    final config = uploadConfig;
    // 只返回客户端需要的信息，不泄露密钥
    return sendJson(request, {
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
    // 配置了公网基础地址 → 返回绝对 URL（外网可访问）；
    // 否则返回相对路径，由客户端按连接地址补全
    final base = uploadConfig.publicBaseUrl;
    if (base != null && base.isNotEmpty) {
      final trimmed = base.endsWith('/')
          ? base.substring(0, base.length - 1)
          : base;
      return '$trimmed/hub/files/$name';
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
  //  Multipart 解析（package:mime）
  // ═══════════════════════════════════════════════════════

  /// 解析 multipart 流，提取第一个带 filename 的 part。
  /// 文件字节超过 [maxBytes] 立即抛 [_UploadTooLarge]，防止内存耗尽。
  Future<_MultipartFile?> _parseMultipart(
    Stream<List<int>> stream,
    String boundary, {
    int maxBytes = 5 * 1024 * 1024,
  }) async {
    final transformer = MimeMultipartTransformer(boundary);
    await for (final part in stream.transform(transformer)) {
      final disposition = part.headers['content-disposition'] ?? '';
      final fnMatch = RegExp(r'filename="([^"]*)"').firstMatch(disposition);
      if (fnMatch == null) {
        await part.drain<void>();
        continue;
      }
      final filename = fnMatch.group(1)?.isNotEmpty == true
          ? fnMatch.group(1)!
          : 'upload';
      final mimeType = part.headers['content-type'] ?? _guessMimeType(filename);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in part) {
        builder.add(chunk);
        if (builder.length > maxBytes) throw _UploadTooLarge();
      }
      return _MultipartFile(
        filename: filename,
        mimeType: mimeType,
        bytes: builder.takeBytes(),
      );
    }
    return null;
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
