import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/hub/hub_chat_page.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/pages/hub/hub_create_room_dialog.dart';
import 'package:kostori/pages/hub/hub_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:kostori/pages/watcher/watcher_controller.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/protocol_parser.dart';

/// 一起看 Tab：嵌入 hub 房间模块。
/// - 未连接：一键连接 / 进入 Hub 设置
/// - 在大厅：房间列表 + 创建房间
/// - 已进入房间：内嵌聊天（无需进入二级页面）+ 房主播放进度同步
class WatchTogetherPage extends ConsumerStatefulWidget {
  final String? animeTitle;
  final PlayerController playerController;
  final WatcherController watcherController;

  const WatchTogetherPage({
    super.key,
    this.animeTitle,
    required this.playerController,
    required this.watcherController,
  });

  @override
  ConsumerState<WatchTogetherPage> createState() => _WatchTogetherPageState();
}

class _WatchTogetherPageState extends ConsumerState<WatchTogetherPage>
    with AutomaticKeepAliveClientMixin {
  Timer? _syncTimer;
  HubPlaybackSync? _ownerSync;
  bool _syncing = false;

  // ── 一起看 P2P 直连 ─────────────────────────────────────────────────────
  HubPeerServer? _peerServer; // 房主侧：直连服务器
  HubPeerClient? _peerClient; // 成员侧：直连客户端
  bool _directConnected = false;
  StreamSubscription<String>? _peerSub;
  int _lastDirectSentAt = 0; // 去重：最近一条直连同步的 sentAt

  /// 保存 HubClient 引用，dispose 时不再通过 ref 访问（避免未挂载时读 ref）
  late final HubClient _client;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _client = ref.read(hubClientProvider);
    _client.addMessageListener(_onHubRaw);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanHistory());
    // 若打开时已连接，则按当前状态启动/停止广播定时器
    _updateSyncTimer(ref.read(hubProvider));
    // 尝试 P2P 直连
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPeerSetup());
  }

  @override
  void dispose() {
    _client.removeMessageListener(_onHubRaw);
    _syncTimer?.cancel();
    _syncTimer = null;
    _teardownPeer();
    super.dispose();
  }

  /// 仅当已连接 + 已进真实房间 + 是房主时才运行广播定时器，否则停止
  void _updateSyncTimer(HubState state) {
    final shouldRun =
        state.isConnected &&
        state.currentRoomId != null &&
        state.currentRoomId != state.lobbyRoomId &&
        state.currentRoom?.ownerUserId == state.myId;
    if (shouldRun) {
      _syncTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _broadcastSync(),
      );
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  // ── 播放进度同步 ──────────────────────────────────────────────────────────

  void _onHubRaw(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = HubEvent.fromJson(data);
    if (event is! HubEventMessage) return;
    final msg = event.message;
    if (!isHubSyncMessage(msg)) return;
    final sync = HubPlaybackSync.fromMessage(msg);
    if (sync == null) return;
    final ownerId = ref.read(hubProvider).currentRoom?.ownerUserId;
    if (ownerId == null || sync.senderId != ownerId) return; // 只接受房主进度
    setState(() => _ownerSync = sync);
  }

  void _scanHistory() {
    if (!mounted) return;
    final state = ref.read(hubProvider);
    final ownerId = state.currentRoom?.ownerUserId;
    if (ownerId == null) return;
    HubPlaybackSync? latest;
    for (final m in state.currentRoom?.messageHistory ?? <HubMessage>[]) {
      if (!isHubSyncMessage(m)) continue;
      final sync = HubPlaybackSync.fromMessage(m);
      if (sync == null || sync.senderId != ownerId) continue;
      if (latest == null || sync.sentAt > latest.sentAt) latest = sync;
    }
    if (latest != null) _ownerSync = latest;
    if (mounted) setState(() {});
  }

  // ── 一起看 P2P 直连 ──────────────────────────────────────────────────────

  /// 进入房间后：房主启动直连服务器并上报候选；成员尝试直连房主。
  void _tryPeerSetup() {
    if (!mounted) return;
    final state = ref.read(hubProvider);
    final room = state.currentRoom;
    if (!state.isConnected ||
        room == null ||
        room.roomId == state.lobbyRoomId) {
      return;
    }
    final isOwner = room.ownerUserId == state.myId;
    if (isOwner) {
      _startOwnerPeerServer(room);
    } else {
      _tryDirectConnect(room);
    }
  }

  Future<void> _startOwnerPeerServer(HubRoomDto room) async {
    try {
      final server = HubPeerServer();
      await server.start();
      _peerServer = server;
      // 上报候选地址给服务器，成员据此直连
      final candidates = await server.candidates();
      _client.setPeerCandidates(candidates);
      HubLog.info('WatchTogether', '📡 房主直连候选：$candidates');
      if (mounted) setState(() {});
    } catch (e) {
      HubLog.warning('WatchTogether', '启动直连服务器失败：$e');
    }
  }

  Future<void> _tryDirectConnect(HubRoomDto room) async {
    if (_peerClient != null) return;
    final state = ref.read(hubProvider);
    // 优先从在线客户端列表取候选（profile_updated 会实时更新），room.participants 可能滞后
    final owner = state.onlineClients.firstWhereOrNull(
      (p) => p.userId == room.ownerUserId,
    );
    final candidates = owner?.peerCandidates ?? const <String>[];
    if (candidates.isEmpty) return;
    HubLog.info('WatchTogether', '📡 尝试直连房主：$candidates');
    final client = await HubPeerClient.connect(candidates);
    if (!mounted) return;
    if (client == null) {
      HubLog.info('WatchTogether', '直连房主失败，回退服务器广播');
      return;
    }
    _peerClient = client;
    _directConnected = true;
    _client.setDirectSyncStatus(true);
    _peerSub = client.frames.listen(_onDirectFrame);
    if (mounted) setState(() {});
  }

  void _onDirectFrame(String frame) {
    if (!mounted) return;
    if (!isHubSyncText(frame)) return;
    final sync = HubPlaybackSync.fromText(frame);
    if (sync == null) return;
    final state = ref.read(hubProvider);
    final ownerId = state.currentRoom?.ownerUserId;
    if (ownerId == null || sync.senderId != ownerId) return;
    if (sync.sentAt == _lastDirectSentAt) return; // 去重
    _lastDirectSentAt = sync.sentAt;
    setState(() => _ownerSync = sync);
  }

  void _teardownPeer() {
    _peerSub?.cancel();
    _peerSub = null;
    if (_directConnected) {
      _client.setDirectSyncStatus(false);
    }
    _directConnected = false;
    _peerClient?.dispose();
    _peerClient = null;
    _peerServer?.stop();
    _peerServer = null;
    _client.setPeerCandidates(const []);
  }

  void _broadcastSync() {
    if (!mounted) return;
    final state = ref.read(hubProvider);
    final room = state.currentRoom;
    if (!state.isConnected || room == null) return;
    if (room.roomId == state.lobbyRoomId) return;
    if (room.ownerUserId != state.myId) return; // 仅房主广播进度
    final anime = widget.watcherController.anime;
    if (anime == null) return;
    final pc = widget.playerController;
    final frame = encodeHubSync(
      episode: pc.currentEpisoded,
      positionMs: pc.playerPosition.inMilliseconds,
      playing: pc.playerPlaying,
      animeId: anime.id,
      title: anime.title,
      sourceKey: anime.sourceKey,
      cover: anime.cover,
      senderId: state.myId ?? '',
    );
    // 服务器广播（兜底通道，直连成员会被服务端跳过）
    _client.broadcast([TextSegment(frame)]);
    // P2P 直连通道：直接推给直连成员，不占服务器带宽
    _peerServer?.broadcastSync(frame);
  }

  Future<void> _syncToOwner() async {
    final sync = _ownerSync;
    if (sync == null || _syncing) return;
    setState(() => _syncing = true);
    try {
      final pc = widget.playerController;
      final current = widget.watcherController.anime;
      // 番剧不一致：无法直接跳集，提示先打开对应番剧
      if (current == null ||
          (sync.sourceKey.isNotEmpty && current.sourceKey != sync.sourceKey) ||
          (sync.animeId.isNotEmpty && current.id != sync.animeId)) {
        App.rootContext.showMessage(
          message: t.syncRequiresSameAnime(
            title: sync.title.isEmpty ? '?' : sync.title,
          ),
          level: LogLevel.warning,
        );
        return;
      }
      if (sync.episode != pc.currentEpisoded) {
        await WatcherState.currentState?.loadInfo(sync.episode, pc.currentRoad);
      }
      await pc.seek(Duration(milliseconds: sync.positionMs));
      App.rootContext.showMessage(message: t.syncedToOwner);
    } catch (_) {
      // ignore: 同步失败不打断
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _fmtTime(int ms) {
    final total = ms ~/ 1000;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // ── 连接 / 房间操作 ────────────────────────────────────────────────────────

  Future<void> _connect() async {
    final client = ref.read(hubClientProvider);
    final address = client.savedAddress;
    if (address == null || address.isEmpty) {
      App.rootContext.showMessage(
        message: t.enterServerAddress,
        level: LogLevel.warning,
      );
      return;
    }
    try {
      await client.connect(
        address,
        client.savedToken ?? '',
        name: client.savedName ?? '',
      );
    } catch (_) {
      App.rootContext.showMessage(
        message: t.connectionFailed,
        level: LogLevel.warning,
      );
    }
  }

  Future<void> _createRoom() async {
    final anime = widget.watcherController.anime;
    final result = await showCreateRoomDialog(
      initialName: widget.animeTitle,
      initialRoomType: HubRoomType.watch,
      watchAnime: anime,
    );
    if (result == null) return;
    ref
        .read(hubClientProvider)
        .createRoom(
          result.name,
          password: result.password,
          announcement: result.announcement,
          maxParticipants: result.maxParticipants,
          roomType: result.roomType,
          animeId: anime?.id,
          animeTitle: anime?.title,
          animeSourceKey: anime?.sourceKey,
          animeCover: anime?.cover,
        );
  }

  /// 分享当前房间：生成二维码（含服务端地址/房间号），他人扫码自动连接并加入
  Future<void> _shareRoomQr() async {
    final state = ref.read(hubProvider);
    final client = ref.read(hubClientProvider);
    final room = state.currentRoom;
    if (room == null) return;
    String? password;
    if (room.isLocked) {
      password = await _showPasswordDialog();
      if (password == null) return; // 取消
    }
    final payload = HubRoomJoinProtocol.encode(
      address: client.savedAddress ?? '',
      roomId: room.roomId,
      roomName: room.roomName,
      password: password,
      token: client.savedToken ?? '',
    );
    showKostoriShareSheet(
      context,
      ref,
      type: KostoriRouteType.hubRoom,
      payload: payload,
      title: t.watchTogether,
      subtitle: room.roomName,
    );
  }

  Future<void> _joinRoom(HubRoomDto room) async {
    final client = ref.read(hubClientProvider);
    if (room.isLocked) {
      final pwd = await _showPasswordDialog();
      if (pwd == null) return;
      client.joinRoom(room.roomId, password: pwd);
    } else {
      client.joinRoom(room.roomId);
    }
  }

  Future<String?> _showPasswordDialog() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: t.roomPassword,
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: t.password),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(t.ok),
          ),
        ],
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = ref.watch(hubProvider);
    final cs = Theme.of(context).colorScheme;
    final connected = state.isConnected;
    final roomId = state.currentRoomId;
    final inRoom = roomId != null && roomId != state.lobbyRoomId;

    ref.listen(hubProvider, (prev, next) {
      if (prev?.currentRoomId != next.currentRoomId) {
        _ownerSync = null;
        _teardownPeer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scanHistory();
          _tryPeerSetup();
        });
      }
      // 房主候选地址更新后重试直连（P2P）
      if (_peerClient == null &&
          next.currentRoomId != null &&
          next.currentRoomId != next.lobbyRoomId) {
        final room = next.currentRoom;
        if (room != null && room.ownerUserId != next.myId) {
          final owner = next.onlineClients.firstWhereOrNull(
            (c) => c.userId == room.ownerUserId,
          );
          final hasNewCandidates =
              (owner?.peerCandidates ?? const []).isNotEmpty;
          if (hasNewCandidates &&
              prev?.onlineClients
                      .firstWhereOrNull((c) => c.userId == room.ownerUserId)
                      ?.peerCandidates
                      .length !=
                  owner?.peerCandidates.length) {
            _tryDirectConnect(room);
          }
        }
      }
      _updateSyncTimer(next);
    });

    return Column(
      children: [
        _buildHeader(state, cs, connected, inRoom),
        Expanded(
          child: !connected
              ? _buildDisconnected(cs)
              : inRoom
              ? _buildRoomView(state, cs)
              : _buildLobbyView(state, cs),
        ),
      ],
    );
  }

  Widget _buildHeader(
    HubState state,
    ColorScheme cs,
    bool connected,
    bool inRoom,
  ) {
    final client = ref.read(hubClientProvider);
    return Material(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.groups_2_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.watchTogether,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (connected && inRoom)
              IconButton(
                tooltip: t.shareRoomQr,
                icon: Icon(
                  Icons.qr_code_2,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: _shareRoomQr,
                visualDensity: VisualDensity.compact,
              ),
            if (connected && inRoom)
              IconButton(
                tooltip: t.leaveRoom,
                icon: Icon(Icons.logout, size: 18, color: cs.onSurfaceVariant),
                onPressed: () => client.leaveRoom(),
                visualDensity: VisualDensity.compact,
              ),
            if (connected)
              IconButton(
                tooltip: t.disconnect,
                icon: Icon(
                  Icons.link_off,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () => client.disconnect(),
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.circle,
              size: 10,
              color: connected
                  ? Colors.greenAccent.shade400
                  : cs.outlineVariant,
            ),
            const SizedBox(width: 4),
            Text(
              connected ? t.connected : t.notConnected,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.toOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnected(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 48, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text(
              t.watchTogetherDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.toOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.link, size: 16),
              label: Text(t.connect),
              onPressed: _connect,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: Text(t.serviceSettings),
              onPressed: () => showHubDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyView(HubState state, ColorScheme cs) {
    final canCreate =
        state.isGlobalAdmin ||
        !state.roomList.any((r) => r.ownerUserId == state.myId);
    final rooms = state.roomList
        .where((r) => r.roomId != state.lobbyRoomId)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          t.selectRoomToStart,
          style: TextStyle(fontSize: 13, color: cs.onSurface.toOpacity(0.6)),
        ),
        const SizedBox(height: 8),
        if (rooms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                t.noRooms,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.toOpacity(0.4),
                ),
              ),
            ),
          )
        else
          for (final room in rooms) _buildRoomTile(room, state, cs),
        if (canCreate)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(t.createRoom),
              onPressed: _createRoom,
            ),
          ),
      ],
    );
  }

  Widget _buildRoomTile(HubRoomDto room, HubState state, ColorScheme cs) {
    final isCurrent = room.roomId == state.currentRoomId;
    final isWatch = room.isWatchRoom;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCurrent ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isWatch
                ? (room.isLocked
                      ? Icons.lock_outline
                      : Icons.play_circle_outline)
                : (room.isLocked
                      ? Icons.lock_outlined
                      : Icons.meeting_room_outlined),
            size: 20,
            color: isCurrent ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                room.roomName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isWatch) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  t.watchTogether,
                  style: TextStyle(
                    fontSize: 9,
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${room.participantCount} ${t.members}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.toOpacity(0.5),
              ),
            ),
            if (isWatch &&
                room.animeTitle != null &&
                room.animeTitle!.isNotEmpty)
              Text(
                t.watchingAnime(a: room.animeTitle!),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary.toOpacity(0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: isCurrent
            ? Text(t.current, style: TextStyle(fontSize: 12, color: cs.primary))
            : TextButton(child: Text(t.join), onPressed: () => _joinRoom(room)),
      ),
    );
  }

  Widget _buildRoomView(HubState state, ColorScheme cs) {
    final room = state.currentRoom;
    final isOwner = room?.ownerUserId == state.myId;
    return Column(
      children: [
        _buildSyncBar(cs, isOwner),
        Expanded(
          child: HubChatPage(
            roomId: state.currentRoomId,
            roomName: state.currentRoomName ?? t.lobby,
            embedded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncBar(ColorScheme cs, bool isOwner) {
    final sync = _ownerSync;
    final room = ref.read(hubProvider).currentRoom;
    final title = sync?.title.isNotEmpty == true
        ? sync!.title
        : (room?.animeTitle?.isNotEmpty == true ? room!.animeTitle : null);
    final canOpenAnime =
        sync != null && sync.sourceKey.isNotEmpty && sync.animeId.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.toOpacity(0.35),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.toOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sync, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: sync == null
                ? Text(
                    title != null
                        ? '${t.watchingAnime(a: title)} · '
                              '${isOwner ? t.sharingAsOwner : t.ownerNotSharing}'
                        : (isOwner ? t.sharingAsOwner : t.ownerNotSharing),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.toOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    '$title · ${t.episodeNEp(n: sync.episode)} · ${_fmtTime(sync.positionMs)}${sync.playing ? ' ▶' : ' ⏸'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.toOpacity(0.75),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          // 番剧源缺失时提示可打开番剧页
          if (canOpenAnime && !isOwner)
            TextButton.icon(
              onPressed: () => _openAnime(sync),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: Text(t.openAnime),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          if (sync != null && !isOwner)
            TextButton.icon(
              onPressed: _syncing ? null : _syncToOwner,
              icon: _syncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 16),
              label: Text(t.syncToOwner),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }

  /// 打开房主正在观看的番剧页。番剧源缺失时给出提示。
  void _openAnime(HubPlaybackSync sync) {
    if (AnimeSource.find(sync.sourceKey) == null) {
      App.rootContext.showMessage(
        message: t.sourceNotInstalled(source: sync.sourceKey),
        level: LogLevel.warning,
      );
      return;
    }
    context.to(
      () => AnimePage(
        id: sync.animeId,
        sourceKey: sync.sourceKey,
        cover: sync.cover,
        title: sync.title,
      ),
    );
  }
}
