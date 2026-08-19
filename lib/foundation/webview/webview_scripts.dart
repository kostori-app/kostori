/// WebView 嗅探共享脚本与结果类型常量。
///
/// 结果类型约定（与源脚本契约保持一致）：
/// - `video`：JS 嗅探或原生检测到的视频直链（m3u8/mp4）
/// - `hls_native`：原生资源拦截到的 m3u8/mp4
/// - `player_url`：maccms 类站点的 player_*.url 原始值，供源脚本解码
/// - `nested_page`：嵌套 iframe 播放页，供源脚本跟随重新加载
/// - `cf`：识别到 Cloudflare 挑战页标记（不结束等待，等挑战自动重载）
/// - `probe`：桥就绪探针（返回前会被过滤）
class WebviewResultType {
  static const video = 'video';
  static const hlsNative = 'hls_native';
  static const playerUrl = 'player_url';
  static const nestedPage = 'nested_page';
  static const cf = 'cf';
  static const probe = 'probe';
}

/// 过滤调试探针等内部标记，只返回有效数据
List<dynamic> cleanWebviewResults(List<dynamic> results) {
  return results
      .where((e) => e is! Map || e['type'] != WebviewResultType.probe)
      .toList();
}

/// flutter_inappwebview 平台的桥：通过 callHandler 上报
const String bridgeInAppWebview = r'''
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

/// 早期脚本：附加请求头（XHR/fetch）
String buildEarlyScript(
  Map<String, String>? headers, {
  required String bridgeSource,
}) {
  final buffer = StringBuffer();
  buffer.writeln(bridgeSource);

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

/// 通用视频链接扫描（借鉴 Kazumi 的思路）：
/// - 按 URL 后缀捕获 .m3u8/.mp4；
/// - 更关键：重写 Response.text 与 XHR，当响应体以 #EXTM3U 开头（HLS 清单）
///   时上报来源 URL —— 不要求 URL 带 .m3u8，可覆盖"API 返回清单"的播放器；
/// - 定时扫描 DOM（script 内容、video/source/iframe 的 src）；
/// - 上报 maccms 的 player_*.url 原始值（type: player_url）供源脚本解码。
const String videoScanScript = r'''
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
      if (raw && !/\.(m3u8|mp4)(\?.*)?$/i.test(raw) && !_reported[raw]) {
        _reported[raw] = true;
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
        document.querySelector('#cf-chl-widget, #challenge-running, form[id^="challenge-form"], input[name="cf_chl"], .cf-browser-verification') != null;
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

/// 桥就绪探针：便于排查，结果返回前会被过滤掉
const String debugProbeScript = r'''
setTimeout(function() {
  __kostoriReport({ type: 'probe', msg: 'bridge ok' });
}, 1000);
''';

const String mobileUA =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

const String desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
