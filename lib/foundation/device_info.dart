import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart' show App, Navigation, ColorExt;
import 'package:kostori/utils/translations.dart';

class DeviceInfo {
  static Future<Object?> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (App.isAndroid) return await deviceInfoPlugin.androidInfo;
    if (App.isIOS) return await deviceInfoPlugin.iosInfo;
    if (App.isWindows) return await deviceInfoPlugin.windowsInfo;
    if (App.isLinux) return await deviceInfoPlugin.linuxInfo;
    if (App.isMacOS) return await deviceInfoPlugin.macOsInfo;

    return null;
  }

  static Future<void> showDeviceInfoDialog() async {
    final info = await getDeviceInfo();
    final infoMap = deviceInfoToMap(info);

    showDialog(
      context: App.rootContext,
      builder: (context) {
        return ContentDialog(
          title: "设备信息",
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 500.0),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false, overscroll: false),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: infoMap.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Material(
                          color: context.brightness == Brightness.light
                              ? Colors.white.toOpacity(0.72)
                              : const Color(0xFF1E1E1E).toOpacity(0.72),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onLongPress: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text: '${entry.key}: ${entry.value}',
                                ),
                              );
                              App.rootContext.showMessage(message: '复制成功');
                            },
                            onTap: () {},
                            child: ListTile(
                              dense: true,
                              title: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text("${entry.value}"),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                final allText = infoMap.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: allText));
                App.rootContext.showMessage(message: '全部复制成功');
              },
              child: Text("Copy".tl),
            ),
          ],
        );
      },
    );
  }

  static Map<String, dynamic> deviceInfoToMap(dynamic info) {
    if (info is AndroidDeviceInfo) {
      return {
        'name'.tl: info.name,
        'brand'.tl: info.brand,
        'model'.tl: info.model,
        'device'.tl: info.device,
        'product'.tl: info.product,
        'manufacturer'.tl: info.manufacturer,
        'version_release'.tl: info.version.release,
        'version_sdkInt'.tl: info.version.sdkInt,
        'display'.tl: info.display,
        'hardware'.tl: info.hardware,
        'physicalRamSize'.tl: info.physicalRamSize,
        'availableRamSize'.tl: info.availableRamSize,
        'freeDiskSize'.tl: info.freeDiskSize,
        'totalDiskSize'.tl: info.totalDiskSize,
        'isPhysicalDevice'.tl: info.isPhysicalDevice,
      };
    } else if (info is IosDeviceInfo) {
      return {
        'name'.tl: info.name,
        'systemName'.tl: info.systemName,
        'systemVersion'.tl: info.systemVersion,
        'model'.tl: info.model,
        'modelName'.tl: info.modelName,
        'identifierForVendor'.tl: info.identifierForVendor,
        'physicalRamSize'.tl: info.physicalRamSize,
        'availableRamSize'.tl: info.availableRamSize,
        'sysname'.tl: info.utsname.sysname,
        'nodename'.tl: info.utsname.nodename,
        'release'.tl: info.utsname.release,
        'version'.tl: info.utsname.version,
        'machine'.tl: info.utsname.machine,
        'isPhysicalDevice'.tl: info.isPhysicalDevice,
      };
    } else if (info is WindowsDeviceInfo) {
      return {
        'computerName'.tl: info.computerName,
        'numberOfCores'.tl: info.numberOfCores,
        'systemMemoryInMegabytes'.tl: info.systemMemoryInMegabytes,
        'userName'.tl: info.userName,
        'majorVersion'.tl: info.majorVersion,
        'minorVersion'.tl: info.minorVersion,
        'buildNumber'.tl: info.buildNumber,
        'displayVersion'.tl: info.displayVersion,
        'productName'.tl: info.productName,
        'registeredOwner'.tl: info.registeredOwner,
        'releaseId'.tl: info.releaseId,
        'deviceId'.tl: info.deviceId,
      };
    } else if (info is LinuxDeviceInfo) {
      return {
        'name'.tl: info.name,
        'version'.tl: info.version,
        'idLike'.tl: info.idLike,
        'versionCodename'.tl: info.versionCodename,
        'versionId'.tl: info.versionId,
        'prettyName'.tl: info.prettyName,
      };
    } else if (info is MacOsDeviceInfo) {
      return {
        'computerName'.tl: info.computerName,
        'hostName'.tl: info.hostName,
        'arch'.tl: info.arch,
        'model'.tl: info.model,
        'modelName'.tl: info.modelName,
        'kernelVersion'.tl: info.kernelVersion,
        'osRelease'.tl: info.osRelease,
        'majorVersion'.tl: info.majorVersion,
        'minorVersion'.tl: info.minorVersion,
        'patchVersion'.tl: info.patchVersion,
        'activeCPUs'.tl: info.activeCPUs,
        'memorySize'.tl: info.memorySize,
        'cpuFrequency'.tl: info.cpuFrequency,
      };
    } else if (info == null) {
      return {"提示": "未获取到设备信息"};
    }
    return {"信息": info.toString()};
  }
}
