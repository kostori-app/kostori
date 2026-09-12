part of 'settings_page.dart';

/// 数据同步风格的表单卡片（Kostori/Satori bot 设置页复用）
class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// 表单卡片标题（icon + 粗体文字）
class _FormSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _FormSectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// 表单输入框装饰（数据同步风格）
InputDecoration _formFieldDecoration({
  required String labelText,
  String? hintText,
  Widget? suffix,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

/// 表单底部全宽保存按钮
class _FormSaveButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _FormSaveButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Button.filled(
        onPressed: onPressed,
        child: Text(t.save, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

// ── _MuteSheet ────────────────────────────────────────────────────────────────

class _MuteSheet extends StatefulWidget {
  const _MuteSheet({required this.clientName, required this.onMute});

  final String clientName;
  final ValueChanged<int> onMute;

  @override
  State<_MuteSheet> createState() => _MuteSheetState();
}

class _MuteSheetState extends State<_MuteSheet> {
  static const _presets = [
    (label: '1 min', seconds: 60),
    (label: '5 min', seconds: 300),
    (label: '10 min', seconds: 600),
    (label: '30 min', seconds: 1800),
    (label: '1 hour', seconds: 3600),
    (label: '24 hour', seconds: 86400),
  ];

  final _controller = TextEditingController();
  bool _showCustom = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.mic_off_outlined, size: 18, color: cs.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${t.mute}  ${widget.clientName}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presets.map(
                  (p) => ActionChip(
                    label: Text(p.label),
                    onPressed: () => widget.onMute(p.seconds),
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: cs.primary,
                  ),
                  label: Text(t.custom, style: TextStyle(color: cs.primary)),
                  onPressed: () => setState(() => _showCustom = !_showCustom),
                ),
              ],
            ),
          ),
          if (_showCustom)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: t.secondsLabel,
                        suffixText: "s",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final s = int.tryParse(_controller.text);
                      if (s != null && s > 0) widget.onMute(s);
                    },
                    child: Text(t.confirm),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    this.min = 1024,
    this.max = 65535,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.toOpacity(0.35),
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: colorScheme.primary.toOpacity(0.6),
              width: 1.5,
            ),
          ),
        ),
        onChanged: (v) {
          final val = int.tryParse(v);
          if (val != null && val >= min && val <= max) {
            onChanged(val);
          }
        },
      ),
    );
  }
}

class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile({
    required this.keyManager,
    required this.onRegenerate,
    this.isAdmin = false,
  });

  final ApiKeyManager keyManager;
  final VoidCallback onRegenerate;
  final bool isAdmin;

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  bool _obscured = true;

  String get _activeKey => widget.isAdmin
      ? widget.keyManager.adminActiveKey
      : widget.keyManager.activeKey;

  String get _label => widget.isAdmin ? t.adminKey : t.userKey;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(_label),
      subtitle: Text(
        _obscured ? '••••••••••••••••' : _activeKey,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _obscured ? Icons.visibility_off : Icons.visibility,
              size: 18,
            ),
            tooltip: _obscured ? t.show : t.hide,
            onPressed: () => setState(() => _obscured = !_obscured),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: t.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _activeKey));
              App.rootContext.showMessage(message: t.copied);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: t.regenerate,
            onPressed: widget.onRegenerate,
          ),
        ],
      ),
    );
  }
}

class _HubTokenInput extends StatefulWidget {
  const _HubTokenInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final void Function(String) onChanged;

  @override
  State<_HubTokenInput> createState() => _HubTokenInputState();
}

class _HubTokenInputState extends State<_HubTokenInput> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        decoration: InputDecoration(
          isDense: true,
          hintText: t.pasteHubServerToken,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: widget.enabled
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.controller.text.isEmpty)
                      IconButton(
                        icon: const Icon(Icons.content_paste, size: 16),
                        tooltip: t.paste,
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final text = data?.text?.trim() ?? '';
                          if (text.isNotEmpty) {
                            widget.controller.text = text;
                            widget.onChanged(text);
                            setState(() {});
                          }
                        },
                      ),
                    if (widget.controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        tooltip: t.clear,
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                          setState(() {});
                        },
                      ),
                  ],
                ),
        ),
        onChanged: (v) {
          widget.onChanged(v.trim());
          setState(() {});
        },
      ),
    );
  }
}

class _HostInput extends StatelessWidget {
  const _HostInput({
    required this.controller,
    required this.enabled,
    this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.url,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: enabled
            ? colorScheme.onSurface
            : colorScheme.onSurface.toOpacity(0.35),
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surface,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary.toOpacity(0.6),
            width: 1.5,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
