import 'package:kostori/foundation/bangumi/reviews/reviews_item.dart';

class ReviewsResponse {
  final List<ReviewsItem> reviewsList;

  ReviewsResponse({required this.reviewsList});

  factory ReviewsResponse.fromJson(List list) {
    List<ReviewsItem> resTopicsList =
        list.map((i) => ReviewsItem.fromJson(i)).toList();
    return ReviewsResponse(
      reviewsList: resTopicsList,
    );
  }

  factory ReviewsResponse.fromTemplate() {
    return ReviewsResponse(
      reviewsList: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewsList': reviewsList.map((e) => e.toJson()).toList(),
    };
  }
}
