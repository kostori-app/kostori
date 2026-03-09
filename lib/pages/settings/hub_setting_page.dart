part of 'settings_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  公共组件
// ═══════════════════════════════════════════════════════════════════════════

/// 底部 Sheet 统一标题栏
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.icon, this.trailing});

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (trailing != null) trailing!,
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// 可拖拽底部 Sheet 模板
class _DraggableSheet extends StatelessWidget {
  const _DraggableSheet({
    required this.title,
    this.icon,
    this.headerTrailing,
    required this.builder,
    this.initialSize = 0.6,
    this.maxSize = 0.9,
    this.footer,
  });

  final String title;
  final IconData? icon;
  final Widget? headerTrailing;
  final Widget Function(BuildContext, ScrollController) builder;
  final double initialSize;
  final double maxSize;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      maxChildSize: maxSize,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _SheetHeader(title: title, icon: icon, trailing: headerTrailing),
          Expanded(child: builder(context, scrollController)),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

/// 统一表单 Dialog
Future<T?> _showFormDialog<T>({
  required BuildContext context,
  required String title,
  required List<Widget> fields,
  required String confirmLabel,
  required Future<T?> Function() onConfirm,
  String? cancelLabel,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: fields.expand((f) => [f, const SizedBox(height: 8)]).toList()
          ..removeLast(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel ?? "Cancel".tl),
        ),
        TextButton(
          onPressed: () async {
            final result = await onConfirm();
            if (context.mounted) Navigator.pop(context, result);
          },
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

/// 成员头像 + 名称 Tile
class _ClientTile extends StatelessWidget {
  const _ClientTile({
    required this.name,
    this.avatarUrl,
    this.trailing,
    this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: avatarUrl != null && avatarUrl!.isNotEmpty
          ? CircleAvatar(backgroundImage: NetworkImage(avatarUrl!))
          : CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ),
      title: Text(name),
      trailing: trailing,
    );
  }
}

/// 空状态提示
class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.toOpacity(0.4),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _HubManagementPage
// ═══════════════════════════════════════════════════════════════════════════

class _HubManagementPage extends StatefulWidget {
  const _HubManagementPage();

  @override
  State<_HubManagementPage> createState() => _HubManagementPageState();
}

class _HubManagementPageState extends State<_HubManagementPage> {
  final _hub = HubService();

  @override
  void initState() {
    super.initState();
    _hub.onClientsChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _hub.onClientsChanged = null;
    super.dispose();
  }

  // ── 黑名单 ────────────────────────────────────────────────────────────────

  void _showBlacklistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: "Blacklist".tl, icon: Icons.block_outlined),
            if (_hub.blacklist.isEmpty)
              _EmptyHint("No banned users".tl)
            else
              ..._hub.blacklist.map(
                (id) => _ClientTile(
                  name: id,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    tooltip: "Remove from Blacklist".tl,
                    onPressed: () {
                      _hub.removeFromBlacklist(id);
                      setSS(() {});
                      setState(() {});
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── 房间列表 ──────────────────────────────────────────────────────────────

  void _showRoomsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => _DraggableSheet(
          title: "Rooms".tl,
          icon: Icons.meeting_room_outlined,
          headerTrailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text("Create".tl),
            onPressed: () async {
              await _showCreateRoomDialog(context);
              setSS(() {});
            },
          ),
          builder: (context, sc) => ListView.builder(
            controller: sc,
            itemCount: _hub.rooms.length,
            itemBuilder: (context, i) {
              final room = _hub.rooms[i];
              final isLobby = room.id == _hub.lobbyId;
              return ListTile(
                leading: Icon(
                  room.isLocked
                      ? Icons.lock_outlined
                      : Icons.meeting_room_outlined,
                ),
                title: Text(room.name),
                subtitle: Text(
                  '${room.members.length} ${"members".tl}'
                  '${room.announcement != null ? "  ·  ${room.announcement}" : ""}',
                ),
                trailing: isLobby
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.manage_accounts_outlined,
                              size: 18,
                            ),
                            tooltip: "Room Admins".tl,
                            onPressed: () =>
                                _showRoomAdminSheet(context, room, setSS),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: "Delete Room".tl,
                            onPressed: () async {
                              await _hub.deleteRoom(room.id);
                              setSS(() {});
                            },
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final announcementCtrl = TextEditingController();

    await _showFormDialog(
      context: context,
      title: "Create Room".tl,
      confirmLabel: "Create".tl,
      fields: [
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: "Room Name".tl),
        ),
        TextField(
          controller: passwordCtrl,
          decoration: InputDecoration(
            labelText: "Password".tl,
            hintText: "Leave empty for public".tl,
          ),
        ),
        TextField(
          controller: announcementCtrl,
          decoration: InputDecoration(labelText: "Announcement".tl),
        ),
      ],
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return null;
        await _hub.createRoom(
          name,
          password: passwordCtrl.text.trim().isEmpty
              ? null
              : passwordCtrl.text.trim(),
          announcement: announcementCtrl.text.trim().isEmpty
              ? null
              : announcementCtrl.text.trim(),
        );
        setState(() {});
        return null;
      },
    );
  }

  void _showRoomAdminSheet(
    BuildContext context,
    HubRoom room,
    StateSetter setParent,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: "${"Room Admins".tl} · ${room.name}",
              icon: Icons.manage_accounts_outlined,
            ),
            Expanded(
              child: ListView(
                children: _hub.clients.map((client) {
                  final isAdmin = room.isAdmin(client.id);
                  return _ClientTile(
                    name: client.name ?? client.id,
                    avatarUrl: client.avatar,
                    trailing: Switch(
                      value: isAdmin,
                      onChanged: (val) async {
                        await _hub.setClientRoomAdmin(client.id, room.id, val);
                        setSS(() {});
                        setParent(() {});
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Hub Management".tl,
      body: CustomScrollView(
        slivers: [
          // 房间
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Rooms".tl,
                  icon: Icons.meeting_room_outlined,
                ),
                _SettingRow(
                  title: "${_hub.rooms.length} ${"rooms".tl}",
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _showRoomsSheet(context),
                  ),
                ),
              ],
            ),
          ),

          // 在线客户端
          if (_hub.clientCount > 0)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: "Online Clients".tl,
                    icon: Icons.people_outline,
                  ),
                  ..._hub.clients.map(
                    (client) => _OnlineClientTile(
                      client: {
                        'id': client.id,
                        'name': client.name,
                        'avatar': client.avatar,
                        'bio': client.bio,
                        'status': client.status.name,
                        'isMuted': client.isMuted,
                        'isGlobalAdmin': client.isGlobalAdmin,
                      },
                      myId: null,
                      isBlocked: false,
                      canManage: true,
                      onBlock: () {},
                      onMute: (seconds) async {
                        if (seconds == 0 || client.isMuted) {
                          await _hub.unmuteClient(client.id);
                        } else {
                          await _hub.muteClient(client.id, seconds: seconds);
                        }
                        setState(() {});
                      },
                      onKick: () async {
                        await _hub.kickClient(client.id);
                        setState(() {});
                      },
                      onSetAdmin: () async {
                        await _hub.setClientGlobalAdmin(
                          client.id,
                          !client.isGlobalAdmin,
                        );
                        setState(() {});
                      },
                      isAdmin: client.isGlobalAdmin,
                      onBlacklist: () async {
                        if (_hub.isBlacklisted(client.id)) {
                          _hub.removeFromBlacklist(client.id);
                        } else {
                          _hub.addToBlacklist(client.id);
                        }
                        setState(() {});
                      },
                      isBlacklisted: _hub.isBlacklisted(client.id),
                    ),
                  ),
                ],
              ),
            ),

          // 消息历史
          if (_hub.messageHistory.isNotEmpty)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: "Message History".tl,
                    icon: Icons.history_outlined,
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _hub.messageHistory.length,
                      itemBuilder: (context, i) {
                        final msg = _hub
                            .messageHistory[_hub.messageHistory.length - 1 - i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Text(
                            '[${msg.type.name}] ${msg.from} → '
                            '${msg.to ?? "all"}: ${msg.payload}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.toOpacity(0.6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: Text("Clear History".tl),
                      onPressed: () {
                        _hub.clearHistory();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),

          // 黑名单
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Blacklist".tl,
                  icon: Icons.block_outlined,
                ),
                _SettingRow(
                  title: "${_hub.blacklistCount} ${"banned".tl}",
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _showBlacklistSheet(context),
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

// ═══════════════════════════════════════════════════════════════════════════
//  _HubClientDetailPage
// ═══════════════════════════════════════════════════════════════════════════

class _HubClientDetailPage extends StatefulWidget {
  const _HubClientDetailPage();

  @override
  State<_HubClientDetailPage> createState() => _HubClientDetailPageState();
}

class _HubClientDetailPageState extends State<_HubClientDetailPage> {
  final _hubClient = HubClient();

  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _tokenController;
  bool _tokenObscured = true;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _hubClient.onClientsChanged = null;
    super.dispose();
  }

  bool get _isConnected => _hubClient.isConnected;

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

    await _showFormDialog(
      context: context,
      title: "Edit Profile".tl,
      confirmLabel: "Save".tl,
      fields: [
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: "Name".tl),
        ),
        TextField(
          controller: avatarCtrl,
          decoration: InputDecoration(
            labelText: "Avatar URL".tl,
            hintText: 'https://...',
          ),
        ),
        TextField(
          controller: bioCtrl,
          decoration: InputDecoration(labelText: "Bio".tl),
          maxLines: 2,
        ),
      ],
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        final bio = bioCtrl.text.trim();
        final avatar = avatarCtrl.text.trim();
        if (name.isNotEmpty) _hubClient.saveName(name);
        if (bio.isNotEmpty) _hubClient.saveBio(bio);
        if (avatar.isNotEmpty) _hubClient.saveAvatar(avatar);
        if (_hubClient.isConnected) {
          _hubClient.updateProfile(
            name: name.isNotEmpty ? name : null,
            bio: bio.isNotEmpty ? bio : null,
            avatar: avatar.isNotEmpty ? avatar : null,
          );
        }
        setState(() {});
        return null;
      },
    );
  }

  // ── 房间列表 ──────────────────────────────────────────────────────────────

  void _showJoinRoomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) {
          _hubClient.onRoomListChanged = () {
            if (context.mounted) setSS(() {});
          };

          final canCreate =
              _hubClient.isGlobalAdmin ||
              !_hubClient.roomList.any((r) => r['ownerId'] == _hubClient.myId);

          return _DraggableSheet(
            title: "Rooms".tl,
            icon: Icons.meeting_room_outlined,
            headerTrailing: canCreate
                ? TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text("Create".tl),
                    onPressed: () async {
                      await _showClientCreateRoomDialog(context);
                      setSS(() {});
                    },
                  )
                : null,
            footer:
                _hubClient.currentRoomId != null &&
                    _hubClient.currentRoomId != _hubClient.lobbyRoomId
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout, size: 16),
                      label: Text("Leave Room".tl),
                      onPressed: () {
                        _hubClient.leaveRoom();
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                  )
                : null,
            builder: (context, sc) {
              final rooms = _hubClient.roomList;
              if (rooms.isEmpty) {
                return Center(child: Text("No rooms".tl));
              }
              return ListView.builder(
                controller: sc,
                itemCount: rooms.length,
                itemBuilder: (context, i) {
                  final room = rooms[i];
                  final isCurrent = room['id'] == _hubClient.currentRoomId;
                  final isLobby = room['id'] == _hubClient.lobbyRoomId;
                  final canManage =
                      !isLobby &&
                      (_hubClient.isGlobalAdmin ||
                          _hubClient.isRoomAdminOf(room['id'] as String?));

                  return ListTile(
                    leading: Icon(
                      room['isLocked'] == true
                          ? Icons.lock_outlined
                          : Icons.meeting_room_outlined,
                    ),
                    title: Text(room['name'] as String? ?? ''),
                    subtitle: Text(
                      '${room['memberCount'] ?? 0} ${"members".tl}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canManage)
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 18),
                            tooltip: "Room Settings".tl,
                            onPressed: () =>
                                _showClientRoomSettingsSheet(context, room),
                          ),
                        if (isCurrent)
                          Text(
                            "Current".tl,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          )
                        else ...[
                          if (!isLobby && room['ownerId'] == _hubClient.myId)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: "Delete Room".tl,
                              onPressed: () {
                                _hubClient.deleteRoom(room['id'] as String);
                                setSS(() {});
                              },
                            ),
                          TextButton(
                            child: Text("Join".tl),
                            onPressed: () async {
                              if (room['isLocked'] == true) {
                                final pwd = await _showPasswordDialog(context);
                                if (pwd == null) return;
                                _hubClient.joinRoom(room['id'], password: pwd);
                              } else {
                                _hubClient.joinRoom(room['id']);
                              }
                              if (context.mounted) Navigator.pop(context);
                              setState(() {});
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
    final nameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await _showFormDialog(
      context: context,
      title: "Create Room".tl,
      confirmLabel: "Create".tl,
      fields: [
        TextField(
          controller: nameCtrl,
          decoration: InputDecoration(labelText: "Room Name".tl),
        ),
        TextField(
          controller: passwordCtrl,
          decoration: InputDecoration(
            labelText: "Password".tl,
            hintText: "Leave empty for public".tl,
          ),
        ),
      ],
      onConfirm: () async {
        final name = nameCtrl.text.trim();
        if (name.isEmpty) return null;
        _hubClient.createRoom(
          name,
          password: passwordCtrl.text.trim().isEmpty
              ? null
              : passwordCtrl.text.trim(),
        );
        setState(() {});
        return null;
      },
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Room Password".tl),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: "Password".tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel".tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text("OK".tl),
          ),
        ],
      ),
    );
  }

  // ── 房间设置 ──────────────────────────────────────────────────────────────

  void _showClientRoomSettingsSheet(
    BuildContext context,
    Map<String, dynamic> room,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) {
          final isGlobalAdmin = _hubClient.isGlobalAdmin;
          final isRoomAdmin = _hubClient.isRoomAdminOf(room['id'] as String?);

          return _DraggableSheet(
            title: room['name'] as String? ?? '',
            icon: Icons.settings_outlined,
            initialSize: 0.7,
            maxSize: 0.95,
            builder: (context, sc) => ListView(
              controller: sc,
              children: [
                // ── 公告 ──
                _SettingPartTitle(
                  title: "Announcement".tl,
                  icon: Icons.campaign_outlined,
                ),
                ListTile(
                  title: Text(
                    (room['announcement'] as String?)?.isNotEmpty == true
                        ? room['announcement'] as String
                        : "No announcement".tl,
                    style: TextStyle(
                      color:
                          (room['announcement'] as String?)?.isNotEmpty == true
                          ? null
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.toOpacity(0.4),
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    final ctrl = TextEditingController(
                      text: room['announcement'] as String? ?? '',
                    );
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("Set Announcement".tl),
                        content: TextField(
                          controller: ctrl,
                          maxLines: 3,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: "Enter announcement...".tl,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel".tl),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, ctrl.text),
                            child: Text("Save".tl),
                          ),
                        ],
                      ),
                    );
                    if (result != null) {
                      _hubClient.setAnnouncement(result);
                      setSS(() => room['announcement'] = result);
                    }
                  },
                ),

                // ── 房间管理员（全局管理员可见）──
                if (isGlobalAdmin) ...[
                  _SettingPartTitle(
                    title: "Room Admins".tl,
                    icon: Icons.manage_accounts_outlined,
                  ),
                  ..._hubClient.currentRoomClients
                      .where((c) {
                        final adminIds = room['adminIds'] as List?;
                        return adminIds?.contains(c['id']) == true;
                      })
                      .map(
                        (c) => _ClientTile(
                          name: c['name'] as String? ?? c['id'] as String,
                          avatarUrl: c['avatar'] as String?,
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 18,
                            ),
                            tooltip: "Remove Admin".tl,
                            onPressed: () {
                              _hubClient.setRoomAdmin(
                                c['id'] as String,
                                value: false,
                              );
                              setSS(
                                () => (room['adminIds'] as List?)?.remove(
                                  c['id'],
                                ),
                              );
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                  ListTile(
                    leading: const Icon(Icons.add, size: 18),
                    title: Text("Add Room Admin".tl),
                    onTap: () => _showPickMemberDialog(
                      context,
                      room,
                      setSS,
                      isAdminPicker: true,
                    ),
                  ),
                ],

                // ── 房间封禁（全局/房间管理员可见）──
                if (isGlobalAdmin || isRoomAdmin) ...[
                  _SettingPartTitle(
                    title: "Room Bans".tl,
                    icon: Icons.block_outlined,
                  ),
                  if ((room['bannedIds'] as List?)?.isEmpty != false)
                    _EmptyHint("No banned users".tl),
                  ...((room['bannedIds'] as List?) ?? []).map((id) {
                    final banned = _hubClient.onlineClients.firstWhereOrNull(
                      (c) => c['id'] == id,
                    );
                    return _ClientTile(
                      name: banned?['name'] as String? ?? id as String,
                      avatarUrl: banned?['avatar'] as String?,
                      trailing: IconButton(
                        icon: const Icon(Icons.lock_open_outlined, size: 18),
                        tooltip: "Unban".tl,
                        onPressed: () {
                          _hubClient.roomUnban(id as String);
                          setSS(() => (room['bannedIds'] as List?)?.remove(id));
                          setState(() {});
                        },
                      ),
                    );
                  }),
                  ListTile(
                    leading: const Icon(Icons.person_off_outlined, size: 18),
                    title: Text("Ban Member".tl),
                    onTap: () => _showPickMemberDialog(
                      context,
                      room,
                      setSS,
                      isAdminPicker: false,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPickMemberDialog(
    BuildContext context,
    Map<String, dynamic> room,
    StateSetter setSS, {
    required bool isAdminPicker,
  }) {
    final adminIds = (room['adminIds'] as List?) ?? [];
    final members =
        (room['members'] as List?)
            ?.map((m) => m as Map<String, dynamic>)
            .toList() ??
        [];
    final available = members
        .where(
          (c) =>
              c['id'] != _hubClient.myId &&
              c['id'] != room['ownerId'] &&
              (isAdminPicker ? !adminIds.contains(c['id']) : true),
        )
        .toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAdminPicker ? "Add Room Admin".tl : "Ban Member".tl),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: available
                .map(
                  (c) => _ClientTile(
                    name: c['name'] as String? ?? c['id'] as String,
                    avatarUrl: c['avatar'] as String?,
                    onTap: () {
                      Navigator.pop(context);
                      if (isAdminPicker) {
                        _hubClient.setRoomAdmin(c['id'] as String, value: true);
                        setSS(() => (room['adminIds'] as List?)?.add(c['id']));
                      } else {
                        _hubClient.roomBan(c['id'] as String);
                        setSS(() => (room['bannedIds'] as List?)?.add(c['id']));
                      }
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel".tl),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopUpWidgetScaffold(
      title: "Hub Details".tl,
      body: CustomScrollView(
        slivers: [
          // ── 服务器地址 ──
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Server Address".tl,
                  icon: Icons.dns_outlined,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 预览 URL
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
                              label: "Host".tl,
                              child: _HostInput(
                                controller: _hostController,
                                enabled: !_isConnected,
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
                              label: "Port".tl,
                              child: _PortInput(
                                controller: _portController,
                                enabled: !_isConnected,
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
                  title: "Authentication".tl,
                  icon: Icons.key_outlined,
                ),
                _SettingRow(
                  title: "Hub Token".tl,
                  subtitle: "Token from the hub server".tl,
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
                        tooltip: _tokenObscured ? "Show".tl : "Hide".tl,
                        onPressed: () =>
                            setState(() => _tokenObscured = !_tokenObscured),
                      ),
                      if (_tokenController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          tooltip: "Copy".tl,
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _tokenController.text),
                            );
                            App.rootContext.showMessage(message: "Copied".tl);
                          },
                        ),
                      if (!_isConnected)
                        _tokenController.text.isEmpty
                            ? IconButton(
                                icon: const Icon(Icons.content_paste, size: 18),
                                tooltip: "Paste".tl,
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
                                tooltip: "Clear".tl,
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
                    enabled: !_isConnected,
                    obscureText: _tokenObscured,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Paste hub server token'.tl,
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

          // ── 资料 & 房间（已连接）──
          if (_isConnected)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: "Profile & Room".tl,
                    icon: Icons.person_outline,
                  ),
                  _SettingRow(
                    title: "Profile".tl,
                    subtitle: _hubClient.savedName ?? "Not set".tl,
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => _showEditProfileDialog(context),
                    ),
                  ),
                  _SettingRow(
                    title: "Current Room".tl,
                    subtitle: _hubClient.currentRoomName ?? "Lobby".tl,
                    trailing: IconButton(
                      icon: const Icon(Icons.meeting_room_outlined, size: 18),
                      onPressed: () => _showJoinRoomSheet(context),
                    ),
                  ),
                ],
              ),
            ),

          // ── 在线客户端（已连接）──
          if (_isConnected && _hubClient.onlineClients.isNotEmpty)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: "Online Clients".tl,
                    icon: Icons.people_outline,
                  ),
                  ..._hubClient.currentRoomClients.map(
                    (client) => _OnlineClientTile(
                      client: client,
                      myId: _hubClient.myId,
                      isBlocked: _hubClient.isBlocked(client['id'] as String),
                      canManage:
                          _hubClient.isGlobalAdmin ||
                          _hubClient.isRoomAdminOf(_hubClient.currentRoomId),
                      onBlock: () {
                        final id = client['id'] as String;
                        _hubClient.isBlocked(id)
                            ? _hubClient.unblockUser(id)
                            : _hubClient.blockUser(id);
                        setState(() {});
                      },
                      onMute: (seconds) {
                        if (seconds == 0 || client['isMuted'] == true) {
                          _hubClient.unmute(client['id'] as String);
                        } else {
                          _hubClient.mute(
                            client['id'] as String,
                            seconds: seconds,
                          );
                        }
                        setState(() {});
                      },
                      onKick: () {
                        _hubClient.kickFromRoom(client['id'] as String);
                        setState(() {});
                      },
                      // 全局管理员可操作服务端黑名单
                      onBlacklist: _hubClient.isGlobalAdmin
                          ? () {
                              if (client['isServerBanned'] == true) {
                                _hubClient.serverUnban(client['id'] as String);
                              } else {
                                _hubClient.serverBan(client['id'] as String);
                              }
                              setState(() {});
                            }
                          : null,
                      isBlacklisted: client['isServerBanned'] == true,
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

// ── 小工具：带标签的输入框列 ──────────────────────────────────────────────────
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.toOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _OnlineClientTile extends StatelessWidget {
  const _OnlineClientTile({
    required this.client,
    required this.myId,
    required this.isBlocked,
    required this.canManage,
    required this.onBlock,
    required this.onMute,
    required this.onKick,
    this.onBlacklist,
    this.isBlacklisted,
    this.onSetAdmin,
    this.isAdmin,
  });

  final Map<String, dynamic> client;
  final String? myId;
  final bool isBlocked;
  final bool canManage;
  final VoidCallback onBlock;
  final ValueChanged<int> onMute; // ← 改为 ValueChanged<int>
  final VoidCallback onKick;
  final VoidCallback? onBlacklist;
  final bool? isBlacklisted;
  final VoidCallback? onSetAdmin;
  final bool? isAdmin;

  void _showMuteSheet(BuildContext context) {
    final isMuted = client['isMuted'] == true;
    if (isMuted) {
      onMute(0); // 0 表示解除禁言，调用方判断
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => _MuteSheet(
        clientName: client['name'] as String? ?? '',
        onMute: (seconds) {
          Navigator.pop(context);
          onMute(seconds);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = client['isMuted'] == true;
    final isMe = client['id'] == myId;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading:
          client['avatar'] != null && (client['avatar'] as String).isNotEmpty
          ? CircleAvatar(
              backgroundImage: NetworkImage(client['avatar'] as String),
              radius: 16,
            )
          : CircleAvatar(
              radius: 16,
              child: Text((client['name'] as String? ?? 'U')[0].toUpperCase()),
            ),
      title: Text(
        '${client['name'] ?? client['id']}'
        '${client['isGlobalAdmin'] == true ? "  👑" : ""}'
        '${isMuted ? "  🔇" : ""}',
      ),
      subtitle: Text(
        client['bio'] != null && (client['bio'] as String).isNotEmpty
            ? client['bio'] as String
            : client['status'] ?? 'online',
      ),
      trailing: isMe
          ? Text("Me".tl, style: TextStyle(color: cs.primary, fontSize: 12))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (myId != null) // 仅客户端视角显示本地屏蔽
                  IconButton(
                    icon: Icon(
                      isBlocked ? Icons.volume_off : Icons.volume_off_outlined,
                      size: 18,
                      color: isBlocked ? cs.error : null,
                    ),
                    tooltip: isBlocked ? "Unblock".tl : "Block".tl,
                    onPressed: onBlock,
                  ),
                if (canManage) ...[
                  IconButton(
                    icon: Icon(
                      isMuted ? Icons.mic : Icons.mic_off,
                      size: 18,
                      color: isMuted ? cs.error : null,
                    ),
                    tooltip: isMuted ? "Unmute".tl : "Mute".tl,
                    onPressed: () => _showMuteSheet(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18),
                    tooltip: "Kick".tl,
                    onPressed: onKick,
                  ),
                ],
                if (onSetAdmin != null)
                  IconButton(
                    icon: Icon(
                      isAdmin == true ? Icons.shield : Icons.shield_outlined,
                      size: 18,
                      color: isAdmin == true ? cs.primary : null,
                    ),
                    tooltip: isAdmin == true
                        ? "Remove Global Admin".tl
                        : "Set Global Admin".tl,
                    onPressed: onSetAdmin,
                  ),
                if (onBlacklist != null)
                  IconButton(
                    icon: Icon(
                      isBlacklisted == true
                          ? Icons.block
                          : Icons.block_outlined,
                      size: 18,
                      color: isBlacklisted == true ? cs.error : null,
                    ),
                    tooltip: isBlacklisted == true
                        ? "Remove from Blacklist".tl
                        : "Add to Blacklist".tl,
                    onPressed: onBlacklist,
                  ),
              ],
            ),
    );
  }
}

// ── _MuteSheet ────────────────────────────────────────────────────────────────

class _MuteSheet extends StatefulWidget {
  const _MuteSheet({required this.clientName, required this.onMute});

  final String clientName;
  final ValueChanged<int> onMute;

  @override
  State<_MuteSheet> createState() => _MuteSheetState();
}

class _MuteSheetState extends State<_MuteSheet> {
  static const _presets = [
    (label: '1 min', seconds: 60),
    (label: '5 min', seconds: 300),
    (label: '10 min', seconds: 600),
    (label: '30 min', seconds: 1800),
    (label: '1 hour', seconds: 3600),
    (label: '24 hour', seconds: 86400),
  ];

  final _controller = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.mic_off_outlined, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${"Mute".tl}  ${widget.clientName}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presets.map(
                  (p) => ActionChip(
                    label: Text(p.label),
                    onPressed: () => widget.onMute(p.seconds),
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  label: Text("Custom".tl, style: TextStyle(color: cs.primary)),
                  onPressed: () => setState(() => _showCustom = !_showCustom),
                ),
              ],
            ),
          ),
          if (_showCustom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Seconds".tl,
                        suffixText: "s",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final s = int.tryParse(_controller.text);
                      if (s != null && s > 0) widget.onMute(s);
                    },
                    child: Text("Confirm".tl),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PortInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _PortInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.toOpacity(0.35),
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: colorScheme.primary.toOpacity(0.6),
              width: 1.5,
            ),
          ),
        ),
        onChanged: (v) {
          final port = int.tryParse(v);
          if (port != null && port >= 1024 && port <= 65535) {
            onChanged(port);
          }
        },
      ),
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({required this.keyManager, required this.onRegenerate});

  final ApiKeyManager keyManager;
  final VoidCallback onRegenerate;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text("Active Key".tl),
      subtitle: Text(
        _obscured ? '••••••••••••••••' : widget.keyManager.activeKey,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _obscured ? Icons.visibility_off : Icons.visibility,
              size: 18,
            ),
            tooltip: _obscured ? "Show".tl : "Hide".tl,
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: "Copy".tl,
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: widget.keyManager.activeKey),
              );
              App.rootContext.showMessage(message: "Copied".tl);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: "Regenerate".tl,
            onPressed: widget.onRegenerate,
          ),
        ],
      ),
    );
  }
}

class _HubTokenInput extends StatefulWidget {
  const _HubTokenInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onChanged;

  @override
  State<_HubTokenInput> createState() => _HubTokenInputState();
}

class _HubTokenInputState extends State<_HubTokenInput> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Paste hub server token'.tl,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: widget.enabled
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.controller.text.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.content_paste, size: 16),
                        tooltip: "Paste".tl,
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final text = data?.text?.trim() ?? '';
                          if (text.isNotEmpty) {
                            widget.controller.text = text;
                            widget.onChanged(text);
                            setState(() {});
                          }
                        },
                      ),
                    if (widget.controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        tooltip: "Clear".tl,
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                          setState(() {});
                        },
                      ),
                  ],
                ),
        ),
        onChanged: (v) {
          widget.onChanged(v.trim());
          setState(() {});
        },
      ),
    );
  }
}

class _HostInput extends StatelessWidget {
  const _HostInput({
    required this.controller,
    required this.enabled,
    this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: enabled
            ? colorScheme.onSurface
            : colorScheme.onSurface.toOpacity(0.35),
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surface,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary.toOpacity(0.6),
            width: 1.5,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
