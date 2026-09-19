import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:charset/charset.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter/services.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:kostori/components/js_ui.dart';
import 'package:kostori/foundation/anime_source/anime_source.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/js_pool.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/webview_resolver.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/cookie_jar.dart';
import 'package:kostori/network/proxy.dart';
import 'package:kostori/utils/init.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/block/modes/cfb.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/block/modes/ofb.dart';
import 'package:uuid/uuid.dart';

class JavaScriptRuntimeException implements Exception {
  final String message;

  JavaScriptRuntimeException(this.message);

  @override
  String toString() {
    return "JSException: $message";
  }
}

class JsEngine with _JSEngineApi, JsUiApi, Init {
  factory JsEngine() => _cache ?? (_cache = JsEngine._create());

  static JsEngine? _cache;

  JsEngine._create();

  FlutterQjs? _engine;

  bool _closed = true;

  Dio? _dio;

  static void reset() {
    _cache = null;
    _cache?.dispose();
    JsEngine().init();
  }

  void resetDio() {
    _dio = AppDio(
      BaseOptions(
        responseType: ResponseType.plain,
        validateStatus: (status) => true,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 8),
      ),
    );
  }

  static Uint8List? _jsInitCache;

  static void cacheJsInit(Uint8List jsInit) {
    _jsInitCache = jsInit;
  }

  @override
  @protected
  Future<void> doInit() async {
    if (!_closed) {
      return;
    }
    try {
      if (App.isInitialized) {
        _cookieJar ??= await SingleInstanceCookieJar.createInstance();
      }
      _dio ??= AppDio(
        BaseOptions(
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 8),
        ),
      );

      _closed = false;
      // timeout：JS 同步执行超时（CPU 时间，毫秒）后由 QuickJS 中断，防止死循环冻结 UI
      _engine = FlutterQjs(timeout: 30000);
      _engine!.dispatch();
      var setGlobalFunc = _engine!.evaluate(
        "(key, value) => { this[key] = value; }",
      );
      (setGlobalFunc as JSInvokable)(["sendMessage", _messageReceiver]);
      setGlobalFunc(["appVersion", App.version]);
      setGlobalFunc.free();
      Uint8List jsInit;
      if (_jsInitCache != null) {
        jsInit = _jsInitCache!;
      } else {
        var buffer = await rootBundle.load("assets/init.js");
        jsInit = buffer.buffer.asUint8List();
      }
      _engine!.evaluate(utf8.decode(jsInit), name: "<init>");
    } catch (e, s) {
      SourceLog.error('JS Engine', 'JS Engine Init Error:\n$e\n$s');
    }
  }

  Object? _messageReceiver(dynamic message) {
    try {
      if (message is Map<dynamic, dynamic>) {
        if (message["method"] == null) return null;
        String method = message["method"] as String;
        switch (method) {
          case "log":
            String level = message["level"];
            SourceLog.log(
              switch (level) {
                "error" => LogLevel.error,
                "warning" => LogLevel.warning,
                "info" => LogLevel.info,
                _ => LogLevel.warning,
              },
              message["title"],
              message["content"].toString(),
            );
          case 'load_data':
            String key = message["key"];
            String dataKey = message["data_key"];
            return AnimeSource.find(key)?.data[dataKey];
          case 'save_data':
            String key = message["key"];
            String dataKey = message["data_key"];
            if (dataKey == 'setting') {
              throw "setting is not allowed to be saved";
            }
            var data = message["data"];
            var source = AnimeSource.find(key)!;
            source.data[dataKey] = data;
            source.saveData();
          case 'delete_data':
            String key = message["key"];
            String dataKey = message["data_key"];
            var source = AnimeSource.find(key);
            source?.data.remove(dataKey);
            source?.saveData();
          case 'http':
            return _http(Map.from(message));
          case 'webview':
            return _handleWebView(Map.from(message));
          case 'html':
            return handleHtmlCallback(Map.from(message));
          case 'convert':
            return _convert(Map.from(message));
          case "random":
            return _random(
              message["min"] ?? 0,
              message["max"] ?? 1,
              message["type"],
            );
          case "cookie":
            return handleCookieCallback(Map.from(message));
          case "uuid":
            return const Uuid().v1();
          case 'load_setting':
            String key = message["key"];
            String settingKey = message["setting_key"];
            var source = AnimeSource.find(key);
            if (source == null) {
              try {
                return JsEngine().runCode(
                  "this['temp']?.settings?.$settingKey?.default ?? null",
                );
              } catch (_) {
                return null;
              }
            }
            return source.data["settings"]?[settingKey] ??
                source.settings?[settingKey]!['default'] ??
                (throw "Setting not found: $settingKey");
          case "isLogged":
            return AnimeSource.find(message["key"])!.isLogged;
          // [setTimeout] 的临时替代实现（QuickJS 里暂不支持定时器）
          case "delay":
            return Future.delayed(Duration(milliseconds: message["time"]));
          case "UI":
            return handleUIMessage(Map.from(message));
          case "getLocale":
            return "${App.locale.languageCode}_${App.locale.countryCode}";
          case "getPlatform":
            return Platform.operatingSystem;
          case "setClipboard":
            return Clipboard.setData(ClipboardData(text: message["text"]));
          case "getClipboard":
            return Future.sync(() async {
              var res = await Clipboard.getData(Clipboard.kTextPlain);
              return res?.text;
            });
          case "compute":
            final func = message["function"];
            final args = message["args"];
            if (func is JSInvokable) {
              func.free();
              throw "Function must be a string";
            }
            if (func is! String) {
              throw "Function must be a string";
            }
            if (args != null && args is! List) {
              throw "Args must be a list";
            }
            return JSPool().execute(func, args ?? []);
        }
      }
      return null;
    } catch (e, s) {
      SourceLog.error("JsEngine", "Failed to handle message: $message\n$e\n$s");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _http(Map<String, dynamic> req) async {
    Response? response;
    String? error;

    try {
      var headers = Map<String, dynamic>.from(req["headers"] ?? {});
      if (headers["user-agent"] == null && headers["User-Agent"] == null) {
        headers["User-Agent"] = webUA;
      }
      var dio = _dio;
      if (headers['http_client'] == "dart:io") {
        dio = Dio(
          BaseOptions(
            responseType: ResponseType.plain,
            validateStatus: (status) => true,
          ),
        );
        var proxy = await getProxy();
        dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            return HttpClient()
              ..findProxy = (uri) => proxy == null ? "DIRECT" : "PROXY $proxy";
          },
        );
        dio.interceptors.add(CookieManagerSql());
        dio.interceptors.add(LogInterceptor());
      }
      response = await dio!.request(
        req["url"],
        data: req["data"],
        options: Options(
          method: req['http_method'],
          responseType: req["bytes"] == true
              ? ResponseType.bytes
              : ResponseType.plain,
          headers: headers,
        ),
      );
    } catch (e) {
      error = e.toString();
    }

    Map<String, String> headers = {};

    response?.headers.forEach(
      (name, values) => headers[name] = values.join(','),
    );

    dynamic body = response?.data;
    if (body is! Uint8List && body is List<int>) {
      body = Uint8List.fromList(body);
    }

    return {
      "status": response?.statusCode,
      "headers": headers,
      "body": body,
      "error": error,
      "url": _finalResponseUrl(response),
    };
  }

  /// 响应最终 URL（含重定向后的地址），供源脚本据此判断实际服务端域名
  String? _finalResponseUrl(Response? response) {
    if (response == null) return null;
    if (response.redirects.isNotEmpty) {
      return response.redirects.last.location.toString();
    }
    return response.requestOptions.uri.toString();
  }

  dynamic runCode(String js, [String? name]) {
    return _engine!.evaluate(js, name: name);
  }

  void dispose() {
    _cache = null;
    _closed = true;
    _engine?.close();
    _engine?.port.close();
  }
}

mixin class _JSEngineApi {
  CookieJarSql? _cookieJar;

  final _documents = <int, DocumentWrapper>{};

  Object? handleHtmlCallback(Map<String, dynamic> data) {
    switch (data["function"]) {
      case "parse":
        if (_documents.length > 8) {
          var shouldDelete = _documents.keys.first;
          SourceLog.warning(
            "JS Engine",
            "Too many documents, deleting the oldest: $shouldDelete\n"
                "Current documents: ${_documents.keys}",
          );
          _documents.remove(shouldDelete);
        }
        _documents[data["key"]] = DocumentWrapper.parse(data["data"]);
        return null;
      case "querySelector":
        var key = data["key"];
        return _documents[key]!.querySelector(data["query"]);
      case "querySelectorAll":
        var key = data["key"];
        return _documents[key]!.querySelectorAll(data["query"]);
      case "getText":
        return _documents[data["doc"]]!.elementGetText(data["key"]);
      case "getAttributes":
        var res = _documents[data["doc"]]!.elementGetAttributes(data["key"]);
        return res;
      case "dom_querySelector":
        var doc = _documents[data["doc"]]!;
        return doc.elementQuerySelector(data["key"], data["query"]);
      case "dom_querySelectorAll":
        var doc = _documents[data["doc"]]!;
        return doc.elementQuerySelectorAll(data["key"], data["query"]);
      case "getChildren":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetChildren(data["key"]);
      case "getNodes":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetNodes(data["key"]);
      case "getInnerHTML":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetInnerHTML(data["key"]);
      case "getParent":
        var doc = _documents[data["doc"]]!;
        return doc.elementGetParent(data["key"]);
      case "node_text":
        return _documents[data["doc"]]!.nodeGetText(data["key"]);
      case "node_type":
        return _documents[data["doc"]]!.nodeType(data["key"]);
      case "node_to_element":
        return _documents[data["doc"]]!.nodeToElement(data["key"]);
      case "dispose":
        var docKey = data["key"];
        _documents.remove(docKey);
        return null;
      case "getClassNames":
        return _documents[data["doc"]]!.getClassNames(data["key"]);
      case "getId":
        return _documents[data["doc"]]!.getId(data["key"]);
      case "getLocalName":
        return _documents[data["doc"]]!.getLocalName(data["key"]);
      case "getElementById":
        return _documents[data["key"]]!.getElementById(data["id"]);
      case "getPreviousSibling":
        return _documents[data["doc"]]!.getPreviousSibling(data["key"]);
      case "getNextSibling":
        return _documents[data["doc"]]!.getNextSibling(data["key"]);
    }
    return null;
  }

  Future<dynamic> handleCookieCallback(Map<String, dynamic> data) async {
    switch (data["function"]) {
      case "set":
        await _cookieJar!.saveFromResponse(
          Uri.parse(data["url"]),
          (data["cookies"] as List).map((e) {
            var c = Cookie(e["name"], e["value"]);
            if (e['domain'] != null) c.domain = e['domain'];
            return c;
          }).toList(),
        );
        return null;
      case "get":
        var cookies = await _cookieJar!.loadForRequest(Uri.parse(data["url"]));
        return cookies
            .map(
              (e) => {
                "name": e.name,
                "value": e.value,
                "domain": e.domain,
                "path": e.path,
                "expires": e.expires,
                "max-age": e.maxAge,
                "secure": e.secure,
                "httpOnly": e.httpOnly,
                "session": e.expires == null,
              },
            )
            .toList();
      case "delete":
        clearCookies([data["url"]]);
        return null;
    }
  }

  Future<dynamic> _handleWebView(Map<String, dynamic> data) async {
    final action = data["action"];
    if (action == 'extract') {
      final url = data["url"]?.toString() ?? '';
      // waitMs 上限钳制，避免插件/源传入超大值导致 WebView 长时间挂起
      final waitMs = (data["waitMs"] is int ? data["waitMs"] as int : 8000)
          .clamp(1000, 60000);
      final scan = data["scan"] is bool ? data["scan"] as bool : true;
      final script = data["script"]?.toString();
      Map<String, String>? headers;
      final rawHeaders = data['headers'];
      if (rawHeaders is Map) {
        headers = rawHeaders.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      try {
        return await WebViewResolver.fetchViaWebView(
          url,
          headers: headers,
          script: script,
          waitMs: waitMs,
          scan: scan,
        );
      } catch (e) {
        SourceLog.error("WebViewResolver", e.toString());
        return <dynamic>[];
      }
    }
    if (action == 'html') {
      final url = data["url"]?.toString() ?? '';
      final waitMs = (data["waitMs"] is int ? data["waitMs"] as int : 10000)
          .clamp(1000, 60000);
      Map<String, String>? headers;
      final rawHeaders = data['headers'];
      if (rawHeaders is Map) {
        headers = rawHeaders.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      try {
        return await WebViewResolver.fetchHtml(
          url,
          headers: headers,
          waitMs: waitMs,
        );
      } catch (e) {
        SourceLog.error("WebViewResolver", e.toString());
        return null;
      }
    }
    return null;
  }

  void clearCookies(List<String> domains) async {
    for (var domain in domains) {
      var uri = Uri.tryParse(domain);
      if (uri == null) continue;
      _cookieJar!.deleteUri(uri);
    }
  }

  Object? _convert(Map<String, dynamic> data) {
    String type = data["type"];
    var value = data["value"];
    bool isEncode = data["isEncode"];
    try {
      switch (type) {
        case "utf8":
          return isEncode ? utf8.encode(value) : utf8.decode(value);
        case "charset":
          // 按指定字符集解码字节（如 euc-jp / gbk / shift-jis）
          final name = data["charset"]?.toString() ?? 'utf-8';
          final encoding = Charset.getByName(name) ?? utf8;
          if (isEncode) return encoding.encode('$value');
          final bytes = jsBytesOf(value);
          if (bytes == null) {
            throw "decode 需要字节数组（Uint8Array/ArrayBuffer），"
                "收到 ${value.runtimeType}";
          }
          return encoding.decode(bytes);
        case "base64":
          if (!isEncode) {
            final text = value is String ? value : '$value';
            if (text.isEmpty) throw "decodeBase64 需要 base64 字符串";
            return base64Decode(text);
          }
          // 源侧常传 Uint8Array/ArrayBuffer：桥接过来可能是 List，也可能是
          // 形如 {0:,1:,…} 的 Map，这里都接受；字符串按 UTF-8 编码
          final bytes = jsBytesOf(value);
          if (bytes != null) return base64Encode(bytes);
          if (value is String) return base64Encode(utf8.encode(value));
          throw "encodeBase64 需要字节数组（Uint8Array/ArrayBuffer），"
              "收到 ${value.runtimeType}";
        case "md5":
          return Uint8List.fromList(md5.convert(_hashInput(value)).bytes);
        case "sha1":
          return Uint8List.fromList(sha1.convert(_hashInput(value)).bytes);
        case "sha256":
          return Uint8List.fromList(sha256.convert(_hashInput(value)).bytes);
        case "sha512":
          return Uint8List.fromList(sha512.convert(_hashInput(value)).bytes);
        case "hmac":
          var key = jsBytesOf(data["key"]) ?? utf8.encode('${data["key"]}');
          var hash = data["hash"];
          var hmac = Hmac(switch (hash) {
            "md5" => md5,
            "sha1" => sha1,
            "sha256" => sha256,
            "sha512" => sha512,
            _ => throw "Unsupported hash: $hash",
          }, key);
          if (data['isString'] == true) {
            return hmac.convert(_hashInput(value)).toString();
          } else {
            return Uint8List.fromList(hmac.convert(_hashInput(value)).bytes);
          }
        case "aes-ecb":
          if (!isEncode) {
            final key = _requireBytes(data["key"], 'aes-ecb key');
            final input = _requireBytes(value, 'aes-ecb data');
            // isolate: true → 放到后台线程算（源侧需 await），不占用 UI 线程
            final background = _aesMaybeIsolate(
              data,
              input,
              () => aesDecryptBytes(mode: 'aes-ecb', data: input, key: key),
            );
            if (background != null) return background;
            var cipher = ECBBlockCipher(AESEngine());
            cipher.init(false, KeyParameter(key));
            var offset = 0;
            var result = Uint8List(input.length);
            while (offset < input.length) {
              offset += cipher.processBlock(input, offset, result, offset);
            }
            return result;
          }
          return null;
        case "aes-cbc":
          if (!isEncode) {
            final key = _requireBytes(data["key"], 'aes-cbc key');
            final iv = _requireBytes(data["iv"], 'aes-cbc iv');
            final input = _requireBytes(value, 'aes-cbc data');
            final background = _aesMaybeIsolate(
              data,
              input,
              () => aesDecryptBytes(
                mode: 'aes-cbc',
                data: input,
                key: key,
                iv: iv,
              ),
            );
            if (background != null) return background;
            var cipher = CBCBlockCipher(AESEngine());
            cipher.init(false, ParametersWithIV(KeyParameter(key), iv));
            var offset = 0;
            var result = Uint8List(input.length);
            while (offset < input.length) {
              offset += cipher.processBlock(input, offset, result, offset);
            }
            return result;
          }
          return null;
        case "aes-cfb":
          if (!isEncode) {
            final key = _requireBytes(data["key"], 'aes-cfb key');
            final input = _requireBytes(value, 'aes-cfb data');
            var blockSize = data["blockSize"];
            final background = _aesMaybeIsolate(
              data,
              input,
              () => aesDecryptBytes(
                mode: 'aes-cfb',
                data: input,
                key: key,
                blockSize: blockSize,
              ),
            );
            if (background != null) return background;
            var cipher = CFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            var offset = 0;
            var result = Uint8List(input.length);
            while (offset < input.length) {
              offset += cipher.processBlock(input, offset, result, offset);
            }
            return result;
          }
          return null;
        case "aes-ofb":
          if (!isEncode) {
            final key = _requireBytes(data["key"], 'aes-ofb key');
            final input = _requireBytes(value, 'aes-ofb data');
            var blockSize = data["blockSize"];
            final background = _aesMaybeIsolate(
              data,
              input,
              () => aesDecryptBytes(
                mode: 'aes-ofb',
                data: input,
                key: key,
                blockSize: blockSize,
              ),
            );
            if (background != null) return background;
            var cipher = OFBBlockCipher(AESEngine(), blockSize);
            cipher.init(false, KeyParameter(key));
            var offset = 0;
            var result = Uint8List(input.length);
            while (offset < input.length) {
              offset += cipher.processBlock(input, offset, result, offset);
            }
            return result;
          }
          return null;
        case "rsa":
          if (!isEncode) {
            var key = data["key"];
            final cipher = PKCS1Encoding(RSAEngine());
            cipher.init(
              false,
              PrivateKeyParameter<RSAPrivateKey>(_parsePrivateKey(key)),
            );
            return _processInBlocks(cipher, _requireBytes(value, 'rsa data'));
          }
          return null;
        default:
          return value;
      }
    } catch (e, s) {
      SourceLog.error("JS Engine", "Failed to convert $type: $e", s);
      return null;
    }
  }

  RSAPrivateKey _parsePrivateKey(String privateKeyString) {
    List<int> privateKeyDER = base64Decode(privateKeyString);
    var asn1Parser = ASN1Parser(privateKeyDER as Uint8List);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;
    final privateKey = topLevelSeq.elements![2];

    asn1Parser = ASN1Parser(privateKey.valueBytes!);
    final pkSeq = asn1Parser.nextObject() as ASN1Sequence;

    final modulus = pkSeq.elements![1] as ASN1Integer;
    final privateExponent = pkSeq.elements![3] as ASN1Integer;
    final p = pkSeq.elements![4] as ASN1Integer;
    final q = pkSeq.elements![5] as ASN1Integer;

    return RSAPrivateKey(
      modulus.integer!,
      privateExponent.integer!,
      p.integer!,
      q.integer!,
    );
  }

  Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final numBlocks =
        input.length ~/ engine.inputBlockSize +
        ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

    final output = Uint8List(numBlocks * engine.outputBlockSize);

    var inputOffset = 0;
    var outputOffset = 0;
    while (inputOffset < input.length) {
      final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
          ? engine.inputBlockSize
          : input.length - inputOffset;

      outputOffset += engine.processBlock(
        input,
        inputOffset,
        chunkSize,
        output,
        outputOffset,
      );

      inputOffset += chunkSize;
    }

    return (output.length == outputOffset)
        ? output
        : output.sublist(0, outputOffset);
  }

  num _random(num min, num max, String type) {
    if (type == "double") {
      return min + (max - min) * math.Random().nextDouble();
    }
    return (min + (max - min) * math.Random().nextDouble()).toInt();
  }
}

class DocumentWrapper {
  final dom.Document doc;

  DocumentWrapper.parse(String doc) : doc = html.parse(doc);

  var elements = <dom.Element>[];

  var nodes = <dom.Node>[];

  int? querySelector(String query) {
    var element = doc.querySelector(query);
    if (element == null) return null;
    elements.add(element);
    return elements.length - 1;
  }

  List<int> querySelectorAll(String query) {
    var res = doc.querySelectorAll(query);
    var keys = <int>[];
    for (var element in res) {
      elements.add(element);
      keys.add(elements.length - 1);
    }
    return keys;
  }

  String? elementGetText(int key) {
    return elements[key].text;
  }

  Map<String, String> elementGetAttributes(int key) {
    return elements[key].attributes.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  String? elementGetInnerHTML(int key) {
    return elements[key].innerHtml;
  }

  int? elementGetParent(int key) {
    var res = elements[key].parent;
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }

  int? elementQuerySelector(int key, String query) {
    var res = elements[key].querySelector(query);
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }

  List<int> elementQuerySelectorAll(int key, String query) {
    var res = elements[key].querySelectorAll(query);
    var keys = <int>[];
    for (var element in res) {
      elements.add(element);
      keys.add(elements.length - 1);
    }
    return keys;
  }

  List<int> elementGetChildren(int key) {
    var res = elements[key].children;
    var keys = <int>[];
    for (var element in res) {
      elements.add(element);
      keys.add(elements.length - 1);
    }
    return keys;
  }

  List<int> elementGetNodes(int key) {
    var res = elements[key].nodes;
    var keys = <int>[];
    for (var node in res) {
      nodes.add(node);
      keys.add(nodes.length - 1);
    }
    return keys;
  }

  String? nodeGetText(int key) {
    return nodes[key].text;
  }

  String nodeType(int key) {
    return switch (nodes[key].nodeType) {
      dom.Node.ELEMENT_NODE => "element",
      dom.Node.TEXT_NODE => "text",
      dom.Node.COMMENT_NODE => "comment",
      dom.Node.DOCUMENT_NODE => "document",
      _ => "unknown",
    };
  }

  int? nodeToElement(int key) {
    if (nodes[key] is dom.Element) {
      elements.add(nodes[key] as dom.Element);
      return elements.length - 1;
    }
    return null;
  }

  List<String> getClassNames(int key) {
    return (elements[key]).classes.toList();
  }

  String? getId(int key) {
    return (elements[key]).id;
  }

  String? getLocalName(int key) {
    return (elements[key]).localName;
  }

  int? getElementById(String id) {
    var element = doc.getElementById(id);
    if (element == null) return null;
    elements.add(element);
    return elements.length - 1;
  }

  int? getPreviousSibling(int key) {
    var res = elements[key].previousElementSibling;
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }

  int? getNextSibling(int key) {
    var res = elements[key].nextElementSibling;
    if (res == null) return null;
    elements.add(res);
    return elements.length - 1;
  }
}

class JSAutoFreeFunction {
  final JSInvokable func;

  /// Automatically free the function when it's not used anymore
  JSAutoFreeFunction(this.func) {
    func.dup();
    finalizer.attach(this, func);
  }

  dynamic call(List<dynamic> args) {
    return func(args);
  }

  static final finalizer = Finalizer<JSInvokable>((func) {
    func.destroy();
  });
}

/// 把 JS 传过来的值尽量转成字节数组。
///
/// flutter_qjs 对 `Uint8Array` / `ArrayBuffer` 的桥接结果可能是 `List`，
/// 也可能是形如 `{0: 1, 1: 2, ...}` 的 `Map`，这里统一归一化；
/// 非字节数据返回 null（由调用方给出更清楚的报错）。
Uint8List? jsBytesOf(Object? value) {
  if (value is Uint8List) return value;
  if (value is List) {
    final out = Uint8List(value.length);
    for (var i = 0; i < value.length; i++) {
      final e = value[i];
      if (e is! num) return null;
      out[i] = e.toInt() & 0xff;
    }
    return out;
  }
  if (value is Map) {
    // 只认「下标 → 字节」的键（忽略 byteLength 之类的附加字段）
    final numeric = <int, int>{};
    value.forEach((k, v) {
      final i = int.tryParse(k.toString());
      if (i == null || i < 0 || v is! num) return;
      numeric[i] = v.toInt() & 0xff;
    });
    if (numeric.isEmpty) return null;
    final length = numeric.keys.reduce((a, b) => a > b ? a : b) + 1;
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      final e = numeric[i];
      if (e == null) return null; // 下标不连续 → 不是字节数组
      out[i] = e;
    }
    return out;
  }
  return null;
}

/// 哈希类 convert 的输入：字节数组，或（兼容）字符串按 UTF-8
List<int> _hashInput(Object? value) =>
    jsBytesOf(value) ?? utf8.encode('$value');

/// 必须拿到字节数组（AES/RSA 等），否则给出清楚的报错
Uint8List _requireBytes(Object? value, String what) =>
    jsBytesOf(value) ??
    (throw "$what 需要字节数组（Uint8Array/ArrayBuffer），收到 ${value.runtimeType}");

/// 小于该体积的 AES 直接在本地算：isolate 的启动 + 数据拷贝开销
/// 比解密本身还大（Android 上 spawn 一次约 10ms）。
const int _kAesIsolateBytes = 64 * 1024;

/// `isolate: true` 的 AES：大图放后台 isolate，小数据原地算。
///
/// 两种情况都返回 Future（保持 JS 侧 `await Convert.xxxAsync()` 的 Promise 语义）；
/// 返回 null 表示源没用 isolate，调用方继续走同步实现。
Future<Uint8List>? _aesMaybeIsolate(
  Map<String, dynamic> data,
  Uint8List input,
  Uint8List Function() compute,
) {
  if (data["isolate"] != true) return null;
  if (input.length < _kAesIsolateBytes) return Future.value(compute());
  return Isolate.run(compute);
}

/// AES 解密（纯计算，可安全地放到后台 isolate 执行）。
///
/// [mode] 取 `aes-ecb` / `aes-cbc` / `aes-cfb` / `aes-ofb`；
/// cbc 需要 [iv]，cfb/ofb 需要 [blockSize]。
Uint8List aesDecryptBytes({
  required String mode,
  required Uint8List data,
  required Uint8List key,
  Uint8List? iv,
  int? blockSize,
}) {
  final engine = AESEngine();
  final BlockCipher cipher = switch (mode) {
    'aes-ecb' => ECBBlockCipher(engine),
    'aes-cbc' => CBCBlockCipher(engine),
    'aes-cfb' => CFBBlockCipher(engine, blockSize ?? 8),
    'aes-ofb' => OFBBlockCipher(engine, blockSize ?? 8),
    _ => throw ArgumentError('Unsupported AES mode: $mode'),
  };
  cipher.init(
    false,
    iv != null
        ? ParametersWithIV(KeyParameter(key), iv)
        : KeyParameter(key),
  );
  final out = Uint8List(data.length);
  var offset = 0;
  while (offset < data.length) {
    offset += cipher.processBlock(data, offset, out, offset);
  }
  return out;
}
