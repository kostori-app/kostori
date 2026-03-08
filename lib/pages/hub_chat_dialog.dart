import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/services/services.dart';
import 'package:kostori/utils/ext.dart';
import 'package:kostori/utils/translations.dart';

class HubChatDialog extends StatefulWidget {
  const HubChatDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true, // ← 点击外部关闭
      builder: (context) => const HubChatDialog(),
    );
  }

  @override
  State<HubChatDialog> createState() => _HubChatDialogState();
}

class _HubChatDialogState extends State<HubChatDialog> {
  final _client = HubClient();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  String? _replyToId;

  bool get _isDesktop => App.isDesktop;

  @override
  void initState() {
    super.initState();
    _messages.addAll(List<Map<String, dynamic>>.from(_client.messageHistory));

    _client.onMessage = (data) {
      if (!mounted) return;
      final type = data['type'] as String?;
      Log.info('HubChat', '收到消息 type=$type payload=${data['payload']}');
      if (type == 'broadcast' || type == 'unicast') {
        if (data['from'] == _client.myId) return;
        setState(() => _messages.add(data));
        _scrollToBottom();
      } else if (type == 'system') {
        final event = data['payload']?['event'] as String?;
        if (event == 'message_recalled') {
          final msgId = data['payload']['msgId'] as String?;
          setState(() => _messages.removeWhere((m) => m['id'] == msgId));
        } else if (event == 'client_joined' || event == 'client_left') {
          setState(
            () => _messages.add({'type': 'system', 'payload': data['payload']}),
          );
        }
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_replyToId != null) {
      _client.reply(_replyToId!, {'text': text});
    } else {
      _client.broadcast({'text': text});
    }
    setState(() {
      _messages.add({
        'type': 'broadcast',
        'from': _client.myId,
        'payload': {'text': text},
        'id': DateTime.now().millisecondsSinceEpoch.toRadixString(36),
        'time': DateTime.now().toIso8601String(),
        if (_replyToId != null) 'replyTo': _replyToId,
      });
      _replyToId = null;
    });
    _inputController.clear();
    _scrollToBottom();
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: size.height * 0.05,
      ),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.9,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _client.currentRoomName ?? "Lobby",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_client.currentRoomClients.length} ${"online".tl}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.toOpacity(0.5),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 消息列表
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        "No messages yet".tl,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.toOpacity(0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final msg = _messages[i];
                        final type = msg['type'] as String?;

                        // 系统消息
                        if (type == 'system') {
                          final event = msg['payload']?['event'] as String?;
                          String text = '';
                          if (event == 'client_joined') {
                            text =
                                '${msg['payload']['client']?['name'] ?? ''} ${"joined".tl}';
                          } else if (event == 'client_left') {
                            text =
                                '${msg['payload']['clientName'] ?? ''} ${"left".tl}';
                          }
                          if (text.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Center(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.toOpacity(0.4),
                                ),
                              ),
                            ),
                          );
                        }

                        // 普通消息
                        final isMe = msg['from'] == _client.myId;
                        final fromName =
                            _client.currentRoomClients.firstWhereOrNull(
                                  (c) => c['id'] == msg['from'],
                                )?['name']
                                as String? ??
                            msg['from'] as String? ??
                            '?';
                        final payload = msg['payload'];
                        final text = payload is Map
                            ? payload['text'] as String? ?? payload.toString()
                            : payload?.toString() ?? '';
                        final replyTo = msg['replyTo'] as String?;
                        final replyMsg = replyTo != null
                            ? _messages.firstWhereOrNull(
                                (m) => m['id'] == replyTo,
                              )
                            : null;
                        final timeStr = _formatTime(msg['time'] as String?);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe) ...[
                                CircleAvatar(
                                  radius: 14,
                                  child: Text(
                                    fromName[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          fromName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .toOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    if (replyMsg != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border(
                                            left: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          () {
                                            final p = replyMsg['payload'];
                                            return p is Map
                                                ? p['text'] as String? ?? '...'
                                                : p?.toString() ?? '...';
                                          }(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .toOpacity(0.6),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    // 消息气泡
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer // ← 改这里
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(12),
                                          topRight: const Radius.circular(12),
                                          bottomLeft: Radius.circular(
                                            isMe ? 12 : 2,
                                          ),
                                          bottomRight: Radius.circular(
                                            isMe ? 2 : 12,
                                          ),
                                        ),
                                      ),
                                      child: SelectableText(
                                        // ← 改这里
                                        text,
                                        style: TextStyle(
                                          fontSize: 13,
                                          // 自己的消息
                                          color: isMe
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer // ← 改这里
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    // 时间戳 + 表情反应
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if ((msg['reactions'] as Map?)
                                                ?.isNotEmpty ==
                                            true)
                                          ...(msg['reactions'] as Map)
                                              .cast<String, dynamic>()
                                              .entries
                                              .map((e) {
                                                final users = e.value as List?;
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 2,
                                                    right: 4,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${e.key} ${users?.length ?? 0}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                );
                                              }),
                                        if (timeStr.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                              left: 4,
                                            ),
                                            child: Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .toOpacity(0.4),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isMe) const SizedBox(width: 6),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // 回复预览
            if (_replyToId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        () {
                          final replyMsg = _messages.firstWhereOrNull(
                            (m) => m['id'] == _replyToId,
                          );
                          final p = replyMsg?['payload'];
                          return p is Map
                              ? p['text'] as String? ?? ''
                              : p?.toString() ?? '';
                        }(),
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => setState(() => _replyToId = null),
                    ),
                  ],
                ),
              ),
            // 输入栏
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (!_isDesktop) return KeyEventResult.ignored;

                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          if (HardwareKeyboard.instance.isControlPressed) {
                            // Ctrl+Enter 换行
                            final text = _inputController.text;
                            final selection = _inputController.selection;
                            final newText = text.replaceRange(
                              selection.start,
                              selection.end,
                              '\n',
                            );
                            _inputController.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: selection.start + 1,
                              ),
                            );
                            return KeyEventResult.handled;
                          } else {
                            // Enter 发送
                            _sendMessage();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: _isDesktop
                              ? "Enter to send, Ctrl+Enter for newline".tl
                              : "Type a message...".tl,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 18),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageMenu(
    BuildContext context,
    Map<String, dynamic> msg,
    bool isMe,
  ) {
    final msgId = msg['id'] as String?;
    if (msgId == null) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text("Reply".tl),
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyToId = msgId);
              _inputFocusNode.requestFocus();
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions_outlined),
            title: Text("React".tl),
            onTap: () {
              Navigator.pop(context);
              _showReactionPicker(context, msgId);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text("Recall".tl),
              onTap: () {
                Navigator.pop(context);
                _client.recall(msgId);
                setState(() => _messages.removeWhere((m) => m['id'] == msgId));
              },
            ),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context, String msgId) {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis
              .map(
                (e) => GestureDetector(
                  onTap: () {
                    _client.react(msgId, e);
                    Navigator.pop(context);
                  },
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
