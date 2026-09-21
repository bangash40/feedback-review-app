import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feedback_review_app/core/utils/app_exception.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:feedback_review_app/repositories/feedback_repository.dart';
import 'package:feedback_review_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FeedbackRepository repository;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repository = FeedbackRepository(
      firestoreService: FirestoreService(firestore: db),
    );
    await seedItem(
      db,
      id: 'i1',
      title: 'Flutter Basics',
      type: ItemType.course,
    );
  });

  Future<Map<String, dynamic>> itemData(String id) async =>
      (await db.collection('items').doc(id).get()).data()!;

  Future<Map<String, dynamic>?> feedbackData(String itemId, String uid) async =>
      (await db.collection('feedback').doc('${itemId}_$uid').get()).data();

  Future<void> submit(
    String uid,
    int rating, {
    String itemId = 'i1',
    String review = '',
    String suggestion = '',
  }) {
    return repository.submit(
      itemId: itemId,
      userId: uid,
      userName: 'User $uid',
      rating: rating,
      review: review,
      suggestion: suggestion,
    );
  }

  test('the document id is item and user joined', () {
    expect(FeedbackRepository.idFor('i1', 'u1'), 'i1_u1');
  });

  group('submit', () {
    test('creates the review with denormalized details', () async {
      await submit('u1', 4, review: '  Great  ', suggestion: ' More labs ');

      final data = (await feedbackData('i1', 'u1'))!;
      expect(data['id'], 'i1_u1');
      expect(data['itemId'], 'i1');
      expect(data['itemTitle'], 'Flutter Basics');
      expect(data['itemType'], 'course');
      expect(data['userId'], 'u1');
      expect(data['userName'], 'User u1');
      expect(data['rating'], 4);
      expect(data['review'], 'Great');
      expect(data['suggestion'], 'More labs');
      expect(data['createdAt'], isNotNull);
      expect(data['updatedAt'], isNotNull);
    });

    test('review and suggestion are optional', () async {
      await submit('u1', 3);

      final data = (await feedbackData('i1', 'u1'))!;
      expect(data['review'], '');
      expect(data['suggestion'], '');
    });

    test('the first review sets the item aggregates', () async {
      await submit('u1', 4);

      final item = await itemData('i1');
      expect(item['ratingCount'], 1);
      expect(item['ratingSum'], 4);
      expect(item['averageRating'], 4);
    });

    test('several users average together', () async {
      await submit('u1', 5);
      await submit('u2', 4);
      await submit('u3', 3);

      final item = await itemData('i1');
      expect(item['ratingCount'], 3);
      expect(item['ratingSum'], 12);
      expect(item['averageRating'], 4);
    });

    test('a non-whole average is kept exactly', () async {
      await submit('u1', 5);
      await submit('u2', 4);

      expect((await itemData('i1'))['averageRating'], 4.5);
    });

    test('submitting again edits in place with no duplicate', () async {
      await submit('u1', 5, review: 'first');
      final created = (await feedbackData('i1', 'u1'))!['createdAt'];

      await submit('u1', 2, review: 'changed my mind');

      final all = await db.collection('feedback').get();
      expect(all.docs, hasLength(1));
      final data = (await feedbackData('i1', 'u1'))!;
      expect(data['rating'], 2);
      expect(data['review'], 'changed my mind');
      expect(data['createdAt'], created);
    });

    test('editing moves the sum but never the count', () async {
      await submit('u1', 5);
      await submit('u2', 3);

      await submit('u1', 1);

      final item = await itemData('i1');
      expect(item['ratingCount'], 2);
      expect(item['ratingSum'], 4);
      expect(item['averageRating'], 2);
    });

    test('feedback on different items is independent', () async {
      await seedItem(db, id: 'i2', title: 'Other');

      await submit('u1', 5);
      await submit('u1', 2, itemId: 'i2');

      expect(await db.collection('feedback').get().then((s) => s.size), 2);
      expect((await itemData('i1'))['averageRating'], 5);
      expect((await itemData('i2'))['averageRating'], 2);
    });

    test('rejects ratings outside 1 to 5', () async {
      for (final bad in [0, 6, -1]) {
        await expectLater(submit('u1', bad), throwsA(isA<AppException>()));
      }
      expect(await feedbackData('i1', 'u1'), isNull);
      expect((await itemData('i1'))['ratingCount'], 0);
    });

    test('rejects an item that does not exist', () async {
      await expectLater(
        submit('u1', 4, itemId: 'ghost'),
        throwsA(isA<AppException>()),
      );
      expect(await db.collection('feedback').get().then((s) => s.size), 0);
    });

    test('an inactive item takes no new feedback', () async {
      await db.collection('items').doc('i1').update({'isActive': false});

      await expectLater(
        submit('u1', 4),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('no longer accepting'),
          ),
        ),
      );
      expect((await itemData('i1'))['ratingCount'], 0);
    });

    test('an inactive item still lets an existing review be edited', () async {
      await submit('u1', 5);
      await db.collection('items').doc('i1').update({'isActive': false});

      await submit('u1', 3);

      expect((await feedbackData('i1', 'u1'))!['rating'], 3);
      expect((await itemData('i1'))['averageRating'], 3);
    });
  });

  group('deleteFeedback', () {
    test('removes the review and takes its rating out of the item', () async {
      await submit('u1', 5);
      await submit('u2', 3);

      await repository.deleteFeedback('i1_u1');

      expect(await feedbackData('i1', 'u1'), isNull);
      final item = await itemData('i1');
      expect(item['ratingCount'], 1);
      expect(item['ratingSum'], 3);
      expect(item['averageRating'], 3);
    });

    test('deleting the last review resets the average to zero', () async {
      await submit('u1', 4);

      await repository.deleteFeedback('i1_u1');

      final item = await itemData('i1');
      expect(item['ratingCount'], 0);
      expect(item['ratingSum'], 0);
      expect(item['averageRating'], 0);
    });

    test('deleting a review that is already gone does nothing', () async {
      await submit('u1', 4);

      await repository.deleteFeedback('i1_nobody');

      expect((await itemData('i1'))['ratingCount'], 1);
    });

    test('a user can review again after deleting', () async {
      await submit('u1', 5);
      await repository.deleteFeedback('i1_u1');

      await submit('u1', 2);

      final item = await itemData('i1');
      expect(item['ratingCount'], 1);
      expect(item['averageRating'], 2);
    });
  });

  group('watchMyFeedback', () {
    test('returns only that user\'s reviews', () async {
      await seedItem(db, id: 'i2', title: 'Other');
      await submit('u1', 5);
      await submit('u1', 4, itemId: 'i2');
      await submit('u2', 3);

      final mine = await repository.watchMyFeedback('u1').first;

      expect(mine.map((f) => f.itemId).toSet(), {'i1', 'i2'});
      expect(mine.every((f) => f.userId == 'u1'), isTrue);
    });

    test('is empty when the user has left nothing', () async {
      expect(await repository.watchMyFeedback('u1').first, isEmpty);
    });

    test('updates live when a review is added', () async {
      final emissions = <int>[];
      final sub = repository
          .watchMyFeedback('u1')
          .listen((list) => emissions.add(list.length));

      await Future<void>.delayed(Duration.zero);
      await submit('u1', 5);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions, containsAllInOrder([0, 1]));
    });
  });
}
