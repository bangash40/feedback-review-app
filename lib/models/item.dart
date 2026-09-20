import 'package:cloud_firestore/cloud_firestore.dart';

/// What kind of subject an item is.
enum ItemType {
  task,
  course,
  service;

  static ItemType fromName(String? name) =>
      ItemType.values.firstWhere((t) => t.name == name, orElse: () => task);

  /// Human-readable label for the UI.
  String get label => switch (this) {
    ItemType.task => 'Task',
    ItemType.course => 'Course',
    ItemType.service => 'Service',
  };
}

/// A feedback subject created by an admin: `items/{itemId}`.
///
/// [ratingCount], [ratingSum] and [averageRating] are denormalized aggregates
/// kept up to date by the feedback repository on every feedback write.
class Item {
  const Item({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    this.ratingCount = 0,
    this.ratingSum = 0,
    this.averageRating = 0.0,
  });

  final String id;
  final String title;
  final String description;
  final ItemType type;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final int ratingCount;
  final int ratingSum;
  final double averageRating;

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      type: ItemType.fromName(map['type'] as String?),
      isActive: (map['isActive'] as bool?) ?? true,
      createdBy: (map['createdBy'] as String?) ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      ratingSum: (map['ratingSum'] as num?)?.toInt() ?? 0,
      averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'isActive': isActive,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(createdAt),
    'ratingCount': ratingCount,
    'ratingSum': ratingSum,
    'averageRating': averageRating,
  };

  Item copyWith({
    String? title,
    String? description,
    ItemType? type,
    bool? isActive,
    int? ratingCount,
    int? ratingSum,
    double? averageRating,
  }) {
    return Item(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy,
      createdAt: createdAt,
      ratingCount: ratingCount ?? this.ratingCount,
      ratingSum: ratingSum ?? this.ratingSum,
      averageRating: averageRating ?? this.averageRating,
    );
  }
}
