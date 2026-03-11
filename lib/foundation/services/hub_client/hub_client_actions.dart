part of 'package:kostori/foundation/services/services.dart';

extension HubClientActions on HubClient {
  void _send(Map<String, dynamic> data) => _socket?.add(jsonEncode(data));

  // ── 消息 ──────────────────────────────────────────────────────────────────

  void broadcast(List<MessageSegment> segments, {String? replyToMessageId}) =>
      _send({
        'messageType': 'broadcast',
        'segments': segments.map((s) => s.toJson()).toList(),
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      });

  void reply(String replyToMessageId, List<MessageSegment> segments) =>
      broadcast(segments, replyToMessageId: replyToMessageId);

  void sendTo(String targetUserId, List<MessageSegment> segments) => _send({
    'messageType': 'unicast',
    'targetUserId': targetUserId,
    'segments': segments.map((s) => s.toJson()).toList(),
  });

  void recall(String messageId) =>
      _send({'messageType': 'recall', 'messageId': messageId});

  void pin(String messageId) =>
      _send({'messageType': 'pin', 'messageId': messageId});

  void react(String messageId, String emojiId) => _send({
    'messageType': 'reaction',
    'messageId': messageId,
    'emojiId': emojiId,
  });

  // ── 房间 ──────────────────────────────────────────────────────────────────

  void joinRoom(String roomId, {String? password}) => _send({
    'messageType': 'join_room',
    'roomId': roomId,
    if (password != null) 'password': password,
  });

  void leaveRoom() => _send({'messageType': 'leave_room'});

  void createRoom(String roomName, {String? password, String? announcement}) =>
      _send({
        'messageType': 'create_room',
        'roomName': roomName,
        if (password != null) 'password': password,
        if (announcement != null) 'announcement': announcement,
      });

  void deleteRoom(String roomId) =>
      _send({'messageType': 'delete_room', 'roomId': roomId});

  void setAnnouncement(String announcement) =>
      _send({'messageType': 'set_announcement', 'announcement': announcement});

  void setRoomPassword(String? password) =>
      _send({'messageType': 'set_room_password', 'password': password});

  void search(String keyword) =>
      _send({'messageType': 'search', 'keyword': keyword});

  // ── 用户 ──────────────────────────────────────────────────────────────────

  void updateProfile({
    String? displayName,
    String? avatarUrl,
    String? biography,
  }) => _send({
    'messageType': 'profile',
    if (displayName != null) 'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (biography != null) 'biography': biography,
  });

  void setStatus(UserStatus s) =>
      _send({'messageType': 'status', 'onlineStatus': s.name});

  void poke(String targetUserId) {
    _send({'messageType': 'poke', 'targetId': targetUserId});
  }

  // ── 管理 ──────────────────────────────────────────────────────────────────

  void kickFromRoom(String userId) =>
      _send({'messageType': 'kick', 'targetUserId': userId});

  void roomBan(String userId) =>
      _send({'messageType': 'room_ban', 'targetUserId': userId});

  void roomUnban(String userId) =>
      _send({'messageType': 'room_unban', 'targetUserId': userId});

  void mute(String targetUserId, {int seconds = 300}) => _send({
    'messageType': 'mute',
    'targetUserId': targetUserId,
    'seconds': seconds,
  });

  void unmute(String targetUserId) =>
      _send({'messageType': 'unmute', 'targetUserId': targetUserId});

  void setGlobalAdmin(String targetUserId, {bool value = true}) => _send({
    'messageType': 'set_global_admin',
    'targetUserId': targetUserId,
    'value': value,
  });

  void setWelcomeMessage(String? message) {
    _send({'messageType': 'set_welcome_message', 'welcomeMessage': message});
  }

  void setRoomAdmin(String targetUserId, {bool value = true}) => _send({
    'messageType': 'set_room_admin',
    'targetUserId': targetUserId,
    'value': value,
  });

  void announce(String msg) =>
      _send({'messageType': 'announce', 'announcement': msg});

  void serverBan(String targetUserId) =>
      _send({'messageType': 'server_ban', 'targetUserId': targetUserId});

  void serverUnban(String targetUserId) =>
      _send({'messageType': 'server_unban', 'targetUserId': targetUserId});

  // ── 心跳（供 hub_client.dart 内部调用）────────────────────────────────────

  void ping() => _send({'messageType': 'ping'});
}
