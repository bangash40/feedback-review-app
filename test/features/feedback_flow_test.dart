import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// User Sam (u1) and another user, plus two items.
Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
  await seedProfile(db, uid: 'u2', name: 'Pat', role: UserRole.user);
  await seedItem(
    db,
    id: 'i1',
    title: 'Flutter Basics',
    type: ItemType.course,
    description: 'An introduction to Flutter',
    minutesAgo: 1,
  );
  await seedItem(db, id: 'i2', title: 'Onboarding Task', minutesAgo: 2);
  return db;
}

Future<Map<String, dynamic>> itemData(
  FakeFirebaseFirestore db,
  String id,
) async => (await db.collection('items').doc(id).get()).data()!;

Future<int> feedbackCount(FakeFirebaseFirestore db) async =>
    (await db.collection('feedback').get()).size;

/// Starts the app as Sam and opens "Flutter Basics".
Future<void> openFlutterBasics(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  await tester.pumpWidget(buildApp(signedInAs('u1'), db));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Flutter Basics'));
  await tester.pumpAndSettle();
}

Future<void> openMyFeedback(WidgetTester tester) async {
  await tester.tap(find.byTooltip('My feedback'));
  await tester.pumpAndSettle();
}

/// Deletes "Flutter Basics" feedback from the My feedback list, confirming.
Future<void> deleteFlutterBasicsReview(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions for Flutter Basics'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
  await tester.pumpAndSettle();
}

void main() {
  group('giving feedback', () {
    testWidgets('the detail page offers to give feedback', (tester) async {
      await openFlutterBasics(tester, await world());

      expect(find.text('Give feedback'), findsOneWidget);
      expect(find.text('Your feedback'), findsNothing);
    });

    testWidgets('a rating is required', (tester) async {
      final db = await world();
      await openFlutterBasics(tester, db);
      await tester.tap(find.text('Give feedback'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a rating'), findsOneWidget);
      expect(find.text('Submit feedback'), findsOneWidget); // still on the form
      expect(await feedbackCount(db), 0);
    });

    testWidgets('choosing stars updates the label and clears the error', (
      tester,
    ) async {
      await openFlutterBasics(tester, await world());
      await tester.tap(find.text('Give feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Tap a star to rate'), findsOneWidget);

      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Please select a rating'), findsOneWidget);

      await tester.tap(find.byTooltip('5 stars'));
      await tester.pumpAndSettle();
      expect(find.text('Excellent'), findsOneWidget);
      expect(find.text('Please select a rating'), findsNothing);

      await tester.tap(find.byTooltip('1 star'));
      await tester.pumpAndSettle();
      expect(find.text('Poor'), findsOneWidget);
    });

    testWidgets('submitting saves the review and updates the average', (
      tester,
    ) async {
      final db = await world();
      await openFlutterBasics(tester, db);
      await tester.tap(find.text('Give feedback'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('4 stars'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Review (optional)'),
        'Clear and practical',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Suggestion (optional)'),
        'More exercises please',
      );
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      // Back on the detail page, showing the review and the new average.
      expect(find.text('Thanks for your feedback!'), findsOneWidget);
      expect(find.text('Your feedback'), findsOneWidget);
      expect(find.text('Clear and practical'), findsOneWidget);
      expect(find.text('More exercises please'), findsOneWidget);
      expect(find.text('4.0 (1 rating)'), findsOneWidget);
      expect(find.text('Edit your feedback'), findsOneWidget);
      expect(find.text('Give feedback'), findsNothing);

      final saved = (await db.collection('feedback').doc('i1_u1').get())
          .data()!;
      expect(saved['userId'], 'u1');
      expect(saved['userName'], 'Sam');
      expect(saved['rating'], 4);
    });

    testWidgets('review and suggestion are optional', (tester) async {
      final db = await world();
      await openFlutterBasics(tester, db);
      await tester.tap(find.text('Give feedback'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('3 stars'));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      expect(find.text('3.0 (1 rating)'), findsOneWidget);
    });

    testWidgets("my rating averages with other users' ratings", (tester) async {
      final db = await world();
      await seedFeedback(db, itemId: 'i1', uid: 'u2', name: 'Pat', rating: 5);
      await openFlutterBasics(tester, db);
      expect(find.text('5.0 (1 rating)'), findsOneWidget);

      await tester.tap(find.text('Give feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('3 stars'));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      expect(find.text('4.0 (2 ratings)'), findsOneWidget);
    });

    testWidgets('an inactive item takes no new feedback', (tester) async {
      final db = await world();
      await db.collection('items').doc('i1').update({'isActive': false});
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      goTo(tester, '/item/i1');
      await tester.pumpAndSettle();
      expect(
        find.text('This item is no longer accepting feedback.'),
        findsOneWidget,
      );
      expect(find.text('Give feedback'), findsNothing);

      goTo(tester, '/item/i1/feedback');
      await tester.pumpAndSettle();
      expect(find.text('Not accepting feedback'), findsOneWidget);
    });
  });

  group('editing feedback', () {
    testWidgets('the form opens with the existing review filled in', (
      tester,
    ) async {
      final db = await world();
      await seedFeedback(
        db,
        itemId: 'i1',
        uid: 'u1',
        rating: 5,
        review: 'Loved it',
        suggestion: 'Add quizzes',
      );
      await openFlutterBasics(tester, db);
      await tester.tap(find.text('Edit your feedback'));
      await tester.pumpAndSettle();

      expect(find.text('Edit feedback'), findsOneWidget);
      expect(find.text('Excellent'), findsOneWidget); // 5 stars preselected
      expect(find.text('Loved it'), findsOneWidget);
      expect(find.text('Add quizzes'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets('saving changes updates in place and re-averages', (
      tester,
    ) async {
      final db = await world();
      await seedFeedback(
        db,
        itemId: 'i1',
        uid: 'u1',
        rating: 5,
        review: 'Loved it',
      );
      await openFlutterBasics(tester, db);
      expect(find.text('5.0 (1 rating)'), findsOneWidget);

      await tester.tap(find.text('Edit your feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('2 stars'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Review (optional)'),
        'Changed my mind',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(find.text('Feedback updated'), findsOneWidget);
      expect(find.text('2.0 (1 rating)'), findsOneWidget);
      expect(find.text('Changed my mind'), findsOneWidget);
      expect(await feedbackCount(db), 1);
      expect((await itemData(db, 'i1'))['ratingCount'], 1);
    });
  });

  group('My feedback', () {
    testWidgets('starts empty', (tester) async {
      await tester.pumpWidget(buildApp(signedInAs('u1'), await world()));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);

      expect(find.text("You haven't left any feedback yet"), findsOneWidget);
    });

    testWidgets('lists only my own reviews', (tester) async {
      final db = await world();
      await seedFeedback(db, itemId: 'i1', uid: 'u1', review: 'Mine one');
      await seedFeedback(db, itemId: 'i2', uid: 'u1', review: 'Mine two');
      await seedFeedback(
        db,
        itemId: 'i1',
        uid: 'u2',
        name: 'Pat',
        review: 'Not mine',
      );
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);

      expect(find.text('Mine one'), findsOneWidget);
      expect(find.text('Mine two'), findsOneWidget);
      expect(find.text('Not mine'), findsNothing);
      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Onboarding Task'), findsOneWidget);
    });

    testWidgets('a new review appears live', (tester) async {
      final db = await world();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);
      expect(find.text('Late review'), findsNothing);

      await seedFeedback(db, itemId: 'i1', uid: 'u1', review: 'Late review');
      await tester.pumpAndSettle();

      expect(find.text('Late review'), findsOneWidget);
    });

    testWidgets('tapping a review opens it for editing', (tester) async {
      final db = await world();
      await seedFeedback(db, itemId: 'i1', uid: 'u1', review: 'Mine one');
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);

      await tester.tap(find.text('Mine one'));
      await tester.pumpAndSettle();

      expect(find.text('Edit feedback'), findsOneWidget);
    });

    testWidgets('deleting removes the review and its rating', (tester) async {
      final db = await world();
      await seedFeedback(
        db,
        itemId: 'i1',
        uid: 'u1',
        rating: 5,
        review: 'Mine one',
      );
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);

      await tester.tap(find.byTooltip('More actions for Flutter Basics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete feedback?'), findsOneWidget);
      // Nothing is removed until confirmed.
      expect(await feedbackCount(db), 1);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Feedback deleted'), findsOneWidget);
      expect(find.text("You haven't left any feedback yet"), findsOneWidget);
      expect(await feedbackCount(db), 0);
      final item = await itemData(db, 'i1');
      expect(item['ratingCount'], 0);
      expect(item['averageRating'], 0);
    });

    testWidgets('cancelling the delete keeps the review', (tester) async {
      final db = await world();
      await seedFeedback(db, itemId: 'i1', uid: 'u1', review: 'Mine one');
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);

      await tester.tap(find.byTooltip('More actions for Flutter Basics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Mine one'), findsOneWidget);
      expect(await feedbackCount(db), 1);
    });

    testWidgets('after deleting, the item can be reviewed again', (
      tester,
    ) async {
      final db = await world();
      await seedFeedback(db, itemId: 'i1', uid: 'u1', rating: 5);
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      await openMyFeedback(tester);
      await deleteFlutterBasicsReview(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Basics'));
      await tester.pumpAndSettle();

      expect(find.text('Give feedback'), findsOneWidget);
      expect(find.text('Your feedback'), findsNothing);
      expect(find.text('No ratings yet'), findsWidgets);
    });
  });
}
