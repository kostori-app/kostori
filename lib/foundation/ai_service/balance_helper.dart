import 'dart:convert';

import 'package:kostori/foundation/ai_service/ai_base.dart';
import 'package:kostori/foundation/res.dart';
import 'package:kostori/network/app_dio.dart';

/// 内置服务商的默认余额查询配置（查询地址路径 + 结果字段点号路径）。
/// 其余服务商返回 null，需要在配置页手动填写。
({String path, String key})? balanceDefaultConfig(String provider) =>
    switch (provider) {
      'deepseek' => (
        path: '/user/balance',
        key: 'balance_infos[0].total_balance',
      ),
      'siliconFlow' => (path: '/user/info', key: 'data.balance'),
      'openrouter' => (path: '/credits', key: 'credits'),
      _ => null,
    };

/// 通用余额查询：
/// - [baseUrl] 服务商基础地址，[balanceUrl] 为相对路径或绝对 URL；
/// - [balanceKey] 为结果字段点号路径（如 `data.balance`、`balance_infos[0].total_balance`），
///   为空时返回整个响应体。
///
/// 不支持的场景返回 [Res.error]，其 [Res.errorMessage] 为 [kBalanceQueryUnsupported]。
Future<Res<String>> queryBalanceByUrl({
  required String baseUrl,
  required String? apiKey,
  String? balanceUrl,
  String? balanceKey,
}) async {
  if (apiKey == null || apiKey.isEmpty) {
    return const Res.error(kBalanceQueryUnsupported);
  }
  final url = balanceUrl?.trim() ?? '';
  if (url.isEmpty) {
    return const Res.error(kBalanceQueryUnsupported);
  }
  try {
    final base = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final endpoint = url.startsWith('http')
        ? url
        : '$base/${url.replaceFirst(RegExp(r'^/+'), '')}';
    final res = await AppDio().request(
      endpoint,
      options: Options(
        method: 'GET',
        headers: {'Authorization': 'Bearer $apiKey'},
      ),
    );
    final key = balanceKey?.trim() ?? '';
    final value = key.isEmpty ? res.data : _walkJsonPath(res.data, key);
    if (value == null) return const Res.error(kBalanceQueryUnsupported);
    if (value is String) return Res(value);
    if (value is num || value is bool) return Res(value.toString());
    return Res(jsonEncode(value));
  } catch (e) {
    return Res.error(e.toString());
  }
}

/// 按点号路径取值，支持数组下标：`a.b[0].c`
dynamic _walkJsonPath(dynamic data, String path) {
  dynamic current = data;
  final re = RegExp(r'([^.\[]+)|\[(\d+)\]');
  for (final m in re.allMatches(path)) {
    final seg = m.group(1) ?? m.group(2)!;
    final idx = int.tryParse(seg);
    if (idx != null) {
      if (current is List && idx >= 0 && idx < current.length) {
        current = current[idx];
      } else {
        return null;
      }
    } else if (current is Map && current[seg] != null) {
      current = current[seg];
    } else {
      return null;
    }
  }
  return current;
}
