import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
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

  /// 打开番剧详情（Bangumi BottomInfo sheet）的回调，由番剧页提供
  final VoidCallback? onOpenBangumiInfo;

  const WatchTogetherPage({
    super.key,
    this.animeTitle,
    required this.playerController,
    required this.watcherController,
    this.onOpenBangumiInfo,
  });

  @override
  ConsumerState<WatchTogetherPage> createState() => _WatchTogetherPageState();
}

class _WatchTogetherPageState extends ConsumerState<WatchTogetherPage>
    with AutomaticKeepAliveClientMixin {
  Timer? _syncTimer;
  HubPlaybackSync? _ownerSync;
  bool _syncing = false;
  // 自动跟播去重：记录最近一次自动跳转的集数，避免房主每 1s 广播触发重复跳集
  int? _lastAutoSyncedEpisode;

  // 缓存最后一次同步状态：dispose 时（房主退出播放页）广播停止状态
  bool _cachedIsOwner = false;
  bool _cachedInWatchRoom = false;
  int _cachedEpisode = 1;
  int _cachedPositionMs = 0;
  dynamic _cachedAnime;

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
    final state = ref.read(hubProvider);
    final room = state.currentRoom;
    final isWatchMember =
        state.isConnected &&
        room != null &&
        room.roomId != state.lobbyRoomId &&
        room.isWatchRoom &&
        room.ownerUserId != state.myId;
    widget.playerController.syncLocked = isWatchMember;
    widget.playerController.onSyncToOwner = _syncToOwner;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanHistory());
    // 若打开时已连接，则按当前状态启动/停止广播定时器
    _updateSyncTimer(state);
    // 尝试 P2P 直连
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryPeerSetup());
  }

  @override
  void dispose() {
    _client.removeMessageListener(_onHubRaw);
    widget.playerController.onSyncToOwner = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _teardownPeer();
    // 房主退出播放页但仍在房间：广播停止状态，让成员知道房主已停止播放
    _broadcastOwnerStopped();
    super.dispose();
  }

  /// 广播"房主已停止播放"（playing=false），供成员侧感知房主退出播放页
  void _broadcastOwnerStopped() {
    if (!_cachedIsOwner || !_cachedInWatchRoom) return;
    final anime = _cachedAnime;
    if (anime == null) return;
    try {
      final frame = encodeHubSync(
        episode: _cachedEpisode,
        positionMs: _cachedPositionMs,
        playing: false,
        animeId: anime.id,
        title: anime.title,
        sourceKey: anime.sourceKey,
        cover: anime.cover,
        senderId: _client.myId ?? '',
      );
      _client.broadcast([TextSegment(frame)]);
    } catch (_) {}
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
        const Duration(seconds: 1),
        (_) => _broadcastSync(),
      );
    } else {
      _syncTimer?.cancel();
      _syncTimer = null;
    }
  }

  // ── 播放进度同步 ──────────────────────────────────────────────────────────

  /// 记录房主（同步时长者）的进度，并同步给播放器用于显示时间差
  void _applyOwnerSync(HubPlaybackSync? sync) {
    _ownerSync = sync;
    if (sync == null) {
      _lastAutoSyncedEpisode = null;
    }
    // 房主自己：无同步目标，不显示时间差 / 暂停图标
    final state = ref.read(hubProvider);
    final isOwner = state.currentRoom?.ownerUserId == _client.myId;
    if (isOwner) {
      widget.playerController.ownerSyncPositionMs = -1;
      widget.playerController.ownerSyncPlaying = true;
      widget.playerController.ownerSyncSentAt = 0;
    } else {
      widget.playerController.ownerSyncPositionMs = sync?.positionMs ?? -1;
      widget.playerController.ownerSyncPlaying = sync?.playing ?? true;
      // 用「本机收到的时间」而非房主广播的 sentAt 做延迟补偿：
      // 房主与成员时钟可能不同步，用 sentAt 算 elapsed 会因时钟偏差跳变。
      widget.playerController.ownerSyncSentAt = sync == null
          ? 0
          : DateTime.now().millisecondsSinceEpoch;
    }
  }

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
    // 房主每秒广播 sync，避免无意义 setState 导致整个一起看页面
    // （含聊天列表）每秒重建、图片闪烁
    final prev = _ownerSync;
    // 自己的回环广播（房主本地进度）：实时刷新，避免房主进度条停滞
    if (sync.senderId == _client.myId) {
      setState(() => _applyOwnerSync(sync));
      return;
    }
    if (prev == null ||
        prev.episode != sync.episode ||
        prev.playing != sync.playing ||
        (sync.positionMs - prev.positionMs).abs() > 5000) {
      setState(() => _applyOwnerSync(sync));
    } else {
      _applyOwnerSync(sync);
    }
    _maybeAutoFollow(sync);
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
    if (latest != null) _applyOwnerSync(latest);
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
    setState(() => _applyOwnerSync(sync));
    _maybeAutoFollow(sync);
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
    _cachedEpisode = pc.currentEpisoded;
    _cachedPositionMs = pc.playerPosition.inMilliseconds;
    _cachedAnime = anime;
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

  Future<void> _syncToOwner({bool silent = false}) async {
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
        if (!silent) {
          App.rootContext.showMessage(
            message: t.syncRequiresSameAnime(
              title: sync.title.isEmpty ? '?' : sync.title,
            ),
            level: LogLevel.warning,
          );
        }
        return;
      }
      // 临时解锁，允许同步切集与 seek（手动拖动/切集仍被 syncLocked 拦截）
      final prev = pc.syncLocked;
      pc.syncLocked = false;
      try {
        if (sync.episode != pc.currentEpisoded) {
          await WatcherState.currentState?.loadInfo(
            sync.episode,
            pc.currentRoad,
          );
        }
        // 延迟补偿：房主在播时，按「距收到广播的时间」补上进度，减少成员固有落后。
        // 用本机收到时间（ownerSyncSentAt）而非房主 sentAt，避免两端时钟不同步导致跳变。
        var targetMs = sync.positionMs;
        if (sync.playing && pc.ownerSyncSentAt > 0) {
          final elapsed =
              DateTime.now().millisecondsSinceEpoch - pc.ownerSyncSentAt;
          targetMs += elapsed.clamp(0, 30000);
        }
        await pc.seek(Duration(milliseconds: targetMs));
      } finally {
        pc.syncLocked = prev;
      }
      if (!silent) {
        App.rootContext.showMessage(message: t.syncedToOwner);
      }
    } catch (_) {
      // ignore: 同步失败不打断
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// 成员自动跟播：房主切集时自动跳转到对应集数（静默，不弹提示）。
  void _maybeAutoFollow(HubPlaybackSync sync) {
    if (!mounted) return;
    final pc = widget.playerController;
    if (!pc.syncLocked) return; // 仅一起看成员自动跟播
    if (sync.episode == pc.currentEpisoded) return; // 集数一致，无需跳转
    if (_lastAutoSyncedEpisode == sync.episode) return; // 去重，避免每秒重复跳集
    _lastAutoSyncedEpisode = sync.episode;
    _syncToOwner(silent: true);
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
          // 播放页只能创建一起看房间
          roomType: HubRoomType.watch,
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
    final saved = client.savedAddress ?? '';
    // 回环地址（127.0.0.1/localhost）扫码端连不上，替换为本机局域网地址
    final address = await _resolveShareAddress(saved);
    // 管理员分享时使用用户级 token，避免泄露管理员 key；普通用户用自身 token
    final shareToken = client.isGlobalAdmin
        ? ApiKeyManager().activeKey
        : (client.savedToken ?? '');
    final payload = HubRoomJoinProtocol.encode(
      address: address,
      roomId: room.roomId,
      roomName: room.roomName,
      password: password,
      token: shareToken,
    );
    showKostoriShareSheet(
      context,
      ref,
      type: KostoriRouteType.hubRoom,
      payload: payload,
      title: t.watchTogether,
      subtitle: room.roomName,
      // 二维码背景使用正在观看的番剧封面
      backgroundImagePath: widget.watcherController.anime?.cover,
    );
  }

  /// 将回环地址替换为局域网可达地址；非回环（如公网域名）保持原样。
  Future<String> _resolveShareAddress(String saved) async {
    final uri = Uri.tryParse(saved);
    final host = uri?.host ?? '';
    if (host != '127.0.0.1' && host != 'localhost' && host != '0.0.0.0') {
      return saved;
    }
    final port = (uri?.hasPort ?? false) ? uri!.port : 9100;
    final scheme = (uri?.scheme ?? 'ws') == 'wss' ? 'wss' : 'ws';
    try {
      final candidates = await collectLanCandidates(port);
      for (final c in candidates) {
        final ip = Uri.tryParse(c)?.host ?? '';
        if (ip.isNotEmpty && ip != '127.0.0.1') {
          return '$scheme://$ip:$port';
        }
      }
    } catch (_) {}
    return saved;
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
    // 一起看房间绑定番剧：仅在当前播放页番剧与房间一致时展示房间视图，
    // 避免在别的番剧播放页误显示/锁定的别的番剧房间
    final currentAnime = widget.watcherController.anime;
    final roomMatchesAnime =
        !inRoom ||
        state.currentRoom?.animeId == null ||
        state.currentRoom?.animeSourceKey == null ||
        (currentAnime != null &&
            state.currentRoom?.animeId == currentAnime.id &&
            state.currentRoom?.animeSourceKey == currentAnime.sourceKey);

    ref.listen(hubProvider, (prev, next) {
      // 一起看成员：锁定播放器（禁止拖动进度/调倍速/切集，强制 1 倍速跟随房主）
      final room = next.currentRoom;
      final currentAnime = widget.watcherController.anime;
      final roomMatchesAnime =
          room == null ||
          room.animeId == null ||
          room.animeSourceKey == null ||
          (currentAnime != null &&
              room.animeId == currentAnime.id &&
              room.animeSourceKey == currentAnime.sourceKey);
      final isWatchMember =
          next.isConnected &&
          room != null &&
          room.roomId != next.lobbyRoomId &&
          room.isWatchRoom &&
          room.ownerUserId != next.myId &&
          roomMatchesAnime;
      // 缓存房主状态，dispose 时用于广播停止
      _cachedIsOwner =
          next.isConnected &&
          room != null &&
          room.roomId != next.lobbyRoomId &&
          room.isWatchRoom &&
          room.ownerUserId == next.myId &&
          roomMatchesAnime;
      _cachedInWatchRoom =
          next.isConnected &&
          room != null &&
          room.roomId != next.lobbyRoomId &&
          room.isWatchRoom &&
          roomMatchesAnime;
      _cachedAnime = widget.watcherController.anime;
      widget.playerController.syncLocked = isWatchMember;
      if (isWatchMember) {
        widget.playerController.setPlaybackSpeed(1);
      }
      if (prev?.currentRoomId != next.currentRoomId) {
        _applyOwnerSync(null);
        _teardownPeer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scanHistory();
          _tryPeerSetup();
          // 一起看成员进入房间后自动对齐房主进度
          final room = ref.read(hubProvider).currentRoom;
          if (room != null &&
              room.roomId != next.lobbyRoomId &&
              room.isWatchRoom &&
              room.ownerUserId != next.myId) {
            _syncToOwner();
          }
        });
      } else if (prev?.currentRoom?.ownerUserId !=
          next.currentRoom?.ownerUserId) {
        // 房主变化（原房主离开 / 所有权转移）：重置同步状态并重建直连
        _applyOwnerSync(null);
        _teardownPeer();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scanHistory();
          _tryPeerSetup();
          if (next.currentRoom?.ownerUserId == next.myId) {
            // 我是新房主：立即广播一次当前进度
            _broadcastSync();
          }
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
              : inRoom && roomMatchesAnime
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
    final currentAnime = widget.watcherController.anime;
    // 播放页只显示与当前番剧绑定的一起看房间
    final rooms = state.roomList.where((r) {
      if (r.roomId == state.lobbyRoomId) return false;
      if (currentAnime == null) return false;
      return r.isWatchRoom &&
          r.animeId == currentAnime.id &&
          r.animeSourceKey == currentAnime.sourceKey;
    }).toList();

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
            // 播放页内嵌：不显示"打开番剧"跳转卡片
            showWatchCard: false,
            // 番剧详情入口移到输入框工具栏（设置按钮旁）
            onOpenBangumiInfo: widget.onOpenBangumiInfo,
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
          // 番剧源缺失时提示可打开番剧页（入口改在个人页浮动按钮，避免与播放器冲突）
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

  /// 打开房主正在观看的番剧页。
  /// 入口已迁移到个人页浮动按钮（避免与播放器 UI 冲突）。
}
