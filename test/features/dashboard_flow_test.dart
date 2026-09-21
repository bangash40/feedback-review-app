import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/features/admin/widgets/stats_overview.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// An admin (Adam), three items and four reviews from different users.
///
///   Alice  5★  Flutter Basics   "Excellent course" + suggestion  (newest)
///   Bob    3★  Flutter Basics   "Okay"
///   Carol  2★  Onboarding Task  "Confusing steps"
///   Dave   4★  Support Desk     (no text)                        (oldest)
///
/// Overall: 4 reviews, average 3.5.
Future<FakeFirebaseFirestore> world({bool withFeedback = true}) async {
  final db = FakeFirebaseFirestore();
  await seedProfile(db, uid: 'adm', name: 'Adam', role: UserRole.admin);
  await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);

  await seedItem(
    db,
    id: 'i1',
    title: 'Flutter Basics',
    type: ItemType.course,
    description: 'An introduction to Flutter',
    ratingCount: withFeedback ? 2 : 0,
    ratingSum: withFeedback ? 8 : 0,
    minutesAgo: 1,
  );
  await seedItem(
    db,
    id: 'i2',
    title: 'Onboarding Task',
    type: ItemType.task,
    ratingCount: withFeedback ? 1 : 0,
    ratingSum: withFeedback ? 2 : 0,
    minutesAgo: 2,
  );
  await seedItem(
    db,
    id: 'i3',
    title: 'Support Desk',
    type: ItemType.service,
    ratingCount: withFeedback ? 1 : 0,
    ratingSum: withFeedback ? 4 : 0,
    minutesAgo: 3,
  );

  if (withFeedback) {
    Future<void> review(
      String id,
      String item,
      String title,
      ItemType type,
      String name,
      int rating,
      int day, {
      String text = '',
      String suggestion = '',
    }) => seedFeedbackDoc(
      db,
      id: id,
      itemId: item,
      itemTitle: title,
      itemType: type,
      userId: 'user-$id',
      userName: name,
      rating: rating,
      review: text,
      suggestion: suggestion,
      createdAt: DateTime(2026, 1, day),
    );

    await review(
      'f1',
      'i1',
      'Flutter Basics',
      ItemType.course,
      'Alice',
      5,
      4,
      text: 'Excellent course',
      suggestion: 'Add labs',
    );
    await review(
      'f2',
      'i1',
      'Flutter Basics',
      ItemType.course,
      'Bob',
      3,
      3,
      text: 'Okay',
    );
    await review(
      'f3',
      'i2',
      'Onboarding Task',
      ItemType.task,
      'Carol',
      2,
      2,
      text: 'Confusing steps',
    );
    await review('f4', 'i3', 'Support Desk', ItemType.service, 'Dave', 4, 1);
  }
  return db;
}

/// Opens the dashboard as the admin, on a screen tall enough to lay out
/// every row.
Future<void> openDashboard(
  WidgetTester tester,
  FakeFirebaseFirestore db,
) async {
  useTallScreen(tester);
  await tester.pumpWidget(buildApp(signedInAs('adm'), db));
  await tester.pumpAndSettle();
}

/// The reviewers currently on screen, top to bottom.
List<String> shownOrder(WidgetTester tester) {
  final names = [
    'Alice',
    'Bob',
    'Carol',
    'Dave',
    'Eve',
  ].where((name) => find.text(name).evaluate().isNotEmpty).toList();
  names.sort(
    (a, b) => tester
        .getTopLeft(find.text(a))
        .dy
        .compareTo(tester.getTopLeft(find.text(b)).dy),
  );
  return names;
}

Finder inStats(String text) =>
    find.descendant(of: find.byType(StatsOverview), matching: find.text(text));

Finder inChart(String text) =>
    find.descendant(of: find.byType(BarChart), matching: find.text(text));

Future<void> chooseRating(WidgetTester tester, int stars) async {
  await tester.tap(find.widgetWithText(ChoiceChip, '$stars★'));
  await tester.pumpAndSettle();
}

Future<void> chooseType(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pumpAndSettle();
}

void main() {
  group('overview', () {
    testWidgets('shows the total and the average', (tester) async {
      await openDashboard(tester, await world());

      expect(find.text('Admin dashboard'), findsOneWidget);
      expect(find.text('Welcome, Adam (admin)'), findsOneWidget);
      expect(inStats('4'), findsOneWidget);
      expect(inStats('3.5'), findsOneWidget);
      expect(find.text('Total feedback'), findsOneWidget);
      expect(find.text('Average rating'), findsOneWidget);
    });

    testWidgets('the chart shows how many ratings each star has', (
      tester,
    ) async {
      await openDashboard(tester, await world());

      expect(find.text('Rating distribution'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      for (final label in ['1★', '2★', '3★', '4★', '5★']) {
        expect(inChart(label), findsOneWidget);
      }
      // One rating each for 2, 3, 4 and 5 stars; none for 1 star.
      expect(inChart('1'), findsNWidgets(4));
      expect(inChart('0'), findsOneWidget);
    });

    testWidgets('with no feedback it says so instead of showing a chart', (
      tester,
    ) async {
      await openDashboard(tester, await world(withFeedback: false));

      expect(find.text('No feedback yet'), findsOneWidget);
      expect(inStats('0'), findsOneWidget);
      expect(inStats('–'), findsOneWidget);
      expect(find.text('No ratings yet'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('new feedback appears live and updates the numbers', (
      tester,
    ) async {
      final db = await world();
      await openDashboard(tester, db);
      expect(find.text('Eve'), findsNothing);

      await seedFeedback(
        db,
        itemId: 'i3',
        uid: 'eve',
        name: 'Eve',
        rating: 5,
        review: 'Just arrived',
      );
      await tester.pumpAndSettle();

      expect(find.text('Eve'), findsOneWidget);
      expect(find.text('Just arrived'), findsOneWidget);
      expect(inStats('5'), findsWidgets); // total is now 5
      expect(find.text('Showing 5 of 5'), findsOneWidget);
    });
  });

  group('feedback list', () {
    testWidgets('lists every review, newest first', (tester) async {
      await openDashboard(tester, await world());

      expect(shownOrder(tester), ['Alice', 'Bob', 'Carol', 'Dave']);
      expect(find.text('Showing 4 of 4'), findsOneWidget);
      expect(find.text('Excellent course'), findsOneWidget);
      expect(find.text('Flutter Basics'), findsWidgets);
    });

    testWidgets('marks reviews that include a suggestion', (tester) async {
      await openDashboard(tester, await world());

      expect(find.text('Includes a suggestion'), findsOneWidget);
    });

    testWidgets('tapping a review opens its full text', (tester) async {
      await openDashboard(tester, await world());

      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      expect(find.text('Feedback details'), findsOneWidget);
      expect(find.text('Excellent course'), findsOneWidget);
      expect(find.text('Add labs'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('5 out of 5'), findsOneWidget);
      expect(find.text('Flutter Basics'), findsOneWidget);
    });

    testWidgets('a review without text says so', (tester) async {
      await openDashboard(tester, await world());

      await tester.tap(find.text('Dave'));
      await tester.pumpAndSettle();

      expect(find.text('No review written.'), findsOneWidget);
      expect(find.text('No suggestion given.'), findsOneWidget);
    });

    testWidgets('the detail page links to the item', (tester) async {
      await openDashboard(tester, await world());
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View item'));
      await tester.pumpAndSettle();

      expect(find.text('Item details'), findsOneWidget);
      expect(find.text('An introduction to Flutter'), findsOneWidget);
    });

    testWidgets('an unknown feedback id shows not found', (tester) async {
      await openDashboard(tester, await world());

      goTo(tester, '/admin/feedback/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('Feedback not found'), findsOneWidget);
    });
  });

  group('filters', () {
    testWidgets('by rating', (tester) async {
      await openDashboard(tester, await world());

      await chooseRating(tester, 5);

      expect(shownOrder(tester), ['Alice']);
      expect(find.text('Showing 1 of 4'), findsOneWidget);
      // The overview keeps describing everything, so the chart keeps its shape.
      expect(inStats('4'), findsOneWidget);
      expect(inStats('3.5'), findsOneWidget);
    });

    testWidgets('by type, which also re-summarizes the overview', (
      tester,
    ) async {
      await openDashboard(tester, await world());

      await chooseType(tester, 'Course');

      expect(shownOrder(tester), ['Alice', 'Bob']);
      expect(find.text('Showing 2 of 4'), findsOneWidget);
      expect(inStats('2'), findsOneWidget);
      expect(inStats('4.0'), findsOneWidget); // (5 + 3) / 2
    });

    testWidgets('by item shows that item\'s count and average', (tester) async {
      await openDashboard(tester, await world());

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Onboarding Task').last);
      await tester.pumpAndSettle();

      expect(shownOrder(tester), ['Carol']);
      expect(inStats('1'), findsOneWidget);
      expect(inStats('2.0'), findsOneWidget);
    });

    testWidgets('the item list narrows to the chosen type', (tester) async {
      await openDashboard(tester, await world());
      await chooseType(tester, 'Service');

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();

      // Only the service item is offered (plus the "All items" entry).
      expect(find.text('Support Desk'), findsWidgets);
      expect(find.text('Onboarding Task'), findsNothing);
      expect(find.text('Flutter Basics'), findsNothing);
    });

    testWidgets('filters combine, and clearing brings everything back', (
      tester,
    ) async {
      await openDashboard(tester, await world());
      expect(find.text('Clear filters'), findsNothing);

      await chooseType(tester, 'Course');
      await chooseRating(tester, 2);
      expect(find.text('No feedback matches these filters'), findsOneWidget);
      expect(shownOrder(tester), isEmpty);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(shownOrder(tester), ['Alice', 'Bob', 'Carol', 'Dave']);
      expect(find.text('Clear filters'), findsNothing);
    });
  });

  group('sorting', () {
    Future<void> sortBy(
      WidgetTester tester,
      String current,
      String label,
    ) async {
      await tester.tap(find.byTooltip('Sort: $current'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('oldest first', (tester) async {
      await openDashboard(tester, await world());

      await sortBy(tester, 'Newest first', 'Oldest first');

      expect(shownOrder(tester), ['Dave', 'Carol', 'Bob', 'Alice']);
    });

    testWidgets('highest rating first', (tester) async {
      await openDashboard(tester, await world());

      await sortBy(tester, 'Newest first', 'Highest rating');

      expect(shownOrder(tester), ['Alice', 'Dave', 'Bob', 'Carol']);
    });

    testWidgets('lowest rating first', (tester) async {
      await openDashboard(tester, await world());

      await sortBy(tester, 'Newest first', 'Lowest rating');

      expect(shownOrder(tester), ['Carol', 'Bob', 'Dave', 'Alice']);
    });

    testWidgets('the sort survives clearing filters', (tester) async {
      await openDashboard(tester, await world());
      await sortBy(tester, 'Newest first', 'Lowest rating');
      await chooseRating(tester, 5);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      expect(shownOrder(tester), ['Carol', 'Bob', 'Dave', 'Alice']);
    });
  });

  group('items tab', () {
    Future<void> openItemsTab(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(Tab, 'Items'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows each item\'s average and response count', (
      tester,
    ) async {
      await openDashboard(tester, await world());

      await openItemsTab(tester);

      expect(find.text('4.0 (2 ratings)'), findsOneWidget); // Flutter Basics
      expect(find.text('2.0 (1 rating)'), findsOneWidget); // Onboarding Task
      expect(find.text('4.0 (1 rating)'), findsOneWidget); // Support Desk
    });

    testWidgets('most-reviewed items come first', (tester) async {
      await openDashboard(tester, await world());
      await openItemsTab(tester);

      double top(String title) => tester.getTopLeft(find.text(title)).dy;

      expect(top('Flutter Basics'), lessThan(top('Onboarding Task')));
      expect(top('Onboarding Task'), lessThan(top('Support Desk')));
    });

    testWidgets('choosing an item jumps to its feedback', (tester) async {
      await openDashboard(tester, await world());
      await openItemsTab(tester);

      await tester.tap(find.text('Onboarding Task'));
      await tester.pumpAndSettle();

      expect(find.text('Showing 1 of 4'), findsOneWidget);
      expect(shownOrder(tester), ['Carol']);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    testWidgets('marks inactive items', (tester) async {
      final db = await world();
      await db.collection('items').doc('i3').update({'isActive': false});
      await openDashboard(tester, db);

      await openItemsTab(tester);

      expect(find.text('Inactive'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('the app bar opens item management', (tester) async {
      await openDashboard(tester, await world());

      await tester.tap(find.byTooltip('Manage items'));
      await tester.pumpAndSettle();

      expect(find.text('Manage items'), findsOneWidget);
      expect(find.text('Add item'), findsOneWidget);
    });

    testWidgets('an admin can log out from the dashboard', (tester) async {
      await openDashboard(tester, await world());

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('a regular user cannot open the feedback detail', (
      tester,
    ) async {
      final db = await world();
      useTallScreen(tester);
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      goTo(tester, '/admin/feedback/f1');
      await tester.pumpAndSettle();

      expect(find.text('Feedback details'), findsNothing);
      expect(find.text('Welcome, Sam'), findsOneWidget);
    });

    testWidgets('a regular user never sees the dashboard', (tester) async {
      final db = await world();
      useTallScreen(tester);
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      goTo(tester, '/admin');
      await tester.pumpAndSettle();

      expect(find.text('Admin dashboard'), findsNothing);
      expect(find.text('Excellent course'), findsNothing);
    });
  });

  // Layout overflows throw in tests, so simply rendering these screens at a
  // narrow phone width proves nothing is clipped or overflowing.
  group('on a narrow phone', () {
    Future<void> openOnPhone(
      WidgetTester tester,
      FakeFirebaseFirestore db,
    ) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(buildApp(signedInAs('adm'), db));
      await tester.pumpAndSettle();
    }

    testWidgets('the feedback tab fits', (tester) async {
      await openOnPhone(tester, await world());

      expect(tester.takeException(), isNull);
      expect(find.text('Rating distribution'), findsOneWidget);
      expect(shownOrder(tester), ['Alice', 'Bob', 'Carol', 'Dave']);
    });

    testWidgets('long names and long review text still fit', (tester) async {
      final db = await world();
      await seedFeedbackDoc(
        db,
        id: 'long',
        itemId: 'i1',
        itemTitle: 'A really quite long item title that keeps going and going',
        userName: 'Bartholomew Maximilian Featherstonehaugh-Cholmondeley',
        rating: 4,
        review: 'word ' * 120,
        suggestion: 'idea ' * 60,
        createdAt: DateTime(2026, 2, 1),
      );
      await openOnPhone(tester, db);

      expect(tester.takeException(), isNull);
      await tester.tap(find.textContaining('Bartholomew'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Feedback details'), findsOneWidget);
    });

    testWidgets('the item picker and sort menu open without overflow', (
      tester,
    ) async {
      await openOnPhone(tester, await world());

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('All items').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort: Newest first'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Highest rating'), findsOneWidget);
    });

    testWidgets('the items tab and the empty dashboard fit', (tester) async {
      await openOnPhone(tester, await world());
      await tester.tap(find.widgetWithText(Tab, 'Items'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty dashboard fits', (tester) async {
      await openOnPhone(tester, await world(withFeedback: false));

      expect(tester.takeException(), isNull);
      expect(find.text('No feedback yet'), findsOneWidget);
    });

    testWidgets('a super admin still fits with the extra app bar button', (
      tester,
    ) async {
      final db = await world();
      await seedProfile(
        db,
        uid: 'boss',
        name: 'Boss',
        role: UserRole.superAdmin,
      );
      usePhoneScreen(tester);
      await tester.pumpWidget(buildApp(signedInAs('boss'), db));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Manage users'), findsOneWidget);
      expect(find.byTooltip('Manage items'), findsOneWidget);
      expect(find.byTooltip('Log out'), findsOneWidget);
    });
  });

  // Phones let people enlarge the system font. The layout must keep fitting.
  group('with a larger system font', () {
    for (final scale in [1.3, 1.6, 2.0]) {
      testWidgets('the feedback tab fits at ${scale}x', (tester) async {
        useTextScale(tester, scale);
        usePhoneScreen(tester, height: 6000);
        await tester.pumpWidget(buildApp(signedInAs('adm'), await world()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Rating distribution'), findsOneWidget);
      });
    }

    testWidgets('the chart labels fit at the largest size', (tester) async {
      useTextScale(tester, 2.0);
      usePhoneScreen(tester, height: 6000);
      await tester.pumpWidget(buildApp(signedInAs('adm'), await world()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final label in ['1★', '2★', '3★', '4★', '5★']) {
        expect(inChart(label), findsOneWidget);
      }
    });

    testWidgets('the items tab and detail screen fit at the largest size', (
      tester,
    ) async {
      useTextScale(tester, 2.0);
      usePhoneScreen(tester, height: 6000);
      await tester.pumpWidget(buildApp(signedInAs('adm'), await world()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Items'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.widgetWithText(Tab, 'Feedback'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Feedback details'), findsOneWidget);
    });
  });
}
