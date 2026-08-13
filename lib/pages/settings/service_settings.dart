part of 'settings_page.dart';

class ServiceSettings extends ConsumerStatefulWidget {
  const ServiceSettings({super.key});

  @override
  ConsumerState<ServiceSettings> createState() => _ServiceSettingsState();
}

class _ServiceSettingsState extends ConsumerState<ServiceSettings> {
  final _service = AppService();
  final _keyManager = ApiKeyManager();

  bool _serviceEnabled = false;
  bool _hubEnabled = false;
  BindMode _bindMode = BindMode.both;
  BindMode _hubBindMode = BindMode.both;

  final _portController = TextEditingController(text: '9000');
  final _hubPortController = TextEditingController(text: '9100');
  final _fixedKeyController = TextEditingController();
  final _hubClientNameController = TextEditingController();
  final _hubTokenController = TextEditingController();
  final _pingIntervalController = TextEditingController();

  bool _keyManagerReady = false;

  late final HubClient _hubClient;
  late final HubService _hub;

  @override
  void initState() {
    super.initState();
    _hubClient = ref.read(hubClientProvider);
    _hub = ref.read(hubServiceProvider);
    _bindMode = _service.savedBindMode;
    _hubBindMode = _hub.savedHubBindMode;
    _portController.text = _service.savedPort.toString();
    _hubPortController.text = _hub.savedHubPort.toString();
    _hubClientNameController.text = _hubClient.savedName ?? '';
    _hubTokenController.text = _hubClient.savedToken ?? '';
    _pingIntervalController.text = _hub.pingInterval.inMilliseconds.toString();
    _initKeyManager();
  }

  @override
  void dispose() {
    _portController.dispose();
    _hubPortController.dispose();
    _fixedKeyController.dispose();
    _hubClientNameController.dispose();
    _hubTokenController.dispose();
    _pingIntervalController.dispose();
    super.dispose();
  }

  Future<void> _initKeyManager() async {
    _fixedKeyController.text = _keyManager.fixedKey ?? '';
    _serviceEnabled = _service.isRunning;
    _hubEnabled = _hub.isRunning;

    // 连接/断开回调只更新非 hub 状态，hub 连接状态由 hubProvider 驱动
    _hubClient.onConnected = () {
      if (mounted) setState(() {});
    };

    _hubClient.onDisconnected = () {
      if (mounted) setState(() {});
      if (_hubClient.shouldReconnect) {
        App.rootContext.showMessage(message: t.connectionDisconnected);
      }
    };

    _hub.onMessageReceived = () {
      if (mounted) setState(() {});
    };

    if (mounted) setState(() => _keyManagerReady = true);
  }

  Future<void> _toggleService(bool value) async {
    if (value) {
      final port = int.tryParse(_portController.text) ?? 9000;
      await _service.init(preferredPort: port, mode: _bindMode);
    } else {
      await _service.dispose();
    }
    setState(() => _serviceEnabled = _service.isRunning);
  }

  Future<void> _toggleHub(bool value) async {
    if (value) {
      final port = int.tryParse(_hubPortController.text) ?? 9100;
      try {
        await _hub.init(preferredPort: port, mode: _hubBindMode);
      } catch (e) {
        App.rootContext.showMessage(
          message: '${t.hubServerStartFailed}: $e',
          level: LogLevel.warning,
        );
      }
    } else {
      await _hub.dispose();
    }
    setState(() => _hubEnabled = _hub.isRunning);
  }

  String get _currentProfileLabel {
    final addr = _hubClient.savedAddress ?? '';
    if (addr.isEmpty) return t.select;
    final nameObj = _hubClient.getProfiles().firstWhereOrNull(
      (p) => p['address'] == addr,
    )?['name'];
    final name = nameObj is String ? nameObj : null;
    return (name?.isNotEmpty == true ? name : addr)!;
  }

  Future<void> _toggleHubClient(bool value) async {
    if (value) {
      final savedAddress = _hubClient.savedAddress ?? '';
      if (savedAddress.isEmpty) {
        App.rootContext.showMessage(message: t.enterServerAddress);
        return;
      }
      // 连接前确保已填写显示名
      final nameOk = await ensureHubNameSet(context);
      if (!nameOk) return;
      try {
        await _hubClient.connect(
          savedAddress,
          _hubClient.savedToken ?? '',
          name: _hubClient.savedName ?? '',
        );
        // 记住当前服务器，方便下次直接切换回来
        _hubClient.saveProfile(
          name: Uri.tryParse(savedAddress)?.host ?? savedAddress,
          address: savedAddress,
          token: _hubClient.savedToken ?? '',
        );
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          App.rootContext.showMessage(
            message: t.connectionFailed,
            level: LogLevel.warning,
          );
        }
      }
    } else {
      await _hubClient.disconnect();
    }
  }

  /// 已保存服务器选择（底部弹窗）
  Future<void> _showHubProfilePicker() async {
    final profiles = _hubClient.getProfiles();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Sheet(
        title: t.savedServers,
        icon: Icons.history_outlined,
        builder: (context, sc) {
          if (profiles.isEmpty) {
            return Center(child: HubEmptyHint(t.noSavedServers));
          }
          return ListView.builder(
            controller: sc,
            itemCount: profiles.length,
            itemBuilder: (context, i) {
              final p = profiles[i];
              final isCurrent = p['address'] == _hubClient.savedAddress;
              return ListTile(
                leading: Icon(
                  isCurrent
                      ? Icons.radio_button_checked
                      : Icons.circle_outlined,
                  size: 18,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  (p['name'] as String?)?.isNotEmpty == true
                      ? p['name'] as String
                      : p['address'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  p['address'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                trailing: isCurrent
                    ? Text(
                        t.current,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(context, p),
              );
            },
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    final addr = result['address'] as String? ?? '';
    if (addr.isEmpty || addr == _hubClient.savedAddress) return;
    if (ref.read(hubProvider).isConnected) await _hubClient.disconnect();
    _hubClient.activateProfile(addr);
    setState(() {});
    await _toggleHubClient(true);
  }

  @override
  Widget build(BuildContext context) {
    final hubState = ref.watch(hubProvider);
    final hubClientEnabled = hubState.isConnected;

    if (!_keyManagerReady) {
      return const Scaffold(body: Center(child: PolygonRefreshIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text(t.serviceSettings)),
          // ── API Key ──────────────────────────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(title: t.apiKey, icon: Icons.key_outlined),

                // ── 用户层 Key ──────────────────────
                _ApiKeyTile(
                  keyManager: _keyManager,
                  onRegenerate: () {
                    _keyManager.regenerateRandomKey();
                    setState(() {});
                  },
                ),

                // ── 管理层 Key ──────────────────────
                _ApiKeyTile(
                  keyManager: _keyManager,
                  isAdmin: true,
                  onRegenerate: () {
                    _keyManager.regenerateAdminRandomKey();
                    setState(() {});
                  },
                ),

                // ── 统一固定 Key 开关 ───────────────
                _SettingRow(
                  title: t.useFixedKey,
                  subtitle: _keyManager.isUsingFixed
                      ? t.keepTheSameKeysAfterRestart
                      : t.regeneratedOnEveryStartup,
                  trailing: CustomSwitch(
                    value: _keyManager.isUsingFixed,
                    onChanged: (val) async {
                      if (val && !_keyManager.isUsingFixed) {
                        final error1 = await _keyManager.setFixedKey(
                          _keyManager.randomKey ?? '',
                        );
                        final error2 = await _keyManager.setAdminFixedKey(
                          _keyManager.adminRandomKey ?? '',
                        );
                        final error = error1 ?? error2;
                        if (error != null && mounted) {
                          App.rootContext.showMessage(message: error);
                          return;
                        }
                      }
                      await _keyManager.setUseFixed(val);
                      await _keyManager.setUseAdminFixed(val);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          // ── AppService ───────────────────────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.service,
                  icon: Icons.miscellaneous_services_outlined,
                ),
                _SettingRow(
                  title: t.enableService,
                  subtitle: _serviceEnabled
                      ? "${t.runningOn} ${_service.boundAddresses.join(' | ')}"
                      : t.serviceIsStopped,
                  trailing: CustomSwitch(
                    value: _serviceEnabled,
                    onChanged: _toggleService,
                  ),
                ),
                _SettingRow(
                  title: t.portAndBindMode,
                  subtitle: t.defaultP(p: "9000  (1024 - 65535)"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BindModeSelector(
                        value: _bindMode,
                        enabled: !_serviceEnabled,
                        onChanged: (mode) {
                          setState(() => _bindMode = mode);
                          _service.saveServiceBindMode(mode);
                        },
                      ),
                      const SizedBox(width: 8),
                      _NumberInput(
                        controller: _portController,
                        enabled: !_serviceEnabled,
                        onChanged: (port) => _service.savePort(port),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Hub 服务端 ───────────────────────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(title: t.hubServer, icon: Icons.hub_outlined),
                _SettingRow(
                  title: t.enableHub,
                  subtitle: _hubEnabled
                      ? "${t.runningOn} ${_hub.boundAddresses.join(' | ')}  "
                            "(${_hub.clientCount} ${t.clientsCount})"
                      : t.hubServerIsStopped,
                  trailing: CustomSwitch(
                    value: _hubEnabled,
                    onChanged: _toggleHub,
                  ),
                ),
                _SettingRow(
                  title: t.noKeyRequired,
                  subtitle: _hub.hubNoAuth
                      ? t.anyoneCanConnectWithoutApiKey
                      : t.clientsMustProvideAValidApiKey,
                  trailing: CustomSwitch(
                    value: _hub.hubNoAuth,
                    onChanged: (val) {
                      _hub.setHubNoAuth(val);
                      setState(() {});
                    },
                  ),
                ),
                _SettingRow(
                  title: t.portAndBindMode,
                  subtitle: t.defaultP(p: "9100  (1024 - 65535)"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BindModeSelector(
                        value: _hubBindMode,
                        enabled: !_hubEnabled,
                        onChanged: (mode) {
                          setState(() => _hubBindMode = mode);
                          _hub.saveHubBindMode(mode);
                        },
                      ),
                      const SizedBox(width: 8),
                      _NumberInput(
                        controller: _hubPortController,
                        enabled: !_hubEnabled,
                        onChanged: (port) => _hub.saveHubPort(port),
                      ),
                    ],
                  ),
                ),
                _SettingRow(
                  title: t.pingInterval,
                  subtitle: t.defaultP(p: "30000ms"),
                  trailing: _NumberInput(
                    controller: _pingIntervalController,
                    enabled: !_hubEnabled,
                    min: 60000,
                    max: 86400000,
                    onChanged: (v) {
                      if (v >= 1000) _hub.setPingInterval(v);
                    },
                  ),
                ),
                _PopupWindowSetting(
                  title: t.enableTls,
                  builder: () => _HubTlsPage(hub: _hub),
                  onClosed: () {
                    if (mounted) setState(() {});
                  },
                ),
                if (_hubEnabled)
                  _PopupWindowSetting(
                    title: t.hubManagement,
                    builder: () => _HubManagementPage(),
                  ),
                _PopupWindowSetting(
                  title: t.imageUpload,
                  builder: () => _HubUploadPage(hub: _hub),
                  onClosed: () {
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
          // ── Hub 客户端 ───────────────────────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: t.hubClient,
                  icon: Icons.devices_outlined,
                ),
                _SettingRow(
                  title: t.connectToHub,
                  subtitle: hubClientEnabled
                      ? '${t.connected}  ID: ${hubState.myId ?? '-'}'
                      : (t.notConnected +
                            (_hubClient.savedAddress?.isNotEmpty == true
                                ? '  ·  ${_hubClient.savedAddress}'
                                : '')),
                  trailing: FilledButton.icon(
                    icon: Icon(
                      hubClientEnabled ? Icons.link_off : Icons.link,
                      size: 16,
                    ),
                    label: Text(hubClientEnabled ? t.disconnect : t.connect),
                    onPressed: () => _toggleHubClient(!hubClientEnabled),
                  ),
                ),
                if (_hubClient.getProfiles().isNotEmpty)
                  _SettingRow(
                    title: t.savedServers,
                    subtitle: _hubClient.savedAddress ?? t.selectServer,
                    trailing: OutlinedButton.icon(
                      icon: const Icon(Icons.expand_more, size: 16),
                      label: Text(
                        _currentProfileLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _showHubProfilePicker,
                    ),
                  ),
                _SettingRow(
                  title: t.autoReconnect,
                  trailing: CustomSwitch(
                    value: _hubClient.autoReconnect,
                    onChanged: (v) {
                      setState(() => _hubClient.autoReconnect = v);
                    },
                  ),
                ),
                _SettingRow(
                  title: t.allowSelfSignedCert,
                  subtitle: t.allowSelfSignedCertHint,
                  trailing: CustomSwitch(
                    value: _hubClient.allowSelfSignedCert,
                    onChanged: (v) {
                      setState(() => _hubClient.allowSelfSignedCert = v);
                    },
                  ),
                ),
                _SettingRow(
                  title: t.editProfile,
                  subtitle: () {
                    final n = _hubClient.savedName;
                    return (n == null || n.trim().isEmpty) ? t.notSet : n;
                  }(),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: t.editProfile,
                    onPressed: () async {
                      await showHubProfileEditDialog(_hubClient);
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                _PopupWindowSetting(
                  title: t.hubDetails,
                  builder: () => const HubClientDetailPage(),
                  onClosed: () {
                    if (mounted) setState(() {});
                  },
                ),
                if (hubClientEnabled)
                  _SettingRow(
                    title: t.chatRoom,
                    subtitle: t.openChatDialog,
                    trailing: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      onPressed: () =>
                          showPopUpWidget(context, const HubPage()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hub 服务端 HTTPS/WSS 二级设置页
class _HubTlsPage extends ConsumerStatefulWidget {
  const _HubTlsPage({required this.hub});

  final HubService hub;

  @override
  ConsumerState<_HubTlsPage> createState() => _HubTlsPageState();
}

class _HubTlsPageState extends ConsumerState<_HubTlsPage> {
  late final TextEditingController _certCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _passwordCtrl;

  HubService get _hub => widget.hub;

  @override
  void initState() {
    super.initState();
    _certCtrl = TextEditingController(text: _hub.tlsCertificatePath ?? '');
    _keyCtrl = TextEditingController(text: _hub.tlsPrivateKeyPath ?? '');
    _passwordCtrl = TextEditingController(text: _hub.tlsPassword ?? '');
  }

  @override
  void dispose() {
    _certCtrl.dispose();
    _keyCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile(
    TextEditingController ctrl,
    void Function(String) save,
  ) async {
    final r = await FilePicker.pickFiles();
    if (r != null && r.files.isNotEmpty && r.files.first.path != null) {
      ctrl.text = r.files.first.path!;
      save(r.files.first.path!);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopUpWidgetScaffold(
      title: t.enableTls,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: cs.outlineVariant, width: 0.6),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t.enableTls,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _hub.tlsEnabled ? t.tlsEnabledDesc : t.tlsDisabledDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: CustomSwitch(
                        value: _hub.tlsEnabled,
                        onChanged: (val) {
                          _hub.setTlsEnabled(val);
                          setState(() {});
                        },
                      ),
                    ),
                    if (_hub.tlsEnabled) ...[
                      const Divider(height: 24),
                      const SizedBox(height: 8),
                      Text(
                        t.tlsCertificate,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.tlsCertificateHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _certCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                _hub.setTlsCertificatePath(v.trim());
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: 18),
                            tooltip: t.browse,
                            onPressed: () => _pickFile(
                              _certCtrl,
                              _hub.setTlsCertificatePath,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.tlsPrivateKey,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.tlsPrivateKeyHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _keyCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                _hub.setTlsPrivateKeyPath(v.trim());
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open, size: 18),
                            tooltip: t.browse,
                            onPressed: () =>
                                _pickFile(_keyCtrl, _hub.setTlsPrivateKeyPath),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.tlsPassword,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        t.tlsPasswordHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _hub.setTlsPassword(v);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
