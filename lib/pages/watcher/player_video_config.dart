import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Android 上 AV1 的 MediaCodec 直通解码需要有 Surface，而 player 建好、
/// 开始 open 时 Video widget 还没挂载、surface 为空，mpv 会报
/// 「av1_mediacodec: Both surface and native_window are NULL」后再回落。
/// 把 av1 从硬解白名单剔除，避免这次无效探测与报错（AV1 仍可用 dav1d 软解）。
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
