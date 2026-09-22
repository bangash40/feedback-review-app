import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/core/utils/app_exception.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/providers/auth_providers.dart';
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

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('updateName saves the new name for the signed-in user', () async {
    final db = FakeFirebaseFirestore();
    await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
    final container = containerWith(signedInAs('u1'), db);
    container.listen(currentUserProvider, (_, _) {}, fireImmediately: true);
    await settle();

    final ok = await container
        .read(profileControllerProvider.notifier)
        .updateName('Samantha');

    expect(ok, isTrue);
    final saved = await db.collection('users').doc('u1').get();
    expect(saved.data()!['name'], 'Samantha');
  });

  test('updateName fails clearly when nobody is signed in', () async {
    final container = containerWith(
      MockFirebaseAuth(),
      FakeFirebaseFirestore(),
    );
    container.listen(signedInUidProvider, (_, _) {}, fireImmediately: true);
    await settle();

    final ok = await container
        .read(profileControllerProvider.notifier)
        .updateName('New Name');

    expect(ok, isFalse);
    expect(
      (container.read(profileControllerProvider).error as AppException).message,
      contains('log in'),
    );
  });
}
