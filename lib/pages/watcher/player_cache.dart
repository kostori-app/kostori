import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 播放器缓存挡位：对应 media_kit PlayerConfiguration.bufferSize（字节）。
class PlayerCacheTier {
  const PlayerCacheTier(this.key, this.bufferBytes);

  final String key;
  final int bufferBytes;
}

const String kPlayerCacheTierKey = 'playerCacheTier';

/// 缓存挡位由低到高；默认「高」保持与原硬编码值（1500MB）一致。
const List<PlayerCacheTier> playerCacheTiers = [
  PlayerCacheTier('low', 256 * 1024 * 1024),
  PlayerCacheTier('medium', 800 * 1024 * 1024),
  PlayerCacheTier('high', 1500 * 1024 * 1024),
  PlayerCacheTier('ultra', 2048 * 1024 * 1024),
];

PlayerCacheTier get currentPlayerCacheTier {
  final key = appdata.implicitData[kPlayerCacheTierKey];
  for (final tier in playerCacheTiers) {
    if (tier.key == key) return tier;
  }
  return playerCacheTiers[2];
}

/// 当前缓存字节数，供 PlayerConfiguration.bufferSize 使用。
/// 修改挡位后需重建 Player（重开播放器）才生效。
int get playerBufferSize => currentPlayerCacheTier.bufferBytes;

/// 本地播放器**独立**的缓存挡位 key（不复用主播放器设置）。
const String kLocalPlayerCacheTierKey = 'localPlayerCacheTier';

/// 本地播放器缓存挡位：本地文件不需要大缓存，大缓存还会在快速 seek 时
/// 占用/刷新大量内存导致闪退，因此整体比主播放器小一档。
const List<PlayerCacheTier> localPlayerCacheTiers = [
  PlayerCacheTier('low', 64 * 1024 * 1024),
  PlayerCacheTier('medium', 128 * 1024 * 1024),
  PlayerCacheTier('high', 256 * 1024 * 1024),
  PlayerCacheTier('ultra', 512 * 1024 * 1024),
];

PlayerCacheTier get currentLocalPlayerCacheTier {
  final key = appdata.implicitData[kLocalPlayerCacheTierKey];
  for (final tier in localPlayerCacheTiers) {
    if (tier.key == key) return tier;
  }
  return localPlayerCacheTiers[1]; // 默认 128MB
}

/// 本地播放器缓存字节数。
int get localPlayerBufferSize => currentLocalPlayerCacheTier.bufferBytes;

String playerCacheTierLabel(PlayerCacheTier tier) => switch (tier.key) {
  'low' => t.cacheLow,
  'medium' => t.cacheMedium,
  'ultra' => t.cacheUltra,
  _ => t.cacheHigh,
};
