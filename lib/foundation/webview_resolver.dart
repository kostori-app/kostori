import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/foundation/main_isolate_runner.dart';

/// 通过 WebView 加载页面并提取数据。
///
/// 工作方式：`HeadlessInAppWebView` 静默加载（各平台均不弹窗），
/// 注入脚本（可自定义 [script]）与桥（`__kostoriReport`）把数据上报到 Dart 侧，
/// 同时拦截 `.m3u8` 资源（hls_native）。
class WebViewResolver {
  WebViewResolver._();

  /// 复用的 WebView2 环境（Windows 需要：其创建过程会初始化 COM，
  /// 否则直接建 HeadlessInAppWebView 会报 "尚未调用 CoInitialize"）
  static WebViewEnvironment? _environment;

  static Future<WebViewEnvironment?> _ensureEnvironment() async {
    return _environment ??= await WebViewEnvironment.create();
  }

  /// 提取入口：加载 [url] 并等待脚本执行，返回上报结果列表。
  /// [scan] 为 false 时不注入视频扫描 JS 钩子（fetch/XHR/Response.text），
  /// 仅保留桥与原生 onLoadResource 拦截，避免干扰 Cloudflare 挑战页。
  /// 注意：Windows 的 WebView2 必须在主线程创建，本方法在后台 isolate
  /// 被调用时会通过 [MainIsolateRunner] 切回主 isolate 执行。
  static Future<List<dynamic>> fetchViaWebView(
    String url, {
    Map<String, String>? headers,
    String? script,
    int waitMs = 8000,
    bool scan = true,
  }) async {
    if (!MainIsolateRunner.isMainIsolate) {
      final result = await MainIsolateRunner.run('webview', {
        'url': url,
        'headers': headers,
        'script': script,
        'waitMs': waitMs,
        'scan': scan,
      });
      return (result as List?)?.cast<dynamic>() ?? [];
    }
    try {
      return await _extractHeadless(
        url,
        headers: headers,
        script: script,
        waitMs: waitMs,
        scan: scan,
      );
    } catch (e, s) {
      SourceLog.error('WebViewResolver', '$e\n$s');
    }
    return [];
  }

  /// 主 isolate 上注册 webview 任务处理器（应用启动时调用）
  static void registerMainIsolateHandler() {
    MainIsolateRunner.registerHandler('webview', (payload) async {
      final args = payload as Map;
      return fetchViaWebView(
        args['url'] as String,
        headers: (args['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
        script: args['script'] as String?,
        waitMs: args['waitMs'] as int? ?? 8000,
        scan: args['scan'] as bool? ?? true,
      );
    });
  }

  /// 无头 WebView 提取（所有平台静默加载，不显示窗口）。
  static Future<List<dynamic>> _extractHeadless(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
    required bool scan,
  }) async {
    final results = <dynamic>[];
    final completer = Completer<List<dynamic>>();
    Timer? completionTimer;
    InAppWebViewController? webViewController;
    // Cloudflare 挑战进行中（识别到 cf 标记时不结束等待，给挑战重载留时间）
    bool sawCf = false;

    final ua =
        headers?['User-Agent'] ??
        headers?['user-agent'] ??
        (Platform.isAndroid || Platform.isIOS ? _mobileUA : _desktopUA);

    // Windows 需要先创建 WebView2 环境（初始化 COM）
    final environment = Platform.isWindows ? await _ensureEnvironment() : null;

    void scheduleComplete() {
      completionTimer?.cancel();
      if (sawCf) {
        // CF 挑战页：每 2s 轮询，等待挑战完成后的自动重载；外层 timeout 兜底
        completionTimer = Timer(const Duration(seconds: 2), () {
          if (!completer.isCompleted) scheduleComplete();
        });
        return;
      }
      // 重定向会多次触发 load stop，每次都重置计时，以最后一次为准
      completionTimer = Timer(Duration(milliseconds: waitMs), () {
        if (!completer.isCompleted) completer.complete(results);
      });
    }

    final webView = HeadlessInAppWebView(
      webViewEnvironment: environment,
      initialUrlRequest: URLRequest(url: WebUri(url), headers: headers),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        blockNetworkImage: true,
        userAgent: ua,
        useOnLoadResource: true,
      ),
      initialUserScripts: UnmodifiableListView(
        _buildUserScripts(headers, script, scan: scan),
      ),
      onWebViewCreated: (controller) {
        webViewController = controller;
        controller.addJavaScriptHandler(
          handlerName: '__kostoriReport',
          callback: (args) {
            if (args.isEmpty) return null;
            final item = args[0];
            if (item is Map && item['type'] == 'cf') {
              sawCf = true;
              return null;
            }
            results.add(item);
            // 已找到视频直链，提前结束等待
            if (item is Map && item['type'] == 'video') {
              if (!completer.isCompleted) completer.complete(results);
            }
            return null;
          },
        );
      },
      onLoadResource: (_, resource) {
        final urlString = resource.url?.toString() ?? '';
        // 原生拦截：m3u8 与 mp4 直链（含跨域 iframe 内的请求，无需 JS 桥）
        if (urlString.contains('.m3u8') || urlString.contains('.mp4')) {
          final exists = results.any(
            (e) =>
                e is Map && e['type'] == 'hls_native' && e['url'] == urlString,
          );
          if (!exists) {
            results.add({'type': 'hls_native', 'url': urlString});
            if (!completer.isCompleted) completer.complete(results);
          }
        }
      },
      onLoadStop: (_, _) => scheduleComplete(),
      onReceivedError: (_, _, _) {
        completionTimer?.cancel();
        if (!completer.isCompleted) completer.complete(results);
      },
    );

    await webView.run();

    List<dynamic> finalResults;
    try {
      // CF 挑战可能耗时较久，硬上限放宽
      finalResults = await completer.future.timeout(
        Duration(milliseconds: waitMs + 15000),
        onTimeout: () => results,
      );
    } finally {
      completionTimer?.cancel();
      // 关键：dispose 前先解除 JS 上报（含同源 iframe），并留出在途上报的缓冲时间，
      // 否则迟到的 __kostoriReport 会在已释放的 WebView 上触发 → 原生崩溃
      await _disarm(webViewController);
      webView.dispose();
    }
    return _cleanResults(finalResults);
  }

  /// 解除 JS 上报（含同源 iframe），留出在途上报缓冲，避免 dispose 后崩溃
  static Future<void> _disarm(InAppWebViewController? controller) async {
    try {
      await controller?.evaluateJavascript(
        source: '''
        (function(){
          window.__kostoriStop && window.__kostoriStop();
          try {
            document.querySelectorAll('iframe').forEach(function(f){
              try { f.contentWindow.__kostoriStop && f.contentWindow.__kostoriStop(); } catch(e){}
            });
          } catch(e){}
        })();
        ''',
      );
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  // ── 脚本构建 ─────────────────────────────────────────────────────────────

  static List<UserScript> _buildUserScripts(
    Map<String, String>? headers,
    String? script, {
    bool scan = true,
  }) {
    return [
      UserScript(
        source: _buildEarlyScript(headers),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
      if (script != null && script.isNotEmpty)
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      // 内置视频扫描：拦截 XHR/fetch 响应文本 + 定时扫描 DOM，上报 {type:'video',url}。
      // scan=false 时跳过（其 fetch/XHR/Response.text 钩子可能被 Cloudflare 检测）。
      if (scan)
        UserScript(
          source: _videoScanScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      // 桥就绪探针：便于排查，结果返回前会被过滤掉
      UserScript(
        source: _debugProbeScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ),
    ];
  }

  /// 通用视频链接扫描（借鉴 Kazumi 的思路）：
  /// - 按 URL 后缀捕获 .m3u8/.mp4；
  /// - 更关键：重写 Response.text 与 XHR，当响应体以 #EXTM3U 开头（HLS 清单）
  ///   时上报来源 URL —— 不要求 URL 带 .m3u8，可覆盖"API 返回清单"的播放器；
  /// - 定时扫描 DOM（script 内容、video/source/iframe 的 src）；
  /// - 上报 maccms 的 player_*.url 原始值（type: player_url）供源脚本解码。
  static const _videoScanScript = r'''
(function () {
  var _found = false;
  var _reported = {};
  var _timer = null;
  function stop() {
    _found = true;
    if (_timer) { clearInterval(_timer); _timer = null; }
  }
  window.__kostoriStop = stop;
  function unescapeHtml(u) {
    return u.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
            .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ');
  }
  function reportVideo(url) {
    if (_found || !url) return;
    var clean = unescapeHtml(url);
    if (_reported[clean]) return;
    _reported[clean] = true;
    try { __kostoriReport({ type: 'video', url: clean }); } catch (e) {}
    stop(); // 找到即停，避免重复上报与 teardown 崩溃
  }
  function report(url) {
    if (!url) return;
    if (/\.(m3u8|mp4)(\?.*)?$/i.test(url)) reportVideo(url);
  }
  function reportM3U(url) {
    if (url) reportVideo(url);
  }
  // 上报嵌套 iframe 播放页（如 QQ 播放器等跨域播放器），供源脚本跟随重新加载嗅探
  var _nestedReported = {};
  function reportNestedPage(url) {
    if (_found || !url) return;
    if (!/^https?:\/\//i.test(url)) return;
    if (_nestedReported[url]) return;
    _nestedReported[url] = true;
    try { __kostoriReport({ type: 'nested_page', url: url }); } catch (e) {}
  }
  function isHLS(text) {
    return text && typeof text === 'string' && text.trim().indexOf('#EXTM3U') === 0;
  }
  function reportFromText(text) {
    if (!text || typeof text !== 'string') return;
    var abs = text.match(/https?:\/\/[^"'<>\s\\]+?\.(m3u8|mp4)(\?[^"'<>\s\\]*)?/gi);
    if (abs) abs.forEach(report);
  }
  // 重写 fetch 的 Response.text：检测 HLS 清单 / 内嵌视频地址
  try {
    var _respText = window.Response.prototype.text;
    window.Response.prototype.text = function () {
      var self = this;
      return _respText.call(this).then(function (text) {
        if (isHLS(text)) reportM3U(self.url);
        else reportFromText(text);
        return text;
      });
    };
  } catch (e) {}
  // XHR：请求 URL + 响应内容
  var _xhrOpen = window.XMLHttpRequest.prototype.open;
  window.XMLHttpRequest.prototype.open = function (m, u) {
    this.__u = u;
    this.addEventListener('load', function () {
      try {
        report(this.__u);
        var t = this.responseText;
        if (isHLS(t)) { reportM3U(this.__u); }
        else { reportFromText(t); }
      } catch (e) {}
    });
    return _xhrOpen.apply(this, arguments);
  };
  // fetch 直接返回（备用）
  var _fetch = window.fetch;
  if (_fetch) {
    window.fetch = function (input, init) {
      var u = typeof input === 'string' ? input : (input && input.url);
      return _fetch.apply(this, arguments).then(function (res) {
        report(u);
        try {
          if (res && res.clone) {
            res.clone().text().then(function (t) {
              if (isHLS(t)) { reportM3U(u); }
              else { reportFromText(t); }
            }).catch(function () {});
          }
        } catch (e) {}
        return res;
      });
    };
  }
  // maccms 类站点：player_aaaa={...url:"..."} 原样上报为 player_url
  function reportPlayerConfigs(text) {
    if (_found || !text || typeof text !== 'string') return;
    var re = /player_[a-z0-9]+\s*=\s*\{[\s\S]*?"url"\s*:\s*"([^"]*)"/gi;
    var m;
    while ((m = re.exec(text))) {
      var raw = unescapeHtml(m[1]);
      if (raw && !/\.(m3u8|mp4)(\?.*)?$/i.test(raw)) {
        try { __kostoriReport({ type: 'player_url', url: raw }); } catch (e) {}
      }
    }
  }
  function reportCf() {
    try {
      var title = (document.title || '').toLowerCase();
      var body = document.body ? document.body.innerHTML : '';
      var hit =
        title.indexOf('just a moment') >= 0 ||
        title.indexOf('请稍候') >= 0 ||
        body.indexOf('__cf_chl') >= 0 ||
        body.indexOf('cf_chl') >= 0 ||
        document.querySelector('.cf-browser-verification, #challenge-running, form[id^="challenge-form"], input[name="cf_chl"]') != null;
      if (hit) { try { __kostoriReport({ type: 'cf' }); } catch (e) {} }
    } catch (e) {}
  }
  function scanDom() {
    if (_found) return;
    try {
      reportCf();
      var texts = [];
      if (document.documentElement) texts.push(document.documentElement.outerHTML);
      document.querySelectorAll('script').forEach(function (s) { texts.push(s.textContent || ''); });
      texts.forEach(reportFromText);
      texts.forEach(reportPlayerConfigs);
      document.querySelectorAll('video, source').forEach(function (el) {
        report(el.src || el.getAttribute('src') || el.getAttribute('data-src'));
      });
      // 嵌套 iframe：若是视频直链则上报；否则作为 nested_page 供源脚本跟随
      document.querySelectorAll('iframe').forEach(function (el) {
        var u = el.src || el.getAttribute('src') || el.getAttribute('data-src') || '';
        if (!u) return;
        var abs = /^https?:\/\//i.test(u) ? u : '';
        if (abs) {
          if (/\.(m3u8|mp4)(\?.*)?$/i.test(abs)) { report(abs); }
          else { reportNestedPage(abs); }
        }
      });
    } catch (e) {}
  }
  scanDom();
  _timer = setInterval(scanDom, 1200);
})();
''';

  static String _buildEarlyScript(Map<String, String>? headers) {
    final buffer = StringBuffer();
    buffer.writeln(_bridge);

    if (headers != null && headers.isNotEmpty) {
      final filtered = Map<String, String>.from(headers)
        ..remove('User-Agent')
        ..remove('user-agent');
      if (filtered.isNotEmpty) {
        String esc(String s) =>
            s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        final headersJs = filtered.entries
            .map((e) => '"${esc(e.key)}": "${esc(e.value)}"')
            .join(', ');
        buffer.writeln('''
(function() {
  var _headers = { $headersJs };
  var origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function() {
    var self = this;
    var origSend = self.send.bind(self);
    self.send = function() {
      Object.entries(_headers).forEach(function(e) {
        self.setRequestHeader(e[0], e[1]);
      });
      return origSend.apply(self, arguments);
    };
    return origOpen.apply(self, arguments);
  };
  var origFetch = window.fetch;
  window.fetch = function(input, init) {
    init = init || {};
    init.headers = Object.assign({}, _headers, init.headers || {});
    return origFetch.call(window, input, init);
  };
})();
''');
      }
    }

    return buffer.toString();
  }

  static const _bridge = r'''
(function() {
  var _queue = [];
  var _ready = false;

  function _flush() {
    if (typeof window.flutter_inappwebview !== 'undefined') {
      _ready = true;
      var pending = _queue.splice(0);
      pending.forEach(function(data) {
        try {
          window.flutter_inappwebview.callHandler('__kostoriReport', data);
        } catch(e) {}
      });
    } else {
      setTimeout(_flush, 50);
    }
  }

  window.__kostoriReport = function(data) {
    if (_ready) {
      try {
        window.flutter_inappwebview.callHandler('__kostoriReport', data);
      } catch(e) {
        _queue.push(data);
        _ready = false;
        _flush();
      }
    } else {
      _queue.push(data);
      _flush();
    }
  };
})();
''';

  static const _debugProbeScript = r'''
setTimeout(function() {
  __kostoriReport({ type: 'probe', msg: 'bridge ok' });
}, 1000);
''';

  /// 过滤调试探针等内部标记，只返回有效数据
  static List<dynamic> _cleanResults(List<dynamic> results) {
    return results.where((e) => e is! Map || e['type'] != 'probe').toList();
  }

  static const _mobileUA =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const _desktopUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}
