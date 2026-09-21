import 'package:feedback_review_app/models/feedback_model.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:feedback_review_app/providers/auth_providers.dart';
import 'package:feedback_review_app/providers/dashboard_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FeedbackModel entry(
  String id, {
  required int rating,
  String itemId = 'i1',
  ItemType type = ItemType.course,
  int day = 1,
}) {
  final at = DateTime(2026, 1, day);
  return FeedbackModel(
    id: id,
    itemId: itemId,
    itemTitle: 'Item $itemId',
    itemType: type,
    userId: 'u-$id',
    userName: 'User $id',
    rating: rating,
    createdAt: at,
    updatedAt: at,
  );
}

/// A container whose feedback list is [all], signed in as admin.
ProviderContainer containerWith(List<FeedbackModel> all) {
  final container = ProviderContainer(
    overrides: [
      signedInUidProvider.overrideWithValue('admin'),
      allFeedbackProvider.overrideWith((ref) => Stream.value(all)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Waits for the feedback stream's first value. Something must listen to it,
/// as the dashboard does: a provider that is only read is paused by Riverpod.
Future<void> loaded(ProviderContainer container) async {
  container.listen(allFeedbackProvider, (_, _) {}, fireImmediately: true);
  await container.read(allFeedbackProvider.future);
}

/// Loads the feedback stream and returns the ids the dashboard would list.
Future<List<String>> shownIds(ProviderContainer container) async {
  await loaded(container);
  return container
      .read(filteredFeedbackProvider)
      .requireValue
      .map((f) => f.id)
      .toList();
}

void main() {
  // Four entries across three items and two types.
  final data = [
    entry('a', rating: 5, itemId: 'i1', type: ItemType.course, day: 4),
    entry('b', rating: 3, itemId: 'i1', type: ItemType.course, day: 3),
    entry('c', rating: 2, itemId: 'i2', type: ItemType.task, day: 2),
    entry('d', rating: 4, itemId: 'i3', type: ItemType.service, day: 1),
  ];

  group('FeedbackStats', () {
    test('counts, averages and distributes ratings', () {
      final stats = FeedbackStats.from(data);

      expect(stats.total, 4);
      expect(stats.average, 3.5);
      // 1★ 2★ 3★ 4★ 5★
      expect(stats.distribution, [0, 1, 1, 1, 1]);
    });

    test('an empty list is all zeros without dividing by zero', () {
      final stats = FeedbackStats.from(const []);

      expect(stats.total, 0);
      expect(stats.average, 0);
      expect(stats.distribution, [0, 0, 0, 0, 0]);
    });

    test('several entries of the same rating stack up', () {
      final stats = FeedbackStats.from([
        entry('a', rating: 5),
        entry('b', rating: 5),
        entry('c', rating: 1),
      ]);

      expect(stats.distribution, [1, 0, 0, 0, 2]);
      expect(stats.average, closeTo(11 / 3, 1e-9));
    });

    test('ratings outside 1 to 5 are ignored rather than crashing', () {
      final stats = FeedbackStats.from([
        entry('a', rating: 0),
        entry('b', rating: 9),
        entry('c', rating: 4),
      ]);

      expect(stats.total, 1);
      expect(stats.average, 4);
    });
  });

  group('FeedbackFilter', () {
    test('starts with nothing active, newest first', () {
      const filter = FeedbackFilter();

      expect(filter.isActive, isFalse);
      expect(filter.sort, FeedbackSort.newest);
      expect(data.every(filter.matches), isTrue);
    });

    test('matches on item, type and rating together', () {
      const filter = FeedbackFilter(
        itemType: ItemType.course,
        itemId: 'i1',
        rating: 5,
      );

      expect(data.where(filter.matches).map((f) => f.id), ['a']);
      expect(filter.isActive, isTrue);
    });

    test('copyWith keeps what is omitted and clears what is null', () {
      const filter = FeedbackFilter(itemId: 'i1', rating: 3);

      expect(filter.copyWith(rating: 4).itemId, 'i1');
      expect(filter.copyWith(rating: 4).rating, 4);
      expect(filter.copyWith(rating: null).rating, isNull);
      expect(filter.copyWith(rating: null).itemId, 'i1');
      expect(filter.copyWith(sort: FeedbackSort.oldest).rating, 3);
    });
  });

  group('filteredFeedbackProvider', () {
    test('shows everything newest first by default', () async {
      expect(await shownIds(containerWith(data)), ['a', 'b', 'c', 'd']);
    });

    test('filters by rating', () async {
      final container = containerWith(data);
      container.read(feedbackFilterProvider.notifier).setRating(3);

      expect(await shownIds(container), ['b']);
    });

    test('filters by type', () async {
      final container = containerWith(data);
      container.read(feedbackFilterProvider.notifier).setType(ItemType.course);

      expect(await shownIds(container), ['a', 'b']);
    });

    test('filters by item', () async {
      final container = containerWith(data);
      container.read(feedbackFilterProvider.notifier).setItem('i2');

      expect(await shownIds(container), ['c']);
    });

    test('filters combine, and can yield nothing', () async {
      final container = containerWith(data);
      final filter = container.read(feedbackFilterProvider.notifier);
      filter.setType(ItemType.course);
      filter.setRating(2);

      expect(await shownIds(container), isEmpty);
    });

    test('sorts oldest first', () async {
      final container = containerWith(data);
      container
          .read(feedbackFilterProvider.notifier)
          .setSort(FeedbackSort.oldest);

      expect(await shownIds(container), ['d', 'c', 'b', 'a']);
    });

    test('sorts by highest rating, newest first among equals', () async {
      final container = containerWith([
        ...data,
        entry('e', rating: 5, day: 9), // ties with 'a' but is newer
      ]);
      container
          .read(feedbackFilterProvider.notifier)
          .setSort(FeedbackSort.highest);

      expect(await shownIds(container), ['e', 'a', 'd', 'b', 'c']);
    });

    test('sorts by lowest rating, newest first among equals', () async {
      final container = containerWith([
        ...data,
        entry('e', rating: 2, day: 9), // ties with 'c' but is newer
      ]);
      container
          .read(feedbackFilterProvider.notifier)
          .setSort(FeedbackSort.lowest);

      expect(await shownIds(container), ['e', 'c', 'b', 'd', 'a']);
    });

    test('changing the filter type drops a mismatched item filter', () async {
      final container = containerWith(data);
      final filter = container.read(feedbackFilterProvider.notifier);
      filter.setItem('i1');
      filter.setType(ItemType.task);

      expect(container.read(feedbackFilterProvider).itemId, isNull);
      expect(await shownIds(container), ['c']);
    });

    test('clear removes filters but keeps the sort order', () async {
      final container = containerWith(data);
      final filter = container.read(feedbackFilterProvider.notifier);
      filter.setRating(5);
      filter.setType(ItemType.course);
      filter.setSort(FeedbackSort.lowest);

      filter.clear();

      final state = container.read(feedbackFilterProvider);
      expect(state.isActive, isFalse);
      expect(state.sort, FeedbackSort.lowest);
      expect(await shownIds(container), ['c', 'b', 'd', 'a']);
    });
  });

  group('feedbackStatsProvider', () {
    Future<FeedbackStats> statsFor(ProviderContainer container) async {
      await loaded(container);
      return container.read(feedbackStatsProvider).requireValue;
    }

    test('covers all feedback when nothing is filtered', () async {
      final stats = await statsFor(containerWith(data));

      expect(stats.total, 4);
      expect(stats.average, 3.5);
    });

    test('follows the item filter: count and average of that item', () async {
      final container = containerWith(data);
      container.read(feedbackFilterProvider.notifier).setItem('i1');

      final stats = await statsFor(container);

      expect(stats.total, 2);
      expect(stats.average, 4);
    });

    test('follows the type filter', () async {
      final container = containerWith(data);
      container.read(feedbackFilterProvider.notifier).setType(ItemType.task);

      final stats = await statsFor(container);

      expect(stats.total, 1);
      expect(stats.average, 2);
    });

    test(
      'ignores the rating filter so the chart keeps its full shape',
      () async {
        final container = containerWith(data);
        container.read(feedbackFilterProvider.notifier).setRating(5);

        final stats = await statsFor(container);

        expect(stats.total, 4);
        expect(stats.distribution, [0, 1, 1, 1, 1]);
      },
    );
  });
}
