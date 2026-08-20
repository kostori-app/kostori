import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/foundation/image_loader/base_image_provider.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/hub/hub_chat_page.dart';
import 'package:kostori/pages/hub/hub_room_settings_sheet.dart';
import 'package:kostori/utils/ext.dart';
import 'package:url_launcher/url_launcher_string.dart';

// ── 颜色工具 ──────────────────────────────────────────────────────────────────

Color hubAvatarColor(String? id) {
  if (id == null) return Colors.grey;
  const palette = [
    Color(0xFFE57373),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFFFB74D),
    Color(0xFF9575CD),
    Color(0xFF4DD0E1),
    Color(0xFFF06292),
    Color(0xFFAED581),
  ];
  return palette[id.codeUnits.fold(0, (a, b) => a + b) % palette.length];
}

String hubInitials(String name) =>
    name.isEmpty ? '?' : name.characters.first.toUpperCase();

/// 解析 Hub 相对路径（如 /hub/files/xxx.png）为绝对 URL。
/// 绝对 URL / data: 原样返回。
String hubFileUrlOf(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') ||
      url.startsWith('https://') ||
      url.startsWith('data:')) {
    return url;
  }
  if (url.startsWith('/hub/')) {
    // 优先用上传配置里的公网基础地址（外网可访问），否则按连接地址补全
    final cfg = HubUploadConfig.load();
    final publicBase = cfg.publicBaseUrl;
    if (publicBase != null && publicBase.isNotEmpty) {
      final trimmed = publicBase.endsWith('/')
          ? publicBase.substring(0, publicBase.length - 1)
          : publicBase;
      return '$trimmed$url';
    }
    final saved = appdata.implicitData['hub_client_address'] as String?;
    if (saved != null && saved.isNotEmpty) {
      // saved 形如 ws://host:port/hub 或 ws://host:port；统一为 http(s)://host:port
      var base = HubImageUploader.httpUrlOf(saved);
      final parsed = Uri.tryParse(base);
      if (parsed != null) {
        // 仅当路径确为 /hub 时剥离，避免误删主机名（如 host 就叫 hub）
        final seg = parsed.pathSegments.toList();
        if (seg.length == 1 && seg.first.toLowerCase() == 'hub') {
          base = parsed
              .replace(path: '')
              .toString()
              .replaceAll(RegExp(r'/$'), '');
        }
      }
      return '$base$url';
    }
  }
  return url;
}

bool hubNeedTimeDivider(DateTime? prev, DateTime curr) {
  if (prev == null) return true;
  return curr.difference(prev).inMinutes >= 5;
}

Future<Uint8List> hubCompressImage(
  Uint8List bytes, {
  int maxDim = 1920,
  int quality = 82,
}) async {
  try {
    final result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: maxDim,
      minHeight: maxDim,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return result;
  } catch (_) {
    return bytes;
  }
}

// ── 播放进度同步（一起看）─────────────────────────────────────────────────────
// 通过带标记的广播消息在房间内同步房主播放进度，客户端过滤后不渲染为聊天气泡。

/// 播放同步消息前缀（聊天气泡渲染时据此过滤）
const String hubSyncPrefix = 'KOSTORI_SYNC:';

/// 是否是一条播放进度同步消息（不渲染为普通聊天气泡）
bool isHubSyncMessage(HubMessage msg) {
  final text = msg.segments.whereType<TextSegment>().firstOrNull?.text ?? '';
  return text.startsWith(hubSyncPrefix);
}

/// 编码播放同步广播文本
String encodeHubSync({
  required int episode,
  required int positionMs,
  required bool playing,
  String animeId = '',
  String title = '',
  String sourceKey = '',
  String cover = '',
  String senderId = '',
}) =>
    '$hubSyncPrefix${jsonEncode({'episode': episode, 'position': positionMs, 'playing': playing, 'animeId': animeId, 'title': title, 'sourceKey': sourceKey, 'cover': cover, 'senderId': senderId, 'sentAt': DateTime.now().millisecondsSinceEpoch})}';

/// 从一条同步消息中解析播放进度
class HubPlaybackSync {
  final String senderId;
  final int episode;
  final int positionMs;
  final bool playing;
  final String animeId;
  final String title;
  final String sourceKey;
  final String cover;
  final int sentAt;

  const HubPlaybackSync({
    required this.senderId,
    required this.episode,
    required this.positionMs,
    required this.playing,
    required this.animeId,
    required this.title,
    this.sourceKey = '',
    this.cover = '',
    required this.sentAt,
  });

  static HubPlaybackSync? fromText(String text) {
    if (!text.startsWith(hubSyncPrefix)) return null;
    try {
      final json = jsonDecode(text.substring(hubSyncPrefix.length));
      if (json is! Map<String, dynamic>) return null;
      return HubPlaybackSync(
        senderId: json['senderId'] as String? ?? '',
        episode: (json['episode'] as num?)?.toInt() ?? 0,
        positionMs: (json['position'] as num?)?.toInt() ?? 0,
        playing: json['playing'] as bool? ?? false,
        animeId: json['animeId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        sourceKey: json['sourceKey'] as String? ?? '',
        cover: json['cover'] as String? ?? '',
        sentAt: (json['sentAt'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static HubPlaybackSync? fromMessage(HubMessage msg) {
    final text = msg.segments.whereType<TextSegment>().firstOrNull?.text ?? '';
    final parsed = fromText(text);
    if (parsed == null) return null;
    return HubPlaybackSync(
      senderId: msg.sender.userId,
      episode: parsed.episode,
      positionMs: parsed.positionMs,
      playing: parsed.playing,
      animeId: parsed.animeId,
      title: parsed.title,
      sourceKey: parsed.sourceKey,
      cover: parsed.cover,
      sentAt: parsed.sentAt,
    );
  }
}

// ── 时间分割线 ────────────────────────────────────────────────────────────────

class HubTimeDivider extends StatelessWidget {
  final DateTime time;

  const HubTimeDivider({super.key, required this.time});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: cs.outlineVariant.toOpacity(0.4),
              thickness: 0.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$h:$m',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.toOpacity(0.35),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: cs.outlineVariant.toOpacity(0.4),
              thickness: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 系统消息行 ────────────────────────────────────────────────────────────────

class HubSystemRow extends ConsumerWidget {
  final HubMessage entry;
  final String roomId;

  const HubSystemRow({super.key, required this.entry, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentRoomId = ref.watch(hubProvider).currentRoomId;
    final raw = entry.segments.whereType<TextSegment>().firstOrNull?.text;
    if (raw == null) return const SizedBox.shrink();
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final payload = HubSystemPayload.fromJson(json);
    if (payload == null) return const SizedBox.shrink();

    if (payload is HubPayloadClientJoinedRoom ||
        payload is HubPayloadClientLeftRoom) {
      if (roomId != currentRoomId) return const SizedBox.shrink();
    }

    if (payload is HubPayloadClientJoined || payload is HubPayloadClientLeft) {
      return const SizedBox.shrink();
    }

    final text = switch (payload) {
      HubPayloadClientJoined() => '',
      HubPayloadClientLeft() => '',
      HubPayloadClientJoinedRoom() =>
        '${payload.displayName} ${t.joinedTheRoom}',
      HubPayloadClientLeftRoom() => '${payload.clientName} ${t.leftTheRoom}',
      HubPayloadRoomWelcome() => payload.message,
      HubPayloadClientKickedFromRoom() => t.pWasKickedByO(
        p: payload.clientName,
        o: payload.operatorName,
      ),
      HubPayloadPoked() => '${payload.fromName} ${t.pokedYou} 👉',
      HubPayloadMessageRecalled() =>
        '${payload.recalledBy} ${t.recalledAMessage}',
      HubPayloadReacted() =>
        payload.added
            ? t.pReactedWithO(p: payload.fromName, o: payload.emojiId)
            : t.pRemovedReactionO(p: payload.fromName, o: payload.emojiId),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: cs.onSurface.toOpacity(0.45)),
          ),
        ),
      ),
    );
  }
}

// ── 气泡行 ────────────────────────────────────────────────────────────────────

class HubBubbleRow extends StatefulWidget {
  final HubMessage entry;
  final bool isMe;
  final String? myId;
  final List<HubMessage> allEntries;
  final bool isContinuation;
  final void Function(String messageId) onReply;
  final void Function(String messageId, String emojiId) onReact;
  final void Function(String messageId) onRecall;
  final void Function(String messageId) onScrollToEntry;
  final List<String> roomModeratorIds;
  final void Function(String userId)? onPoke;
  final void Function(HubClientDto sender)? onMention;
  final String heroPrefix;

  const HubBubbleRow({
    super.key,
    required this.entry,
    required this.isMe,
    required this.myId,
    required this.allEntries,
    required this.isContinuation,
    required this.onReply,
    required this.onReact,
    required this.onRecall,
    required this.onScrollToEntry,
    required this.roomModeratorIds,
    required this.heroPrefix,
    this.onPoke,
    this.onMention,
  });

  @override
  State<HubBubbleRow> createState() => _HubBubbleRowState();
}

class _HubBubbleRowState extends State<HubBubbleRow> {
  bool _pokeCooling = false;
  OverlayEntry? _overlayEntry;
  static OverlayEntry? _activeOverlay;

  bool get _isPureImage =>
      widget.entry.segments.isNotEmpty &&
      widget.entry.segments.every((s) => s is ImageSegment);

  void _poke(String userId) {
    if (_pokeCooling) return;
    widget.onPoke?.call(userId);
    setState(() => _pokeCooling = true);
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _pokeCooling = false);
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // 如果当前实例是全局活跃的，清除全局引用
    if (_globalRemoveOverlay == _removeOverlay) {
      _globalRemoveOverlay = null;
    }
  }

  VoidCallback? _globalRemoveOverlay;

  static void _dismissActiveOverlay() {
    _activeOverlay?.remove();
    _activeOverlay = null;
  }

  void _showActions(BuildContext context, ColorScheme cs) {
    // 先关掉上一个（不管是哪个实例的）
    _dismissActiveOverlay();
    final hasImage = widget.entry.segments.whereType<ImageSegment>().isNotEmpty;
    final isMe = widget.isMe;

    // 气泡全局区域：菜单精确定位到长按的消息附近（宽屏下不再固定居中于整屏）
    Rect? bubbleRect;
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        bubbleRect = box.localToGlobal(Offset.zero) & box.size;
      }
    } catch (_) {}

    final overlay = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.of(context).size;

    final entry = OverlayEntry(
      builder: (_) => _MessageActionMenu(
        cs: cs,
        isMe: isMe,
        hasImage: hasImage,
        isPureImage: _isPureImage,
        bubbleRect: bubbleRect,
        screenSize: screenSize,
        entry: widget.entry,
        onDismiss: _dismissActiveOverlay,
        onReact: (emojiId) => widget.onReact(widget.entry.messageId, emojiId),
        onReply: () => widget.onReply(widget.entry.messageId),
        onRecall: () => widget.onRecall(widget.entry.messageId),
      ),
    );
    _activeOverlay = entry;
    overlay.insert(entry);
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRoomAdmin = widget.roomModeratorIds.contains(
      widget.entry.sender.userId,
    );
    final cs = Theme.of(context).colorScheme;
    final replyEntry = widget.entry.replyToMessageId != null
        ? widget.allEntries.firstWhereOrNull(
            (e) => e.messageId == widget.entry.replyToMessageId,
          )
        : null;

    const avatarRadius = 17.0;
    const avatarDiam = avatarRadius * 2;
    const avatarGap = 8.0;
    final maxW =
        MediaQuery.of(context).size.width -
        24 -
        avatarDiam -
        avatarGap -
        (avatarDiam + avatarGap);

    final bubbleColor = widget.isMe ? cs.primary : cs.surfaceContainerHighest;
    final textColor = widget.isMe ? cs.onPrimary : cs.onSurface;

    // ── 头像 ──────────────────────────────────────────────────────────────────
    final avatarUrl = widget.entry.sender.avatarUrl;

    Widget buildInitials(HubMessage entry) => Text(
      hubInitials(entry.sender.displayName),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    final avatarWidget = !widget.isContinuation
        ? GestureDetector(
            onDoubleTap: () => _poke(widget.entry.sender.userId),
            onLongPress: () => widget.onMention?.call(widget.entry.sender),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: hubAvatarColor(widget.entry.sender.userId),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: AnimatedImage(
                        image: CachedImageProvider(
                          hubFileUrlOf(avatarUrl),
                          sourceKey: 'hub',
                        ),
                        width: avatarDiam,
                        height: avatarDiam,
                        fit: BoxFit.cover,
                      ),
                    )
                  : buildInitials(widget.entry),
            ),
          )
        : const SizedBox(width: avatarDiam);

    // ── 引用块 ─────────────────────────────────────────────────────────────────
    Widget? replyWidget;
    if (replyEntry != null) {
      final replyBg = widget.isMe
          ? cs.primaryContainer.toOpacity(0.45)
          : cs.surfaceContainer;
      final replyAccent = widget.isMe ? cs.onPrimaryContainer : cs.primary;

      final replyHasImage = replyEntry.segments
          .whereType<ImageSegment>()
          .isNotEmpty;
      final Widget replyPreview = replyHasImage
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 12,
                  color: widget.isMe
                      ? cs.onPrimaryContainer.toOpacity(0.6)
                      : cs.onSurface.toOpacity(0.5),
                ),
                const SizedBox(width: 3),
                Text(
                  t.image,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isMe
                        ? cs.onPrimaryContainer.toOpacity(0.7)
                        : cs.onSurface.toOpacity(0.6),
                  ),
                ),
              ],
            )
          : Text(
              replyEntry.plainText,
              style: TextStyle(
                fontSize: 12,
                color: widget.isMe
                    ? cs.onPrimaryContainer.toOpacity(0.7)
                    : cs.onSurface.toOpacity(0.6),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );

      replyWidget = Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => widget.onScrollToEntry(replyEntry.messageId),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxW),
              decoration: BoxDecoration(
                color: replyBg,
                border: Border(left: BorderSide(color: replyAccent, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          replyEntry.sender.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: replyAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        replyPreview,
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.vertical_align_top,
                    size: 14,
                    color: replyAccent.toOpacity(0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── 时间字符串 ─────────────────────────────────────────────────────────────
    final local = widget.entry.sentAt.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    final bubbleBr = widget.isContinuation
        ? BorderRadius.circular(14)
        : BorderRadius.only(
            topLeft: Radius.circular(widget.isMe ? 14 : 3),
            topRight: Radius.circular(widget.isMe ? 3 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          );

    // ── 气泡 ───────────────────────────────────────────────────────────────────
    final Widget bubbleWidget;

    if (_isPureImage) {
      bubbleWidget = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(
          crossAxisAlignment: widget.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.entry.segments.whereType<ImageSegment>().map(
              (seg) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _BubbleImage(
                  url: seg.url,
                  borderRadius: bubbleBr,
                  messageId: widget.entry.messageId,
                  heroPrefix: widget.heroPrefix,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: cs.onSurface.toOpacity(0.35),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      final imageSegs = widget.entry.segments
          .whereType<ImageSegment>()
          .toList();
      final linkSegs = widget.entry.segments.whereType<LinkSegment>().toList();

      bubbleWidget = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: bubbleBr,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: widget.entry.segments
                        .where(
                          (s) =>
                              s is TextSegment ||
                              s is MentionSegment ||
                              s is QuoteSegment,
                        )
                        .map((s) {
                          if (s is MentionSegment) {
                            return TextSpan(
                              text: '@${s.displayName}',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: widget.isMe ? cs.onPrimary : cs.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                          if (s is QuoteSegment) {
                            // 回复引用：斜体 + 引用色
                            final preview = s.preview.trim();
                            final label = s.fromName.isNotEmpty
                                ? '${s.fromName}: '
                                : '';
                            return TextSpan(
                              text: preview.isEmpty ? t.replyBracket : '$label$preview',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                                color: widget.isMe
                                    ? cs.onPrimary.toOpacity(0.7)
                                    : textColor.toOpacity(0.6),
                              ),
                            );
                          }
                          return TextSpan(
                            text: (s as TextSegment).text,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              height: 1.4,
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
                ...imageSegs.map(
                  (seg) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _BubbleImage(
                        url: seg.url,
                        borderRadius: BorderRadius.circular(8),
                        messageId: widget.entry.messageId,
                        heroPrefix: widget.heroPrefix,
                      ),
                    ),
                  ),
                ),
                ...linkSegs.map(
                  (seg) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _BubbleLinkCard(
                      url: seg.url,
                      title: seg.title,
                      image: seg.image,
                      isMe: widget.isMe,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      color: widget.isMe
                          ? cs.onPrimary.toOpacity(0.5)
                          : cs.onSurface.toOpacity(0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── 表情反应 ───────────────────────────────────────────────────────────────
    Widget? reactionsWidget;
    final visible = widget.entry.reactions
        .where((r) => r.users.isNotEmpty)
        .toList();
    if (visible.isNotEmpty) {
      reactionsWidget = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: visible.map((r) {
            final count = r.users.length;
            final iMine =
                widget.myId != null &&
                r.users.any((u) => u.userId == widget.myId);
            return GestureDetector(
              onTap: () => widget.onReact(widget.entry.messageId, r.emojiId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: iMine
                      ? cs.primaryContainer
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: iMine
                        ? cs.primary.toOpacity(0.5)
                        : cs.outlineVariant.toOpacity(0.5),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HubEmoji.render(r.emojiId, size: 14),
                    if (count > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          color: iMine
                              ? cs.primary
                              : cs.onSurface.toOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // ── 内容列 ─────────────────────────────────────────────────────────────────
    final contentCol = Column(
      crossAxisAlignment: widget.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isContinuation)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!widget.isMe && widget.entry.sender.isGlobalAdmin) ...[
                  _AdminBadge(label: 'Admin', color: const Color(0xFFFFB300)),
                  const SizedBox(width: 4),
                ] else if (!widget.isMe && isRoomAdmin) ...[
                  _AdminBadge(label: 'Mod', color: const Color(0xFF81C784)),
                  const SizedBox(width: 4),
                ] else if (!widget.isMe && widget.entry.sender.isBot) ...[
                  _AdminBadge(label: 'BOT', color: const Color(0xFF64B5F6)),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.entry.sender.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (widget.isMe && widget.entry.sender.isGlobalAdmin) ...[
                  const SizedBox(width: 4),
                  _AdminBadge(label: 'Admin', color: const Color(0xFFFFB300)),
                ] else if (widget.isMe && isRoomAdmin) ...[
                  const SizedBox(width: 4),
                  _AdminBadge(label: 'Mod', color: const Color(0xFF81C784)),
                ],
                if (widget.isMe && widget.entry.sender.isBot) ...[
                  const SizedBox(width: 4),
                  _AdminBadge(label: 'BOT', color: const Color(0xFF64B5F6)),
                ],
              ],
            ),
          ),
        if (replyWidget != null) replyWidget,
        GestureDetector(
          onLongPress: () {
            _showActions(context, cs);
          },
          child: bubbleWidget,
        ),
        if (reactionsWidget != null) reactionsWidget,
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: widget.isContinuation ? 2 : 8, bottom: 2),
      child: Row(
        mainAxisAlignment: widget.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.isMe
            ? [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: contentCol,
                  ),
                ),
                const SizedBox(width: avatarGap),
                avatarWidget,
              ]
            : [
                avatarWidget,
                const SizedBox(width: avatarGap),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: contentCol,
                  ),
                ),
              ],
      ),
    );
  }
}

// ── 悬浮托盘按钮 ────────────────────────────────────────────────────────────────
class _TrayBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _TrayBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 长按消息操作菜单：精确定位到消息附近 + 缩放渐显动画 ───────────────────────

class _MessageActionMenu extends StatefulWidget {
  final ColorScheme cs;
  final bool isMe;
  final bool hasImage;
  final bool isPureImage;
  final Rect? bubbleRect;
  final Size screenSize;
  final HubMessage entry;
  final VoidCallback onDismiss;
  final void Function(String emojiId) onReact;
  final VoidCallback onReply;
  final VoidCallback onRecall;

  const _MessageActionMenu({
    required this.cs,
    required this.isMe,
    required this.hasImage,
    required this.isPureImage,
    required this.bubbleRect,
    required this.screenSize,
    required this.entry,
    required this.onDismiss,
    required this.onReact,
    required this.onReply,
    required this.onRecall,
  });

  @override
  State<_MessageActionMenu> createState() => _MessageActionMenuState();
}

class _MessageActionMenuState extends State<_MessageActionMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  late final Animation<double> _scale = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  static const double _menuWidth = 280;

  /// 估算高度（仅用于上下定位判断，实际高度由内容撑开）
  static const double _estHeight = 150;

  static double _clampD(double v, double lo, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  Offset _computePosition() {
    final rect = widget.bubbleRect;
    final size = widget.screenSize;
    if (rect == null) {
      return Offset(
        (size.width - _menuWidth) / 2,
        (size.height - _estHeight) / 2,
      );
    }
    final left = _clampD(
      rect.center.dx - _menuWidth / 2,
      12,
      size.width - _menuWidth - 12,
    );
    const margin = 8.0;
    double top;
    if (rect.top > _estHeight + margin + 12) {
      top = rect.top - _estHeight - margin;
    } else {
      top = rect.bottom + margin;
    }
    top = _clampD(top, 12, size.height - _estHeight - 12);
    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    final pos = _computePosition();
    final cs = widget.cs;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onDismiss,
      child: Stack(
        children: [
          Positioned(
            left: pos.dx,
            top: pos.dy,
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _anim,
                child: BlurEffect(
                  borderRadius: BorderRadius.circular(20),
                  child: Material(
                    color: cs.surfaceContainerHigh.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: _menuWidth,
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 快捷表情
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ...HubEmoji.quickBar.map(
                                (e) => _QuickEmojiBtn(
                                  emoji: e,
                                  onTap: () {
                                    widget.onDismiss();
                                    widget.onReact(e.id);
                                  },
                                ),
                              ),
                              _MoreEmojiBtn(
                                onTap: () {
                                  widget.onDismiss();
                                  HubEmojiPicker.show(
                                    context,
                                    Offset(
                                      widget.screenSize.width / 2,
                                      widget.screenSize.height * 0.8,
                                    ),
                                    onPick: widget.onReact,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (!widget.isPureImage)
                                Expanded(
                                  child: _TrayBtn(
                                    icon: Icons.copy_outlined,
                                    label: t.copy,
                                    onTap: () {
                                      widget.onDismiss();
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: widget.entry.plainText,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (widget.hasImage)
                                Expanded(
                                  child: _TrayBtn(
                                    icon: Icons.mood_outlined,
                                    label: t.memes,
                                    onTap: () {
                                      widget.onDismiss();
                                      for (final seg in widget.entry.segments
                                          .whereType<ImageSegment>()) {
                                        HubStickerManager.add(
                                          HubSticker(url: seg.url),
                                        );
                                      }
                                      App.rootContext.showMessage(
                                        message: t.memeSaved,
                                        level: LogLevel.info,
                                      );
                                    },
                                  ),
                                ),
                              Expanded(
                                child: _TrayBtn(
                                  icon: Icons.reply_outlined,
                                  label: t.reply,
                                  onTap: () {
                                    widget.onDismiss();
                                    widget.onReply();
                                  },
                                ),
                              ),
                              if (widget.isMe)
                                Expanded(
                                  child: _TrayBtn(
                                    icon: Icons.undo_outlined,
                                    label: t.recall,
                                    color: cs.error,
                                    onTap: () {
                                      widget.onDismiss();
                                      widget.onRecall();
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 气泡图片组件 ──────────────────────────────────────────────────────────────

class _BubbleImage extends StatelessWidget {
  final String url;
  final BorderRadius borderRadius;
  final String messageId;
  final String heroPrefix;
  static const double _maxWidth = 220;
  static const double _fixedHeight = 200; // 固定外框高度，避免抽搐
  const _BubbleImage({
    required this.url,
    required this.borderRadius,
    required this.messageId,
    required this.heroPrefix,
  });

  /// Hero 标签：同一房间聊天可能同时存在多个实例（一起看 Tab + 全屏浮层），
  /// 用 heroPrefix 区分实例，用 url.hashCode 区分同一消息里的多张图，
  /// 避免 tag 冲突导致 Hero 崩溃。
  String get _heroTag => '$heroPrefix-$messageId-${url.hashCode}';

  /// Hero 转场：统一用预览页（目标）的图片作为 shuttle，
  /// 避免气泡固定高度(BoxFit.contain)在返回时造成的缩放跳变。
  Widget _buildHero(Widget child) {
    return Hero(
      tag: _heroTag,
      flightShuttleBuilder:
          (flightContext, animation, direction, fromContext, toContext) {
            return direction == HeroFlightDirection.pop
                ? (fromContext.widget as Hero).child
                : (toContext.widget as Hero).child;
          },
      child: child,
    );
  }

  bool get _isBase64 => url.startsWith('data:');

  bool get _isLocalFile =>
      url.startsWith('file://') ||
      (url.startsWith('/') && !url.startsWith('/hub/'));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: SizedBox(
            height: _fixedHeight,
            child: _isBase64
                ? _buildBase64()
                : _isLocalFile
                ? _buildLocalFile()
                : _buildNetwork(),
          ),
        ),
      ),
    );
  }

  /// 读取本地文件图片（Koishi 与 Hub 同机时，file:// 路径可直接读）
  Widget _buildLocalFile() {
    try {
      final raw = url.replaceFirst('file://', '');
      final path = Uri.tryParse(raw)?.toFilePath() ?? raw;
      if (!File(path).existsSync()) return _placeholder();
      return _buildHero(
        Image.file(
          File(path),
          height: _fixedHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _buildNetwork() {
    return _buildHero(
      AnimatedImage(
        image: CachedImageProvider(hubFileUrlOf(url), sourceKey: 'hub'),
        height: _fixedHeight,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildBase64() {
    try {
      return _buildHero(
        AnimatedImage(
          // Base64ImageProvider key 稳定（按 base64 前缀），避免每次 build 重解码闪烁
          image: Base64ImageProvider(url),
          height: _fixedHeight,
          fit: BoxFit.contain,
        ),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  void _openFullscreen(BuildContext context) async {
    if (_isBase64) {
      try {
        final data = base64Decode(url.split(',').last);
        final tmp = File(
          '${Directory.systemTemp.path}/hub_img_${url.hashCode}.jpg',
        );
        if (!await tmp.exists()) {
          await tmp.writeAsBytes(data);
        }
        await BangumiWidget.showImagePreview(
          context: App.rootContext,
          url: tmp.path,
          title: '',
          heroTag: _heroTag,
        );
      } catch (e) {
        HubLog.error('HubBubbleImage', '$e');
      }
    } else if (_isLocalFile) {
      try {
        final raw = url.replaceFirst('file://', '');
        final path = Uri.tryParse(raw)?.toFilePath() ?? raw;
        await BangumiWidget.showImagePreview(
          context: App.rootContext,
          url: path,
          title: '',
          heroTag: _heroTag,
        );
      } catch (e) {
        HubLog.error('HubBubbleImage', '$e');
      }
    } else {
      await BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: url,
        title: '',
        heroTag: _heroTag,
      );
    }
  }

  Widget _placeholder() => Container(
    width: 200,
    height: 220,
    color: Colors.black12,
    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
  );
}

/// 链接预览卡片：标题 + 缩略图 + 域名，点击打开链接
class _BubbleLinkCard extends StatelessWidget {
  final String url;
  final String title;
  final String? image;
  final bool isMe;

  const _BubbleLinkCard({
    required this.url,
    required this.title,
    required this.image,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final host = Uri.tryParse(url)?.host ?? url;
    final displayTitle = title.isNotEmpty ? title : host;
    final hasImage = image != null && image!.isNotEmpty;
    return GestureDetector(
      onTap: () => launchUrlString(url),
      child: Container(
        width: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isMe
                    ? Colors.white
                    : cs.outlineVariant)
                .withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              SizedBox(
                width: 220,
                height: 116,
                child: AnimatedImage(
                  image: CachedImageProvider(image!, sourceKey: 'hub'),
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : cs.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: (isMe ? Colors.white : cs.onSurface).withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 快捷 emoji 按钮 ───────────────────────────────────────────────────────────

class _QuickEmojiBtn extends StatelessWidget {
  final HubEmojiDef emoji;
  final VoidCallback onTap;

  const _QuickEmojiBtn({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: emoji.toWidget(size: 26),
      ),
    );
  }
}

class _MoreEmojiBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _MoreEmojiBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.add_reaction_outlined,
          size: 26,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ── 输入栏 ────────────────────────────────────────────────────────────────────

class HubInputBar extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPasteImage;
  final VoidCallback onOpenStickers;
  final bool isDesktop;
  final bool uploading;
  final List<PendingImage> pendingImages;
  final void Function(int index) onRemovePending;
  final HubRoomDto? room;

  /// 打开番剧详情（Bangumi BottomInfo）的回调，仅一起看房间需要
  final VoidCallback? onOpenBangumiInfo;

  /// 是否需要手动补偿软键盘高度。
  /// 播放器全屏聊天面板（embedded，无 PopUpWidgetScaffold）需要；
  /// 弹层内（PopUpWidgetScaffold 已通过 keyboardOffset 统一处理）不需要，避免双重顶起。
  final bool applyKeyboardPadding;

  const HubInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickImage,
    required this.onPasteImage,
    required this.onOpenStickers,
    required this.isDesktop,
    this.uploading = false,
    required this.pendingImages,
    required this.onRemovePending,
    required this.room,
    this.onOpenBangumiInfo,
    this.applyKeyboardPadding = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // 跟随软键盘：弹出时输入框上移（嵌入式/无 Scaffold 调整时也生效）。
    // 仅当需要手动补偿时启用；弹层内 PopUpWidgetScaffold 已统一处理，避免双重叠加
    final keyboardBottom = applyKeyboardPadding
        ? (MediaQuery.of(context).viewInsets.bottom -
                  MediaQuery.of(context).padding.bottom)
              .clamp(0.0, double.infinity)
        : 0.0;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: Container(
        padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.toOpacity(0.4),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingImages.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  itemCount: pendingImages.length,
                  itemBuilder: (_, i) {
                    final img = pendingImages[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: img.isNetwork
                                ? Image.network(
                                    img.networkUrl!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.black12,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : Image.memory(
                                    img.bytes!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => onRemovePending(i),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            // ── 输入框 + 发送按钮 ───────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent || !isDesktop) {
                        return KeyEventResult.ignored;
                      }
                      // 支持粘贴剪贴板图片（Ctrl+V）
                      if (event.logicalKey == LogicalKeyboardKey.keyV &&
                          HardwareKeyboard.instance.isControlPressed) {
                        onPasteImage();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter) {
                        if (HardwareKeyboard.instance.isControlPressed) {
                          final t = controller.text;
                          final s = controller.selection;
                          controller.value = TextEditingValue(
                            text: t.replaceRange(s.start, s.end, '\n'),
                            selection: TextSelection.collapsed(
                              offset: s.start + 1,
                            ),
                          );
                          return KeyEventResult.handled;
                        }
                        onSend();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: 4,
                      minLines: 1,
                      // 点击输入框外部时取消焦点，避免"没点输入框却在打字"
                      onTapOutside: (_) => focusNode.unfocus(),
                      style: TextStyle(fontSize: 14, color: cs.onSurface),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: isDesktop
                            ? t.enterToSendCtrlEnterForNewline
                            : t.message,
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.toOpacity(0.35),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.toOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: cs.primary.toOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // ── 发送按钮 ──────────────────────────────────────────────
                Material(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: onSend,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.send_rounded,
                        size: 17,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── 工具栏（图片 + 表情包）─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: uploading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: PolygonRefreshIndicator(),
                          )
                        : Icon(
                            Icons.image_outlined,
                            size: 20,
                            color: cs.onSurface.toOpacity(0.5),
                          ),
                    onPressed: uploading ? null : onPickImage,
                    tooltip: t.image,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.emoji_emotions_outlined,
                      size: 20,
                      color: cs.onSurface.toOpacity(0.5),
                    ),
                    onPressed: onOpenStickers,
                    tooltip: t.memes,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const Spacer(),
                  if (onOpenBangumiInfo != null)
                    IconButton(
                      onPressed: onOpenBangumiInfo,
                      icon: Icon(
                        Icons.movie_outlined,
                        size: 20,
                        color: cs.onSurface.toOpacity(0.5),
                      ),
                      tooltip: t.bangumiInfo,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  if (room != null)
                    IconButton(
                      onPressed: () => showHubRoomSettingsSheet(context, room!),
                      icon: Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: cs.onSurface.toOpacity(0.5),
                      ),
                      tooltip: t.roomSettings,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HubStickerPanel extends StatefulWidget {
  final void Function(HubSticker sticker) onSend;

  const HubStickerPanel({super.key, required this.onSend});

  @override
  State<HubStickerPanel> createState() => _HubStickerPanelState();
}

class _HubStickerPanelState extends State<HubStickerPanel> {
  late List<HubSticker> _stickers;

  @override
  void initState() {
    super.initState();
    _stickers = HubStickerManager.load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ), // ← 加这行
        border: Border(
          top: BorderSide(color: cs.outlineVariant.toOpacity(0.3), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.emoji_emotions_outlined, size: 16),
                const SizedBox(width: 6),
                Text(t.stickers, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(
                  t.longPressImageToSave,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.toOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant.toOpacity(0.3)),
          // 网格
          Expanded(
            child: _stickers.isEmpty
                ? Center(
                    child: Text(
                      t.noStickersYet,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.toOpacity(0.4),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: _stickers.length,
                    itemBuilder: (context, i) {
                      final s = _stickers[i];
                      return GestureDetector(
                        onTap: () => widget.onSend(s),
                        onLongPress: () => _confirmDelete(context, s),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildStickerImage(s),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerImage(HubSticker s) {
    if (s.isBase64) {
      try {
        final data = base64Decode(s.url.split(',').last);
        return Image.memory(data, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.broken_image_outlined);
      }
    }
    return Image.network(
      s.url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }

  void _confirmDelete(BuildContext context, HubSticker s) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                t.removeSticker,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                HubStickerManager.remove(s.url);
                setState(() => _stickers = HubStickerManager.load());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HubEmojiPicker {
  static void show(
    BuildContext context,
    Offset globalOffset, {
    required void Function(String emojiId) onPick,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, _) =>
          _EmojiPickerOverlay(globalOffset: globalOffset, onPick: onPick),
    );
  }
}

class _EmojiPickerOverlay extends StatefulWidget {
  final Offset globalOffset;
  final void Function(String emojiId) onPick;

  const _EmojiPickerOverlay({required this.globalOffset, required this.onPick});

  @override
  State<_EmojiPickerOverlay> createState() => _EmojiPickerOverlayState();
}

class _EmojiPickerOverlayState extends State<_EmojiPickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _pick(String id) {
    Navigator.pop(context);
    widget.onPick(id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    const popW = 280.0;
    const fullH = 360.0;
    final h = fullH;
    double left = widget.globalOffset.dx - popW / 2;
    double top = widget.globalOffset.dy - h - 8;
    left = left.clamp(8.0, size.width - popW - 8);
    top = top.clamp(8.0, size.height - h - 8);

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: popW,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomCenter,
              child: Material(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                elevation: 8,
                shadowColor: Colors.black26,
                child: _fullGrid(cs),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 完整网格 ───────────────────────────────────────────────────────────────
  Widget _fullGrid(ColorScheme cs) {
    return SizedBox(
      height: 360,
      child: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Emoji',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: HubEmoji.groups.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.toOpacity(0.45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GridView.count(
                      crossAxisCount: 8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      children: entry.value
                          .map(
                            (e) => _EmojiBtn(
                              emoji: e,
                              size: 24,
                              onTap: () => _pick(e.id),
                            ),
                          )
                          .toList(),
                    ),
                    // 自定义 emoji 分组
                    if (HubEmoji.custom.isNotEmpty &&
                        entry.key == HubEmoji.groups.keys.last) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.toOpacity(0.45),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GridView.count(
                        crossAxisCount: 8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        children: HubEmoji.custom
                            .map(
                              (e) => _EmojiBtn(
                                emoji: e,
                                size: 24,
                                onTap: () => _pick(e.id),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiBtn extends StatelessWidget {
  final HubEmojiDef emoji;
  final double size;
  final VoidCallback onTap;

  const _EmojiBtn({
    required this.emoji,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Center(child: emoji.toWidget(size: size)),
    );
  }
}

class _AdminBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _AdminBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.toOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.toOpacity(0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
