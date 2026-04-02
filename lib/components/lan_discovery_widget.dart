import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/appdata.dart';
import 'package:kostori/foundation/hub_services/services.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final lanDiscoveryProvider = ChangeNotifierProvider<LanDiscoveryController>((
  ref,
) {
  return LanDiscoveryController();
});

// ── Controller ──────────────────────────────────────────────────────────────

class LanDiscoveryController extends ChangeNotifier {
  LanDiscoveryController() {
    _init();
  }

  final LanDiscoveryService _service = LanDiscoveryService.instance;
  Timer? _qrRefreshTimer;

  LanDiscoveryServiceState _serviceState = LanDiscoveryServiceState.idle;
  List<LanDiscoveredDevice> _devices = [];
  LanDiscoveredDevice? _selectedDevice;
  String? _qrContent;
  int _qrRemainingSeconds = 0;
  final bool _isConnecting = false;
  bool _isRefreshing = false;

  // Getters
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
  }

  void _onDeviceDiscovered(LanDiscoveredDevice device) {
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx >= 0) {
      _devices[idx] = device;
    } else {
      _devices.add(device);
    }
    notifyListeners();
  }

  void _onDeviceLeft(LanDiscoveredDevice device) {
    _devices.removeWhere((d) => d.id != device.id);
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
      builder: (ctx) => AlertDialog(
        title: Text(t.lanPairingRequestReceived),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t.lanDevice}: ${request.requesterName}'),
            Text('ID: ${request.requesterId}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.lanAccept),
          ),
        ],
      ),
    );
  }

  Future<void> startDiscovery() async {
    _isRefreshing = true;
    notifyListeners();

    await _service.init(
      deviceId: _getDeviceId(),
      deviceName: _getDeviceName(),
      deviceType: _getDeviceType(),
      capabilities: {'remoteControl': true, 'qrPairing': true, 'wsHub': true},
      hubPort: _getHubPort(),
    );
    await _service.startDiscovery();
    _isRefreshing = false;
    notifyListeners();
  }

  void stopDiscovery() => _service.stopDiscovery();

  Future<void> refresh() async {
    _isRefreshing = true;
    _devices = [];
    notifyListeners();
    await _service.refresh();
    _isRefreshing = false;
    notifyListeners();
  }

  void generatePairingQr() {
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

  void selectDevice(LanDiscoveredDevice? device) {
    _selectedDevice = device;
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

  int _getHubPort() => appdata.implicitData['hub_server_port'] as int? ?? 8080;

  @override
  void dispose() {
    _qrRefreshTimer?.cancel();
    _service.removeDeviceDiscoveredListener(_onDeviceDiscovered);
    _service.removeDeviceLeftListener(_onDeviceLeft);
    _service.removeStateChangedListener(_onStateChanged);
    _service.removePairingRequestListener(_onPairingRequest);
    super.dispose();
  }
}

// ── Widget ───────────────────────────────────────────────────────────────────

class LanDiscoveryWidget extends ConsumerStatefulWidget {
  const LanDiscoveryWidget({super.key});

  @override
  ConsumerState<LanDiscoveryWidget> createState() => _LanDiscoveryWidgetState();
}

class _LanDiscoveryWidgetState extends ConsumerState<LanDiscoveryWidget>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant, width: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.wifi_find, color: cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(t.lanDiscovery, style: ts.s16),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: t.lanDiscoverDevices),
                Tab(text: t.lanRemoteControl),
              ],
              labelStyle: ts.s14,
            ),
            SizedBox(
              height: 280,
              child: TabBarView(
                controller: _tabController,
                children: [_DeviceDiscoveryTab(), _RemoteControlTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDiscoveryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.watch(lanDiscoveryProvider.notifier);
    final state = ref.watch(lanDiscoveryProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child:
                    state.serviceState == LanDiscoveryServiceState.discovering
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: state.isRefreshing ? null : ctrl.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.devices_other, size: 48, color: cs.outline),
                      const SizedBox(height: 8),
                      Text(
                        t.lanNoDevicesFound,
                        style: ts.s14.copyWith(color: cs.outline),
                      ),
                      if (state.serviceState ==
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
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: ListTile(
                        leading: _DeviceIcon(deviceType: device.deviceType),
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.ip}:${device.port}',
                          style: ts.s12,
                        ),
                        selected: isSelected,
                        onTap: () => ctrl.selectDevice(device),
                        trailing: device.supportsRemoteControl
                            ? Chip(
                                label: Text(t.lanRemoteControl, style: ts.s10),
                                visualDensity: VisualDensity.compact,
                              )
                            : null,
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lanDiscoveryProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: state.qrContent != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: PrettyQrView.data(data: state.qrContent!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 16, color: cs.outline),
                          const SizedBox(width: 4),
                          Text(
                            '${state.qrRemainingSeconds}s',
                            style: ts.s14.copyWith(color: cs.outline),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            height: 4,
                            child: LinearProgressIndicator(
                              value: state.qrRemainingSeconds / 10,
                              backgroundColor: cs.surfaceContainerHighest,
                              color: state.qrRemainingSeconds > 3
                                  ? cs.primary
                                  : cs.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t.lanScanQrCodeToConnect,
                        style: ts.s12.copyWith(color: cs.outline),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code, size: 48, color: cs.outline),
                      const SizedBox(height: 8),
                      Text(
                        t.lanGeneratingQrCode,
                        style: ts.s14.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: cs.outline),
              const SizedBox(width: 8),
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
