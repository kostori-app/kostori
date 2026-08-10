import 'package:kostori/foundation/bangumi/bangumi_item.dart';
import 'package:kostori/foundation/bangumi/staff/staff_item.dart';

/// 人物参与作品（/p1/persons/{id}/works 的 data 项）
class PersonWorkItem {
  final BangumiItem subject;
  final List<Position> positions;

  PersonWorkItem({required this.subject, required this.positions});

  factory PersonWorkItem.fromJson(Map<String, dynamic> json) {
    return PersonWorkItem(
      subject: BangumiItem.fromJson(json['subject'] ?? {}),
      positions: (json['positions'] as List? ?? [])
          .map((e) => Position.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
