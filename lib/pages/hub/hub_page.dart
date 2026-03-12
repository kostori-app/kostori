import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/services/services.dart';
import 'package:kostori/foundation/widget_utils.dart';
import 'package:kostori/pages/hub/hub_chat_page.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/hub/hub_create_room_dialog.dart';
import 'package:kostori/pages/hub/hub_room_settings_sheet.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

void showHubDialog(BuildContext context) {
  showPopUpWidget(context, const HubPage());
}

// ─────────────────────────────────────────────────────────────────────────────
// HubPage
// ─────────────────────────────────────────────────────────────────────────────

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
    final client = ref.read(hubClientProvider);
    final totalUnread = client.dmUnread.values.fold(0, (a, b) => a + b);

    return PopUpWidgetScaffold(
      title: 'Hub',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Members'.tl),
                    if (totalUnread > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$totalUnread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [_RoomsTab(), _PeopleTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rooms Tab
// ─────────────────────────────────────────────────────────────────────────────

class _RoomsTab extends ConsumerWidget {
  const _RoomsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.read(hubClientProvider);
    final hubState = ref.watch(hubProvider);
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
                  onPressed: () => showHubRoomSettingsSheet(context, room, ref),
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
      builder: (ctx) => ContentDialog(
        title: 'Room Password'.tl,
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Password'.tl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// People Tab
// ─────────────────────────────────────────────────────────────────────────────

class _PeopleTab extends ConsumerWidget {
  const _PeopleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final hubState = ref.watch(hubProvider);
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

        final room = hubState.roomList.firstWhereOrNull(
          (r) => r.participants.any((p) => p.userId == c.userId),
        );
        final roomLabel = room == null
            ? ''
            : (room.roomId == hubState.lobbyRoomId
                  ? 'Lobby'.tl
                  : room.roomName);
        final client = ref.read(hubClientProvider);
        final unread = client.dmUnread[c.userId] ?? 0;
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
              if (unread > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.error,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.surface, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
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
          onTap: isMe
              ? null
              : () {
                  // 清空未读
                  if (unread > 0) {
                    ref.read(hubProvider.notifier).update((s) {
                      final updated = Map<String, int>.from(s.dmUnread)
                        ..remove(c.userId);
                      return s.copyWith(dmUnread: updated);
                    });
                  }
                  _openDm(context, c);
                },
        );
      },
    );
  }

  Color _statusColor(UserStatus status) => switch (status) {
    UserStatus.online => Colors.greenAccent.shade400,
    UserStatus.away => Colors.orangeAccent,
    UserStatus.busy => Colors.redAccent,
    UserStatus.offline => Colors.grey,
  };

  void _openDm(BuildContext context, HubClientDto c) {
    showPopUpWidget(
      context,
      HubChatPage(dmUserId: c.userId, dmUserName: c.displayName),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// People Actions
// ─────────────────────────────────────────────────────────────────────────────

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
      backgroundColor: Colors.transparent,
      builder: (_) => HubSheet(
        title: client.displayName,
        icon: Icons.manage_accounts_outlined,
        initialSize: 0.45,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(
                client.isMuted ? Icons.mic : Icons.mic_off_outlined,
                color: client.isMuted ? cs.error : null,
              ),
              title: Text(client.isMuted ? 'Unmute'.tl : 'Mute'.tl),
              onTap: () {
                Navigator.pop(ctx);
                if (client.isMuted) {
                  hub.unmute(client.userId);
                } else {
                  _showMuteDurationSheet(context, hub);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.logout),
              title: Text('Kick'.tl),
              onTap: () {
                Navigator.pop(ctx);
                hub.kickFromRoom(client.userId);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(Icons.block_outlined, color: cs.error),
              title: Text('Room Bans'.tl, style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(ctx);
                hub.roomBan(client.userId);
              },
            ),
            if (hubState.isGlobalAdmin) ...[
              const HubSettingDivider(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(
                  hubState.serverBannedIds.contains(client.userId)
                      ? Icons.lock_open_outlined
                      : Icons.block,
                  color: cs.error,
                ),
                title: Text(
                  hubState.serverBannedIds.contains(client.userId)
                      ? 'Remove from Blacklist'.tl
                      : 'Add to Blacklist'.tl,
                  style: TextStyle(color: cs.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
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
      backgroundColor: Colors.transparent,
      builder: (_) => HubSheet(
        title: 'Mute Duration'.tl,
        icon: Icons.mic_off_outlined,
        initialSize: 0.35,
        builder: (ctx, sc) => Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map(
                  (p) => ActionChip(
                    label: Text(p.label),
                    onPressed: () {
                      Navigator.pop(ctx);
                      hub.mute(client.userId, seconds: p.seconds);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
