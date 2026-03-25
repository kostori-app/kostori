part of 'settings_page.dart';

class _HubClientDetailPage extends ConsumerStatefulWidget {
  const _HubClientDetailPage();

  @override
  ConsumerState<_HubClientDetailPage> createState() =>
      _HubClientDetailPageState();
}

class _HubClientDetailPageState extends ConsumerState<_HubClientDetailPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _tokenController;
  late final HubClient _hubClient;
  bool _tokenObscured = true;

  @override
  void initState() {
    super.initState();
    _hubClient = ref.read(hubClientProvider);
    final saved = _hubClient.savedAddress ?? '';
    String host = '';
    String port = '9100';
    if (saved.isNotEmpty) {
      try {
        final uri = Uri.parse(saved);
        host = uri.host;
        port = uri.hasPort ? uri.port.toString() : '9100';
      } catch (_) {
        host = saved;
      }
    }
    _hostController = TextEditingController(text: host);
    _portController = TextEditingController(text: port);
    _tokenController = TextEditingController(text: _hubClient.savedToken ?? '');

    _hubClient.onClientsChanged = () {
      if (mounted) setState(() {});
    };
    _hubClient.onRoomListChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _hubClient.onClientsChanged = null;
    _hubClient.onRoomListChanged = null;
    super.dispose();
  }

  void _saveAddress() {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    if (host.isNotEmpty) _hubClient.saveAddress('ws://$host:$port');
  }

  // ── 编辑资料 ──────────────────────────────────────────────────────────────

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final nameCtrl = TextEditingController(text: _hubClient.savedName);
    final bioCtrl = TextEditingController(text: _hubClient.savedBio);
    final avatarCtrl = TextEditingController(text: _hubClient.savedAvatar);

    await showHubFormDialog(
      title: t.editProfile,
      confirmLabel: t.save,
      fields: [
        InputField(
          controller: nameCtrl,
          hint: t.enterDisplayName,
          icon: Icons.person_outline,
        ),
        InputField(
          controller: avatarCtrl,
          hint: 'https://...',
          icon: Icons.image_outlined,
        ),
        InputField(
          controller: bioCtrl,
          hint: t.enterBio,
          icon: Icons.info_outline,
        ),
      ],
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        final bio = bioCtrl.text.trim();
        final avatar = avatarCtrl.text.trim();

        if (name.isNotEmpty) _hubClient.saveName(name);
        if (bio.isNotEmpty) _hubClient.saveBio(bio);
        if (avatar.isNotEmpty) {
          final uri = Uri.tryParse(avatar);
          if (uri == null || !uri.hasScheme) {
            App.rootContext.showMessage(
              message:
                  t.pleaseEnterAValidUrl,
              level: LogLevel.warning,
            );
            return null;
          }
          _hubClient.saveAvatar(avatar);
        }

        if (_hubClient.isConnected) {
          _hubClient.updateProfile(
            displayName: name.isNotEmpty ? name : null,
            biography: bio.isNotEmpty ? bio : null,
            avatarUrl: avatar.isNotEmpty ? avatar : null,
          );
        }
        return null;
      },
    );

    nameCtrl.dispose();
    bioCtrl.dispose();
    avatarCtrl.dispose();
  }

  // ── 房间列表 ──────────────────────────────────────────────────────────────

  void _showJoinRoomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) {
          _hubClient.onRoomListChanged = () {
            if (context.mounted) setSS(() {});
          };

          final hubState = ref.read(hubProvider);
          final rooms = hubState.roomList;
          final myId = hubState.myId;
          final canCreate =
              _hubClient.isGlobalAdmin ||
              !rooms.any((r) => r.ownerUserId == myId);

          return Sheet(
            title: t.rooms,
            icon: Icons.meeting_room_outlined,
            headerTrailing: canCreate
                ? TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(t.create),
                    onPressed: () async {
                      await _showClientCreateRoomDialog(context);
                      setSS(() {});
                    },
                  )
                : null,
            footer:
                hubState.currentRoomId != null &&
                    hubState.currentRoomId != hubState.lobbyRoomId
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text(t.leaveRoom),
                      onPressed: () {
                        _hubClient.leaveRoom();
                        Navigator.pop(context);
                      },
                    ),
                  )
                : null,
            builder: (context, sc) {
              if (rooms.isEmpty) {
                return Center(child: HubEmptyHint(t.noRooms));
              }
              return ListView.builder(
                controller: sc,
                itemCount: rooms.length,
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final isCurrent = room.roomId == hubState.currentRoomId;
                  final isLobby = room.roomId == hubState.lobbyRoomId;
                  final canManage =
                      !isLobby &&
                      (_hubClient.isGlobalAdmin ||
                          _hubClient.isRoomAdminOf(room.roomId));

                  return ListTile(
                    leading: Icon(
                      room.isLocked
                          ? Icons.lock_outlined
                          : Icons.meeting_room_outlined,
                    ),
                    title: Text(isLobby ? t.lobby : room.roomName),
                    subtitle: Text('${room.participantCount} ${t.members}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canManage)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            tooltip: t.roomSettings,
                            onPressed: () =>
                                showHubRoomSettingsSheet(context, room),
                          ),
                        if (isCurrent)
                          Text(
                            t.current,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          )
                        else ...[
                          TextButton(
                            child: Text(t.join),
                            onPressed: () async {
                              if (room.isLocked) {
                                final pwd = await _showPasswordDialog(context);
                                if (pwd == null) return;
                                _hubClient.joinRoom(room.roomId, password: pwd);
                              } else {
                                _hubClient.joinRoom(room.roomId);
                              }
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    ).whenComplete(() => _hubClient.onRoomListChanged = null);
  }

  Future<void> _showClientCreateRoomDialog(BuildContext context) async {
    final result = await showCreateRoomDialog();
    if (result == null) return;
    _hubClient.createRoom(
      result.name,
      password: result.password,
      announcement: result.announcement,
      maxParticipants: result.maxParticipants,
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.roomPassword),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: t.password),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text(t.ok),
          ),
        ],
      ),
    );
  }

  // ── 本地屏蔽 ──────────────────────────────────────────────────────────────

  void _showClientBlacklistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) {
          final blocked = _hubClient.blockedUsers;
          return Sheet(
            title: t.blockedUsers,
            icon: Icons.block_outlined,
            builder: (context, sc) {
              if (blocked.isEmpty) {
                return Center(child: HubEmptyHint(t.noBlockedUsers));
              }
              return ListView.builder(
                controller: sc,
                itemCount: blocked.length,
                itemBuilder: (context, i) {
                  final id = blocked[i];
                  final client = ref
                      .read(hubProvider)
                      .onlineClients
                      .firstWhereOrNull((c) => c.userId == id);
                  return HubClientTile(
                    name: client?.displayName ?? id,
                    avatarUrl: client?.avatarUrl,
                    userId: id,
                    trailing: IconButton(
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      tooltip: t.unblock,
                      onPressed: () {
                        _hubClient.unblockUser(id);
                        setSS(() {});
                        setState(() {});
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(hubProvider);
    final isConnected = _hubClient.isConnected;
    final cs = Theme.of(context).colorScheme;

    return PopUpWidgetScaffold(
      title: t.hubDetails,
      body: CustomScrollView(
        slivers: [
          // ── 服务器地址 ──
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.serverAddress,
                  icon: Icons.dns_outlined,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.toOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ws://'
                          '${_hostController.text.isEmpty ? '192.168.x.x' : _hostController.text}'
                          ':${_portController.text}',
                          style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: cs.onSurface.toOpacity(0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _LabeledField(
                              label: t.host,
                              child: _HostInput(
                                controller: _hostController,
                                enabled: !isConnected,
                                hintText: '192.168.1.x',
                                onChanged: (_) {
                                  _saveAddress();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            child: _LabeledField(
                              label: t.port,
                              child: _NumberInput(
                                controller: _portController,
                                enabled: !isConnected,
                                onChanged: (_) {
                                  _saveAddress();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Token ──
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.authentication,
                  icon: Icons.key_outlined,
                ),
                _SettingRow(
                  title: t.hubToken,
                  subtitle: t.tokenFromTheHubServer,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _tokenObscured
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                        ),
                        tooltip: _tokenObscured ? t.show : t.hide,
                        onPressed: () =>
                            setState(() => _tokenObscured = !_tokenObscured),
                      ),
                      if (_tokenController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: t.copy,
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _tokenController.text),
                            );
                            App.rootContext.showMessage(message: t.copied);
                          },
                        ),
                      if (!isConnected)
                        _tokenController.text.isEmpty
                            ? IconButton(
                                icon: const Icon(Icons.content_paste, size: 18),
                                tooltip: t.paste,
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  final text = data?.text?.trim() ?? '';
                                  if (text.isNotEmpty) {
                                    _tokenController.text = text;
                                    _hubClient.saveToken(text);
                                    setState(() {});
                                  }
                                },
                              )
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: t.clear,
                                onPressed: () {
                                  _tokenController.clear();
                                  _hubClient.saveToken('');
                                  setState(() {});
                                },
                              ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _tokenController,
                    enabled: !isConnected,
                    obscureText: _tokenObscured,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: t.pasteHubServerToken,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.toOpacity(0.5),
                    ),
                    onChanged: (v) {
                      _hubClient.saveToken(v.trim());
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),

          _BuildSectionPadding(
            _SettingCard(
              children: [_ClientUploadConfigSetting(client: _hubClient)],
            ),
          ),

          // ── 资料 & 房间 ──
          if (isConnected)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.profileAndRoom,
                    icon: Icons.person_outline,
                  ),
                  _SettingRow(
                    title: t.displayName,
                    subtitle: _hubClient.savedName ?? t.notSet,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showEditProfileDialog(context),
                    ),
                  ),
                  _SettingRow(
                    title: t.currentRoom,
                    subtitle: () {
                      final name = hubState.currentRoomName;
                      return (name == null || name.toLowerCase() == 'lobby')
                          ? t.lobby
                          : name;
                    }(),
                    trailing: IconButton(
                      icon: const Icon(Icons.meeting_room_outlined, size: 18),
                      onPressed: () => _showJoinRoomSheet(context),
                    ),
                  ),
                ],
              ),
            ),

          // ── 本地屏蔽 ──
          if (isConnected)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.blockedUsers,
                    icon: Icons.volume_off_outlined,
                  ),
                  _SettingRow(
                    title: '${_hubClient.blockedUsers.length} ${t.blocked}',
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => _showClientBlacklistSheet(context),
                    ),
                  ),
                ],
              ),
            ),

          // ── 屏蔽邀请 ──
          if (isConnected)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.blockedInvites,
                    icon: Icons.person_off_outlined,
                  ),
                  if (hubState.blockedInviteUserIds.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Text(
                        t.noBlockedInvites,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.toOpacity(0.4),
                        ),
                      ),
                    )
                  else
                    ...hubState.blockedInviteUserIds.map((id) {
                      final c = hubState.onlineClients.firstWhereOrNull(
                        (c) => c.userId == id,
                      );
                      return _SettingRow(
                        title: c?.displayName ?? id,
                        trailing: TextButton(
                          child: Text(t.unblock),
                          onPressed: () {
                            _hubClient.unblockInvite(id);
                            setState(() {});
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),

          // ── 在线客户端 ──
          if (isConnected && hubState.onlineClients.isNotEmpty)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.onlineClients,
                    icon: Icons.people_outline,
                  ),
                  ...hubState.onlineClients.map(
                    (client) => _OnlineClientTile(
                      client: client,
                      myId: hubState.myId,
                      isBlocked: _hubClient.isBlocked(client.userId),
                      canManage:
                          hubState.isGlobalAdmin ||
                          _hubClient.isRoomAdminOf(hubState.currentRoomId),
                      isBlacklisted: hubState.serverBannedIds.contains(
                        client.userId,
                      ),
                      onBlock: () {
                        _hubClient.isBlocked(client.userId)
                            ? _hubClient.unblockUser(client.userId)
                            : _hubClient.blockUser(client.userId);
                        setState(() {});
                      },
                      onMute: (seconds) {
                        if (seconds == 0 || client.isMuted) {
                          _hubClient.unmute(client.userId);
                        } else {
                          _hubClient.mute(client.userId, seconds: seconds);
                        }
                        setState(() {});
                      },
                      onKick: () {
                        _hubClient.kickFromRoom(client.userId);
                        setState(() {});
                      },
                      onBlacklist: hubState.isGlobalAdmin
                          ? () {
                              hubState.serverBannedIds.contains(client.userId)
                                  ? _hubClient.serverUnban(client.userId)
                                  : _hubClient.serverBan(client.userId);
                              setState(() {});
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
