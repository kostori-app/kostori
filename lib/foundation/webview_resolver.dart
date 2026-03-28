import 'dart:async';
import 'dart:io';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kostori/foundation/log.dart';

class WebViewResolver {
  static Future<List<dynamic>> fetchViaWebView(
    String url, {
    Map<String, String>? headers,
    String? script,
    int waitMs = 8000,
  }) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return await _extractMobile(
          url,
          headers: headers,
          script: script,
          waitMs: waitMs,
        );
      }
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return await _extractDesktop(
          url,
          headers: headers,
          script: script,
          waitMs: waitMs,
        );
      }
    } catch (e, s) {
      SourceLog.error('WebViewResolver', '$e\n$s');
    }
    return [];
  }

  static Future<List<dynamic>> _extractMobile(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
  }) async {
    final results = <dynamic>[];
    final completer = Completer<List<dynamic>>();
    HeadlessInAppWebView? webView;

    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url), headers: headers),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        blockNetworkImage: true,
        userAgent:
            headers?['User-Agent'] ??
            headers?['user-agent'] ??
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: '__kostoriReport',
          callback: (args) {
            if (args.isNotEmpty) results.add(args[0]);
            return null;
          },
        );
      },
      onLoadStop: (controller, _) async {
        await controller.evaluateJavascript(source: _mobileBridge);

        if (headers != null && headers.isNotEmpty) {
          final filtered = Map<String, String>.from(headers)
            ..remove('User-Agent')
            ..remove('user-agent');
          if (filtered.isNotEmpty) {
            final headersJs = filtered.entries
                .map((e) => '"${e.key}": "${e.value}"')
                .join(', ');
            await controller.evaluateJavascript(
              source:
                  '''
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
      ''',
            );
          }
        }

        if (script != null && script.isNotEmpty) {
          await controller.evaluateJavascript(source: script);
        }
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

  static Future<List<dynamic>> _extractDesktop(
    String url, {
    Map<String, String>? headers,
    String? script,
    required int waitMs,
  }) async {
    final results = <dynamic>[];
    Webview? webview;

    try {
      webview = await WebviewWindow.create(
        configuration: CreateConfiguration(
          windowWidth: 1,
          windowHeight: 1,
          title: '',
        ),
      );

      webview.registerJavaScriptMessageHandler('__kostoriReport', (name, body) {
        results.add(body);
      });

      webview.addScriptToExecuteOnDocumentCreated(_desktopBridge);

      if (headers != null && headers.isNotEmpty) {
        final headersJs = headers.entries
            .map((e) => '"${e.key}": "${e.value}"')
            .join(', ');
        webview.addScriptToExecuteOnDocumentCreated('''
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

      if (script != null && script.isNotEmpty) {
        webview.addScriptToExecuteOnDocumentCreated(script);
      }

      webview.launch(url);
      await Future.delayed(Duration(milliseconds: waitMs));

      return results;
    } finally {
      webview?.close();
    }
  }

  static const _mobileBridge = '''
    window.__kostoriReport = function(data) {
      window.flutter_inappwebview.callHandler('__kostoriReport', data);
    };
  ''';

  static const _desktopBridge = '''
    window.__kostoriReport = function(data) {
      window.chrome.webview.postMessage(
        JSON.stringify({ channel: '__kostoriReport', data: data })
      );
    };
  ''';
}
