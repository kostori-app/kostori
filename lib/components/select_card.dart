part of 'components.dart';

/// 通用可选卡片：整行点击切换、选中高亮，无左侧勾选框 / 单选框。
class SelectCard extends StatelessWidget {
  const SelectCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 8),
    this.subtitleMaxLines = 1,
  });

  final String title;
  final bool selected;

  /// 为空时卡片不可点击（仍显示为普通卡片）
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// 副标题最多显示行数
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          leading: leading,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
          trailing: trailing,
          onTap: onChanged == null ? null : () => onChanged!(!selected),
        ),
      ),
    );
  }
}
