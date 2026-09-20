import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/core/utils/app_exception.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/repositories/user_repository.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late UserRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = UserRepository(
      firestoreService: FirestoreService(firestore: db),
    );
  });

  Future<void> seed(String email, {UserRole role = UserRole.user}) {
    final uid = email.split('@').first;
    return seedProfile(db, uid: uid, name: uid, role: role, email: email);
  }

  Future<UserRole> roleOf(String uid) async {
    final data = (await db.collection('users').doc(uid).get()).data()!;
    return UserRole.fromName(data['role'] as String?);
  }

  group('searchUsers', () {
    test('lists users ordered by email', () async {
      await seed('carol@x.com');
      await seed('alice@x.com');
      await seed('bob@x.com');

      final page = await repository.searchUsers();

      expect(page.users.map((u) => u.email), [
        'alice@x.com',
        'bob@x.com',
        'carol@x.com',
      ]);
      expect(page.hasMore, isFalse);
    });

    test('matches the start of the email, ignoring case', () async {
      await seed('alice@x.com');
      await seed('alan@x.com');
      await seed('bob@x.com');

      final page = await repository.searchUsers(emailPrefix: '  AL ');

      expect(page.users.map((u) => u.email), ['alan@x.com', 'alice@x.com']);
    });

    test('a prefix that matches nobody returns an empty page', () async {
      await seed('alice@x.com');

      final page = await repository.searchUsers(emailPrefix: 'zzz');

      expect(page.users, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('pages through results without repeats or gaps', () async {
      for (final name in ['a', 'b', 'c', 'd', 'e']) {
        await seed('$name@x.com');
      }

      final first = await repository.searchUsers(limit: 2);
      expect(first.users.map((u) => u.email), ['a@x.com', 'b@x.com']);
      expect(first.hasMore, isTrue);

      final second = await repository.searchUsers(
        limit: 2,
        startAfter: first.cursor,
      );
      expect(second.users.map((u) => u.email), ['c@x.com', 'd@x.com']);
      expect(second.hasMore, isTrue);

      final third = await repository.searchUsers(
        limit: 2,
        startAfter: second.cursor,
      );
      expect(third.users.map((u) => u.email), ['e@x.com']);
      expect(third.hasMore, isFalse);
    });

    test('paging stays inside the search prefix', () async {
      for (final email in ['ab1@x.com', 'ab2@x.com', 'ab3@x.com', 'zz@x.com']) {
        await seed(email);
      }

      final first = await repository.searchUsers(emailPrefix: 'ab', limit: 2);
      final second = await repository.searchUsers(
        emailPrefix: 'ab',
        limit: 2,
        startAfter: first.cursor,
      );

      expect(first.users.map((u) => u.email), ['ab1@x.com', 'ab2@x.com']);
      expect(second.users.map((u) => u.email), ['ab3@x.com']);
      expect(second.hasMore, isFalse);
    });

    test('adminsOnly lists admins and the super admin, not users', () async {
      await seed('user@x.com');
      await seed('adm@x.com', role: UserRole.admin);
      await seed('boss@x.com', role: UserRole.superAdmin);

      final page = await repository.searchUsers(adminsOnly: true);

      expect(page.users.map((u) => u.email), ['adm@x.com', 'boss@x.com']);
      expect(page.hasMore, isFalse);
    });

    test('adminsOnly also honours the email prefix', () async {
      await seed('adm@x.com', role: UserRole.admin);
      await seed('boss@x.com', role: UserRole.superAdmin);

      final page = await repository.searchUsers(
        adminsOnly: true,
        emailPrefix: 'bo',
      );

      expect(page.users.map((u) => u.email), ['boss@x.com']);
    });
  });

  group('setRole', () {
    test('promotes a user to admin and demotes them back', () async {
      await seed('sam@x.com');

      await repository.setRole(uid: 'sam', role: UserRole.admin);
      expect(await roleOf('sam'), UserRole.admin);

      await repository.setRole(uid: 'sam', role: UserRole.user);
      expect(await roleOf('sam'), UserRole.user);
    });

    test('changes only the role field', () async {
      await seed('sam@x.com');
      final before = (await db.collection('users').doc('sam').get()).data()!;

      await repository.setRole(uid: 'sam', role: UserRole.admin);

      final after = (await db.collection('users').doc('sam').get()).data()!;
      expect({...after}..remove('role'), {...before}..remove('role'));
    });

    test('can never grant the super admin role', () async {
      await seed('sam@x.com');

      await expectLater(
        repository.setRole(uid: 'sam', role: UserRole.superAdmin),
        throwsA(isA<AppException>()),
      );
      expect(await roleOf('sam'), UserRole.user);
    });

    test('refuses to change a super admin, even from a stale screen', () async {
      await seed('boss@x.com', role: UserRole.superAdmin);

      await expectLater(
        repository.setRole(uid: 'boss', role: UserRole.user),
        throwsA(isA<AppException>()),
      );
      expect(await roleOf('boss'), UserRole.superAdmin);
    });

    test('fails clearly for a user that does not exist', () async {
      await expectLater(
        repository.setRole(uid: 'ghost', role: UserRole.admin),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('no longer exists'),
          ),
        ),
      );
    });
  });
}
