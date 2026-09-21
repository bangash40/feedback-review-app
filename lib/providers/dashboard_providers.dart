import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback_model.dart';
import '../models/item.dart';
import 'auth_providers.dart';
import 'feedback_providers.dart';

/// How the dashboard's feedback list is ordered.
enum FeedbackSort {
  newest('Newest first'),
  oldest('Oldest first'),
  highest('Highest rating'),
  lowest('Lowest rating');

  const FeedbackSort(this.label);

  final String label;
}

/// The dashboard's current filters and sort order. All filters are optional
/// (null = no restriction) and combine with AND.
class FeedbackFilter {
  const FeedbackFilter({
    this.itemId,
    this.itemType,
    this.rating,
    this.sort = FeedbackSort.newest,
  });

  final String? itemId;
  final ItemType? itemType;

  /// Only feedback with exactly this star rating (1 to 5).
  final int? rating;
  final FeedbackSort sort;

  /// True if any filter (not the sort order) is set.
  bool get isActive => itemId != null || itemType != null || rating != null;

  static const _keep = Object();

  /// Pass an explicit null to clear a filter; omit a field to keep it.
  FeedbackFilter copyWith({
    Object? itemId = _keep,
    Object? itemType = _keep,
    Object? rating = _keep,
    FeedbackSort? sort,
  }) {
    return FeedbackFilter(
      itemId: identical(itemId, _keep) ? this.itemId : itemId as String?,
      itemType: identical(itemType, _keep)
          ? this.itemType
          : itemType as ItemType?,
      rating: identical(rating, _keep) ? this.rating : rating as int?,
      sort: sort ?? this.sort,
    );
  }

  /// Whether [feedback] passes the item and type filters.
  bool matchesItemAndType(FeedbackModel feedback) {
    if (itemId != null && feedback.itemId != itemId) return false;
    if (itemType != null && feedback.itemType != itemType) return false;
    return true;
  }

  bool matches(FeedbackModel feedback) {
    return matchesItemAndType(feedback) &&
        (rating == null || feedback.rating == rating);
  }
}

class FeedbackFilterController extends Notifier<FeedbackFilter> {
  @override
  FeedbackFilter build() {
    // Start fresh for whoever signs in next.
    ref.watch(signedInUidProvider);
    return const FeedbackFilter();
  }

  void setItem(String? itemId) => state = state.copyWith(itemId: itemId);

  /// Changing the type also drops the item filter, which may belong to a
  /// different type.
  void setType(ItemType? type) =>
      state = state.copyWith(itemType: type, itemId: null);

  void setRating(int? rating) => state = state.copyWith(rating: rating);

  void setSort(FeedbackSort sort) => state = state.copyWith(sort: sort);

  /// Clears every filter but keeps the chosen sort order.
  void clear() => state = FeedbackFilter(sort: state.sort);
}

final feedbackFilterProvider =
    NotifierProvider<FeedbackFilterController, FeedbackFilter>(
      FeedbackFilterController.new,
    );

/// Every recent feedback entry, live. Only admins may read it, so it stays
/// empty for anyone else instead of asking Firestore for something it denies.
final allFeedbackProvider = StreamProvider<List<FeedbackModel>>((ref) {
  final isAdmin = ref.watch(
    currentUserProvider.select((user) => user.value?.isAdmin ?? false),
  );
  if (!isAdmin) return Stream.value(const []);
  return ref.watch(feedbackRepositoryProvider).watchAllFeedback();
});

/// One feedback entry by id (admin detail screen).
final feedbackByIdProvider = StreamProvider.family<FeedbackModel?, String>((
  ref,
  id,
) {
  final isAdmin = ref.watch(
    currentUserProvider.select((user) => user.value?.isAdmin ?? false),
  );
  if (!isAdmin) return Stream.value(null);
  return ref.watch(feedbackRepositoryProvider).watchFeedback(id);
});

/// Summary numbers for a set of feedback.
class FeedbackStats {
  const FeedbackStats({
    required this.total,
    required this.average,
    required this.distribution,
  });

  factory FeedbackStats.from(Iterable<FeedbackModel> feedback) {
    // Index 0 counts 1-star ratings ... index 4 counts 5-star ratings.
    final distribution = List<int>.filled(5, 0);
    var total = 0;
    var sum = 0;
    for (final entry in feedback) {
      if (entry.rating < 1 || entry.rating > 5) continue;
      distribution[entry.rating - 1]++;
      total++;
      sum += entry.rating;
    }
    return FeedbackStats(
      total: total,
      average: total == 0 ? 0 : sum / total,
      distribution: distribution,
    );
  }

  final int total;
  final double average;
  final List<int> distribution;
}

/// Statistics for the item and type filters. The rating filter is ignored so
/// the distribution chart always shows the full spread of ratings.
final feedbackStatsProvider = Provider<AsyncValue<FeedbackStats>>((ref) {
  final filter = ref.watch(feedbackFilterProvider);
  return ref
      .watch(allFeedbackProvider)
      .whenData(
        (all) => FeedbackStats.from(all.where(filter.matchesItemAndType)),
      );
});

/// The list the dashboard shows: filtered, then sorted.
final filteredFeedbackProvider = Provider<AsyncValue<List<FeedbackModel>>>((
  ref,
) {
  final filter = ref.watch(feedbackFilterProvider);
  return ref.watch(allFeedbackProvider).whenData((all) {
    final list = all.where(filter.matches).toList();
    int newestFirst(FeedbackModel a, FeedbackModel b) =>
        b.createdAt.compareTo(a.createdAt);

    switch (filter.sort) {
      case FeedbackSort.newest:
        list.sort(newestFirst);
      case FeedbackSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case FeedbackSort.highest:
        list.sort((a, b) {
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0 ? byRating : newestFirst(a, b);
        });
      case FeedbackSort.lowest:
        list.sort((a, b) {
          final byRating = a.rating.compareTo(b.rating);
          return byRating != 0 ? byRating : newestFirst(a, b);
        });
    }
    return list;
  });
});
