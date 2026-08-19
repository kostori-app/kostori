import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/utils/ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 公共入口（合并了原 showHubRoomSettingsSheet 和 AdminPanelSheet）
// ─────────────────────────────────────────────────────────────────────────────

void showHubRoomSettingsSheet(BuildContext context, HubRoomDto room) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 3 / 4,
    ),
    builder: (_) => _RoomSettingsSheet(room: room),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 统一 Sheet（Tab 布局，权限决定 tab 数量和内容）
// ─────────────────────────────────────────────────────────────────────────────

class _RoomSettingsSheet extends ConsumerStatefulWidget {
  final HubRoomDto room;

  const _RoomSettingsSheet({required this.room});

  @override
  ConsumerState<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends ConsumerState<_RoomSettingsSheet>
    with SingleTickerProviderStateMixin {
  HubRoomDto get _room => ref
      .watch(hubProvider)
      .roomList
      .firstWhere(
        (r) => r.roomId == widget.room.roomId,
        orElse: () => widget.room,
      );
  late TabController _tabCtrl;

  HubState get _hs => ref.watch(hubProvider);

  HubClient get _client => ref.read(hubClientProvider);

  bool get _isGlobal => _hs.isGlobalAdmin;

  bool get _isRoomAdmin => _client.isRoomAdminOf(_room.roomId);

  bool get _canEdit => (_isGlobal || _isRoomAdmin);

  bool get _cantEditLobby =>
      _canEdit && _room.roomId != '6ba7b810-9dad-11d1-80b4-00c04fd430c8';

  bool get _isOwner => _room.ownerUserId == _hs.myId;

  bool _editingWelcome = false;
  late final TextEditingController _welcomeCtrl;

  bool _editingPassword = false;
  late final TextEditingController _passwordCtrl;

  @override
  void initState() {
    super.initState();
    final room = ref
        .read(hubProvider)
        .roomList
        .firstWhere(
          (r) => r.roomId == widget.room.roomId,
          orElse: () => widget.room,
        );
    _welcomeCtrl = TextEditingController(text: room.welcomeMessage ?? '');
    _passwordCtrl = TextEditingController();

    final hs = ref.read(hubProvider);
    final isGlobal = hs.isGlobalAdmin;
    final client = ref.read(hubClientProvider);
    final isRoomAdmin = client.isRoomAdminOf(room.roomId);
    final canEdit = isGlobal || isRoomAdmin;
    final tabCount = isGlobal ? 3 : (canEdit ? 2 : 1);

    _tabCtrl = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _welcomeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _patchRoom(HubRoomDto updated) {
    final hs = _hs;
    ref.read(hubProvider.notifier).state = hs.copyWith(
      roomList: hs.roomList.map((r) {
        if (r.roomId != updated.roomId) return r;
        return updated;
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: cs.surface,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.toOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
                child: Row(
                  children: [
                    Icon(
                      _isGlobal
                          ? Icons.admin_panel_settings_outlined
                          : Icons.settings_outlined,
                      size: 18,
                      color: cs.onSurface.toOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isGlobal ? t.adminPanel : _room.roomName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_cantEditLobby)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: cs.error,
                        ),
                        tooltip: t.deleteRoom,
                        onPressed: () => ContentDialog.show(
                          context: context,
                          title: t.deleteRoom,
                          content: Text(
                            t.areYouSureYouWantToDeleteR(r: _room.roomName),
                          ),
                          actions: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error,
                                side: BorderSide(
                                  color: cs.error.toOpacity(0.4),
                                ),
                              ),
                              onPressed: () {
                                _client.deleteRoom(_room.roomId);
                                Navigator.of(App.rootContext).pop();
                                Navigator.pop(context);
                              },
                              label: Text(t.delete),
                            ),
                          ],
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // tab bar
              TabBar(
                controller: _tabCtrl,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: cs.outlineVariant.toOpacity(0.4),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 15),
                        const SizedBox(width: 6),
                        Text(t.room),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 15),
                        const SizedBox(width: 6),
                        Text(t.membersList),
                      ],
                    ),
                  ),
                  if (_isGlobal)
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dns_outlined, size: 15),
                          const SizedBox(width: 6),
                          Text(t.server),
                        ],
                      ),
                    ),
                ],
              ),
              // tab content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildRoomTab(context, cs),
                    _buildMembersTab(context, cs),
                    if (_isGlobal) _buildServerTab(context, cs),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomTab(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        HubSettingSection(icon: Icons.home_max_outlined, title: t.room),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(Icons.tag, size: 20, color: cs.primary),
          title: Text(t.roomName, style: const TextStyle(fontSize: 12)),
          subtitle: Text(
            _room.roomId == _hs.lobbyRoomId ? t.lobby : _room.roomName,
            style: TextStyle(fontSize: 14, color: cs.onSurface),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(Icons.numbers, size: 20, color: cs.primary),
          title: Text(t.roomId, style: const TextStyle(fontSize: 12)),
          subtitle: Text(
            _room.roomId,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface,
              fontFamily: 'monospace',
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.copy_outlined, size: 16),
            tooltip: t.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _room.roomId));
              App.rootContext.showMessage(message: t.copySuccess);
            },
          ),
        ),
        HubSettingSection(
          icon: Icons.campaign_outlined,
          title: t.announcements,
        ),
        if (_room.announcements.isEmpty)
          HubEmptyHint(t.noAnnouncementsYet)
        else
          ..._room.announcements.asMap().entries.map(
            (e) => _AnnouncementTile(
              text: e.value,
              canDelete: _canEdit,
              onDelete: () {
                _client.removeAnnouncement(e.key);
                _patchRoom(
                  _room.copyWith(
                    announcements: List.from(_room.announcements)
                      ..removeAt(e.key),
                  ),
                );
              },
            ),
          ),
        if (_canEdit)
          _AddTile(
            label: t.addAnnouncement,
            onTap: () => _showAddAnnouncementDialog(context),
          ),

        HubSettingSection(
          icon: Icons.waving_hand_outlined,
          title: t.welcomeMessage,
        ),
        if (!_editingWelcome)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              _welcomeCtrl.text.isNotEmpty
                  ? _welcomeCtrl.text
                  : t.noWelcomeMessage,
              style: TextStyle(
                fontSize: 13,
                color: _welcomeCtrl.text.isNotEmpty
                    ? cs.onSurface.toOpacity(0.8)
                    : cs.onSurface.toOpacity(0.35),
                fontStyle: FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _canEdit
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: t.edit,
                        onPressed: () => setState(() => _editingWelcome = true),
                      ),
                      if (_welcomeCtrl.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: cs.error,
                          ),
                          tooltip: t.remove,
                          onPressed: () {
                            _client.setWelcomeMessage(null);
                            setState(() => _welcomeCtrl.clear());
                            _patchRoom(_room.copyWith(welcomeMessage: null));
                          },
                        ),
                    ],
                  )
                : null,
          )
        else
          _InlineEditField(
            controller: _welcomeCtrl,
            hint: t.enterWelcomeMessage,
            maxLines: 3,
            onCancel: () => setState(() => _editingWelcome = false),
            onSave: () {
              final msg = _welcomeCtrl.text.trim();
              _client.setWelcomeMessage(msg.isEmpty ? null : msg);
              _patchRoom(
                _room.copyWith(welcomeMessage: msg.isEmpty ? null : msg),
              );
              setState(() => _editingWelcome = false);
            },
          ),

        if (_cantEditLobby) ...[
          HubSettingSection(icon: Icons.lock_outline, title: t.security),
          if (!_editingPassword)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(
                _room.isLocked ? Icons.lock_outlined : Icons.lock_open_outlined,
                size: 20,
                color: _room.isLocked
                    ? cs.primary
                    : cs.onSurface.toOpacity(0.4),
              ),
              title: Text(
                _room.isLocked ? t.passwordProtected : t.noPasswordSet,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: _room.isLocked ? t.changePassword : t.setPassword,
                    onPressed: () => setState(() {
                      _editingPassword = true;
                      _passwordCtrl.clear();
                    }),
                  ),
                  if (_room.isLocked)
                    IconButton(
                      icon: Icon(
                        Icons.no_encryption_outlined,
                        size: 18,
                        color: cs.error,
                      ),
                      tooltip: t.removePassword,
                      onPressed: () {
                        _client.setRoomPassword(null);
                        _patchRoom(_room.copyWith(isLocked: false));
                      },
                    ),
                ],
              ),
            )
          else
            _InlineEditField(
              controller: _passwordCtrl,
              hint: 'New password (empty to remove)',
              obscureText: true,
              onCancel: () => setState(() => _editingPassword = false),
              onSave: () {
                final pwd = _passwordCtrl.text.trim();
                _client.setRoomPassword(pwd.isEmpty ? null : pwd);
                _patchRoom(_room.copyWith(isLocked: pwd.isNotEmpty));
                setState(() => _editingPassword = false);
              },
            ),
        ],

        if (_isOwner && !_isGlobal) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
              label: Text(t.deleteRoom, style: TextStyle(color: cs.error)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.error.toOpacity(0.4)),
              ),
              onPressed: () {
                _client.deleteRoom(_room.roomId);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMembersTab(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (_isGlobal) ...[
          HubSettingSection(
            icon: Icons.manage_accounts_outlined,
            title: t.roomAdmins,
          ),
          if (_room.moderatorIds.isEmpty)
            HubEmptyHint(t.noAdminsYet)
          else
            ..._room.moderatorIds.map((id) {
              final c = _hs.onlineClients.firstWhereOrNull(
                (c) => c.userId == id,
              );
              return HubClientTile(
                name: c?.displayName ?? id,
                avatarUrl: c?.avatarUrl,
                userId: id,
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  tooltip: t.removeAdmin,
                  onPressed: () {
                    _client.setRoomAdmin(id, value: false);
                    _patchRoom(
                      _room.copyWith(
                        moderatorIds: List.from(_room.moderatorIds)..remove(id),
                      ),
                    );
                  },
                ),
              );
            }),
          _AddTile(
            label: t.addRoomAdmin,
            onTap: () => _showPickMemberDialog(context, isAdminPicker: true),
          ),
        ],

        if (_cantEditLobby) ...[
          HubSettingSection(icon: Icons.block_outlined, title: t.roomBans),
          if (_room.bannedUserIds.isEmpty)
            HubEmptyHint(t.noBannedMembers)
          else
            ..._room.bannedUserIds.map((id) {
              final c = _hs.onlineClients.firstWhereOrNull(
                (c) => c.userId == id,
              );
              return HubClientTile(
                name: c?.displayName ?? id,
                avatarUrl: c?.avatarUrl,
                userId: id,
                trailing: IconButton(
                  icon: const Icon(Icons.lock_open_outlined, size: 18),
                  tooltip: t.unban,
                  onPressed: () {
                    _client.roomUnban(id);
                    _patchRoom(
                      _room.copyWith(
                        bannedUserIds: List.from(_room.bannedUserIds)
                          ..remove(id),
                      ),
                    );
                  },
                ),
              );
            }),
          _AddTile(
            label: t.banMember,
            icon: Icons.person_off_outlined,
            onTap: () => _showPickMemberDialog(context, isAdminPicker: false),
          ),
        ],
        if (_cantEditLobby) ...[
          HubSettingSection(icon: Icons.person_add_outlined, title: t.invite),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              t.allowMemberInvites,
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              t.letAllMembersInviteOthers,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Opacity(
              opacity: _canEdit ? 1 : 0.4,
              child: IgnorePointer(
                ignoring: !_canEdit,
                child: CustomSwitch(
                  value: _room.allowMemberInvite,
                  onChanged: (v) {
                    _client.setAllowMemberInvite(v);
                    _patchRoom(_room.copyWith(allowMemberInvite: v));
                  },
                ),
              ),
            ),
          ),
        ],
        if (_canEdit) ...[
          HubSettingSection(
            icon: Icons.person_add_outlined,
            title: t.inviteToRoom,
          ),
          ...() {
            final inRoom = _room.participants.map((p) => p.userId).toSet();
            final available = _hs.onlineClients
                .where((c) => !inRoom.contains(c.userId))
                .toList();
            if (available.isEmpty) {
              return [HubEmptyHint(t.noUsersAvailableToInvite)];
            }
            return available
                .map(
                  (c) => HubClientTile(
                    name: c.displayName,
                    avatarUrl: c.avatarUrl,
                    userId: c.userId,
                    trailing: IconButton(
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      tooltip: t.invite,
                      onPressed: () {
                        _client.inviteToRoom(c.userId, _room.roomId);
                        App.rootContext.showMessage(
                          message: '${c.displayName} ${t.invited}',
                        );
                      },
                    ),
                  ),
                )
                .toList();
          }(),
        ],
        HubSettingSection(
          icon: Icons.people_outline,
          title: '${t.onlineUsersList} (${_room.participants.length})',
        ),
        if (_room.participants.isEmpty)
          HubEmptyHint(t.noUsersOnline)
        else
          ..._room.participants.map(
            (c) => _AdminUserTile(
              client: c,
              hs: _hs,
              hubClient: _client,
              onChanged: () => setState(() {}),
              canEdit: _canEdit,
            ),
          ),
      ],
    );
  }

  Widget _buildServerTab(BuildContext context, ColorScheme cs) {
    final hs = _hs;
    final onlineCount = hs.onlineClients.length;
    final roomCount = hs.roomList.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer.toOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.toOpacity(0.15)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.people_outline,
                  label: '$onlineCount',
                  sub: t.online,
                  color: cs.primary,
                ),
                const SizedBox(width: 20),
                _StatChip(
                  icon: Icons.meeting_room_outlined,
                  label: '$roomCount',
                  sub: t.rooms,
                  color: cs.tertiary,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      t.managing,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.toOpacity(0.45),
                      ),
                    ),
                    Text(
                      _room.roomId == hs.lobbyRoomId ? t.lobby : _room.roomName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        HubSettingSection(
          icon: Icons.gpp_bad_outlined,
          title: t.serverBlacklist,
        ),
        if (hs.serverBannedIds.isEmpty)
          HubEmptyHint(t.noBannedUsers)
        else
          ...hs.serverBannedIds.map(
            (id) => HubClientTile(
              name: id,
              userId: id,
              trailing: IconButton(
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                tooltip: t.unban,
                onPressed: () {
                  _client.serverUnban(id);
                  setState(() {});
                },
              ),
            ),
          ),

        HubSettingSection(icon: Icons.people_outline, title: t.onlineUsersList),
        if (hs.onlineClients.isEmpty)
          HubEmptyHint(t.noUsersOnline)
        else
          ...hs.onlineClients.map(
            (c) => _AdminUserTile(
              client: c,
              hs: hs,
              hubClient: _client,
              onChanged: () => setState(() {}),
              canEdit: _canEdit,
            ),
          ),
      ],
    );
  }

  void _showAddAnnouncementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _HubInputDialog(
        title: t.addAnnouncement,
        hint: t.enterAnnouncementText,
        maxLines: 3,
        confirmLabel: t.add,
        onConfirm: (text) {
          if (text.isEmpty) return;
          _client.setAnnouncement(text);
          _patchRoom(
            _room.copyWith(announcements: [..._room.announcements, text]),
          );
        },
      ),
    );
  }

  void _showPickMemberDialog(
    BuildContext context, {
    required bool isAdminPicker,
  }) {
    final myId = _hs.myId;
    final available = _room.participants
        .where(
          (c) =>
              c.userId != myId &&
              c.userId != _room.ownerUserId &&
              (isAdminPicker ? !_room.moderatorIds.contains(c.userId) : true),
        )
        .toList();

    showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: isAdminPicker ? t.addRoomAdmin : t.banMember,
        displayButton: false,
        content: available.isEmpty
            ? Text(t.noMembersAvailable)
            : SizedBox(
                width: 320,
                child: ListView(
                  shrinkWrap: true,
                  children: available
                      .map(
                        (c) => HubClientTile(
                          name: c.displayName,
                          avatarUrl: c.avatarUrl,
                          userId: c.userId,
                          onTap: () {
                            Navigator.pop(context);
                            if (isAdminPicker) {
                              _client.setRoomAdmin(c.userId, value: true);
                              _patchRoom(
                                _room.copyWith(
                                  moderatorIds: List.from(_room.moderatorIds)
                                    ..add(c.userId),
                                ),
                              );
                            } else {
                              _client.roomBan(c.userId);
                              _patchRoom(
                                _room.copyWith(
                                  bannedUserIds: List.from(_room.bannedUserIds)
                                    ..add(c.userId),
                                ),
                              );
                            }
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

class _AnnouncementTile extends StatelessWidget {
  final String text;
  final bool canDelete;
  final VoidCallback onDelete;

  const _AnnouncementTile({
    required this.text,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(Icons.fiber_manual_record, size: 8, color: cs.tertiary),
      title: Text(text, style: const TextStyle(fontSize: 13)),
      trailing: canDelete
          ? IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: cs.onSurface.toOpacity(0.4),
              ),
              onPressed: onDelete,
            )
          : null,
    );
  }
}

class _AddTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddTile({
    required this.label,
    required this.onTap,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, size: 18, color: cs.primary),
      title: Text(label, style: TextStyle(fontSize: 13, color: cs.primary)),
      onTap: onTap,
    );
  }
}

class _HubInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final int maxLines;
  final String confirmLabel;
  final void Function(String text) onConfirm;

  const _HubInputDialog({
    required this.title,
    required this.hint,
    required this.onConfirm,
    this.maxLines = 1,
    this.confirmLabel = '',
  });

  @override
  State<_HubInputDialog> createState() => _HubInputDialogState();
}

class _HubInputDialogState extends State<_HubInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _ctrl.text.trim();
    Navigator.pop(context);
    widget.onConfirm(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.confirmLabel.isEmpty ? t.save : widget.confirmLabel;

    return ContentDialog(
      title: widget.title,
      content: TextField(
        controller: _ctrl,
        maxLines: widget.maxLines,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.outline.toOpacity(0.3)),
          ),
          filled: true,
          fillColor: cs.surfaceContainerHighest.toOpacity(0.5),
        ),
      ),
      actions: [Button.filled(onPressed: _submit, child: Text(label))],
    );
  }
}

class HubSettingSection extends StatelessWidget {
  final IconData icon;
  final String title;

  const HubSettingSection({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: cs.primary.toOpacity(0.8)),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary.toOpacity(0.8),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 带头像的成员 tile。
class HubClientTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? userId;
  final Widget? trailing;
  final VoidCallback? onTap;

  const HubClientTile({
    super.key,
    required this.name,
    this.avatarUrl,
    this.userId,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: hubAvatarColor(userId),
        child: hasAvatar
            ? ClipOval(
                child: AnimatedImage(
                  image: CachedImageProvider(avatarUrl!, sourceKey: 'hub'),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                hubInitials(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Text(name, style: const TextStyle(fontSize: 14)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// 空状态提示。
class HubEmptyHint extends StatelessWidget {
  final String text;

  const HubEmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.toOpacity(0.35),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color.toOpacity(0.8)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              sub,
              style: TextStyle(fontSize: 10, color: color.toOpacity(0.6)),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineEditField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final bool obscureText;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _InlineEditField({
    required this.controller,
    required this.hint,
    required this.onCancel,
    required this.onSave,
    this.maxLines = 1,
    this.obscureText = false,
  });

  @override
  State<_InlineEditField> createState() => _InlineEditFieldState();
}

class _InlineEditFieldState extends State<_InlineEditField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isObscure = widget.obscureText;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.controller,
            maxLines: isObscure ? 1 : widget.maxLines,
            obscureText: isObscure && _obscured,
            autofocus: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: cs.onSurface.toOpacity(0.35),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixIcon: isObscure
                  ? IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outline.toOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.outline.toOpacity(0.25)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.toOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.onCancel, child: Text(t.cancel)),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: widget.onSave, child: Text(t.save)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminUserTile extends StatefulWidget {
  final HubClientDto client;
  final HubState hs;
  final HubClient hubClient;
  final VoidCallback onChanged;
  final bool canEdit;

  const _AdminUserTile({
    required this.client,
    required this.hs,
    required this.hubClient,
    required this.onChanged,
    required this.canEdit,
  });

  @override
  State<_AdminUserTile> createState() => _AdminUserTileState();
}

class _AdminUserTileState extends State<_AdminUserTile> {
  bool _pokeCooling = false;

  void _poke() {
    if (_pokeCooling) return;
    widget.hubClient.poke(widget.client.userId);
    setState(() => _pokeCooling = true);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _pokeCooling = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = widget.client.userId == widget.hs.myId;
    final isBanned = widget.hs.serverBannedIds.contains(widget.client.userId);
    final avatarUrl = widget.client.avatarUrl;
    final client = widget.client;
    final canEdit = widget.canEdit;
    final hubClient = widget.hubClient;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: hubAvatarColor(client.userId),
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? ClipOval(
                child: AnimatedImage(
                  image: CachedImageProvider(avatarUrl, sourceKey: 'hub'),
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                hubInitials(client.displayName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              client.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (client.isGlobalAdmin) ...[
            const SizedBox(width: 4),
            const Text('👑', style: TextStyle(fontSize: 11)),
          ],
          if (client.isMuted) ...[
            const SizedBox(width: 4),
            const Text('🔇', style: TextStyle(fontSize: 11)),
          ],
        ],
      ),
      subtitle: Text(
        isMe ? t.youLabel : (isBanned ? t.banned : ''),
        style: TextStyle(
          fontSize: 11,
          color: isBanned ? cs.error : cs.onSurface.toOpacity(0.4),
        ),
      ),
      trailing: isMe
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 戳一戳
                IconButton(
                  icon: Icon(
                    Icons.touch_app_outlined,
                    size: 18,
                    color: _pokeCooling ? cs.onSurface.toOpacity(0.3) : null,
                  ),
                  tooltip: t.poke,
                  onPressed: _pokeCooling ? null : _poke,
                ),
                if (canEdit && !client.isGlobalAdmin)
                  IconButton(
                    icon: Icon(
                      client.isMuted ? Icons.mic : Icons.mic_off_outlined,
                      size: 18,
                      color: client.isMuted ? cs.error : null,
                    ),
                    tooltip: client.isMuted ? t.unmute : t.mute,
                    onPressed: () {
                      if (client.isMuted) {
                        hubClient.unmute(client.userId);
                      } else {
                        hubClient.mute(client.userId, seconds: 300);
                      }
                      widget.onChanged();
                    },
                  ),
                if (canEdit && !client.isGlobalAdmin)
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18),
                    tooltip: t.kick,
                    onPressed: () {
                      hubClient.kickFromRoom(client.userId);
                      widget.onChanged();
                    },
                  ),
                if (canEdit && !client.isGlobalAdmin)
                  IconButton(
                    icon: Icon(
                      isBanned
                          ? Icons.lock_open_outlined
                          : Icons.block_outlined,
                      size: 18,
                      color: isBanned ? cs.primary : cs.error.toOpacity(0.7),
                    ),
                    tooltip: isBanned
                        ? t.removeFromBlacklist
                        : t.addToBlacklist,
                    onPressed: () {
                      isBanned
                          ? hubClient.serverUnban(client.userId)
                          : hubClient.serverBan(client.userId);
                      widget.onChanged();
                    },
                  ),
              ],
            ),
    );
  }
}
