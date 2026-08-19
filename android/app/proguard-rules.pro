# FFmpegKit rules
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# Keep all FFmpegKit native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep FFmpegKit Config
-keep class com.antonkarpenko.ffmpegkit.FFmpegKitConfig {
    *;
}

# Keep ABI Detection
-keep class com.antonkarpenko.ffmpegkit.AbiDetect {
    *;
}

# Keep all FFmpegKit sessions
-keep class com.antonkarpenko.ffmpegkit.*Session {
    *;
}

# Keep FFmpegKit callbacks
-keep class com.antonkarpenko.ffmpegkit.*Callback {
    *;
}

# Preserve all public classes in ffmpegkit
-keep public class com.antonkarpenko.ffmpegkit.** {
    public *;
}

# Keep reflection-based access
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# 忽略 Google Play Core 的类缺失警告
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
# Floating (画中画 PiP)
-keep class eu.wroblewscy.marcin.floating.** { *; }
-dontwarn eu.wroblewscy.marcin.floating.**

# audio_service 播放通知
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.audioservice.**

# wakelock_plus / permission_handler / flutter_inappwebview 等常用插件
-keep class com.fluttercandies.ffmpeg_kit.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**
-keep class com.bluebubbles.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
