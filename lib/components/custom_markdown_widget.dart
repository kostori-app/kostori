import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/utils/utils.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/config/markdown_generator.dart';
import 'package:markdown_widget/widget/blocks/container/blockquote.dart';
import 'package:markdown_widget/widget/blocks/container/table.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/blocks/leaf/heading.dart';
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
    final codeBorder = isDark ? Colors.white12 : Colors.grey[300]!;
    final tableBorderColor = isDark ? Colors.white24 : Colors.grey[300]!;
    final tableHeaderBg = isDark ? Colors.white10 : Colors.grey[100]!;

    final config = MarkdownConfig(
      configs: [
        // 正文段落
        PConfig(
          textStyle: TextStyle(color: textColor, fontSize: 14, height: 1.6),
        ),

        // 行内代码
        CodeConfig(
          style: TextStyle(
            color: colorScheme.primary,
            backgroundColor: codeBackground,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),

        // 代码块
        PreConfig(
          textStyle: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.greenAccent[200] : Colors.teal[800],
            fontFamily: 'monospace',
          ),
          decoration: BoxDecoration(
            color: codeBackground,
            border: Border.all(color: codeBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),

        // H1
        H1Config(
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),

        // H2
        H2Config(
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),

        // H3
        H3Config(
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),

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
          headPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          bodyPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      markdown = selectable ? SelectionArea(child: column) : column;
    } catch (_) {
      markdown = SelectionArea(
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
}
