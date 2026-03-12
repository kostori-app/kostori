import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/services/services.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 公共入口（合并了原 showHubRoomSettingsSheet 和 AdminPanelSheet）
// ─────────────────────────────────────────────────────────────────────────────

void showHubRoomSettingsSheet(
  BuildContext context,
  HubRoomDto room,
  WidgetRef ref,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RoomSettingsSheet(room: room, ref: ref),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 统一 Sheet（Tab 布局，权限决定 tab 数量和内容）
// ─────────────────────────────────────────────────────────────────────────────

class _RoomSettingsSheet extends StatefulWidget {
  final HubRoomDto room;
  final WidgetRef ref;

  const _RoomSettingsSheet({required this.room, required this.ref});

  @override
  State<_RoomSettingsSheet> createState() => _RoomSettingsSheetState();
}

class _RoomSettingsSheetState extends State<_RoomSettingsSheet>
    with SingleTickerProviderStateMixin {
  late HubRoomDto _room;
  late TabController _tabCtrl;

  HubClient get _client => widget.ref.read(hubClientProvider);

  HubState get _hs => widget.ref.read(hubProvider);

  bool get _isGlobal => _hs.isGlobalAdmin;

  bool get _isRoomAdmin => _client.isRoomAdminOf(_room.roomId);

  bool get _canEdit => _isGlobal || _isRoomAdmin;

  bool get _isOwner => _room.ownerUserId == _hs.myId;

  bool _editingWelcome = false;
  late final TextEditingController _welcomeCtrl;

  bool _editingPassword = false;
  late final TextEditingController _passwordCtrl;

  int get _tabCount => _isGlobal ? 3 : (_canEdit ? 2 : 1);

  @override
  void initState() {
    super.initState();
    _room = widget.room;
    _welcomeCtrl = TextEditingController(text: _room.welcomeMessage ?? '');
    _passwordCtrl = TextEditingController();
    _tabCtrl = TabController(length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _welcomeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _patchRoom(HubRoomDto updated) {
    setState(() => _room = updated);
    final hs = _hs;
    widget.ref.read(hubProvider.notifier).state = hs.copyWith(
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
        child: DraggableScrollableSheet(
          initialChildSize: _isGlobal ? 0.75 : 0.65,
          maxChildSize: 0.92,
          minChildSize: 0.3,
          expand: false,
          builder: (context, _) => Column(
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
                        _isGlobal ? 'Admin Panel'.tl : _room.roomName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_isOwner || _isGlobal)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: cs.error,
                        ),
                        tooltip: 'Delete Room'.tl,
                        onPressed: () => ContentDialog.show(
                          context: context,
                          title: 'Delete Room'.tl,
                          content: Text(
                            'Are you sure you want to delete @r? This cannot be undone.'
                                .tlParams({'r': _room.roomName}),
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
                              label: Text('Delete'.tl),
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
                        Text('Room'.tl),
                      ],
                    ),
                  ),
                  if (_canEdit)
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 15),
                          const SizedBox(width: 6),
                          Text('Members'.tl),
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
                          Text('Server'.tl),
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
                    if (_canEdit) _buildMembersTab(context, cs),
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

  // ── Tab 1: Room ────────────────────────────────────────────────────────────

  Widget _buildRoomTab(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        HubSettingSection(
          icon: Icons.campaign_outlined,
          title: 'Announcements'.tl,
        ),
        if (_room.announcements.isEmpty)
          HubEmptyHint('No announcements yet'.tl)
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
            label: 'Add Announcement'.tl,
            onTap: () => _showAddAnnouncementDialog(context),
          ),

        const HubSettingDivider(),

        HubSettingSection(
          icon: Icons.waving_hand_outlined,
          title: 'Welcome Message'.tl,
        ),
        if (!_editingWelcome)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Text(
              _welcomeCtrl.text.isNotEmpty
                  ? _welcomeCtrl.text
                  : 'No welcome message'.tl,
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
                        tooltip: 'Edit'.tl,
                        onPressed: () => setState(() => _editingWelcome = true),
                      ),
                      if (_welcomeCtrl.text.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: cs.error,
                          ),
                          tooltip: 'Remove'.tl,
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
            hint: 'Enter welcome message shown to users who join...'.tl,
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

        if (_canEdit) ...[
          const HubSettingDivider(),
          HubSettingSection(icon: Icons.lock_outline, title: 'Security'.tl),
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
                _room.isLocked ? 'Password protected'.tl : 'No password set'.tl,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: _room.isLocked ? 'Change'.tl : 'Set password'.tl,
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
                      tooltip: 'Remove password'.tl,
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
              hint: 'New password (empty to remove)'.tl,
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
          const HubSettingDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
              label: Text('Delete Room'.tl, style: TextStyle(color: cs.error)),
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

  // ── Tab 2: Members ─────────────────────────────────────────────────────────

  Widget _buildMembersTab(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (_isGlobal) ...[
          HubSettingSection(
            icon: Icons.manage_accounts_outlined,
            title: 'Room Admins'.tl,
          ),
          if (_room.moderatorIds.isEmpty)
            HubEmptyHint('No admins yet'.tl)
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
                  tooltip: 'Remove Admin'.tl,
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
            label: 'Add Room Admin'.tl,
            onTap: () => _showPickMemberDialog(context, isAdminPicker: true),
          ),
          const HubSettingDivider(),
        ],

        HubSettingSection(icon: Icons.block_outlined, title: 'Room Bans'.tl),
        if (_room.bannedUserIds.isEmpty)
          HubEmptyHint('No banned members'.tl)
        else
          ..._room.bannedUserIds.map((id) {
            final c = _hs.onlineClients.firstWhereOrNull((c) => c.userId == id);
            return HubClientTile(
              name: c?.displayName ?? id,
              avatarUrl: c?.avatarUrl,
              userId: id,
              trailing: IconButton(
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                tooltip: 'Unban'.tl,
                onPressed: () {
                  _client.roomUnban(id);
                  _patchRoom(
                    _room.copyWith(
                      bannedUserIds: List.from(_room.bannedUserIds)..remove(id),
                    ),
                  );
                },
              ),
            );
          }),
        _AddTile(
          label: 'Ban Member'.tl,
          icon: Icons.person_off_outlined,
          onTap: () => _showPickMemberDialog(context, isAdminPicker: false),
        ),
        HubSettingSection(
          icon: Icons.people_outline,
          title: '${'Online Users'.tl} (${_room.participants.length})',
        ),
        if (_room.participants.isEmpty)
          HubEmptyHint('No users online'.tl)
        else
          ..._room.participants.map(
            (c) => _AdminUserTile(
              client: c,
              hs: _hs,
              hubClient: _client,
              onChanged: () => setState(() {}),
            ),
          ),
      ],
    );
  }

  // ── Tab 3: Server（仅全局管理员）─────────────────────────────────────────

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
                  sub: 'online'.tl,
                  color: cs.primary,
                ),
                const SizedBox(width: 20),
                _StatChip(
                  icon: Icons.meeting_room_outlined,
                  label: '$roomCount',
                  sub: 'rooms'.tl,
                  color: cs.tertiary,
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Managing'.tl,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.toOpacity(0.45),
                      ),
                    ),
                    Text(
                      _room.roomId == hs.lobbyRoomId
                          ? 'Lobby'.tl
                          : _room.roomName,
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

        const HubSettingDivider(),

        HubSettingSection(
          icon: Icons.gpp_bad_outlined,
          title: 'Server Blacklist'.tl,
        ),
        if (hs.serverBannedIds.isEmpty)
          HubEmptyHint('No banned users'.tl)
        else
          ...hs.serverBannedIds.map(
            (id) => HubClientTile(
              name: id,
              userId: id,
              trailing: IconButton(
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                tooltip: 'Unban'.tl,
                onPressed: () {
                  _client.serverUnban(id);
                  setState(() {});
                },
              ),
            ),
          ),

        const HubSettingDivider(),

        HubSettingSection(icon: Icons.people_outline, title: 'Online Users'.tl),
        if (hs.onlineClients.isEmpty)
          HubEmptyHint('No users online'.tl)
        else
          ...hs.onlineClients.map(
            (c) => _AdminUserTile(
              client: c,
              hs: hs,
              hubClient: _client,
              onChanged: () => setState(() {}),
            ),
          ),
      ],
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showAddAnnouncementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _HubInputDialog(
        title: 'Add Announcement'.tl,
        hint: 'Enter announcement text...'.tl,
        maxLines: 3,
        confirmLabel: 'Add'.tl,
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
        title: isAdminPicker ? 'Add Room Admin'.tl : 'Ban Member'.tl,
        displayButton: false,
        content: available.isEmpty
            ? Text('No members available'.tl)
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

// ─────────────────────────────────────────────────────────────────────────────
// 公告 tile
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// 通用 "＋添加" tile
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// 通用输入 dialog
// ─────────────────────────────────────────────────────────────────────────────

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
    final label = widget.confirmLabel.isEmpty ? 'Save'.tl : widget.confirmLabel;

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
      actions: [
        Button.outlined(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'.tl),
        ),
        Button.filled(onPressed: _submit, child: Text(label)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 公共 UI 组件（供 hub_page.dart / hub_client_setting.dart 共用）
// ─────────────────────────────────────────────────────────────────────────────

/// 可拖拽 bottom sheet 框架，统一 header 样式。
class HubSheet extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget Function(BuildContext context, ScrollController sc) builder;
  final Widget? headerTrailing;
  final Widget? footer;
  final double initialSize;

  const HubSheet({
    super.key,
    required this.title,
    required this.builder,
    this.icon,
    this.headerTrailing,
    this.footer,
    this.initialSize = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sc = ScrollController();
    final height = MediaQuery.of(context).size.height * initialSize;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        color: cs.surface,
        height: height,
        child: Column(
          children: [
            _HubSheetHandle(),
            _HubSheetHeader(title: title, icon: icon, trailing: headerTrailing),
            Expanded(child: builder(context, sc)),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class _HubSheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.toOpacity(0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _HubSheetHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const _HubSheetHeader({required this.title, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: cs.onSurface.toOpacity(0.7)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outlineVariant.toOpacity(0.4),
        ),
      ],
    );
  }
}

/// 分区标题，带左侧小图标和文字。
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

/// 分区之间的细分隔线。
class HubSettingDivider extends StatelessWidget {
  const HubSettingDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 16,
      indent: 20,
      endIndent: 20,
      color: Theme.of(context).colorScheme.outlineVariant.toOpacity(0.3),
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

// ─────────────────────────────────────────────────────────────────────────────
// 概况小组件
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// 内联编辑字段（欢迎语 / 密码共用）
// ─────────────────────────────────────────────────────────────────────────────

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
              TextButton(onPressed: widget.onCancel, child: Text('Cancel'.tl)),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: widget.onSave,
                child: Text('Save'.tl),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 管理员面板 - 在线用户行（含全局管理员切换 + 禁言 + 封禁）
// ─────────────────────────────────────────────────────────────────────────────

class _AdminUserTile extends StatelessWidget {
  final HubClientDto client;
  final HubState hs;
  final HubClient hubClient;
  final VoidCallback onChanged;

  const _AdminUserTile({
    required this.client,
    required this.hs,
    required this.hubClient,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = client.userId == hs.myId;
    final isBanned = hs.serverBannedIds.contains(client.userId);
    final avatarUrl = client.avatarUrl;
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
        isMe ? 'You'.tl : (isBanned ? 'Banned'.tl : ''),
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
                // 禁言切换
                IconButton(
                  icon: Icon(
                    client.isMuted ? Icons.mic : Icons.mic_off_outlined,
                    size: 18,
                    color: client.isMuted ? cs.error : null,
                  ),
                  tooltip: client.isMuted ? 'Unmute'.tl : 'Mute'.tl,
                  onPressed: () {
                    if (client.isMuted) {
                      hubClient.unmute(client.userId);
                    } else {
                      hubClient.mute(client.userId, seconds: 300);
                    }
                    onChanged();
                  },
                ),
                // 服务器封禁切换
                IconButton(
                  icon: Icon(
                    isBanned ? Icons.lock_open_outlined : Icons.block_outlined,
                    size: 18,
                    color: isBanned ? cs.primary : cs.error.toOpacity(0.7),
                  ),
                  tooltip: isBanned ? 'Unban'.tl : 'Server Ban'.tl,
                  onPressed: () {
                    isBanned
                        ? hubClient.serverUnban(client.userId)
                        : hubClient.serverBan(client.userId);
                    onChanged();
                  },
                ),
                // 全局管理员切换
                IconButton(
                  icon: Icon(
                    client.isGlobalAdmin
                        ? Icons.admin_panel_settings
                        : Icons.admin_panel_settings_outlined,
                    size: 18,
                    color: client.isGlobalAdmin ? Colors.amber : null,
                  ),
                  tooltip: client.isGlobalAdmin
                      ? 'Remove Admin'.tl
                      : 'Make Admin'.tl,
                  onPressed: () {
                    hubClient.setGlobalAdmin(
                      client.userId,
                      value: !client.isGlobalAdmin,
                    );
                    onChanged();
                  },
                ),
              ],
            ),
    );
  }
}
