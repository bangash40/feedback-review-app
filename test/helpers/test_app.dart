import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/app.dart';
import 'package:feedback_review_app/core/router/app_router.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:feedback_review_app/providers/firebase_providers.dart';
import 'package:feedback_review_app/repositories/feedback_repository.dart';
import 'package:feedback_review_app/services/auth_service.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The whole app wired to in-memory Firebase fakes.
Widget buildApp(MockFirebaseAuth auth, FakeFirebaseFirestore db) {
  return ProviderScope(
    // No retries: a failing stream should surface, not leave timers pending.
    retry: (_, _) => null,
    overrides: [
      authServiceProvider.overrideWithValue(AuthService(auth: auth)),
      firestoreServiceProvider.overrideWithValue(
        FirestoreService(firestore: db),
      ),
    ],
    child: const FeedbackReviewApp(),
  );
}

/// A mock auth that is already signed in as [uid].
MockFirebaseAuth signedInAs(String uid) {
  return MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid, email: '$uid@example.com'),
  );
}

Future<void> seedProfile(
  FakeFirebaseFirestore db, {
  required String uid,
  required String name,
  required UserRole role,
  String? email,
}) {
  return db
      .collection('users')
      .doc(uid)
      .set(
        AppUser(
          uid: uid,
          name: name,
          email: email ?? '$uid@example.com',
          role: role,
          createdAt: DateTime(2026),
        ).toMap(),
      );
}

/// Adds an item; [minutesAgo] controls the newest-first ordering.
Future<void> seedItem(
  FakeFirebaseFirestore db, {
  required String id,
  required String title,
  ItemType type = ItemType.task,
  bool isActive = true,
  String description = '',
  int ratingCount = 0,
  int ratingSum = 0,
  int minutesAgo = 0,
}) {
  return db
      .collection('items')
      .doc(id)
      .set(
        Item(
          id: id,
          title: title,
          description: description,
          type: type,
          isActive: isActive,
          createdBy: 'admin1',
          createdAt: DateTime(
            2026,
            1,
            1,
          ).subtract(Duration(minutes: minutesAgo)),
          ratingCount: ratingCount,
          ratingSum: ratingSum,
          averageRating: ratingCount == 0 ? 0 : ratingSum / ratingCount,
        ).toMap(),
      );
}

/// Leaves a review the same way the app does, so the item's rating totals
/// stay consistent with the feedback documents.
Future<void> seedFeedback(
  FakeFirebaseFirestore db, {
  required String itemId,
  required String uid,
  String name = 'Sam',
  int rating = 4,
  String review = '',
  String suggestion = '',
}) {
  return FeedbackRepository(firestoreService: FirestoreService(firestore: db))
      .submit(
        itemId: itemId,
        userId: uid,
        userName: name,
        rating: rating,
        review: review,
        suggestion: suggestion,
      );
}

/// Navigates the running app to [location] via its router.
void goTo(WidgetTester tester, String location) {
  final context = tester.element(find.byType(MaterialApp));
  ProviderScope.containerOf(context).read(routerProvider).go(location);
}
