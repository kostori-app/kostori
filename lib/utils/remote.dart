import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/foundation/log.dart';
import 'package:kostori/i18n/strings.g.dart';

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
                                      onTap: () {
                                        try {
                                          App.rootContext.showMessage(
                                            message:
                                                '${t.tryingToCast} ${value.info.friendlyName}',
                                          );
                                          DLNADevice(value.info).setUrl(video);
                                          DLNADevice(value.info).play();
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
