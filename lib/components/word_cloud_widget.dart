import 'package:flutter/material.dart';
import 'package:kostori/foundation/consts.dart';
import 'package:word_cloud/word_cloud_data.dart';
import 'package:word_cloud/word_cloud_view.dart';

class WordCloudWidget extends StatefulWidget {
  final List<Map<String, dynamic>> wordCloudData;

  const WordCloudWidget({super.key, required this.wordCloudData});

  @override
  State<WordCloudWidget> createState() => _WordCloudWidgetState();
}

class _WordCloudWidgetState extends State<WordCloudWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight.isInfinite
            ? 400.0
            : constraints.maxHeight;

        final minSize = (w * 0.01).clamp(5.0, 12.0);
        final maxSize = (w * 0.08).clamp(20.0, 80.0);

        return WordCloudView(
          key: ValueKey('$w-$h'),
          data: WordCloudData(data: widget.wordCloudData),
          mapwidth: w,
          mapheight: h,
          mintextsize: minSize,
          maxtextsize: maxSize,
          colorlist: standardColorMap.keys.toList(),
        );
      },
    );
  }
}
