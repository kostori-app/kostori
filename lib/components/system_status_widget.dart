// ignore_for_file: file_names, avoid_print

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kostori/foundation/app.dart';
import 'package:network_info_plus/network_info_plus.dart';

class BatteryWidget extends StatefulWidget {
  final Duration animationDuration;

  const BatteryWidget({
    super.key,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  BatteryWidgetState createState() => BatteryWidgetState();
}

class BatteryWidgetState extends State<BatteryWidget>
    with SingleTickerProviderStateMixin {
  late Battery _battery;

  StreamSubscription<BatteryState>? _batterySubscription;

  int _batteryLevel = 100;
  bool _hasBattery = false;
  BatteryState _batteryState = BatteryState.unknown;

  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayLevel = 100;
  bool _hasAnimationListener = false;

  @override
  void initState() {
    super.initState();
    _battery = Battery();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _initBattery();
  }

  void _initBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;

      if (mounted) {
        setState(() {
          _hasBattery = true;
          _displayLevel = _batteryLevel.toDouble();
          _startAnimation(_batteryLevel.toDouble());
        });
      }

      _batterySubscription = _battery.onBatteryStateChanged.listen((
        BatteryState state,
      ) {
        _handleStateChange(state);
      });
    } catch (e) {
      debugPrint("获取电池信息失败: $e");
    }
  }

  Future<void> _handleStateChange(BatteryState newState) async {
    int newLevel;
    try {
      newLevel = await _battery.batteryLevel;
    } catch (_) {
      return;
    }

    if (mounted) {
      if (newLevel != _batteryLevel || newState != _batteryState) {
        _startAnimation(newLevel.toDouble());
        setState(() {
          _batteryLevel = newLevel;
          _batteryState = newState;
        });
      }
    }
  }

  void _startAnimation(double targetLevel) {
    // 先创建动画（避免 late _animation 未初始化就 addListener 崩溃）
    _animation = Tween<double>(
      begin: _displayLevel,
      end: targetLevel,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 复用同一个监听器，避免多次调用时累积监听导致重复 setState
    if (!_hasAnimationListener) {
      _hasAnimationListener = true;
      _animation.addListener(() {
        if (mounted) {
          setState(() {
            _displayLevel = _animation.value;
          });
        }
      });
    }

    _controller.reset();
    _controller.forward();
  }

  Widget _buildBatterySvg(double level, BatteryState state) {
    Color batteryColor = Colors.white;

    bool isCharging =
        state == BatteryState.charging || state == BatteryState.full;

    if (isCharging) {
      batteryColor = Colors.green;
    } else if (level > 20) {
      batteryColor = Colors.white;
    } else if (level > 10) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = Colors.red;
    }

    // toARGB32 返回 AARRGGBB，取低 24 位作为 #RRGGBB
    final colorHex =
        '#${(batteryColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

    const double maxFillWidth = 11.0;
    double fillWidth = (level / 100.0) * maxFillWidth;
    fillWidth = fillWidth.clamp(0.0, maxFillWidth);

    String svgString =
        '''
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M17 6H7C5.89543 6 5 6.89543 5 8V16C5 17.1046 5.89543 18 7 18H17C18.1046 18 19 17.1046 19 16V8C19 6.89543 18.1046 6 17 6Z" stroke="$colorHex" stroke-width="1.5"/>
      <path d="M21 10V14" stroke="$colorHex" stroke-width="1.5" stroke-linecap="round"/>
      <rect x="6.5" y="8" width="$fillWidth" height="8" rx="0.5" fill="$colorHex"/>
      ${isCharging ? '<path d="M11 15L13.5 10H10.5L13 7" stroke="black" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round" fill="white"/>' : ''}
    </svg>
    ''';

    return SvgPicture.string(svgString, width: 26, height: 24);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBattery) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildBatterySvg(_displayLevel, _batteryState),
        Padding(
          padding: const EdgeInsets.only(left: 2.0),
          child: Text(
            '${_displayLevel.round()}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

class SpeedMonitorWidget extends StatefulWidget {
  const SpeedMonitorWidget({super.key});

  @override
  State<SpeedMonitorWidget> createState() => _SpeedMonitorWidgetState();
}

class _SpeedMonitorWidgetState extends State<SpeedMonitorWidget> {
  static const platform = MethodChannel('kostori/network_speed');
  String _downloadSpeed = '0 B/s';
  String _uploadSpeed = '0 B/s';
  int _lastRxBytes = 0;
  int _lastTxBytes = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  void _startMonitoring() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      try {
        final result = await platform.invokeMethod('getNetworkStats');
        final rxBytes = result['rxBytes'] as int;
        final txBytes = result['txBytes'] as int;

        if (_lastRxBytes == 0 && _lastTxBytes == 0) {
          _lastRxBytes = rxBytes;
          _lastTxBytes = txBytes;
          return;
        }

        // 网卡重启后计数器可能归零导致负值，clamp 到 0
        final downloadSpeed = (rxBytes - _lastRxBytes).clamp(0, rxBytes);
        final uploadSpeed = (txBytes - _lastTxBytes).clamp(0, txBytes);

        setState(() {
          _downloadSpeed = _formatSpeed(downloadSpeed);
          _uploadSpeed = _formatSpeed(uploadSpeed);
          _lastRxBytes = rxBytes;
          _lastTxBytes = txBytes;
        });
      } catch (e) {
        debugPrint("getNetworkStats error: $e");
      }
    });
  }

  String _formatSpeed(int speed) {
    if (speed <= 0) return '0 B/s';
    if (speed < 1024) {
      // 低于 1KB 显示字节
      return '$speed B/s';
    }
    if (speed < 1024 * 1024) {
      // 显示 KB/s
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    // 显示 MB/s
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.arrow_downward, size: 8, color: Colors.white),
              Text(
                " $_downloadSpeed",
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 8, color: Colors.white),
              Text(
                " $_uploadSpeed",
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NetworkStatusWidget extends StatefulWidget {
  const NetworkStatusWidget({super.key});

  @override
  State<NetworkStatusWidget> createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> {
  // 网络状态
  final Connectivity _connectivity = Connectivity();
  ConnectivityResult _connectivityResult = ConnectivityResult.none;
  bool _initialized = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // WiFi 信号强度 (Android: -100 到 0 dBm, iOS: 不支持)
  // ignore: unused_field
  final NetworkInfo _networkInfo = NetworkInfo();

  // ignore: unused_field
  int? _wifiSignalStrength; // null 表示不支持或无法获取，预留用于未来扩展

  Timer? _wifiPollTimer;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _wifiPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    try {
      // 初始状态（取列表的第一个结果）
      final results = await _connectivity.checkConnectivity();
      final ConnectivityResult result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      if (mounted) {
        setState(() {
          _connectivityResult = result;
          _initialized = true;
        });
      }

      // 如果是 WiFi，尝试获取信号强度
      if (result == ConnectivityResult.wifi) {
        await _updateWifiSignalStrength();
      }

      // 监听变化（同样取列表的第一个结果）
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) async {
        final ConnectivityResult result = results.isNotEmpty
            ? results.first
            : ConnectivityResult.none;
        if (mounted) {
          setState(() {
            _connectivityResult = result;
            // 如果切换到非 WiFi，清除信号强度
            if (result != ConnectivityResult.wifi) {
              _wifiSignalStrength = null;
            }
          });

          // 如果是 WiFi，尝试获取信号强度
          if (result == ConnectivityResult.wifi) {
            await _updateWifiSignalStrength();
          }
        }
      });

      // 定期更新 WiFi 信号强度（如果是 WiFi）
      _wifiPollTimer?.cancel();
      _wifiPollTimer = Timer.periodic(const Duration(seconds: 5), (
        timer,
      ) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_connectivityResult == ConnectivityResult.wifi) {
          await _updateWifiSignalStrength();
        }
      });
    } catch (_) {
      // 忽略异常，保持默认 none 状态
    }
  }

  /// 更新 WiFi 信号强度
  Future<void> _updateWifiSignalStrength() async {
    try {
      // Android 才支持获取 WiFi 信号强度 (单位: dBm, 范围通常 -100 到 0)
      // iOS 不支持此功能
      if (App.isAndroid) {
        // network_info_plus 需要权限: ACCESS_FINE_LOCATION
        // 注意: network_info_plus 6.x 版本可能没有直接获取信号强度的API
        // 这里我们使用一个变通方法，或者考虑使用 wifi_info_flutter 等其他包
        // 为了演示，这里假设我们能获取到信号强度
        // 实际情况下可能需要使用平台通道或其他方法

        // 由于 network_info_plus 不直接提供信号强度，我们这里先设置为 null
        // 如果需要真实的信号强度，可能需要使用平台特定的代码
        if (mounted) {
          setState(() {
            // 暂时设置为 null，表示不支持
            // 如果有实际的信号强度 API，在这里设置
            _wifiSignalStrength = null;
          });
        }
      }
    } catch (_) {
      // 忽略错误
    }
  }

  /// 判断是否应该显示网络状态
  bool _shouldShowNetworkStatus() {
    // 只显示 WiFi、移动网络、宽带和无网络
    return _connectivityResult == ConnectivityResult.wifi ||
        _connectivityResult == ConnectivityResult.mobile ||
        _connectivityResult == ConnectivityResult.ethernet ||
        _connectivityResult == ConnectivityResult.none;
  }

  /// 网络状态图标（不显示文本）
  Widget _buildNetworkStatus() {
    // 根据网络类型返回对应的 SVG 图标
    switch (_connectivityResult) {
      case ConnectivityResult.wifi:
        return _buildWifiIcon();
      case ConnectivityResult.mobile:
        return _buildMobileNetworkIcon();
      case ConnectivityResult.ethernet:
        return _buildEthernetIcon();
      case ConnectivityResult.none:
        // 无网络显示红色的断网图标
        return _buildNoNetworkIcon();
      // 其他类型（vpn, bluetooth, other）不显示
      default:
        return const SizedBox.shrink();
    }
  }

  /// WiFi 图标（带信号强度）
  Widget _buildWifiIcon() {
    // WiFi 图标 - 简洁的扇形信号设计
    // 由于 network_info_plus 不提供信号强度，我们显示满信号的 WiFi 图标
    const String svgString = '''
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- WiFi 信号波纹 - 3层 -->
        <path d="M12 18C12.5523 18 13 17.5523 13 17C13 16.4477 12.5523 16 12 16C11.4477 16 11 16.4477 11 17C11 17.5523 11.4477 18 12 18Z" fill="white"/>
        <path d="M9.17 14.83C9.95639 14.0436 11.0217 13.5977 12.135 13.5977C13.2483 13.5977 14.3136 14.0436 15.1 14.83" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
        <path d="M6.34 12C7.90609 10.4339 10.0261 9.55664 12.235 9.55664C14.4439 9.55664 16.5639 10.4339 18.13 12" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
        <path d="M3.51 9.17C5.85609 6.82391 9.08174 5.50391 12.455 5.50391C15.8283 5.50391 19.0539 6.82391 21.4 9.17" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    ''';

    return SvgPicture.string(svgString, width: 20, height: 16);
  }

  /// 移动网络图标（统一样式）
  Widget _buildMobileNetworkIcon() {
    // 移动网络信号塔图标
    const String svgString = '''
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- 信号塔主体 -->
        <path d="M12 4L9 9H15L12 4Z" fill="white"/>
        <rect x="11" y="9" width="2" height="11" fill="white"/>
        <!-- 左侧信号波 -->
        <path d="M7 11C8.5 11 9 12 9 13" stroke="white" stroke-width="1.2" stroke-linecap="round"/>
        <path d="M5 9C7.5 9 8.5 11 8.5 13" stroke="white" stroke-width="1.2" stroke-linecap="round"/>
        <!-- 右侧信号波 -->
        <path d="M17 11C15.5 11 15 12 15 13" stroke="white" stroke-width="1.2" stroke-linecap="round"/>
        <path d="M19 9C16.5 9 15.5 11 15.5 13" stroke="white" stroke-width="1.2" stroke-linecap="round"/>
        <!-- 底座 -->
        <rect x="9" y="20" width="6" height="1.5" rx="0.5" fill="white"/>
      </svg>
    ''';

    return SvgPicture.string(svgString, width: 20, height: 16);
  }

  /// 宽带（以太网）图标
  Widget _buildEthernetIcon() {
    // 以太网接口图标
    const String svgString = '''
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- 网线接口外框 -->
        <rect x="4" y="8" width="16" height="10" rx="1.5" stroke="white" stroke-width="1.5"/>
        <!-- 接口卡槽 -->
        <rect x="7" y="11" width="2" height="4" rx="0.5" fill="white"/>
        <rect x="11" y="11" width="2" height="4" rx="0.5" fill="white"/>
        <rect x="15" y="11" width="2" height="4" rx="0.5" fill="white"/>
        <!-- 网线 -->
        <path d="M10 8V5H14V8" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
        <path d="M10 5H14" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
      </svg>
    ''';

    return SvgPicture.string(svgString, width: 20, height: 16);
  }

  /// 无网络图标
  Widget _buildNoNetworkIcon() {
    // 断网图标 - WiFi + 斜线
    const String svgString = '''
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <!-- WiFi 信号（半透明） -->
        <path d="M12 18C12.5523 18 13 17.5523 13 17C13 16.4477 12.5523 16 12 16C11.4477 16 11 16.4477 11 17C11 17.5523 11.4477 18 12 18Z" fill="#F44336" opacity="0.5"/>
        <path d="M9.17 14.83C9.95639 14.0436 11.0217 13.5977 12.135 13.5977C13.2483 13.5977 14.3136 14.0436 15.1 14.83" stroke="#F44336" stroke-width="1.5" stroke-linecap="round" opacity="0.5"/>
        <path d="M6.34 12C7.90609 10.4339 10.0261 9.55664 12.235 9.55664C14.4439 9.55664 16.5639 10.4339 18.13 12" stroke="#F44336" stroke-width="1.5" stroke-linecap="round" opacity="0.5"/>
        <!-- 斜线表示断网 -->
        <line x1="4" y1="20" x2="20" y2="4" stroke="#F44336" stroke-width="2" stroke-linecap="round"/>
      </svg>
    ''';

    return SvgPicture.string(svgString, width: 20, height: 16);
  }

  @override
  Widget build(BuildContext context) {
    // 未完成首次检测前不显示，避免闪烁断网图标
    if (!_initialized) return const SizedBox.shrink();
    return _shouldShowNetworkStatus()
        ? _buildNetworkStatus()
        : const SizedBox.shrink();
  }
}
