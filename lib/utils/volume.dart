import 'dart:async';

import 'package:flutter/services.dart';

class VolumeListener {
  static const channel = EventChannel('kostori/volume');

  void Function()? onUp;

  void Function()? onDown;

  VolumeListener({this.onUp, this.onDown});

  StreamSubscription? stream;

  void listen() {
    stream = channel.receiveBroadcastStream().listen(onEvent);
  }

  void onEvent(dynamic event) {
    if (event == 1) {
      onUp!();
    } else if (event == 2) {
      onDown!();
    }
  }

  void cancel() {
    stream?.cancel();
  }
}
