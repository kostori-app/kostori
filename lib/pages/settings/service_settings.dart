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
      await _hub.init(preferredPort: port, mode: _bindMode);
    } else {
      await _hub.dispose();
    }
    setState(() => _hubEnabled = _hub.isRunning);
  }

  Future<void> _toggleHubClient(bool value) async {
    if (value) {
      final savedAddress = _hubClient.savedAddress ?? '';
      if (savedAddress.isEmpty) {
        App.rootContext.showMessage(message: t.enterServerAddress);
        return;
      }
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
                if (_hubEnabled)
                  _PopupWindowSetting(
                    title: t.hubManagement,
                    builder: () => _HubManagementPage(),
                  ),
                _UploadConfigSetting(hub: _hub, serverRunning: _hubEnabled),
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
                    trailing: DropdownButton<String>(
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      value:
                          _hubClient.getProfiles().any(
                            (p) => p['address'] == _hubClient.savedAddress,
                          )
                          ? _hubClient.savedAddress
                          : null,
                      hint: const Text('—'),
                      items: [
                        for (final p in _hubClient.getProfiles())
                          DropdownMenuItem(
                            value: p['address'] as String,
                            child: Text(
                              (p['name'] as String?)?.isNotEmpty == true
                                  ? p['name'] as String
                                  : p['address'] as String,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (addr) async {
                        if (addr == null || addr == _hubClient.savedAddress) {
                          return;
                        }
                        if (hubClientEnabled) {
                          await _hubClient.disconnect();
                        }
                        _hubClient.activateProfile(addr);
                        setState(() {});
                        await _toggleHubClient(true);
                      },
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
                _PopupWindowSetting(
                  title: t.hubDetails,
                  builder: () => const _HubClientDetailPage(),
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
