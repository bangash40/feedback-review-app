import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
  await seedProfile(db, uid: 'adm', name: 'Adam', role: UserRole.admin);
  await seedProfile(db, uid: 'boss', name: 'Boss', role: UserRole.superAdmin);
  return db;
}

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Profile'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the name, email and role', (tester) async {
    final db = await world();
    await tester.pumpWidget(buildApp(signedInAs('u1'), db));
    await tester.pumpAndSettle();

    await openProfile(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Display name'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('u1@example.com'), findsOneWidget);
    expect(find.text('User'), findsOneWidget);
  });

  testWidgets('shows Admin and Super admin roles correctly', (tester) async {
    final db = await world();

    await tester.pumpWidget(buildApp(signedInAs('adm'), db));
    await tester.pumpAndSettle();
    await openProfile(tester);
    expect(find.text('Admin'), findsOneWidget);

    await tester.pumpWidget(buildApp(signedInAs('boss'), db));
    await tester.pumpAndSettle();
    await openProfile(tester);
    expect(find.text('Super admin'), findsOneWidget);
  });

  testWidgets('Save changes is disabled until the name is edited', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp(signedInAs('u1'), await world()));
    await tester.pumpAndSettle();
    await openProfile(tester);

    Finder save() => find.widgetWithText(FilledButton, 'Save changes');
    expect(tester.widget<FilledButton>(save()).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Samantha',
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(save()).onPressed, isNotNull);
  });

  testWidgets('saving updates the name and confirms it', (tester) async {
    final db = await world();
    await tester.pumpWidget(buildApp(signedInAs('u1'), db));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Samantha',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Profile updated'), findsOneWidget);
    final saved = await db.collection('users').doc('u1').get();
    expect(saved.data()!['name'], 'Samantha');

    // Elsewhere in the app, the new name is now used too.
    expect(find.text('Welcome, Samantha'), findsNothing); // still on Profile
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Samantha'), findsOneWidget);
  });

  testWidgets('an empty name is rejected and nothing is saved', (tester) async {
    final db = await world();
    await tester.pumpWidget(buildApp(signedInAs('u1'), db));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      '   ',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name'), findsOneWidget);
    final saved = await db.collection('users').doc('u1').get();
    expect(saved.data()!['name'], 'Sam');
  });

  testWidgets('a name over the limit is rejected', (tester) async {
    await tester.pumpWidget(buildApp(signedInAs('u1'), await world()));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'x' * 101,
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Name must be 100 characters or fewer'), findsOneWidget);
  });

  testWidgets('reachable from the admin dashboard too', (tester) async {
    await tester.pumpWidget(buildApp(signedInAs('adm'), await world()));
    await tester.pumpAndSettle();

    await openProfile(tester);

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Adam'), findsOneWidget);
  });

  testWidgets('a regular user cannot open another user\'s profile route', (
    tester,
  ) async {
    // The profile route always shows the signed-in user's own profile;
    // there is no id in the URL to point at someone else.
    await tester.pumpWidget(buildApp(signedInAs('u1'), await world()));
    await tester.pumpAndSettle();

    goTo(tester, '/profile');
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Adam'), findsNothing);
  });
}
