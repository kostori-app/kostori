import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';

class WebViewResolver {
  static bool _webViewEnvReady = false;

  static Future<List<dynamic>> fetchViaWebView(
    String url, {
    Map<String, String>? headers,
    String? script,
    int waitMs = 8000,
  }) async {
    try {
      if (Platform.isWindows) {
        return await _extractWindows(
          url,
          headers: headers,
          script: script,
          waitMs: waitMs,
        );
      }
      return await _extractHeadless(
        url,
        headers: headers,
        script: script,
        waitMs: waitMs,
      );
    } catch (e, s) {
      SourceLog.error('WebViewResolver', '$e\n$s');
    }
    return [];
  }

  static Future<List<dynamic>> _extractWindows(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
  }) async {
    if (!_webViewEnvReady) {
      await WebViewEnvironment.create();
      _webViewEnvReady = true;
    }

    final results = <dynamic>[];
    bool loaded = false;
    bool errored = false;

    final userScripts = _buildUserScripts(headers, script);
    OverlayEntry? entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 100,
        top: 100,
        width: 1024,
        height: 768,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url), headers: headers),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            blockNetworkImage: true,
            userAgent: _desktopUA,
            allowingReadAccessTo: null,
            useOnLoadResource: true,
          ),
          initialUserScripts: UnmodifiableListView(userScripts),
          onWebViewCreated: (controller) {
            controller.addJavaScriptHandler(
              handlerName: '__kostoriReport',
              callback: (args) {
                if (args.isNotEmpty) {
                  SourceLog.info(
                    'WebViewResolver',
                    '__kostoriReport: ${args[0]}',
                  );
                  results.add(args[0]);
                }
                return null;
              },
            );
          },
          onLoadResource: (controller, resource) {
            final urlString = resource.url?.toString() ?? "";
            SourceLog.info('WebViewResolver', '🌐 拦截到资源: $urlString');
            if (urlString.contains('.m3u8')) {
              SourceLog.info('WebViewResolver', '🎯 成功捕获目标 m3u8: $urlString');
              // 避免重复添加
              bool alreadyExists = results.any(
                (e) => e is Map && e['url'] == urlString,
              );
              if (!alreadyExists) {
                results.add({'type': 'hls_native', 'url': urlString});
              }
            }
          },
          onLoadStop: (_, _) => loaded = true,
          onReceivedError: (_, _, _) => errored = true,
        ),
      ),
    );

    Overlay.of(App.rootContext).insert(entry);

    try {
      final pageDeadline = DateTime.now().add(
        Duration(milliseconds: waitMs + 10000),
      );
      while (!loaded && !errored && DateTime.now().isBefore(pageDeadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      SourceLog.info(
        'WebViewResolver',
        'page loaded=$loaded errored=$errored, waiting ${waitMs}ms for scripts...',
      );

      if (loaded) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }

      SourceLog.info(
        'WebViewResolver',
        'done, collected ${results.length} result(s)',
      );
    } finally {
      entry.remove();
    }

    return results;
  }

  static Future<List<dynamic>> _extractHeadless(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
  }) async {
    final results = <dynamic>[];
    final completer = Completer<List<dynamic>>();

    final ua =
        headers?['User-Agent'] ??
        headers?['user-agent'] ??
        (Platform.isAndroid || Platform.isIOS ? _mobileUA : _desktopUA);

    final userScripts = _buildUserScripts(headers, script);

    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url), headers: headers),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        blockNetworkImage: true,
        userAgent: ua,
      ),
      initialUserScripts: UnmodifiableListView(userScripts),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: '__kostoriReport',
          callback: (args) {
            if (args.isNotEmpty) results.add(args[0]);
            return null;
          },
        );
      },
      onLoadStop: (_, _) async {
        await Future.delayed(Duration(milliseconds: waitMs));
        if (!completer.isCompleted) completer.complete(results);
      },
      onReceivedError: (_, _, _) {
        if (!completer.isCompleted) completer.complete(results);
      },
    );

    await webView.run();

    List<dynamic> finalResults;
    try {
      finalResults = await completer.future.timeout(
        Duration(milliseconds: waitMs + 5000),
      );
    } on TimeoutException {
      finalResults = results;
    }

    await webView.dispose();
    return finalResults;
  }

  static List<UserScript> _buildUserScripts(
    Map<String, String>? headers,
    String? script,
  ) {
    return [
      UserScript(
        source: _buildEarlyScript(headers),
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
      // user script：也在 document 创建时注入，确保在页面脚本发出请求前 hook 已就位
      if (script != null && script.isNotEmpty)
        UserScript(
          source: script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
        ),
      UserScript(
        source: _debugProbeScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        forMainFrameOnly: false,
      ),
    ];
  }

  static String _buildEarlyScript(Map<String, String>? headers) {
    final buffer = StringBuffer();
    buffer.writeln(_bridge);

    if (headers != null && headers.isNotEmpty) {
      final filtered = Map<String, String>.from(headers)
        ..remove('User-Agent')
        ..remove('user-agent');
      if (filtered.isNotEmpty) {
        final headersJs = filtered.entries
            .map((e) => '"${e.key}": "${e.value}"')
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

  static const _mobileUA =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static const _desktopUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}
