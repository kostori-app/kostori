import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/watcher/player_cache.dart';
import 'package:kostori/pages/watcher/player_controller.dart';

/// 播放器设置卡片（图标 + 标题 + 任意内容），用于倍速 / 超分辨率等。
/// 「更多」sheet、「视频详情」tab 与本地播放器共用，避免重复实现。
class PlayerSettingCard extends StatelessWidget {
  const PlayerSettingCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;

  final String title;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放器设置卡片（图标 + 标题 + 开关），用于各功能开关。
class PlayerSwitchCard extends StatefulWidget {
  const PlayerSwitchCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;

  final String title;

  final bool value;

  final ValueChanged<bool> onChanged;

  @override
  State<PlayerSwitchCard> createState() => _PlayerSwitchCardState();
}

class _PlayerSwitchCardState extends State<PlayerSwitchCard> {
  late bool _value = widget.value;

  @override
  void didUpdateWidget(covariant PlayerSwitchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              CustomSwitch(
                value: _value,
                onChanged: (v) {
                  setState(() => _value = v);
                  widget.onChanged(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 播放倍速卡片（watcher 与本地播放器共用）。
class PlayerPlaybackSpeedCard extends StatelessWidget {
  const PlayerPlaybackSpeedCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;

  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return PlayerSettingCard(
      icon: Icons.speed_outlined,
      title: t.playbackSpeed,
      child: Column(
        children: [
          Slider(
            value: value.clamp(0.5, 4.0),
            min: 0.5,
            max: 4.0,
            divisions: 7,
            onChanged: onChanged,
          ),
          Text(
            '${value.toStringAsFixed(2)}x',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// 超分辨率卡片（watcher 与本地播放器共用），[value] 为 1 关 / 2 效率 / 3 质量。
class PlayerSuperResolutionCard extends StatelessWidget {
  const PlayerSuperResolutionCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PlayerSettingCard(
      icon: Icons.high_quality_outlined,
      title: t.superResolution,
      child: CapsuleOptions(
        alignment: WrapAlignment.start,
        wrap: true,
        children: [
          CapsuleOption(
            text: t.superResolutionOff,
            isSelected: value == 1,
            onTap: () => onChanged(1),
          ),
          CapsuleOption(
            text: t.superResolutionEfficiency,
            isSelected: value == 2,
            onTap: () => onChanged(2),
          ),
          CapsuleOption(
            text: t.superResolutionQuality,
            isSelected: value == 3,
            onTap: () => onChanged(3),
          ),
        ],
      ),
    );
  }
}

/// 通用功能开关 + 缓存挡位（watcher 与本地播放器共用，新增开关只需改这里）。
/// 本地播放器可传 [showCache] = false 并用自己的 [PlayerCacheCard]。
class PlayerCommonToggles extends StatefulWidget {
  const PlayerCommonToggles({super.key, this.showCache = true});

  final bool showCache;

  @override
  State<PlayerCommonToggles> createState() => _PlayerCommonTogglesState();
}

class _PlayerCommonTogglesState extends State<PlayerCommonToggles> {
  Widget _switch({
    required IconData icon,
    required String title,
    required String key,
    bool defaultValue = true,
  }) {
    return PlayerSwitchCard(
      icon: icon,
      title: title,
      value: appdata.implicitData[key] ?? defaultValue,
      onChanged: (v) {
        appdata.implicitData[key] = v;
        appdata.writeImplicitData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _switch(
          icon: Icons.headphones_outlined,
          title: t.playerBackgroundPlay,
          key: 'playerBackgroundPlay',
        ),
        _switch(
          icon: Icons.history_toggle_off,
          title: t.playerAutoResume,
          key: 'playerAutoResume',
        ),
        _switch(
          icon: Icons.brightness_6_outlined,
          title: t.playerBrightnessGesture,
          key: 'playerBrightnessGesture',
        ),
        _switch(
          icon: Icons.volume_up_outlined,
          title: t.playerVolumeGesture,
          key: 'playerVolumeGesture',
        ),
        // 播放器缓存挡位（分段胶囊），修改后需重开播放器生效
        if (widget.showCache)
          PlayerCacheCard(
            tierKey: kPlayerCacheTierKey,
            tiers: playerCacheTiers,
            current: currentPlayerCacheTier,
          ),
      ],
    );
  }
}

/// 播放器缓存挡位卡片：可选独立 [tierKey] / [tiers]，
/// 本地播放器用它维护自己独立的持久化缓存设置。
class PlayerCacheCard extends StatefulWidget {
  const PlayerCacheCard({
    super.key,
    required this.tierKey,
    required this.tiers,
    this.current,
  });

  final String tierKey;

  final List<PlayerCacheTier> tiers;

  final PlayerCacheTier? current;

  @override
  State<PlayerCacheCard> createState() => _PlayerCacheCardState();
}

class _PlayerCacheCardState extends State<PlayerCacheCard> {
  PlayerCacheTier get _current {
    final key = appdata.implicitData[widget.tierKey];
    for (final tier in widget.tiers) {
      if (tier.key == key) return tier;
    }
    return widget.current ?? widget.tiers.first;
  }

  @override
  Widget build(BuildContext context) {
    return PlayerSettingCard(
      icon: Icons.sd_storage_outlined,
      title: t.playerCache,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CapsuleOptions(
            alignment: WrapAlignment.start,
            wrap: true,
            children: [
              for (final tier in widget.tiers)
                CapsuleOption(
                  text: playerCacheTierLabel(tier),
                  isSelected: _current.key == tier.key,
                  onTap: () {
                    appdata.implicitData[widget.tierKey] = tier.key;
                    appdata.writeImplicitData();
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.playerCacheDesc,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// watcher 播放器设置卡片组：专属开关 + 通用开关 + 倍速 + 超分辨率。
/// 「更多」sheet 与「视频详情」tab 共用；新增设置只需改这里一处。
class PlayerSettingsCards extends StatelessWidget {
  const PlayerSettingsCards({super.key, required this.playerController});

  final PlayerController playerController;

  @override
  Widget build(BuildContext context) {
    final pc = playerController;
    return Observer(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (App.isAndroid)
            PlayerSwitchCard(
              icon: Icons.speaker_outlined,
              title: t.audioOption,
              value: pc.audioOutType,
              onChanged: (v) async {
                await pc.setAudioOutType(v);
                App.rootContext.showMessage(message: t.switchSuccessful);
              },
            ),
          if (App.isDesktop)
            PlayerSwitchCard(
              icon: Icons.graphic_eq_outlined,
              title: t.volumeBoost,
              value: pc.volumeBoost,
              onChanged: (v) async {
                await pc.toggleVolumeBoost();
                App.rootContext.showMessage(message: t.switchSuccessful);
              },
            ),
          PlayerSwitchCard(
            icon: Icons.auto_awesome_outlined,
            title: t.glimmerMode,
            value: pc.glimmerEffect,
            onChanged: (v) {
              pc.glimmerEffect = v;
              appdata.implicitData['glimmerEffect'] = v;
              appdata.writeImplicitData();
            },
          ),
          PlayerSwitchCard(
            icon: Icons.play_circle_outline,
            title: t.playerAutoPlayOnEnter,
            value: appdata.implicitData['playerAutoPlayOnEnter'] ?? true,
            onChanged: (v) {
              appdata.implicitData['playerAutoPlayOnEnter'] = v;
              appdata.writeImplicitData();
            },
          ),
          PlayerSwitchCard(
            icon: Icons.skip_next_rounded,
            title: t.playerAutoPlay,
            value: appdata.implicitData['playerAutoPlay'] ?? true,
            onChanged: (v) {
              appdata.implicitData['playerAutoPlay'] = v;
              appdata.writeImplicitData();
            },
          ),
          PlayerSwitchCard(
            icon: Icons.repeat_rounded,
            title: t.playerLoopEpisode,
            value: appdata.implicitData['playerLoopEpisode'] ?? false,
            onChanged: (v) {
              appdata.implicitData['playerLoopEpisode'] = v;
              appdata.writeImplicitData();
            },
          ),
          const PlayerCommonToggles(),
          PlayerSwitchCard(
            icon: Icons.filter_alt_outlined,
            title: t.m3u8AdFilter,
            value: appdata.settings['m3u8AdFilterEnabled'] ?? false,
            onChanged: (v) {
              appdata.settings['m3u8AdFilterEnabled'] = v;
              appdata.saveData();
            },
          ),
          PlayerPlaybackSpeedCard(
            value: pc.playbackSpeed,
            onChanged: pc.setPlaybackSpeed,
          ),
          PlayerSuperResolutionCard(
            value: pc.superResolutionType,
            onChanged: pc.setShader,
          ),
        ],
      ),
    );
  }
}
