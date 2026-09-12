part of 'settings_page.dart';

/// 通用账号登录模块：插件 JS 通过声明 methods 提供会话/验证码/同步能力。
/// 登录成功后自动同步插件返回的饼干列表进通用 cookies 存储。
class _PluginAccountEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginAccountEditor({required this.plugin, required this.m});

  @override
  State<_PluginAccountEditor> createState() => _PluginAccountEditorState();
}

class _PluginAccountEditorState extends State<_PluginAccountEditor> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _verifyCtrl = TextEditingController();
  Timer? _captchaTimeout;
  Timer? _credsTimer;
  bool _busy = false;
  bool _captchaBusy = false;
  bool _logged = false;
  String _email = '';
  String? _captchaData; // 插件返回的 base64 验证码图
  String? _error;

  String _method(String k) {
    final raw = widget.m['methods'];
    if (raw is Map) {
      final v = raw[k];
      if (v != null) return v.toString();
    }
    return '';
  }

  String _txt(String k, String fallback) {
    final raw = widget.m['texts'];
    if (raw is Map) {
      final v = raw[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return fallback;
  }

  String get _listKey => widget.m['listKey']?.toString() ?? 'cookies';

  String get _activeKey => widget.m['activeKey']?.toString() ?? 'activeCookie';

  String get _configKey => widget.m['configKey']?.toString() ?? 'userhash';

  int? _activeIndexOf(List<Map<String, dynamic>> list) {
    final v = widget.plugin.dataValue(_activeKey);
    final idx = v is num
        ? v.toInt()
        : (v is String ? int.tryParse(v) : null);
    if (idx == null || idx < 0 || idx >= list.length) return null;
    return idx;
  }

  @override
  void initState() {
    super.initState();
    // 回填已持久化的账号密码（保存在本插件的 creds）
    final creds = MePagePluginManager().credsOf(widget.plugin.key);
    if (creds != null) {
      _emailCtrl.text = creds['username']?.toString() ?? '';
      _passCtrl.text = creds['password']?.toString() ?? '';
    }
    // 输入即持久化（不需要等登录成功），下次打开自动回填
    _emailCtrl.addListener(_schedulePersistCreds);
    _passCtrl.addListener(_schedulePersistCreds);
    _refreshStatus();
  }

  void _schedulePersistCreds() {
    _credsTimer?.cancel();
    _credsTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      await MePagePluginManager().setCreds(
        widget.plugin.key,
        username: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
    });
  }

  @override
  void dispose() {
    _captchaTimeout?.cancel();
    _credsTimer?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _verifyCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    if (_method('status').isEmpty) return;
    final res = await widget.plugin.invoke(_method('status'));
    if (!mounted) return;
    final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
    final logged = m?['logged'] == true;
    setState(() {
      _logged = logged;
      _email = m?['email']?.toString() ?? '';
      _error = null;
    });
    if (!logged) await _refreshCaptcha();
  }

  Future<void> _refreshCaptcha() async {
    if (_method('captcha').isEmpty) return;
    if (_captchaBusy) {
      App.rootContext.showMessage(message: '正在刷新验证码…');
      return;
    }
    setState(() {
      _captchaData = null;
      _captchaBusy = true;
      _error = null;
    });
    _captchaTimeout?.cancel();
    _captchaTimeout = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      setState(() {
        _captchaBusy = false;
        _error = t.invalidCookieHash;
      });
    });
    try {
      final res = await widget.plugin.invoke(_method('captcha'));
      if (!mounted) return;
      final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
      final data = m?['data']?.toString() ?? '';
      if (data.isEmpty) {
        setState(() {
          _error =
              m?['error']?.toString().isNotEmpty == true
                  ? m!['error'].toString()
                  : t.invalidCookieHash;
        });
        return;
      }
      setState(() => _captchaData = data);
    } finally {
      _captchaTimeout?.cancel();
      _captchaTimeout = null;
      if (mounted) setState(() => _captchaBusy = false);
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final verify = _verifyCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = t.cannotBeEmpty);
      return;
    }
    if (verify.isEmpty || _captchaData == null) {
      setState(() => _error = t.cookieNameRequired);
      return;
    }
    if (_method('login').isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.plugin
        .invoke(_method('login'), [email, password, verify]);
    if (!mounted) return;
    final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
    setState(() => _busy = false);
    if (m?['ok'] == true) {
      _logged = true;
      _email = m?['email']?.toString() ?? email;
      // 登录成功：持久化账号密码，重启后回填
      await MePagePluginManager().setCreds(
        widget.plugin.key,
        username: email,
        password: password,
      );
      _verifyCtrl.clear();
      setState(() {});
      await _sync();
    } else {
      setState(() {
        _error =
            m?['message']?.toString().isNotEmpty == true
                ? m!['message'].toString()
                : t.loginFailed;
      });
      await _refreshCaptcha();
    }
  }

  Future<void> _sync() async {
    if (_method('sync').isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await widget.plugin.invoke(_method('sync'));
    if (!mounted) return;
    final m = res is Map ? res.map((k, v) => MapEntry('$k', v)) : null;
    setState(() => _busy = false);
    if (m == null || m['items'] is! List) {
      if (mounted) {
        setState(() {
          _error =
              m?['error']?.toString().isNotEmpty == true
                  ? m!['error'].toString()
                  : t.noData;
        });
      }
      return;
    }
    final rawItems = m['items'] as List;
    final incoming = <Map<String, dynamic>>[];
    for (final e in rawItems) {
      if (e is Map) {
        final em = e.map((k, v) => MapEntry('$k', v));
        final hash = _normalizeCookieUserhash(em['userhash']?.toString() ?? '');
        if (hash == null) continue;
        incoming.add({
          'name': (em['name']?.toString().trim() ?? '').isEmpty
              ? '饼干'
              : em['name'].toString(),
          'userhash': hash,
          if ((em['note']?.toString().trim() ?? '').isNotEmpty)
            'note': em['note'].toString(),
        });
      }
    }
    _merge(incoming);
    if (incoming.isEmpty) {
      App.rootContext.showMessage(
        message: _txt('noCookies', '账号下没有可同步的饼干'),
        level: LogLevel.warning,
      );
      return;
    }
    App.rootContext.showMessage(message: t.cookieImported);
  }

  void _merge(List<Map<String, dynamic>> incoming) {
    final current = widget.plugin.dataValue(_listKey);
    final list = <Map<String, dynamic>>[];
    if (current is List) {
      for (final e in current) {
        if (e is Map) {
          final m = e.map((k, v) => MapEntry(k.toString(), v));
          if ((m['userhash']?.toString() ?? '').isNotEmpty) list.add(m);
        }
      }
    }
    String? oldActive;
    final oldIdx = _activeIndexOf(list);
    if (oldIdx != null && oldIdx < list.length) {
      oldActive = list[oldIdx]['userhash']?.toString();
    }
    for (final item in incoming) {
      final idx = list.indexWhere(
        (e) => e['userhash'] == item['userhash'],
      );
      if (idx >= 0) {
        list[idx] = item;
      } else {
        list.add(item);
      }
    }
    var active = oldActive != null
        ? list.indexWhere((e) => e['userhash'] == oldActive)
        : (list.isNotEmpty ? 0 : -1);
    if (active < 0 && incoming.isNotEmpty) {
      active = list.indexWhere((e) => e['userhash'] == incoming.first['userhash']);
    }
    widget.plugin.setDataValue(_listKey, list);
    widget.plugin.setDataValue(
      _activeKey,
      active >= 0 && active < list.length ? active : null,
    );
    if (active >= 0 && active < list.length) {
      widget.plugin.setConfigValue(_configKey, list[active]['userhash']!.toString());
    } else {
      widget.plugin.setConfigValue(_configKey, '');
    }
    MePagePluginManager().touch();
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    if (_method('logout').isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await widget.plugin.invoke(_method('logout'));
    if (!mounted) return;
    setState(() {
      _busy = false;
      _logged = false;
      _verifyCtrl.clear();
    });
    await _refreshCaptcha();
  }

  Uint8List? _captchaBytes() {
    final data = _captchaData;
    if (data == null) return null;
    try {
      return base64Decode(data.replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_logged) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _txt('loggedIn', _email.isEmpty ? t.loggedIn : _email),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconTileButton(
                icon: const Icon(Icons.sync),
                label: _txt('sync', '同步账号饼干'),
                onTap: _sync,
              ),
              IconTileButton(
                icon: const Icon(Icons.logout),
                label: _txt('logout', t.logOut),
                onTap: _logout,
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: cs.error),
              ),
            ),
        ],
      );
    }
    final bytes = _captchaBytes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: _txt('email', t.username),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: _txt('password', t.password),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _verifyCtrl,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: _txt('verify', 'Verify code'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        // 验证码单独一大块展示，方便辨认；点图即可刷新/重试
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Tooltip(
            message: _txt('captchaTip', '看不清？点击刷新验证码'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _refreshCaptcha,
              child: SizedBox(
                width: double.infinity,
                height: 120,
                child: bytes != null
                    ? ColoredBox(
                        color: cs.surfaceContainerHigh,
                        child: Image.memory(
                          bytes,
                          key: ValueKey(_captchaData),
                          fit: BoxFit.contain,
                          gaplessPlayback: false,
                          errorBuilder: (_, _, _) => _captchaFallback(cs),
                        ),
                      )
                    : _captchaFallback(cs),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _refreshCaptcha,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(_txt('captchaRefresh', '刷新验证码')),
          ),
        ),
        const SizedBox(height: 4),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(fontSize: 12, color: cs.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: _busy ? null : _login,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: PolygonRefreshIndicator(),
                )
              : const Icon(Icons.login),
          label: Text(_txt('login', t.logIn)),
        ),
      ],
    );
  }

  Widget _captchaFallback(ColorScheme cs) {
    return Container(
      width: double.infinity,
      height: 120,
      color: cs.surfaceContainerHigh,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_captchaBusy)
            const SizedBox.square(
              dimension: 18,
              child: PolygonRefreshIndicator(),
            )
          else ...[
            Icon(Icons.refresh, size: 24, color: cs.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              _txt('captchaTipShort', '点击重试'),
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// 多凭据管理器（列表 + 增删 + 选中默认项）
class _PluginCookiesEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginCookiesEditor({required this.plugin, required this.m});

  @override
  State<_PluginCookiesEditor> createState() => _PluginCookiesEditorState();
}

class _PluginCookiesEditorState extends State<_PluginCookiesEditor> {
  @override
  void initState() {
    super.initState();
    // 旧版单饼干配置 → 迁移进列表（仅首次且列表为空时）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final legacy = widget.plugin.configs[_configKey]?.toString() ?? '';
      if (legacy.isNotEmpty && _list().isEmpty) {
        _addEntry(name: _txt('legacy', '饼干'), hash: legacy);
      }
    });
  }

  String get _listKey => widget.m['key']?.toString() ?? 'cookies';

  String get _activeKey => widget.m['activeKey']?.toString() ?? 'activeCookie';

  String get _configKey => widget.m['configKey']?.toString() ?? 'userhash';

  String _txt(String k, String fallback) {
    final raw = widget.m['texts'];
    if (raw is Map) {
      final v = raw[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return fallback;
  }

  List<Map<String, dynamic>> _list() {
    final raw = widget.plugin.dataValue(_listKey);
    final out = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final m = e.map((k, v) => MapEntry(k.toString(), v));
          if ((m['userhash']?.toString() ?? '').isNotEmpty) out.add(m);
        }
      }
    }
    return out;
  }

  int? _active() {
    final v = widget.plugin.dataValue(_activeKey);
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  Map<String, dynamic>? _activeCookie() {
    final list = _list();
    final idx = _active();
    if (idx == null || idx < 0 || idx >= list.length) return null;
    return list[idx];
  }

  void _commit(List<Map<String, dynamic>> list, int? active) {
    widget.plugin.setDataValue(_listKey, list);
    widget.plugin.setDataValue(_activeKey, active);
    if (active != null &&
        active >= 0 &&
        active < list.length &&
        (list[active]['userhash']?.toString() ?? '').isNotEmpty) {
      widget.plugin.setConfigValue(
        _configKey,
        list[active]['userhash']!.toString(),
      );
    } else {
      widget.plugin.setConfigValue(_configKey, '');
    }
    MePagePluginManager().touch();
    if (mounted) setState(() {});
  }

  void _select(int idx) {
    final list = _list();
    if (idx < 0 || idx >= list.length) return;
    _commit(list, idx);
    App.rootContext.showMessage(
      message: '${list[idx]['name'] ?? list[idx]['userhash']} · '
          '${_txt('active', '用于浏览')}',
    );
  }

  Future<void> _addManual() async {
    final nameCtrl = TextEditingController();
    final hashCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String? error;
    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => ContentDialog(
          title: _txt('add', '添加自定义饼干'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: _txt('name', 'name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: hashCtrl,
                decoration: InputDecoration(
                  labelText: _txt('hash', 'userhash / cookie'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: _txt('note', '备注（可不填）'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final hash = _normalizeCookieUserhash(hashCtrl.text);
                if (name.isEmpty) {
                  setD(() => error = t.cookieNameRequired);
                  return;
                }
                if (hash == null) {
                  setD(() => error = t.invalidCookieHash);
                  return;
                }
                Navigator.pop(ctx, true);
                _addEntry(
                  name: name,
                  hash: hash,
                  note: noteCtrl.text.trim(),
                );
              },
              child: Text(_txt('save', t.confirm)),
            ),
          ],
        ),
      ),
    );
    // 注意：不要在这里 dispose 控制器——弹窗关闭的过渡动画期间
    // TextField 仍会引用它们（见 “used after being disposed” 崩溃）
  }

  Future<void> _addByScan() async {
    final result = await QrScannerPage.push(context);
    if (result == null || !mounted) return;
    var name = '';
    var hash = _normalizeCookieUserhash(result.rawValue);
    try {
      final decoded = jsonDecode(result.rawValue);
      if (decoded is Map) {
        final map = decoded.map((k, v) => MapEntry('$k', v));
        name = map['name']?.toString() ?? '';
        hash =
            _normalizeCookieUserhash(
              map['cookie']?.toString() ?? '',
            ) ??
            hash;
      }
    } catch (_) {}
    if (hash == null) {
      App.rootContext.showMessage(
        message: t.invalidCookieQrCode,
        level: LogLevel.error,
      );
      return;
    }
    if (name.isEmpty) name = _txt('scanFallback', '扫码饼干');
    _addEntry(name: name, hash: hash);
  }

  void _addEntry({
    required String name,
    required String hash,
    String note = '',
  }) {
    final list = _list();
    final existing = list.indexWhere((e) => e['userhash'] == hash);
    if (existing >= 0) {
      _commit(list, existing);
      App.rootContext.showMessage(message: '${t.alreadyExists}: $name');
      return;
    }
    list.add({
      'name': name,
      'userhash': hash,
      if (note.isNotEmpty) 'note': note,
    });
    _commit(list, list.length - 1);
    App.rootContext.showMessage(message: t.cookieImported);
  }

  void _remove(int idx) {
    final list = _list();
    if (idx < 0 || idx >= list.length) return;
    final removed = list[idx];
    showConfirmDialog(
      context: context,
      title: t.delete,
      content:
          '${removed['name'] ?? ''}\n${removed['userhash']}'
          '${(removed['note'] ?? '').toString().isNotEmpty ? '\n${removed['note']}' : ''}',
      btnColor: Theme.of(context).colorScheme.error,
      onConfirm: () {
        final active = _active();
        list.removeAt(idx);
        var newActive = active;
        if (newActive != null) {
          if (newActive == idx) {
            newActive = list.isEmpty ? null : 0;
          } else if (newActive > idx) {
            newActive--;
          }
        }
        _commit(list, newActive);
        App.rootContext.showMessage(message: t.deleted);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _list();
    final active = _activeCookie();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cookie_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                active == null
                    ? _txt('none', '还没有饼干')
                    : '${active['name'] ?? active['userhash']} · '
                          '${_txt('active', '用于浏览')}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active == null ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconTileButton(
              icon: const Icon(Icons.edit_note),
              label: _txt('add', '添加自定义饼干'),
              onTap: _addManual,
            ),
            IconTileButton(
              icon: const Icon(Icons.qr_code_scanner),
              label: _txt('scan', '扫描饼干二维码'),
              onTap: _addByScan,
            ),
          ],
        ),
        if (list.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) Divider(height: 1, color: cs.outlineVariant),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                i == _active()
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: i == _active() ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(
                (list[i]['name']?.toString() ?? '')
                    .isEmpty
                    ? (list[i]['userhash']?.toString() ?? '')
                    : list[i]['name']!.toString(),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                [
                  list[i]['userhash']?.toString() ?? '',
                  list[i]['note']?.toString() ?? '',
                ].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: t.delete,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: cs.error,
                ),
                onPressed: () => _remove(i),
              ),
              onTap: () => _select(i),
            ),
          ],
        ],
      ],
    );
  }
}

/// 凭据设置：自定义粘贴导入 / 扫码导入
class _PluginCookieEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginCookieEditor({required this.plugin, required this.m});

  @override
  State<_PluginCookieEditor> createState() => _PluginCookieEditorState();
}

class _PluginCookieEditorState extends State<_PluginCookieEditor> {
  String get _key => widget.m['key']?.toString() ?? 'userhash';

  String get _value => widget.plugin.configs[_key]?.toString() ?? '';

  /// 兼容多种来源：裸 userhash / userhash=xxx / {"cookie":"…","name":"…"} / {"userhash":…}
  String? _normalize(String raw) => _normalizeCookieUserhash(raw);

  void _save(String hash) {
    widget.plugin.setConfigValue(_key, hash);
    MePagePluginManager().touch();
    if (mounted) setState(() {});
    App.rootContext.showMessage(message: t.cookieImported);
  }

  Future<void> _manualImport() async {
    await showInputDialog(
      context: context,
      title: t.importCustomCookie,
      hintText: 'userhash=xxxxx 或 {"cookie":"…","name":"…"}',
      initialValue: _value,
      minLines: 1,
      onConfirm: (raw) {
        final hash = _normalize(raw);
        if (hash == null) return t.invalidCookieQrCode;
        _save(hash);
        return null;
      },
    );
  }

  Future<void> _scanImport() async {
    final result = await QrScannerPage.push(context);
    if (result == null || !mounted) return;
    final hash = _normalize(result.rawValue);
    if (hash == null) {
      App.rootContext.showMessage(
        message: t.invalidCookieQrCode,
        level: LogLevel.error,
      );
      return;
    }
    _save(hash);
  }

  void _clear() {
    widget.plugin.setConfigValue(_key, '');
    MePagePluginManager().touch();
    if (mounted) setState(() {});
    App.rootContext.showMessage(message: t.cookieCleared);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cookie_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              _value.isEmpty ? t.noData : _value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                color: _value.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconTileButton(
              icon: const Icon(Icons.edit_note),
              label: t.importCustomCookie,
              onTap: _manualImport,
            ),
            IconTileButton(
              icon: const Icon(Icons.qr_code_scanner),
              label: t.scanCookieQrCode,
              onTap: _scanImport,
            ),
            if (_value.isNotEmpty)
              IconTileButton(
                icon: const Icon(Icons.backspace_outlined),
                label: t.clear,
                onTap: _clear,
              ),
          ],
        ),
      ],
    );
  }
}

/// 插件 config 输入：写入 `.data['configs']` 并通知刷新
class _PluginConfigEditor extends StatefulWidget {
  final MePagePlugin plugin;
  final Map<String, dynamic> m;

  const _PluginConfigEditor({required this.plugin, required this.m});

  @override
  State<_PluginConfigEditor> createState() => _PluginConfigEditorState();
}

class _PluginConfigEditorState extends State<_PluginConfigEditor> {
  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  List<Map<String, dynamic>> get _fields {
    final raw = widget.m['fields'] ?? widget.m['items'];
    final list = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final f in raw) {
        if (f is Map) {
          list.add(f.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      final key = f['key']?.toString() ?? '';
      _ctrls[key] = TextEditingController(
        text: widget.plugin.configs[key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (final f in _fields) {
        final key = f['key']?.toString() ?? '';
        widget.plugin.setConfigValue(key, _ctrls[key]?.text ?? '');
      }
      App.rootContext.showMessage(message: t.saved);
      MePagePluginManager().touch();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in _fields) ...[
          TextField(
            controller: _ctrls[f['key']?.toString() ?? ''],
            keyboardType: (f['kind']?.toString() ?? '') == 'number'
                ? TextInputType.number
                : TextInputType.text,
            decoration: InputDecoration(
              isDense: true,
              labelText: f['label']?.toString() ?? '',
              hintText: f['hint']?.toString(),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Button.filled(
            isLoading: _saving,
            onPressed: _save,
            child: Text(widget.m['saveText']?.toString() ?? t.apply),
          ),
        ),
      ],
    );
  }
}

/// 插件登录：与番剧源设置页的登录模块一致——账号/密码表单，
/// 提交后调用插件 `login(username, password)`（JS 内自行发请求、存 Cookie）
class _PluginLoginPage extends StatefulWidget {
  const _PluginLoginPage({
    required this.plugin,
    this.initialUsername = '',
  });

  final MePagePlugin plugin;
  final String initialUsername;

  @override
  State<_PluginLoginPage> createState() => _PluginLoginPageState();
}

class _PluginLoginPageState extends State<_PluginLoginPage> {
  late final TextEditingController _userCtrl = TextEditingController(
    text: widget.initialUsername,
  );
  final TextEditingController _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      context.showMessage(message: t.cannotBeEmpty);
      return;
    }
    setState(() => _loading = true);
    final res = await widget.plugin.login(username, password);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['ok'] == true) {
      widget.plugin.setLogged(true);
      await MePagePluginManager().setCreds(
        widget.plugin.key,
        username: username,
        password: password,
      );
      App.rootContext.showMessage(message: t.switchSuccessful);
      if (mounted) context.pop();
    } else {
      context.showMessage(
        message: res['message']?.toString().isNotEmpty == true
            ? res['message'].toString()
            : t.loginFailed,
        level: LogLevel.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.plugin.name)),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.login,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _userCtrl,
                decoration: InputDecoration(
                  labelText: t.username,
                  border: const OutlineInputBorder(),
                ),
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: t.password,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _login(),
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 24),
              Button.filled(
                isLoading: _loading,
                onPressed: _login,
                child: Text(t.continueText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
