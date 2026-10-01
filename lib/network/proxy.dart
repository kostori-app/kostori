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
    final raw = Platform.environment[key]?.removeAllBlank;
    if (raw == null || raw.isEmpty) continue;
    final normalized = normalizeProxyUrl(raw);
    if (normalized != null) return normalized;
  }
  return null;
}

/// 把代理地址规整成 `host:port`，不带 scheme。
///
/// 环境变量通常是 `http://host:port`，平台通道返回的则是裸 `IP:端口`，
/// 统一成后者才能同时喂给 rhttp 与 dart:io。无法识别时返回 null。
String? normalizeProxyUrl(String raw) {
  var value = raw.removeAllBlank;
  value = value.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
  value = value.replaceAll(RegExp(r'/+$'), '');
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(
    // Uri.parse 认不出裸 host:port，补 scheme 才能取到 host / port
    value.contains('://') ? value : 'http://$value',
  );
  final host = uri?.host ?? '';
  final port = uri?.port;
  if (host.isEmpty || port == null || port <= 0) return null;
  // 丢弃 user:pass —— host:port 形式带不下认证信息
  return '$host:$port';
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

  // 环境变量常带 scheme（http://host:port），平台通道给的则是裸 IP:端口
  return normalizeProxyUrl(res);
}
