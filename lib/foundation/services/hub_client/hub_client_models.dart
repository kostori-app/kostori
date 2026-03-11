part of 'package:kostori/foundation/services/services.dart';

// ── HubClientDto（客户端视图，无 WebSocket）──────────

class HubClientDto {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? biography;
  final UserStatus onlineStatus;
  final bool isGlobalAdmin;
  final bool isMuted;
  final DateTime connectedAt;
  final String currentRoomId;
  final bool isBot;

  HubClientDto({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.biography,
    this.onlineStatus = UserStatus.online,
    this.isGlobalAdmin = false,
    this.isMuted = false,
    required this.connectedAt,
    this.currentRoomId = 'lobby',
    this.isBot = false,
  });

  factory HubClientDto.fromJson(Map<String, dynamic> json) {
    return HubClientDto(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String? ?? json['userId'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      biography: json['biography'] as String?,
      onlineStatus:
          UserStatus.values.firstWhereOrNull(
            (e) => e.name == json['onlineStatus'],
          ) ??
          UserStatus.online,
      isGlobalAdmin: json['isGlobalAdmin'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      connectedAt: json['connectedAt'] != null
          ? DateTime.tryParse(json['connectedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      currentRoomId: json['currentRoomId'] as String? ?? 'lobby',
      isBot: json['isBot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'biography': biography,
    'onlineStatus': onlineStatus.name,
    'isGlobalAdmin': isGlobalAdmin,
    'isMuted': isMuted,
    'connectedAt': connectedAt.toIso8601String(),
    'currentRoomId': currentRoomId,
    'isBot': isBot,
  };
}

// ── HubRoomDto（客户端视图，无服务端成员映射）──────────

class HubRoomDto {
  final String roomId;
  final String roomName;
  final String? welcomeMessage;
  final List<String> announcements;
  final String ownerUserId;
  final List<String> moderatorIds;
  final List<HubClientDto> participants;
  final bool isLocked;
  final bool isFull;
  final int? maxParticipants;
  final bool allowMemberInvite;
  final DateTime createdAt;
  final List<String> bannedUserIds;
  final List<HubMessage> pinnedMessages;
  final List<HubMessage> messageHistory;

  HubRoomDto({
    required this.roomId,
    required this.roomName,
    required this.announcements,
    required this.ownerUserId,
    required this.moderatorIds,
    required this.participants,
    required this.isLocked,
    required this.isFull,
    required this.maxParticipants,
    required this.allowMemberInvite,
    required this.createdAt,
    required this.bannedUserIds,
    required this.pinnedMessages,
    List<HubMessage>? messageHistory,
    this.welcomeMessage,
  }) : messageHistory = messageHistory ?? [];

  int get participantCount => participants.length;

  bool isModerator(String userId) =>
      ownerUserId == userId || moderatorIds.contains(userId);

  bool isPinned(String messageId) =>
      pinnedMessages.any((m) => m.messageId == messageId);

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'roomName': roomName,
    'announcements': announcements,
    'ownerUserId': ownerUserId,
    'moderatorIds': moderatorIds,
    'participants': participants.map((p) => p.toJson()).toList(),
    'isLocked': isLocked,
    'isFull': isFull,
    'maxParticipants': maxParticipants,
    'allowMemberInvite': allowMemberInvite,
    'createdAt': createdAt.toIso8601String(),
    'bannedUserIds': bannedUserIds,
    'pinnedMessages': pinnedMessages.map((m) => m.toJson()).toList(),
    'welcomeMessage': welcomeMessage,
  };

  factory HubRoomDto.fromJson(Map<String, dynamic> json) => HubRoomDto(
    roomId: json['roomId'] as String,
    roomName: json['roomName'] as String,
    announcements: List<String>.from(json['announcements'] as List? ?? []),
    ownerUserId: json['ownerUserId'] as String,
    moderatorIds: List<String>.from(json['moderatorIds'] as List? ?? []),
    participants: (json['participants'] as List? ?? [])
        .map((p) => HubClientDto.fromJson(p as Map<String, dynamic>))
        .toList(),
    isLocked: json['isLocked'] as bool? ?? false,
    isFull: json['isFull'] as bool? ?? false,
    maxParticipants: json['maxParticipants'] as int?,
    allowMemberInvite: json['allowMemberInvite'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    bannedUserIds: List<String>.from(json['bannedUserIds'] as List? ?? []),
    pinnedMessages: (json['pinnedMessages'] as List? ?? [])
        .map((m) => HubMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    messageHistory: (json['history'] as List? ?? [])
        .map((m) => HubMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    welcomeMessage: json['welcomeMessage'] as String?,
  );

  HubRoomDto copyWith({
    String? roomId,
    String? roomName,
    String? welcomeMessage,
    List<String>? announcements,
    String? ownerUserId,
    List<String>? moderatorIds,
    List<HubClientDto>? participants,
    bool? isLocked,
    bool? isFull,
    int? maxParticipants,
    bool? allowMemberInvite,
    DateTime? createdAt,
    List<String>? bannedUserIds,
    List<HubMessage>? pinnedMessages,
    List<HubMessage>? messageHistory,
  }) => HubRoomDto(
    roomId: roomId ?? this.roomId,
    roomName: roomName ?? this.roomName,
    welcomeMessage: welcomeMessage ?? this.welcomeMessage,
    announcements: announcements ?? this.announcements,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    moderatorIds: moderatorIds ?? this.moderatorIds,
    participants: participants ?? this.participants,
    isLocked: isLocked ?? this.isLocked,
    isFull: isFull ?? this.isFull,
    maxParticipants: maxParticipants ?? this.maxParticipants,
    allowMemberInvite: allowMemberInvite ?? this.allowMemberInvite,
    createdAt: createdAt ?? this.createdAt,
    bannedUserIds: bannedUserIds ?? this.bannedUserIds,
    pinnedMessages: pinnedMessages ?? this.pinnedMessages,
    messageHistory: messageHistory ?? this.messageHistory,
  );
}
