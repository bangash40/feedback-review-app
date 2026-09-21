import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// Screens overflow when a user raises the system font size. A layout overflow
/// is thrown as an exception in tests, so simply visiting each screen at a
/// large font on a narrow phone is enough to catch one.
Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  await seedProfile(db, uid: 'adm', name: 'Adam', role: UserRole.admin);
  await seedProfile(
    db,
    uid: 'boss',
    name: 'Boss',
    role: UserRole.superAdmin,
    email: 'boss@x.com',
  );
  await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
  await seedItem(
    db,
    id: 'i1',
    title: 'Flutter Basics',
    type: ItemType.course,
    description: 'An introduction to Flutter development for beginners',
  );
  await seedItem(
    db,
    id: 'i2',
    title: 'Onboarding Task',
    type: ItemType.task,
    isActive: false,
  );
  await seedFeedback(
    db,
    itemId: 'i1',
    uid: 'u1',
    rating: 4,
    review: 'Great course, would recommend',
    suggestion: 'More labs',
  );
  return db;
}

void main() {
  // (screen name, who is signed in, route)
  final screens = [
    ('home', 'u1', '/home'),
    ('item detail', 'u1', '/item/i1'),
    ('edit feedback', 'u1', '/item/i1/feedback'),
    ('my feedback', 'u1', '/my-feedback'),
    ('admin dashboard', 'boss', '/admin'),
    ('admin feedback detail', 'boss', '/admin/feedback/i1_u1'),
    ('manage items', 'adm', '/admin/items'),
    ('edit item', 'adm', '/admin/items/i1'),
    ('new item', 'adm', '/admin/items/new'),
    ('manage users', 'boss', '/admin/users'),
  ];

  for (final scale in [1.3, 2.0]) {
    for (final (name, uid, route) in screens) {
      testWidgets('$name fits at ${scale}x font', (tester) async {
        useTextScale(tester, scale);
        usePhoneScreen(tester, height: 900);
        await tester.pumpWidget(buildApp(signedInAs(uid), await world()));
        await tester.pumpAndSettle();

        goTo(tester, route);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('the login and register screens fit at ${scale}x font', (
      tester,
    ) async {
      useTextScale(tester, scale);
      usePhoneScreen(tester, height: 900);
      await tester.pumpWidget(
        buildApp(MockFirebaseAuth(), FakeFirebaseFirestore()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sign up').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
