import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/services/auth_service.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreService', () {
    test('exposes the three top-level collections', () async {
      final fake = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: fake);

      await service.users.doc('u1').set({'name': 'A'});
      await service.items.doc('i1').set({'title': 'B'});
      await service.feedback.doc('f1').set({'rating': 5});

      expect((await fake.collection('users').doc('u1').get()).exists, isTrue);
      expect((await fake.collection('items').doc('i1').get()).exists, isTrue);
      expect(
        (await fake.collection('feedback').doc('f1').get()).data()!['rating'],
        5,
      );
    });

    test('runTransaction reads and writes atomically', () async {
      final service = FirestoreService(firestore: FakeFirebaseFirestore());
      final ref = service.items.doc('i1');
      await ref.set({'ratingCount': 1});

      await service.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final count = snap.data()!['ratingCount'] as int;
        tx.update(ref, {'ratingCount': count + 1});
      });

      expect((await ref.get()).data()!['ratingCount'], 2);
    });
  });

  group('AuthService', () {
    test('sign up, sign out and sign in', () async {
      final service = AuthService(auth: MockFirebaseAuth());

      final created = await service.signUp(
        email: 'a@example.com',
        password: 'secret1',
      );
      expect(created.user, isNotNull);
      expect(service.currentUser?.email, 'a@example.com');

      await service.signOut();
      expect(service.currentUser, isNull);

      await service.signIn(email: 'a@example.com', password: 'secret1');
      expect(service.currentUser, isNotNull);
    });

    test('authStateChanges emits null after sign out', () async {
      final service = AuthService(auth: MockFirebaseAuth(signedIn: true));
      expect(service.currentUser, isNotNull);

      final states = <bool>[];
      final sub = service.authStateChanges().listen(
        (u) => states.add(u != null),
      );
      await service.signOut();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states.last, isFalse);
    });
  });
}
