import 'package:device_info_plus/device_info_plus.dart';
import 'package:kostori/skills/skill.dart';

/// 读取当前设备的基础信息（系统、型号、版本等）
class DeviceInfoSkill extends Skill {
  @override
  String get id => 'get_device_info';

  @override
  String get name => '设备信息';

  @override
  String get description => '读取当前运行设备的系统平台、设备型号、系统版本与应用包信息。';

  @override
  Map<String, dynamic> get inputSchema => {'type': 'object', 'properties': {}};

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final info = await DeviceInfoPlugin().deviceInfo;
    final lines = <String>[
      for (final e in info.data.entries.take(14))
        '${e.key}: ${e.value?.toString() ?? ''}',
    ];
    return lines.join('\n');
  }
}
