part of 'settings_page.dart';

class ServiceSettings extends StatefulWidget {
  const ServiceSettings({super.key});

  @override
  State<ServiceSettings> createState() => _ServiceSettingsState();
}

class _ServiceSettingsState extends State<ServiceSettings> {
  final _service = AppService();
  final _keyManager = ApiKeyManager();
  final _hub = HubService();
  final _hubClient = HubClient();

  bool _serviceEnabled = false;
  bool _hubEnabled = false;
  bool _hubClientEnabled = false;
  BindMode _bindMode = BindMode.both;
  BindMode _hubBindMode = BindMode.both;

  final _portController = TextEditingController(text: '9000');
  final _hubPortController = TextEditingController(text: '9100');
  final _fixedKeyController = TextEditingController();
  final _hubClientNameController = TextEditingController();
  final _hubTokenController = TextEditingController();

  bool _keyManagerReady = false;

  @override
  void initState() {
    super.initState();
    _bindMode = _service.savedBindMode;
    _hubBindMode = _hub.savedHubBindMode;
    _portController.text = _service.savedPort.toString();
    _hubPortController.text = _hub.savedHubPort.toString();
    _hubClientNameController.text = _hubClient.savedName ?? '';
    _hubTokenController.text = _hubClient.savedToken ?? '';
    _initKeyManager();
  }

  @override
  void dispose() {
    _portController.dispose();
    _hubPortController.dispose();
    _fixedKeyController.dispose();
    _hubClientNameController.dispose();
    _hubTokenController.dispose();
    super.dispose();
  }

  Future<void> _initKeyManager() async {
    _fixedKeyController.text = _keyManager.fixedKey ?? '';
    _serviceEnabled = _service.isRunning;
    _hubEnabled = _hub.isRunning;
    _hubClientEnabled = _hubClient.isConnected;

    _hubClient.onConnected = () {
      if (mounted) setState(() => _hubClientEnabled = true);
    };

    _hubClient.onDisconnected = () {
      if (mounted) {
        setState(() => _hubClientEnabled = false);
        // ← 只要断开就提示
        if (_hubClientEnabled) {
          App.rootContext.showMessage(message: '与服务端的连接已断开'.tl);
        }
      }
    };

    _hub.onMessageReceived = () {
      if (mounted) setState(() {});
    };

    _hubClient.onMessage = (data) {
      if (!mounted) return;
      // toast 已由 handler 统一处理，这里只刷新 UI
      setState(() {});
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
        App.rootContext.showMessage(message: '请输入服务端地址'.tl);
        return;
      }
      try {
        await _hubClient.connect(
          savedAddress,
          _hubClient.savedToken ?? '',
          name: _hubClient.savedName ?? '',
        );
      } catch (e) {
        if (mounted) {
          App.rootContext.showMessage(message: '连接失败：$e');
        }
        return;
      }
    } else {
      await _hubClient.disconnect();
    }
    if (mounted) setState(() => _hubClientEnabled = _hubClient.isConnected);
  }

  @override
  Widget build(BuildContext context) {
    if (!_keyManagerReady) {
      return const Scaffold(body: Center(child: PolygonRefreshIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text("Service Settings".tl)),
          // ── API Key ─────────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "API Key".tl,
                  icon: Icons.key_outlined,
                ),
                _ApiKeyTile(
                  keyManager: _keyManager,
                  onRegenerate: () {
                    _keyManager.regenerateRandomKey();
                    setState(() {});
                  },
                ),
                _SettingRow(
                  title: "Use Fixed Key".tl,
                  subtitle: _keyManager.isUsingFixed
                      ? "Keep the same key after restart".tl
                      : "Regenerated on every startup".tl,
                  trailing: CustomSwitch(
                    value: _keyManager.isUsingFixed,
                    onChanged: (val) async {
                      if (val && !_keyManager.isUsingFixed) {
                        final error = await _keyManager.setFixedKey(
                          _keyManager.randomKey ?? '',
                        );
                        if (error != null && mounted) {
                          App.rootContext.showMessage(message: error);
                          return;
                        }
                      }
                      await _keyManager.setUseFixed(val);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          // ── AppService ──────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Service".tl,
                  icon: Icons.miscellaneous_services_outlined,
                ),
                _SettingRow(
                  title: "Enable Service".tl,
                  subtitle: _serviceEnabled
                      ? "${"Running on".tl} ${_service.boundAddresses.join(' | ')}"
                      : "Service is stopped".tl,
                  trailing: CustomSwitch(
                    value: _serviceEnabled,
                    onChanged: _toggleService,
                  ),
                ),
                _SettingRow(
                  title: "Port & Bind Mode".tl,
                  subtitle: "Default: @p".tlParams({
                    "p": "9000  (1024 - 65535)",
                  }),
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
                      _PortInput(
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

          // ── Hub 服务端 ───────────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Hub Server".tl,
                  icon: Icons.hub_outlined,
                ),
                _SettingRow(
                  title: "Enable Hub".tl,
                  subtitle: _hubEnabled
                      ? "${"Running on".tl} ${_hub.boundAddresses.join(' | ')}  "
                            "(${_hub.clientCount} ${"clients".tl})"
                      : "Hub server is stopped".tl,
                  trailing: CustomSwitch(
                    value: _hubEnabled,
                    onChanged: _toggleHub,
                  ),
                ),
                _SettingRow(
                  title: "Port & Bind Mode".tl,
                  subtitle: "Default: @p".tlParams({
                    "p": "9100  (1024 - 65535)",
                  }),
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
                      _PortInput(
                        controller: _hubPortController,
                        enabled: !_hubEnabled,
                        onChanged: (port) => _hub.saveHubPort(port),
                      ),
                    ],
                  ),
                ),
                if (_hubEnabled) ...[
                  _PopupWindowSetting(
                    title: "Hub Management".tl,
                    builder: () => _HubManagementPage(),
                  ),
                ],
              ],
            ),
          ),

          // ── Hub 客户端入口卡片 ──────────────────────────────
          _BuildSectionPadding(
            _SettingCard(
              children: [
                _SettingPartTitle(
                  title: "Hub Client".tl,
                  icon: Icons.devices_outlined,
                ),
                _SettingRow(
                  title: "Connect to Hub".tl,
                  subtitle: _hubClientEnabled
                      ? "${"Connected".tl}  ID: ${_hubClient.myId ?? '-'}"
                      : "Not connected".tl,
                  trailing: CustomSwitch(
                    value: _hubClientEnabled,
                    onChanged: _toggleHubClient,
                  ),
                ),
                _PopupWindowSetting(
                  title: "Hub Details".tl,
                  builder: () => const _HubClientDetailPage(),
                ),
                if (_hubClientEnabled)
                  _SettingRow(
                    title: "Chat Room".tl,
                    subtitle: "Open chat dialog".tl,
                    trailing: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      onPressed: () => HubChatDialog.show(context),
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
