import 'package:cloud_firestore/cloud_firestore.dart';

import 'item.dart';

/// One user's rating and review of an item: `feedback/{feedbackId}`.
///
/// Named `FeedbackModel` to avoid clashing with Flutter's own `Feedback`
/// widget. [itemTitle], [itemType] and [userName] are denormalized so the
/// admin dashboard can render rows without extra reads.
class FeedbackModel {
  const FeedbackModel({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.itemType,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.review = '',
    this.suggestion = '',
  });

  final String id;
  final String itemId;
  final String itemTitle;
  final ItemType itemType;
  final String userId;
  final String userName;

  /// Star rating, 1 to 5.
  final int rating;
  final String review;
  final String suggestion;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return FeedbackModel(
      id: map['id'] as String,
      itemId: (map['itemId'] as String?) ?? '',
      itemTitle: (map['itemTitle'] as String?) ?? '',
      itemType: ItemType.fromName(map['itemType'] as String?),
      userId: (map['userId'] as String?) ?? '',
      userName: (map['userName'] as String?) ?? '',
      rating: (map['rating'] as num?)?.toInt() ?? 0,
      review: (map['review'] as String?) ?? '',
      suggestion: (map['suggestion'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? now,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? now,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'itemTitle': itemTitle,
    'itemType': itemType.name,
    'userId': userId,
    'userName': userName,
    'rating': rating,
    'review': review,
    'suggestion': suggestion,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  FeedbackModel copyWith({
    int? rating,
    String? review,
    String? suggestion,
    DateTime? updatedAt,
  }) {
    return FeedbackModel(
      id: id,
      itemId: itemId,
      itemTitle: itemTitle,
      itemType: itemType,
      userId: userId,
      userName: userName,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      suggestion: suggestion ?? this.suggestion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
