import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/repositories/auth_repository.dart';
import 'package:feedback_review_app/services/auth_service.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late AuthRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    repository = AuthRepository(
      authService: AuthService(auth: auth),
      firestoreService: FirestoreService(firestore: db),
    );
  });

  test('signUp creates the account and a profile with role user', () async {
    await repository.signUp(
      name: '  Farhan  ',
      email: 'f@example.com',
      password: 'secret1',
    );

    final uid = repository.currentUser!.uid;
    final doc = await db.collection('users').doc(uid).get();
    expect(doc.exists, isTrue);

    final profile = AppUser.fromMap(doc.data()!);
    expect(profile.uid, uid);
    expect(profile.name, 'Farhan');
    expect(profile.email, 'f@example.com');
    expect(profile.role, UserRole.user);
  });

  test('signIn recreates a missing profile', () async {
    await repository.signUp(
      name: 'Farhan',
      email: 'f@example.com',
      password: 'secret1',
    );
    final uid = repository.currentUser!.uid;
    await repository.signOut();
    await db.collection('users').doc(uid).delete();

    await repository.signIn(email: 'f@example.com', password: 'secret1');

    final doc = await db
        .collection('users')
        .doc(repository.currentUser!.uid)
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['role'], 'user');
  });

  test(
    'signIn leaves an existing profile untouched (keeps admin role)',
    () async {
      final admin = MockFirebaseAuth(
        mockUser: MockUser(uid: 'admin1', email: 'admin@example.com'),
      );
      await db
          .collection('users')
          .doc('admin1')
          .set(
            AppUser(
              uid: 'admin1',
              name: 'Boss',
              email: 'admin@example.com',
              role: UserRole.admin,
              createdAt: DateTime(2026),
            ).toMap(),
          );
      final adminRepo = AuthRepository(
        authService: AuthService(auth: admin),
        firestoreService: FirestoreService(firestore: db),
      );

      await adminRepo.signIn(email: 'admin@example.com', password: 'secret1');

      final doc = await db.collection('users').doc('admin1').get();
      expect(doc.data()!['role'], 'admin');
      expect(doc.data()!['name'], 'Boss');
    },
  );

  test('watchUser emits the profile and null when missing', () async {
    expect(await repository.watchUser('nobody').first, isNull);

    await db
        .collection('users')
        .doc('u1')
        .set(
          AppUser(
            uid: 'u1',
            name: 'A',
            email: 'a@example.com',
            role: UserRole.user,
            createdAt: DateTime(2026),
          ).toMap(),
        );
    final profile = await repository.watchUser('u1').first;
    expect(profile?.name, 'A');
  });
}
