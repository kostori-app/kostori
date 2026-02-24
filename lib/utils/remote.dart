import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';

class RemotePlay {
  Future<void> castVideo(String video) async {
    final searcher = DLNAManager();
    final dlna = await searcher.start();

    List<Widget> dlnaDevice = [];
    bool isSearching = false;
    StreamSubscription? subscription;

    await showModalBottomSheet(
      context: App.rootContext,
      isScrollControlled: true,
      backgroundColor: Theme.of(App.rootContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '远程投屏',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),

                          /// 退出
                          TextButton(
                            onPressed: () {
                              subscription?.cancel();
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              '退出',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),

                          /// 搜索
                          TextButton(
                            onPressed: () {
                              if (isSearching) return;

                              setState(() {
                                isSearching = true;
                                dlnaDevice.clear();
                              });

                              App.rootContext.showMessage(message: '开始搜索');

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
                                        onTap: () {
                                          try {
                                            App.rootContext.showMessage(
                                              message:
                                                  '尝试投屏至 ${value.info.friendlyName}',
                                            );
                                            DLNADevice(
                                              value.info,
                                            ).setUrl(video);
                                            DLNADevice(value.info).play();
                                          } catch (e) {
                                            Log.addLog(
                                              LogLevel.error,
                                              'DLNA',
                                              '$e',
                                            );
                                            App.rootContext.showMessage(
                                              message: 'DLNA 异常: $e',
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
                            child: isSearching
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('搜索中...'),
                                    ],
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.search, size: 18),
                                      SizedBox(width: 6),
                                      Text('搜索'),
                                    ],
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      /// 列表区域
                      Expanded(
                        child: dlnaDevice.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.devices_other,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      isSearching ? '正在搜索设备...' : '未找到设备',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(children: dlnaDevice),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      subscription?.cancel();
      searcher.stop();
    });
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
