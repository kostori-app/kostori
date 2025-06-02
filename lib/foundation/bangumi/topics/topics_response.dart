import 'package:kostori/foundation/bangumi/topics/topics_item.dart';

class TopicsResponse {
  final List<TopicsItem> topicsList;

  TopicsResponse({required this.topicsList});

  factory TopicsResponse.fromJson(List list) {
    List<TopicsItem> resTopicsList =
        list.map((i) => TopicsItem.fromJson(i)).toList();
    return TopicsResponse(
      topicsList: resTopicsList,
    );
  }

  factory TopicsResponse.fromTemplate() {
    return TopicsResponse(
      topicsList: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topicsList': topicsList.map((e) => e.toJson()).toList(),
    };
  }
}
