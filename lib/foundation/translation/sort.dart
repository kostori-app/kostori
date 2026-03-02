import 'package:flutter/material.dart';

enum SortId {
  // 中文
  zhCN,
  zhTW,
  zhHK,
  // 英语变体
  enUS,
  enGB,
  // 东亚语言
  ja,
  ko,
  // 欧洲语言
  fr,
  de,
  es,
  it,
  pt,
  ru,
}

class Sort {
  final SortId id;
  final String label;
  final String extData;
  final String deeplCode;
  final StatelessWidget? icon;

  const Sort({
    required this.id,
    required this.label,
    this.icon,
    this.extData = '',
    this.deeplCode = '',
  });
}

extension SortExt on List<Sort> {
  String labelByExtData(String extData, {String defaultLabel = '简体中文'}) {
    final sort = firstWhere(
      (s) => s.extData == extData,
      orElse: () => Sort(id: SortId.zhCN, label: defaultLabel, extData: ''),
    );
    return sort.label.isEmpty ? defaultLabel : sort.label;
  }
}
