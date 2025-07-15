// ignore_for_file: file_names, avoid_print

import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

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
  late int _batteryLevel = 100;
  Timer? _timer;
  bool _hasBattery = false;
  BatteryState _batteryState = BatteryState.unknown;
  late AnimationController _controller;
  late Animation<double> _animation;
  double _displayLevel = 100;

  @override
  void initState() {
    super.initState();
    _battery = Battery();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _checkBatteryAvailability();
  }

  void _checkBatteryAvailability() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
      _batteryState = await _battery.batteryState;
      if (mounted) {
        setState(() {
          _hasBattery = true;
          _startAnimation(_batteryLevel.toDouble());
        });
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateBatteryInfo();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _updateBatteryInfo() async {
    final newLevel = await _battery.batteryLevel;
    final newState = await _battery.batteryState;

    if (mounted && (newLevel != _batteryLevel || newState != _batteryState)) {
      setState(() {
        _batteryLevel = newLevel;
        _batteryState = newState;
      });
      _startAnimation(newLevel.toDouble());
    }
  }

  void _startAnimation(double targetLevel) {
    _animation =
        Tween<double>(
          begin: _displayLevel,
          end: targetLevel,
        ).animate(_controller)..addListener(() {
          if (mounted) {
            setState(() {
              _displayLevel = _animation.value;
            });
          }
        });
    _controller.reset();
    _controller.forward();
  }

  Color _getBatteryColor() {
    if (_batteryState == BatteryState.charging) return Colors.green;
    if (_displayLevel > 20) return Colors.white;
    if (_displayLevel > 10) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBattery) return const SizedBox.shrink();

    return SizedBox(
      // height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min, // 让Row自适应内容宽度
        crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中
        children: [
          // 电池图标部分（保持原有Stack结构）
          SizedBox(
            width: 32,
            // height: 20,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 32,
                    height: 28,
                    child: SvgPicture.asset(
                      'assets/img/battery_empty.svg',
                      fit: BoxFit.fill, // 强制填充
                      colorFilter: ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 32 * 0.08,
                  right: 50 * 0.08,
                  top: 28 * 0.15,
                  bottom: 28 * 0.15,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * (_displayLevel / 100),
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getBatteryColor(),
                            borderRadius: BorderRadius.circular(32 * 0.03),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_batteryState == BatteryState.charging)
                  Padding(
                    padding: EdgeInsets.only(top: 6.0),
                    child: Center(
                      child: Icon(
                        Icons.bolt,
                        size: 22 * 0.7,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(
            height: 14,
            // width: widget.width + 20,
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0), // 图标和数字之间的间距
              child: Text(
                '${_displayLevel.round()}%',
                style: TextStyle(
                  fontSize: 16 * 0.8, // 调大字号
                  color: Colors.white, // 根据背景自动选择文字颜色
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 数字部分（添加间距和样式调整）
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
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

        // 计算速度
        final downloadSpeed = rxBytes - _lastRxBytes;
        final uploadSpeed = txBytes - _lastTxBytes;

        setState(() {
          _downloadSpeed = _formatSpeed(downloadSpeed);
          _uploadSpeed = _formatSpeed(uploadSpeed);
          _lastRxBytes = rxBytes;
          _lastTxBytes = txBytes;
        });
      } on PlatformException catch (e) {
        print("Failed to get network stats: '${e.message}'.");
      }
    });
  }

  String _formatSpeed(int speed) {
    if (speed < 1024 * 1024) {
      // 显示 KB/s（即使低于 1KB 也强制为 0.1 KB/s 之类）
      final kb = speed / 1024;
      return '${kb < 0.1 ? '0.1' : kb.toStringAsFixed(1)} KB/s';
    } else {
      // 显示 MB/s
      return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
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
              Icon(Icons.arrow_downward, size: 8),
              Text(
                " $_downloadSpeed",
                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 8),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.arrow_upward, size: 8),
              Text(
                " $_uploadSpeed",
                style: TextStyle(fontWeight: FontWeight.normal, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
