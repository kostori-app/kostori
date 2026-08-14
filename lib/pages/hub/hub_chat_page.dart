import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image_picker/image_picker.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/components/custom_markdown_widget.dart';
import 'package:kostori/database/history.dart';
import 'package:kostori/foundation/anime_type.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/bangumi/bottom_info.dart';
import 'package:kostori/pages/bangumi/info_controller.dart';
import 'package:kostori/pages/hub/hub_chat_widgets.dart';
import 'package:kostori/utils/ext.dart';

part 'hub_chat_page_upload.dart';

/// roomId 有值 → 房间聊天
/// dmUserId 有值 → 私聊
class HubChatPage extends ConsumerStatefulWidget {
  final String? roomId;
  final String? roomName;
  final String? dmUserId;
  final String? dmUserName;

  /// 嵌入模式：不渲染标题栏 / 滚动容器，直接输出聊天主体，供页面 Tab 内嵌使用
  final bool embedded;

  /// 是否显示"打开番剧"卡片（播放页内嵌一起看时置 false，避免重复跳转）
  final bool showWatchCard;

  /// 打开番剧详情（Bangumi BottomInfo）的回调，仅一起看房间需要
  final VoidCallback? onOpenBangumiInfo;

  const HubChatPage({
    super.key,
    this.roomId,
    this.roomName,
    this.dmUserId,
    this.dmUserName,
    this.embedded = false,
    this.showWatchCard = true,
    this.manualKeyboardPadding = false,
    this.onOpenBangumiInfo,
  }) : assert(roomId != null || dmUserId != null);

  bool get isDm => dmUserId != null;

  /// 是否由调用方负责手动补偿软键盘高度（仅在无 Scaffold 调整的全屏覆盖层中需要）
  final bool manualKeyboardPadding;

  @override
  ConsumerState<HubChatPage> createState() => _HubChatPageState();
}

class _HubChatPageState extends ConsumerState<HubChatPage>
    with _HubChatUploadMixin, AutomaticKeepAliveClientMixin {
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

  /// 本聊天实例的 Hero 前缀：同一房间聊天可能同时存在多个实例
  /// （一起看 Tab + 全屏浮层），用于区分 Hero tag，避免冲突。
  static int _heroCounter = 0;
  final String _heroPrefix = 'chat${_heroCounter++}';

  @override
  bool get wantKeepAlive => true;

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
    if (widget.isDm) {
      final dmId = widget.dmUserId;
      if (dmId == null) return;
      _client.activeDmUserId = dmId;
      _client.clearDmUnread(dmId);
      _entries.addAll(ref.read(hubProvider).dmHistory[dmId] ?? []);
    } else {
      _entries.addAll(
        ref.read(hubProvider).messageHistory.where((m) => !isHubSyncMessage(m)),
      );
    }

    _client.addMessageListener(_onMessage);

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
    _client.removeMessageListener(_onMessage);
    _scroll.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    if (widget.isDm) {
      _client.activeDmUserId = null;
    }
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
      // 私聊：只接收 unicast，且必须是和 dmUserId 之间的消息
      if (!event.isUnicast) return;
      final fromMe = msg.sender.userId == ref.read(hubProvider).myId;
      final fromTarget = msg.sender.userId == widget.dmUserId;
      if (!fromMe && !fromTarget) return;
    } else {
      // 房间：只接收广播，过滤掉所有私聊
      if (event.isUnicast) return;
    }

    switch (msg.messageType) {
      // ── reaction ────────────────────────────────────────────────────────────
      case HubMessageType.reaction:
        final seg = msg.segments.whereType<ReactionSegment>().firstOrNull;
        if (seg == null) return;
        final idx = _entries.indexWhere(
          (e) => e.messageId == seg.targetMessageId,
        );
        if (idx < 0) return;
        setState(() {
          _entries[idx].toggleReaction(
            seg.emojiId,
            HubReactionUser(
              userId: seg.reactorUserId,
              username: msg.sender.displayName,
            ),
          );
        });

      // ── recall ──────────────────────────────────────────────────────────────
      case HubMessageType.recall:
        final targetId = msg.replyToMessageId;
        if (targetId == null) return;
        setState(() => _entries.removeWhere((e) => e.messageId == targetId));

      // ── chat / pin / 默认 ───────────────────────────────────────────────────
      default:
        // 播放进度同步消息不进入聊天列表，由一起看 Tab 监听
        if (isHubSyncMessage(msg)) return;
        _autoScroll = true;
        setState(() => _entries.add(msg));
        _scrollToBottom();
    }
  }

  void _handleSystem(HubEventSystem event) {
    switch (event) {
      // ── 撤回（服务端推送）──────────────────────────────────────────────────
      case HubSystemMessageRecalled():
        setState(
          () => _entries.removeWhere((e) => e.messageId == event.messageId),
        );
        if (!widget.isDm) {
          _addSystemMsg(HubSystemEvent.messageRecalled, {
            'messageId': event.messageId,
            'recalledBy': event.recalledBy,
          });
          if (_autoScroll) _scrollToBottom();
        }

      // ── 用户进出大厅 ────────────────────────────────────────────────────────
      case HubSystemClientJoined():
        if (widget.isDm) return;
        _addSystemMsg(HubSystemEvent.clientJoined, {
          'client': event.client.toJson(),
        });
        if (_autoScroll) _scrollToBottom();

      case HubSystemClientLeft():
        if (widget.isDm) return;
        _addSystemMsg(HubSystemEvent.clientLeft, {
          'clientName': event.clientName ?? '',
        });
        if (_autoScroll) _scrollToBottom();

      // ── 用户进出当前房间 ────────────────────────────────────────────────────
      case HubSystemClientRoomChanged():
        if (widget.isDm) return;
        if (event.roomId != ref.read(hubProvider).currentRoomId) return;
        if (event.client.userId == ref.read(hubProvider).myId) return;
        _addSystemMsg(
          event.joined
              ? HubSystemEvent.clientJoinedRoom
              : HubSystemEvent.clientLeftRoom,
          {
            'client': event.client.toJson(),
            'clientName': event.client.displayName,
          },
        );
        if (_autoScroll) _scrollToBottom();

      // ── 公告更新 ────────────────────────────────────────────────────────────
      case HubSystemRoomAnnouncement():
        final current = ref.read(hubProvider);
        ref.read(hubProvider.notifier).state = current.copyWith(
          roomList: current.roomList.map((r) {
            if (r.roomId != event.roomId) return r;
            return r.copyWith(announcements: event.announcements);
          }).toList(),
        );
        if (event.setByName.isNotEmpty) {
          App.rootContext.showMessage(
            message: '📢 ${event.setByName} ${t.updatedTheAnnouncement}',
            style: ToastStyle.topRight,
          );
        }

      case HubSystemPoked():
        if (widget.isDm) return;
        _addSystemMsg(HubSystemEvent.poked, {
          'fromId': event.fromId,
          'fromName': event.fromName,
        });
        if (_autoScroll) _scrollToBottom();

      case HubSystemUserReacted():
        if (widget.isDm) return;
        _addSystemMsg(HubSystemEvent.userReacted, {
          'fromId': event.fromId,
          'fromName': event.fromName,
          'messageId': event.messageId,
          'emojiId': event.emojiId,
          'added': event.added,
        });
        if (_autoScroll) _scrollToBottom();

      default:
        break;
    }
  }

  void _addSystemMsg(HubSystemEvent event, Map<String, dynamic> extra) {
    final msg = HubMessage(
      messageType: HubMessageType.chat,
      sender: _client.serverDto,
      targetRoomIds: [],
      segments: [
        TextSegment(jsonEncode({'event': event.value, ...extra})),
      ],
    );
    final roomId = ref.read(hubProvider).currentRoomId;
    if (roomId == null) return;
    ref.read(hubProvider.notifier).state = ref
        .read(hubProvider)
        .copyWith(
          roomList: ref.read(hubProvider).roomList.map((r) {
            if (r.roomId != roomId) return r;
            return r.copyWith(messageHistory: [...r.messageHistory, msg]);
          }).toList(),
        );
    setState(() => _entries.add(msg));
    if (_autoScroll) _scrollToBottom();
  }

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
      _mentionQuery = null;
      _pendingImages.clear();
      _inputCtrl.clear();
      _autoScroll = true;
    });

    final segments = <MessageSegment>[];
    if (text.isNotEmpty) {
      segments.addAll(await _parseTextWithLinks(text));
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

  // ── 链接转图片 / 链接预览 ───────────────────────────────────────────────────

  static final RegExp _urlRegex = RegExp(
    r"https?://[^\s<>'()\[\]{}]+",
    caseSensitive: false,
  );

  /// 图片直链后缀（去掉查询串后判断）
  static const Set<String> _imageExts = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'svg',
    'avif',
  };

  /// 先解析 @ 提及，再对纯文本段扫描 URL，把链接转成图片/预览卡片
  Future<List<MessageSegment>> _parseTextWithLinks(String text) async {
    final mentionSegs = _parseTextWithMentions(text);
    final result = <MessageSegment>[];
    for (final seg in mentionSegs) {
      if (seg is! TextSegment) {
        result.add(seg);
        continue;
      }
      result.addAll(await _convertTextUrls(seg.text));
    }
    return result;
  }

  /// 扫描一段纯文本里的 URL：图片直链→ImageSegment，网页→LinkSegment，
  /// 抓取失败则保留原始文本。支持一条消息里多个链接。
  Future<List<MessageSegment>> _convertTextUrls(String text) async {
    final result = <MessageSegment>[];
    int last = 0;
    for (final m in _urlRegex.allMatches(text)) {
      if (m.start > last) {
        result.add(TextSegment(text.substring(last, m.start)));
      }
      final raw = m.group(0)!;
      final url = _stripUrlPunctuation(raw);
      if (url.isEmpty) {
        result.add(TextSegment(raw));
      } else {
        result.add(await _buildUrlSegment(url));
        // 被剥掉的结尾标点保留为文本
        if (url.length < raw.length) {
          result.add(TextSegment(raw.substring(url.length)));
        }
      }
      last = m.end;
    }
    if (last < text.length) {
      result.add(TextSegment(text.substring(last)));
    }
    if (result.isEmpty) result.add(TextSegment(text));
    return result;
  }

  /// 去掉 URL 结尾的中英文标点（这些通常不属于链接本身）
  static final RegExp _urlTrailingPunct = RegExp(
    "[.,;:!?、，。；：！？…）)\\]}'\"»]+\$",
  );

  String _stripUrlPunctuation(String url) {
    return url.replaceFirst(_urlTrailingPunct, '');
  }

  bool _isImageUrl(String url) {
    final path = url.toLowerCase().split('?').first.split('#').first;
    final ext = path.split('.').last;
    return _imageExts.contains(ext);
  }

  Future<MessageSegment> _buildUrlSegment(String url) async {
    if (_isImageUrl(url)) {
      final fileName = url.split('/').last.split('?').first;
      return ImageSegment(url: url, alt: fileName);
    }
    final meta = await _fetchLinkMeta(url);
    if (meta != null) {
      return LinkSegment(url: url, title: meta.$1, image: meta.$2);
    }
    return TextSegment(url);
  }

  /// 抓取网页标题 + og:image 缩略图（限时 5s，失败返回 null）
  Future<(String, String?)?> _fetchLinkMeta(String url) async {
    try {
      final resp = await AppDio().request(
        url,
        options: Options(
          method: 'GET',
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 400,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
      // 非文本/非 HTML 响应（如图片、二进制）不解析
      final ct = (resp.headers.value('content-type') ?? '').toLowerCase();
      if (ct.isNotEmpty &&
          !ct.contains('html') &&
          !ct.contains('text') &&
          !ct.contains('xml')) {
        return null;
      }
      final body = resp.data;
      if (body is! String || body.isEmpty) return null;
      final doc = html_parser.parse(body);
      String? firstMeta(String selector) {
        final el = doc.querySelector(selector);
        final v = el?.attributes['content'];
        return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
      }

      final title = firstMeta('meta[property="og:title"]') ??
          firstMeta('meta[name="twitter:title"]') ??
          doc.querySelector('title')?.text.trim();

      // 相对路径缩略图补全为绝对地址
      String? toAbsolute(String? u) {
        if (u == null || u.isEmpty) return null;
        final resolved = Uri.tryParse(url)?.resolve(u).toString();
        return resolved ?? u;
      }

      final image = toAbsolute(
        firstMeta('meta[property="og:image"]') ??
            firstMeta('meta[name="twitter:image"]') ??
            firstMeta('meta[property="twitter:image:src"]') ??
            firstMeta('meta[property="og:image:secure_url"]'),
      );

      if ((title == null || title.isEmpty) && (image == null)) {
        return null;
      }
      final finalTitle = (title != null && title.isNotEmpty) ? title : url;
      return (finalTitle, image);
    } catch (_) {
      return null;
    }
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
      _replyToId = null;
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
    super.build(context);
    final hubState = ref.watch(hubProvider);
    final cs = Theme.of(context).colorScheme;

    if (!_initialScrollDone && _entries.isNotEmpty) {
      _initialScrollDone = true;
      _scrollToBottom();
    }
    final chatStack = _buildChatStack(cs, hubState);
    if (widget.embedded) {
      return chatStack;
    }
    return AppScrollBar(
      topPadding: 52,
      bottomPadding: 80,
      controller: _scroll,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: PopUpWidgetScaffold(
          title: _title,
          tailing: widget.isDm ? _buildDmActions(context, hubState) : [],
          body: chatStack,
        ),
      ),
    );
  }

  Widget _buildChatStack(ColorScheme cs, HubState hubState) {
    final room = ref.watch(hubProvider).currentRoom;
    return DropTarget(
      onDragDone: (d) => _onDragDone(d),
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Stack(
        children: [
          Column(
            children: [
              if (!widget.isDm) _buildRoomSubtitle(cs, hubState),
              if (!widget.isDm && widget.showWatchCard)
                _buildWatchRoomCard(cs, hubState),
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
                room: room,
                onOpenBangumiInfo: _bangumiInfoCallback,
                // 弹层内 PopUpWidgetScaffold 已统一处理键盘偏移，避免双重顶起；
                // 仅无 Scaffold 的全屏覆盖层（播放器面板）才手动补偿
                applyKeyboardPadding: widget.manualKeyboardPadding,
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
                        t.dropToSendImage,
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
          PopupMenuItem(value: 'mute', child: Text(t.mute)),
          PopupMenuItem(value: 'unmute', child: Text(t.unmute)),
          PopupMenuItem(value: 'kick', child: Text(t.kick)),
          PopupMenuItem(value: 'ban', child: Text(t.roomBan)),
        ],
      ),
    ];
  }

  Widget _buildRoomSubtitle(ColorScheme cs, HubState hubState) {
    final count = hubState.currentRoomClients(hubState.currentRoomId).length;
    final room = hubState.currentRoom;
    final isWatch = room?.isWatchRoom == true;
    final watchTitle = room?.animeTitle;
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
            '$count ${t.online}',
            style: TextStyle(fontSize: 12, color: cs.onSurface.toOpacity(0.5)),
          ),
          if (isWatch && watchTitle != null && watchTitle.isNotEmpty) ...[
            const SizedBox(width: 10),
            // 一起看房间：点击跳转到绑定的番剧播放页（播放页内嵌时仅文本不可跳转）
            InkWell(
              onTap: widget.showWatchCard ? _openRoomAnime : null,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      size: 13,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t.watchingAnime(a: watchTitle),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary.toOpacity(0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 12, color: cs.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 一起看房间：明显的"打开番剧"卡片（封面 + 标题 + 按钮）
  Widget _buildWatchRoomCard(ColorScheme cs, HubState hubState) {
    final room = hubState.currentRoom;
    HubLog.info(
      'HubChatPage',
      'watchCard: roomId=${room?.roomId} '
          'roomType=${room?.roomType} '
          'isWatch=${room?.isWatchRoom} '
          'animeId=${room?.animeId} '
          'animeSourceKey=${room?.animeSourceKey}',
    );
    // 只要房间携带番剧信息就显示卡片（不依赖 roomType 解析）
    if (room?.animeId == null && room?.animeSourceKey == null) {
      return const SizedBox.shrink();
    }
    final title = room?.animeTitle;
    final cover = room?.animeCover;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.toOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.toOpacity(0.4)),
      ),
      child: Row(
        children: [
          if (cover != null && cover.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BangumiWidget.kostoriImage(
                context,
                cover,
                width: 48,
                height: 64,
              ),
            )
          else
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.play_circle_outline, color: cs.primary),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.watchTogether,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  (title?.isNotEmpty == true) ? title! : '?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: _openRoomAnime,
            child: Text(t.openAnime),
          ),
        ],
      ),
    );
  }

  /// 跳转到当前一起看房间绑定的番剧播放页
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
    // 关闭所有 pop up 层（HubPage/聊天页等可能叠加多层），再在主导航跳转番剧页
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

  /// 一起看房间：Bangumi 详情按钮回调。
  /// 播放器内嵌时优先用外部传入的回调；独立聊天页则根据房间绑定的番剧补一个。
  VoidCallback? get _bangumiInfoCallback {
    if (widget.onOpenBangumiInfo != null) return widget.onOpenBangumiInfo;
    final room = ref.read(hubProvider).currentRoom;
    final hasAnime =
        room?.animeId?.isNotEmpty == true &&
        room?.animeSourceKey?.isNotEmpty == true;
    return hasAnime ? _openRoomBangumiInfo : null;
  }

  /// 打开一起看房间绑定番剧的 Bangumi 详情
  Future<void> _openRoomBangumiInfo() async {
    final room = ref.read(hubProvider).currentRoom;
    final animeId = room?.animeId;
    final sourceKey = room?.animeSourceKey;
    if (animeId == null ||
        animeId.isEmpty ||
        sourceKey == null ||
        sourceKey.isEmpty) {
      App.rootContext.showMessage(
        message: t.notBoundToBangumi,
        level: LogLevel.warning,
      );
      return;
    }
    try {
      final history = await HistoryManager().findAsync(
        animeId,
        AnimeType(sourceKey.hashCode),
      );
      final bangumiId = history?.bangumiId;
      if (bangumiId == null) {
        App.rootContext.showMessage(
          message: t.notBoundToBangumi,
          level: LogLevel.warning,
        );
        return;
      }
      if (!mounted) return;
      final infoController = ref.read(infoControllerProvider.notifier);
      showModalBottomSheet(
        isScrollControlled: true,
        context: context,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 3 / 4,
          maxWidth: MediaQuery.of(context).size.width <= 600
              ? MediaQuery.of(context).size.width
              : App.isDesktop
                  ? MediaQuery.of(context).size.width * 9 / 16
                  : MediaQuery.of(context).size.width,
        ),
        builder: (_) => BottomInfo(
          bangumiId: bangumiId,
          infoController: infoController,
        ),
      );
    } catch (_) {
      App.rootContext.showMessage(
        message: t.notBoundToBangumi,
        level: LogLevel.warning,
      );
    }
  }

  Widget _buildAnnouncementBar(ColorScheme cs, HubState hubState) {
    final announcements = hubState.currentRoom?.announcements ?? [];
    final pinnedMessages = hubState.currentRoom?.pinnedMessages ?? [];
    if (announcements.isEmpty && pinnedMessages.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      height: 42,
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
          Expanded(
            child: announcements.isEmpty
                ? const SizedBox.shrink()
                : _AnnouncementCarousel(announcements: announcements),
          ),
          if (pinnedMessages.isNotEmpty)
            InkWell(
              onTap: () => _openPinnedMessages(pinnedMessages),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.push_pin_outlined,
                  size: 15,
                  color: cs.tertiary.toOpacity(0.8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPinnedMessages(List<HubMessage> pinned) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, size: 16, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.pinnedMessages,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.toOpacity(0.3)),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: pinned.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant.toOpacity(0.2),
                ),
                itemBuilder: (_, i) {
                  final msg = pinned[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: hubAvatarColor(msg.sender.userId),
                      child: Text(
                        hubInitials(msg.sender.displayName),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      msg.sender.displayName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      msg.plainText,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.toOpacity(0.75),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _scrollToEntry(msg.messageId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMentionPopup(ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerHigh,
      elevation: 8,
      shadowColor: Colors.black.toOpacity(0.2),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.toOpacity(0.3)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
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
                            hubFileUrlOf(user.avatarUrl),
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
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (user.isBot) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'BOT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () => _onMentionSelect(user),
            );
          },
        ),
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
                  t.noMessagesYet,
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
                addAutomaticKeepAlives: true,
                itemCount: _entries.length,
                itemBuilder: (ctx, i) {
                  final entry = _entries[i];
                  final prev = i > 0 ? _entries[i - 1] : null;
                  final isSystem = entry.sender.userId == 'server';
                  final prevIsSystem =
                      prev == null || prev.sender.userId == 'server';

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
                          HubSystemRow(
                            entry: entry,
                            roomId: widget.roomId ?? '',
                          )
                        else
                          HubBubbleRow(
                            entry: entry,
                            isMe: entry.sender.userId == hubState.myId,
                            myId: hubState.myId,
                            allEntries: _entries,
                            isContinuation: isContinuation,
                            heroPrefix: _heroPrefix,
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
                      t.newMessages,
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

// ── 公告轮播 ─────────────────────────────────────────────────────────────────

class _AnnouncementCarousel extends StatefulWidget {
  final List<String> announcements;

  const _AnnouncementCarousel({required this.announcements});

  @override
  State<_AnnouncementCarousel> createState() => _AnnouncementCarouselState();
}

class _AnnouncementCarouselState extends State<_AnnouncementCarousel> {
  late final PageController _pageCtrl;
  late final ScrollController _indicatorCtrl;
  int _index = 0;

  static const _itemExtent = 8.0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _indicatorCtrl = ScrollController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _indicatorCtrl.dispose();
    super.dispose();
  }

  void _scrollIndicatorTo(int i) {
    if (!_indicatorCtrl.hasClients) return;
    final target = (i * _itemExtent) - _itemExtent;
    _indicatorCtrl.animateTo(
      target.clamp(0.0, _indicatorCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.announcements.length;

    return Row(
      children: [
        if (count > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SizedBox(
              width: 4,
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _indicatorCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: count,
                  itemExtent: _itemExtent,
                  itemBuilder: (_, i) {
                    final active = i == _index;
                    return Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: active ? 4 : 3,
                        height: active ? 14 : 4,
                        decoration: BoxDecoration(
                          color: active
                              ? cs.tertiary
                              : cs.tertiary.toOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(
              Icons.campaign_outlined,
              size: 14,
              color: cs.tertiary.toOpacity(0.8),
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: count,
            onPageChanged: (i) {
              setState(() => _index = i);
              _scrollIndicatorTo(i);
            },
            itemBuilder: (ctx, i) => InkWell(
              onTap: () => showDialog(
                context: ctx,
                builder: (_) => ContentDialog(
                  isDismissible: true,
                  displayButton: false,
                  title: t.announcement,
                  content: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 2 / 3,
                    ),
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(
                        scrollbars: false,
                      ),
                      child: SingleChildScrollView(
                        child: CustomMarkdownWidget(
                          data: widget.announcements[i],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.announcements[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.toOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
