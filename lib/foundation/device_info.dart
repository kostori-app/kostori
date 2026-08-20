import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart' show App, Navigation, ColorExt;
import 'package:kostori/i18n/strings.g.dart';

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
          title: t.deviceInfo,
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
                              App.rootContext.showMessage(message: t.copySuccess);
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
                App.rootContext.showMessage(message: t.allCopiedSuccess);
              },
              child: Text(t.copy),
            ),
          ],
        );
      },
    );
  }

  static Map<String, dynamic> deviceInfoToMap(dynamic info) {
    if (info is AndroidDeviceInfo) {
      return {
        t.name: info.name,
        t.brandField: info.brand,
        t.model: info.model,
        t.deviceField: info.device,
        t.productField: info.product,
        t.manufacturerField: info.manufacturer,
        t.versionReleaseField: info.version.release,
        t.versionSdkIntField: info.version.sdkInt,
        t.displayField: info.display,
        t.hardwareField: info.hardware,
        t.physicalRamSizeField: info.physicalRamSize,
        t.availableRamSizeField: info.availableRamSize,
        t.freeDiskSizeField: info.freeDiskSize,
        t.totalDiskSizeField: info.totalDiskSize,
        t.isPhysicalDeviceField: info.isPhysicalDevice,
      };
    } else if (info is IosDeviceInfo) {
      return {
        t.name: info.name,
        t.systemNameField: info.systemName,
        t.systemVersionField: info.systemVersion,
        t.model: info.model,
        t.modelNameField: info.modelName,
        t.identifierForVendorField: info.identifierForVendor,
        t.physicalRamSizeField: info.physicalRamSize,
        t.availableRamSizeField: info.availableRamSize,
        t.sysnameField: info.utsname.sysname,
        t.nodenameField: info.utsname.nodename,
        t.releaseField: info.utsname.release,
        t.versionField: info.utsname.version,
        t.machineField: info.utsname.machine,
        t.isPhysicalDeviceField: info.isPhysicalDevice,
      };
    } else if (info is WindowsDeviceInfo) {
      return {
        t.computerNameField: info.computerName,
        t.numberOfCoresField: info.numberOfCores,
        t.systemMemoryInMegabytesField: info.systemMemoryInMegabytes,
        t.userNameField: info.userName,
        t.majorVersionField: info.majorVersion,
        t.minorVersionField: info.minorVersion,
        t.buildNumberField: info.buildNumber,
        t.displayVersionField: info.displayVersion,
        t.productNameField: info.productName,
        t.registeredOwnerField: info.registeredOwner,
        t.releaseIdField: info.releaseId,
        'deviceId': info.deviceId,
      };
    } else if (info is LinuxDeviceInfo) {
      return {
        t.name: info.name,
        t.versionField: info.version,
        'idLike': info.idLike,
        'versionCodename': info.versionCodename,
        'versionId': info.versionId,
        'prettyName': info.prettyName,
      };
    } else if (info is MacOsDeviceInfo) {
      return {
        t.computerNameField: info.computerName,
        'hostName': info.hostName,
        'arch': info.arch,
        t.model: info.model,
        t.modelNameField: info.modelName,
        'kernelVersion': info.kernelVersion,
        'osRelease': info.osRelease,
        t.majorVersionField: info.majorVersion,
        t.minorVersionField: info.minorVersion,
        'patchVersion': info.patchVersion,
        'activeCPUs': info.activeCPUs,
        'memorySize': info.memorySize,
        'cpuFrequency': info.cpuFrequency,
      };
    } else if (info == null) {
      return {"提示": "未获取到设备信息"};
    }
    return {"信息": info.toString()};
  }
}
