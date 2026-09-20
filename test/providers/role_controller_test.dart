import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/core/utils/app_exception.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/providers/auth_providers.dart';
import 'package:feedback_review_app/providers/firebase_providers.dart';
import 'package:feedback_review_app/providers/user_providers.dart';
import 'package:feedback_review_app/services/auth_service.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// A container signed in as [uid], with that user's profile loaded.
Future<ProviderContainer> containerFor(
  String uid,
  FakeFirebaseFirestore db,
) async {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(AuthService(auth: signedInAs(uid))),
      firestoreServiceProvider.overrideWithValue(
        FirestoreService(firestore: db),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Keep the profile alive and wait until the signed-in user's own profile has
  // really loaded (it is null until auth reports the user).
  container.listen(currentUserProvider, (_, _) {}, fireImmediately: true);
  for (var i = 0; i < 50; i++) {
    if (container.read(currentUserProvider).value?.uid == uid) return container;
    await Future<void>.delayed(Duration.zero);
  }
  fail('The profile for $uid never loaded');
}

void main() {
  late FakeFirebaseFirestore db;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await seedProfile(db, uid: 'boss', name: 'Boss', role: UserRole.superAdmin);
    await seedProfile(db, uid: 'adm', name: 'Adam', role: UserRole.admin);
    await seedProfile(db, uid: 'sam', name: 'Sam', role: UserRole.user);
  });

  AppUser userOf(String uid, String name, UserRole role) => AppUser(
    uid: uid,
    name: name,
    email: '$uid@example.com',
    role: role,
    createdAt: DateTime(2026),
  );

  Future<UserRole> roleOf(String uid) async {
    final data = (await db.collection('users').doc(uid).get()).data()!;
    return UserRole.fromName(data['role'] as String?);
  }

  test('the super admin can promote a user', () async {
    final container = await containerFor('boss', db);

    final ok = await container
        .read(roleControllerProvider.notifier)
        .setRole(userOf('sam', 'Sam', UserRole.user), UserRole.admin);

    expect(ok, isTrue);
    expect(await roleOf('sam'), UserRole.admin);
  });

  test('a regular admin cannot change roles', () async {
    final container = await containerFor('adm', db);

    final ok = await container
        .read(roleControllerProvider.notifier)
        .setRole(userOf('sam', 'Sam', UserRole.user), UserRole.admin);

    expect(ok, isFalse);
    expect(
      (container.read(roleControllerProvider).error as AppException).message,
      contains('Only the super admin'),
    );
    expect(await roleOf('sam'), UserRole.user);
  });

  test('a regular user cannot change roles', () async {
    final container = await containerFor('sam', db);

    final ok = await container
        .read(roleControllerProvider.notifier)
        .setRole(userOf('sam', 'Sam', UserRole.user), UserRole.admin);

    expect(ok, isFalse);
    expect(await roleOf('sam'), UserRole.user);
  });

  test('the super admin cannot change their own role', () async {
    final container = await containerFor('boss', db);

    final ok = await container
        .read(roleControllerProvider.notifier)
        .setRole(userOf('boss', 'Boss', UserRole.superAdmin), UserRole.user);

    expect(ok, isFalse);
    expect(
      (container.read(roleControllerProvider).error as AppException).message,
      contains('own role'),
    );
    expect(await roleOf('boss'), UserRole.superAdmin);
  });

  test('nobody can grant the super admin role', () async {
    final container = await containerFor('boss', db);

    final ok = await container
        .read(roleControllerProvider.notifier)
        .setRole(userOf('sam', 'Sam', UserRole.user), UserRole.superAdmin);

    expect(ok, isFalse);
    expect(await roleOf('sam'), UserRole.user);
  });
}
