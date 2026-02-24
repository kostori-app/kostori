part of 'settings_page.dart';

class NetworkSettings extends StatefulWidget {
  const NetworkSettings({super.key});

  @override
  State<NetworkSettings> createState() => _NetworkSettingsState();
}

class _NetworkSettingsState extends State<NetworkSettings> {
  @override
  Widget build(BuildContext context) {
    return SmoothCustomScrollView(
      slivers: [
        SliverAppbar(title: Text("Network".tl)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: _SettingCard(
              children: [
                _PopupWindowSetting(
                  title: "Proxy".tl,
                  builder: () => const _ProxySettingView(),
                ),
                _PopupWindowSetting(
                  title: "DNS Overrides".tl,
                  builder: () => const _DNSOverrides(),
                ),
                _PopupWindowSetting(
                  title: "No Proxy Overrides".tl,
                  builder: () => const _NoProxyOverrides(),
                ),
                _SwitchSetting(
                  title: "Ignore Certificate Errors".tl,
                  settingKey: "ignoreBadCertificate",
                ),
                _SliderSetting(
                  title: "Download Threads".tl,
                  settingsIndex: 'downloadThreads',
                  interval: 1,
                  min: 1,
                  max: 16,
                ),
                const SizedBox(height: 8),
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
  String type = '';
  String host = '';
  String port = '';
  String username = '';
  String password = '';

  // USERNAME:PASSWORD@HOST:PORT
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
    type = 'manual';
    var parts = proxy.split('@');
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
      parts = proxy.split(':');
      if (parts.length == 2) {
        host = parts[0];
        port = parts[1];
      }
    }
  }

  @override
  void initState() {
    var proxy = appdata.settings['proxy'];
    parseProxyString(proxy);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "Proxy".tl,
      body: SingleChildScrollView(
        child: Column(
          children: [
            RadioGroup<String>(
              groupValue: type,
              onChanged: (v) {
                setState(() {
                  type = v!;
                  if (v == 'manual') {
                    if (host.isEmpty && port.isEmpty) {
                      if (appdata.implicitData['proxy'] != null) {
                        var data = appdata.implicitData['proxy'];
                        host = data['host'];
                        port = data['port'];
                        username = data['username'];
                        password = data['password'];
                      }
                    }
                  }
                });
                appdata.settings['proxy'] = toProxyStr();
                appdata.saveData();
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Text("Direct".tl),
                    value: 'direct',
                  ),
                  RadioListTile<String>(
                    title: Text("System".tl),
                    value: 'system',
                  ),
                  RadioListTile<String>(
                    title: Text("Manual".tl),
                    value: 'manual',
                  ),
                ],
              ),
            ),

            if (type == 'manual') buildManualProxy(),
          ],
        ),
      ),
    );
  }

  var formKey = GlobalKey<FormState>();

  Widget buildManualProxy() {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "Host".tl,
            ),
            controller: TextEditingController(text: host),
            onChanged: (v) {
              host = v;
            },
            validator: (v) {
              if (v?.isEmpty ?? false) {
                return "Host cannot be empty".tl;
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "Port".tl,
            ),
            controller: TextEditingController(text: port),
            onChanged: (v) {
              port = v;
            },
            validator: (v) {
              if (v?.isEmpty ?? true) {
                return null;
              }
              if (int.tryParse(v!) == null) {
                return "Port must be a number".tl;
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "Username".tl,
            ),
            controller: TextEditingController(text: username),
            onChanged: (v) {
              username = v;
            },
            validator: (v) {
              if ((v?.isEmpty ?? false) && password.isNotEmpty) {
                return "Username cannot be empty".tl;
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "Password".tl,
            ),
            controller: TextEditingController(text: password),
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
                appdata.implicitData['proxy'] = data;
                appdata.writeImplicitData();
                App.rootContext.pop();
              }
            },
            child: Text("Save".tl),
          ),
        ],
      ),
    ).paddingHorizontal(16).paddingTop(16);
  }
}

class _DNSOverrides extends StatefulWidget {
  const _DNSOverrides();

  @override
  State<_DNSOverrides> createState() => __DNSOverridesState();
}

class __DNSOverridesState extends State<_DNSOverrides> {
  var overrides = <(bool, TextEditingController, TextEditingController)>[];

  @override
  void initState() {
    super.initState();

    final stored = appdata.settings['dnsOverrides'] as Map? ?? {};

    for (var entry in stored.entries) {
      if (entry.key is String && entry.value is Map) {
        final ip = (entry.value['ip'] ?? '') as String;
        final enabled = (entry.value['enabled'] ?? true) as bool;
        overrides.add((
          enabled,
          TextEditingController(text: entry.key),
          TextEditingController(text: ip),
        ));
      } else if (entry.key is String && entry.value is String) {
        overrides.add((
          true,
          TextEditingController(text: entry.key),
          TextEditingController(text: entry.value),
        ));
      }
    }
  }

  void _saveData() {
    final map = <String, Map<String, dynamic>>{};

    for (var entry in overrides) {
      map[entry.$2.text] = {'ip': entry.$3.text, 'enabled': entry.$1};
    }

    appdata.settings['dnsOverrides'] = map;
    appdata.saveData();
    JsEngine().resetDio();
  }

  @override
  void dispose() {
    for (var entry in overrides) {
      entry.$2.dispose();
      entry.$3.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "DNS Overrides".tl,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _SwitchSetting(
              title: "Enable DNS Overrides".tl,
              settingKey: "enableDnsOverrides",
            ),
            _SwitchSetting(
              title: "Server Name Indication".tl,
              settingKey: "sni",
            ),
            const SizedBox(height: 8),
            Divider(color: context.colorScheme.outlineVariant, height: 1),
            for (var i = 0; i < overrides.length; i++) buildOverride(i),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  overrides.add((
                    true,
                    TextEditingController(),
                    TextEditingController(),
                  ));
                });
              },
              icon: const Icon(Icons.add),
              label: Text("Add".tl),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOverride(int index) {
    var entry = overrides[index];

    return Card(
      key: ValueKey(index),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: entry.$2,
              decoration: InputDecoration(
                labelText: "Domain".tl,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // IP
                Expanded(
                  child: TextField(
                    controller: entry.$3,
                    decoration: InputDecoration(
                      labelText: "IP".tl,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 开关
                _InlineSwitch(
                  value: entry.$1,
                  onChanged: (v) {
                    setState(() {
                      overrides[index] = (v, entry.$2, entry.$3);
                      _saveData();
                    });
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() {
                      entry.$2.dispose();
                      entry.$3.dispose();
                      overrides.removeAt(index);
                      _saveData();
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoProxyOverrides extends StatefulWidget {
  const _NoProxyOverrides();

  @override
  State<_NoProxyOverrides> createState() => __NoProxyOverridesState();
}

class __NoProxyOverridesState extends State<_NoProxyOverrides> {
  var overrides = <(bool, TextEditingController)>[];

  @override
  void initState() {
    super.initState();
    final stored = appdata.settings['noProxyOverrides'] as List? ?? [];
    overrides = [];

    for (var i = 0; i < stored.length; i++) {
      final e = stored[i];
      if (e is Map) {
        final domain = e['domain']?.toString() ?? '';
        final enabled = e['enabled'] as bool? ?? true;
        overrides.add((enabled, TextEditingController(text: domain)));
      } else {
        overrides.add((true, TextEditingController(text: e.toString())));
      }
    }
  }

  void _saveData() {
    final list = <Map<String, dynamic>>[];
    for (var entry in overrides) {
      list.add({'domain': entry.$2.text, 'enabled': entry.$1});
    }
    appdata.settings['noProxyOverrides'] = list;
    appdata.saveData();
    JsEngine().resetDio();
  }

  @override
  void dispose() {
    for (var entry in overrides) {
      entry.$2.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopUpWidgetScaffold(
      title: "No Proxy Overrides".tl,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _SwitchSetting(
              title: "Enable No Proxy Overrides".tl,
              settingKey: "enableNoProxyOverrides",
            ),
            const SizedBox(height: 8),
            Divider(color: context.colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 8),
            for (var i = 0; i < overrides.length; i++) buildOverride(i),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text("Add".tl),
              onPressed: () {
                setState(() {
                  overrides.add((true, TextEditingController()));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOverride(int index) {
    final entry = overrides[index];

    return Card(
      key: ValueKey(index),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: entry.$2,
                decoration: InputDecoration(
                  labelText: "Domain".tl,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => _saveData(),
              ),
            ),
            const SizedBox(width: 8),
            _InlineSwitch(
              value: entry.$1,
              onChanged: (v) {
                setState(() {
                  overrides[index] = (v, entry.$2);
                  _saveData();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  entry.$2.dispose();
                  overrides.removeAt(index);
                  _saveData();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineSwitch extends StatelessWidget {
  const _InlineSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CustomSwitch(value: value, onChanged: onChanged),
    );
  }
}
