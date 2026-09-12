part of 'hub_chat_widgets.dart';

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
    final size = MediaQuery.sizeOf(context);
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
