part of 'settings_page.dart';

class ServiceSettings extends StatefulWidget {
  const ServiceSettings({super.key});

  @override
  State<ServiceSettings> createState() => _ServiceSettingsState();
}

class _ServiceSettingsState extends State<ServiceSettings> {
  final _service = AppService();
  final _keyManager = ApiKeyManager();
  final _hub = HubService();
  final _hubClient = HubClient();

  bool _serviceEnabled = false;
  bool _hubEnabled = false;
  bool _hubClientEnabled = false;
  BindMode _bindMode = BindMode.ipv4;
  StateSetter? _joinRoomSheetState;

  final _portController = TextEditingController(text: '9000');
  final _hubPortController = TextEditingController(text: '9100');
  final _hubAddressController = TextEditingController(); // 客户端连接地址
  final _fixedKeyController = TextEditingController();
  final _hubClientNameController = TextEditingController();
  final _hubTokenController = TextEditingController();

  bool _keyManagerReady = false;

  @override
  void initState() {
    super.initState();
    _bindMode = _service.savedBindMode;
    _portController.text = _service.savedPort.toString();
    _hubPortController.text = _hub.savedPort.toString();
    _hubAddressController.text = _hubClient.savedAddress ?? '';
    _hubClientNameController.text = _hubClient.savedName ?? '';
    _hubTokenController.text = _hubClient.savedToken ?? '';
    _initKeyManager();
  }

  @override
  void dispose() {
    _portController.dispose();
    _hubPortController.dispose();
    _hubAddressController.dispose();
    _fixedKeyController.dispose();
    _hubClientNameController.dispose();
    _hubTokenController.dispose();
    super.dispose();
  }

  Future<void> _initKeyManager() async {
    _fixedKeyController.text = _keyManager.fixedKey ?? '';
    _serviceEnabled = _service.isRunning;
    _hubEnabled = _hub.isRunning;
    _hubClientEnabled = _hubClient.isConnected;

    _hubClient.onConnected = () {
      if (mounted) setState(() => _hubClientEnabled = true);
    };

    _hubClient.onDisconnected = () {
      if (mounted) {
        setState(() => _hubClientEnabled = false);
        // ← 只要断开就提示
        if (_hubClientEnabled) {
          App.rootContext.showMessage(message: '与服务端的连接已断开'.tl);
        }
      }
    };

    _hub.onMessageReceived = () {
      if (mounted) setState(() {});
    };

    _hubClient.onMessage = (data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      final event = data['payload']?['event'] as String?;

      if (type == 'kicked') {
        App.rootContext.showMessage(message: '已被服务端踢出'.tl);
        setState(() => _hubClientEnabled = false);
        return;
      }

      if (type == 'error') {
        App.rootContext.showMessage(
          message: data['message'] as String? ?? 'Error'.tl,
        );
        return;
      }

      if (type == 'system') {
        switch (event) {
          case 'server_shutdown':
            App.rootContext.showMessage(message: '服务端已关闭'.tl);
            setState(() => _hubClientEnabled = false);

          case 'you_are_muted':
            final seconds = data['payload']['seconds'];
            App.rootContext.showMessage(message: '你已被禁言 $seconds 秒'.tl);

          case 'you_are_unmuted':
            App.rootContext.showMessage(message: '你已被解除禁言'.tl);

          case 'you_are_room_banned':
            final roomName = data['payload']['roomName'] ?? '';
            App.rootContext.showMessage(message: '你已被禁止进入房间：$roomName');
            setState(() {});

          case 'you_are_room_unbanned':
            final roomName = data['payload']['roomName'] ?? '';
            App.rootContext.showMessage(message: '你已可以重新进入房间：$roomName');
            setState(() {});

          case 'kicked_from_room':
            App.rootContext.showMessage(message: '你已被踢出房间'.tl);
            setState(() {});

          case 'client_kicked_from_room':
            setState(() {});

          case 'room_ban_updated':
            setState(() {});

          case 'message_recalled':
            setState(() {});

          case 'reaction_updated':
            setState(() {});

          case 'message_pinned':
            setState(() {});

          case 'client_joined':
            final name = data['payload']['client']?['name'] ?? '';
            App.rootContext.showMessage(message: '$name ${"joined".tl}');
            setState(() {});

          case 'client_left':
            final name = data['payload']['clientName'] ?? '';
            App.rootContext.showMessage(message: '$name ${"left".tl}');
            setState(() {});

          case 'client_joined_room':
            setState(() {});

          case 'client_left_room':
            setState(() {});

          case 'room_created':
            final name = data['payload']['room']?['name'] ?? '';
            App.rootContext.showMessage(message: '${"New room".tl}: $name');
            setState(() {});
            _joinRoomSheetState?.call(() {});

          case 'room_deleted':
            App.rootContext.showMessage(message: '所在房间已被删除，已回到大厅'.tl);
            setState(() {});
            _joinRoomSheetState?.call(() {});

          case 'announcement_updated':
            final msg = data['payload']['announcement'] ?? '';
            if (msg.isNotEmpty) {
              App.rootContext.showMessage(message: '📢 $msg');
            }
            setState(() {});

          case 'global_admin_changed':
            if (data['payload']['clientId'] == _hubClient.myId) {
              final isAdmin = data['payload']['isGlobalAdmin'] == true;
              App.rootContext.showMessage(
                message: isAdmin ? '你已成为全局管理员'.tl : '你的全局管理员权限已被撤销'.tl,
              );
            }
            setState(() {});

          case 'room_admin_changed':
            if (data['payload']['clientId'] == _hubClient.myId) {
              final isAdmin = data['payload']['isRoomAdmin'] == true;
              App.rootContext.showMessage(
                message: isAdmin ? '你已成为房间管理员'.tl : '你的房间管理员权限已被撤销'.tl,
              );
            }
            setState(() {});

          case 'status_changed':
          case 'profile_updated':
          case 'user_muted':
          case 'user_unmuted':
          case 'admin_changed':
            setState(() {});
        }
      }

      if (type == 'broadcast' || type == 'unicast' || type == 'room_joined') {
        setState(() {});
      }
    };

    if (mounted) setState(() => _keyManagerReady = true);
  }

  Future<void> _toggleService(bool value) async {
    if (value) {
      final port = int.tryParse(_portController.text) ?? 9000;
      await _service.init(preferredPort: port, mode: _bindMode);
    } else {
      await _service.dispose();
    }
    setState(() => _serviceEnabled = _service.isRunning);
  }

  Future<void> _toggleHub(bool value) async {
    if (value) {
      final port = int.tryParse(_hubPortController.text) ?? 9100;
      await _hub.init(preferredPort: port, mode: _bindMode);
    } else {
      await _hub.dispose();
    }
    setState(() => _hubEnabled = _hub.isRunning);
  }

  Future<void> _toggleHubClient(bool value) async {
    if (value) {
      final address = _hubAddressController.text.trim();
      if (address.isEmpty) {
        App.rootContext.showMessage(message: '请输入服务端地址'.tl);
        return;
      }
      try {
        await _hubClient.connect(
          address,
          _hubClient.savedToken ?? '',
          name: _hubClientNameController.text.trim(),
        );
      } catch (e) {
        if (mounted) {
          App.rootContext.showMessage(message: '连接失败：$e'.tl);
        }
        return;
      }
    } else {
      await _hubClient.disconnect();
    }
    if (mounted) setState(() => _hubClientEnabled = _hubClient.isConnected);
  }

  void _showRoomsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          "Rooms".tl,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        // 创建房间按钮
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: Text("Create".tl),
                          onPressed: () async {
                            await _showCreateRoomDialog(context);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 房间列表
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _hub.rooms.length,
                      itemBuilder: (context, i) {
                        final room = _hub.rooms[i];
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 房间管理员管理
                              IconButton(
                                icon: const Icon(
                                  Icons.manage_accounts_outlined,
                                  size: 18,
                                ),
                                tooltip: "Room Admins".tl,
                                onPressed: () => _showRoomAdminSheet(
                                  context,
                                  room,
                                  setSheetState,
                                ),
                              ),
                              // 删除房间（大厅不能删）
                              if (room.id != _hub.lobbyId)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  tooltip: "Delete Room".tl,
                                  onPressed: () async {
                                    await _hub.deleteRoom(room.id);
                                    setSheetState(() {});
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateRoomDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final announcementController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Create Room".tl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Room Name".tl),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password".tl,
                hintText: "Leave empty for public".tl,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: announcementController,
              decoration: InputDecoration(labelText: "Announcement".tl),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel".tl),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await _hub.createRoom(
                name,
                password: passwordController.text.trim().isEmpty
                    ? null
                    : passwordController.text.trim(),
                announcement: announcementController.text.trim().isEmpty
                    ? null
                    : announcementController.text.trim(),
              );
              if (context.mounted) Navigator.pop(context);
              setState(() {});
            },
            child: Text("Create".tl),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context) async {
    final nameController = TextEditingController(text: _hubClient.savedName);
    final bioController = TextEditingController(text: _hubClient.savedBio);
    final avatarController = TextEditingController(
      text: _hubClient.savedAvatar,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit Profile".tl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Name".tl),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: avatarController,
              decoration: InputDecoration(
                labelText: "Avatar URL".tl,
                hintText: "https://...",
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: bioController,
              decoration: InputDecoration(labelText: "Bio".tl),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel".tl),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final bio = bioController.text.trim();
              final avatar = avatarController.text.trim();
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
              if (context.mounted) Navigator.pop(context);
              setState(() {});
            },
            child: Text("Save".tl),
          ),
        ],
      ),
    );
  }

  void _showRoomAdminSheet(
    BuildContext context,
    HubRoom room,
    StateSetter setSheetState,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setAdminState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "${"Room Admins".tl} · ${room.name}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: _hub.clients.map((client) {
                    final isAdmin = room.isAdmin(client.id);
                    return ListTile(
                      leading: Icon(
                        isAdmin ? Icons.manage_accounts : Icons.person_outline,
                        color: isAdmin
                            ? Theme.of(context).colorScheme.secondary
                            : null,
                      ),
                      title: Text(client.name ?? client.id),
                      trailing: Switch(
                        value: isAdmin,
                        onChanged: (val) async {
                          await _hub.setClientRoomAdmin(
                            client.id,
                            room.id,
                            val,
                          );
                          setAdminState(() {});
                          setSheetState(() {});
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinRoomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          _joinRoomSheetState = setSheetState; // ← 保存
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) {
              final rooms = _hubClient.roomList;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          "Rooms".tl,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        // 全局管理员不限制，普通用户只能创建一个
                        if (_hubClient.isGlobalAdmin ||
                            !_hubClient.roomList.any(
                              (r) => r['ownerId'] == _hubClient.myId,
                            ))
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: Text("Create".tl),
                            onPressed: () async {
                              await _showClientCreateRoomDialog(context);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: rooms.isEmpty
                        ? Center(child: Text("No rooms".tl))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: rooms.length,
                            itemBuilder: (context, i) {
                              final room = rooms[i];
                              final isCurrent =
                                  room['id'] == _hubClient.currentRoomId;
                              return ListTile(
                                leading: Icon(
                                  room['isLocked'] == true
                                      ? Icons.lock_outlined
                                      : Icons.meeting_room_outlined,
                                ),
                                title: Text(room['name'] ?? ''),
                                subtitle: Text(
                                  '${room['memberCount'] ?? 0} ${"members".tl}',
                                  // ← 去掉公告显示
                                ),
                                trailing: isCurrent
                                    ? Text(
                                        "Current".tl,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (room['ownerId'] ==
                                              _hubClient.myId)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                              ),
                                              tooltip: "Delete Room".tl,
                                              onPressed: () {
                                                _hubClient.deleteRoom(
                                                  room['id'] as String,
                                                );
                                                setSheetState(() {});
                                              },
                                            ),
                                          TextButton(
                                            child: Text("Join".tl),
                                            onPressed: () async {
                                              if (room['isLocked'] == true) {
                                                final pwd =
                                                    await _showPasswordDialog(
                                                      context,
                                                    );
                                                if (pwd == null) return;
                                                _hubClient.joinRoom(
                                                  room['id'],
                                                  password: pwd,
                                                );
                                              } else {
                                                _hubClient.joinRoom(room['id']);
                                              }
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                              }
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                              );
                            },
                          ),
                  ),
                  if (_hubClient.currentRoomId != null &&
                      _hubClient.currentRoomId != _hubClient.lobbyRoomId)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextButton.icon(
                        icon: const Icon(Icons.logout, size: 16),
                        label: Text("Leave Room".tl),
                        onPressed: () {
                          _hubClient.leaveRoom();
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ).whenComplete(() => _joinRoomSheetState = null); // ← 关闭时清空
  }

  Future<void> _showClientCreateRoomDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Create Room".tl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: "Room Name".tl),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password".tl,
                hintText: "Leave empty for public".tl,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel".tl),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              _hubClient.createRoom(
                name,
                password: passwordController.text.trim().isEmpty
                    ? null
                    : passwordController.text.trim(),
              );
              Navigator.pop(context);
              setState(() {});
            },
            child: Text("Create".tl),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Room Password".tl),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: "Password".tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text("Cancel".tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text("OK".tl),
          ),
        ],
      ),
    );
  }

  void _showBlacklistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "Blacklist".tl,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              if (_hub.blacklist.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text("No banned users".tl),
                )
              else
                ..._hub.blacklist.map(
                  (id) => ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: Text(id),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () {
                        _hub.removeFromBlacklist(id);
                        setSheetState(() {});
                        setState(() {});
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_keyManagerReady) {
      return const Scaffold(body: Center(child: PolygonRefreshIndicator()));
    }

    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Service Settings".tl)),

        // ── AppService ──────────────────────────────────
        _buildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: "Service".tl,
                icon: Icons.miscellaneous_services_outlined,
              ),
              const SizedBox(height: 8),
              _SettingRow(
                title: "Enable Service".tl,
                subtitle: _serviceEnabled
                    ? "${"Running on".tl} ${_service.boundAddresses.join(' | ')}"
                    : "Service is stopped".tl,
                trailing: CustomSwitch(
                  value: _serviceEnabled,
                  onChanged: _toggleService,
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                title: "Port".tl,
                subtitle: "Default: @p".tlParams({"p": "9000  (1024 - 65535)"}),
                trailing: _PortInput(
                  controller: _portController,
                  enabled: !_serviceEnabled,
                  onChanged: (port) => _service.savePort(port),
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                title: "Bind Mode".tl,
                subtitle: "Choose IP version to listen on".tl,
                trailing: _BindModeSelector(
                  value: _bindMode,
                  enabled: !_serviceEnabled,
                  onChanged: (mode) {
                    setState(() => _bindMode = mode);
                    _service.saveBindMode(mode);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── API Key ─────────────────────────────────────
        _buildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(title: "API Key".tl, icon: Icons.key_outlined),
              const SizedBox(height: 8),
              _SettingRow(
                title: "Active Key".tl,
                subtitle: _keyManager.isUsingFixed
                    ? "Using fixed key".tl
                    : "Using random key (regenerated on startup)".tl,
                trailing: _KeyDisplay(keyValue: _keyManager.activeKey),
              ),
              const Divider(height: 1),
              _SettingRow(
                title: "Use Fixed Key".tl,
                subtitle: "Keep the same key after restart".tl,
                trailing: CustomSwitch(
                  value: _keyManager.isUsingFixed,
                  onChanged: (val) async {
                    await _keyManager.setUseFixed(val);
                    setState(() {});
                  },
                ),
              ),
              if (_keyManager.isUsingFixed) ...[
                const Divider(height: 1),
                _SettingRow(
                  title: "Fixed Key".tl,
                  subtitle: "Leave empty to auto-generate".tl,
                  trailing: SizedBox(
                    width: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fixedKeyController,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Enter fixed key'.tl,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, size: 18),
                          onPressed: () async {
                            final error = await _keyManager.setFixedKey(
                              _fixedKeyController.text.trim(),
                            );
                            if (error != null && mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(error)));
                            } else {
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Divider(height: 1),
              _SettingRow(
                title: "Regenerate Random Key".tl,
                subtitle: "Generate a new random key immediately".tl,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text("Regenerate".tl),
                  onPressed: () {
                    _keyManager.regenerateRandomKey();
                    setState(() {});
                  },
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                title: "Save as Fixed Key".tl,
                subtitle: "Save current random key as fixed key".tl,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.push_pin_outlined, size: 16),
                  label: Text("Save".tl),
                  onPressed: () async {
                    final error = await _keyManager.setFixedKey(
                      _keyManager.randomKey ?? '',
                    );
                    if (error != null && mounted) {
                      App.rootContext.showMessage(message: error);
                    } else {
                      await _keyManager.setUseFixed(true);
                      _fixedKeyController.text = _keyManager.fixedKey ?? '';
                      setState(() {});
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Hub 服务端 ───────────────────────────────────
        _buildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: "Hub Server".tl,
                icon: Icons.hub_outlined,
              ),
              const SizedBox(height: 8),
              _SettingRow(
                title: "Enable Hub".tl,
                subtitle: _hubEnabled
                    ? "${"Running on".tl} ${_hub.boundAddresses.join(' | ')}  "
                          "(${_hub.clientCount} ${"clients".tl})"
                    : "Hub server is stopped".tl,
                trailing: CustomSwitch(
                  value: _hubEnabled,
                  onChanged: _toggleHub,
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                title: "Hub Port".tl,
                subtitle: "Default: @p".tlParams({"p": "9100  (1024 - 65535)"}),
                trailing: _PortInput(
                  controller: _hubPortController,
                  enabled: !_hubEnabled,
                  onChanged: (port) => _hub.savePort(port),
                ),
              ),

              // 在 Hub Server 区块里加
              if (_hubEnabled) ...[
                const Divider(height: 1),
                _SettingRow(
                  title: "Rooms".tl,
                  subtitle: "${_hub.rooms.length} ${"rooms".tl}",
                  trailing: IconButton(
                    icon: const Icon(Icons.meeting_room_outlined, size: 18),
                    onPressed: () => _showRoomsSheet(context),
                  ),
                ),
              ],

              // 在线客户端列表
              if (_hubEnabled && _hub.clientCount > 0) ...[
                const Divider(height: 1),
                _SettingPartTitle(
                  title: "Online Clients".tl,
                  icon: Icons.people_outline,
                ),
                ..._hub.clients.map(
                  (client) => _SettingRow(
                    title:
                        '${client.name ?? client.id}'
                        '${client.isGlobalAdmin ? '  👑' : ''}'
                        '${client.isMuted ? '  🔇' : ''}',
                    subtitle:
                        "${"Connected at".tl} "
                        "${client.connectedAt.hour.toString().padLeft(2, '0')}:"
                        "${client.connectedAt.minute.toString().padLeft(2, '0')}:"
                        "${client.connectedAt.second.toString().padLeft(2, '0')}",
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 禁言/解禁
                        IconButton(
                          icon: Icon(
                            client.isMuted ? Icons.mic : Icons.mic_off,
                            size: 18,
                          ),
                          tooltip: client.isMuted
                              ? "Unmute".tl
                              : "Mute 5min".tl,
                          onPressed: () async {
                            if (client.isMuted) {
                              await _hub.unmuteClient(client.id);
                            } else {
                              await _hub.muteClient(client.id, seconds: 300);
                            }
                            setState(() {});
                          },
                        ),
                        // 设置页面按钮改成两个
                        IconButton(
                          icon: Icon(
                            client.isGlobalAdmin
                                ? Icons.shield
                                : Icons.shield_outlined,
                            color: client.isGlobalAdmin
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          tooltip: client.isGlobalAdmin
                              ? "Remove Global Admin".tl
                              : "Set Global Admin".tl,
                          onPressed: () async {
                            await _hub.setClientGlobalAdmin(
                              client.id,
                              !client.isGlobalAdmin,
                            );
                            setState(() {});
                          },
                        ),
                        // 踢出
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: "Kick".tl,
                          onPressed: () async {
                            await _hub.kickClient(client.id);
                            setState(() {});
                          },
                        ),
                        // 拉黑
                        IconButton(
                          icon: Icon(
                            _hub.isBlacklisted(client.id)
                                ? Icons.block
                                : Icons.block_outlined,
                            size: 18,
                            color: _hub.isBlacklisted(client.id)
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                          tooltip: _hub.isBlacklisted(client.id)
                              ? "Remove from Blacklist".tl
                              : "Add to Blacklist".tl,
                          onPressed: () async {
                            if (_hub.isBlacklisted(client.id)) {
                              _hub.removeFromBlacklist(client.id);
                            } else {
                              _hub.addToBlacklist(client.id);
                            }
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 消息历史
              if (_hubEnabled && _hub.messageHistory.isNotEmpty) ...[
                const Divider(height: 1),
                _SettingPartTitle(
                  title: "Message History".tl,
                  icon: Icons.history_outlined,
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _hub.messageHistory.length,
                    reverse: true,
                    itemBuilder: (context, i) {
                      final msg = _hub
                          .messageHistory[_hub.messageHistory.length - 1 - i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          '[${msg.type.name}] '
                          '${msg.from} → ${msg.to ?? "all"}: '
                          '${msg.payload}',
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
              if (_hubEnabled) ...[
                const Divider(height: 1),
                _SettingRow(
                  title: "Blacklist".tl,
                  subtitle: "${_hub.blacklistCount} ${"banned".tl}",
                  trailing: IconButton(
                    icon: const Icon(Icons.block_outlined, size: 18),
                    onPressed: () => _showBlacklistSheet(context),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),

        // ── Hub 客户端 ───────────────────────────────────
        _buildSectionPadding(
          _SettingCard(
            children: [
              _SettingPartTitle(
                title: "Hub Client".tl,
                icon: Icons.devices_outlined,
              ),
              const SizedBox(height: 8),
              _SettingRow(
                title: "Connect to Hub".tl,
                subtitle: _hubClientEnabled
                    ? "${"Connected".tl}  ID: ${_hubClient.myId ?? '-'}"
                    : "Not connected".tl,
                trailing: CustomSwitch(
                  value: _hubClientEnabled,
                  onChanged: _toggleHubClient,
                ),
              ),
              const Divider(height: 1),

              // 服务端地址输入
              _SettingRow(
                title: "Hub Address".tl,
                subtitle: "ws://192.168.1.x:9100",
                trailing: SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _hubAddressController,
                    enabled: !_hubClientEnabled,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'ws://192.168.1.x:9100',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => _hubClient.saveAddress(v.trim()),
                  ),
                ),
              ),
              const Divider(height: 1),
              _SettingRow(
                title: "Hub Token".tl,
                subtitle: "Token from the hub server".tl,
                trailing: SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _hubTokenController,
                    enabled: !_hubClientEnabled,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Paste hub server token'.tl,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => _hubClient.saveToken(v.trim()),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Hub Client 区块
              if (_hubClientEnabled) ...[
                const Divider(height: 1),
                // 个人资料
                _SettingRow(
                  title: "Profile".tl,
                  subtitle: _hubClient.savedName ?? "Not set".tl,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _showEditProfileDialog(context),
                  ),
                ),
                const Divider(height: 1),
                _SettingRow(
                  title: "Current Room".tl,
                  subtitle: _hubClient.currentRoomName ?? "Lobby".tl,
                  trailing: IconButton(
                    icon: const Icon(Icons.meeting_room_outlined, size: 18),
                    onPressed: () => _showJoinRoomSheet(context),
                  ),
                ),
                const Divider(height: 1),

                // 在线客户端列表
                if (_hubClient.onlineClients.isNotEmpty) ...[
                  _SettingPartTitle(
                    title: "Online Clients".tl,
                    icon: Icons.people_outline,
                  ),
                  ..._hubClient.currentRoomClients.map(
                    (client) => ListTile(
                      leading:
                          client['avatar'] != null &&
                              (client['avatar'] as String).isNotEmpty
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(
                                client['avatar'] as String,
                              ),
                              radius: 16,
                            )
                          : CircleAvatar(
                              radius: 16,
                              child: Text(
                                (client['name'] as String? ?? 'U')[0]
                                    .toUpperCase(),
                              ),
                            ),
                      title: Text(
                        '${client['name'] ?? client['id']}'
                        '${client['isGlobalAdmin'] == true ? "  👑" : ""}',
                      ),
                      subtitle: Text(
                        client['bio'] != null &&
                                (client['bio'] as String).isNotEmpty
                            ? client['bio'] as String
                            : client['status'] ?? 'online',
                      ),
                      trailing: client['id'] == _hubClient.myId
                          ? Text(
                              "Me".tl,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 12,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 屏蔽
                                IconButton(
                                  icon: Icon(
                                    _hubClient.isBlocked(client['id'] as String)
                                        ? Icons.volume_off
                                        : Icons.volume_off_outlined,
                                    size: 18,
                                    color:
                                        _hubClient.isBlocked(
                                          client['id'] as String,
                                        )
                                        ? Theme.of(context).colorScheme.error
                                        : null,
                                  ),
                                  tooltip:
                                      _hubClient.isBlocked(
                                        client['id'] as String,
                                      )
                                      ? "Unblock".tl
                                      : "Block".tl,
                                  onPressed: () {
                                    final id = client['id'] as String;
                                    if (_hubClient.isBlocked(id)) {
                                      _hubClient.unblockUser(id);
                                    } else {
                                      _hubClient.blockUser(id);
                                    }
                                    setState(() {});
                                  },
                                ),
                                // 禁言（全局管理员或房间管理员）
                                if (_hubClient.isGlobalAdmin ||
                                    _hubClient.isRoomAdminOf(
                                      _hubClient.currentRoomId,
                                    ))
                                  IconButton(
                                    icon: Icon(
                                      client['isMuted'] == true
                                          ? Icons.mic
                                          : Icons.mic_off,
                                      size: 18,
                                    ),
                                    tooltip: client['isMuted'] == true
                                        ? "Unmute".tl
                                        : "Mute 5min".tl,
                                    onPressed: () {
                                      if (client['isMuted'] == true) {
                                        _hubClient.unmute(
                                          client['id'] as String,
                                        );
                                      } else {
                                        _hubClient.mute(
                                          client['id'] as String,
                                          seconds: 300,
                                        );
                                      }
                                      setState(() {});
                                    },
                                  ),
                                // 设置房间管理员（房间管理员）
                                if (_hubClient.isGlobalAdmin ||
                                    _hubClient.isRoomAdminOf(
                                      _hubClient.currentRoomId,
                                    ))
                                  // 禁言
                                  IconButton(
                                    icon: Icon(
                                      client['isMuted'] == true
                                          ? Icons.mic
                                          : Icons.mic_off,
                                      size: 18,
                                    ),
                                    tooltip: client['isMuted'] == true
                                        ? "Unmute".tl
                                        : "Mute 5min".tl,
                                    onPressed: () {
                                      if (client['isMuted'] == true) {
                                        _hubClient.unmute(
                                          client['id'] as String,
                                        );
                                      } else {
                                        _hubClient.mute(
                                          client['id'] as String,
                                          seconds: 300,
                                        );
                                      }
                                      setState(() {});
                                    },
                                  ),
                                // 踢出
                                IconButton(
                                  icon: const Icon(Icons.logout, size: 18),
                                  tooltip: "Kick".tl,
                                  onPressed: () {
                                    _hubClient.kickFromRoom(
                                      client['id'] as String,
                                    );
                                    setState(() {});
                                  },
                                ),
                                // 房间封禁
                                IconButton(
                                  icon: const Icon(
                                    Icons.block_outlined,
                                    size: 18,
                                  ),
                                  tooltip: "Room Ban".tl,
                                  onPressed: () {
                                    _hubClient.roomBan(client['id'] as String);
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    _hubClient.isRoomAdminOf(
                                              _hubClient.currentRoomId,
                                            ) &&
                                            (client['id'] as String?) != null &&
                                            (_hubClient.roomList.firstWhereOrNull(
                                                          (r) =>
                                                              r['id'] ==
                                                              _hubClient
                                                                  .currentRoomId,
                                                        )?['adminIds']
                                                        as List?)
                                                    ?.contains(client['id']) ==
                                                true
                                        ? Icons.manage_accounts
                                        : Icons.manage_accounts_outlined,
                                    size: 18,
                                    color:
                                        (_hubClient.roomList.firstWhereOrNull(
                                                      (r) =>
                                                          r['id'] ==
                                                          _hubClient
                                                              .currentRoomId,
                                                    )?['adminIds']
                                                    as List?)
                                                ?.contains(client['id']) ==
                                            true
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.secondary
                                        : null,
                                  ),
                                  tooltip:
                                      (_hubClient.roomList.firstWhereOrNull(
                                                    (r) =>
                                                        r['id'] ==
                                                        _hubClient
                                                            .currentRoomId,
                                                  )?['adminIds']
                                                  as List?)
                                              ?.contains(client['id']) ==
                                          true
                                      ? "Remove Room Admin".tl
                                      : "Set Room Admin".tl,
                                  onPressed: () {
                                    final isAdmin =
                                        (_hubClient.roomList.firstWhereOrNull(
                                                  (r) =>
                                                      r['id'] ==
                                                      _hubClient.currentRoomId,
                                                )?['adminIds']
                                                as List?)
                                            ?.contains(client['id']) ==
                                        true;
                                    _hubClient.setRoomAdmin(
                                      client['id'] as String,
                                      value: !isAdmin,
                                    );
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
              if (_hubClientEnabled) ...[
                const Divider(height: 1),
                _SettingRow(
                  title: "Chat Room".tl,
                  subtitle: "Open chat dialog".tl,
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    onPressed: () => HubChatDialog.show(context),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // ── 复用组件 ───────────────────────────────────────────

  Widget _buildSectionPadding(Widget child) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

// ── 端口输入框（复用） ─────────────────────────────────────

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
    return SizedBox(
      width: 80,
      height: 36,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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

class _BindModeSelector extends StatelessWidget {
  final BindMode value;
  final bool enabled;
  final ValueChanged<BindMode> onChanged;

  const _BindModeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final disabledColor = Colors.grey.toOpacity(0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModeChip(
          label: 'IPv4',
          selected: value == BindMode.ipv4,
          enabled: enabled,
          color: color,
          disabledColor: disabledColor,
          onTap: () => onChanged(BindMode.ipv4),
        ),
        const SizedBox(width: 6),
        _ModeChip(
          label: 'IPv6',
          selected: value == BindMode.ipv6,
          enabled: enabled,
          color: color,
          disabledColor: disabledColor,
          onTap: () => onChanged(BindMode.ipv6),
        ),
        const SizedBox(width: 6),
        _ModeChip(
          label: 'Both',
          selected: value == BindMode.both,
          enabled: enabled,
          color: color,
          disabledColor: disabledColor,
          onTap: () => onChanged(BindMode.both),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final Color disabledColor;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.disabledColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : disabledColor;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? effectiveColor : effectiveColor.toOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: effectiveColor, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : effectiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget trailing;

  const _SettingRow({
    required this.title,
    this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.toOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _KeyDisplay extends StatefulWidget {
  final String keyValue;

  const _KeyDisplay({required this.keyValue});

  @override
  State<_KeyDisplay> createState() => _KeyDisplayState();
}

class _KeyDisplayState extends State<_KeyDisplay> {
  bool _visible = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 显示/隐藏 Key
        Text(
          _visible ? widget.keyValue : '••••••••••••••••',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onSurface.toOpacity(0.7),
          ),
        ),
        const SizedBox(width: 4),

        // 显示/隐藏按钮
        IconButton(
          icon: Icon(
            _visible ? Icons.visibility_off : Icons.visibility,
            size: 16,
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),

        // 复制按钮
        IconButton(
          icon: Icon(
            _copied ? Icons.check : Icons.copy,
            size: 16,
            color: _copied ? Colors.green : null,
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.keyValue));
            setState(() => _copied = true);
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) setState(() => _copied = false);
          },
        ),
      ],
    );
  }
}
