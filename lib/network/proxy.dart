import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/utils/ext.dart';

String? _cachedProxy;

DateTime? _cachedProxyTime;

/// Headless `--proxy` 的进程内覆盖，不写回用户配置文件。
String? _runtimeProxyOverride;

void setRuntimeProxyOverride(String? raw) {
  _runtimeProxyOverride = raw == null ? null : normalizeProxyUrl(raw);
  _cachedProxy = null;
  _cachedProxyTime = null;
}

/// 是否存在部署层显式代理（环境变量或 `--proxy`）。
bool get hasProxyOverride =>
    _runtimeProxyOverride != null || proxyFromEnvironment() != null;

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

/// 无头部署可通过环境变量配置代理；KOSTORI_PROXY 优先于标准代理变量。
String? proxyFromEnvironment() {
  const keys = [
    "KOSTORI_PROXY",
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

/// 把代理地址规整成 rhttp 可以使用的绝对 URL。
///
/// 环境变量通常已经带有 scheme，应用设置和平台通道则可能只返回
/// `host:port`。rhttp 的 [ProxySettings.proxy] 要求绝对 URL；之前把 scheme
/// 去掉后再传给 rhttp，会导致无头服务看似配置了代理，实际仍然无法连接
/// Bangumi。无法识别时返回 null。
String? normalizeProxyUrl(String raw) {
  var value = raw.removeAllBlank;
  if (value.isEmpty) return null;

  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(value);
  final uri = Uri.tryParse(
    // Uri.parse 认不出裸 host:port，补默认 HTTP scheme。
    hasScheme ? value : 'http://$value',
  );
  final host = uri?.host ?? '';
  final port = uri?.port;
  final scheme = uri?.scheme.toLowerCase();
  if (host.isEmpty || port == null || port <= 0) return null;
  if (scheme != 'http' && scheme != 'https' && scheme != 'socks5') {
    return null;
  }

  // 代理地址不应带路径或查询参数，但要保留 user:pass 认证信息。
  return uri
      ?.replace(scheme: scheme, path: '', query: null, fragment: null)
      .toString();
}

/// 将绝对代理 URL 转成 dart:io `findProxy` 使用的 PAC 规则。
String proxyForDartIo(String proxy) {
  final uri = Uri.tryParse(proxy);
  if (uri == null || uri.host.isEmpty || uri.port <= 0) {
    return 'PROXY $proxy';
  }
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final address = '$host:${uri.port}';
  return uri.scheme.toLowerCase() == 'socks5'
      ? 'SOCKS5 $address'
      : 'PROXY $address';
}

/// 解析 Windows 返回的 `http=host:port;https=host:port` 形式。
String? _normalizeProxyResponse(String raw) {
  final value = raw.removeAllBlank;
  if (value.isEmpty || value == 'No Proxy') return null;

  if (value.contains(';')) {
    final entries = <String, String>{};
    for (final part in value.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      entries[part.substring(0, separator).toLowerCase()] = part.substring(
        separator + 1,
      );
    }
    // HTTPS 代理通常也能处理 HTTP 请求；没有时再退回 HTTP / SOCKS5。
    for (final key in ['https', 'http', 'socks', 'socks5']) {
      final candidate = entries[key];
      if (candidate == null) continue;
      final normalized = normalizeProxyUrl(
        candidate.startsWith('socks') ? 'socks5://$candidate' : candidate,
      );
      if (normalized != null) return normalized;
    }
    return null;
  }

  return normalizeProxyUrl(value);
}

Future<String?> _getProxy() async {
  if (_runtimeProxyOverride != null) return _runtimeProxyOverride;

  // Headless 部署显式设置 KOSTORI_PROXY 时优先于应用内代理选项，
  // 这样不会被 GUI 设备上保存的 direct/system 设置影响。
  final deploymentProxy = Platform.environment['KOSTORI_PROXY']?.removeAllBlank;
  if (deploymentProxy != null && deploymentProxy.isNotEmpty) {
    final normalized = normalizeProxyUrl(deploymentProxy);
    if (normalized != null) return normalized;
  }
  if ((appdata.settings['proxy'] as String).removeAllBlank == "direct") {
    return null;
  }
  if (appdata.settings['proxy'] != "system") {
    return normalizeProxyUrl(appdata.settings['proxy']);
  }

  String res;
  if (!App.isLinux) {
    const channel = MethodChannel("kostori/method_channel");
    try {
      res = await channel.invokeMethod<String>("getProxy") ?? "No Proxy";
    } catch (e) {
      // Headless 模式没有桌面平台通道；部署代理可从环境变量提供。
      res = proxyFromEnvironment() ?? "No Proxy";
    }
    // 桌面通道报告无代理时，也允许部署环境显式提供代理。
    if (res == "No Proxy") res = proxyFromEnvironment() ?? res;
  } else {
    // 探测不到时返回 null，由调用方透传给底层客户端读取环境变量
    res = proxyFromEnvironment() ?? "No Proxy";
  }
  return _normalizeProxyResponse(res);
}
