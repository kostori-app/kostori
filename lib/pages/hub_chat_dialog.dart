import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/services/models/chat_entry.dart';
import 'package:kostori/foundation/services/services.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

// ── 入口 ──────────────────────────────────────────────

void showHubChatDialog(BuildContext context) {
  showPopUpWidget(context, const _HubChatPage());
}

// ── 颜色工具 ──────────────────────────────────────────

Color _chatAvatarColor(String? id) {
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

String _chatInitials(String name) =>
    name.isEmpty ? '?' : name.characters.first.toUpperCase();

bool _needTimeDivider(DateTime? prev, DateTime curr) {
  if (prev == null) return true;
  return curr.difference(prev).inMinutes >= 5;
}

// ── 主页面 ────────────────────────────────────────────

class _HubChatPage extends StatefulWidget {
  const _HubChatPage();

  @override
  State<_HubChatPage> createState() => _HubChatPageState();
}

class _HubChatPageState extends State<_HubChatPage>
    with SingleTickerProviderStateMixin {
  final _client = HubClient();
  final _scroll = ScrollController();
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();

  final List<ChatEntry> _entries = [];
  final Map<String, GlobalKey> _entryKeys = {};
  String? _replyToId;
  bool _autoScroll = true;

  late final AnimationController _enterAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _enterAnim,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.03),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _enterAnim, curve: Curves.easeOut));

  bool get _isDesktop => App.isDesktop;

  GlobalKey _keyFor(String id) => _entryKeys.putIfAbsent(id, () => GlobalKey());

  void _scrollToEntry(String id) {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    if (!_scroll.hasClients) return;
    // 第一阶段：估算 offset 让目标附近渲染出来
    const estH = 72.0;
    final maxExt = _scroll.position.maxScrollExtent;
    final est = (idx * estH).clamp(0.0, maxExt.isFinite ? maxExt : 0.0);
    _scroll.jumpTo(est);
    // 第二阶段：目标渲染后精确定位
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _entryKeys[id]?.currentContext;
      if (ctx == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx2 = _entryKeys[id]?.currentContext;
          if (ctx2 != null) {
            Scrollable.ensureVisible(
              ctx2,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.3,
            );
          }
        });
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    });
  }

  String _nameOf(String? id) {
    if (id == null) return '?';
    return _client.currentRoomClients.firstWhereOrNull(
              (c) => c['id'] == id,
            )?['name']
            as String? ??
        id;
  }

  @override
  void initState() {
    super.initState();

    // 载入历史消息
    for (final m in _client.messageHistory) {
      final e = ChatEntry.fromMap(m);
      _entries.add(
        ChatEntry(
          id: e.id,
          fromId: e.fromId,
          fromName: _nameOf(e.fromId),
          text: e.text,
          time: e.time,
          replyToId: e.replyToId,
        ),
      );
    }

    _client.onMessage = (data) {
      if (!mounted) return;
      final type = data['type'] as String?;

      if (type == 'broadcast' || type == 'unicast') {
        if (data['from'] == _client.myId) return;
        final e = ChatEntry.fromMap(data);
        setState(
          () => _entries.add(
            ChatEntry(
              id: e.id,
              fromId: e.fromId,
              fromName: _nameOf(e.fromId),
              text: e.text,
              time: e.time,
              replyToId: e.replyToId,
            ),
          ),
        );
        if (_autoScroll) _scrollToBottom();
      } else if (type == 'system') {
        final event = data['payload']?['event'] as String?;
        if (event == 'message_recalled') {
          final mid = data['payload']['msgId'] as String?;
          setState(() => _entries.removeWhere((e) => e.id == mid));
        } else if (event == 'client_joined' || event == 'client_left') {
          setState(() => _entries.add(ChatEntry.system(data['payload'])));
          if (_autoScroll) _scrollToBottom();
        }
      }
    };

    _scroll.addListener(() {
      final atBottom =
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 60;
      if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _enterAnim.forward();
  }

  @override
  void dispose() {
    _client.onMessage = null;
    _enterAnim.dispose();
    _scroll.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    if (_replyToId != null) {
      _client.reply(_replyToId!, {'text': text});
    } else {
      _client.broadcast({'text': text});
    }
    setState(() {
      _entries.add(
        ChatEntry(
          id: id,
          fromId: _client.myId,
          fromName: _client.savedName ?? _client.myId ?? '?',
          text: text,
          time: DateTime.now(),
          replyToId: _replyToId,
        ),
      );
      _replyToId = null;
    });
    _inputCtrl.clear();
    _autoScroll = true;
    _scrollToBottom();
  }

  // ── build ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: cs.surface,
          child: Column(
            children: [
              _buildTitleBar(cs),
              Expanded(child: _buildList(cs)),
              if (_replyToId != null) _buildReplyBanner(cs),
              _buildInputBar(cs),
            ],
          ),
        ),
      ),
    );
  }

  // ── 标题栏 ─────────────────────────────────────────

  Widget _buildTitleBar(ColorScheme cs) {
    // PopUpWidgetScaffold 顶栏高度约 56，我们自己做一个简洁版
    return Container(
      height: 56 + context.padding.top,
      padding: EdgeInsets.only(top: context.padding.top),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.toOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            tooltip: "Back".tl,
            onPressed: () => context.canPop() ? context.pop() : App.pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _client.currentRoomName ?? "Lobby".tl,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: Colors.greenAccent.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_client.currentRoomClients.length} ${"online".tl}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.toOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── 消息列表 ───────────────────────────────────────

  Widget _buildList(ColorScheme cs) {
    return Stack(
      children: [
        Container(color: cs.surfaceContainerLowest),
        _entries.isEmpty
            ? Center(
                child: Text(
                  "No messages yet".tl,
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
                  final next = i < _entries.length - 1 ? _entries[i + 1] : null;

                  // 连续消息：与上一条同人且时间差<2分钟
                  final isContinuation =
                      prev != null &&
                      !prev.isSystem &&
                      !entry.isSystem &&
                      prev.fromId == entry.fromId &&
                      entry.time.difference(prev.time).inMinutes < 2;

                  // 是否是该用户这段连续消息的最后一条
                  final isLastInGroup =
                      next == null ||
                      next.isSystem ||
                      next.fromId != entry.fromId ||
                      next.time.difference(entry.time).inMinutes >= 2;

                  return KeyedSubtree(
                    key: _keyFor(entry.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!entry.isSystem &&
                            _needTimeDivider(prev?.time, entry.time))
                          _TimeDivider(time: entry.time),
                        if (entry.isSystem)
                          _SystemRow(entry: entry)
                        else
                          _BubbleRow(
                            entry: entry,
                            isMe: entry.fromId == _client.myId,
                            myId: _client.myId,
                            allEntries: _entries,
                            isContinuation: isContinuation,
                            isLastInGroup: isLastInGroup,
                            onReply: (id) {
                              setState(() => _replyToId = id);
                              _inputFocus.requestFocus();
                            },
                            onReact: (id, emoji) => _client.react(id, emoji),
                            onRecall: (id) {
                              _client.recall(id);
                              setState(
                                () => _entries.removeWhere((e) => e.id == id),
                              );
                            },
                            onScrollToEntry: _scrollToEntry,
                          ),
                      ],
                    ),
                  );
                },
              ),
        // 跳到最新按钮
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
                      "New messages".tl,
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

  // ── 回复预览条 ─────────────────────────────────────

  Widget _buildReplyBanner(ColorScheme cs) {
    final entry = _entries.firstWhereOrNull((e) => e.id == _replyToId);
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
                  entry?.fromName ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                Text(
                  entry?.text ?? '',
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

  // ── 输入栏 ─────────────────────────────────────────

  Widget _buildInputBar(ColorScheme cs) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            context.padding.bottom +
            8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.toOpacity(0.4), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent || !_isDesktop) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.enter) {
                  if (HardwareKeyboard.instance.isControlPressed) {
                    final t = _inputCtrl.text;
                    final s = _inputCtrl.selection;
                    _inputCtrl.value = TextEditingValue(
                      text: t.replaceRange(s.start, s.end, '\n'),
                      selection: TextSelection.collapsed(offset: s.start + 1),
                    );
                    return KeyEventResult.handled;
                  }
                  _send();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _inputCtrl,
                focusNode: _inputFocus,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _isDesktop
                      ? "Enter to send  ·  Ctrl+Enter for newline".tl
                      : "Message...".tl,
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
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.send_rounded, size: 17, color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 时间分割线 ────────────────────────────────────────

class _TimeDivider extends StatelessWidget {
  final DateTime time;

  const _TimeDivider({required this.time});

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

// ── 系统消息行 ────────────────────────────────────────

class _SystemRow extends StatelessWidget {
  final ChatEntry entry;

  const _SystemRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final event = entry.systemPayload?['event'] as String?;
    final String text;
    if (event == 'client_joined') {
      text = '${entry.systemPayload?['client']?['name'] ?? ''} ${"joined".tl}';
    } else if (event == 'client_left') {
      text = '${entry.systemPayload?['clientName'] ?? ''} ${"left".tl}';
    } else {
      return const SizedBox.shrink();
    }
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

// ── 气泡行 ────────────────────────────────────────────

class _BubbleRow extends StatelessWidget {
  final ChatEntry entry;
  final bool isMe;
  final String? myId;
  final List<ChatEntry> allEntries;
  final bool isContinuation;
  final bool isLastInGroup;
  final void Function(String id) onReply;
  final void Function(String id, String emoji) onReact;
  final void Function(String id) onRecall;
  final void Function(String id) onScrollToEntry;

  const _BubbleRow({
    required this.entry,
    required this.isMe,
    required this.myId,
    required this.allEntries,
    required this.isContinuation,
    required this.isLastInGroup,
    required this.onReply,
    required this.onReact,
    required this.onRecall,
    required this.onScrollToEntry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final replyEntry = entry.replyToId != null
        ? allEntries.firstWhereOrNull((e) => e.id == entry.replyToId)
        : null;

    const avatarRadius = 17.0;
    const avatarDiam = avatarRadius * 2; // 34
    const avatarGap = 8.0;
    final screenW = MediaQuery.of(context).size.width;
    // 最大宽 = 屏宽 - 两侧padding(24) - 头像(34) - 头像间距(8) - 对侧留空(34+8)
    final maxW =
        screenW - 24 - avatarDiam - avatarGap - (avatarDiam + avatarGap);

    final bubbleColor = isMe ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMe ? cs.onPrimary : cs.onSurface;

    // ── 头像槽：连续消息只有最后一条（视觉最下）显示头像，其余占位 ──
    Widget avatarSlot = const SizedBox.shrink();
    if (!isMe) {
      avatarSlot = isLastInGroup
          ? CircleAvatar(
              radius: avatarRadius,
              backgroundColor: _chatAvatarColor(entry.fromId),
              child: Text(
                _chatInitials(entry.fromName),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
          : const SizedBox(width: avatarDiam);
    }

    // ── 引用块：ClipRRect 做圆角裁切 ──
    Widget? replyWidget;
    if (replyEntry != null) {
      final replyBg = isMe
          ? cs.primaryContainer.toOpacity(0.45)
          : cs.surfaceContainer;
      final replyAccent = isMe ? cs.onPrimaryContainer : cs.primary;
      replyWidget = Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: GestureDetector(
            onTap: () => onScrollToEntry(replyEntry.id),
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
                          replyEntry.fromName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: replyAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          replyEntry.text,
                          style: TextStyle(
                            fontSize: 12,
                            color: isMe
                                ? cs.onPrimaryContainer.toOpacity(0.7)
                                : cs.onSurface.toOpacity(0.6),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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

    // ── 气泡（含右下角时间）──
    final h = entry.time.toLocal().hour.toString().padLeft(2, '0');
    final m = entry.time.toLocal().minute.toString().padLeft(2, '0');
    final timeStr = '$h:$m';
    final bubbleBr = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isMe ? 14 : (isLastInGroup ? 3 : 14)),
      bottomRight: Radius.circular(isMe ? (isLastInGroup ? 3 : 14) : 14),
    );
    final bubbleWidget = GestureDetector(
      onLongPress: () => _showActions(context, cs),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: bubbleBr),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry.text,
              style: TextStyle(fontSize: 14, color: textColor, height: 1.4),
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
    );

    // ── 气泡列：首条显示名字，末条头像，连续消息减少间距 ──
    final bubbleCol = Column(
      crossAxisAlignment: isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 只在连续组第一条显示用户名（非自己）
        if (!isMe && !isContinuation)
          Padding(
            padding: const EdgeInsets.only(bottom: 3, left: 2),
            child: Text(
              entry.fromName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.toOpacity(0.55),
              ),
            ),
          ),
        if (replyWidget != null) replyWidget,
        bubbleWidget,
      ],
    );

    final vertPad = isContinuation ? 2.0 : 6.0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertPad),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe
            ? [
                // 自己：左侧留一个头像宽的空，气泡靠右
                const SizedBox(width: avatarDiam + avatarGap),
                Flexible(child: bubbleCol),
              ]
            : [
                // 别人：头像槽 + 气泡 + 右侧留一个头像宽的空
                avatarSlot,
                const SizedBox(width: avatarGap),
                Flexible(child: bubbleCol),
                const SizedBox(width: avatarDiam + avatarGap),
              ],
      ),
    );
  }

  void _showActions(BuildContext context, ColorScheme cs) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: emojis
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onReact(entry.id, e);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text("Copy".tl),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: entry.text));
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: Text("Reply".tl),
              onTap: () {
                Navigator.pop(context);
                onReply(entry.id);
              },
            ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.undo_outlined, color: cs.error),
                title: Text("Recall".tl, style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(context);
                  onRecall(entry.id);
                },
              ),
          ],
        ),
      ),
    );
  }
}
