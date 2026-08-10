// ignore_for_file: use_build_context_synchronously, empty_catches

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:kostori/foundation/context.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/network/app_dio.dart';
import 'package:kostori/network/cookie_jar.dart';

const _kAccessToken = 'bangumi_access_token';
const _kRefreshToken = 'bangumi_refresh_token';
const _kRedirectUri = 'bangumi_redirect_uri';

/// 网页端接口使用浏览器 UA（避免被 WAF 拒绝），API 接口才用 bangumiHTTPHeader
const _webHeaders = {'user-agent': webUA, 'referer': 'https://bgm.tv/'};

/// 本地回调固定端口（需在 bgm.tv/dev 注册该回调地址）
const bangumiCallbackPort = 5788;

/// 内置 Bangumi 应用客户端 ID（写死，无需用户填写）
const bangumiClientId = 'bgm68556a791c57ccf88';

/// 内置 Bangumi 应用客户端密钥（写死，Bangumi OAuth 规范必填）
const bangumiClientSecret = 'f49ee603dee65e096a3bec75bd037079';

String? get bangumiAccessToken =>
    appdata.implicitData[_kAccessToken] as String?;

String? get bangumiRefreshTokenValue =>
    appdata.implicitData[_kRefreshToken] as String?;

bool get bangumiLoggedIn {
  final token = bangumiAccessToken;
  return token != null && token.trim().isNotEmpty;
}

String bangumiRedirectUri() =>
    (appdata.implicitData[_kRedirectUri] as String?) ??
    'http://127.0.0.1:$bangumiCallbackPort/callback';

String _oauthFormEncode(Map<String, String> data) => data.entries
    .map(
      (e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
    )
    .join('&');

/// 用 refresh_token 换新 access_token（OAuth 授权有效期刷新）
Future<bool> bangumiRefreshToken() async {
  final refresh = bangumiRefreshTokenValue;
  if (refresh == null || refresh.trim().isEmpty) return false;
  try {
    final res = await AppDio().request(
      'https://bgm.tv/oauth/access_token',
      data: _oauthFormEncode({
        'grant_type': 'refresh_token',
        'client_id': bangumiClientId,
        'client_secret': bangumiClientSecret,
        'refresh_token': refresh.trim(),
        'redirect_uri': bangumiRedirectUri(),
      }),
      options: Options(
        method: 'POST',
        contentType: 'application/x-www-form-urlencoded',
        headers: _webHeaders,
        validateStatus: (_) => true,
      ),
    );
    final json = res.data;
    Log.info('BangumiOAuth', '刷新token status=${res.statusCode} body=$json');
    if (json is Map) {
      final access = json['access_token']?.toString() ?? '';
      if (access.isNotEmpty) {
        appdata.implicitData[_kAccessToken] = access;
        final newRefresh = json['refresh_token']?.toString() ?? '';
        if (newRefresh.isNotEmpty) {
          appdata.implicitData[_kRefreshToken] = newRefresh;
        }
        appdata.writeImplicitData();
        return true;
      }
    }
  } catch (e) {
    Log.error('BangumiOAuth', '刷新token失败: $e');
  }
  return false;
}

/// 查询授权信息（access_token 的过期时间 / user_id 等）
Future<Map<String, dynamic>?> bangumiTokenStatus() async {
  final token = bangumiAccessToken;
  if (token == null || token.trim().isEmpty) return null;
  try {
    final res = await AppDio().request(
      'https://bgm.tv/oauth/token_status',
      data: 'access_token=${Uri.encodeQueryComponent(token.trim())}',
      options: Options(
        method: 'POST',
        contentType: 'application/x-www-form-urlencoded',
        headers: _webHeaders,
        validateStatus: (_) => true,
      ),
    );
    final json = res.data;
    Log.info(
      'BangumiOAuth',
      'token_status status=${res.statusCode} body=$json',
    );
    if (json is Map) return json.cast<String, dynamic>();
  } catch (e) {
    Log.error('BangumiOAuth', 'token_status失败: $e');
  }
  return null;
}

/// 打开 Bangumi 账号密码登录弹窗（与 czy0729 一致：仅填账号密码+验证码，自动换取 token）
Future<void> bangumiOAuthLogin(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: const BangumiLoginPage(),
        ),
      ),
    ),
  );
}

/// 退出登录，清除令牌
void bangumiOAuthLogout() {
  appdata.implicitData[_kAccessToken] = '';
  appdata.implicitData[_kRefreshToken] = '';
  appdata.writeImplicitData();
}

/// Bangumi 账号密码登录弹窗内容
class BangumiLoginPage extends StatefulWidget {
  const BangumiLoginPage({super.key});

  @override
  State<BangumiLoginPage> createState() => _BangumiLoginPageState();
}

class _BangumiLoginPageState extends State<BangumiLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  Uint8List? _captchaBytes;
  String _info = '';
  bool _loading = false;
  String _loginFormhash = '';
  String _oauthFormhash = '';

  @override
  void initState() {
    super.initState();
    _emailCtrl.text =
        appdata.implicitData['bangumi_login_email'] as String? ?? '';
    _passwordCtrl.text =
        appdata.implicitData['bangumi_login_password'] as String? ?? '';
    _initFlow();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  String _authUrl() =>
      'https://bgm.tv/oauth/authorize'
      '?client_id=$bangumiClientId'
      '&response_type=code'
      '&redirect_uri=${Uri.encodeQueryComponent(bangumiRedirectUri())}';

  /// 第一步：清掉失效的旧会话，再获取 /login 的 formhash（Cookie 由 CookieManagerSql 自动管理）
  Future<void> _initFlow() async {
    try {
      // 失效的 chii_auth 会被 Discuz 当作"已登录"而拒绝重新登录，先清掉整个 bgm.tv 会话
      await SingleInstanceCookieJar.instance?.deleteUri(
        Uri.parse('https://bgm.tv/'),
      );
      final res = await AppDio().request(
        'https://bgm.tv/login',
        options: Options(
          method: 'GET',
          headers: _webHeaders,
          validateStatus: (_) => true,
        ),
      );
      final data = res.data;
      if (data is String) {
        final m = RegExp(
          r'<input type="hidden" name="formhash" value="(.+?)">',
        ).firstMatch(data);
        _loginFormhash = m?.group(1) ?? '';
      }
      Log.info('BangumiLogin', '登录页 formhash=$_loginFormhash');
    } catch (e) {
      Log.error('BangumiLogin', 'init 失败: $e');
    }
    await _loadCaptcha();
  }

  /// 第二步：获取验证码图片（URL = 时间戳 + 1~6 随机尾数）
  Future<void> _loadCaptcha() async {
    if (mounted) setState(() => _captchaBytes = null);
    try {
      final res = await AppDio().request<Uint8List>(
        'https://bgm.tv/signup/captcha?'
        '${DateTime.now().millisecondsSinceEpoch}${1 + Random().nextInt(6)}',
        options: Options(
          method: 'GET',
          responseType: ResponseType.bytes,
          headers: _webHeaders,
          validateStatus: (_) => true,
        ),
      );
      final data = res.data;
      Log.info(
        'BangumiLogin',
        '验证码 status=${res.statusCode} type=${data.runtimeType} '
            'len=${data is Uint8List ? data.length : '?'}',
      );
      if (data is Uint8List && data.isNotEmpty) {
        if (mounted) {
          setState(() {
            _captchaBytes = data;
            _captchaCtrl.clear();
          });
        }
      } else {
        Log.error('BangumiLogin', '验证码数据为空或类型异常: ${data.runtimeType}');
      }
    } catch (e) {
      Log.error('BangumiLogin', '验证码获取失败: $e');
    }
  }

  /// 获取授权页 HTML（返回授权表单=会话有效；返回登录页=需要登录）
  Future<String> _fetchAuthPage() async {
    final res = await AppDio().request(
      _authUrl(),
      options: Options(
        method: 'GET',
        headers: _webHeaders,
        validateStatus: (_) => true,
      ),
    );
    return res.data is String ? res.data as String : '';
  }

  /// 判断是否为「授权应用访问」表单页
  bool _isAuthPage(String html) =>
      html.contains('授权应用访问') &&
      RegExp(
        r'<input type="hidden" name="formhash" value="(.+?)">',
      ).hasMatch(html);

  /// 第三步：登录并换取 OAuth code → access_token
  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final captcha = _captchaCtrl.text.trim();

    if (email.isNotEmpty) {
      appdata.implicitData['bangumi_login_email'] = email;
      appdata.writeImplicitData();
    }
    if (password.isNotEmpty) {
      appdata.implicitData['bangumi_login_password'] = password;
      appdata.writeImplicitData();
    }

    setState(() {
      _loading = true;
      _info = t.bangumiLoggingIn;
    });

    try {
      // 1. 先用现有会话获取授权页
      var authData = await _fetchAuthPage();
      var needLogin = !_isAuthPage(authData);

      if (needLogin) {
        // 2. 会话无效 → 密码登录
        if (email.isEmpty || password.isEmpty || captcha.isEmpty) {
          if (mounted) {
            setState(() {
              _loading = false;
              _info = t.bangumiClientIdSecretRequired;
            });
          }
          return;
        }
        // 登录成功会返回 302（chii_auth 在 302 的 set-cookie 里），必须拦截重定向
        final loginRes = await AppDio().request(
          'https://bgm.tv/FollowTheRabbit',
          data: _oauthFormEncode({
            'formhash': _loginFormhash,
            // 与 czy0729 一致：referer/dreferer 为空，避免 oauth URL 触发不同处理路径
            'referer': '',
            'dreferer': '',
            'email': email,
            'password': password,
            'captcha_challenge_field': captcha,
            'loginsubmit': '登录',
          }),
          options: Options(
            method: 'POST',
            maxRedirects: 0,
            validateStatus: (_) => true,
            contentType: 'application/x-www-form-urlencoded',
            headers: _webHeaders,
          ),
        );
        final setCookie = (loginRes.headers['set-cookie'] ?? const <String>[])
            .join('; ');
        final hasAuth = setCookie.contains('chii_auth=');
        final bodyStr = loginRes.data is String ? loginRes.data as String : '';
        final loginLocation =
            loginRes.headers.value('x-redirect-url') ??
            loginRes.headers.value('location') ??
            '';
        Log.info(
          'BangumiLogin',
          '登录 status=${loginRes.statusCode} 有chii_auth=$hasAuth '
              '已登录页=${bodyStr.contains('class="logout"')} location=$loginLocation',
        );
        // 302 = 登录成功（chii_auth 在 302 的 set-cookie 里）
        final loggedIn302 = loginRes.statusCode == 302;
        if (!hasAuth && !loggedIn302 && !bodyStr.contains('class="logout"')) {
          String? errText;
          // Discuz 错误信息常在 class="text" 容器里（如“验证码错误，请返回重试。”）
          final textMatch = RegExp(
            r'<(?:p|div|span|strong)[^>]*class="[^"]*(?:text|error|alert|notice)[^"]*"[^>]*>(.*?)</(?:p|div|span|strong)>',
            dotAll: true,
          ).firstMatch(bodyStr);
          final text = textMatch?.group(1)?.trim() ?? '';
          if (text.isNotEmpty && text.length < 100 && !text.contains('<')) {
            errText = text;
          } else {
            for (final kw in ['验证码错误', '用户名或密码错误', '密码错误', '不能登录']) {
              final i = bodyStr.indexOf(kw);
              if (i != -1) {
                errText = bodyStr
                    .substring(i, i + 40)
                    .split(RegExp(r'[<]'))
                    .first
                    .trim();
                break;
              }
            }
          }
          // 静默回显登录页（标题“登录至 Bangumi”且带登录表单）也视为验证码或密码错误
          if (errText == null &&
              (bodyStr.contains('id="loginForm"') ||
                  bodyStr.contains('登录至 Bangumi'))) {
            errText = t.bangumiCaptchaOrPasswordError;
          }
          Log.error(
            'BangumiLogin',
            '登录失败，错误提示=${errText ?? '未找到'} '
                '片段=${bodyStr.substring(0, bodyStr.length > 200 ? 200 : bodyStr.length)}',
          );
          await _loadCaptcha();
          if (mounted) {
            setState(() {
              _loading = false;
              _info = errText ?? t.bangumiLoginFailed;
            });
          }
          return;
        }
        // 登录成功后重新获取授权页
        authData = await _fetchAuthPage();
        needLogin = !_isAuthPage(authData);
      }

      if (needLogin) {
        Log.error('BangumiLogin', '登录后仍未取得授权页');
        if (mounted) {
          setState(() {
            _loading = false;
            _info = t.bangumiLoginFailed;
          });
        }
        return;
      }

      // 3. 提取授权页 formhash
      _oauthFormhash =
          RegExp(
            r'<input type="hidden" name="formhash" value="(.+?)">',
          ).firstMatch(authData)?.group(1) ??
          '';
      Log.info('BangumiLogin', '授权页 oauthFormhash=$_oauthFormhash');

      // 4. 提交授权，从重定向 URL 取 code
      String code = '';
      try {
        final authRes = await AppDio().request(
          _authUrl(),
          data: _oauthFormEncode({
            'formhash': _oauthFormhash,
            'redirect_uri': bangumiRedirectUri(),
            'client_id': bangumiClientId,
            'submit': '授权',
            'state': DateTime.now().millisecondsSinceEpoch.toString(),
          }),
          options: Options(
            method: 'POST',
            maxRedirects: 0,
            validateStatus: (_) => true,
            contentType: 'application/x-www-form-urlencoded',
            headers: {
              ..._webHeaders,
              'Referer': _authUrl(),
              'Origin': 'https://bgm.tv',
            },
          ),
        );
        final location =
            authRes.headers.value('x-redirect-url') ??
            authRes.headers.value('location') ??
            '';
        code = RegExp(r'[?&]code=([^&]+)').firstMatch(location)?.group(1) ?? '';
        if (code.isEmpty && authRes.data is String) {
          code =
              RegExp(
                r'[?&]code=([^&]+)',
              ).firstMatch(authRes.data as String)?.group(1) ??
              '';
        }
        Log.info(
          'BangumiLogin',
          '授权提交 status=${authRes.statusCode} location=$location code=$code'
              ' body=${authRes.data is String ? (authRes.data as String).substring(0, ((authRes.data as String).length > 300 ? 300 : (authRes.data as String).length)) : authRes.data}',
        );
      } catch (e) {
        Log.error('BangumiLogin', '授权提交异常: $e');
      }

      if (code.isEmpty) {
        Log.error('BangumiLogin', '授权未取到 code（oauthFormhash=$_oauthFormhash）');
        if (mounted) {
          setState(() {
            _loading = false;
            _info = t.bangumiLoginFailed;
          });
        }
        return;
      }

      // 5. 换取 access_token
      final tokenRes = await AppDio().request(
        'https://bgm.tv/oauth/access_token',
        data: _oauthFormEncode({
          'grant_type': 'authorization_code',
          'client_id': bangumiClientId,
          'client_secret': bangumiClientSecret,
          'code': code,
          'redirect_uri': bangumiRedirectUri(),
          'state': DateTime.now().millisecondsSinceEpoch.toString(),
        }),
        options: Options(
          method: 'POST',
          contentType: 'application/x-www-form-urlencoded',
          headers: _webHeaders,
          validateStatus: (_) => true,
        ),
      );
      final json = tokenRes.data;
      Log.info(
        'BangumiLogin',
        'token status=${tokenRes.statusCode} body=$json',
      );
      if (json is Map) {
        final access = json['access_token']?.toString() ?? '';
        if (access.isNotEmpty) {
          appdata.implicitData[_kAccessToken] = access;
          appdata.implicitData[_kRefreshToken] =
              json['refresh_token']?.toString() ?? '';
          appdata.writeImplicitData();
          if (mounted) {
            context.showMessage(message: t.bangumiLoginSuccess);
            Navigator.of(context).pop();
          }
          return;
        }
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _info = t.bangumiLoginFailed;
        });
      }
    } catch (e) {
      Log.error('BangumiLogin', '登录失败: $e');
      await _loadCaptcha();
      if (mounted) {
        setState(() {
          _loading = false;
          _info = t.bangumiLoginFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    InputDecoration inputDecoration(String label, IconData icon) =>
        InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.movie_filter_outlined,
                    size: 22,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Bangumi', style: textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              t.bangumiOAuthHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: inputDecoration('Email', Icons.alternate_email),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: inputDecoration('Password', Icons.lock_outline),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_captchaBytes != null)
                  GestureDetector(
                    onTap: _loadCaptcha,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Image.memory(
                          _captchaBytes!,
                          // contain 完整显示，避免 cover 裁剪掉验证码边缘
                          width: 172,
                          height: 52,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _captchaCtrl,
                    decoration: inputDecoration(
                      'Captcha',
                      Icons.verified_user_outlined,
                    ),
                    onSubmitted: (_) => _loading ? null : _login(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: t.reload,
                  onPressed: _loadCaptcha,
                ),
              ],
            ),
            if (_captchaBytes != null) ...[
              const SizedBox(height: 4),
              Text(
                t.bangumiCaptchaHint,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
            if (_info.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _info,
                style: TextStyle(
                  fontSize: 12,
                  color: _loading ? scheme.onSurfaceVariant : scheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _login,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.bangumiOAuthLogin),
            ),
          ],
        ),
      ),
    );
  }
}
