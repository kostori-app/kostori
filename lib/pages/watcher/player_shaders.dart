import 'package:kostori/foundation/consts.dart';
import 'package:kostori/shaders/shaders_controller.dart';
import 'package:kostori/utils/utils.dart';
import 'package:media_kit/media_kit.dart';

/// 给播放器应用超分辨率 shader，返回实际生效的挡位（1 关 / 2 效率 / 3 质量）。
/// watcher 与本地播放器共用，避免两边各写一遍 mpv 命令。
Future<int> applySuperResolutionShader(
  Player player,
  ShadersController shaders,
  int type,
) async {
  final pp = player.platform as NativePlayer;
  await pp.waitForPlayerInitialization;
  await pp.waitForVideoControllerInitializationIfAttached;
  if (type == 2) {
    await pp.command([
      'change-list',
      'glsl-shaders',
      'set',
      Utils.buildShadersAbsolutePath(
        shaders.shadersDirectory.path,
        mpvAnime4KShadersLite,
      ),
    ]);
    return 2;
  }
  if (type == 3) {
    await pp.command([
      'change-list',
      'glsl-shaders',
      'set',
      Utils.buildShadersAbsolutePath(
        shaders.shadersDirectory.path,
        mpvAnime4KShaders,
      ),
    ]);
    return 3;
  }
  await pp.command(['change-list', 'glsl-shaders', 'clr', '']);
  return 1;
}
