import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kostori/components/bangumi_widget.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/image_loader/cached_image.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/pages/hub/hub_chat_page.dart';
import 'package:kostori/pages/hub/hub_room_settings_sheet.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

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
        '${payload.displayName} ${"joined the room".tl}',
      HubPayloadClientLeftRoom() =>
        '${payload.clientName} ${"left the room".tl}',
      HubPayloadRoomWelcome() => payload.message,
      HubPayloadClientKickedFromRoom() => '@p was kicked by @o'.tlParams({
        'p': payload.clientName,
        'o': payload.operatorName,
      }),
      HubPayloadPoked() => '${payload.fromName} ${"poked you".tl} 👉',
      HubPayloadMessageRecalled() =>
        '${payload.recalledBy} ${"recalled a message".tl}',
      HubPayloadReacted() =>
        payload.added
            ? '@p reacted with @o'.tlParams({
                'p': payload.fromName,
                'o': payload.emojiId,
              })
            : '@p removed reaction @o'.tlParams({
                'p': payload.fromName,
                'o': payload.emojiId,
              }),
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
    final entry = OverlayEntry(
      builder: (_) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _dismissActiveOverlay,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom + 120,
                child: Center(
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(16),
                    color: cs.surfaceContainer,
                    child: SizedBox(
                      width: 260,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                              child: Wrap(
                                alignment: WrapAlignment.spaceEvenly,
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...HubEmoji.quickBar.map(
                                    (e) => _QuickEmojiBtn(
                                      emoji: e,
                                      onTap: () {
                                        _dismissActiveOverlay();
                                        widget.onReact(
                                          widget.entry.messageId,
                                          e.id,
                                        );
                                      },
                                    ),
                                  ),
                                  _MoreEmojiBtn(
                                    onTap: () {
                                      _dismissActiveOverlay();
                                      final size = MediaQuery.of(context).size;
                                      final centerOffset = Offset(
                                        size.width / 2,
                                        size.height * 0.8,
                                      );
                                      HubEmojiPicker.show(
                                        context,
                                        centerOffset,
                                        onPick: (emojiId) => widget.onReact(
                                          widget.entry.messageId,
                                          emojiId,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: cs.outlineVariant.toOpacity(0.3),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  if (!_isPureImage)
                                    Expanded(
                                      child: _TrayBtn(
                                        icon: Icons.copy_outlined,
                                        label: 'Copy'.tl,
                                        onTap: () {
                                          _dismissActiveOverlay();
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: widget.entry.plainText,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  if (hasImage)
                                    Expanded(
                                      child: _TrayBtn(
                                        icon: Icons.mood_outlined,
                                        label: 'Memes'.tl,
                                        onTap: () {
                                          _dismissActiveOverlay();
                                          for (final seg
                                              in widget.entry.segments
                                                  .whereType<ImageSegment>()) {
                                            HubStickerManager.add(
                                              HubSticker(url: seg.url),
                                            );
                                          }
                                          App.rootContext.showMessage(
                                            message: 'Meme saved'.tl,
                                            level: LogLevel.info,
                                          );
                                        },
                                      ),
                                    ),
                                  Expanded(
                                    child: _TrayBtn(
                                      icon: Icons.reply_outlined,
                                      label: 'Reply'.tl,
                                      onTap: () {
                                        _dismissActiveOverlay();
                                        widget.onReply(widget.entry.messageId);
                                      },
                                    ),
                                  ),
                                  if (isMe)
                                    Expanded(
                                      child: _TrayBtn(
                                        icon: Icons.undo_outlined,
                                        label: 'Recall'.tl,
                                        color: cs.error,
                                        onTap: () {
                                          _dismissActiveOverlay();
                                          widget.onRecall(
                                            widget.entry.messageId,
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _activeOverlay = entry;
    Overlay.of(context).insert(entry);
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
                        image: CachedImageProvider(avatarUrl, sourceKey: 'hub'),
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
                  'Image'.tl,
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
                        .where((s) => s is TextSegment || s is MentionSegment)
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
                      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, color: c)),
          ],
        ),
      ),
    );
  }
}

// ── 气泡图片组件 ──────────────────────────────────────────────────────────────

class _BubbleImage extends StatelessWidget {
  final String url;
  final BorderRadius borderRadius;
  final String messageId;
  static const double _maxWidth = 220;
  static const double _fixedHeight = 200; // 固定外框高度，避免抽搐
  const _BubbleImage({
    required this.url,
    required this.borderRadius,
    required this.messageId,
  });

  bool get _isBase64 => url.startsWith('data:');

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
            child: _isBase64 ? _buildBase64() : _buildNetwork(),
          ),
        ),
      ),
    );
  }

  Widget _buildNetwork() {
    return Hero(
      tag: messageId,
      child: AnimatedImage(
        image: CachedImageProvider(url, sourceKey: 'hub'),
        height: _fixedHeight,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildBase64() {
    try {
      final data = base64Decode(url.split(',').last);
      return Hero(
        tag: messageId,
        child: Image.memory(
          data,
          height: _fixedHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _placeholder(),
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
          heroTag: messageId,
        );
      } catch (e) {
        HubLog.error('HubBubbleImage', '$e');
      }
    } else {
      await BangumiWidget.showImagePreview(
        context: App.rootContext,
        url: url,
        title: '',
        heroTag: messageId,
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
  final VoidCallback onOpenStickers;
  final bool isDesktop;
  final bool uploading;
  final List<PendingImage> pendingImages;
  final void Function(int index) onRemovePending;
  final HubRoomDto? room;

  const HubInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onPickImage,
    required this.onOpenStickers,
    required this.isDesktop,
    this.uploading = false,
    required this.pendingImages,
    required this.onRemovePending,
    required this.room,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.toOpacity(0.4), width: 0.5),
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
                    style: TextStyle(fontSize: 14, color: cs.onSurface),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: isDesktop
                          ? 'Enter to send  ·  Ctrl+Enter for newline'.tl
                          : 'Message...'.tl,
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: cs.onSurface.toOpacity(0.5),
                        ),
                  onPressed: uploading ? null : onPickImage,
                  tooltip: 'Image'.tl,
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
                  tooltip: 'Memes'.tl,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                if (room != null)
                  IconButton(
                    onPressed: () => showHubRoomSettingsSheet(context, room!),
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: cs.onSurface.toOpacity(0.5),
                    ),
                    tooltip: 'Room Settings'.tl,
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
                Text(
                  'Stickers'.tl,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  'Long press image to save'.tl,
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
                      'No stickers yet'.tl,
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
                'Remove sticker'.tl,
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
