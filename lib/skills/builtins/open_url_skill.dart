import 'package:kostori/skills/skill.dart';
import 'package:url_launcher/url_launcher.dart';

/// 打开外部浏览器访问指定 URL
class OpenUrlSkill extends Skill {
  @override
  String get id => 'open_url';

  @override
  String get name => '打开网页';

  @override
  String get description => '使用系统默认浏览器打开指定网址（必须是完整的 http/https URL）。';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'url': {
        'type': 'string',
        'description': '要打开的完整网址，如 https://example.com',
      },
    },
    'required': ['url'],
  };

  @override
  Future<String> execute(Map<String, dynamic> arguments) async {
    final url = arguments['url']?.toString().trim() ?? '';
    if (url.isEmpty) throw SkillException('缺少参数: url');
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
      throw SkillException('无效的 URL: $url');
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return ok ? '已在浏览器中打开: $url' : '打开 $url 失败（系统可能不支持）';
  }
}
