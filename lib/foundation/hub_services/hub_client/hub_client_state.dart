part of 'package:kostori/foundation/hub_services/services.dart';

class HubState {
  final String? myId;
  final bool isConnected;
  final bool isGlobalAdmin;
  final bool serverUploadEnabled;
  final List<HubClientDto> onlineClients;
  final List<HubRoomDto> roomList;
  final String? currentRoomId;
  final String? currentRoomName;
  final String? lobbyRoomId;
  final List<String> serverBannedIds;
  final Map<String, List<HubMessage>> dmHistory;
  final Map<String, int> dmUnread;
  final String? activeDmUserId;
  final List<String> blockedInviteUserIds;
  final Set<String> blockedUserIds;

  const HubState({
    this.myId,
    this.isConnected = false,
    this.isGlobalAdmin = false,
    this.onlineClients = const [],
    this.roomList = const [],
    this.currentRoomId,
    this.currentRoomName,
    this.lobbyRoomId,
    this.serverBannedIds = const [],
    this.serverUploadEnabled = false,
    this.dmHistory = const {},
    this.dmUnread = const {},
    this.activeDmUserId,
    this.blockedInviteUserIds = const [],
    this.blockedUserIds = const {},
  });

  HubState copyWith({
    String? myId,
    bool? isConnected,
    bool? isGlobalAdmin,
    List<HubClientDto>? onlineClients,
    List<HubRoomDto>? roomList,
    String? currentRoomId,
    String? currentRoomName,
    String? lobbyRoomId,
    List<String>? serverBannedIds,
    bool? serverUploadEnabled,
    Map<String, List<HubMessage>>? dmHistory,
    Map<String, int>? dmUnread,
    String? activeDmUserId,
    bool clearActiveDmUserId = false,
    List<String>? blockedInviteUserIds,
    Set<String>? blockedUserIds,
  }) => HubState(
    myId: myId ?? this.myId,
    isConnected: isConnected ?? this.isConnected,
    isGlobalAdmin: isGlobalAdmin ?? this.isGlobalAdmin,
    onlineClients: onlineClients ?? this.onlineClients,
    roomList: roomList ?? this.roomList,
    currentRoomId: currentRoomId ?? this.currentRoomId,
    currentRoomName: currentRoomName ?? this.currentRoomName,
    lobbyRoomId: lobbyRoomId ?? this.lobbyRoomId,
    serverBannedIds: serverBannedIds ?? this.serverBannedIds,
    serverUploadEnabled: serverUploadEnabled ?? this.serverUploadEnabled,
    dmHistory: dmHistory ?? this.dmHistory,
    dmUnread: dmUnread ?? this.dmUnread,
    activeDmUserId: clearActiveDmUserId
        ? null
        : (activeDmUserId ?? this.activeDmUserId),
    blockedInviteUserIds: blockedInviteUserIds ?? this.blockedInviteUserIds,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
  );

  List<HubMessage> get messageHistory {
    final room = roomList.firstWhereOrNull((r) => r.roomId == currentRoomId);
    return room != null ? List.unmodifiable(room.messageHistory) : const [];
  }

  List<HubClientDto> currentRoomClients(String? lobbyId) {
    if (currentRoomId == lobbyId) return onlineClients;
    final room = roomList.firstWhereOrNull((r) => r.roomId == currentRoomId);
    if (room == null) return onlineClients;
    final memberIds = room.participants.map((p) => p.userId).toSet();
    return onlineClients.where((c) => memberIds.contains(c.userId)).toList();
  }

  List<String> get currentRoomModerators {
    final room = roomList.firstWhereOrNull((r) => r.roomId == currentRoomId);
    return room?.moderatorIds ?? [];
  }

  HubRoomDto? get currentRoom =>
      roomList.firstWhereOrNull((r) => r.roomId == currentRoomId);

  int totalDmUnread() => dmUnread.values.fold(0, (a, b) => a + b);
}

final hubProvider = StateProvider<HubState>((ref) => const HubState());
