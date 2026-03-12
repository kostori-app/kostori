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
import 'package:kostori/foundation/services/services.dart';
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

class HubSystemRow extends StatelessWidget {
  final HubMessage entry;

  const HubSystemRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final raw = entry.segments.whereType<TextSegment>().firstOrNull?.text;
    if (raw == null) return const SizedBox.shrink();
    final payload = HubSystemPayload.fromJson(jsonDecode(raw));
    if (payload == null) return const SizedBox.shrink();

    final text = switch (payload) {
      HubPayloadClientJoined() => '${payload.displayName} ${"joined".tl}',
      HubPayloadClientLeft() => '${payload.clientName} ${"left".tl}',
      HubPayloadClientJoinedRoom() =>
        '${payload.displayName} ${"joined the room".tl}',
      HubPayloadClientLeftRoom() =>
        '${payload.clientName} ${"left the room".tl}',
      HubPayloadRoomWelcome() => payload.message,
      HubPayloadClientKickedFromRoom() =>
        '${payload.clientName} ${"was kicked by".tl} ${payload.operatorName}',
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

class HubBubbleRow extends StatelessWidget {
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

  /// 是否是纯图片消息（无文字段）
  bool get _isPureImage =>
      entry.segments.isNotEmpty &&
      entry.segments.every((s) => s is ImageSegment);

  @override
  Widget build(BuildContext context) {
    final isRoomAdmin = roomModeratorIds.contains(entry.sender.userId);
    final cs = Theme.of(context).colorScheme;
    final replyEntry = entry.replyToMessageId != null
        ? allEntries.firstWhereOrNull(
            (e) => e.messageId == entry.replyToMessageId,
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

    final bubbleColor = isMe ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;

    // ── 头像 ─────────────────────────────────────────────────────────────────
    final avatarUrl = entry.sender.avatarUrl;

    Widget buildInitials(HubMessage entry) => Text(
      hubInitials(entry.sender.displayName),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    final avatarWidget = !isContinuation
        ? GestureDetector(
            onDoubleTap: () => onPoke?.call(entry.sender.userId),
            onLongPress: () => onMention?.call(entry.sender),
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: hubAvatarColor(entry.sender.userId),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: AnimatedImage(
                        image: CachedImageProvider(avatarUrl, sourceKey: 'hub'),
                        width: avatarDiam,
                        height: avatarDiam,
                        fit: BoxFit.cover,
                      ),
                    )
                  : buildInitials(entry),
            ),
          )
        : const SizedBox(width: avatarDiam);

    // ── 引用块 ───────────────────────────────────────────────────────────────
    Widget? replyWidget;
    if (replyEntry != null) {
      final replyBg = isMe
          ? cs.primaryContainer.toOpacity(0.45)
          : cs.surfaceContainer;
      final replyAccent = isMe ? cs.onPrimaryContainer : cs.primary;

      // 引用内容预览：图片 or 文字
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
                  color: isMe
                      ? cs.onPrimaryContainer.toOpacity(0.6)
                      : cs.onSurface.toOpacity(0.5),
                ),
                const SizedBox(width: 3),
                Text(
                  'Image'.tl,
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe
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
                color: isMe
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
            onTap: () => onScrollToEntry(replyEntry.messageId),
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

    // ── 时间字符串 ────────────────────────────────────────────────────────────
    final local = entry.sentAt.toLocal();
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    final bubbleBr = isContinuation
        ? BorderRadius.circular(14)
        : BorderRadius.only(
            topLeft: Radius.circular(isMe ? 14 : 3),
            topRight: Radius.circular(isMe ? 3 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          );

    // ── 气泡 ─────────────────────────────────────────────────────────────────
    // 纯图片：无气泡背景，图片直接裸显示
    // 文字 / 混合：有气泡背景
    final Widget bubbleWidget;

    if (_isPureImage) {
      // 纯图片气泡
      bubbleWidget = GestureDetector(
        onLongPress: () => _showActions(context, cs),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...entry.segments.whereType<ImageSegment>().map(
                (seg) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _BubbleImage(
                    url: seg.url,
                    borderRadius: bubbleBr,
                    messageId: entry.messageId,
                  ),
                ),
              ),
              // 时间戳放图片外下方
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
        ),
      );
    } else {
      // 文字 / 混合气泡
      final imageSegs = entry.segments.whereType<ImageSegment>().toList();

      bubbleWidget = GestureDetector(
        onLongPress: () => _showActions(context, cs),
        child: ConstrainedBox(
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
                  // 文字段
                  Text.rich(
                    TextSpan(
                      children: entry.segments
                          .where((s) => s is TextSegment || s is MentionSegment)
                          .map((s) {
                            if (s is MentionSegment) {
                              return TextSpan(
                                text: '@${s.displayName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: isMe ? cs.onPrimary : cs.primary,
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
                  // 图片段（混合消息）
                  ...imageSegs.map(
                    (seg) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _BubbleImage(
                          url: seg.url,
                          borderRadius: BorderRadius.circular(8),
                          messageId: entry.messageId,
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
                        color: isMe
                            ? cs.onPrimary.toOpacity(0.5)
                            : cs.onSurface.toOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── 表情反应 ──────────────────────────────────────────────────────────────
    Widget? reactionsWidget;
    final visible = entry.reactions.where((r) => r.users.isNotEmpty).toList();
    if (visible.isNotEmpty) {
      reactionsWidget = Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: visible.map((r) {
            final count = r.users.length;
            final iMine = myId != null && r.users.any((u) => u.userId == myId);
            return GestureDetector(
              onTap: () => onReact(entry.messageId, r.emojiId),
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

    // ── 内容列 ────────────────────────────────────────────────────────────────
    final contentCol = Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isContinuation)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isMe && entry.sender.isGlobalAdmin) ...[
                  _AdminBadge(label: 'Admin', color: const Color(0xFFFFB300)),
                  const SizedBox(width: 4),
                ] else if (!isMe && isRoomAdmin) ...[
                  _AdminBadge(label: 'Mod', color: const Color(0xFF81C784)),
                  const SizedBox(width: 4),
                ] else if (!isMe && entry.sender.isBot) ...[
                  _AdminBadge(label: 'BOT', color: const Color(0xFF64B5F6)),
                  const SizedBox(width: 4),
                ],
                Text(
                  entry.sender.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (isMe && entry.sender.isGlobalAdmin) ...[
                  const SizedBox(width: 4),
                  _AdminBadge(label: 'Admin', color: const Color(0xFFFFB300)),
                ] else if (isMe && isRoomAdmin) ...[
                  const SizedBox(width: 4),
                  _AdminBadge(label: 'Mod', color: const Color(0xFF81C784)),
                ],
                if (isMe && entry.sender.isBot) ...[
                  const SizedBox(width: 4),
                  _AdminBadge(label: 'BOT', color: const Color(0xFF64B5F6)),
                ],
              ],
            ),
          ),
        if (replyWidget != null) replyWidget,
        bubbleWidget,
        if (reactionsWidget != null) reactionsWidget,
      ],
    );

    return Padding(
      padding: EdgeInsets.only(top: isContinuation ? 2 : 8, bottom: 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isMe
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

  // ── 长按操作面板 ──────────────────────────────────────────────────────────

  void _showActions(BuildContext context, ColorScheme cs) {
    final hasImage = entry.segments.whereType<ImageSegment>().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 快捷 emoji 行 ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ...HubEmoji.quickBar.map(
                    (e) => _QuickEmojiBtn(
                      emoji: e,
                      onTap: () {
                        Navigator.pop(ctx);
                        onReact(entry.messageId, e.id);
                      },
                    ),
                  ),
                  _MoreEmojiBtn(
                    onTap: () {
                      Navigator.pop(ctx);
                      final box = context.findRenderObject() as RenderBox?;
                      final offset = box != null
                          ? box.localToGlobal(
                              Offset(box.size.width / 2, box.size.height / 2),
                            )
                          : const Offset(200, 400);
                      HubEmojiPicker.show(
                        context,
                        offset,
                        onPick: (emojiId) => onReact(entry.messageId, emojiId),
                      );
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.toOpacity(0.3)),
            // ── 操作列表 ────────────────────────────────────────────────────
            if (!_isPureImage)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text('Copy'.tl),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: entry.plainText));
                },
              ),
            // 有图片才显示保存表情包
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: Text('Save as Sticker'.tl),
                onTap: () {
                  Navigator.pop(ctx);
                  // 多张图片全部保存
                  for (final seg in entry.segments.whereType<ImageSegment>()) {
                    HubStickerManager.add(HubSticker(url: seg.url));
                  }
                  App.rootContext.showMessage(
                    message: 'Sticker saved'.tl,
                    level: LogLevel.info,
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: Text('Reply'.tl),
              onTap: () {
                Navigator.pop(ctx);
                onReply(entry.messageId);
              },
            ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.undo_outlined, color: cs.error),
                title: Text('Recall'.tl, style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRecall(entry.messageId);
                },
              ),
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
        child: SizedBox(
          width: 200,
          height: 220,
          child: _isBase64 ? _buildBase64() : _buildNetwork(),
        ),
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
          fit: BoxFit.cover,
          width: 200,
          height: 220,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _buildNetwork() {
    return Hero(
      tag: messageId,
      child: AnimatedImage(
        image: CachedImageProvider(url, sourceKey: 'hub'),
        fit: BoxFit.cover,
        width: 200,
        height: 160,
      ),
    );
  }

  void _openFullscreen(BuildContext context) async {
    if (_isBase64) {
      // base64 → 写临时文件 → 用本地路径预览
      try {
        final data = base64Decode(url.split(',').last);
        final tmp = File(
          '${Directory.systemTemp.path}/hub_img_${url.hashCode}.jpg',
        );
        if (!await tmp.exists()) {
          await tmp.writeAsBytes(data);
        }
        await BangumiWidget.showImagePreview(
          context: context,
          url: tmp.path,
          title: '',
          heroTag: messageId,
        );
      } catch (e) {
        Log.addLog(LogLevel.error, 'HubBubbleImage', '$e');
      }
    } else {
      // 网络图片直接预览
      await BangumiWidget.showImagePreview(
        context: context,
        url: url,
        title: '',
        heroTag: 'hub_img_${url.hashCode}',
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
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 4,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.toOpacity(0.4), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column 的最顶部加
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
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    size: 17,
                    color: cs.onPrimary,
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
                  tooltip: 'Stickers'.tl,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                if (room != null)
                  IconButton(
                    onPressed: () =>
                        showHubRoomSettingsSheet(context, room!, ref),
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

  bool _expanded = false;

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
    const popH = 56.0;
    const fullH = 360.0;
    final h = _expanded ? fullH : popH;
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
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _expanded ? _fullGrid(cs) : _quickBar(cs),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 快捷栏（6个 + 展开按钮）──────────────────────────────────────────────
  Widget _quickBar(ColorScheme cs) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...HubEmoji.quickBar.map(
            (e) => _EmojiBtn(emoji: e, size: 28, onTap: () => _pick(e.id)),
          ),
          IconButton(
            icon: const Icon(Icons.add_reaction_outlined, size: 20),
            tooltip: 'More',
            onPressed: () => setState(() => _expanded = true),
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
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _expanded = false),
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
