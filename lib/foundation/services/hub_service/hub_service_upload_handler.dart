// hub_upload_handler.dart
part of 'package:kostori/foundation/services/services.dart';

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
    addPost('/hub/upload', _handleUpload);
    addGet('/hub/files/<filename>', _handleServeFile);
    addGet('/hub/upload/config', _handleGetUploadConfig);
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

      // 读取全部 body
      final bodyBytes = await _collectBytes(request);

      // 大小预检（加点余量给 headers）
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

      // ── 写缓存 & 返回 ─────────────────────────────────────────────────
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
    final stat = await file.stat();

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set('Content-Type', mime)
      ..headers.set('Content-Length', stat.size)
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

  /// 从 HttpRequest 收集全部字节
  Future<Uint8List> _collectBytes(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// 解析 multipart body，提取第一个带 filename 的 part
  _MultipartFile? _parseMultipart(Uint8List body, String boundary) {
    final boundaryBytes = utf8.encode('--$boundary');
    final crlfCrlf = utf8.encode('\r\n\r\n');

    // 找到所有 boundary 的位置
    final positions = <int>[];
    for (var i = 0; i <= body.length - boundaryBytes.length; i++) {
      if (_bytesMatch(body, i, boundaryBytes)) {
        positions.add(i);
      }
    }

    if (positions.length < 2) return null;

    // 遍历每个 part
    for (var p = 0; p < positions.length - 1; p++) {
      final partStart = positions[p] + boundaryBytes.length;
      final partEnd = positions[p + 1];

      // 跳过 boundary 后的 \r\n
      var headerStart = partStart;
      if (headerStart + 2 <= body.length &&
          body[headerStart] == 0x0D &&
          body[headerStart + 1] == 0x0A) {
        headerStart += 2;
      }

      // 找 header 和 body 的分界
      final headerEndIdx = _indexOfBytes(body, crlfCrlf, headerStart);
      if (headerEndIdx < 0 || headerEndIdx >= partEnd) continue;

      final headerBytes = body.sublist(headerStart, headerEndIdx);
      final headerStr = utf8.decode(headerBytes, allowMalformed: true);

      // 必须包含 filename
      if (!headerStr.contains('filename=')) continue;

      // 提取 filename
      final fnMatch = RegExp(r'filename="([^"]*)"').firstMatch(headerStr);
      final filename = fnMatch?.group(1) ?? 'upload';

      // 提取 Content-Type
      final ctMatch = RegExp(
        r'Content-Type:\s*(.+)',
        caseSensitive: false,
      ).firstMatch(headerStr);
      final mimeType = ctMatch?.group(1)?.trim() ?? _guessMimeType(filename);

      // body 数据：headerEnd + 4 (\r\n\r\n) 到 partEnd 前的 \r\n
      final dataStart = headerEndIdx + 4;
      var dataEnd = partEnd;
      // 去掉结尾的 \r\n（boundary 前面通常有 \r\n）
      if (dataEnd >= 2 &&
          body[dataEnd - 2] == 0x0D &&
          body[dataEnd - 1] == 0x0A) {
        dataEnd -= 2;
      }

      if (dataStart >= dataEnd) continue;

      return _MultipartFile(
        filename: filename,
        mimeType: mimeType,
        bytes: Uint8List.sublistView(body, dataStart, dataEnd),
      );
    }

    return null;
  }

  /// 检查 body[offset..] 是否以 pattern 开头
  bool _bytesMatch(Uint8List body, int offset, List<int> pattern) {
    if (offset + pattern.length > body.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (body[offset + i] != pattern[i]) return false;
    }
    return true;
  }

  /// 在 body 中从 start 开始搜索 pattern
  int _indexOfBytes(Uint8List data, List<int> pattern, [int start = 0]) {
    for (var i = start; i <= data.length - pattern.length; i++) {
      if (_bytesMatch(data, i, pattern)) return i;
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
