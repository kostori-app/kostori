import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/services/services.dart';
import 'package:kostori/foundation/widget_utils.dart';
import 'package:kostori/pages/hub/hub_chat_page.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/hub/hub_create_room_dialog.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

void showHubDialog(BuildContext context) {
  showPopUpWidget(context, const HubPage());
}

class HubPage extends ConsumerStatefulWidget {
  const HubPage({super.key});

  @override
  ConsumerState<HubPage> createState() => _HubPageState();
}

class _HubPageState extends ConsumerState<HubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  late final HubClient _client;

  @override
  void initState() {
    super.initState();
    _client = ref.read(hubClientProvider);
    _client.onRoomListChanged = () {
      if (mounted) setState(() {});
    };
    _client.onClientsChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    _client.onRoomListChanged = null;
    _client.onClientsChanged = null;
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(hubProvider);

    return PopUpWidgetScaffold(
      title: 'Hub',
      tailing: [
        if (hubState.isGlobalAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
            tooltip: 'Admin'.tl,
            onPressed: () => _showAdminSheet(context, hubState),
          ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            tabs: [
              Tab(
                icon: const Icon(Icons.meeting_room_outlined, size: 18),
                text: 'Rooms'.tl,
              ),
              Tab(
                icon: const Icon(Icons.people_outline, size: 18),
                text: 'People'.tl,
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _RoomsTab(hubState: hubState),
                _PeopleTab(hubState: hubState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 全局管理面板 ──────────────────────────────────────────────────────────

  void _showAdminSheet(BuildContext context, HubState hubState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, sc) => Column(
            children: [
              _SheetHeader(
                title: 'Admin Panel'.tl,
                icon: Icons.admin_panel_settings_outlined,
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  children: [
                    // ── 公告 ──
                    ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text('Set Announcement'.tl),
                      onTap: () => _showAnnouncementDialog(context),
                    ),
                    // ── 房间密码 ──
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text('Set Room Password'.tl),
                      onTap: () => _showSetPasswordDialog(context),
                    ),
                    // ── 服务端黑名单 ──
                    ListTile(
                      leading: const Icon(Icons.block_outlined),
                      title: Text('Server Blacklist'.tl),
                      subtitle: Text(
                        '${hubState.serverBannedIds.length} ${"banned".tl}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showServerBlacklistSheet(context, hubState),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Announcement'.tl),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter announcement...'.tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                _client.setAnnouncement(ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text('Send'.tl),
          ),
        ],
      ),
    );
  }

  void _showSetPasswordDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Room Password'.tl),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Leave empty to remove'.tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () {
              _client.setRoomPassword(
                ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
              );
              Navigator.pop(context);
            },
            child: Text('OK'.tl),
          ),
        ],
      ),
    );
  }

  void _showServerBlacklistSheet(BuildContext context, HubState hubState) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: 'Server Blacklist'.tl,
              icon: Icons.block_outlined,
            ),
            if (hubState.serverBannedIds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No banned users'.tl,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.toOpacity(0.4),
                  ),
                ),
              )
            else
              ...hubState.serverBannedIds.map(
                (id) => ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: Text(id),
                  trailing: IconButton(
                    icon: const Icon(Icons.lock_open_outlined, size: 18),
                    onPressed: () {
                      _client.serverUnban(id);
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
}

// ── Rooms Tab ─────────────────────────────────────────────────────────────────

class _RoomsTab extends ConsumerWidget {
  final HubState hubState;

  const _RoomsTab({required this.hubState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(hubClientProvider);
    final cs = Theme.of(context).colorScheme;
    final canCreate =
        hubState.isGlobalAdmin ||
        !hubState.roomList.any((r) => r.ownerUserId == hubState.myId);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hubState.roomList.length + (canCreate ? 1 : 0),
      itemBuilder: (context, i) {
        if (canCreate && i == hubState.roomList.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text('Create Room'.tl),
              onPressed: () => _showCreateRoomDialog(context, client),
            ),
          );
        }

        final room = hubState.roomList[i];
        final isLobby = room.roomId == hubState.lobbyRoomId;
        final isCurrent = room.roomId == hubState.currentRoomId;
        final canManage =
            !isLobby &&
            (hubState.isGlobalAdmin || client.isRoomAdminOf(room.roomId));

        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  room.isLocked
                      ? Icons.lock_outlined
                      : Icons.meeting_room_outlined,
                  size: 20,
                  color: isCurrent ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              if (isCurrent)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            isLobby ? 'Lobby'.tl : room.roomName,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${room.participantCount} ${"members".tl}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.toOpacity(0.5),
                ),
              ),
              if (room.announcements.isNotEmpty)
                Text(
                  room.announcements.first,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.primary.toOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  onPressed: () => _showRoomSettingsSheet(context, ref, room),
                ),
              if (!isCurrent)
                TextButton(
                  child: Text('Join'.tl),
                  onPressed: () async {
                    if (room.isLocked) {
                      final pwd = await _showPasswordDialog(context);
                      if (pwd == null) return;
                      client.joinRoom(room.roomId, password: pwd);
                    } else {
                      client.joinRoom(room.roomId);
                    }
                  },
                )
              else
                TextButton(
                  child: Text('Chat'.tl, style: TextStyle(color: cs.primary)),
                  onPressed: () => _openChat(
                    context,
                    roomId: room.roomId,
                    roomName: isLobby ? 'Lobby'.tl : room.roomName,
                  ),
                ),
            ],
          ),
          onTap: isCurrent
              ? () => _openChat(
                  context,
                  roomId: room.roomId,
                  roomName: isLobby ? 'Lobby'.tl : room.roomName,
                )
              : null,
        );
      },
    );
  }

  void _openChat(
    BuildContext context, {
    required String roomId,
    required String roomName,
  }) {
    showPopUpWidget(context, HubChatPage(roomId: roomId, roomName: roomName));
  }

  Future<String?> _showPasswordDialog(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Room Password'.tl),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Password'.tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: Text('OK'.tl),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateRoomDialog(
    BuildContext context,
    HubClient client,
  ) async {
    final result = await showCreateRoomDialog();
    if (result == null) return;
    client.createRoom(
      result.name,
      password: result.password,
      announcement: result.announcement,
      maxParticipants: result.maxParticipants,
    );
  }

  void _showRoomSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    HubRoomDto room,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RoomSettingsSheet(room: room),
    );
  }
}

// ── 房间设置 Sheet ────────────────────────────────────────────────────────────

class _RoomSettingsSheet extends ConsumerWidget {
  final HubRoomDto room;

  const _RoomSettingsSheet({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(hubClientProvider);
    final hubState = ref.read(hubProvider);
    final isGlobal = hubState.isGlobalAdmin;
    final isRoomAdmin = client.isRoomAdminOf(room.roomId);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, sc) => Column(
        children: [
          _SheetHeader(title: room.roomName, icon: Icons.settings_outlined),
          Expanded(
            child: ListView(
              controller: sc,
              children: [
                if (isRoomAdmin || isGlobal) ...[
                  ListTile(
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text('Set Announcement'.tl),
                    onTap: () {
                      Navigator.pop(context);
                      _showAnnouncementDialog(context, client);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text('Set Password'.tl),
                    onTap: () {
                      Navigator.pop(context);
                      _showPasswordDialog(context, client);
                    },
                  ),
                ],
                if (isGlobal) ...[
                  ListTile(
                    leading: const Icon(Icons.manage_accounts_outlined),
                    title: Text('Room Admins'.tl),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAdminsSheet(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.block_outlined),
                    title: Text('Room Bans'.tl),
                    subtitle: Text(
                      '${room.bannedUserIds.length} ${"banned".tl}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showBansSheet(context, ref),
                  ),
                ],
                if (!isGlobal && room.ownerUserId == hubState.myId)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Delete Room'.tl,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () {
                      client.deleteRoom(room.roomId);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context, HubClient client) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Announcement'.tl),
        content: TextField(controller: ctrl, maxLines: 3, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                client.setAnnouncement(ctrl.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text('Send'.tl),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, HubClient client) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Room Password'.tl),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Leave empty to remove'.tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () {
              client.setRoomPassword(
                ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
              );
              Navigator.pop(context);
            },
            child: Text('OK'.tl),
          ),
        ],
      ),
    );
  }

  void _showAdminsSheet(BuildContext context, WidgetRef ref) {
    final client = ref.read(hubClientProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: 'Room Admins'.tl,
              icon: Icons.manage_accounts_outlined,
            ),
            ...ref.read(hubProvider).onlineClients.map((c) {
              final isAdmin = room.moderatorIds.contains(c.userId);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: hubAvatarColor(c.userId),
                  child: Text(
                    hubInitials(c.displayName),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                title: Text(c.displayName),
                trailing: Switch(
                  value: isAdmin,
                  onChanged: (val) {
                    client.setRoomAdmin(c.userId, value: val);
                    setSS(() {});
                  },
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showBansSheet(BuildContext context, WidgetRef ref) {
    final client = ref.read(hubClientProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(title: 'Room Bans'.tl, icon: Icons.block_outlined),
            if (room.bannedUserIds.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No banned users'.tl),
              )
            else
              ...room.bannedUserIds.map(
                (id) => ListTile(
                  title: Text(id),
                  trailing: IconButton(
                    icon: const Icon(Icons.lock_open_outlined, size: 18),
                    onPressed: () {
                      client.roomUnban(id);
                      setSS(() {});
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
}

// ── People Tab ────────────────────────────────────────────────────────────────

class _PeopleTab extends ConsumerWidget {
  final HubState hubState;

  const _PeopleTab({required this.hubState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final people = hubState.onlineClients;

    if (people.isEmpty) {
      return Center(
        child: Text(
          'No one online'.tl,
          style: TextStyle(color: cs.onSurface.toOpacity(0.4)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: people.length,
      itemBuilder: (context, i) {
        final c = people[i];
        final isMe = c.userId == hubState.myId;

        // 当前房间名
        final room = hubState.roomList.firstWhereOrNull(
          (r) => r.participants.any((p) => p.userId == c.userId),
        );
        final roomLabel = room == null
            ? ''
            : (room.roomId == hubState.lobbyRoomId
                  ? 'Lobby'.tl
                  : room.roomName);

        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: hubAvatarColor(c.userId),
                child: Text(
                  hubInitials(c.displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(c.onlineStatus),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Text(
                c.displayName,
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (c.isGlobalAdmin) ...[
                const SizedBox(width: 4),
                const Text('👑', style: TextStyle(fontSize: 12)),
              ],
              if (c.isMuted) ...[
                const SizedBox(width: 4),
                const Text('🔇', style: TextStyle(fontSize: 12)),
              ],
            ],
          ),
          subtitle: Text(
            roomLabel,
            style: TextStyle(fontSize: 11, color: cs.onSurface.toOpacity(0.45)),
          ),
          trailing: isMe
              ? Text('Me'.tl, style: TextStyle(fontSize: 12, color: cs.primary))
              : _PeopleActions(client: c, hubState: hubState),
          onTap: isMe ? null : () => _openDm(context, c),
        );
      },
    );
  }

  Color _statusColor(UserStatus status) {
    return switch (status) {
      UserStatus.online => Colors.greenAccent.shade400,
      UserStatus.away => Colors.orangeAccent,
      UserStatus.busy => Colors.redAccent,
      UserStatus.offline => Colors.grey,
    };
  }

  void _openDm(BuildContext context, HubClientDto c) {
    showPopUpWidget(
      context,
      HubChatPage(dmUserId: c.userId, dmUserName: c.displayName),
    );
  }
}

// ── 人员操作按钮 ──────────────────────────────────────────────────────────────

class _PeopleActions extends ConsumerWidget {
  final HubClientDto client;
  final HubState hubState;

  const _PeopleActions({required this.client, required this.hubState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.read(hubClientProvider);
    final cs = Theme.of(context).colorScheme;
    final canManage =
        hubState.isGlobalAdmin || hub.isRoomAdminOf(hubState.currentRoomId);
    final isBlocked = hub.isBlocked(client.userId);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // DM 按钮
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          tooltip: 'Direct Message'.tl,
          onPressed: () => showPopUpWidget(
            context,
            HubChatPage(
              dmUserId: client.userId,
              dmUserName: client.displayName,
            ),
          ),
        ),
        // 屏蔽
        IconButton(
          icon: Icon(
            isBlocked ? Icons.volume_off : Icons.volume_off_outlined,
            size: 18,
            color: isBlocked ? cs.error : null,
          ),
          tooltip: isBlocked ? 'Unblock'.tl : 'Block'.tl,
          onPressed: () {
            isBlocked
                ? hub.unblockUser(client.userId)
                : hub.blockUser(client.userId);
          },
        ),
        // 管理菜单
        if (canManage)
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18),
            onPressed: () => _showManageSheet(context, hub, cs),
          ),
      ],
    );
  }

  void _showManageSheet(BuildContext context, HubClient hub, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: hubAvatarColor(client.userId),
                    child: Text(
                      hubInitials(client.displayName),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    client.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 禁言
            ListTile(
              leading: Icon(
                client.isMuted ? Icons.mic : Icons.mic_off_outlined,
                color: client.isMuted ? cs.error : null,
              ),
              title: Text(client.isMuted ? 'Unmute'.tl : 'Mute'.tl),
              onTap: () {
                Navigator.pop(context);
                if (client.isMuted) {
                  hub.unmute(client.userId);
                } else {
                  _showMuteDurationSheet(context, hub);
                }
              },
            ),
            // T出房间
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text('Kick'.tl),
              onTap: () {
                Navigator.pop(context);
                hub.kickFromRoom(client.userId);
              },
            ),
            // 封禁
            ListTile(
              leading: Icon(Icons.block_outlined, color: cs.error),
              title: Text('Room Ban'.tl, style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(context);
                hub.roomBan(client.userId);
              },
            ),
            if (hubState.isGlobalAdmin) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  hubState.serverBannedIds.contains(client.userId)
                      ? Icons.lock_open_outlined
                      : Icons.block,
                  color: cs.error,
                ),
                title: Text(
                  hubState.serverBannedIds.contains(client.userId)
                      ? 'Server Unban'.tl
                      : 'Server Ban'.tl,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  hubState.serverBannedIds.contains(client.userId)
                      ? hub.serverUnban(client.userId)
                      : hub.serverBan(client.userId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMuteDurationSheet(BuildContext context, HubClient hub) {
    const presets = [
      (label: '1 min', seconds: 60),
      (label: '5 min', seconds: 300),
      (label: '10 min', seconds: 600),
      (label: '30 min', seconds: 1800),
      (label: '1 hour', seconds: 3600),
    ];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: 'Mute Duration'.tl,
              icon: Icons.mic_off_outlined,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets
                    .map(
                      (p) => ActionChip(
                        label: Text(p.label),
                        onPressed: () {
                          Navigator.pop(context);
                          hub.mute(client.userId, seconds: p.seconds);
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet Header 复用 ─────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SheetHeader({required this.title, this.icon});

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
