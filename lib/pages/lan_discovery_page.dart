import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/pages/anime_details_page/anime_page.dart';
import 'package:kostori/pages/main_page.dart';
import 'package:kostori/pages/search_page.dart';
import 'package:kostori/pages/settings/settings_page.dart';
import 'package:kostori/pages/watcher/watcher.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

class _LanPlayerControlHandler implements LanPlayerControlHandler {
  @override
  Future<Map<String, dynamic>?> handle(
    PlayerControlAction action,
    dynamic value,
  ) async {
    final watcher = _getWatcher();
    if (watcher == null) return {'error': '播放器未打开'};

    final controller = watcher.playerController;
    switch (action) {
      case PlayerControlAction.play:
        await controller.player.play();
        break;
      case PlayerControlAction.pause:
        await controller.player.pause();
        break;
      case PlayerControlAction.toggle:
        await controller.player.playOrPause();
        break;
      case PlayerControlAction.seek:
        await controller.player.seek(Duration(seconds: (value as num).toInt()));
        break;
      case PlayerControlAction.seekForward:
        final seconds = (value as num?)?.toInt() ?? 10;
        await controller.player.seek(
          controller.player.state.position + Duration(seconds: seconds),
        );
        break;
      case PlayerControlAction.seekBackward:
        final seconds = (value as num?)?.toInt() ?? 10;
        await controller.player.seek(
          controller.player.state.position - Duration(seconds: seconds),
        );
        break;
      case PlayerControlAction.setVolume:
        await controller.player.setVolume((value as num).toDouble());
        break;
      case PlayerControlAction.setSpeed:
        await controller.player.setRate((value as num).toDouble());
        break;
      case PlayerControlAction.nextEpisode:
        await watcher.playNextEpisode();
        break;
      case PlayerControlAction.previousEpisode:
        if (controller.player.state.position.inSeconds > 10) {
          await controller.player.seek(Duration.zero);
        } else {
          await watcher.playNextEpisode();
        }
        break;
      case PlayerControlAction.setQuality:
        break;
    }
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>?> selectEpisode(
    int animeId,
    String source,
    int episode,
    String? episodeId,
    bool autoPlay,
  ) async {
    final watcher = _getWatcher();
    if (watcher == null) return {'error': '播放器未打开'};
    final controller = watcher.watcherController;
    final episodes = controller.anime?.episode;
    if (episodes == null) return {'error': '无集数信息'};
    int roadIndex = 0;
    int episodeIndex = episode - 1;
    if (episodeIndex >= 0) {
      await watcher.loadInfo(episodeIndex, roadIndex);
      if (autoPlay) await watcher.playerController.player.play();
    }
    return {'success': true, 'episode': episode};
  }

  @override
  PlayerStatus? getCurrentStatus() {
    final watcher = _getWatcher();
    if (watcher == null) return null;
    final p = watcher.playerController.player.state;
    return PlayerStatus(
      isPlaying: p.playing,
      position: p.position.inSeconds.toDouble(),
      duration: p.duration.inSeconds.toDouble(),
      volume: p.volume,
      speed: p.rate,
    );
  }

  @override
  CurrentAnime? getCurrentAnime() {
    final watcher = _getWatcher();
    if (watcher == null) return null;
    final anime = watcher.anime;
    return CurrentAnime(
      animeId: int.tryParse(anime.id) ?? 0,
      source: anime.sourceKey,
      title: anime.title,
      currentEpisode: watcher.epIndex,
      coverUrl: anime.cover,
    );
  }

  WatcherState? _getWatcher() => WatcherState.currentState;
}

final lanDiscoveryProvider = ChangeNotifierProvider<LanDiscoveryController>((
  ref,
) {
  return LanDiscoveryController();
});

class LanDiscoveryController extends ChangeNotifier {
  LanDiscoveryController() {
    _init();
  }

  final LanDiscoveryService _service = LanDiscoveryService.instance;
  Timer? _qrRefreshTimer;

  bool _isInitialized = false;
  LanDiscoveryServiceState _serviceState = LanDiscoveryServiceState.idle;
  final List<LanDiscoveredDevice> _devices = [];
  LanDiscoveredDevice? _selectedDevice;
  String? _qrContent;
  int _qrRemainingSeconds = 0;
  bool _isConnecting = false;
  bool _isRefreshing = false;

  bool get isInitialized => _isInitialized;

  LanDiscoveryServiceState get serviceState => _serviceState;

  List<LanDiscoveredDevice> get devices => _devices;

  LanDiscoveredDevice? get selectedDevice => _selectedDevice;

  String? get qrContent => _qrContent;

  int get qrRemainingSeconds => _qrRemainingSeconds;

  bool get isConnecting => _isConnecting;

  bool get isRefreshing => _isRefreshing;

  void _init() {
    _service.addDeviceDiscoveredListener(_onDeviceDiscovered);
    _service.addDeviceLeftListener(_onDeviceLeft);
    _service.addStateChangedListener(_onStateChanged);
    _service.addPairingRequestListener(_onPairingRequest);
    LanControlService.instance.setNavigationHandler(_onNavigationRequest);
    LanControlService.instance.setPlayerHandler(_LanPlayerControlHandler());
  }

  Future<void> _onNavigationRequest(
    NavigateTarget target,
    Map<String, dynamic>? params,
  ) async {
    switch (target) {
      case NavigateTarget.animeDetail:
        final id = params?['id'] ?? params?['animeId'];
        final source = params?['source'] as String? ?? 'bangumi';
        if (id != null) {
          App.mainNavigatorKey?.currentContext?.to(
            () => AnimePage(id: id.toString(), sourceKey: source),
          );
        }
        break;
      case NavigateTarget.search:
        App.mainNavigatorKey?.currentContext?.to(() => const SearchPage());
        break;
      case NavigateTarget.bangumi:
        App.rootContext.toReplacement(() => const MainPage());
        break;
      case NavigateTarget.settings:
        App.mainNavigatorKey?.currentContext?.to(() => const SettingsPage());
        break;
      case NavigateTarget.exitPlayer:
        if (WatcherState.currentState != null) {
          App.pop();
        }
        break;
    }
  }

  void _onDeviceDiscovered(LanDiscoveredDevice device) {
    if (LanControlClient.instance.isConnected) return;

    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx >= 0) {
      _devices[idx] = device;
    } else {
      _devices.add(device);
    }
    notifyListeners();
  }

  void _onDeviceLeft(LanDiscoveredDevice device) {
    _devices.removeWhere((d) => d.id == device.id);
    if (_selectedDevice?.id == device.id) {
      _selectedDevice = null;
    }
    notifyListeners();
  }

  void _onStateChanged(LanDiscoveryServiceState s, String? _) {
    _serviceState = s;
    notifyListeners();
  }

  void _onPairingRequest(LanPairingRequest request) {
    showDialog(
      context: App.rootContext,
      builder: (ctx) => ContentDialog(
        title: t.lanPairingRequestReceived,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.lanDevice}: ${request.requesterName}'),
            Text('ID: ${request.requesterId}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.lanAccept),
          ),
        ],
      ),
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _service.init(
      deviceId: _getDeviceId(),
      deviceName: _getDeviceName(),
      deviceType: _getDeviceType(),
      capabilities: {'remoteControl': true, 'qrPairing': true, 'wsHub': true},
      hubPort: _getHubPort(),
    );
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> startDiscovery() async {
    if (!_isInitialized) {
      await initialize();
    }

    _isRefreshing = true;
    notifyListeners();

    await _service.startDiscovery();
    await Future.delayed(const Duration(milliseconds: 500));
    _isRefreshing = false;
    notifyListeners();
  }

  void stopDiscovery() => _service.stopDiscovery();

  Future<void> refresh() async {
    _isRefreshing = true;
    notifyListeners();
    await _service.refresh();
    await Future.delayed(const Duration(milliseconds: 500));
    _isRefreshing = false;
    notifyListeners();
  }

  void generatePairingQr() {
    if (!_isInitialized) {
      initialize().then((_) => generatePairingQr());
      return;
    }

    _qrRefreshTimer?.cancel();
    _qrContent = _service.generatePairingQrContent();
    _qrRemainingSeconds = 10;
    notifyListeners();

    _qrRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _qrRemainingSeconds--;
      if (_qrRemainingSeconds <= 0) {
        generatePairingQr();
      } else {
        notifyListeners();
      }
    });
  }

  void stopPairingQr() {
    _qrRefreshTimer?.cancel();
    _qrContent = null;
    _qrRemainingSeconds = 0;
    notifyListeners();
  }

  Future<void> reinitialize(int newPort) async {
    _isInitialized = false;
    await _service.init(
      deviceId: _getDeviceId(),
      deviceName: _getDeviceName(),
      deviceType: _getDeviceType(),
      capabilities: {'remoteControl': true, 'qrPairing': true, 'wsHub': true},
      hubPort: newPort,
    );
    _isInitialized = true;
    generatePairingQr();
    notifyListeners();
  }

  void selectDevice(LanDiscoveredDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<void> connectToDevice(LanDiscoveredDevice device) async {
    if (_isConnecting) return;
    _isConnecting = true;
    notifyListeners();

    try {
      await LanControlClient.instance.connect(device);
      _selectedDevice = device;
      App.rootContext.showMessage(message: t.lanRemoteControlConnected);
      _service.stopDiscovery();
      _serviceState = LanDiscoveryServiceState.idle;
    } catch (e) {
      App.rootContext.showMessage(message: t.lanRemoteControlConnectionFailed);
      _selectedDevice = null;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void disconnectFromDevice() {
    LanControlClient.instance.disconnect();
    _selectedDevice = null;
    notifyListeners();
  }

  Future<void> disconnectControlledSession() async {
    LanControlService.instance.stop();
    final port = _getHubPort();
    await LanControlService.instance.start(port);
    notifyListeners();
  }

  String _getDeviceId() {
    var id = appdata.implicitData['lan_device_id'] as String?;
    if (id == null) {
      id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      appdata.implicitData['lan_device_id'] = id;
      appdata.writeImplicitData();
    }
    return id;
  }

  String _getDeviceName() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return Platform.localHostname;
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'Mobile Device';
    }
    return 'Unknown Device';
  }

  LanDeviceType _getDeviceType() {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return LanDeviceType.desktop;
    } else if (Platform.isAndroid || Platform.isIOS) {
      return LanDeviceType.mobile;
    }
    return LanDeviceType.unknown;
  }

  int _getHubPort() =>
      appdata.implicitData['lan_discovery_port'] as int? ?? 42183;

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _service.stopDiscovery();
    if (LanControlService.instance.connectionCount == 0) {
      LanControlService.instance.stop();
    }
    _service.removeDeviceDiscoveredListener(_onDeviceDiscovered);
    _service.removeDeviceLeftListener(_onDeviceLeft);
    _service.removeStateChangedListener(_onStateChanged);
    _service.removePairingRequestListener(_onPairingRequest);
    super.dispose();
  }
}

class LanDiscoveryPage extends ConsumerStatefulWidget {
  const LanDiscoveryPage({super.key});

  @override
  ConsumerState<LanDiscoveryPage> createState() => _LanDiscoveryPageState();
}

class _LanDiscoveryPageState extends ConsumerState<LanDiscoveryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  LanDiscoveryController? _savedCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      final ctrl = ref.read(lanDiscoveryProvider.notifier);
      _savedCtrl = ctrl;
      ctrl.initialize();
      ctrl.generatePairingQr();
      ctrl.startDiscovery();
      final port = appdata.implicitData['lan_discovery_port'] as int? ?? 42183;
      await LanControlService.instance.start(port);
    });
  }

  void _showPortSettings() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _PortSettingsSheet(),
    );
  }

  @override
  void dispose() {
    final ctrl = _savedCtrl;
    if (ctrl != null) {
      Future.microtask(() {
        ctrl.stopDiscovery();
      });
    }
    if (LanControlService.instance.connectionCount == 0) {
      LanControlService.instance.stop();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.lanDiscovery),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showPortSettings,
            tooltip: t.settings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t.lanDiscoverDevices),
            Tab(text: t.lanRemoteControl),
          ],
          labelStyle: ts.s14,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_DeviceDiscoveryTab(), _RemoteControlTab()],
      ),
    );
  }
}

class _DeviceDiscoveryTab extends ConsumerStatefulWidget {
  const _DeviceDiscoveryTab();

  @override
  ConsumerState<_DeviceDiscoveryTab> createState() =>
      _DeviceDiscoveryTabState();
}

class _DeviceDiscoveryTabState extends ConsumerState<_DeviceDiscoveryTab> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '42183');
  bool _showManualConnect = false;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(lanDiscoveryProvider.notifier);
    final state = ref.watch(lanDiscoveryProvider);
    final cs = Theme.of(context).colorScheme;
    final isConnected = LanControlClient.instance.isConnected;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: isConnected
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(t.connected),
                      )
                    : state.serviceState == LanDiscoveryServiceState.discovering
                    ? OutlinedButton.icon(
                        onPressed: ctrl.stopDiscovery,
                        icon: const Icon(Icons.stop),
                        label: Text(t.lanStopDiscovery),
                      )
                    : FilledButton.icon(
                        onPressed: ctrl.startDiscovery,
                        icon: const Icon(Icons.search),
                        label: Text(t.lanStartDiscovery),
                      ),
              ),
              if (!isConnected) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: state.isRefreshing ? null : ctrl.refresh,
                  icon: state.isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _showManualConnect = !_showManualConnect),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: _showManualConnect ? cs.primary : null,
                  ),
                  tooltip: '手动输入 IP 连接',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: state.devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_other, size: 48, color: cs.outline),
                      const SizedBox(height: 8),
                      Text(
                        isConnected ? t.connected : t.lanNoDevicesFound,
                        style: ts.s14.copyWith(color: cs.outline),
                      ),
                      if (!isConnected &&
                          state.serviceState ==
                              LanDiscoveryServiceState.discovering)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            t.lanSearching,
                            style: ts.s12.copyWith(color: cs.outline),
                          ),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: state.devices.length,
                  itemBuilder: (context, index) {
                    final device = state.devices[index];
                    final isSelected = state.selectedDevice?.id == device.id;
                    final isThisConnected =
                        isSelected && LanControlClient.instance.isConnected;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: ListTile(
                        leading: _DeviceIcon(deviceType: device.deviceType),
                        title: Text(device.name),
                        subtitle: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${device.ip}:${device.port}', style: ts.s12),
                            if (isThisConnected)
                              Text(
                                t.connected,
                                style: ts.s10.copyWith(color: cs.primary),
                              ),
                          ],
                        ),
                        selected: isSelected,
                        onTap: isThisConnected
                            ? null
                            : () => ctrl.selectDevice(device),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isThisConnected)
                              FilledButton.tonal(
                                onPressed: () => ctrl.disconnectFromDevice(),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: cs.error,
                                  backgroundColor: cs.errorContainer.withAlpha(
                                    120,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link_off, size: 16),
                                    const SizedBox(width: 4),
                                    Text(t.lanExitControl, style: ts.s12),
                                  ],
                                ),
                              )
                            else if (isSelected &&
                                !LanControlClient.instance.isConnected)
                              IconButton(
                                icon: state.isConnecting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.link),
                                onPressed: state.isConnecting
                                    ? null
                                    : () => ctrl.connectToDevice(device),
                                tooltip: t.lanConnect,
                              )
                            else if (!isSelected &&
                                !LanControlClient.instance.isConnected &&
                                device.supportsRemoteControl)
                              Chip(
                                label: Text(t.lanRemoteControl, style: ts.s10),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RemoteControlTab extends ConsumerWidget {
  const _RemoteControlTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lanDiscoveryProvider);
    final ctrl = ref.watch(lanDiscoveryProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qrBg = isDark ? cs.surfaceContainerHighest : cs.surface;

    final isBeingControlled =
        LanControlService.instance.isListening &&
        LanControlService.instance.connectionCount > 0;

    return Column(
      children: [
        if (isBeingControlled)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withAlpha(80), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.screen_share_outlined,
                    color: cs.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '设备正在被远程控制',
                          style: ts.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '桌面端已连接并可控制此设备',
                          style: ts.copyWith(
                            color: cs.onPrimaryContainer.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => ctrl.disconnectControlledSession(),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: cs.error,
                      backgroundColor: cs.errorContainer,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stop_screen_share_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text('断开', style: ts.s12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: Center(
            child: state.qrContent != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: qrBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outlineVariant.withAlpha(128),
                            width: 0.8,
                          ),
                        ),
                        child: SizedBox(
                          width: 180,
                          height: 180,
                          child: PrettyQrView.data(
                            data: state.qrContent!,
                            errorCorrectLevel: QrErrorCorrectLevel.H,
                            decoration: PrettyQrDecoration(
                              background: qrBg,
                              shape: const PrettyQrSmoothSymbol(
                                color: PrettyQrBrush.gradient(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF80D8DA),
                                      Color(0xFFF1919B),
                                    ],
                                  ),
                                ),
                                roundFactor: 1.0,
                              ),
                              image: const PrettyQrDecorationImage(
                                image: AssetImage('images/app_icon.png'),
                                scale: 0.2,
                                position:
                                    PrettyQrDecorationImagePosition.embedded,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 18, color: cs.outline),
                          const SizedBox(width: 6),
                          Text(
                            '${state.qrRemainingSeconds}s',
                            style: ts.s14.copyWith(color: cs.outline),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            height: 6,
                            child: LinearProgressIndicator(
                              value: state.qrRemainingSeconds / 10,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: state.qrRemainingSeconds > 3
                                  ? cs.primary
                                  : cs.error,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t.lanScanQrCodeToConnect,
                        style: ts.s14.copyWith(color: cs.outline),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        t.lanGeneratingQrCode,
                        style: ts.s14.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: cs.outline),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t.lanRemoteControlDescription,
                  style: ts.s12.copyWith(color: cs.outline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final LanDeviceType deviceType;

  const _DeviceIcon({required this.deviceType});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    IconData icon;
    switch (deviceType) {
      case LanDeviceType.desktop:
        icon = Icons.desktop_windows;
      case LanDeviceType.mobile:
        icon = Icons.phone_android;
      case LanDeviceType.tablet:
        icon = Icons.tablet_android;
      case LanDeviceType.unknown:
        icon = Icons.devices_other;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: cs.primary),
    );
  }
}

class _PortSettingsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PortSettingsSheet> createState() => _PortSettingsSheetState();
}

class _PortSettingsSheetState extends ConsumerState<_PortSettingsSheet> {
  late final TextEditingController _portController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final currentPort =
        appdata.implicitData['lan_discovery_port'] as int? ?? 42183;
    _portController = TextEditingController(text: currentPort.toString());
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final port = int.tryParse(_portController.text);
    if (port == null || port < 1024 || port > 65535) {
      return;
    }

    appdata.implicitData['lan_discovery_port'] = port;
    appdata.writeImplicitData();

    ref.read(lanDiscoveryProvider.notifier).reinitialize(port);

    Navigator.pop(context);
    App.rootContext.showMessage(message: t.saved);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: context.padding.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(64),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.settings_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(t.settings, style: ts.s18),
            ],
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.port, style: ts.s14),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '42183',
                    prefixIcon: const Icon(Icons.lan_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: 'UDP/WebSocket',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t.thisFieldCannotBeEmpty;
                    }
                    final port = int.tryParse(value);
                    if (port == null) {
                      return t.invalidUrlConfig;
                    }
                    if (port < 1024 || port > 65535) {
                      return '端口号必须在 1024-65535 之间';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'UDP 广播端口用于设备发现，WebSocket 端口用于远程控制连接',
                  style: ts.s12.copyWith(color: cs.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: Text(t.save)),
          ),
        ],
      ),
    );
  }
}
