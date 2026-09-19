import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/feedback_model.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Whole-minute dates make the Timestamp comparison exact.
  final created = DateTime(2026, 9, 19, 10, 30);
  final updated = DateTime(2026, 9, 20, 8, 15);

  group('AppUser', () {
    test('round-trips through map serialization', () {
      final user = AppUser(
        uid: 'u1',
        name: 'Farhan',
        email: 'f@example.com',
        role: UserRole.admin,
        createdAt: created,
      );
      final copy = AppUser.fromMap(user.toMap());
      expect(copy.uid, 'u1');
      expect(copy.name, 'Farhan');
      expect(copy.email, 'f@example.com');
      expect(copy.role, UserRole.admin);
      expect(copy.isAdmin, isTrue);
      expect(copy.createdAt, created);
    });

    test('unknown or missing role falls back to user', () {
      expect(AppUser.fromMap({'uid': 'u2', 'role': 'superuser'}).role,
          UserRole.user);
      expect(AppUser.fromMap({'uid': 'u3'}).role, UserRole.user);
    });

    test('toMap writes dates as Firestore Timestamps', () {
      final map = AppUser(
        uid: 'u1',
        name: 'N',
        email: 'e',
        role: UserRole.user,
        createdAt: created,
      ).toMap();
      expect(map['createdAt'], isA<Timestamp>());
    });
  });

  group('Item', () {
    test('round-trips through map serialization', () {
      final item = Item(
        id: 'i1',
        title: 'Flutter Basics',
        description: 'Intro course',
        type: ItemType.course,
        isActive: false,
        createdBy: 'admin1',
        createdAt: created,
        ratingCount: 4,
        ratingSum: 17,
        averageRating: 4.25,
      );
      final copy = Item.fromMap(item.toMap());
      expect(copy.id, 'i1');
      expect(copy.title, 'Flutter Basics');
      expect(copy.description, 'Intro course');
      expect(copy.type, ItemType.course);
      expect(copy.isActive, isFalse);
      expect(copy.createdBy, 'admin1');
      expect(copy.createdAt, created);
      expect(copy.ratingCount, 4);
      expect(copy.ratingSum, 17);
      expect(copy.averageRating, 4.25);
    });

    test('aggregates default to zero and whole-number averages parse', () {
      final item = Item.fromMap({'id': 'i2', 'averageRating': 3});
      expect(item.ratingCount, 0);
      expect(item.ratingSum, 0);
      expect(item.averageRating, 3.0);
      expect(item.isActive, isTrue);
    });
  });

  group('FeedbackModel', () {
    test('round-trips through map serialization', () {
      final feedback = FeedbackModel(
        id: 'f1',
        itemId: 'i1',
        itemTitle: 'Flutter Basics',
        itemType: ItemType.course,
        userId: 'u1',
        userName: 'Farhan',
        rating: 5,
        review: 'Great',
        suggestion: 'More examples',
        createdAt: created,
        updatedAt: updated,
      );
      final copy = FeedbackModel.fromMap(feedback.toMap());
      expect(copy.id, 'f1');
      expect(copy.itemId, 'i1');
      expect(copy.itemTitle, 'Flutter Basics');
      expect(copy.itemType, ItemType.course);
      expect(copy.userId, 'u1');
      expect(copy.userName, 'Farhan');
      expect(copy.rating, 5);
      expect(copy.review, 'Great');
      expect(copy.suggestion, 'More examples');
      expect(copy.createdAt, created);
      expect(copy.updatedAt, updated);
    });

    test('review and suggestion are optional', () {
      final copy = FeedbackModel.fromMap({'id': 'f2', 'rating': 3});
      expect(copy.review, '');
      expect(copy.suggestion, '');
    });

    test('copyWith keeps identity and changes only what is given', () {
      final feedback = FeedbackModel(
        id: 'f1',
        itemId: 'i1',
        itemTitle: 'T',
        itemType: ItemType.task,
        userId: 'u1',
        userName: 'N',
        rating: 2,
        createdAt: created,
        updatedAt: created,
      );
      final edited = feedback.copyWith(rating: 4, updatedAt: updated);
      expect(edited.rating, 4);
      expect(edited.updatedAt, updated);
      expect(edited.createdAt, created);
      expect(edited.id, 'f1');
    });
  });
}
