import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/js_engine.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/network/app_dio.dart';
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

  /// 插件声明的站点 Referer（图片防盗链用，可选）
  final String? referer;

  /// 本插件独立状态（对齐番剧源 `.data`），持久化到 `plugins/<key>.data`
  Map<String, dynamic> data;

  MePagePlugin({
    required this.name,
    required this.key,
    required this.version,
    required this.description,
    required this.filePath,
    this.referer,
    Map<String, dynamic> initialData = const {},
  }) : data = {...initialData};

  String get _dataPath {
    final base = filePath.endsWith('.js')
        ? filePath.substring(0, filePath.length - 3)
        : filePath;
    return '$base.data';
  }

  void _saveData() {
    try {
      File(_dataPath).writeAsStringSync(jsonEncode(data));
    } catch (e) {
      SourceLog.error('MePagePlugin($name).saveData', '$e');
    }
  }

  /// 插件是否启用（默认启用）
  bool get isEnabled => data['enabled'] != false;

  void setEnabled(bool v) {
    data['enabled'] = v;
    _saveData();
  }

  /// 是否在“自动签到”名单（默认加入）
  bool get isAutoSign => data['autoSign'] != false;

  void setAutoSign(bool v) {
    data['autoSign'] = v;
    _saveData();
  }

  /// 是否提供规范的 `plugin.signin()` 签到入口
  bool get signinAvailable {
    try {
      final res = JsEngine().runCode(
        "typeof globalThis.__me_plugins[${_jsStr(key)}]?.signin === 'function'",
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// 调用插件 `signin()`，期望返回 `{ ok, message? }`。
  Future<Map<String, dynamic>> signin() async {
    try {
      final res = await JsEngine().runCode("""
        (async () => {
          const fn = globalThis.__me_plugins[${_jsStr(key)}]?.signin;
          if (typeof fn !== 'function') {
            return JSON.stringify({ ok: false, message: '' });
          }
          const r = await fn();
          return JSON.stringify({
            ok: !!(r && r.ok),
            message: (r && (r.message || r.error)) || ''
          });
        })()
      """);
      if (res is String) {
        try {
          final data = jsonDecode(res) as Map<String, dynamic>;
          return {'ok': data['ok'] == true, 'message': data['message'] ?? ''};
        } catch (_) {}
      }
    } catch (e, s) {
      SourceLog.error('MePagePlugin($name).signin', '$e\n$s');
      return {'ok': false, 'message': '$e'};
    }
    return {'ok': false, 'message': ''};
  }

  /// 插件是否已登录
  bool get isLogged => data['logged'] == true;

  void setLogged(bool v) {
    data['logged'] = v;
    _saveData();
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// 今日已签日期；仅当“最后一次成功签到”是今天时返回，否则空串
  String get signedToday {
    if (data['signed'] == _today()) return _today();
    return '';
  }

  void markSignedToday() {
    data['signed'] = _today();
    _saveData();
  }

  /// 记住的登录凭证（供“重新登录”使用）
  Map<String, dynamic>? get creds {
    final raw = data['creds'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void setCreds({required String username, required String password}) {
    data['creds'] = {'username': username, 'password': password};
    _saveData();
  }

  void clearCreds() {
    data.remove('creds');
    _saveData();
  }

  /// 插件自定义配置项（uid 等）：存于本插件 `.data['configs']`
  Map<String, dynamic> get configs {
    final raw = data['configs'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  void setConfigValue(String key, String value) {
    final map = Map<String, dynamic>.from(configs);
    final v = value.trim();
    if (v.isEmpty) {
      map.remove(key);
    } else {
      map[key] = v;
    }
    data['configs'] = map;
    _saveData();
  }

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

  /// 是否声明了导航（nav），用于决定是否进入“插件导航壳”浏览。
  bool get hasNav {
    try {
      final res = JsEngine().runCode(
        "Array.isArray(globalThis.__me_plugins[${_jsStr(key)}]?.nav)",
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// 是否声明了自动签到：`plugin.autoSignin = true` 或提供了 `plugin.autoSignin()`。
  bool get autoSigninEnabled {
    try {
      final res = JsEngine().runCode(
        "typeof globalThis.__me_plugins[${_jsStr(key)}]?.autoSignin === 'function'"
        " || globalThis.__me_plugins[${_jsStr(key)}]?.autoSignin === true",
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// 执行自动签到：调用 `plugin.autoSignin()`，期望返回 `{ ok, message? }`。
  Future<Map<String, dynamic>> autoSignin() async {
    try {
      final res = await JsEngine().runCode("""
        (async () => {
          const fn = globalThis.__me_plugins[${_jsStr(key)}]?.autoSignin;
          if (typeof fn !== 'function') {
            return JSON.stringify({ ok: false, message: '' });
          }
          const r = await fn();
          return JSON.stringify({
            ok: !!(r && r.ok),
            message: (r && (r.message || r.error)) || ''
          });
        })()
      """);
      if (res is String) {
        try {
          final data = jsonDecode(res) as Map<String, dynamic>;
          return {'ok': data['ok'] == true, 'message': data['message'] ?? ''};
        } catch (_) {}
      }
    } catch (e, s) {
      SourceLog.error('MePagePlugin($name).autoSignin', '$e\n$s');
      return {'ok': false, 'message': '$e'};
    }
    return {'ok': false, 'message': ''};
  }

  /// 是否声明了登录能力：`plugin.login` 是 async 函数，签名
  /// `async login(username, password) => { ok, message? }`（与番源 account.login 对齐）
  bool get hasLogin {
    try {
      final res = JsEngine().runCode(
        "typeof globalThis.__me_plugins[${_jsStr(key)}]?.login === 'function'",
      );
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// 调用插件 login(username, password)，返回 { ok, message }。
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await JsEngine().runCode("""
        (async () => {
          const r = await globalThis.__me_plugins[${_jsStr(key)}].login(
            ${_jsStr(username)},
            ${_jsStr(password)}
          );
          return JSON.stringify({
            ok: !!(r && r.ok),
            message: (r && (r.message || r.error)) || ''
          });
        })()
      """);
      if (res is String) {
        try {
          final data = jsonDecode(res) as Map<String, dynamic>;
          return {'ok': data['ok'] == true, 'message': data['message'] ?? ''};
        } catch (_) {}
      }
    } catch (e, s) {
      SourceLog.error('MePagePlugin($name).login', '$e\n$s');
      return {'ok': false, 'message': '$e'};
    }
    return {'ok': false, 'message': ''};
  }

  /// 调用插件可选的 `logout()` 清理服务端/本地会话
  Future<void> logout() async {
    try {
      await JsEngine().runCode(
        "globalThis.__me_plugins[${_jsStr(key)}]?.logout?.()",
      );
    } catch (_) {}
  }

  /// 插件导航项列表：`[{key,title,icon}]`，icon 为 Dart 图标白名单字符串。
  Future<List<Map<String, dynamic>>> nav() async {
    try {
      final res = await JsEngine().runCode(
        "globalThis.__me_plugins[${_jsStr(key)}]?.nav ?? []",
      );
      if (res is List) {
        return res
            .map((e) => (e is Map)
                ? e.map((k, v) => MapEntry(k.toString(), v.toString()))
                : const <String, dynamic>{})
            .toList();
      }
    } catch (e, s) {
      SourceLog.error('MePagePlugin($name).nav', '$e\n$s');
    }
    return const [];
  }

  /// 子页面标题：优先取 nav 中对应 key 的 title，其次返回 key 本身。
  String titleOf(String pageName) {
    try {
      final res = JsEngine().runCode(
        "globalThis.__me_plugins[${_jsStr(key)}]?.nav"
        "?.find(n => n.key === ${_jsStr(pageName)})?.title",
      );
      if (res != null && res.toString().isNotEmpty) return res.toString();
    } catch (_) {}
    return pageName;
  }

  /// 调用插件 page(name, params)，返回该页模块列表。
  Future<List<dynamic>> page(
    String name, [
    Map<String, dynamic> params = const {},
  ]) async {
    try {
      final paramsJs = _jsJson(params);
      // 注入“今日已签”状态与自定义配置，供插件页直接读取（无需再次请求）
      await JsEngine().runCode(
        "globalThis.__me_plugin_signed_today = ${_jsStr(signedToday)};",
      );
      await JsEngine().runCode(
        "globalThis.__me_plugin_config = ${_jsJson(configs)};",
      );
      final res = await JsEngine().runCode(
        "globalThis.__me_plugins[${_jsStr(key)}]"
        "?.page(${_jsStr(name)}, $paramsJs) ?? []",
      );
      if (res is List) return res;
    } catch (e, s) {
      SourceLog.error('MePagePlugin($name).page($name)', '$e\n$s');
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

  MePagePlugin? _byKey(String key) {
    for (final p in _plugins) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// 插件是否启用（默认启用；存于各插件 .data）
  bool isEnabled(String key) => _byKey(key)?.isEnabled ?? true;

  /// 设置启用/禁用（写入该插件 .data）并通知
  Future<void> setEnabled(String key, bool enabled) async {
    _byKey(key)?.setEnabled(enabled);
    notifyListeners();
  }

  /// 已保存的登录凭证（供“重新登录”使用，与番源 account 存法对齐）
  Map<String, dynamic>? credsOf(String key) => _byKey(key)?.creds;

  Future<void> setCreds(
    String key, {
    required String username,
    required String password,
  }) async {
    _byKey(key)?.setCreds(username: username, password: password);
  }

  void clearCreds(String key) {
    _byKey(key)?.clearCreds();
  }

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

  /// 数据变更后的轻量通知（供界面按需刷新当前页）
  void touch() {
    notifyListeners();
  }

  /// 全局“启动时自动签到”总开关（默认开）
  bool get autoSigninMaster =>
      appdata.implicitData['meAutoSignin'] != false;

  /// 自动签到候选：启用 + 在自动名单 + 已登录 + 有签到入口 + 今天还没签
  List<MePagePlugin> autoCandidates() {
    return all().where((p) {
      return isEnabled(p.key) &&
          p.isAutoSign &&
          p.isLogged &&
          p.signinAvailable &&
          p.signedToday.isEmpty;
    }).toList();
  }

  /// 执行单个插件签到并记录结果（成功标记今日已签；写入 lastSign 供卡片展示）
  Future<Map<String, dynamic>> runSignin(MePagePlugin p) async {
    try {
      final res = await p.signin();
      final ok = res['ok'] == true;
      p.data['lastSign'] = {
        'ok': ok,
        'message': res['message'] ?? '',
        'time': DateTime.now().toIso8601String(),
      };
      p._saveData();
      if (ok) p.markSignedToday();
      return {'key': p.key, 'name': p.name, 'ok': ok, 'message': res['message'] ?? ''};
    } catch (e, s) {
      SourceLog.error('MePagePlugin.runSignin', '${p.name}: $e\n$s');
      p.data['lastSign'] = {'ok': false, 'message': '$e', 'time': DateTime.now().toIso8601String()};
      p._saveData();
      return {'key': p.key, 'name': p.name, 'ok': false, 'message': '$e'};
    }
  }

  /// 集体签到：默认签 autoCandidates；可跳过（不签）未登录/不在名单/已签。
  /// 返回逐条结果列表。
  Future<List<Map<String, dynamic>>> runCollectiveSignin() async {
    await ensureInit();
    final results = <Map<String, dynamic>>[];
    for (final p in autoCandidates()) {
      results.add(await runSignin(p));
    }
    notifyListeners();
    return results;
  }

  /// App 启动后自动签到（受总开关与每插件自动名单约束；不重复签今日已签者）
  Future<void> autoSigninAtStart() async {
    try {
      await ensureInit();
    } catch (_) {}
    if (!autoSigninMaster) return;
    for (final p in autoCandidates()) {
      final r = await runSignin(p);
      if (!r['ok']) {
        SourceLog.warning('MePagePlugin.autoSignin', '${p.name}: ${r['message']}');
      }
    }
  }

  /// 从插件源地址拉取插件列表并安装。
  ///
  /// 源地址返回 JSON 数组，形如：
  /// ```json
  /// [{ "name": "girigirilove", "fileName": "girigirilove.js", "key": "girigirilove", "version": "1.1.6" }]
  /// ```
  /// 每项无 url 字段，JS 下载地址 = 源地址所在目录 + fileName。
  /// 逐个下载 JS 到 plugins 目录后重载。返回安装数量。
  Future<int> fetchFromUrl(String url) async {
    var dio = AppDio();
    final list = await dio.get<List<dynamic>>(
      url,
      options: Options(method: 'GET', receiveTimeout: const Duration(seconds: 30)),
    );
    final items = list.data;
    if (items is! List) return 0;

    final baseUrl = _baseDirOf(url);

    final dir = Directory('${App.dataPath}/$mePluginsDirName');
    if (!await dir.exists()) {
      await dir.create();
    }

    int installed = 0;
    for (final raw in items) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString().trim() ?? '';
      final key = raw['key']?.toString().trim() ?? '';
      var fileName = raw['fileName']?.toString().trim() ?? '';
      if (fileName.isEmpty) fileName = '$key.js';
      // 文件名白名单 + 去路径，避免路径注入
      final safe = fileName.split('/').last;
      if (!RegExp(r'^[A-Za-z0-9_\-]+\.js$').hasMatch(safe)) continue;
      final jsUrl = '$baseUrl$safe';
      try {
        final jsRes = await dio.get<String>(
          jsUrl,
          options: Options(
            method: 'GET',
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
        if (jsRes.statusCode != 200) continue;
        final file = File('${dir.path}/$safe');
        await file.writeAsString(jsRes.data ?? '');
        installed++;
      } catch (e, s) {
        SourceLog.error('MePagePlugin', '下载插件 $name 失败: $e\n$s');
      }
    }
    await reload();
    return installed;
  }

  /// 源地址去掉末尾文件名与查询串，得到目录部分。
  /// 如 `https://x/plugins/index.json` → `https://x/plugins/`
  static String _baseDirOf(String url) {
    final clean = url.split('?').first.split('#').first;
    final idx = clean.lastIndexOf('/');
    if (idx < 0) return '$clean/';
    return clean.substring(0, idx + 1);
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
    final referer = JsEngine()
            .runCode("globalThis.__me_plugins[${_jsStr(key)}]?.referer")
            ?.toString() ??
        '';

    // 各插件独立 `.data`（对齐番剧源）；无文件时从旧 implicitData 迁移一次
    Map<String, dynamic> initialData = const {};
    final dataPath = filePath.endsWith('.js')
        ? '${filePath.substring(0, filePath.length - 3)}.data'
        : '$filePath.data';
    try {
      if (File(dataPath).existsSync()) {
        final raw = jsonDecode(await File(dataPath).readAsString());
        if (raw is Map) {
          initialData = raw.map((k, v) => MapEntry(k.toString(), v));
        }
      } else {
        bool? enabled;
        bool? logged;
        String? signed;
        Map<String, dynamic>? creds;
        final enabledMap = appdata.implicitData['mePluginEnabled'];
        if (enabledMap is Map && enabledMap[key] is bool) {
          enabled = enabledMap[key] as bool;
        }
        final loggedMap = appdata.implicitData['mePluginLogged'];
        if (loggedMap is Map && loggedMap[key] == true) logged = true;
        final signedMap = appdata.implicitData['mePluginSigned'];
        if (signedMap is Map && signedMap[key] is String) {
          signed = signedMap[key] as String;
        }
        final credsMap = appdata.implicitData['mePluginCreds'];
        if (credsMap is Map && credsMap[key] is Map) {
          final rawCreds = credsMap[key] as Map;
          creds = rawCreds.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        initialData = {
          if (enabled != null) 'enabled': enabled,
          if (logged != null) 'logged': logged,
          if (signed != null) 'signed': signed,
          if (creds != null) 'creds': creds,
        };
      }
    } catch (_) {}

    return MePagePlugin(
      name: name.toString(),
      key: key,
      version: version,
      description: description,
      filePath: filePath,
      referer: referer.isEmpty ? null : referer,
      initialData: initialData,
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
  if (o is String) {
    try {
      final d = jsonDecode(o);
      if (d is Map) {
        return d.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
  }
  return {};
}
