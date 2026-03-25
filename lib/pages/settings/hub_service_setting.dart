part of 'settings_page.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  公共组件
// ═══════════════════════════════════════════════════════════════════════════

/// 底部 Sheet 统一标题栏
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.icon});

  final String title;
  final IconData? icon;

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

/// 成员头像 + 名称 Tile
class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.name, this.avatarUrl, this.trailing});

  final String name;
  final String? avatarUrl;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
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

class _HubManagementPage extends ConsumerStatefulWidget {
  const _HubManagementPage();

  @override
  ConsumerState<_HubManagementPage> createState() => _HubManagementPageState();
}

class _HubManagementPageState extends ConsumerState<_HubManagementPage> {
  late final HubService _hub;

  @override
  void initState() {
    super.initState();
    _hub = ref.read(hubServiceProvider);
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
            _SheetHeader(title: t.blacklist, icon: Icons.block_outlined),
            if (_hub.blacklist.isEmpty)
              _EmptyHint(t.noBannedUsers)
            else
              ..._hub.blacklist.map(
                (id) => _ClientTile(
                  name: id,
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    tooltip: t.removeFromBlacklist,
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
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Sheet(
          title: t.rooms,
          icon: Icons.meeting_room_outlined,
          headerTrailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: Text(t.create),
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
              return ListTile(
                leading: Icon(
                  room.isLocked
                      ? Icons.lock_outlined
                      : Icons.meeting_room_outlined,
                ),
                title: Text(room.roomName),
                subtitle: Text(
                  '${room.participantCount} ${t.members}'
                  '${room.announcements.isNotEmpty ? "  ·  ${room.announcements.first}" : ""}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 18,
                      ),
                      tooltip: t.roomAdmins,
                      onPressed: () =>
                          _showRoomAdminSheet(context, room, setSS),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: t.deleteRoom,
                      onPressed: () async {
                        await _hub.deleteRoom(room.roomId);
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
    final result = await showCreateRoomDialog();
    if (result == null) return;
    await _hub.createRoom(
      result.name,
      password: result.password,
      announcement: result.announcement,
      maxParticipants: result.maxParticipants,
    );
    setState(() {});
  }

  void _showRoomAdminSheet(
    BuildContext context,
    HubRoom room,
    StateSetter setParent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: "${t.roomAdmins} · ${room.roomName}",
              icon: Icons.manage_accounts_outlined,
            ),
            Expanded(
              child: ListView(
                children: _hub.clients.map((client) {
                  final isAdmin = room.isModerator(client.userId);
                  return _ClientTile(
                    name: client.displayName ?? client.userId,
                    avatarUrl: client.avatarUrl,
                    trailing: Switch(
                      value: isAdmin,
                      onChanged: (val) async {
                        await _hub.setClientRoomAdmin(
                          client.userId,
                          room.roomId,
                          val,
                        );
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
      title: t.hubManagement,
      body: CustomScrollView(
        slivers: [
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.rooms,
                  icon: Icons.meeting_room_outlined,
                ),
                _SettingRow(
                  title: "${_hub.rooms.length} rooms",
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _showRoomsSheet(context),
                  ),
                ),
              ],
            ),
          ),
          if (_hub.eventLog.isNotEmpty)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.eventLog,
                    icon: Icons.history_outlined,
                  ),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      reverse: true,
                      itemCount: _hub.eventLog.length,
                      itemBuilder: (context, i) {
                        final log = _hub.eventLog[_hub.eventLog.length - 1 - i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Text(
                            log,
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
                      label: Text(t.clear),
                      onPressed: () {
                        _hub.eventLog.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.blacklist,
                  icon: Icons.block_outlined,
                ),
                _SettingRow(
                  title: "${_hub.blacklistCount} banned",
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => _showBlacklistSheet(context),
                  ),
                ),
              ],
            ),
          ),
          if (_hub.clientCount > 0)
            _BuildSectionPadding(
              _SettingCard(
                children: [
                  _SettingPartTitle(
                    title: t.onlineClients,
                    icon: Icons.people_outline,
                  ),
                  ..._hub.clients.map(
                    (client) => _OnlineClientTile(
                      client: client.toDto(),
                      myId: null,
                      isBlocked: false,
                      canManage: true,
                      isAdmin: client.isGlobalAdmin,
                      isBlacklisted: _hub.isBlacklisted(client.userId),
                      onBlock: () {},
                      onMute: (seconds) async {
                        if (seconds == 0 || client.isMuted) {
                          await _hub.unmuteClient(client.userId);
                        } else {
                          await _hub.muteClient(
                            client.userId,
                            seconds: seconds,
                          );
                        }
                        setState(() {});
                      },
                      onKick: () async {
                        await _hub.kickClient(client.userId);
                        setState(() {});
                      },
                      onSetAdmin: () async {
                        await _hub.setClientGlobalAdmin(
                          client.userId,
                          !client.isGlobalAdmin,
                        );
                        setState(() {});
                      },
                      onBlacklist: () {
                        _hub.isBlacklisted(client.userId)
                            ? _hub.removeFromBlacklist(client.userId)
                            : _hub.addToBlacklist(client.userId);
                        setState(() {});
                      },
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

  final HubClientDto client;
  final String? myId;
  final bool isBlocked;
  final bool canManage;
  final VoidCallback onBlock;
  final ValueChanged<int> onMute;
  final VoidCallback onKick;
  final VoidCallback? onBlacklist;
  final bool? isBlacklisted;
  final VoidCallback? onSetAdmin;
  final bool? isAdmin;

  void _showMuteSheet(BuildContext context) {
    if (client.isMuted) {
      onMute(0);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => _MuteSheet(
        clientName: client.displayName,
        onMute: (seconds) {
          Navigator.pop(context);
          onMute(seconds);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = client.isMuted;
    final isMe = client.userId == myId;
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: client.avatarUrl != null && client.avatarUrl!.isNotEmpty
          ? CircleAvatar(
              backgroundImage: NetworkImage(client.avatarUrl!),
              radius: 16,
            )
          : CircleAvatar(
              radius: 16,
              child: Text(
                (client.displayName.isEmpty ? 'U' : client.displayName)[0]
                    .toUpperCase(),
              ),
            ),
      title: Text(
        '${client.displayName}'
        '${client.isGlobalAdmin ? "  👑" : ""}'
        '${isMuted ? "  🔇" : ""}',
      ),
      subtitle: Text(
        client.biography != null && client.biography!.isNotEmpty
            ? client.biography!
            : client.onlineStatus.name,
      ),
      trailing: isMe
          ? Text(t.me, style: TextStyle(color: cs.primary, fontSize: 12))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (myId != null)
                  IconButton(
                    icon: Icon(
                      isBlocked ? Icons.volume_off : Icons.volume_off_outlined,
                      size: 18,
                      color: isBlocked ? cs.error : null,
                    ),
                    tooltip: isBlocked ? t.unblock : t.block,
                    onPressed: onBlock,
                  ),
                if (canManage && !client.isGlobalAdmin) ...[
                  IconButton(
                    icon: Icon(
                      isMuted ? Icons.mic : Icons.mic_off,
                      size: 18,
                      color: isMuted ? cs.error : null,
                    ),
                    tooltip: isMuted ? t.unmute : t.mute,
                    onPressed: () => _showMuteSheet(context),
                  ),
                  if (!client.isGlobalAdmin)
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      tooltip: t.kick,
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
                        ? t.removeGlobalAdmin
                        : t.setGlobalAdmin,
                    onPressed: onSetAdmin,
                  ),
                if (onBlacklist != null && !client.isGlobalAdmin)
                  IconButton(
                    icon: Icon(
                      isBlacklisted == true
                          ? Icons.block
                          : Icons.block_outlined,
                      size: 18,
                      color: isBlacklisted == true ? cs.error : null,
                    ),
                    tooltip: isBlacklisted == true
                        ? t.removeFromBlacklist
                        : t.addToBlacklist,
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
                    '${t.mute}  ${widget.clientName}',
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
                  label: Text(t.custom, style: TextStyle(color: cs.primary)),
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
                        hintText: t.secondsLabel,
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
                    child: Text(t.confirm),
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

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.min = 1024,
    this.max = 65535,
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
          final val = int.tryParse(v);
          if (val != null && val >= min && val <= max) {
            onChanged(val);
          }
        },
      ),
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({
    required this.keyManager,
    required this.onRegenerate,
    this.isAdmin = false,
  });

  final ApiKeyManager keyManager;
  final VoidCallback onRegenerate;
  final bool isAdmin;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  bool _obscured = true;

  String get _activeKey => widget.isAdmin
      ? widget.keyManager.adminActiveKey
      : widget.keyManager.activeKey;

  String get _label => widget.isAdmin ? t.adminKey : t.userKey;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_label),
      subtitle: Text(
        _obscured ? '••••••••••••••••' : _activeKey,
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
            tooltip: _obscured ? t.show : t.hide,
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: t.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _activeKey));
              App.rootContext.showMessage(message: t.copied);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: t.regenerate,
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
          hintText: t.pasteHubServerToken,
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
                        tooltip: t.paste,
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
                        tooltip: t.clear,
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
