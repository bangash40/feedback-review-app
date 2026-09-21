import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/app_exception.dart';
import '../models/feedback_model.dart';
import '../models/item.dart';
import '../services/firestore_service.dart';

/// Reads and writes `feedback/{feedbackId}` and keeps each item's rating
/// aggregates (`ratingCount`, `ratingSum`, `averageRating`) in step.
///
/// The document id is `{itemId}_{userId}`, so a user can only ever have one
/// review per item: submitting again updates that review in place.
class FeedbackRepository {
  FeedbackRepository({required FirestoreService firestoreService})
    : _firestore = firestoreService;

  final FirestoreService _firestore;

  /// The single feedback document id for [userId]'s review of [itemId].
  static String idFor(String itemId, String userId) => '${itemId}_$userId';

  /// All of [userId]'s feedback, most recently changed first.
  ///
  /// Filters by `userId` (which Firestore's owner rule can verify) and sorts
  /// on the client, so it needs no composite index.
  Stream<List<FeedbackModel>> watchMyFeedback(String userId) {
    return _firestore.feedback
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map(
                (doc) => FeedbackModel.fromMap({...doc.data(), 'id': doc.id}),
              )
              .toList();
          list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return list;
        });
  }

  /// How many feedback entries the admin dashboard loads.
  ///
  /// The dashboard filters, sorts and summarizes on the device, which needs no
  /// composite indexes and makes every filter instant. That is comfortable for
  /// a few hundred to a few thousand entries; beyond that the filters should
  /// move to server-side queries.
  static const dashboardLimit = 500;

  /// The newest [limit] feedback entries across all users (admin only).
  Stream<List<FeedbackModel>> watchAllFeedback({int limit = dashboardLimit}) {
    return _firestore.feedback
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => FeedbackModel.fromMap({...doc.data(), 'id': doc.id}),
              )
              .toList(),
        );
  }

  /// One feedback entry (admin only); emits null if it does not exist.
  Stream<FeedbackModel?> watchFeedback(String id) {
    return _firestore.feedback.doc(id).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null
          ? null
          : FeedbackModel.fromMap({...data, 'id': snapshot.id});
    });
  }

  /// Creates or updates [userId]'s review of [itemId] and adjusts the item's
  /// aggregates, atomically, so the average is always right.
  Future<void> submit({
    required String itemId,
    required String userId,
    required String userName,
    required int rating,
    String review = '',
    String suggestion = '',
  }) async {
    if (rating < 1 || rating > 5) {
      throw const AppException('Choose a rating from 1 to 5 stars.');
    }

    final itemRef = _firestore.items.doc(itemId);
    final feedbackRef = _firestore.feedback.doc(idFor(itemId, userId));

    await _firestore.runTransaction((transaction) async {
      // Firestore requires every read to happen before any write.
      final itemSnapshot = await transaction.get(itemRef);
      final feedbackSnapshot = await transaction.get(feedbackRef);

      final itemData = itemSnapshot.data();
      if (itemData == null) {
        throw const AppException('This item no longer exists.');
      }
      final item = Item.fromMap({...itemData, 'id': itemSnapshot.id});

      var count = item.ratingCount;
      var sum = item.ratingSum;

      if (feedbackSnapshot.data() == null) {
        if (!item.isActive) {
          throw const AppException(
            'This item is no longer accepting feedback.',
          );
        }
        count += 1;
        sum += rating;
        final now = DateTime.now();
        transaction.set(feedbackRef, {
          ...FeedbackModel(
            id: feedbackRef.id,
            itemId: itemId,
            itemTitle: item.title,
            itemType: item.type,
            userId: userId,
            userName: userName,
            rating: rating,
            review: review.trim(),
            suggestion: suggestion.trim(),
            createdAt: now,
            updatedAt: now,
          ).toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Editing: the count is unchanged, only the rating's difference moves.
        final previous =
            (feedbackSnapshot.data()!['rating'] as num?)?.toInt() ?? 0;
        sum += rating - previous;
        transaction.update(feedbackRef, {
          'itemTitle': item.title,
          'itemType': item.type.name,
          'userName': userName,
          'rating': rating,
          'review': review.trim(),
          'suggestion': suggestion.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(itemRef, _aggregates(count: count, sum: sum));
    });
  }

  /// Deletes a review and takes its rating back out of the item's aggregates.
  /// Does nothing if the review is already gone.
  Future<void> deleteFeedback(String feedbackId) async {
    final feedbackRef = _firestore.feedback.doc(feedbackId);

    await _firestore.runTransaction((transaction) async {
      final feedbackSnapshot = await transaction.get(feedbackRef);
      final data = feedbackSnapshot.data();
      if (data == null) return;

      final itemRef = _firestore.items.doc(data['itemId'] as String);
      final itemSnapshot = await transaction.get(itemRef);

      transaction.delete(feedbackRef);

      final itemData = itemSnapshot.data();
      if (itemData != null) {
        final item = Item.fromMap({...itemData, 'id': itemSnapshot.id});
        final rating = (data['rating'] as num?)?.toInt() ?? 0;
        transaction.update(
          itemRef,
          _aggregates(
            count: math.max(0, item.ratingCount - 1),
            sum: math.max(0, item.ratingSum - rating),
          ),
        );
      }
    });
  }

  Map<String, Object> _aggregates({required int count, required int sum}) => {
    'ratingCount': count,
    'ratingSum': sum,
    'averageRating': count == 0 ? 0.0 : sum / count,
  };
}
