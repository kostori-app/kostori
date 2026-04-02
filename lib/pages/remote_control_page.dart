import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/i18n/strings.g.dart';

class RemoteControlPage extends StatefulWidget {
  final LanDiscoveredDevice device;

  const RemoteControlPage({super.key, required this.device});

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  bool _isConnected = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _isConnected = LanControlClient.instance.isConnected;
    LanControlClient.instance.addStateChangedListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    LanControlClient.instance.removeStateChangedListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged(LanControlServiceState state, String? error) {
    if (!mounted) return;
    setState(() {
      _isConnected = state == LanControlServiceState.connected;
    });
    if (!_isConnected) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _send(Future<void> Function() action) async {
    if (!_isConnected || _isSending) return;
    setState(() => _isSending = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _play() => _send(
    () => LanControlClient.instance.sendPlayerControl(PlayerControlAction.play),
  );

  Future<void> _pause() => _send(
    () =>
        LanControlClient.instance.sendPlayerControl(PlayerControlAction.pause),
  );

  Future<void> _seekForward() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.seekForward,
      10,
    ),
  );

  Future<void> _seekBack() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.seekBackward,
      10,
    ),
  );

  Future<void> _nextEpisode() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.nextEpisode,
    ),
  );

  Future<void> _prevEpisode() => _send(
    () => LanControlClient.instance.sendPlayerControl(
      PlayerControlAction.previousEpisode,
    ),
  );

  Future<void> _navigateTo(NavigateTarget target) =>
      _send(() => LanControlClient.instance.sendNavigate(target));

  void _disconnect() {
    LanControlClient.instance.disconnect();
    App.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isConnected) {
          await LanControlClient.instance.sendNavigate(
            NavigateTarget.exitPlayer,
          );
        }
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: Appbar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_outlined),
            onPressed: () async {
              if (_isConnected) {
                await LanControlClient.instance.sendNavigate(
                  NavigateTarget.exitPlayer,
                );
              }
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Text('${t.lanRemoteControl}: ${widget.device.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: t.lanExitControl,
            ),
          ],
        ),
        body: Column(
          children: [
            _ConnectionBanner(isConnected: _isConnected, device: widget.device),

            if (_isSending)
              const LinearProgressIndicator()
            else
              const SizedBox(height: 4),

            const Divider(height: 1),

            Expanded(
              child: _isConnected
                  ? ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _ControlSection(
                          title: t.lanPlayerControl,
                          children: [
                            _IconButton(
                              icon: Icons.skip_previous,
                              label: t.lanPreviousEpisode,
                              onPressed: _prevEpisode,
                            ),
                            _IconButton(
                              icon: Icons.replay_10,
                              label: t.lanSeekBack,
                              onPressed: _seekBack,
                            ),
                            _IconButton(
                              icon: Icons.play_arrow,
                              label: t.lanPlay,
                              onPressed: _play,
                            ),
                            _IconButton(
                              icon: Icons.pause,
                              label: t.lanPause,
                              onPressed: _pause,
                            ),
                            _IconButton(
                              icon: Icons.forward_10,
                              label: t.lanSeekForward,
                              onPressed: _seekForward,
                            ),
                            _IconButton(
                              icon: Icons.skip_next,
                              label: t.lanNextEpisode,
                              onPressed: _nextEpisode,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _ControlSection(
                          title: t.lanNavigationControl,
                          children: [
                            _IconButton(
                              icon: Icons.home_outlined,
                              label: t.lanNavHome,
                              onPressed: () =>
                                  _navigateTo(NavigateTarget.bangumi),
                            ),
                            _IconButton(
                              icon: Icons.search_outlined,
                              label: t.lanNavSearch,
                              onPressed: () =>
                                  _navigateTo(NavigateTarget.search),
                            ),
                            _IconButton(
                              icon: Icons.settings_outlined,
                              label: t.lanNavSettings,
                              onPressed: () =>
                                  _navigateTo(NavigateTarget.settings),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_off_rounded,
                            size: 56,
                            color: cs.outlineVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.lanRemoteControlConnectionFailed,
                            style: TextStyle(color: cs.outline),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final bool isConnected;
  final LanDiscoveredDevice device;

  const _ConnectionBanner({required this.isConnected, required this.device});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isConnected
          ? cs.primaryContainer.withAlpha(80)
          : cs.errorContainer.withAlpha(80),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : cs.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isConnected
                  ? '${t.lanRemoteControlConnected}  •  ${device.ip}:${device.port}'
                  : t.lanRemoteControlConnectionFailed,
              style: TextStyle(
                fontSize: 13,
                color: isConnected
                    ? cs.onPrimaryContainer
                    : cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ControlSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: children),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _IconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}
