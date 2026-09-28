import 'package:kostori/foundation/appdata.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
    hwdec: hardwareAcceleration ? hardwareDecoder : 'no',
    androidAttachSurfaceAfterVideoParameters: false,
  );
}
