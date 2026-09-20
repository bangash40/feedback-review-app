import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:feedback_review_app/repositories/item_repository.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ItemRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = ItemRepository(
      firestoreService: FirestoreService(firestore: db),
    );
  });

  test('createItem stores the item with zeroed aggregates', () async {
    final id = await repository.createItem(
      title: '  Flutter Basics  ',
      description: ' Intro ',
      type: ItemType.course,
      createdBy: 'admin1',
    );

    final data = (await db.collection('items').doc(id).get()).data()!;
    expect(data['id'], id);
    expect(data['title'], 'Flutter Basics');
    expect(data['description'], 'Intro');
    expect(data['type'], 'course');
    expect(data['isActive'], true);
    expect(data['createdBy'], 'admin1');
    expect(data['ratingCount'], 0);
    expect(data['ratingSum'], 0);
    expect(data['averageRating'], 0);
  });

  test(
    'watchActiveItems hides inactive items and sorts newest first',
    () async {
      await seedItem(db, id: 'old', title: 'Old', minutesAgo: 30);
      await seedItem(db, id: 'new', title: 'New', minutesAgo: 1);
      await seedItem(db, id: 'off', title: 'Off', isActive: false);

      final items = await repository.watchActiveItems().first;

      expect(items.map((i) => i.id), ['new', 'old']);
    },
  );

  test('watchActiveItems filters by type', () async {
    await seedItem(db, id: 't', title: 'Task', type: ItemType.task);
    await seedItem(db, id: 'c', title: 'Course', type: ItemType.course);
    await seedItem(
      db,
      id: 'c2',
      title: 'Off course',
      type: ItemType.course,
      isActive: false,
    );

    final courses = await repository
        .watchActiveItems(type: ItemType.course)
        .first;

    expect(courses.map((i) => i.id), ['c']);
  });

  test('watchAllItems includes inactive items', () async {
    await seedItem(db, id: 'a', title: 'A');
    await seedItem(db, id: 'b', title: 'B', isActive: false);

    final items = await repository.watchAllItems().first;

    expect(items.map((i) => i.id).toSet(), {'a', 'b'});
  });

  test('watchItem emits the item, or null when missing', () async {
    await seedItem(db, id: 'a', title: 'A');

    expect((await repository.watchItem('a').first)?.title, 'A');
    expect(await repository.watchItem('missing').first, isNull);
  });

  test('updateItem changes editable fields but never the aggregates', () async {
    await seedItem(db, id: 'a', title: 'Before', ratingCount: 5, ratingSum: 20);
    // Simulates an edit form that loaded the item before more ratings arrived.
    final stale = (await repository.watchItem('a').first)!.copyWith(
      title: 'After',
      type: ItemType.service,
      isActive: false,
      ratingCount: 0,
      ratingSum: 0,
      averageRating: 0,
    );

    await repository.updateItem(stale);

    final data = (await db.collection('items').doc('a').get()).data()!;
    expect(data['title'], 'After');
    expect(data['type'], 'service');
    expect(data['isActive'], false);
    expect(data['ratingCount'], 5);
    expect(data['ratingSum'], 20);
    expect(data['averageRating'], 4);
  });

  test('setActive toggles visibility', () async {
    await seedItem(db, id: 'a', title: 'A');

    await repository.setActive('a', isActive: false);
    expect(await repository.watchActiveItems().first, isEmpty);

    await repository.setActive('a', isActive: true);
    expect(await repository.watchActiveItems().first, hasLength(1));
  });
}
