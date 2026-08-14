part of 'hub_chat_page.dart';

// ── 待发图片模型 ───────────────────────────────────────────────────────────────

class PendingImage {
  final Uint8List? bytes;
  final String? networkUrl;
  final String fileName;

  PendingImage.local({required Uint8List this.bytes, required this.fileName})
    : networkUrl = null;

  PendingImage.network({required String url, required this.fileName})
    : bytes = null,
      networkUrl = url;

  bool get isNetwork => networkUrl != null;
}

// ── 上传 Mixin ─────────────────────────────────────────────────────────────────

mixin _HubChatUploadMixin on ConsumerState<HubChatPage> {
  static const _kBase64Limit = 512 * 1024; // 512 KB 压缩目标
  // 服务端 WS 单条消息 64KB 上限；base64 膨胀约 4/3，加上 JSON 包装，
  // 二进制需压到 ~44KB 以下才能安全降级为 base64 发送
  static const _kBase64FallbackBinary = 44 * 1024;

  bool _uploading = false;

  // ── appdata 读取客户端 OSS 配置 ───────────────────────────────────────────
  HubUploadConfig? get _clientUploadCfg {
    final enabled =
        appdata.implicitData['hub_client_oss_enabled'] as bool? ?? false;
    if (!enabled) return null;
    final raw = appdata.implicitData['hub_client_upload_config'];
    if (raw is! Map) return null;
    return HubUploadConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  static String _guessMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  // ── 选图（桌面多选 / 移动多选）────────────────────────────────────────────
  Future<void> _pickAndSendImage() async {
    // _pendingImages / setState 由主 State 提供
    final state = this as _HubChatPageState;
    try {
      if (App.isDesktop) {
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result == null || result.files.isEmpty) return;
        for (final f in result.files) {
          final b = await f.readAsBytes();
          if (state.mounted) {
            state.setState(
              () => state._pendingImages.add(
                PendingImage.local(bytes: b, fileName: f.name),
              ),
            );
          }
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickMultiImage(imageQuality: 85);
        for (final f in picked) {
          final b = await f.readAsBytes();
          if (state.mounted) {
            state.setState(
              () => state._pendingImages.add(
                PendingImage.local(bytes: b, fileName: f.name),
              ),
            );
          }
        }
      }
    } catch (e) {
      App.rootContext.showMessage(
        message: '${t.failedToPickImage}: $e',
        level: LogLevel.warning,
      );
    }
  }

  // ── 拖入处理 ──────────────────────────────────────────────────────────────
  Future<void> _onDragDone(DropDoneDetails detail) async {
    final state = this as _HubChatPageState;
    for (final file in detail.files) {
      final path = file.path;
      final ext = path.split('.').last.toLowerCase();

      if ({'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext)) {
        // 本地图片文件
        final bytes = await File(path).readAsBytes();
        if (!state.mounted) return;
        state.setState(
          () => state._pendingImages.add(
            PendingImage.local(bytes: bytes, fileName: file.name),
          ),
        );
      } else {
        // 尝试解析为 URL 文本（.url / .webloc）
        final content = await File(path).readAsString().catchError((_) => '');
        final match = RegExp(r'https?://\S+').firstMatch(content);
        if (match != null) await _addNetworkImage(match.group(0)!);
      }
    }
    if (state.mounted) state.setState(() => state._isDragging = false);
  }

  // ── 添加网络图片到待发列表 ────────────────────────────────────────────────
  Future<void> _addNetworkImage(String url) async {
    final state = this as _HubChatPageState;
    final lower = url.toLowerCase().split('?').first;
    final isImage = [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'svg',
    ].any((e) => lower.endsWith('.$e'));
    if (!isImage) return;

    final fileName = url.split('/').last.split('?').first;
    if (!state.mounted) return;
    state.setState(
      () => state._pendingImages.add(
        PendingImage.network(
          url: url,
          fileName: fileName.isEmpty ? 'image.jpg' : fileName,
        ),
      ),
    );
  }

  // ── 构建 ImageSegment（统一入口）─────────────────────────────────────────
  Future<ImageSegment?> _buildImageSegment(PendingImage img) async {
    if (img.isNetwork) {
      return ImageSegment(url: img.networkUrl!, alt: img.fileName);
    }
    if (img.bytes == null) return null;
    return _buildImageSegmentFromBytes(img.bytes!, img.fileName);
  }

  // ── 压缩 + 上传策略 ───────────────────────────────────────────────────────
  Future<ImageSegment?> _buildImageSegmentFromBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    final client = (this as _HubChatPageState)._client;
    Uint8List toSend = bytes;
    String mimeType = _guessMime(fileName);
    final bool isGif = mimeType == 'image/gif';

    // 1. 压缩（GIF 跳过，避免变成静态 JPEG）
    if (!isGif && bytes.length > _kBase64Limit) {
      final c1 = await hubCompressImage(bytes, maxDim: 1280, quality: 82);
      mimeType = 'image/jpeg';
      toSend = c1.length <= _kBase64Limit
          ? c1
          : await hubCompressImage(c1, maxDim: 800, quality: 60);
    }

    // 2. 缓存命中
    final hash = md5.convert(toSend).toString();
    final cached = client.uploadCache[hash];
    if (cached != null) {
      Log.info('HubUploader', 'cache hit: $hash → $cached');
      return ImageSegment(url: cached, alt: fileName);
    }

    // 记录上传失败的具体原因，用于向用户展示真实错误而非笼统的「图片太大」
    String? lastUploadError;

    // 3. 服务端上传
    final hubState = ref.read(hubProvider);
    if (hubState.serverUploadEnabled) {
      final (url, err) = await _tryServerUpload(toSend, fileName, mimeType);
      if (url != null) {
        client.uploadCache[hash] = url;
        return ImageSegment(url: url, alt: fileName);
      }
      if (err != null && err.isNotEmpty) lastUploadError = err;
    }

    // 4. 客户端直传 OSS
    final (clientUrl, clientErr) = await _tryClientOssUpload(
      toSend,
      fileName,
      mimeType,
    );
    if (clientUrl != null) {
      client.uploadCache[hash] = clientUrl;
      return ImageSegment(url: clientUrl, alt: fileName);
    }
    if (clientErr != null && clientErr.isNotEmpty) lastUploadError = clientErr;

    // 5. 无上传通道：GIF 无法安全压缩，直接报错（区分具体失败原因）
    if (isGif && toSend.length > _kBase64FallbackBinary) {
      _showUploadError(lastUploadError);
      return null;
    }

    // 6. 压缩到 WS 消息上限内（44KB 二进制 → ~59KB base64 + JSON < 64KB）
    if (!isGif && toSend.length > _kBase64FallbackBinary) {
      toSend = await hubCompressImage(toSend, maxDim: 480, quality: 55);
      if (toSend.length > _kBase64FallbackBinary) {
        toSend = await hubCompressImage(toSend, maxDim: 320, quality: 40);
      }
    }

    // 7. 仍超限报错（区分「确实太大」与「上传通道失败」）
    if (toSend.length > _kBase64FallbackBinary) {
      final sizeMb = (toSend.length / 1024 / 1024).toStringAsFixed(1);
      if (lastUploadError != null) {
        _showUploadError(lastUploadError);
      } else {
        App.rootContext.showMessage(
          message:
              '${t.imageTooLargeToSend} (${sizeMb}MB). '
              '${t.pleaseConfigureServerUploadOrClientOss}',
          level: LogLevel.warning,
        );
      }
      return null;
    }

    // 8. 降级 base64
    return ImageSegment(
      url: 'data:$mimeType;base64,${base64Encode(toSend)}',
      alt: fileName,
    );
  }

  /// 将上传失败的具体原因映射为友好的错误提示
  void _showUploadError(String? error) {
    if (error == null || error.isEmpty) {
      App.rootContext.showMessage(
        message: t.pleaseConfigureServerUploadOrClientOss,
        level: LogLevel.warning,
      );
      return;
    }
    final s = error.toLowerCase();
    if (s.contains('too large')) {
      App.rootContext.showMessage(
        message: t.imageTooLargeToSend,
        level: LogLevel.warning,
      );
      return;
    }
    if (s.contains('not configured')) {
      App.rootContext.showMessage(
        message: t.pleaseConfigureServerUploadOrClientOss,
        level: LogLevel.warning,
      );
      return;
    }
    App.rootContext.showMessage(
      message: '${t.uploadFailed}: $error',
      level: LogLevel.error,
    );
  }

  // ── 服务端上传 ────────────────────────────────────────────────────────────
  Future<(String?, String?)> _tryServerUpload(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final client = (this as _HubChatPageState)._client;
    final savedAddress = client.savedAddress;
    if (savedAddress == null || savedAddress.isEmpty) return (null, null);

    // 把 ws:// → http://、wss:// → https://，无协议时补 http://；去掉尾部 /hub
    final httpBase = HubImageUploader.httpUrlOf(
      savedAddress,
    ).replaceAll(RegExp(r'/hub/?$'), '');

    try {
      final token = client.savedToken;
      final resp = await AppDio().request(
        '$httpBase/hub/upload/config',
        options: Options(
          method: 'GET',
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
      );
      if (resp.statusCode != 200 || resp.data is! Map) {
        return (null, 'server returned ${resp.statusCode}');
      }

      final config = HubUploadConfig.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );

      final url = await HubImageUploader(
        config: config,
        serverBaseUrl: httpBase,
        authToken: client.savedToken,
      ).upload(bytes, fileName);
      return (url, null);
    } catch (e) {
      Log.warning('HubUploader', '_tryServerUpload failed: $e');
      return (null, e.toString());
    }
  }

  // ── 客户端直传 OSS ────────────────────────────────────────────────────────
  Future<(String?, String?)> _tryClientOssUpload(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final cfg = _clientUploadCfg;
    if (cfg?.ossConfig == null || !cfg!.ossConfig!.isValid) return (null, null);

    try {
      final url = await HubImageUploader(
        config: cfg,
        serverBaseUrl: '',
      ).upload(bytes, fileName);
      return (url, null);
    } catch (e, st) {
      Log.error('HubUploader', '_tryClientOssUpload failed: $e\n$st');
      return (null, e.toString());
    }
  }
}
