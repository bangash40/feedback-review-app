import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// A super admin (Boss), an admin, and a few regular users.
Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  Future<void> user(String uid, String name, String email, UserRole role) =>
      seedProfile(db, uid: uid, name: name, role: role, email: email);

  await user('boss', 'Boss', 'boss@x.com', UserRole.superAdmin);
  await user('adm', 'Adam', 'adam@x.com', UserRole.admin);
  await user('alice', 'Alice', 'alice@x.com', UserRole.user);
  await user('alan', 'Alan', 'alan@x.com', UserRole.user);
  await user('bob', 'Bob', 'bob@x.com', UserRole.user);
  return db;
}

Future<UserRole> roleOf(FakeFirebaseFirestore db, String uid) async {
  final data = (await db.collection('users').doc(uid).get()).data()!;
  return UserRole.fromName(data['role'] as String?);
}

/// Opens Manage users as the super admin.
Future<void> openManageUsers(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  await tester.pumpWidget(buildApp(signedInAs('boss'), db));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Manage users'));
  await tester.pumpAndSettle();
}

/// Types into the search box and waits out the debounce.
Future<void> searchFor(WidgetTester tester, String text) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Search by email'),
    text,
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Finder roleMenuFor(String name) => find.byTooltip('Change role for $name');

void main() {
  group('who can reach user management', () {
    testWidgets('the super admin sees the button and the label', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(signedInAs('boss'), await world()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Boss (super admin)'), findsOneWidget);
      expect(find.text('Manage users'), findsOneWidget);
    });

    testWidgets('a regular admin has no button and is bounced back', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(signedInAs('adm'), await world()));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Adam (admin)'), findsOneWidget);
      expect(find.text('Manage users'), findsNothing);

      goTo(tester, '/admin/users');
      await tester.pumpAndSettle();

      expect(find.text('Admin dashboard'), findsOneWidget);
      expect(find.text('Manage users'), findsNothing);
    });

    testWidgets('a regular user cannot open it either', (tester) async {
      await tester.pumpWidget(buildApp(signedInAs('bob'), await world()));
      await tester.pumpAndSettle();

      goTo(tester, '/admin/users');
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Bob'), findsOneWidget);
    });
  });

  group('managing users', () {
    testWidgets('lists everyone, marking the signed-in user', (tester) async {
      await openManageUsers(tester, await world());

      expect(find.text('Boss (you)'), findsOneWidget);
      expect(find.text('Adam'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Super admin'), findsOneWidget);
    });

    testWidgets('search narrows the list by email prefix', (tester) async {
      await openManageUsers(tester, await world());

      await searchFor(tester, 'AL');

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Alan'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);

      await searchFor(tester, 'nobody');
      expect(find.text('No users found'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('promotes a user after confirming', (tester) async {
      final db = await world();
      await openManageUsers(tester, db);

      await tester.tap(roleMenuFor('Alice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make admin').last);
      await tester.pumpAndSettle();

      // A confirmation names what will happen; nothing changed yet.
      expect(find.text('Make admin?'), findsOneWidget);
      expect(await roleOf(db, 'alice'), UserRole.user);

      await tester.tap(find.widgetWithText(FilledButton, 'Make admin'));
      await tester.pumpAndSettle();

      expect(await roleOf(db, 'alice'), UserRole.admin);
      expect(find.text('Alice is now an admin'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      final db = await world();
      await openManageUsers(tester, db);

      await tester.tap(roleMenuFor('Alice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make admin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await roleOf(db, 'alice'), UserRole.user);
      expect(find.text('Alice is now an admin'), findsNothing);
    });

    testWidgets('demotes an admin back to a regular user', (tester) async {
      final db = await world();
      await openManageUsers(tester, db);

      await tester.tap(roleMenuFor('Adam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make regular user'));
      await tester.pumpAndSettle();
      expect(find.text('Remove admin?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove admin'));
      await tester.pumpAndSettle();

      expect(await roleOf(db, 'adm'), UserRole.user);
      expect(find.text('Adam is now a regular user'), findsOneWidget);
    });

    testWidgets('you cannot change your own role or another super admin', (
      tester,
    ) async {
      final db = await world();
      await seedProfile(
        db,
        uid: 'boss2',
        name: 'Second Boss',
        role: UserRole.superAdmin,
        email: 'boss2@x.com',
      );
      await openManageUsers(tester, db);

      expect(find.text('Second Boss'), findsOneWidget);
      expect(roleMenuFor('Boss'), findsNothing);
      expect(roleMenuFor('Second Boss'), findsNothing);
      // Regular people do have the menu.
      expect(roleMenuFor('Alice'), findsOneWidget);
    });

    testWidgets('the Admins only filter shows admins and super admins', (
      tester,
    ) async {
      await openManageUsers(tester, await world());

      await tester.tap(find.widgetWithText(FilterChip, 'Admins only'));
      await tester.pumpAndSettle();

      expect(find.text('Adam'), findsOneWidget);
      expect(find.text('Boss (you)'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
      expect(find.text('Bob'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Admins only'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('demoting inside Admins only removes the row', (tester) async {
      final db = await world();
      await openManageUsers(tester, db);
      await tester.tap(find.widgetWithText(FilterChip, 'Admins only'));
      await tester.pumpAndSettle();

      await tester.tap(roleMenuFor('Adam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make regular user'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove admin'));
      await tester.pumpAndSettle();

      expect(find.text('Adam'), findsNothing);
      expect(await roleOf(db, 'adm'), UserRole.user);
    });

    testWidgets('long lists load in pages with a Load more button', (
      tester,
    ) async {
      final db = await world();
      for (var i = 10; i < 40; i++) {
        await seedProfile(
          db,
          uid: 'z$i',
          name: 'Zed $i',
          role: UserRole.user,
          email: 'z$i@x.com',
        );
      }
      await openManageUsers(tester, db);

      // 5 seeded + 30 extra = 35 users; the first page holds 20.
      await tester.scrollUntilVisible(
        find.text('Load more'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Zed 39'), findsNothing);

      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Zed 39'),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Zed 39'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    });
  });
}
