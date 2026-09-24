import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class VolumeListener {
  static const channel = EventChannel('kostori/volume');

  void Function()? onUp;

  void Function()? onDown;

  VolumeListener({this.onUp, this.onDown});

  StreamSubscription? stream;

  void listen() {
    // 该通道只有 Android 注册了原生实现，其它平台监听会抛 PlatformException
    if (!Platform.isAndroid) return;
    stream = channel.receiveBroadcastStream().listen(
      onEvent,
      onError: (_) {},
      cancelOnError: true,
    );
  }

  void onEvent(dynamic event) {
    if (event == 1) {
      onUp?.call();
    } else if (event == 2) {
      onDown?.call();
    }
  }

  void cancel() {
    stream?.cancel();
  }
}
