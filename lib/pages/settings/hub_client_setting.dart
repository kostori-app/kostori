part of 'settings_page.dart';

/// 连接 Hub 前确保已填写显示名；未填写则弹框强制填写。
/// 返回 false 表示用户取消（不应连接）。
Future<bool> ensureHubNameSet(BuildContext context) async {
  final client = ProviderScope.containerOf(context).read(hubClientProvider);
  final saved = client.savedName;
  if (saved != null && saved.trim().isNotEmpty) return true;

  var confirmed = false;
  await showInputDialog(
    context: context,
    title: t.enterDisplayName,
    hintText: t.enterDisplayName,
    inputValidator: RegExp(r'\S'),
    onConfirm: (value) {
      final name = value.trim();
      if (name.isEmpty) return t.displayNameRequired;
      client.saveName(name);
      confirmed = true;
      return null;
    },
  );
  return confirmed;
}

class HubClientDetailPage extends ConsumerStatefulWidget {
  const HubClientDetailPage({super.key});

  @override
  ConsumerState<HubClientDetailPage> createState() =>
      HubClientDetailPageState();
}

class HubClientDetailPageState extends ConsumerState<HubClientDetailPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _tokenController;
  late final HubClient _hubClient;
  bool _tokenObscured = true;
  bool _useWss = false;

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
        _useWss = uri.scheme == 'wss' || uri.scheme == 'https';
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

  // ── 已保存的服务器配置 ─────────────────────────────────────────────────────

  Future<void> _saveCurrentProfile() async {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    final address = 'ws://$host:$port';
    String? name;
    await showInputDialog(
      context: App.rootContext,
      title: t.saveCurrentConfig,
      hintText: t.serverName,
      initialValue: host.isEmpty ? address : host,
      onConfirm: (v) {
        name = v;
        return null;
      },
    );
    if (name == null || !mounted) return;
    _hubClient.saveProfile(
      name: name!,
      address: address,
      token: _tokenController.text.trim(),
    );
    _saveAddress();
    setState(() {});
  }

  Future<void> _connectProfile(Map<String, dynamic> p) async {
    final address = p['address'] as String? ?? '';
    if (address.isEmpty) return;
    // 连接前确保已填写显示名
    final nameOk = await ensureHubNameSet(context);
    if (!nameOk) return;
    if (_hubClient.isConnected) await _hubClient.disconnect();
    _hubClient.activateProfile(address);
    _hostController.text = Uri.tryParse(address)?.host ?? address;
    _portController.text = (Uri.tryParse(address)?.hasPort ?? false)
        ? (Uri.tryParse(address)?.port ?? 9100).toString()
        : '9100';
    _tokenController.text = _hubClient.savedToken ?? '';
    setState(() {});
    try {
      await _hubClient.connect(
        address,
        _hubClient.savedToken ?? '',
        name: _hubClient.savedName ?? '',
      );
    } catch (e) {
      App.rootContext.showMessage(
        message: t.connectionFailed,
        level: LogLevel.warning,
      );
    }
  }

  Widget _buildProfilesCard(BuildContext context) {
    final profiles = _hubClient.getProfiles();
    final cs = Theme.of(context).colorScheme;
    return _BuildSectionPadding(
      _SettingCard(
        children: [
          _SettingPartTitle(
            title: t.savedServers,
            icon: Icons.history_outlined,
          ),
          if (profiles.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                t.noSavedServers,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.toOpacity(0.4),
                ),
              ),
            )
          else
            ...profiles.map(
              (p) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _connectProfile(p),
                    onLongPress: () => _editProfileDialog(context, p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            p['address'] == _hubClient.savedAddress
                                ? Icons.radio_button_checked
                                : Icons.circle_outlined,
                            size: 18,
                            color: p['address'] == _hubClient.savedAddress
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (p['name'] as String?)?.isNotEmpty == true
                                      ? p['name'] as String
                                      : p['address'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p['address'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.link, size: 18),
                            tooltip: t.connect,
                            onPressed: () => _connectProfile(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: t.delete,
                            onPressed: () {
                              _hubClient.deleteProfile(p['address'] as String);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(t.saveCurrentConfig),
              onPressed: _saveCurrentProfile,
            ),
          ),
        ],
      ),
    );
  }

  /// 长按已保存服务器 → 编辑（名称/地址/token）
  Future<void> _editProfileDialog(
    BuildContext context,
    Map<String, dynamic> profile,
  ) async {
    final uri = Uri.tryParse(profile['address'] as String? ?? '');
    final oldScheme = uri?.scheme ?? 'ws';
    final nameCtrl = TextEditingController(text: profile['name'] ?? '');
    final hostCtrl = TextEditingController(text: uri?.host ?? '');
    final portCtrl = TextEditingController(
      text: (uri?.hasPort ?? false) ? (uri?.port ?? 9100).toString() : '9100',
    );
    final tokenCtrl = TextEditingController(text: profile['token'] ?? '');

    var useWss = oldScheme == 'wss' || oldScheme == 'https';

    final result = await showHubFormDialog<Map<String, String>>(
      title: t.edit,
      confirmLabel: t.save,
      fields: [
        InputField(
          controller: nameCtrl,
          hint: t.serverName,
          icon: Icons.badge_outlined,
        ),
        InputField(
          controller: hostCtrl,
          hint: t.host,
          icon: Icons.dns_outlined,
        ),
        InputField(
          controller: portCtrl,
          hint: t.port,
          icon: Icons.numbers_outlined,
        ),
        // 协议选择
        StatefulBuilder(
          builder: (context, setSS) => Row(
            children: [
              Text(
                t.protocol,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              _ProtoSelector(
                useWss: useWss,
                enabled: true,
                onChanged: (wss) => setSS(() => useWss = wss),
              ),
            ],
          ),
        ),
        InputField(
          controller: tokenCtrl,
          hint: t.hubToken,
          icon: Icons.key_outlined,
        ),
      ],
      // 只做数据保存；避免在 dialog 关闭动画期间直接操作下层页面的
      // controller / setState（会导致 overlay GlobalKey 冲突与
      // TextEditingController used after disposed 报错）
      onConfirm: () async {
        final oldAddress = profile['address'] as String? ?? '';
        final scheme = useWss ? 'wss' : 'ws';
        final address =
            '$scheme://${hostCtrl.text.trim()}:${portCtrl.text.trim()}';
        _hubClient.saveProfile(
          name: nameCtrl.text.trim(),
          address: address,
          token: tokenCtrl.text.trim(),
        );
        if (oldAddress.isNotEmpty && oldAddress != address) {
          _hubClient.deleteProfile(oldAddress);
        }
        return {'oldAddress': oldAddress, 'token': tokenCtrl.text.trim()};
      },
    );

    // dialog 完全关闭后再更新页面状态，避免与关闭动画竞争
    if (result != null && mounted) {
      if (_hubClient.savedAddress == result['oldAddress']) {
        _hubClient.saveToken(result['token'] ?? '');
        _tokenController.text = result['token'] ?? '';
      }
      setState(() {});
    }

    nameCtrl.dispose();
    hostCtrl.dispose();
    portCtrl.dispose();
    tokenCtrl.dispose();
  }

  void _saveAddress() {
    final host = _hostController.text.trim();
    final port = _portController.text.trim();
    if (host.isNotEmpty) {
      _hubClient.saveAddress('${_useWss ? 'wss' : 'ws'}://$host:$port');
    }
  }

  /// 跳到当前一起看房间绑定的番剧播放页
  void _openRoomAnime() {
    final room = ref.read(hubProvider).currentRoom;
    final animeId = room?.animeId;
    final sourceKey = room?.animeSourceKey;
    if (room == null || animeId == null || sourceKey == null) {
      App.rootContext.showMessage(
        message: t.watchTogetherRoomHasNoAnime,
        level: LogLevel.warning,
      );
      return;
    }
    // 关闭所有 pop up 层，再在主导航跳转番剧页
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.popUntil((route) => route.isFirst);
    App.mainNavigatorKey?.currentContext?.to(
      () => AnimePage(
        id: animeId,
        sourceKey: sourceKey,
        cover: room.animeCover,
        title: room.animeTitle,
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
                          '${_useWss ? 'wss' : 'ws'}://'
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
                      const SizedBox(height: 12),
                      // 协议选择：ws / wss
                      Row(
                        children: [
                          Text(
                            t.protocol,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _ProtoSelector(
                            useWss: _useWss,
                            enabled: !isConnected,
                            onChanged: (wss) {
                              setState(() => _useWss = wss);
                              _saveAddress();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            t.hubToken,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          if (_tokenController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
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
                                    icon: const Icon(
                                      Icons.content_paste,
                                      size: 16,
                                    ),
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
                                    icon: const Icon(Icons.clear, size: 16),
                                    tooltip: t.clear,
                                    onPressed: () {
                                      _tokenController.clear();
                                      _hubClient.saveToken('');
                                      setState(() {});
                                    },
                                  ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
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
                          suffixIcon: IconButton(
                            icon: Icon(
                              _tokenObscured
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                            ),
                            tooltip: _tokenObscured ? t.show : t.hide,
                            onPressed: () => setState(
                              () => _tokenObscured = !_tokenObscured,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          _hubClient.saveToken(v.trim());
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 当前一起看房间 ──
          if (hubState.isConnected &&
              hubState.currentRoomId != null &&
              hubState.currentRoomId != hubState.lobbyRoomId &&
              hubState.currentRoom?.isWatchRoom == true)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.watchTogether,
                    icon: Icons.groups_2_outlined,
                  ),
                  ListTile(
                    leading: Icon(Icons.play_circle_outline, color: cs.primary),
                    title: Text(
                      hubState.currentRoomName ?? hubState.currentRoomId ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      hubState.currentRoom?.animeTitle?.isNotEmpty == true
                          ? hubState.currentRoom!.animeTitle!
                          : t.watchTogether,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                        (hubState.currentRoom?.animeId != null &&
                            hubState.currentRoom?.animeSourceKey != null)
                        ? TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 15),
                            label: Text(t.openAnime),
                            onPressed: _openRoomAnime,
                          )
                        : null,
                  ),
                ],
              ),
            ),

          // ── 已保存的服务器配置 ──
          _buildProfilesCard(context),

          _BuildSectionPadding(
            _SettingCard(
              children: [_ClientUploadConfigSetting(client: _hubClient)],
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

/// 编辑 Hub 个人资料（名字/头像/简介）。可复用于「Hub 客户端」卡片与「Hub 详情」页。
Future<void> showHubProfileEditDialog(HubClient client) async {
  final nameCtrl = TextEditingController(text: client.savedName);
  final bioCtrl = TextEditingController(text: client.savedBio);
  final avatarCtrl = TextEditingController(text: client.savedAvatar);

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
      // 上传图片作为头像
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.upload_file, size: 16),
          label: Text(t.uploadAvatar),
          onPressed: () => _uploadAvatarForClient(client, avatarCtrl),
        ),
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

      if (name.isNotEmpty) client.saveName(name);
      if (bio.isNotEmpty) client.saveBio(bio);
      // 头像允许清空；非空时校验 URL
      if (avatar.isNotEmpty) {
        final uri = Uri.tryParse(avatar);
        if (uri == null || !uri.hasScheme) {
          App.rootContext.showMessage(
            message: t.pleaseEnterAValidUrl,
            level: LogLevel.warning,
          );
          return null;
        }
      }
      client.saveAvatar(avatar);

      if (client.isConnected) {
        client.updateProfile(
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

/// 选择本地图片上传到 hub 服务器作为头像，成功后把 URL 填入输入框
Future<void> _uploadAvatarForClient(
  HubClient client,
  TextEditingController ctrl,
) async {
  // 上传需要连接到服务器（图片会存到该服务器）
  if (!client.isConnected) {
    App.rootContext.showMessage(
      message: t.connectFirstToUploadAvatar,
      level: LogLevel.warning,
    );
    return;
  }
  try {
    Uint8List bytes;
    String fileName;
    if (App.isDesktop) {
      final result = await FilePicker.pickFiles(type: FileType.image);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      bytes = await f.readAsBytes();
      fileName = f.name;
    } else {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      bytes = await picked.readAsBytes();
      fileName = picked.name;
    }
    final url = await _uploadHubImageForClient(client, bytes, fileName);
    if (url != null) {
      // 上传返回的可能是相对路径 /hub/files/xxx，转成绝对 URL，
      // 这样即使之后连接别的服务器，头像仍指向图片实际所在的服务器
      ctrl.text = hubFileUrlOf(url);
      App.rootContext.showMessage(message: t.avatarUploaded);
    } else {
      App.rootContext.showMessage(
        message: t.uploadFailed,
        level: LogLevel.warning,
      );
    }
  } catch (e) {
    App.rootContext.showMessage(
      message: '${t.uploadFailed}: $e',
      level: LogLevel.warning,
    );
  }
}

/// 经 hub 服务器上传图片，返回访问 URL
Future<String?> _uploadHubImageForClient(
  HubClient client,
  Uint8List bytes,
  String fileName,
) async {
  final savedAddress = client.savedAddress;
  if (savedAddress == null || savedAddress.isEmpty) return null;
  final httpBase = HubImageUploader.httpUrlOf(
    savedAddress,
  ).replaceAll(RegExp(r'/hub/?$'), '');
  try {
    final resp = await AppDio().request(
      '$httpBase/hub/upload/config',
      options: Options(
        method: 'GET',
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    if (resp.statusCode != 200 || resp.data is! Map) return null;
    final config = HubUploadConfig.fromJson(
      Map<String, dynamic>.from(resp.data as Map),
    );
    return await HubImageUploader(
      config: config,
      serverBaseUrl: httpBase,
      authToken: client.savedToken,
    ).upload(bytes, fileName);
  } catch (e) {
    Log.warning('HubUploader', 'uploadHubImage failed: $e');
    return null;
  }
}
