part of 'settings_page.dart';

class NetworkSettings extends StatefulWidget {
  const NetworkSettings({super.key});

  @override
  State<NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends State<NetworkSettings> {
  String _bangumiMirrorSummary() {
    final parts = <String>[];
    for (final type in BangumiMirrorType.values) {
      final label = bangumiMirrorTypeLabel(type);
      final selected = selectedBangumiMirror(type);
      parts.add('$label: ${selected?.name ?? t.mirrorOfficial}');
    }
    return parts.join('  ·  ');
  }

  /// 域名规则的摘要，hosts / 指定 DNS 与无代理直连都在这里，一眼能看到当前配置。
  String _domainRuleSummary() {
    final rules = loadDomainRules();
    final hosts = rules.where((r) => r.dnsMode == DnsRuleMode.hosts).length;
    final servers = rules.where((r) => r.dnsMode == DnsRuleMode.servers).length;
    final direct = rules.where((r) => r.noProxy).length;
    final parts = <String>[t.dnsRulesCount(count: rules.length)];
    if (dnsOverridesEnabled && hosts > 0) {
      parts.add(t.hostsRulesCount(count: hosts));
    }
    if (dnsOverridesEnabled && servers > 0) {
      parts.add(t.dnsServersRulesCount(count: servers));
    }
    if (noProxyOverridesEnabled && direct > 0) {
      parts.add(t.noProxyRulesCount(count: direct));
    }
    return parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text(t.network)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(title: t.network, icon: Icons.wifi),
                _PopupWindowSetting(
                  title: t.proxy,
                  builder: () => const _ProxySettingView(),
                ),
                _CallbackSetting(
                  title: t.domainRules,
                  subtitle: _domainRuleSummary(),
                  actionTitle: t.manage,
                  callback: () {
                    showPopUpWidget(
                      App.rootContext,
                      const DomainRuleManagerPage(),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.tlsSettings,
                  icon: Icons.lock_outline,
                ),
                _SwitchSetting(
                  title: t.serverNameIndication,
                  settingKey: "sni",
                  defaultValue: true,
                  onChanged: () => JsEngine().resetDio(),
                ),
                _SwitchSetting(
                  title: t.ignoreCertificateErrors,
                  subtitle: t.ignoreCertificateErrorsDesc,
                  settingKey: "ignoreBadCertificate",
                  onChanged: () => JsEngine().resetDio(),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.networkMirror,
                  icon: Icons.cloud_outlined,
                ),
                _CallbackSetting(
                  title: t.bangumiMirror,
                  subtitle: _bangumiMirrorSummary(),
                  actionTitle: t.manage,
                  callback: () {
                    showPopUpWidget(
                      App.rootContext,
                      const BangumiMirrorManagerPage(),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
                _CallbackSetting(
                  title: t.githubMirror,
                  subtitle:
                      githubMirrorStore.selected?.name ?? t.mirrorOfficial,
                  actionTitle: t.manage,
                  callback: () {
                    showPopUpWidget(
                      App.rootContext,
                      MirrorManagerPage(
                        store: githubMirrorStore,
                        title: t.githubMirror,
                        description: t.githubMirrorDesc,
                        addressHint: 'https://cdn.jsdelivr.net/',
                        allowScope: true,
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProxySettingView extends StatefulWidget {
  const _ProxySettingView();

  @override
  State<_ProxySettingView> createState() => _ProxySettingViewState();
}

class _ProxySettingViewState extends State<_ProxySettingView> {
  /// 手动(HTTP)与 SOCKS5 各自记住上次填写的主机/端口，互不覆盖
  static const _httpImplicitKey = 'proxyHttp';
  static const _socks5ImplicitKey = 'proxySocks5';

  /// 旧版两种手动代理共用的记录键，仅用于一次性迁移
  static const _legacyImplicitKey = 'proxy';

  String type = '';
  String host = '';
  String port = '';
  String username = '';
  String password = '';

  static Map<dynamic, dynamic>? _savedProxyFor(String key) {
    final data = appdata.implicitData[key];
    return data is Map ? data : null;
  }

  void _loadSavedProxy(String key) {
    final data = _savedProxyFor(key);
    host = data?['host']?.toString() ?? '';
    port = data?['port']?.toString() ?? '';
    username = data?['username']?.toString() ?? '';
    password = data?['password']?.toString() ?? '';
    _hostCtrl.text = host;
    _portCtrl.text = port;
    _usernameCtrl.text = username;
    _passwordCtrl.text = password;
  }

  // USERNAME:PASSWORD@HOST:PORT，SOCKS5 时前面加 socks5://
  // （socks5:// 表示本地解析，hosts 设置里钉的 IP 会生效）
  String toProxyStr() {
    if (type == 'direct') {
      return 'direct';
    } else if (type == 'system') {
      return 'system';
    }
    var res = '';
    if (username.isNotEmpty) {
      res += username;
      if (password.isNotEmpty) {
        res += ':$password';
      }
      res += '@';
    }
    res += host;
    if (port.isNotEmpty) {
      res += ':$port';
    }
    if (type == 'socks5') {
      return 'socks5://$res';
    }
    return res;
  }

  void parseProxyString(String proxy) {
    if (proxy == 'direct') {
      type = 'direct';
      return;
    } else if (proxy == 'system') {
      type = 'system';
      return;
    }
    var value = proxy;
    type = 'manual';
    if (value.toLowerCase().startsWith('socks5://')) {
      type = 'socks5';
      value = value.substring('socks5://'.length);
    }
    var parts = value.split('@');
    if (parts.length == 2) {
      var auth = parts[0].split(':');
      if (auth.length == 2) {
        username = auth[0];
        password = auth[1];
      }
      parts = parts[1].split(':');
      if (parts.length == 2) {
        host = parts[0];
        port = parts[1];
      }
    } else {
      parts = value.split(':');
      if (parts.length == 2) {
        host = parts[0];
        port = parts[1];
      }
    }
  }

  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;

  @override
  void initState() {
    var proxy = appdata.settings['proxy'];
    parseProxyString(proxy);
    _hostCtrl = TextEditingController(text: host);
    _portCtrl = TextEditingController(text: port);
    _usernameCtrl = TextEditingController(text: username);
    _passwordCtrl = TextEditingController(text: password);
    // 旧版手动/SOCKS5 共用一个记录，按当前类型搬进各自的键
    if (type == 'manual' || type == 'socks5') {
      final key = type == 'socks5' ? _socks5ImplicitKey : _httpImplicitKey;
      final legacy = _savedProxyFor(_legacyImplicitKey);
      if (_savedProxyFor(key) == null && legacy != null) {
        appdata.implicitData[key] = legacy;
        appdata.writeImplicitData();
      }
    }
    super.initState();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: t.proxy,
      body: SingleChildScrollView(
        child: Column(
          children: [
            RadioGroup<String>(
              groupValue: type,
              onChanged: (v) {
                setState(() {
                  type = v!;
                  if (v == 'manual' || v == 'socks5') {
                    // 各类型读各自的记录，切换时不互相带值
                    _loadSavedProxy(
                      v == 'socks5' ? _socks5ImplicitKey : _httpImplicitKey,
                    );
                  }
                });
                appdata.settings['proxy'] = toProxyStr();
                appdata.saveData();
              },
              child: Column(
                children: [
                  RadioListTile<String>(title: Text(t.direct), value: 'direct'),
                  RadioListTile<String>(title: Text(t.system), value: 'system'),
                  RadioListTile<String>(title: Text(t.manual), value: 'manual'),
                  RadioListTile<String>(
                    title: Text(t.proxySocks5),
                    value: 'socks5',
                  ),
                ],
              ),
            ),

            if (type == 'manual') buildManualProxy(),
            if (type == 'socks5') buildManualProxy(socks5: true),
          ],
        ),
      ),
    );
  }

  var formKey = GlobalKey<FormState>();

  Widget buildManualProxy({bool socks5 = false}) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          if (socks5) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                t.proxySocks5Hint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: t.host,
            ),
            controller: _hostCtrl,
            onChanged: (v) {
              host = v;
            },
            validator: (v) {
              if (v?.isEmpty ?? false) {
                return 'Host cannot be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: t.port,
            ),
            controller: _portCtrl,
            onChanged: (v) {
              port = v;
            },
            validator: (v) {
              if (v?.isEmpty ?? true) {
                return null;
              }
              if (int.tryParse(v!) == null) {
                return 'Port must be a number';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: t.username,
            ),
            controller: _usernameCtrl,
            onChanged: (v) {
              username = v;
            },
            validator: (v) {
              if ((v?.isEmpty ?? false) && password.isNotEmpty) {
                return 'Username cannot be empty';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: t.password,
            ),
            controller: _passwordCtrl,
            onChanged: (v) {
              password = v;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                appdata.settings['proxy'] = toProxyStr();
                appdata.saveData();
                var data = {
                  "host": host,
                  "port": port,
                  "username": username,
                  "password": password,
                };
                appdata.implicitData[type == 'socks5'
                        ? _socks5ImplicitKey
                        : _httpImplicitKey] =
                    data;
                appdata.writeImplicitData();
                App.rootContext.pop();
              }
            },
            child: Text(t.save),
          ),
        ],
      ),
    ).paddingHorizontal(16).paddingTop(16);
  }
}
