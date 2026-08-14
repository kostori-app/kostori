import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/utils/init.dart';

/// 插件目录名（相对 App.dataPath）
const String mePluginsDirName = 'plugins';

/// 个人页插件模型：对应 data/me_plugins 目录下一个 *.js 文件。
///
/// 插件 JS 约定：
/// ```js
/// const plugin = {
///   name: '示例插件',
///   version: '1.0.0',
///   description: '描述',
///   async render() {
///     // 可用 Network.get / Network.post / appdata 等运行时 API
///     return [
///       { type: 'card', title: '标题', children: [
///         { type: 'text', text: '内容' },
///         { type: 'keyValue', key: '状态', value: '正常' },
///       ]},
///       { type: 'signIn', text: '签到', url: 'https://x/sign', method: 'POST', body: {} },
///     ];
///   }
/// };
/// ```
class MePagePlugin {
  final String name;
  final String key;
  final String version;
  final String description;
  final String filePath;

  const MePagePlugin({
    required this.name,
    required this.key,
    required this.version,
    required this.description,
    required this.filePath,
  });

  /// 调用插件 render()，返回模块列表（List<Map>）。
  Future<List<dynamic>> render() async {
    try {
      final res = await JsEngine().runCode(
        "globalThis.__me_plugins[${_jsStr(key)}]?.render()",
      );
      if (res is List) return res;
    } catch (e, s) {
      SourceLog.error('MePagePlugin($name)', '$e\n$s');
    }
    return const [];
  }

  /// 发送插件里的 signIn 请求（复用 JS Network，走代理/Cookie）。
  /// 返回 { status, body }。
  static Future<Map<String, dynamic>> request({
    required String url,
    required String method,
    Map<String, dynamic> headers = const {},
    Map<String, dynamic> body = const {},
  }) async {
    final isPost = method.toUpperCase() == 'POST';
    final resJson = await JsEngine().runCode("""
      (async () => {
        const [u, h, b] = ${_jsJson([url, headers, body])};
        const r = ${isPost ? 'await Network.post(u, h, b)' : 'await Network.get(u, h)'};
        return JSON.stringify({ status: r.status, body: r.body ?? '' });
      })()
    """);
    try {
      final data = _jsJsonDecode(resJson);
      return {'status': data['status'], 'body': data['body']?.toString() ?? ''};
    } catch (_) {
      return {'status': -1, 'body': resJson?.toString() ?? ''};
    }
  }
}

/// 个人页插件管理器：从 data/me_plugins 读取 *.js。
class MePagePluginManager with ChangeNotifier, Init {
  final List<MePagePlugin> _plugins = [];

  static MePagePluginManager? _instance;

  factory MePagePluginManager() => _instance ??= MePagePluginManager._create();

  MePagePluginManager._create();

  List<MePagePlugin> all() => List.from(_plugins);

  bool get isEmpty => _plugins.isEmpty;

  @override
  @protected
  Future<void> doInit() async {
    await JsEngine().ensureInit();
    JsEngine().runCode(
      "globalThis.__me_plugins = globalThis.__me_plugins ?? {};",
    );
    final path = "${App.dataPath}/$mePluginsDirName";
    if (!(await Directory(path).exists())) {
      await Directory(path).create();
      return;
    }
    await for (final entity in Directory(path).list()) {
      if (entity is! File || !entity.path.endsWith('.js')) continue;
      try {
        final plugin = await MePagePluginParser().parse(
          await entity.readAsString(),
          entity.absolute.path,
        );
        _plugins.add(plugin);
      } catch (e, s) {
        SourceLog.error('MePagePlugin', '$e\n$s');
      }
    }
  }

  Future<void> reload() async {
    _plugins.clear();
    await doInit();
    notifyListeners();
  }
}

/// 个人页插件解析器：执行 JS 文件并把 `plugin` 对象挂到全局。
class MePagePluginParser {
  Future<MePagePlugin> parse(String js, String filePath) async {
    js = js.replaceAll('\r\n', '\n');
    final fileName = filePath.split(Platform.pathSeparator).last;
    final key = fileName.endsWith('.js')
        ? fileName.substring(0, fileName.length - 3)
        : fileName;

    JsEngine().runCode("""
      (() => {
        $js
        if (typeof plugin !== 'undefined') {
          globalThis.__me_plugins[${_jsStr(key)}] = plugin;
        }
      }).call()
    """);

    final name = JsEngine().runCode(
      "globalThis.__me_plugins[${_jsStr(key)}]?.name",
    );
    if (name == null) throw Exception('插件缺少 name');
    final version =
        JsEngine()
            .runCode("globalThis.__me_plugins[${_jsStr(key)}]?.version")
            ?.toString() ??
        '0.0.0';
    final description =
        JsEngine()
            .runCode("globalThis.__me_plugins[${_jsStr(key)}]?.description")
            ?.toString() ??
        '';

    return MePagePlugin(
      name: name.toString(),
      key: key,
      version: version,
      description: description,
      filePath: filePath,
    );
  }
}

String _jsStr(String s) => "'${s.replaceAll("'", r"\'")}'";

String _jsJson(Object o) {
  final buf = StringBuffer();
  _writeJson(buf, o);
  return buf.toString();
}

void _writeJson(StringBuffer buf, Object? o) {
  if (o == null) {
    buf.write('null');
  } else if (o is String) {
    buf.write("'${o.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'");
  } else if (o is num || o is bool) {
    buf.write(o.toString());
  } else if (o is Map) {
    buf.write('{');
    var first = true;
    o.forEach((k, v) {
      if (!first) buf.write(',');
      first = false;
      buf.write(_jsStr(k.toString()));
      buf.write(':');
      _writeJson(buf, v);
    });
    buf.write('}');
  } else if (o is List) {
    buf.write('[');
    for (var i = 0; i < o.length; i++) {
      if (i > 0) buf.write(',');
      _writeJson(buf, o[i]);
    }
    buf.write(']');
  } else {
    buf.write('null');
  }
}

Map<String, dynamic> _jsJsonDecode(Object? o) {
  if (o is Map) {
    return o.map((k, v) => MapEntry(k.toString(), v));
  }
  return {};
}
