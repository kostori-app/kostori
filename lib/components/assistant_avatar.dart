part of 'components.dart';

/// 助手头像：仅支持 base64 图片（data:image/...）；没有图片时显示中性占位图标。
/// 不再用 emoji 当头像。
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, required this.icon, this.size = 40});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (icon.startsWith('data:image')) {
      try {
        final comma = icon.indexOf(',');
        final bytes = base64Decode(icon.substring(comma + 1));
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.secondaryContainer,
      child: Icon(
        Icons.smart_toy_outlined,
        size: size * 0.55,
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}
