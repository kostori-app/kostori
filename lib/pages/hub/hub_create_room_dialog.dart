import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/i18n/strings.g.dart';

// ── 公共表单对话框 ──────────────────────────────────────────────────────────────

Future<T?> showHubFormDialog<T>({
  required String title,
  required List<Widget> fields,
  required String confirmLabel,
  required Future<T?> Function() onConfirm,
  String? subtitle,
  IconData? icon,
}) {
  return ContentDialog.show<T>(
    context: App.rootContext,
    title: title,
    isDismissible: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null) ...[
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                App.rootContext,
              ).colorScheme.onSurface.toOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...fields.expand((f) => [f, const SizedBox(height: 12)]).toList()
          ..removeLast(),
      ],
    ),
    actions: [
      Button.filled(
        onPressed: () async {
          final result = await onConfirm();
          Navigator.of(App.rootContext).pop(result);
        },
        child: Text(confirmLabel),
      ),
    ],
  );
}

// ── 创建房间对话框 ──────────────────────────────────────────────────────────────

Future<HubCreateRoomResult?> showCreateRoomDialog() async {
  final notifier = _CreateRoomNotifier();

  final result = await showDialog<HubCreateRoomResult>(
    context: App.rootContext,
    barrierDismissible: true,
    builder: (ctx) => _CreateRoomDialog(notifier: notifier),
  );

  return result;
}

class HubCreateRoomResult {
  final String name;
  final String? password;
  final String? announcement;
  final int? maxParticipants;

  const HubCreateRoomResult({
    required this.name,
    this.password,
    this.announcement,
    this.maxParticipants,
  });
}

// ── 状态 notifier ─────────────────────────────────────────────────────────────

class _CreateRoomNotifier extends ChangeNotifier {
  double _maxParticipants = 2;
  bool _hasLimit = false;

  double get maxParticipants => _maxParticipants;

  bool get hasLimit => _hasLimit;

  void setHasLimit(bool v) {
    _hasLimit = v;
    notifyListeners();
  }

  void setMax(double v) {
    _maxParticipants = v;
    notifyListeners();
  }
}

// ── 对话框 widget ─────────────────────────────────────────────────────────────

class _CreateRoomDialog extends StatefulWidget {
  final _CreateRoomNotifier notifier;

  const _CreateRoomDialog({required this.notifier});

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  late final _CreateRoomNotifier _n;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _announcementCtrl;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _n = widget.notifier;
    _nameCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _announcementCtrl = TextEditingController();
    _n.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _announcementCtrl.dispose();
    _n.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final pwd = _passwordCtrl.text.trim();
    final announcement = _announcementCtrl.text.trim();
    final result = HubCreateRoomResult(
      name: name,
      password: pwd.isEmpty ? null : pwd,
      announcement: announcement.isEmpty ? null : announcement,
      maxParticipants: _n.hasLimit ? _n.maxParticipants.round() : null,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ContentDialog(
      title: t.createRoom,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 房间名 ────────────────────────────────────────────────
          _FieldLabel(t.roomName),
          const SizedBox(height: 6),
          InputField(
            controller: _nameCtrl,
            hint: t.enterRoomName,
            icon: Icons.meeting_room_outlined,
            onSubmit: (_) => _confirm(),
          ),
          const SizedBox(height: 14),

          // ── 公告（可选）────────────────────────────────────────────
          _FieldLabel(t.announcements, optional: true),
          const SizedBox(height: 6),
          InputField(
            controller: _announcementCtrl,
            hint: t.roomAnnouncement,
            icon: Icons.campaign_outlined,
            onSubmit: (_) => _confirm(),
          ),
          const SizedBox(height: 14),

          // ── 密码（可选）────────────────────────────────────────────
          _FieldLabel(t.password, optional: true),
          const SizedBox(height: 6),
          InputField(
            controller: _passwordCtrl,
            hint: t.leaveEmptyForPublicRoom,
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            onSubmit: (_) => _confirm(),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: cs.onSurface.toOpacity(0.4),
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 14),

          // ── 人数限制 ──────────────────────────────────────────────
          Row(
            children: [
              _FieldLabel(t.maxParticipants),
              const Spacer(),
              CustomSwitch(value: _n.hasLimit, onChanged: _n.setHasLimit),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _n.hasLimit
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: _n.maxParticipants,
                          min: 2,
                          max: 20,
                          divisions: 18,
                          onChanged: _n.setMax,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _n.maxParticipants.round().toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${t.upTo} ${_n.maxParticipants.round()} ${t.peopleLabel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.toOpacity(0.45),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                t.noLimit,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.toOpacity(0.4),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [Button.filled(onPressed: _confirm, child: Text(t.create))],
    );
  }
}

// ── 共用小组件 ────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;

  const _FieldLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.toOpacity(0.75),
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            t.optional,
            style: TextStyle(fontSize: 11, color: cs.onSurface.toOpacity(0.35)),
          ),
        ],
      ],
    );
  }
}

class InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final void Function(String)? onSubmit;

  const InputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmit,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: cs.onSurface.toOpacity(0.35)),
        prefixIcon: Icon(icon, size: 18, color: cs.onSurface.toOpacity(0.4)),
        suffixIcon: suffix,
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
