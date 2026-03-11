part of 'package:kostori/foundation/services/services.dart';

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
}

final hubProvider = StateProvider<HubState>((ref) => const HubState());
