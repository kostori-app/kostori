import 'package:flutter/material.dart';
import 'package:kostori/foundation/app.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/inlines/code.dart';
import 'package:markdown_widget/widget/markdown_block.dart';

class CustomMarkdownWidget extends StatelessWidget {
  const CustomMarkdownWidget({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final config = MarkdownConfig(
      configs: [
        PConfig(
          textStyle: TextStyle(
            color: context.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        CodeConfig(
          style: TextStyle(
            color: context.isDarkMode ? Colors.white : Colors.black,
            backgroundColor: context.isDarkMode
                ? Colors.black26
                : Colors.grey[200],
          ),
        ),
      ],
    );
    return MarkdownBlock(data: data, config: config);
  }
}
