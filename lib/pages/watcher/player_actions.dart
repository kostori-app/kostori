import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/watcher/player_controller.dart';
import 'package:kostori/utils/remote.dart';

/// 桌面端音频输出设备选择弹窗。
/// 用 [App.rootContext]，以便在 sheet 已经关闭后仍能弹出。
Future<void> showPlayerAudioDevicePicker(PlayerController playerController) async {
  final devices = await playerController.getAudioDevices();
  final current = playerController.currentAudioDevice;
  final context = App.rootContext;
  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => ContentDialog(
      title: t.audioOutputDevice,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.autorenew, size: 18),
            title: Text(t.autoDetect),
            trailing: current.isEmpty ? const Icon(Icons.check, size: 18) : null,
            onTap: () async {
              await playerController.setAudioDevice('');
              if (ctx.mounted) Navigator.pop(ctx);
            },
          ),
          for (final d in devices)
            ListTile(
              dense: true,
              leading: const Icon(Icons.speaker_outlined, size: 18),
              title: Text(d.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: current == d.name
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () async {
                await playerController.setAudioDevice(d.name);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(t.noAudioDevice),
            ),
        ],
      ),
    ),
  );
}

/// 播放器操作按钮行（音频设备 / 小窗 / 投屏 / 日志 / 播放器详情）。
/// 「更多」面板与「视频详情」tab 共用，保证按钮数量与样式一致。
/// 弹窗一律用 [App.rootContext]，避免 sheet 关闭后 context 失效。
class PlayerActionButtons extends StatelessWidget {
  const PlayerActionButtons({
    super.key,
    required this.playerController,
    required this.onPlayerDetails,
    this.onBeforeAction,
  });

  final PlayerController playerController;

  /// 「播放器详情」动作
  final VoidCallback onPlayerDetails;

  /// 每个动作执行前调用（如关闭当前 sheet）
  final VoidCallback? onBeforeAction;

  void _run(VoidCallback action) {
    onBeforeAction?.call();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final pc = playerController;
    final rootContext = App.rootContext;
    return Row(
      children: [
        if (App.isDesktop)
          IconTileButton(
            icon: const Icon(Icons.speaker_outlined),
            label: t.audioOutputDevice,
            onTap: () => _run(() => showPlayerAudioDevicePicker(pc)),
          ),
        if (!pc.isFullScreen && App.isAndroid)
          IconTileButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            label: t.watcherMiniWindow,
            onTap: () => _run(() async {
              final floating = Floating();
              if (await floating.isPipAvailable) {
                final status = await floating.pipStatus;
                if (status == PiPStatus.disabled ||
                    status == PiPStatus.automatic) {
                  pc.enterPiPMode();
                } else if (status == PiPStatus.enabled) {
                  pc.exitPiPMode();
                }
              }
            }),
          ),
        IconTileButton(
          icon: const Icon(Icons.cast_outlined),
          label: t.remoteCast,
          onTap: () => _run(() {
            final needRestart = pc.playing;
            pc.pause();
            RemotePlay().castVideo(pc.videoUrl).whenComplete(() {
              if (needRestart) pc.play();
            });
          }),
        ),
        // 正在用种子播放：可切回在线源（本集）
        if (pc.isTorrentPlayback)
          IconTileButton(
            icon: const Icon(Icons.cloud_outlined),
            label: t.torrentSwitchOnline,
            onTap: () => _run(() {
              pc.playEpisodeFromSource(pc.currentEpisoded, pc.currentRoad);
            }),
          ),
        if (!pc.isFullScreen)
          IconTileButton(
            icon: const Icon(Icons.article_outlined),
            label: t.log,
            onTap: () => _run(() {
              showModalBottomSheet(
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(rootContext).height * 0.85,
                  maxWidth: MediaQuery.sizeOf(rootContext).width <= 600
                      ? MediaQuery.sizeOf(rootContext).width
                      : (App.isDesktop
                            ? MediaQuery.sizeOf(rootContext).width * 9 / 16
                            : MediaQuery.sizeOf(rootContext).width),
                ),
                clipBehavior: Clip.antiAlias,
                context: rootContext,
                builder: (_) => Sheet(
                  title: t.logs,
                  icon: Icons.article_outlined,
                  initialSize: 0.85,
                  builder: (_, _) => const LogsPage(inSheet: true),
                ),
              );
            }),
          ),
        IconTileButton(
          icon: const Icon(Icons.info_outline),
          label: t.playerDetails,
          onTap: () => _run(onPlayerDetails),
        ),
      ],
    );
  }
}
