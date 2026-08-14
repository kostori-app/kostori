// satori_adapter.dart
// Satori 协议适配层：让第三方 Satori 客户端（如 Koishi）通过标准协议
// 连接 Kostori Hub，读取房间/消息/成员并发送消息。
// 参考 https://satori.chat/zh-CN/protocol/
part of 'package:kostori/foundation/hub_services/services.dart';

/// Satori WebSocket Gateway opcode
class SatoriOpcode {
  static const int event = 0;
  static const int ping = 1;
  static const int pong = 2;
  static const int identify = 3;
  static const int ready = 4;
  static const int meta = 5;
}

/// Satori 适配层（单例）。在 HubService 启动时 attach，负责：
/// - 注册 REST 方法路由（POST /v1/:method）
/// - 注册 Gateway WebSocket（/v1/events）
/// - 桥接 Hub 房间消息 / 系统事件 → Satori Event，维护全局 sn 支持断线续传
class SatoriServer {
  SatoriServer._();

  static final SatoriServer instance = SatoriServer._();

  static const String platform = 'kostori';

  /// Satori 机器人身份。注意不能用 'server'（客户端把 'server' 当系统消息渲染，
  /// 会导致 bot 的聊天消息被吞掉不显示）。
  static const String selfId = 'satori-bot';

  HubService? _hub;

  int _sn = 0;
  final List<Map<String, dynamic>> _buffer = [];
  static const int _maxBuffer = 5000;

  /// 已鉴权的 Satori 网关连接 → 该连接绑定的 bot 档案
  final Map<WebSocket, SatoriBotProfile> _clients = {};

  /// 默认身份（未用专属令牌连接时的回退，向后兼容旧版）
  SatoriBotProfile get _defaultProfile {
    final store = SatoriBotProfileStore.instance;
    return store.findById(SatoriServer.selfId) ??
        store.findByToken('') ??
        SatoriBotProfile.defaultBot();
  }

  HubService? get hub => _hub;

  int get sn => _sn;

  bool get enabled => _hub != null;

  void attach(HubService hub) {
    if (_hub != null) return;
    _hub = hub;
    hub.onMessageBroadcast = _onMessageBroadcast;
    hub.onDmBroadcast = _onDmBroadcast;
    hub.onSystemBroadcast = _onSystemBroadcast;
  }

  void detach() {
    final hub = _hub;
    if (hub == null) return;
    hub.onMessageBroadcast = null;
    hub.onDmBroadcast = null;
    hub.onSystemBroadcast = null;
    for (final socket in _clients.keys.toList()) {
      try {
        socket.close();
      } catch (_) {}
    }
    _clients.clear();
    _hub = null;
    _sn = 0;
    _buffer.clear();
  }

  // ── 路由注册 ────────────────────────────────────────────

  void registerRoutes(HubService hub) {
    hub.addPost(
      '/v1/:name',
      _handleRest,
      middlewares: hub.hubNoAuth ? [] : [_satoriAuth],
      doc: RouteDoc(
        summary: 'Satori REST 方法',
        description: 'Satori 协议 v1 方法调用，见 https://satori.chat/zh-CN/protocol/',
        requiresAuth: true,
      ),
    );
    hub.addGet('/v1/:name', (req) async {
      req.response
        ..statusCode = HttpStatus.methodNotAllowed
        ..headers.set('Allow', 'POST')
        ..headers.contentType = ContentType.json
        ..write('{"error":"Please use POST method to send requests."}');
      await req.response.close();
    });
    hub.addWs('/v1/events', _handleGateway);
  }

  /// Satori REST 鉴权：接受专属 bot 令牌或用户/管理层 Key。
  Future<bool> _satoriAuth(HttpRequest request) async {
    final header = request.headers.value('Authorization');
    final bearerToken = header != null && header.startsWith('Bearer ')
        ? header.substring(7)
        : null;
    final queryToken = request.uri.queryParameters['token'];
    final token = bearerToken ?? queryToken;
    final valid =
        token != null &&
        (SatoriBotProfileStore.instance.findByToken(token) != null ||
            ApiKeyManager().validate(token) ||
            ApiKeyManager().validateAdmin(token));
    if (!valid) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'error': 'Unauthorized',
            'message': 'Invalid or missing token',
          }),
        );
      await request.response.close();
      return false;
    }
    return true;
  }

  // ── Gateway WebSocket ───────────────────────────────────

  Future<void> _handleGateway(WebSocket socket, HttpRequest request) async {
    bool authorized = false;
    SatoriBotProfile? profile;
    await for (final raw in socket) {
      try {
        final payload = jsonDecode(raw as String) as Map<String, dynamic>;
        final op = payload['op'] as int;
        final body = payload['body'] as Map<String, dynamic>? ?? {};
        if (op == SatoriOpcode.identify) {
          final hub = _hub;
          final token = body['token'] as String?;
          // 优先：专属令牌绑定档案
          final byToken = token != null
              ? SatoriBotProfileStore.instance.findByToken(token)
              : null;
          final valid =
              hub?.hubNoAuth == true ||
              (token != null &&
                  (ApiKeyManager().validate(token) ||
                      ApiKeyManager().validateAdmin(token)));
          if (byToken == null && !valid) {
            await socket.close(
              WebSocketStatus.policyViolation,
              'invalid token',
            );
            return;
          }
          authorized = true;
          // 绑定档案：专属令牌 → 该档案；通用 key → 默认档案
          profile = byToken ?? _defaultProfile;
          // 把机器人注册为 Hub 成员，使其出现在房间 @ 列表 / 成员列表
          hub?.registerBotMember(
            userId: profile.id,
            displayName: profile.name,
            avatarUrl: _resolveAvatar(profile.avatarUrl),
          );
          _clients[socket] = profile;
          socket.add(
            jsonEncode({'op': SatoriOpcode.ready, 'body': _meta(profile)}),
          );
          final sn = body['sn'] as int?;
          if (sn != null) {
            for (final ev in _buffer) {
              if ((ev['sn'] as int) > sn) {
                final replay = {...ev};
                replay['selfId'] = profile.id;
                replay['login'] = _login(profile);
                socket.add(
                  jsonEncode({'op': SatoriOpcode.event, 'body': replay}),
                );
              }
            }
          }
        } else if (op == SatoriOpcode.ping) {
          socket.add(jsonEncode({'op': SatoriOpcode.pong, 'body': {}}));
        }
      } catch (_) {}
    }
    if (authorized) {
      _clients.remove(socket);
      // 该档案无其他连接时注销机器人成员
      if (profile != null && !_clients.containsValue(profile)) {
        _hub?.unregisterBotMember(profile.id);
      }
    }
  }

  Map<String, dynamic> _meta(SatoriBotProfile profile) => {
    'logins': [_login(profile)],
    'proxyUrls': [],
  };

  /// 把机器人头像解析为公网可访问地址（优先 publicBaseUrl，避免 localhost）
  String? _resolveAvatar(String? url) {
    if (url == null || url.isEmpty) return null;
    return _hub?.uploadConfig.resolveFileUrl(url) ?? url;
  }

  Map<String, dynamic> _login(SatoriBotProfile profile) => {
    'sn': _sn,
    'adapter': 'kostori',
    'platform': platform,
    'user': {
      'id': profile.id,
      'name': profile.name,
      if (profile.avatarUrl?.isNotEmpty == true)
        'avatar': _resolveAvatar(profile.avatarUrl),
      'isBot': true,
    },
    'status': 1,
    'features': [
      'channel.get',
      'channel.list',
      'guild.get',
      'guild.list',
      'guild.member.list',
      'guild.member.get',
      'guild.member.kick',
      'guild.member.mute',
      'message.create',
      'message.get',
      'message.list',
      'message.delete',
      'reaction.create',
      'reaction.delete',
      'reaction.list',
      'user.get',
      'login.get',
      'friend.list',
      'upload.create',
    ],
  };

  /// 广播事件给所有已鉴权连接。每个连接按自己的 bot 档案填充 selfId/login。
  void _dispatch(Map<String, dynamic> baseEvent) {
    _sn++;
    final sn = _sn;
    _buffer.add({...baseEvent, 'sn': sn});
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);
    for (final entry in _clients.entries.toList()) {
      try {
        final socket = entry.key;
        final profile = entry.value;
        final ev = {...baseEvent, 'sn': sn};
        ev['selfId'] = profile.id;
        ev['login'] = _login(profile);
        socket.add(jsonEncode({'op': SatoriOpcode.event, 'body': ev}));
      } catch (_) {
        _clients.remove(entry.key);
      }
    }
  }

  // ── Hub 事件 → Satori Event 桥接 ────────────────────────

  void _onMessageBroadcast(HubRoom room, HubMessage msg) {
    if (_clients.isEmpty) return;
    final event = _buildMessageEvent(room, msg);
    if (event == null) return;
    _dispatch(event);
  }

  /// 私聊 → 仅推送给目标 bot 对应的连接。
  void _onDmBroadcast(HubRoom room, HubMessage msg, String targetUserId) {
    if (_clients.isEmpty) return;
    final event = _buildMessageEvent(room, msg);
    if (event == null) return;
    _sn++;
    final sn = _sn;
    _buffer.add({...event, 'sn': sn});
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);
    for (final entry in _clients.entries.toList()) {
      if (entry.value.id != targetUserId) continue;
      try {
        final socket = entry.key;
        final profile = entry.value;
        final ev = {...event, 'sn': sn};
        ev['selfId'] = profile.id;
        ev['login'] = _login(profile);
        socket.add(jsonEncode({'op': SatoriOpcode.event, 'body': ev}));
      } catch (_) {
        _clients.remove(entry.key);
      }
    }
  }

  /// 消息广播 → Satori 事件。
  /// 注意：撤回/反应既有消息广播又有系统事件（messageRecalled / userReacted），
  /// 且只有系统事件携带 added 状态，故这里只处理 chat 与 pin，避免重复触发。
  Map<String, dynamic>? _buildMessageEvent(HubRoom room, HubMessage msg) {
    switch (msg.messageType) {
      case HubMessageType.chat:
        // 顶层 user 必须带 id（Koishi 由 event.user.id 得到 session.userId）
        return _event(
          'message',
          room: room,
          message: _message(room, msg),
          user: _user(msg.sender),
          member: _member(msg.sender),
        );
      case HubMessageType.pin:
        final id = msg.segments
            .whereType<TextSegment>()
            .map((s) => s.text)
            .join('');
        return _event(
          'message-pinned',
          room: room,
          message: {'id': id, 'channel': _channel(room), 'guild': _guild(room)},
        );
      case HubMessageType.recall:
      case HubMessageType.reaction:
        return null; // 由 onSystemBroadcast 统一处理
    }
  }

  void _onSystemBroadcast(
    HubSystemEvent event,
    Map<String, dynamic> data,
    String? roomId,
  ) {
    if (_clients.isEmpty) return;
    final hub = _hub;
    if (hub == null) return;
    final room = roomId != null ? hub.findRoom(roomId) : null;
    switch (event) {
      case HubSystemEvent.clientJoinedRoom:
        final client = _clientFromData(data);
        if (room == null || client == null) return;
        _dispatch(
          _event(
            'guild-member-added',
            room: room,
            user: client,
            member: _memberFromUser(client),
          ),
        );
      case HubSystemEvent.clientLeftRoom:
        final client = _clientFromData(data);
        if (room == null || client == null) return;
        _dispatch(_event('guild-member-deleted', room: room, user: client));
      case HubSystemEvent.clientJoined:
        final client = _clientFromData(data);
        if (client == null) return;
        final lobby = hub.findRoom(hub.lobbyRoomId);
        if (lobby != null) {
          _dispatch(
            _event(
              'guild-member-added',
              room: lobby,
              user: client,
              member: _memberFromUser(client),
            ),
          );
        }
      case HubSystemEvent.clientLeft:
        final id = data['clientId'] as String?;
        if (id == null) return;
        _dispatch(_event('user-updated', user: {'id': id}));
      case HubSystemEvent.roomCreated:
        final roomData = data['room'];
        if (roomData is Map<String, dynamic>) {
          final r = HubRoomDto.fromJson(roomData);
          _dispatch(_event('guild-added', guild: _guildDto(r)));
        }
      case HubSystemEvent.roomDeleted:
        final id = data['roomId'] as String?;
        if (id == null) return;
        _dispatch(_event('guild-deleted', guild: {'id': id}));
      case HubSystemEvent.roomUpdated:
        final roomData = data['room'];
        if (roomData is Map<String, dynamic>) {
          final r = HubRoomDto.fromJson(roomData);
          _dispatch(_event('guild-updated', guild: _guildDto(r)));
        }
      case HubSystemEvent.profileUpdated:
        final client = _clientFromData(data);
        if (client != null) {
          _dispatch(_event('user-updated', user: client));
        }
      case HubSystemEvent.clientKickedFromRoom:
        final client = _clientFromData(data);
        if (room != null && client != null) {
          _dispatch(
            _event(
              'guild-member-deleted',
              room: room,
              user: client,
              operator: {'id': data['by'] as String? ?? 'server'},
            ),
          );
        }
      case HubSystemEvent.messageRecalled:
        final id = data['messageId'] as String?;
        if (room != null && id != null) {
          _dispatch(
            _event(
              'message-deleted',
              room: room,
              message: {
                'id': id,
                'channel': _channel(room),
                'guild': _guild(room),
              },
            ),
          );
        }
      case HubSystemEvent.userReacted:
        if (room == null) return;
        final messageId = data['messageId'] as String?;
        final emojiId = data['emojiId'] as String?;
        final fromId = data['fromId'] as String?;
        final added = data['added'] as bool? ?? true;
        if (messageId == null || emojiId == null || fromId == null) return;
        _dispatch(
          _event(
            added ? 'reaction-added' : 'reaction-deleted',
            room: room,
            message: {
              'id': messageId,
              'channel': _channel(room),
              'guild': _guild(room),
            },
            emoji: {'id': emojiId, 'name': emojiId},
            user: {'id': fromId, 'name': fromId},
          ),
        );
      default:
        break;
    }
  }

  Map<String, dynamic> _event(
    String type, {
    HubRoom? room,
    Map<String, dynamic>? message,
    Map<String, dynamic>? guild,
    Map<String, dynamic>? user,
    Map<String, dynamic>? member,
    Map<String, dynamic>? operator,
    Map<String, dynamic>? emoji,
  }) => {
    'type': type,
    'platform': platform,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    if (room != null) 'channel': _channel(room),
    if (room != null) 'guild': _guild(room),
    if (guild != null) 'guild': guild,
    if (message != null) 'message': message,
    if (user != null) 'user': user,
    if (member != null) 'member': member,
    if (operator != null) 'operator': operator,
    if (emoji != null) 'emoji': emoji,
    'referrer': null,
  };

  // ── REST 方法分发 ───────────────────────────────────────

  Future<void> _handleRest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    final name = segments.isNotEmpty ? segments.last : '';
    final hub = _hub;
    if (hub == null) {
      await _sendJson(request, {'error': 'satori not enabled'}, status: 503);
      return;
    }
    // upload.create 的请求体是 multipart，不能先按 JSON 读取
    final body = name == 'upload.create'
        ? <String, dynamic>{}
        : await _readJsonBody(request) ?? <String, dynamic>{};
    try {
      final result = await _invoke(name, body, request);
      await _sendJsonValue(request, result);
    } catch (e) {
      await _sendJson(request, {'error': e.toString()}, status: 400);
    }
  }

  /// 从 REST 请求头解析调用方 bot 档案（Koishi 会带 Satori-User-ID）。
  SatoriBotProfile _profileFromRequest(HttpRequest request) {
    final userId = request.headers.value('Satori-User-ID');
    if (userId != null && userId.isNotEmpty) {
      final byId = SatoriBotProfileStore.instance.findById(userId);
      if (byId != null) return byId;
    }
    return _defaultProfile;
  }

  Future<Object?> _invoke(
    String name,
    Map<String, dynamic> body,
    HttpRequest request,
  ) async {
    final hub = _hub;
    if (hub == null) throw StateError('satori not enabled');
    final profile = _profileFromRequest(request);
    switch (name) {
      case 'login.get':
        return _login(profile);

      case 'channel.get':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        if (room == null) throw StateError('channel not found');
        return _channel(room);

      case 'channel.list':
        return hub.rooms.map(_channel).toList();

      case 'guild.get':
        final room = hub.findRoom(body['guild_id'] as String? ?? '');
        if (room == null) throw StateError('guild not found');
        return _guild(room);

      case 'guild.list':
        return hub.rooms.map(_guild).toList();

      case 'guild.member.list':
        final room = hub.findRoom(body['guild_id'] as String? ?? '');
        if (room == null) throw StateError('guild not found');
        return room.participants.values.map((c) => _member(c.toDto())).toList();

      case 'guild.member.get':
        final room = hub.findRoom(body['guild_id'] as String? ?? '');
        final userId = body['user_id'] as String?;
        if (room == null) throw StateError('guild not found');
        final client = room.participants[userId];
        if (client == null) throw StateError('member not found');
        return _member(client.toDto());

      case 'guild.member.kick':
        final roomId = body['guild_id'] as String? ?? '';
        final userId = body['user_id'] as String?;
        final room = hub.findRoom(roomId);
        if (room == null) throw StateError('guild not found');
        final target = room.participants[userId];
        if (target == null) throw StateError('member not found');
        hub.moveToLobbyForSatori(target);
        return null;

      case 'guild.member.mute':
        final userId = body['user_id'] as String?;
        if (userId == null) throw StateError('user_id required');
        hub.muteClient(userId, seconds: body['duration'] as int? ?? 600);
        return null;

      case 'user.get':
        final userId = body['user_id'] as String? ?? profile.id;
        final client = hub.clients.firstWhereOrNull((c) => c.userId == userId);
        if (client == null) throw StateError('user not found');
        return _user(client.toDto());

      case 'message.create':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        if (room == null) throw StateError('channel not found');
        final content = body['content'] as String? ?? '';
        var segments = _elementsToSegments(content);
        if (segments.isEmpty) throw StateError('empty content');
        // 回复引用：Satori referrer 字段 = 被回复消息 id，转为 QuoteSegment
        final referrer = body['referrer'];
        if (referrer is String && referrer.isNotEmpty) {
          final replied = room.messageHistory.firstWhereOrNull(
            (m) => m.messageId == referrer,
          );
          final preview = replied != null ? replied.plainText : '';
          segments = [
            QuoteSegment(
              messageId: referrer,
              fromName: replied?.sender.displayName ?? '',
              preview: preview,
            ),
            ...segments,
          ];
        }
        // 确保机器人成员已注册（全局可见，可被 @）
        hub.registerBotMember(
          userId: profile.id,
          displayName: profile.name,
          avatarUrl: _resolveAvatar(profile.avatarUrl),
        );
        final bot =
            hub.clients.firstWhereOrNull((c) => c.userId == profile.id) ??
            hub.serverBotClient(room.roomId);
        final msg = HubMessage(
          messageType: HubMessageType.chat,
          sender: bot.toDto(),
          targetRoomIds: [room.roomId],
          segments: segments,
        );
        hub.broadcastToRoomFrom(room.roomId, msg);
        return [_message(room, msg)];

      case 'message.get':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        final messageId = body['message_id'] as String?;
        if (room == null) throw StateError('channel not found');
        final msg = room.messageHistory.firstWhereOrNull(
          (m) => m.messageId == messageId,
        );
        if (msg == null) throw StateError('message not found');
        return _message(room, msg);

      case 'message.list':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        if (room == null) throw StateError('channel not found');
        var list = room.messageHistory.reversed.toList();
        final limit = body['limit'] as int?;
        if (limit != null && limit > 0 && list.length > limit) {
          list = list.sublist(0, limit);
        }
        return list.map((m) => _message(room, m)).toList();

      case 'message.delete':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        final messageId = body['message_id'] as String?;
        if (room == null) throw StateError('channel not found');
        room.messageHistory.removeWhere((m) => m.messageId == messageId);
        hub.registerBotMember(
          userId: profile.id,
          displayName: profile.name,
          avatarUrl: _resolveAvatar(profile.avatarUrl),
        );
        final deleter =
            hub.clients.firstWhereOrNull((c) => c.userId == profile.id) ??
            hub.serverBotClient(room.roomId);
        hub.broadcastToRoomFrom(
          room.roomId,
          HubMessage(
            messageType: HubMessageType.recall,
            sender: deleter.toDto(),
            targetRoomIds: [room.roomId],
            segments: [TextSegment(messageId ?? '')],
          ),
        );
        return null;

      case 'reaction.create':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        final messageId = body['message_id'] as String?;
        final emojiId = body['emoji_id'] as String?;
        if (room == null) throw StateError('channel not found');
        final msg = room.messageHistory.firstWhereOrNull(
          (m) => m.messageId == messageId,
        );
        if (msg == null) throw StateError('message not found');
        msg.toggleReaction(
          emojiId ?? '',
          HubReactionUser(userId: profile.id, username: profile.name),
        );
        return null;

      case 'reaction.delete':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        final messageId = body['message_id'] as String?;
        final emojiId = body['emoji_id'] as String?;
        if (room == null) throw StateError('channel not found');
        final msg = room.messageHistory.firstWhereOrNull(
          (m) => m.messageId == messageId,
        );
        if (msg == null) throw StateError('message not found');
        msg.toggleReaction(
          emojiId ?? '',
          HubReactionUser(userId: profile.id, username: profile.name),
        );
        return null;

      case 'reaction.list':
        final room = hub.findRoom(body['channel_id'] as String? ?? '');
        final messageId = body['message_id'] as String?;
        final emojiId = body['emoji_id'] as String?;
        if (room == null) throw StateError('channel not found');
        final msg = room.messageHistory.firstWhereOrNull(
          (m) => m.messageId == messageId,
        );
        final reaction = msg?.reactions.firstWhereOrNull(
          (r) => r.emojiId == emojiId,
        );
        return (reaction?.users ?? <HubReactionUser>[])
            .map((u) => {'id': u.userId, 'name': u.username})
            .toList();

      case 'friend.list':
        return <Object?>[];

      case 'upload.create':
        return _handleSatoriUpload(request);

      default:
        throw StateError('method not found: $name');
    }
  }

  // ── Satori Element 与 Hub MessageSegment 互转 ────────────

  String _segmentsToElements(List<MessageSegment> segments) {
    final sb = StringBuffer();
    for (final s in segments) {
      if (s is TextSegment) {
        sb.write(_escapeText(s.text));
      } else if (s is ImageSegment) {
        sb.write('<img src="${s.url}"/>');
      } else if (s is MentionSegment) {
        sb.write('<at id="${s.userId}"/>');
      } else if (s is QuoteSegment) {
        sb.write(
          '<quote id="${s.messageId}">${_escapeText(s.preview)}</quote>',
        );
      }
    }
    return sb.toString();
  }

  String _escapeText(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  List<MessageSegment> _elementsToSegments(String content) {
    if (content.isEmpty) return [];
    final segments = <MessageSegment>[];
    final atRe = RegExp(r'<at\s+id="([^"]*)"\s*/?>');
    // 同时兼容 <img> 与 <image> 标签（Koishi 部分插件输出 <image>）
    final imgRe = RegExp(r'<img(?:e)?\s+src="([^"]*)"[^>]*/?>');
    // 自闭合 <quote id="..."/> 与带内容 <quote id="...">...</quote>
    final quoteSelfRe = RegExp(r'<quote\s+id="([^"]*)"\s*/>');
    final quoteRe = RegExp(r'<quote\s+id="([^"]*)"[^>]*>(.*?)</quote>');
    var index = 0;
    final tokens = <({int start, int end, MessageSegment segment})>[];
    for (final m in atRe.allMatches(content)) {
      tokens.add((
        start: m.start,
        end: m.end,
        segment: MentionSegment(
          userId: m.group(1) ?? '',
          displayName: m.group(1) ?? '',
        ),
      ));
    }
    for (final m in imgRe.allMatches(content)) {
      tokens.add((
        start: m.start,
        end: m.end,
        segment: ImageSegment(url: m.group(1) ?? ''),
      ));
    }
    for (final m in quoteRe.allMatches(content)) {
      tokens.add((
        start: m.start,
        end: m.end,
        segment: QuoteSegment(
          messageId: m.group(1) ?? '',
          fromName: '',
          preview: _unescapeText(m.group(2) ?? ''),
        ),
      ));
    }
    for (final m in quoteSelfRe.allMatches(content)) {
      tokens.add((
        start: m.start,
        end: m.end,
        segment: QuoteSegment(
          messageId: m.group(1) ?? '',
          fromName: '',
          preview: '',
        ),
      ));
    }
    tokens.sort((a, b) => a.start.compareTo(b.start));
    for (final t in tokens) {
      if (t.start > index) {
        final text = _unescapeText(content.substring(index, t.start));
        if (text.isNotEmpty) segments.add(TextSegment(text));
      }
      segments.add(t.segment);
      index = t.end;
    }
    if (index < content.length) {
      final text = _unescapeText(content.substring(index));
      if (text.isNotEmpty) segments.add(TextSegment(text));
    }
    return segments;
  }

  String _unescapeText(String text) => text
      // 段落/换行等块级标签 → 换行，其余残留标签剥离
      .replaceAll(RegExp(r'</?p\s*/?>'), '\n')
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'</?[a-zA-Z][^>]*>'), '')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .trim();

  // ── 数据模型转换 ────────────────────────────────────────

  Map<String, dynamic> _channel(HubRoom room) => {
    'id': room.roomId,
    'type': 0,
    'name': room.roomName,
  };

  Map<String, dynamic> _guild(HubRoom room) => {
    'id': room.roomId,
    'name': room.roomName,
  };

  Map<String, dynamic> _guildDto(HubRoomDto room) => {
    'id': room.roomId,
    'name': room.roomName,
  };

  Map<String, dynamic> _user(HubClientDto client) => {
    'id': client.userId,
    'name': client.displayName,
    if (client.avatarUrl?.isNotEmpty == true)
      'avatar': _resolveAvatar(client.avatarUrl),
    'isBot': client.isBot,
  };

  Map<String, dynamic> _member(HubClientDto client) =>
      _memberFromUser(_user(client));

  Map<String, dynamic> _memberFromUser(Map<String, dynamic> user) => {
    'user': user,
    'name': user['name'],
    if (user['avatar'] != null) 'avatar': user['avatar'],
  };

  Map<String, dynamic> _message(HubRoom room, HubMessage msg) => {
    'id': msg.messageId,
    'channel': _channel(room),
    'guild': _guild(room),
    'user': _user(msg.sender),
    'content': _segmentsToElements(msg.segments),
    'timestamp': msg.sentAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic>? _clientFromData(Map<String, dynamic> data) {
    final raw = data['client'];
    if (raw is Map<String, dynamic>) {
      return _user(HubClientDto.fromJson(raw));
    }
    final id = data['clientId'] as String?;
    if (id != null) {
      final name = data['clientName'] as String? ?? id;
      return {'id': id, 'name': name, 'isBot': false};
    }
    return null;
  }

  // ── 响应工具 ────────────────────────────────────────────

  Future<Map<String, dynamic>?> _readJsonBody(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) return {};
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendJson(
    HttpRequest request,
    Map<String, dynamic> data, {
    int status = 200,
  }) async {
    final bytes = utf8.encode(jsonEncode(data));
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set('Content-Length', bytes.length.toString())
      ..add(bytes);
    await request.response.close();
  }

  Future<void> _sendJsonValue(
    HttpRequest request,
    Object? value, {
    int status = 200,
  }) async {
    final bytes = utf8.encode(jsonEncode(value));
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set('Content-Length', bytes.length.toString())
      ..add(bytes);
    await request.response.close();
  }

  // ── upload.create：复用 Hub 上传能力 ────────────────────

  Future<Object?> _handleSatoriUpload(HttpRequest request) async {
    final hub = _hub!;
    final contentType = request.headers.contentType;
    if (contentType == null ||
        contentType.primaryType != 'multipart' ||
        contentType.subType != 'form-data') {
      throw StateError('expected multipart/form-data');
    }
    final boundary = contentType.parameters['boundary'];
    if (boundary == null || boundary.isEmpty) {
      throw StateError('missing boundary');
    }
    final body = await hub.collectRequestBodyBytes(request);
    final parsed = hub.parseMultipartFile(body, boundary);
    if (parsed == null) throw StateError('no file found');
    final url = await hub.storeUploadedFile(parsed);
    return {parsed.filename: url};
  }
}
