import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/core/utils/app_exception.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/providers/auth_providers.dart';
import 'package:feedback_review_app/providers/feedback_providers.dart';
import 'package:feedback_review_app/providers/firebase_providers.dart';
import 'package:feedback_review_app/services/auth_service.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

ProviderContainer containerWith(
  MockFirebaseAuth auth,
  FakeFirebaseFirestore db,
) {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(AuthService(auth: auth)),
      firestoreServiceProvider.overrideWithValue(
        FirestoreService(firestore: db),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the auth stream and the profile stream deliver their first values.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
    await seedItem(db, id: 'i1', title: 'Flutter Basics');
  });

  test('submit stores the signed-in user and their profile name', () async {
    final container = containerWith(signedInAs('u1'), db);
    container.listen(currentUserProvider, (_, _) {}, fireImmediately: true);
    await settle();

    final ok = await container
        .read(feedbackControllerProvider.notifier)
        .submit(itemId: 'i1', rating: 5, review: 'Great');

    expect(ok, isTrue);
    final saved = (await db.collection('feedback').doc('i1_u1').get()).data()!;
    expect(saved['userId'], 'u1');
    expect(saved['userName'], 'Sam');
    expect(saved['rating'], 5);
  });

  test('submit fails clearly when nobody is signed in', () async {
    final container = containerWith(MockFirebaseAuth(), db);
    container.listen(signedInUidProvider, (_, _) {}, fireImmediately: true);
    await settle();

    final ok = await container
        .read(feedbackControllerProvider.notifier)
        .submit(itemId: 'i1', rating: 5);

    expect(ok, isFalse);
    expect(
      (container.read(feedbackControllerProvider).error as AppException)
          .message,
      contains('log in'),
    );
    expect(await db.collection('feedback').get().then((s) => s.size), 0);
  });

  test('submit waits for the profile instead of guessing a name', () async {
    // Signed in, but there is no profile document to take a name from.
    final container = containerWith(signedInAs('nobody'), db);
    container.listen(currentUserProvider, (_, _) {}, fireImmediately: true);
    await settle();

    final ok = await container
        .read(feedbackControllerProvider.notifier)
        .submit(itemId: 'i1', rating: 5);

    expect(ok, isFalse);
    expect(
      (container.read(feedbackControllerProvider).error as AppException)
          .message,
      contains('profile is still loading'),
    );
    expect(await db.collection('feedback').get().then((s) => s.size), 0);
  });

  test('a repository failure becomes a friendly error', () async {
    final container = containerWith(signedInAs('u1'), db);
    container.listen(currentUserProvider, (_, _) {}, fireImmediately: true);
    await settle();

    final ok = await container
        .read(feedbackControllerProvider.notifier)
        .submit(itemId: 'missing-item', rating: 4);

    expect(ok, isFalse);
    expect(
      (container.read(feedbackControllerProvider).error as AppException)
          .message,
      contains('no longer exists'),
    );
  });

  test('my feedback for one item is picked out of my whole list', () async {
    await seedItem(db, id: 'i2', title: 'Other');
    final container = containerWith(signedInAs('u1'), db);
    container.listen(myFeedbackProvider, (_, _) {}, fireImmediately: true);
    container.listen(currentUserProvider, (_, _) {}, fireImmediately: true);
    await settle();
    final controller = container.read(feedbackControllerProvider.notifier);
    await controller.submit(itemId: 'i1', rating: 5);
    await controller.submit(itemId: 'i2', rating: 2);
    await settle();

    final forFirst = container.read(myFeedbackForItemProvider('i1')).value;
    final forSecond = container.read(myFeedbackForItemProvider('i2')).value;
    final forNone = container.read(myFeedbackForItemProvider('zzz')).value;

    expect(forFirst?.rating, 5);
    expect(forSecond?.rating, 2);
    expect(forNone, isNull);
  });
}
