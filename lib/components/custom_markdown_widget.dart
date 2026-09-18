import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kostori/components/components.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/i18n/strings.g.dart';
import 'package:kostori/utils/utils.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/config/markdown_generator.dart';
import 'package:markdown_widget/widget/blocks/container/blockquote.dart';
import 'package:markdown_widget/widget/blocks/container/list.dart';
import 'package:markdown_widget/widget/blocks/container/table.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/blocks/leaf/heading.dart';
import 'package:markdown_widget/widget/blocks/leaf/horizontal_rules.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/inlines/code.dart';

class CustomMarkdownWidget extends StatelessWidget {
  const CustomMarkdownWidget({
    super.key,
    required this.data,
    this.selectable = true,
    this.padding = EdgeInsets.zero,
    this.textScaleFactor,
    this.indentFirstLine = false,
  });

  final String data;

  /// 是否支持文字选中
  final bool selectable;

  /// 整体内边距
  final EdgeInsetsGeometry padding;

  /// 文字缩放比例，默认跟随系统
  final double? textScaleFactor;

  /// 是否对普通段落加首行缩进前缀（默认取消，保持正常 markdown 排布）
  final bool indentFirstLine;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : Colors.black87;
    final codeBackground = isDark ? Colors.white10 : Colors.grey[100]!;
    final tableBorderColor = isDark ? Colors.white24 : Colors.grey[300]!;
    final tableHeaderBg = isDark ? Colors.white10 : Colors.grey[100]!;

    final config = MarkdownConfig(
      configs: [
        // 正文段落：略小字号 + 紧凑行高，贴近常见 AI 客户端的排版
        PConfig(
          textStyle: TextStyle(color: textColor, fontSize: 15, height: 1.5),
        ),

        // 行内代码
        CodeConfig(
          style: TextStyle(
            color: colorScheme.primary,
            backgroundColor: codeBackground,
            fontSize: 13.5,
            fontFamily: 'monospace',
          ),
        ),

        // 代码块：自带「语言 + 复制」头部（见 _codeBlockWrapper）
        PreConfig(
          textStyle: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: textColor.toOpacity(0.92),
            fontFamily: 'monospace',
          ),
          // 主题跟随明暗，避免深色下用浅色主题导致颜色发灰发绿
          theme: isDark ? PreConfig.darkConfig.theme : const PreConfig().theme,
          decoration: const BoxDecoration(),
          padding: EdgeInsets.zero,
          margin: EdgeInsets.zero,
          wrapper: (child, code, language) =>
              _codeBlockWrapper(context, child, code, language),
        ),

        // 标题：字号收敛一些，间距紧凑
        H1Config(
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
        H2Config(
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
        H3Config(
          style: TextStyle(
            color: textColor,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),

        // 水平分割线：细线 + 弱化颜色
        HrConfig(height: 1, color: colorScheme.outlineVariant.toOpacity(0.6)),

        // 列表：收紧左侧缩进与行间距（避免「松散列表」大间距）
        ListConfig(marginLeft: 20, marginBottom: 2),

        // 引用块
        BlockquoteConfig(
          textColor: textColor.toOpacity(0.75),
          sideColor: colorScheme.primary,
        ),

        // 表格：表头加粗带背景、细边框、单元格内边距、文字换行、
        // 列宽自适应；窄屏时整表可横向滚动（不撑破气泡）。
        TableConfig(
          border: TableBorder.all(color: tableBorderColor, width: 0.6),
          headerRowDecoration: BoxDecoration(color: tableHeaderBg),
          headerStyle: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            height: 1.4,
          ),
          bodyStyle: TextStyle(color: textColor, fontSize: 13, height: 1.4),
          headPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          bodyPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          wrapper: (child) => ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ),
      ],
    );

    // 自行组装而非直接 MarkdownBlock，以便捕获解析异常：
    // 流式输出中途（如表格未闭合）解析失败时回退为纯文本，避免闪崩；
    // 输出完成后会自动渲染为完整表格。
    Widget markdown;
    try {
      final generator = MarkdownGenerator();
      final widgets = generator.buildWidgets(
        Utils.normalizeData(data, indentFirstLine: indentFirstLine),
        config: config,
      );
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
      markdown = selectable ? AppSelectionArea(child: column) : column;
    } catch (_) {
      markdown = AppSelectionArea(
        child: SelectableText(
          data,
          style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
        ),
      );
    }

    if (textScaleFactor != null) {
      markdown = MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScaleFactor!)),
        child: markdown,
      );
    }

    return Padding(padding: padding, child: markdown);
  }

  /// 代码块外壳：顶部「语言 + 复制」栏 + 内容区，圆角卡片样式
  Widget _codeBlockWrapper(
    BuildContext context,
    Widget child,
    String code,
    String language,
  ) {
    final cs = Theme.of(context).colorScheme;
    final label = language.trim().isEmpty ? 'text' : language.trim();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.toOpacity(0.5),
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: t.copy,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                color: cs.onSurfaceVariant,
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  App.rootContext.showMessage(message: t.copySuccess);
                },
              ),
            ],
          ),
          Divider(height: 1, color: cs.outlineVariant.toOpacity(0.4)),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }
}
