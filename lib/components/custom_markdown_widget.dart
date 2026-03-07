import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:kostori/utils/utils.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/blocks/container/blockquote.dart';
import 'package:markdown_widget/widget/blocks/leaf/code_block.dart';
import 'package:markdown_widget/widget/blocks/leaf/heading.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/inlines/code.dart';
import 'package:markdown_widget/widget/markdown_block.dart';

class CustomMarkdownWidget extends StatelessWidget {
  const CustomMarkdownWidget({
    super.key,
    required this.data,
    this.selectable = true,
    this.padding = EdgeInsets.zero,
    this.textScaleFactor,
  });

  final String data;

  /// 是否支持文字选中
  final bool selectable;

  /// 整体内边距
  final EdgeInsetsGeometry padding;

  /// 文字缩放比例，默认跟随系统
  final double? textScaleFactor;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDark ? Colors.white : Colors.black87;
    final codeBackground = isDark ? Colors.white10 : Colors.grey[100]!;
    final codeBorder = isDark ? Colors.white12 : Colors.grey[300]!;

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
      ],
    );

    Widget markdown = MarkdownBlock(
      data: Utils.normalizeData(data),
      config: config,
      selectable: selectable,
    );

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
