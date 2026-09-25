import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/local_media_server.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';

/// 自动续投时下一集要投的媒体（地址 + 需要的请求头）
typedef CastNextMedia = ({String url, Map<String, String>? headers});

class RemotePlay {
  RemotePlay._();

  static final RemotePlay instance = RemotePlay._();

  /// 当前投屏设备名（null = 未投屏）。UI 监听它以显示「停止投屏」入口。
  final ValueNotifier<String?> castingDeviceName = ValueNotifier(null);

  DLNADevice? _activeDevice;

  /// 续投解析：TV 放完时调用，返回下一集媒体；返回 null 表示不再续投。
  Future<CastNextMedia?> Function()? _nextResolver;

  /// 投屏状态变化回调（调用方据此切换本地播放器的「只加载不播放」模式）
  void Function(bool casting)? _onCastingChanged;

  Timer? _transportTimer;
  bool _wasPlaying = false;
  bool _switching = false;

  bool get isCasting => _activeDevice != null;

  /// 停止投屏：让设备停止播放并关闭本地转发服务。
  Future<void> stopCast() => _cleanupCast(showToast: true);

  Future<void> _cleanupCast({required bool showToast}) async {
    _transportTimer?.cancel();
    _transportTimer = null;
    _nextResolver = null;
    final device = _activeDevice;
    _activeDevice = null;
    castingDeviceName.value = null;
    final onChanged = _onCastingChanged;
    _onCastingChanged = null;
    onChanged?.call(false);
    try {
      await device?.stop();
    } catch (e) {
      PlayLog.error('DLNA', 'stop failed: $e');
    }
    await LocalMediaServer.instance.stop();
    if (showToast) {
      App.rootContext.showMessage(message: t.castStopped);
    }
  }

  /// 轮询 TV 播放状态，靠 PLAYING → STOPPED 判断本集结束，触发自动续投。
  void _startTransportWatch() {
    _transportTimer?.cancel();
    _wasPlaying = false;
    _transportTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _pollTransport();
    });
  }

  Future<void> _pollTransport() async {
    if (_switching) return;
    final device = _activeDevice;
    if (device == null) return;
    try {
      final xml = await device.getTransportInfo();
      final state = _parseTransportState(xml);
      if (state == 'PLAYING') {
        _wasPlaying = true;
        return;
      }
      if (_wasPlaying && (state == 'STOPPED' || state == 'NO_MEDIA_PRESENT')) {
        _wasPlaying = false;
        await _onCastEnded();
      }
    } catch (_) {}
  }

  String _parseTransportState(String xml) {
    final match = RegExp(
      r'<CurrentTransportState>([^<]+)</CurrentTransportState>',
    ).firstMatch(xml);
    return match?.group(1)?.trim() ?? '';
  }

  Future<void> _onCastEnded() async {
    if (_switching) return;
    _switching = true;
    try {
      final resolver = _nextResolver;
      final device = _activeDevice;
      if (resolver == null || device == null) {
        await _cleanupCast(showToast: true);
        return;
      }
      final next = await resolver();
      if (next == null) {
        await _cleanupCast(showToast: true);
        return;
      }
      final castUrl = await _resolveCastUrl(next.url, next.headers);
      await device.setUrl(castUrl);
      await device.play();
      _wasPlaying = false;
    } catch (e) {
      PlayLog.error('DLNA', 'cast next failed: $e');
      await _cleanupCast(showToast: true);
    } finally {
      _switching = false;
    }
  }

  Future<void> castVideo(
    String video, {
    Map<String, String>? headers,
    Future<CastNextMedia?> Function()? next,
    void Function(bool casting)? onCastingChanged,
  }) async {
    if (isCasting) {
      await _cleanupCast(showToast: false);
    }
    final castUrl = await _resolveCastUrl(video, headers);
    final searcher = DLNAManager();
    final dlna = await searcher.start();

    List<Widget> dlnaDevice = [];
    bool isSearching = false;
    StreamSubscription? subscription;

    await showModalBottomSheet(
      context: App.rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Sheet(
              title: t.remoteCast,
              icon: Icons.cast,
              initialSize: 0.6,
              headerTrailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: isSearching
                        ? null
                        : () {
                            setState(() {
                              isSearching = true;
                              dlnaDevice.clear();
                            });

                            App.rootContext.showMessage(
                              message: t.startSearching,
                            );

                            subscription?.cancel();

                            subscription = dlna.devices.stream.listen((
                              deviceList,
                            ) {
                              setState(() {
                                dlnaDevice.clear();

                                deviceList.forEach((key, value) {
                                  final type = value.info.deviceType.split(
                                    ':',
                                  )[3];

                                  dlnaDevice.add(
                                    ListTile(
                                      leading: _deviceUPnPIcon(type),
                                      title: Text(value.info.friendlyName),
                                      subtitle: Text(type),
                                      onTap: () async {
                                        try {
                                          App.rootContext.showMessage(
                                            message:
                                                '${t.tryingToCast} ${value.info.friendlyName}',
                                          );
                                          final device = DLNADevice(value.info);
                                          await device.setUrl(castUrl);
                                          await device.play();
                                          _activeDevice = device;
                                          _nextResolver = next;
                                          _onCastingChanged = onCastingChanged;
                                          _onCastingChanged?.call(true);
                                          _switching = false;
                                          _startTransportWatch();
                                          castingDeviceName.value =
                                              value.info.friendlyName;
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                          }
                                          App.rootContext.showMessage(
                                            message: t.castingTo(
                                              device: value.info.friendlyName,
                                            ),
                                            seconds: 6,
                                            trailing: TextButton(
                                              onPressed: () => stopCast(),
                                              child: Text(t.stopCast),
                                            ),
                                          );
                                        } catch (e) {
                                          PlayLog.error('DLNA', '$e');
                                          App.rootContext.showMessage(
                                            message: '${t.dlnaException}: $e',
                                          );
                                        }
                                      },
                                    ),
                                  );
                                });

                                isSearching = false;
                              });
                            });
                          },
                    icon: isSearching
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: PolygonRefreshIndicator(),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: Text(isSearching ? t.searchingDevices : t.search),
                  ),
                ],
              ),
              builder: (context, sc) {
                if (dlnaDevice.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.devices_other,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isSearching ? t.searchingDevices : t.noDevicesFound,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: dlnaDevice,
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      subscription?.cancel();
      searcher.stop();
    });
  }

  /// 解析出电视能访问的播放地址：
  /// - 本地文件路径 → 局域网 HTTP 流（支持 Range）；
  /// - `127.0.0.1` / `localhost` 回环地址（BT 等）→ 局域网代理；
  /// - 其他 http(s) 直链 → 经本机转发，顺便带上源站需要的请求头，
  ///   并让本机（可走代理/科学上网）代取流。
  Future<String> _resolveCastUrl(
    String video,
    Map<String, String>? headers,
  ) async {
    final uri = Uri.tryParse(video);
    final isNetwork =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!isNetwork) {
      try {
        return await LocalMediaServer.instance.serveFile(video);
      } catch (e) {
        PlayLog.error('DLNA', 'serve local file failed: $e');
        return video;
      }
    }
    if (uri.host == '127.0.0.1' || uri.host == 'localhost') {
      try {
        return await LocalMediaServer.instance.serveLoopback(video);
      } catch (e) {
        PlayLog.error('DLNA', 'proxy loopback failed: $e');
        return video;
      }
    }
    try {
      return await LocalMediaServer.instance.serveRemote(
        video,
        headers: headers,
      );
    } catch (e) {
      PlayLog.error('DLNA', 'proxy remote failed: $e');
      return video;
    }
  }

  Icon _deviceUPnPIcon(String deviceType) {
    switch (deviceType) {
      case 'MediaRenderer':
      case 'MediaServer':
        return const Icon(Icons.cast_connected);
      case 'InternetGatewayDevice':
        return const Icon(Icons.router);
      case 'BasicDevice':
        return const Icon(Icons.device_hub);
      case 'DimmableLight':
        return const Icon(Icons.lightbulb);
      case 'WLANAccessPoint':
        return const Icon(Icons.lan);
      case 'WLANConnectionDevice':
        return const Icon(Icons.wifi_tethering);
      case 'Printer':
        return const Icon(Icons.print);
      case 'Scanner':
        return const Icon(Icons.scanner);
      case 'DigitalSecurityCamera':
        return const Icon(Icons.camera_enhance_outlined);
      default:
        return const Icon(Icons.question_mark);
    }
  }
}
