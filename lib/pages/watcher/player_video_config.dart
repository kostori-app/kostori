import 'dart:async';

import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// AV1 的 MediaCodec 直通解码需要有 Surface；播放开始时 Surface 尚未挂载，
/// mpv 会先输出 `Both surface and native_window are NULL` 再回落到其他解码器。
/// AV1 保留软件解码，避免触发这次无效探测。
const String _kHwdecCodecsWithoutAv1 =
    'h264,vc1,hevc,vp8,vp9,prores,prores_raw,ffv1,dpx,apv';

/// 在 open 媒体前调用：Android 下限制硬解编码列表（去掉 av1）。
Future<void> applyAndroidHwdecCodecs(Player player) async {
  if (!App.isAndroid) return;
  final platform = player.platform;
  if (platform is NativePlayer) {
    try {
      await platform.setProperty('hwdec-codecs', _kHwdecCodecsWithoutAv1);
    } catch (_) {}
  }
}

/// GPU 渲染时使用 MediaCodec copy 输出，避免 Android 在 Surface 就绪前
/// 尝试直通解码。`mediacodec_embed` 需要直通模式，因此保留原配置。
String resolveAndroidHardwareDecoder(
  String hardwareDecoder, {
  String? videoRenderer,
}) {
  if (!App.isAndroid || videoRenderer == 'mediacodec_embed') {
    return hardwareDecoder;
  }

  if (hardwareDecoder == 'auto' ||
      hardwareDecoder == 'auto-safe' ||
      hardwareDecoder == 'mediacodec') {
    return 'mediacodec-copy';
  }
  return hardwareDecoder;
}

/// `mediacodec_embed` 要求 Android Surface 就绪后才能开始解码。
Future<void> waitForAndroidVideoSurface(VideoController controller) async {
  if (!App.isAndroid || controller.id.value != null) return;

  final surfaceAvailable = Completer<void>();
  void onTextureChanged() {
    if (controller.id.value != null && !surfaceAvailable.isCompleted) {
      surfaceAvailable.complete();
    }
  }

  controller.id.addListener(onTextureChanged);
  onTextureChanged();
  try {
    await surfaceAvailable.future.timeout(const Duration(seconds: 3));
  } on TimeoutException {
    // Surface 创建失败时继续打开媒体，由播放器统一处理后续错误。
  } finally {
    controller.id.removeListener(onTextureChanged);
  }
}

/// 本地播放器视频配置：与 watcher 播放器**实际生效**的配置一致。
///
/// watcher 在 `changePlayerSettings` 里虽然传了 `vo: 'gpu-next'`，但首帧已经
/// 用 `late` 字段按 `vo=null`（Android 默认 `gpu`）创建过一次 `VideoController`；
/// media_kit 对同一个 player 会复用已建的控制器（见 AndroidVideoController.create），
/// 第二次的 `gpu-next` 配置被丢弃，所以实际就是 `gpu`。
///
/// 关键差别只有 `androidAttachSurfaceAfterVideoParameters: false`：
/// 默认（`vo=gpu`）为 true，seek/分辨率变化会重新附加 surface、触发 media_kit
/// 内部的 `widListener` 再次 seek，快速 seek 时容易崩；设成 false 只附加一次。
VideoControllerConfiguration playerVideoControllerConfiguration() {
  final hardwareAcceleration = appdata.settings.s.haEnable;
  final hardwareDecoder = appdata.settings.s.hardwareDecoder;
  return VideoControllerConfiguration(
    // vo 留空 = 平台默认（Android 为 gpu），不要显式 gpu-next（部分机型黑屏）
    enableHardwareAcceleration: hardwareAcceleration,
    hwdec: hardwareAcceleration
        ? resolveAndroidHardwareDecoder(hardwareDecoder)
        : 'no',
    androidAttachSurfaceAfterVideoParameters: false,
  );
}
