import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

Future<FakeFirebaseFirestore> userWithItems() async {
  final db = FakeFirebaseFirestore();
  await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
  await seedItem(
    db,
    id: 'i1',
    title: 'Flutter Basics',
    type: ItemType.course,
    description: 'An introduction to Flutter',
    ratingCount: 2,
    ratingSum: 9,
    minutesAgo: 1,
  );
  await seedItem(
    db,
    id: 'i2',
    title: 'Onboarding Task',
    type: ItemType.task,
    minutesAgo: 2,
  );
  await seedItem(
    db,
    id: 'i3',
    title: 'Hidden Service',
    type: ItemType.service,
    isActive: false,
    minutesAgo: 3,
  );
  return db;
}

Future<FakeFirebaseFirestore> adminWithItems() async {
  final db = await userWithItems();
  await seedProfile(db, uid: 'a1', name: 'Boss', role: UserRole.admin);
  return db;
}

void main() {
  group('user browsing', () {
    testWidgets('shows active items only, with ratings', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Onboarding Task'), findsOneWidget);
      expect(find.text('Hidden Service'), findsNothing);
      // 9 / 2 = 4.5 average from 2 ratings; the other item has none.
      expect(find.text('4.5 (2 ratings)'), findsOneWidget);
      expect(find.text('No ratings yet'), findsOneWidget);
    });

    testWidgets('type chips filter the list', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Course'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Onboarding Task'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Task'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Basics'), findsNothing);
      expect(find.text('Onboarding Task'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Onboarding Task'), findsOneWidget);
    });

    testWidgets('a type with no items shows an empty state', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      // The only service is inactive, so users see none.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Service'));
      await tester.pumpAndSettle();

      expect(find.text('No services to review'), findsOneWidget);
    });

    testWidgets('no items at all shows an empty state', (tester) async {
      final db = FakeFirebaseFirestore();
      await seedProfile(db, uid: 'u1', name: 'Sam', role: UserRole.user);
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to review yet'), findsOneWidget);
    });

    testWidgets('a new item appears live without a refresh', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      expect(find.text('Brand New'), findsNothing);

      await seedItem(db, id: 'i9', title: 'Brand New', minutesAgo: 0);
      await tester.pumpAndSettle();

      expect(find.text('Brand New'), findsOneWidget);
    });

    testWidgets('tapping an item opens its details', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Flutter Basics'));
      await tester.pumpAndSettle();

      expect(find.text('Item details'), findsOneWidget);
      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('An introduction to Flutter'), findsOneWidget);
      expect(find.text('4.5 (2 ratings)'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Sam'), findsOneWidget);
    });

    testWidgets('an unknown item id shows not found', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      goTo(tester, '/item/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.text('Item not found'), findsOneWidget);
    });
  });

  group('admin management', () {
    Future<void> openManage(
      WidgetTester tester,
      FakeFirebaseFirestore db,
    ) async {
      await tester.pumpWidget(buildApp(signedInAs('a1'), db));
      await tester.pumpAndSettle();
      expect(find.text('Admin dashboard'), findsOneWidget);
      await tester.tap(find.text('Manage items'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every item including inactive ones', (tester) async {
      final db = await adminWithItems();
      await openManage(tester, db);

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('Onboarding Task'), findsOneWidget);
      expect(find.text('Hidden Service'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('creates an item that users then see', (tester) async {
      final db = await adminWithItems();
      await openManage(tester, db);

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      expect(find.text('New item'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Design Review',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Weekly design critique',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<ItemType>),
          matching: find.text('Service'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create item'));
      await tester.pumpAndSettle();

      // Back on the list with the new item.
      expect(find.text('Manage items'), findsOneWidget);
      expect(find.text('Design Review'), findsOneWidget);

      final created = await db
          .collection('items')
          .where('title', isEqualTo: 'Design Review')
          .get();
      final data = created.docs.single.data();
      expect(data['type'], 'service');
      expect(data['createdBy'], 'a1');
      expect(data['isActive'], true);
      expect(data['ratingCount'], 0);

      // A user opening the app now sees it in the browse list.
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      expect(find.text('Design Review'), findsOneWidget);
    });

    testWidgets('the create form rejects an empty title', (tester) async {
      final db = await adminWithItems();
      await openManage(tester, db);

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create item'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a title'), findsOneWidget);
      expect(find.text('New item'), findsOneWidget);
    });

    testWidgets('edits an item and keeps its ratings', (tester) async {
      final db = await adminWithItems();
      await openManage(tester, db);

      await tester.tap(find.text('Flutter Basics'));
      await tester.pumpAndSettle();
      expect(find.text('Edit item'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Flutter Advanced',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Advanced'), findsOneWidget);
      final data = (await db.collection('items').doc('i1').get()).data()!;
      expect(data['title'], 'Flutter Advanced');
      expect(data['ratingCount'], 2);
      expect(data['ratingSum'], 9);
    });

    testWidgets('deactivating then reactivating controls user visibility', (
      tester,
    ) async {
      final db = await adminWithItems();
      await openManage(tester, db);

      Finder switchFor(String title) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Card)),
        matching: find.byType(Switch),
      );

      // Deactivate "Onboarding Task" from the admin list.
      await tester.tap(switchFor('Onboarding Task'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('items').doc('i2').get()).data()!['isActive'],
        false,
      );

      // A user no longer sees it.
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      expect(find.text('Onboarding Task'), findsNothing);
      expect(find.text('Flutter Basics'), findsOneWidget);

      // Reactivate "Hidden Service" from the admin list.
      await tester.pumpWidget(buildApp(signedInAs('a1'), db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage items'));
      await tester.pumpAndSettle();
      await tester.tap(switchFor('Hidden Service'));
      await tester.pumpAndSettle();

      // Now users see it.
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();
      expect(find.text('Hidden Service'), findsOneWidget);
    });

    testWidgets('regular users cannot open the admin screens', (tester) async {
      final db = await userWithItems();
      await tester.pumpWidget(buildApp(signedInAs('u1'), db));
      await tester.pumpAndSettle();

      goTo(tester, '/admin/items');
      await tester.pumpAndSettle();

      expect(find.text('Manage items'), findsNothing);
      expect(find.text('Welcome, Sam'), findsOneWidget);
    });
  });
}
