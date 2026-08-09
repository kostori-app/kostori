part of 'package:kostori/foundation/hub_services/services.dart';

// ── HubClientInfo（服务端专用，保留 WebSocket）──────────

class HubClientInfo {
  final String userId;
  String? displayName;
  final WebSocket? connection;
  final DateTime connectedAt;
  String? avatarUrl;
  String? biography;
  UserStatus onlineStatus;
  bool isGlobalAdmin;
  DateTime? mutedUntil;
  String currentRoomId;
  final bool isBot;

  /// 该客户端连接时使用的鉴权 token（用于按 token 逐人加密广播）
  String? authToken;

  /// 该客户端可直连的候选地址（一起看 P2P：房主上报自己的直连 WS 地址）
  List<String> peerCandidates = const [];

  bool get isMuted => mutedUntil != null && mutedUntil!.isAfter(DateTime.now());
  DateTime lastHeartbeat = DateTime.now();

  HubClientInfo({
    required this.userId,
    required this.connection,
    this.displayName,
    this.avatarUrl,
    this.biography,
    this.onlineStatus = UserStatus.online,
    this.isGlobalAdmin = false,
    this.mutedUntil,
    this.currentRoomId = 'lobby',
    this.isBot = false,
  }) : connectedAt = DateTime.now();

  HubClientDto toDto() => HubClientDto(
    userId: userId,
    displayName: displayName ?? userId,
    avatarUrl: avatarUrl,
    biography: biography,
    onlineStatus: onlineStatus,
    isGlobalAdmin: isGlobalAdmin,
    isMuted: isMuted,
    connectedAt: connectedAt,
    currentRoomId: currentRoomId,
    isBot: isBot,
    peerCandidates: peerCandidates,
  );

  Map<String, dynamic> toJson() => toDto().toJson();

  void send(Map<String, dynamic> data) {
    if (connection == null) return; // 机器人无连接
    try {
      HubLog.info('send', '服务端发送: ${jsonEncode(data)}');
      connection!.add(jsonEncode(data));
    } catch (_) {}
  }
}

// ── HubRoom（服务端专用）─────────────────────────────

/// 房间类型：chat 普通聊天房，watch 一起看房间
enum HubRoomType { chat, watch }

class HubRoom {
  final String roomId;
  String roomName;
  List<String> announcements;
  String? password;
  final String ownerUserId;
  final DateTime createdAt;
  final Map<String, HubClientInfo> participants = {};
  final List<HubMessage> messageHistory = [];
  final Set<String> moderatorIds = {};
  final Set<String> bannedUserIds = {};
  final Set<String> invitedUserIds = {};
  final List<HubMessage> pinnedMessages = [];
  static const _maxMessageHistory = 400;
  String? welcomeMessage;

  int? maxParticipants;
  bool allowMemberInvite;

  /// 房间类型（chat / watch）
  HubRoomType roomType;

  /// 一起看房间的番剧信息（普通聊天房为空）
  String? animeId;
  String? animeTitle;
  String? animeSourceKey;
  String? animeCover;

  HubRoom({
    String? roomId,
    required this.roomName,
    required this.ownerUserId,
    List<String>? announcements,
    this.password,
    this.maxParticipants,
    this.allowMemberInvite = false,
    this.welcomeMessage,
    this.roomType = HubRoomType.chat,
    this.animeId,
    this.animeTitle,
    this.animeSourceKey,
    this.animeCover,
  }) : roomId = roomId ?? const Uuid().v4(),
       createdAt = DateTime.now(),
       announcements = announcements ?? [];

  // ── 计算属性 ──────────────────────────────────

  bool get isLocked => password != null && password!.isNotEmpty;

  bool get isFull =>
      maxParticipants != null && participants.length >= maxParticipants!;

  int get participantCount => participants.length;

  bool isPinned(String messageId) =>
      pinnedMessages.any((m) => m.messageId == messageId);

  // ── 权限方法 ──────────────────────────────────

  bool isModerator(String userId) =>
      ownerUserId == userId || moderatorIds.contains(userId);

  bool isInvited(String userId) => invitedUserIds.contains(userId);

  bool canInvite(String userId) => isModerator(userId) || allowMemberInvite;

  // 验证密码：被邀请的用户可以无视密码
  bool validatePassword(String userId, String? pwd) {
    if (!isLocked) return true;
    if (isInvited(userId)) return true;
    return pwd == password;
  }

  // 验证是否可以加入（密码 + 人数上限）
  bool canJoin(String userId, String? pwd) {
    if (isFull) return false;
    return validatePassword(userId, pwd);
  }

  // ── 消息 ──────────────────────────────────────

  void addMessage(HubMessage message) {
    messageHistory.add(message);
    if (messageHistory.length > _maxMessageHistory) {
      messageHistory.removeAt(0);
    }
  }

  // 置顶/取消置顶
  void togglePin(HubMessage msg) {
    final exists = pinnedMessages.any((m) => m.messageId == msg.messageId);
    if (exists) {
      pinnedMessages.removeWhere((m) => m.messageId == msg.messageId);
    } else {
      pinnedMessages.add(msg);
    }
  }

  // ── 公告 ──────────────────────────────────────

  void addAnnouncement(String announcement) {
    announcements.add(announcement);
  }

  void removeAnnouncement(int index) {
    if (index >= 0 && index < announcements.length) {
      announcements.removeAt(index);
    }
  }

  // ── 序列化 ────────────────────────────────────

  HubRoomDto toDto() => HubRoomDto(
    roomId: roomId,
    roomName: roomName,
    announcements: announcements,
    ownerUserId: ownerUserId,
    moderatorIds: moderatorIds.toList(),
    participants: participants.values.map((p) => p.toDto()).toList(),
    isLocked: isLocked,
    isFull: isFull,
    maxParticipants: maxParticipants,
    allowMemberInvite: allowMemberInvite,
    createdAt: createdAt,
    bannedUserIds: bannedUserIds.toList(),
    pinnedMessages: List.from(pinnedMessages),
    welcomeMessage: welcomeMessage,
    roomType: roomType,
    animeId: animeId,
    animeTitle: animeTitle,
    animeSourceKey: animeSourceKey,
    animeCover: animeCover,
  );

  Map<String, dynamic> toJson() => toDto().toJson();
}
