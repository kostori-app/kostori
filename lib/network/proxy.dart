import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/utils/ext.dart';

String? _cachedProxy;

DateTime? _cachedProxyTime;

Future<String?> getProxy() async {
  if (_cachedProxyTime != null &&
      DateTime.now().difference(_cachedProxyTime!).inSeconds < 1) {
    return _cachedProxy;
  }
  String? proxy = await _getProxy();
  _cachedProxy = proxy;
  _cachedProxyTime = DateTime.now();
  return proxy;
}

/// 「跟随系统」时不应显式指定代理，交给底层客户端读取环境变量。
bool get isSystemProxy =>
    (appdata.settings['proxy'] as String).removeAllBlank == "system";

/// Linux/WSL 无平台通道，只能从环境变量探测。
String? proxyFromEnvironment() {
  const keys = [
    "HTTPS_PROXY",
    "https_proxy",
    "HTTP_PROXY",
    "http_proxy",
    "ALL_PROXY",
    "all_proxy",
  ];
  for (final key in keys) {
    final value = Platform.environment[key]?.removeAllBlank;
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

Future<String?> _getProxy() async {
  if ((appdata.settings['proxy'] as String).removeAllBlank == "direct") {
    return null;
  }
  if (appdata.settings['proxy'] != "system") return appdata.settings['proxy'];

  String res;
  if (!App.isLinux) {
    const channel = MethodChannel("kostori/method_channel");
    try {
      res = await channel.invokeMethod("getProxy");
    } catch (e) {
      return null;
    }
  } else {
    // 探测不到时返回 null，由调用方透传给底层客户端读取环境变量
    res = proxyFromEnvironment() ?? "No Proxy";
  }
  if (res == "No Proxy") return null;

  if (res.contains(";")) {
    var proxies = res.split(";");
    for (String proxy in proxies) {
      proxy = proxy.removeAllBlank;
      if (proxy.startsWith('https=')) {
        return proxy.substring(6);
      }
    }
  }

  final RegExp regex = RegExp(
    r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+$',
    caseSensitive: false,
    multiLine: false,
  );
  if (!regex.hasMatch(res)) {
    return null;
  }

  return res;
}
