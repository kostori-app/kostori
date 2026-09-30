// hub_web_admin_api.dart
//
// 管理后台的「集成类」接口：上传配置、入站 Webhook、Satori 机器人、
// API Key 轮换、消息检索。
//
// 刻意不含 LAN 远程控制：那是独立的 LanControlService（自己的 HttpServer 单例），
// PIN 也一直由设置页持久化与编辑。放进 Hub 的管理面板会造出第二个真相来源，
// 还会让「拿到 admin key」能直接改掉另一个暴露在 0.0.0.0 上的服务的唯一鉴权。
part of 'package:kostori/foundation/hub_services/services.dart';

extension HubWebAdminApi on HubWebAdminService {
  /// 上传体积下限/上限（1MB ~ 512MB）
  static const _minUploadBytes = 1 * 1024 * 1024;
  static const _maxUploadBytes = 512 * 1024 * 1024;

  void registerIntegrationRoutes() {
    _registerUploadConfigRoutes();
    _registerWebhookRoutes();
    _registerSatoriBotRoutes();
    _registerKeyRoutes();
    _registerSearchRoutes();
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  上传配置（此前只有 publicBaseUrl 可写，其余全部只能进 app 改）
  // ═══════════════════════════════════════════════════════════════════════

  void _registerUploadConfigRoutes() {
    addGet(
      '/api/admin/upload',
      (req, params) => sendJson(req, _uploadConfigJson(_hub.uploadConfig)),
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '读取上传配置',
        description: '返回上传模式、体积上限、存储路径与 OSS 配置（密钥不回显）',
        requiresAuth: true,
        response:
            'JSON: mode, maxSizeBytes, localStorePath, publicBaseUrl, oss',
      ),
    );

    addPost(
      '/api/admin/upload',
      (req, params) async {
        final body = await readJson(req);
        if (body == null) {
          return sendJson(req, {'error': 'Invalid JSON body'}, status: 400);
        }
        final error = _applyUploadConfig(body);
        if (error != null) {
          return sendJson(req, {'error': error}, status: 400);
        }
        return sendJson(req, {
          'saved': true,
          'config': _uploadConfigJson(_hub.uploadConfig),
        });
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '写入上传配置',
        description:
            '按字段部分更新。oss.accessKeySecret 传空或缺省表示保留原值。'
            'maxSizeBytes 同时是服务端的请求体上限（413 阈值）',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'mode',
            type: 'body',
            description: 'serverLocal/serverOss/clientOss',
          ),
          DocParam(
            name: 'maxSizeBytes',
            type: 'body',
            description: '1MB ~ 512MB',
          ),
          DocParam(
            name: 'localStorePath',
            type: 'body',
            description: 'serverLocal 存储根目录',
          ),
          DocParam(
            name: 'publicBaseUrl',
            type: 'body',
            description: '公网基础地址，空串表示清除',
          ),
          DocParam(
            name: 'oss',
            type: 'body',
            description: 'endpoint/bucket/accessKeyId/accessKeySecret/region/prefix/cdnDomain',
          ),
        ],
        response: 'JSON: saved, config',
      ),
    );
  }

  /// 对外只暴露「是否已配置」，不回显 OSS 密钥
  Map<String, dynamic> _uploadConfigJson(HubUploadConfig config) {
    final oss = config.ossConfig;
    return {
      'mode': config.mode.name,
      'maxSizeBytes': config.maxSizeBytes,
      'localStorePath': config.localStorePath,
      'publicBaseUrl': config.publicBaseUrl,
      'oss': oss == null
          ? null
          : {
              'endpoint': oss.endpoint,
              'bucket': oss.bucket,
              'accessKeyId': oss.accessKeyId,
              // 密钥不回显，只告知是否已设置；写入时留空即保留原值
              'secretConfigured': oss.accessKeySecret.isNotEmpty,
              if (oss.region != null) 'region': oss.region,
              if (oss.prefix != null) 'prefix': oss.prefix,
              if (oss.cdnDomain != null) 'cdnDomain': oss.cdnDomain,
            },
    };
  }

  /// 按字段部分更新上传配置并落盘，返回 null 表示成功，否则为错误原因。
  ///
  /// 这是 HTTP 边界，逐字段校验；内部调用方之间不重复校验。
  String? _applyUploadConfig(Map<String, dynamic> body) {
    final current = _hub.uploadConfig;
    var mode = current.mode;
    if (body['mode'] != null) {
      final parsed = HubUploadMode.values.asNameMap()[body['mode'].toString()];
      if (parsed == null) return 'Invalid mode: ${body['mode']}';
      mode = parsed;
    }

    var maxSizeBytes = current.maxSizeBytes;
    if (body['maxSizeBytes'] != null) {
      final value = (body['maxSizeBytes'] as num?)?.toInt();
      if (value == null || value < _minUploadBytes || value > _maxUploadBytes) {
        return 'maxSizeBytes must be $_minUploadBytes..$_maxUploadBytes';
      }
      maxSizeBytes = value;
    }

    OssConfig? oss = current.ossConfig;
    if (body['oss'] != null) {
      if (body['oss'] is! Map) return 'oss must be an object';
      final raw = Map<String, dynamic>.from(body['oss'] as Map);
      final base = current.ossConfig;
      final secret = raw['accessKeySecret']?.toString() ?? '';
      oss = OssConfig(
        endpoint: raw['endpoint']?.toString() ?? base?.endpoint ?? '',
        bucket: raw['bucket']?.toString() ?? base?.bucket ?? '',
        accessKeyId: raw['accessKeyId']?.toString() ?? base?.accessKeyId ?? '',
        // 留空表示不改动已保存的密钥
        accessKeySecret: secret.isEmpty
            ? (base?.accessKeySecret ?? '')
            : secret,
        region: raw['region']?.toString() ?? base?.region,
        prefix: raw['prefix']?.toString() ?? base?.prefix,
        cdnDomain: raw['cdnDomain']?.toString() ?? base?.cdnDomain,
      );
    }

    var localStorePath = current.localStorePath;
    var clearLocalStorePath = false;
    if (body.containsKey('localStorePath')) {
      final value = body['localStorePath']?.toString().trim() ?? '';
      localStorePath = value.isEmpty ? null : value;
      clearLocalStorePath = value.isEmpty;
    }

    var publicBaseUrl = current.publicBaseUrl;
    var clearPublicBaseUrl = false;
    if (body.containsKey('publicBaseUrl')) {
      final value = body['publicBaseUrl']?.toString().trim() ?? '';
      publicBaseUrl = value.isEmpty ? null : value;
      clearPublicBaseUrl = value.isEmpty;
    }

    final next = current.copyWith(
      mode: mode,
      ossConfig: oss,
      clearOssConfig: oss == null,
      maxSizeBytes: maxSizeBytes,
      localStorePath: localStorePath,
      clearLocalStorePath: clearLocalStorePath,
      publicBaseUrl: publicBaseUrl,
      clearPublicBaseUrl: clearPublicBaseUrl,
    );

    final modeError = next.validateForServer();
    if (modeError != null) return modeError;

    _hub.uploadConfig = next;
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  入站 Webhook
  //
  //  HubWebhookManager.addInbound 此前无任何调用方，导致
  //  POST /hub/webhook/:token 永远签不出合法 token，整条入站链路不可用。
  //  出站 / WS Bot 已迁移到 subscription，不在此重复提供。
  // ═══════════════════════════════════════════════════════════════════════

  void _registerWebhookRoutes() {
    addGet(
      '/api/admin/webhooks',
      (req, params) {
        final manager = HubWebhookManager.instance;
        final rooms = {for (final r in _hub.rooms) r.roomId: r.roomName};
        final list = manager
            .loadInbound()
            .map(
              (w) => {
                'id': w.id,
                'name': w.name,
                // 令牌必须回显：调用方要拿它去配置外部服务，这是入站 webhook 的用途
                'token': w.token,
                'roomId': w.roomId,
                'roomName': rooms[w.roomId] ?? '(房间不存在)',
                'createdAt': w.createdAt,
                'url': '/hub/webhook/${w.token}',
              },
            )
            .toList();
        return sendJson(req, {
          'count': list.length,
          'items': list,
          'rooms': _hub.rooms
              .map((r) => {'roomId': r.roomId, 'roomName': r.roomName})
              .toList(),
        });
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '入站 Webhook 列表',
        description: '返回全部入站 Webhook 及其令牌、目标房间',
        requiresAuth: true,
        response: 'JSON: count, items[], rooms[]',
      ),
    );

    addPost(
      '/api/admin/webhooks',
      (req, params) async {
        final body = await readJson(req);
        if (body == null) {
          return sendJson(req, {'error': 'Invalid JSON body'}, status: 400);
        }
        final roomId = body['roomId']?.toString() ?? '';
        if (_hub.findRoom(roomId) == null) {
          return sendJson(req, {
            'error': 'Room not found: $roomId',
          }, status: 400);
        }
        final name = body['name']?.toString().trim() ?? '';
        if (name.isEmpty || name.length > 64) {
          return sendJson(req, {
            'error': 'name must be 1-64 characters',
          }, status: 400);
        }
        final webhook = HubWebhookManager.instance.addInbound(
          name: name,
          roomId: roomId,
        );
        return sendJson(req, {'created': true, 'webhook': webhook.toJson()});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '创建入站 Webhook',
        description: '签发一个新令牌，外部服务即可用 POST /hub/webhook/<token> 发消息',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'name',
            type: 'body',
            description: '备注名',
            required: true,
          ),
          DocParam(
            name: 'roomId',
            type: 'body',
            description: '目标房间 ID',
            required: true,
          ),
        ],
        response: 'JSON: created, webhook',
      ),
    );

    addDelete(
      '/api/admin/webhooks/:id',
      (req, params) {
        final id = params['id'] ?? '';
        final existed = HubWebhookManager.instance.loadInbound().any(
          (w) => w.id == id,
        );
        HubWebhookManager.instance.deleteInbound(id);
        return sendJson(req, {'deleted': existed});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '删除入站 Webhook',
        description: '令牌立即失效',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'id',
            type: 'path',
            description: 'Webhook ID',
            required: true,
          ),
        ],
        response: 'JSON: deleted',
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Satori 机器人档案
  // ═══════════════════════════════════════════════════════════════════════

  void _registerSatoriBotRoutes() {
    addGet(
      '/api/admin/satori-bots',
      (req, params) {
        final store = SatoriBotProfileStore.instance;
        final items = store
            .load()
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'avatarUrl': p.avatarUrl,
                'biography': p.biography,
                'enabled': p.enabled,
                // 令牌是接入 Koishi 的凭据，必须可读
                'token': p.token,
                'online': _hub.rooms.any(
                  (r) => r.participants.containsKey(p.id),
                ),
              },
            )
            .toList();
        return sendJson(req, {'count': items.length, 'items': items});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: 'Satori 机器人列表',
        description: '返回接入档案及其专属令牌',
        requiresAuth: true,
        response: 'JSON: count, items[]',
      ),
    );

    addPost(
      '/api/admin/satori-bots',
      (req, params) async {
        final body = await readJson(req);
        if (body == null) {
          return sendJson(req, {'error': 'Invalid JSON body'}, status: 400);
        }
        final store = SatoriBotProfileStore.instance;
        final name = body['name']?.toString().trim() ?? '';
        if (name.isEmpty || name.length > 32) {
          return sendJson(req, {
            'error': 'name must be 1-32 characters',
          }, status: 400);
        }
        final profile = SatoriBotProfile(
          id: body['id']?.toString().trim().isNotEmpty == true
              ? body['id'].toString().trim()
              : store.generateId(),
          name: name,
          avatarUrl: body['avatarUrl']?.toString(),
          biography: body['biography']?.toString(),
          token: store.generateToken(),
        );
        store.save([...store.load(), profile]);
        return sendJson(req, {'created': true, 'bot': profile.toJson()});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '创建 Satori 机器人',
        description: '生成新 id 与 32 位专属令牌',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'name',
            type: 'body',
            description: '显示名',
            required: true,
          ),
          DocParam(name: 'id', type: 'body', description: '自定义 userId，缺省自动生成'),
          DocParam(name: 'avatarUrl', type: 'body', description: '头像 URL'),
          DocParam(name: 'biography', type: 'body', description: '简介'),
        ],
        response: 'JSON: created, bot',
      ),
    );

    addPut(
      '/api/admin/satori-bots/:id',
      (req, params) async {
        final store = SatoriBotProfileStore.instance;
        final id = params['id'] ?? '';
        final existing = store.findById(id);
        if (existing == null) {
          return sendJson(req, {'error': 'Bot not found'}, status: 404);
        }
        final body = await readJson(req);
        if (body == null) {
          return sendJson(req, {'error': 'Invalid JSON body'}, status: 400);
        }
        final name = body['name']?.toString().trim();
        if (name != null && (name.isEmpty || name.length > 32)) {
          return sendJson(req, {
            'error': 'name must be 1-32 characters',
          }, status: 400);
        }
        final updated = existing.copyWith(
          name: name,
          avatarUrl: body.containsKey('avatarUrl')
              ? body['avatarUrl']?.toString()
              : existing.avatarUrl,
          biography: body.containsKey('biography')
              ? body['biography']?.toString()
              : existing.biography,
          enabled: body['enabled'] is bool
              ? body['enabled'] as bool
              : existing.enabled,
        );
        store.save([
          for (final p in store.load())
            if (p.id == id) updated else p,
        ]);
        // 名字/头像变了要同步到在线成员，否则房间内仍显示旧名
        if (updated.name != existing.name ||
            updated.avatarUrl != existing.avatarUrl) {
          _hub.registerBotMember(
            userId: updated.id,
            displayName: updated.name,
            avatarUrl: updated.avatarUrl,
          );
        }
        return sendJson(req, {'saved': true, 'bot': updated.toJson()});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '更新 Satori 机器人',
        description: '支持改名、头像、简介与启停；令牌只能轮换',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'id',
            type: 'path',
            description: '机器人 ID',
            required: true,
          ),
          DocParam(name: 'name', type: 'body', description: '显示名'),
          DocParam(
            name: 'enabled',
            type: 'body',
            description: 'false 时该令牌拒绝连接',
          ),
        ],
        response: 'JSON: saved, bot',
      ),
    );

    addDelete(
      '/api/admin/satori-bots/:id',
      (req, params) {
        final store = SatoriBotProfileStore.instance;
        final id = params['id'] ?? '';
        final list = store.load();
        // 默认档案是 load() 的兜底返回值，删空会立刻被重新造出来
        final target = store.findById(id);
        if (target == null) {
          return sendJson(req, {'error': 'Bot not found'}, status: 404);
        }
        store.save(list.where((p) => p.id != id).toList());
        _hub.unregisterBotMember(id);
        return sendJson(req, {'deleted': true});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '删除 Satori 机器人',
        description: '令牌立即失效，并从成员列表注销',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'id',
            type: 'path',
            description: '机器人 ID',
            required: true,
          ),
        ],
        response: 'JSON: deleted',
      ),
    );

    addPost(
      '/api/admin/satori-bots/:id/rotate-token',
      (req, params) {
        final store = SatoriBotProfileStore.instance;
        final id = params['id'] ?? '';
        if (store.findById(id) == null) {
          return sendJson(req, {'error': 'Bot not found'}, status: 404);
        }
        final token = store.generateToken();
        store.save([
          for (final p in store.load())
            if (p.id == id)
              SatoriBotProfile(
                id: p.id,
                name: p.name,
                avatarUrl: p.avatarUrl,
                biography: p.biography,
                token: token,
                enabled: p.enabled,
              )
            else
              p,
        ]);
        return sendJson(req, {'rotated': true, 'token': token});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '轮换 Satori 机器人令牌',
        description: '旧令牌立即失效',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'id',
            type: 'path',
            description: '机器人 ID',
            required: true,
          ),
        ],
        response: 'JSON: rotated, token',
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  API Key 轮换
  // ═══════════════════════════════════════════════════════════════════════

  void _registerKeyRoutes() {
    addGet(
      '/api/admin/keys',
      (req, params) => sendJson(req, {
        'userKey': SecretVault.mask(ApiKeyManager().activeKey),
        'adminKey': SecretVault.mask(ApiKeyManager().adminActiveKey),
        'usingFixedKey': ApiKeyManager().isUsingFixed,
        'usingAdminFixedKey': ApiKeyManager().isUsingAdminFixed,
        'userKeyConfigured': ApiKeyManager().activeKey.isNotEmpty,
        'adminKeyConfigured': ApiKeyManager().adminActiveKey.isNotEmpty,
      }),
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '读取 Key 状态',
        description: '仅返回打码后的 Key 与是否使用固定 Key',
        requiresAuth: true,
        response: 'JSON: userKey, adminKey, usingFixedKey, ...',
      ),
    );

    addPost(
      '/api/admin/keys/rotate',
      (req, params) async {
        final body = await readJson(req);
        final admin = body?['admin'] == true;
        final manager = ApiKeyManager();
        if (manager.isUsingFixed || (admin && manager.isUsingAdminFixed)) {
          return sendJson(req, {
            'error': 'Fixed key in use; clear it before rotating',
          }, status: 409);
        }
        if (admin) {
          manager.regenerateAdminRandomKey();
        } else {
          manager.regenerateRandomKey();
        }
        return sendJson(req, {
          'rotated': true,
          'key': SecretVault.mask(
            admin ? manager.adminActiveKey : manager.activeKey,
          ),
        });
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '轮换 API Key',
        description:
            '随机 Key 重新生成，已连接的客户端会立即失效，需重新配对。'
            '使用固定 Key 时返回 409',
        requiresAuth: true,
        params: [
          DocParam(name: 'admin', type: 'body', description: 'true 轮换管理层 Key'),
        ],
        response: 'JSON: rotated, key',
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  消息检索
  //
  //  /hub/search 与 /hub/pinned 挂在 HubService 自己的端口（默认 9100），
  //  管理后台在另一个端口（默认 9200），页面无法跨端口调用。
  //  这里直接读 HubService 内存，不再要求页面去拼 9100。
  // ═══════════════════════════════════════════════════════════════════════

  void _registerSearchRoutes() {
    addGet(
      '/api/admin/search',
      (req, params) {
        final q = req.requestedUri.queryParameters['q'] ?? '';
        if (q.isEmpty) {
          return sendJson(req, {'error': 'q required'}, status: 400);
        }
        final roomId = req.requestedUri.queryParameters['room'];
        final needle = q.toLowerCase();
        final rooms = roomId != null && roomId.isNotEmpty
            ? [if (_hub.findRoom(roomId) != null) _hub.findRoom(roomId)!]
            : _hub.rooms;
        final results = <Map<String, dynamic>>[];
        for (final room in rooms) {
          for (final m in room.messageHistory) {
            if (!m.plainText.toLowerCase().contains(needle)) continue;
            results.add({
              ...m.toJson(),
              'roomId': room.roomId,
              'roomName': room.roomName,
            });
            if (results.length >= 200) break;
          }
          if (results.length >= 200) break;
        }
        return sendJson(req, {
          'keyword': q,
          'roomId': roomId,
          'truncated': results.length >= 200,
          'count': results.length,
          'results': results,
        });
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '检索房间消息',
        description: '按关键词搜索，最多吃 200 条。?room= 限定房间',
        requiresAuth: true,
        params: [
          DocParam(
            name: 'q',
            type: 'query',
            description: '关键词',
            required: true,
          ),
          DocParam(name: 'room', type: 'query', description: '房间 ID，缺省搜索全部'),
        ],
        response: 'JSON: keyword, count, truncated, results[]',
      ),
    );

    addGet(
      '/api/admin/pinned',
      (req, params) {
        final roomId = req.requestedUri.queryParameters['room'];
        final rooms = roomId != null && roomId.isNotEmpty
            ? [if (_hub.findRoom(roomId) != null) _hub.findRoom(roomId)!]
            : _hub.rooms;
        final pinned = <Map<String, dynamic>>[];
        for (final room in rooms) {
          for (final m in room.pinnedMessages) {
            pinned.add({
              ...m.toJson(),
              'roomId': room.roomId,
              'roomName': room.roomName,
            });
          }
        }
        return sendJson(req, {'count': pinned.length, 'messages': pinned});
      },
      middlewares: [adminAuthMiddleware],
      doc: const RouteDoc(
        summary: '置顶消息',
        description: '按房间列出置顶消息',
        requiresAuth: true,
        params: [
          DocParam(name: 'room', type: 'query', description: '房间 ID，缺省返回全部'),
        ],
        response: 'JSON: count, messages[]',
      ),
    );
  }
}
