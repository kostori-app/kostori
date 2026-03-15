part of 'package:kostori/foundation/services/services.dart';

extension HubClientUtils on HubClient {
  // ── 内部状态操作 ──────────────────────────────────────────────────────────

  void _addMessageToRoom(HubMessage msg) {
    final roomId = msg.targetRoomIds.firstOrNull ?? _s.currentRoomId;
    if (roomId == null) return;
    final idx = _s.roomList.indexWhere((r) => r.roomId == roomId);
    if (idx == -1) return;
    _s.roomList[idx].messageHistory.add(msg);
    _setState((s) => s.copyWith(roomList: [...s.roomList]));
  }

  void _upsertRoom(HubRoomDto incoming, {bool preserveHistory = false}) {
    final idx = _s.roomList.indexWhere((r) => r.roomId == incoming.roomId);
    final history = (preserveHistory && idx != -1)
        ? _s.roomList[idx].messageHistory
        : <HubMessage>[];
    final updated = HubRoomDto(
      roomId: incoming.roomId,
      roomName: incoming.roomName,
      announcements: incoming.announcements,
      ownerUserId: incoming.ownerUserId,
      moderatorIds: incoming.moderatorIds,
      participants: incoming.participants,
      isLocked: incoming.isLocked,
      isFull: incoming.isFull,
      maxParticipants: incoming.maxParticipants,
      allowMemberInvite: incoming.allowMemberInvite,
      createdAt: incoming.createdAt,
      bannedUserIds: incoming.bannedUserIds,
      pinnedMessages: incoming.pinnedMessages,
      messageHistory: history,
      welcomeMessage: incoming.welcomeMessage,
    );
    final newRooms = [..._s.roomList];
    if (idx != -1) {
      newRooms[idx] = updated;
    } else {
      newRooms.add(updated);
    }
    _setState((s) => s.copyWith(roomList: newRooms));
  }

  void _patchClient(
    String clientId, {
    bool? isGlobalAdmin,
    bool? isMuted,
    UserStatus? onlineStatus,
  }) {
    final idx = _s.onlineClients.indexWhere((c) => c.userId == clientId);
    if (idx == -1) return;
    final c = _s.onlineClients[idx];
    final newClients = [..._s.onlineClients];
    newClients[idx] = HubClientDto(
      userId: c.userId,
      displayName: c.displayName,
      avatarUrl: c.avatarUrl,
      biography: c.biography,
      onlineStatus: onlineStatus ?? c.onlineStatus,
      isGlobalAdmin: isGlobalAdmin ?? c.isGlobalAdmin,
      isMuted: isMuted ?? c.isMuted,
      connectedAt: c.connectedAt,
      currentRoomId: c.currentRoomId,
    );
    _setState((s) => s.copyWith(onlineClients: newClients));
  }

  // ── 设备 ID ───────────────────────────────────────────────────────────────

  Future<String> getDeviceId() async {
    final info = await _collectDeviceFingerprint();
    return const Uuid().v5(Namespace.oid.value, info);
  }

  Future<String> _collectDeviceFingerprint() async {
    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        return [
          info.id,
          info.model,
          info.brand,
          info.hardware,
          info.fingerprint,
        ].join('|');
      } else if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        return [
          info.identifierForVendor ?? '',
          info.utsname.machine,
          info.model,
        ].join('|');
      } else if (Platform.isMacOS) {
        final info = await DeviceInfoPlugin().macOsInfo;
        return [info.systemGUID ?? '', info.computerName, info.model].join('|');
      } else if (Platform.isWindows) {
        final info = await DeviceInfoPlugin().windowsInfo;
        return [info.deviceId, info.computerName].join('|');
      } else if (Platform.isLinux) {
        final info = await DeviceInfoPlugin().linuxInfo;
        return [info.machineId ?? '', info.name].join('|');
      }
    } catch (e) {
      HubLog.warning('HubClient', '设备信息获取失败，降级：$e');
    }
    return '${Platform.operatingSystem}|$pid';
  }

  // ── 默认显示名 ────────────────────────────────────────────────────────────

  Future<String> getDefaultDisplayName() async {
    try {
      if (App.isAndroid) return (await DeviceInfoPlugin().androidInfo).model;
      if (App.isIOS) return (await DeviceInfoPlugin().iosInfo).name;
      if (App.isMacOS) return (await DeviceInfoPlugin().macOsInfo).computerName;
      if (App.isWindows) {
        return (await DeviceInfoPlugin().windowsInfo).computerName;
      }
      if (App.isLinux) return (await DeviceInfoPlugin().linuxInfo).prettyName;
    } catch (e) {
      HubLog.warning('HubClient', '获取设备名失败：$e');
    }
    return 'User';
  }
}
