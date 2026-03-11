import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/services/services.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

part 'hub_chat_page_upload.dart';

/// roomId 有值 → 房间聊天
/// dmUserId 有值 → 私聊
class HubChatPage extends ConsumerStatefulWidget {
  final String? roomId;
  final String? roomName;
  final String? dmUserId;
  final String? dmUserName;

  const HubChatPage({
    super.key,
    this.roomId,
    this.roomName,
    this.dmUserId,
    this.dmUserName,
  }) : assert(roomId != null || dmUserId != null);

  bool get isDm => dmUserId != null;

  @override
  ConsumerState<HubChatPage> createState() => _HubChatPageState();
}

class _HubChatPageState extends ConsumerState<HubChatPage>
    with _HubChatUploadMixin {
  final _scroll = ScrollController();
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();

  final List<HubMessage> _entries = [];
  final Map<String, GlobalKey> _entryKeys = {};
  final List<PendingImage> _pendingImages = [];

  String? _replyToId;
  String? _mentionQuery;
  bool _autoScroll = true;
  bool _isDragging = false;
  bool _initialScrollDone = false;

  late final HubClient _client;

  String get _title =>
      widget.isDm ? (widget.dmUserName ?? 'DM') : (widget.roomName ?? 'Chat');

  GlobalKey _keyFor(String id) => _entryKeys.putIfAbsent(id, () => GlobalKey());

  List<HubClientDto> get _mentionCandidates {
    final query = _mentionQuery;
    if (query == null) return [];
    final clients = ref
        .read(hubProvider)
        .currentRoomClients(ref.read(hubProvider).currentRoomId);
    if (query.isEmpty) return clients;
    return clients
        .where((c) => c.displayName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  // ── 生命周期 ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _client = ref.read(hubClientProvider);

    if (!widget.isDm) {
      _entries.addAll(ref.read(hubProvider).messageHistory);
    }

    _client.onMessage = _onMessage;

    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      if (_scroll.position.isScrollingNotifier.value) return;
      final atBottom =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 60;
      if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
    });

    // @ 触发补全
    _inputCtrl.addListener(() {
      final text = _inputCtrl.text;
      final atIdx = text.lastIndexOf('@');
      if (atIdx < 0) {
        if (_mentionQuery != null) setState(() => _mentionQuery = null);
        return;
      }
      final after = text.substring(atIdx + 1);
      if (after.contains(' ')) {
        if (_mentionQuery != null) setState(() => _mentionQuery = null);
        return;
      }
      if (_mentionQuery != after) setState(() => _mentionQuery = after);
    });
  }

  @override
  void dispose() {
    _client.onMessage = null;
    _scroll.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── 消息处理 ───────────────────────────────────────────────────────────────

  void _onMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final event = HubEvent.fromJson(data);
    switch (event) {
      case HubEventMessage():
        _handleMessage(event);
      case HubEventSystem():
        _handleSystem(event);
      default:
        break;
    }
  }

  void _handleMessage(HubEventMessage event) {
    final msg = event.message;
    if (_client.isBlocked(msg.sender.userId)) return;

    if (widget.isDm) {
      final fromMe = msg.sender.userId == ref.read(hubProvider).myId;
      final fromTarget = msg.sender.userId == widget.dmUserId;
      if (!fromMe && !fromTarget) return;
      if (event.isUnicast == false) return;
    }

    switch (msg.messageType) {
      case HubMessageType.reaction:
        final targetId = msg.replyToMessageId;
        if (targetId == null) return;
        final idx = _entries.indexWhere((e) => e.messageId == targetId);
        if (idx < 0) return;
        setState(() {
          _entries[idx].toggleReaction(
            msg.plainText,
            HubReactionUser(
              userId: msg.sender.userId,
              username: msg.sender.displayName,
            ),
          );
        });

      case HubMessageType.recall:
        final targetId = msg.replyToMessageId;
        if (targetId != null) {
          setState(() => _entries.removeWhere((e) => e.messageId == targetId));
        }

      default:
        if (msg.messageType == HubMessageType.system) return;
        _autoScroll = true;
        setState(() => _entries.add(msg));
        _scrollToBottom();
    }
  }

  void _handleSystem(HubEventSystem event) {
    switch (event) {
      case HubSystemMessageRecalled():
        setState(
          () => _entries.removeWhere((e) => e.messageId == event.messageId),
        );

      case HubSystemClientJoined():
        if (widget.isDm) return;
        App.rootContext.showMessage(
          message: '${event.client.displayName} ${"joined the room".tl}',
          level: LogLevel.info,
          style: ToastStyle.topLeft,
        );
        setState(
          () => _entries.add(
            _makeSystemMsg('client_joined', {'client': event.client.toJson()}),
          ),
        );
        if (_autoScroll) _scrollToBottom();

      case HubSystemClientLeft():
        if (widget.isDm) return;
        setState(
          () => _entries.add(
            _makeSystemMsg('client_left', {
              'clientName': event.clientName ?? '',
            }),
          ),
        );
        if (_autoScroll) _scrollToBottom();

      case HubSystemClientRoomChanged():
        if (widget.isDm) return;
        if (event.client.userId == ref.read(hubProvider).myId) return;
        setState(
          () => _entries.add(
            _makeSystemMsg(
              event.joined ? 'client_joined_room' : 'client_left_room',
              {
                'clientName': event.client.displayName,
                'clientId': event.client.userId,
              },
            ),
          ),
        );
        if (_autoScroll) _scrollToBottom();

      case HubSystemProfileUpdated():
        break;

      case HubSystemRoomAnnouncement():
        // 更新公告栏
        final roomId = ref.read(hubProvider).currentRoomId;
        if (roomId != null) {
          final current = ref.read(hubProvider);
          ref.read(hubProvider.notifier).state = current.copyWith(
            roomList: current.roomList.map((r) {
              if (r.roomId != roomId) return r;
              return r.copyWith(announcements: event.announcements);
            }).toList(),
          );
        }
        // toast 提示
        if (event.setByName.isNotEmpty) {
          App.rootContext.showMessage(
            message: '📢 ${event.setByName} ${"updated the announcement".tl}',
            style: ToastStyle.topRight,
          );
        }

      case HubSystemRoomWelcome():
        App.rootContext.showMessage(
          message: event.message,
          level: LogLevel.info,
          style: ToastStyle.topLeft,
          icon: const Icon(Icons.waving_hand_outlined, size: 16),
        );

      case HubSystemPoked():
        App.rootContext.showMessage(
          message: '${event.fromName} ${"poked you".tl} 👉',
          level: LogLevel.info,
          style: ToastStyle.topRight,
          icon: const Icon(Icons.touch_app_outlined, size: 16),
        );

      case HubSystemMentioned():
        App.rootContext.showMessage(
          message: '@${event.fromName}: ${event.previewText}',
          level: LogLevel.info,
          style: ToastStyle.topRight,
          icon: const Icon(Icons.alternate_email, size: 16),
        );

      default:
        break;
    }
  }

  HubMessage _makeSystemMsg(String event, Map<String, dynamic> extra) =>
      HubMessage(
        messageType: HubMessageType.system,
        sender: _client.serverDto,
        targetRoomIds: [],
        segments: [
          TextSegment(jsonEncode({'event': event, ...extra})),
        ],
      );

  // ── 滚动 ───────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    });
  }

  void _scrollToEntry(String messageId) {
    final idx = _entries.indexWhere((e) => e.messageId == messageId);
    if (idx < 0 || !_scroll.hasClients) return;
    _scroll.jumpTo((idx * 72.0).clamp(0.0, _scroll.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _entryKeys[messageId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      }
    });
  }

  // ── 发送 ───────────────────────────────────────────────────────────────────

  void _send() async {
    final text = _inputCtrl.text.trim();
    final images = List<PendingImage>.from(_pendingImages);
    if (text.isEmpty && images.isEmpty) return;

    setState(() {
      _replyToId = null;
      _mentionQuery = null;
      _pendingImages.clear();
      _inputCtrl.clear();
      _autoScroll = true;
    });

    final segments = <MessageSegment>[];
    if (text.isNotEmpty) {
      segments.addAll(_parseTextWithMentions(text));
    }

    if (images.isNotEmpty) {
      setState(() => _uploading = true);
      try {
        for (final img in images) {
          final seg = await _buildImageSegment(img);
          if (seg != null) segments.add(seg);
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }

    if (segments.isEmpty) return;
    _sendSegments(segments);
    _scrollToBottom();
  }

  List<MessageSegment> _parseTextWithMentions(String text) {
    final clients = ref
        .read(hubProvider)
        .currentRoomClients(ref.read(hubProvider).currentRoomId);
    final segments = <MessageSegment>[];
    final pattern = RegExp(r'@(\S+)');
    int last = 0;

    for (final match in pattern.allMatches(text)) {
      final name = match.group(1)!;
      final found = clients.firstWhereOrNull((c) => c.displayName == name);
      if (found == null) continue;

      if (match.start > last) {
        segments.add(TextSegment(text.substring(last, match.start)));
      }
      segments.add(
        MentionSegment(userId: found.userId, displayName: found.displayName),
      );
      last = match.end;
    }

    if (last < text.length) {
      segments.add(TextSegment(text.substring(last)));
    }

    if (segments.isEmpty) segments.add(TextSegment(text));
    return segments;
  }

  void _onMentionSelect(HubClientDto user) {
    final text = _inputCtrl.text;
    final atIdx = text.lastIndexOf('@');
    if (atIdx < 0) return;
    final before = text.substring(0, atIdx);
    _inputCtrl.text = '$before@${user.displayName} ';
    _inputCtrl.selection = TextSelection.collapsed(
      offset: _inputCtrl.text.length,
    );
    setState(() => _mentionQuery = null);
  }

  void _sendSegments(List<MessageSegment> segments) {
    final replyId = _replyToId;
    if (widget.isDm) {
      _client.sendTo(widget.dmUserId!, segments);
    } else if (replyId != null) {
      _client.reply(replyId, segments);
    } else {
      _client.broadcast(segments);
    }
    _autoScroll = true;
    _scrollToBottom();
  }

  void _openStickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HubStickerPanel(
        onSend: (sticker) {
          Navigator.pop(context);
          _sendSegments([ImageSegment(url: sticker.url)]);
        },
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(hubProvider);
    final cs = Theme.of(context).colorScheme;

    if (!_initialScrollDone && _entries.isNotEmpty) {
      _initialScrollDone = true;
      _scrollToBottom();
    }

    return PopUpWidgetScaffold(
      title: _title,
      tailing: widget.isDm ? _buildDmActions(context, hubState) : [],
      body: DropTarget(
        onDragDone: (d) => _onDragDone(d),
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Stack(
          children: [
            Column(
              children: [
                if (!widget.isDm) _buildRoomSubtitle(cs, hubState),
                if (!widget.isDm) _buildAnnouncementBar(cs, hubState),
                Expanded(child: _buildList(cs, hubState)),
                if (_replyToId != null) _buildReplyBanner(cs),
                if (_mentionCandidates.isNotEmpty) _buildMentionPopup(cs),
                HubInputBar(
                  controller: _inputCtrl,
                  focusNode: _inputFocus,
                  onSend: _send,
                  onPickImage: _pickAndSendImage,
                  onOpenStickers: _openStickerSheet,
                  isDesktop: App.isDesktop,
                  uploading: _uploading,
                  pendingImages: _pendingImages,
                  onRemovePending: (i) =>
                      setState(() => _pendingImages.removeAt(i)),
                ),
              ],
            ),
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: cs.primary.toOpacity(0.12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined, size: 48, color: cs.primary),
                        const SizedBox(height: 12),
                        Text(
                          'Drop to send image'.tl,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── UI 组件 ────────────────────────────────────────────────────────────────

  List<Widget> _buildDmActions(BuildContext context, HubState hubState) {
    final canManage =
        hubState.isGlobalAdmin || _client.isRoomAdminOf(hubState.currentRoomId);
    if (!canManage || widget.dmUserId == null) return [];
    return [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          switch (v) {
            case 'mute':
              _client.mute(widget.dmUserId!);
            case 'unmute':
              _client.unmute(widget.dmUserId!);
            case 'kick':
              _client.kickFromRoom(widget.dmUserId!);
            case 'ban':
              _client.roomBan(widget.dmUserId!);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'mute', child: Text('Mute'.tl)),
          PopupMenuItem(value: 'unmute', child: Text('Unmute'.tl)),
          PopupMenuItem(value: 'kick', child: Text('Kick'.tl)),
          PopupMenuItem(value: 'ban', child: Text('Room Ban'.tl)),
        ],
      ),
    ];
  }

  Widget _buildRoomSubtitle(ColorScheme cs, HubState hubState) {
    final count = hubState.currentRoomClients(hubState.lobbyRoomId).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.toOpacity(0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: Colors.greenAccent.shade400),
          const SizedBox(width: 6),
          Text(
            '$count ${"online".tl}',
            style: TextStyle(fontSize: 12, color: cs.onSurface.toOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementBar(ColorScheme cs, HubState hubState) {
    final announcements = hubState.currentRoom?.announcements ?? [];
    if (announcements.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.toOpacity(0.35),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.toOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 14,
            color: cs.tertiary.toOpacity(0.8),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: announcements.length == 1
                ? Text(
                    announcements.first,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.toOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : _AnnouncementCarousel(announcements: announcements),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionPopup(ColorScheme cs) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.toOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.toOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _mentionCandidates.length,
        itemBuilder: (_, i) {
          final user = _mentionCandidates[i];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: hubAvatarColor(user.userId),
              child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: AnimatedImage(
                        image: CachedImageProvider(
                          user.avatarUrl!,
                          sourceKey: 'hub',
                        ),
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      hubInitials(user.displayName),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
            title: Text(
              user.displayName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            onTap: () => _onMentionSelect(user),
          );
        },
      ),
    );
  }

  Widget _buildList(ColorScheme cs, HubState hubState) {
    return Stack(
      children: [
        Container(color: cs.surfaceContainerLowest),
        _entries.isEmpty
            ? Center(
                child: Text(
                  'No messages yet'.tl,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.toOpacity(0.35),
                  ),
                ),
              )
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                itemCount: _entries.length,
                itemBuilder: (ctx, i) {
                  final entry = _entries[i];
                  final prev = i > 0 ? _entries[i - 1] : null;
                  final isSystem = entry.messageType == HubMessageType.system;
                  final prevIsSystem =
                      prev == null || prev.messageType == HubMessageType.system;

                  final isContinuation =
                      !prevIsSystem &&
                      !isSystem &&
                      prev.sender.userId == entry.sender.userId &&
                      entry.sentAt.difference(prev.sentAt).inMinutes < 2;

                  return KeyedSubtree(
                    key: _keyFor(entry.messageId),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isSystem &&
                            hubNeedTimeDivider(prev?.sentAt, entry.sentAt))
                          HubTimeDivider(time: entry.sentAt),
                        if (isSystem)
                          HubSystemRow(entry: entry)
                        else
                          HubBubbleRow(
                            entry: entry,
                            isMe: entry.sender.userId == hubState.myId,
                            myId: hubState.myId,
                            allEntries: _entries,
                            isContinuation: isContinuation,
                            onReply: (id) {
                              setState(() => _replyToId = id);
                              _inputFocus.requestFocus();
                            },
                            onReact: (id, value) {
                              _client.react(id, value);
                              final myId = hubState.myId;
                              if (myId == null) return;
                              setState(() {
                                final idx = _entries.indexWhere(
                                  (e) => e.messageId == id,
                                );
                                if (idx >= 0) {
                                  _entries[idx].toggleReaction(
                                    value,
                                    HubReactionUser(
                                      userId: myId,
                                      username: _client.savedName ?? myId,
                                    ),
                                  );
                                }
                              });
                            },
                            onRecall: (id) {
                              _client.recall(id);
                              setState(
                                () => _entries.removeWhere(
                                  (e) => e.messageId == id,
                                ),
                              );
                            },
                            onScrollToEntry: _scrollToEntry,
                            roomModeratorIds: hubState.currentRoomModerators,
                            onPoke: (userId) {
                              if (userId == hubState.myId) return;
                              _client.poke(userId);
                            },
                            onMention: (sender) {
                              final text = _inputCtrl.text;
                              final insert = '@${sender.displayName} ';
                              _inputCtrl.text =
                                  text.endsWith(' ') || text.isEmpty
                                  ? '$text$insert'
                                  : '$text $insert';
                              _inputCtrl.selection = TextSelection.collapsed(
                                offset: _inputCtrl.text.length,
                              );
                              _inputFocus.requestFocus();
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
        if (!_autoScroll)
          Positioned(
            bottom: 10,
            right: 14,
            child: GestureDetector(
              onTap: () {
                setState(() => _autoScroll = true);
                _scrollToBottom();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: cs.primary.toOpacity(0.35), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward, size: 12, color: cs.onPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'New messages'.tl,
                      style: TextStyle(fontSize: 11, color: cs.onPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReplyBanner(ColorScheme cs) {
    final entry = _entries.firstWhereOrNull((e) => e.messageId == _replyToId);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      color: cs.surfaceContainerHighest,
      child: Row(
        children: [
          Container(
            width: 2.5,
            height: 30,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(right: 8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry?.sender.displayName ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                Text(
                  entry?.plainText ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.toOpacity(0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 16,
              color: cs.onSurface.toOpacity(0.4),
            ),
            onPressed: () => setState(() => _replyToId = null),
            style: IconButton.styleFrom(
              minimumSize: const Size(30, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 公告轮播 ────────────────────────────────────────────────────────────────────

class _AnnouncementCarousel extends StatefulWidget {
  final List<String> announcements;

  const _AnnouncementCarousel({required this.announcements});

  @override
  State<_AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<_AnnouncementCarousel> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % widget.announcements.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Text(
        widget.announcements[_index],
        key: ValueKey(_index),
        style: TextStyle(fontSize: 12, color: cs.onSurface.toOpacity(0.7)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
