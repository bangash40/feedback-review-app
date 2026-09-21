import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../models/feedback_model.dart';
import '../repositories/feedback_repository.dart';
import 'async_action_runner.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

/// The signed-in user's own feedback, most recently changed first.
final myFeedbackProvider = StreamProvider<List<FeedbackModel>>((ref) {
  final uid = ref.watch(signedInUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(feedbackRepositoryProvider).watchMyFeedback(uid);
});

/// The signed-in user's review of one item, or null if they have not left one.
/// Derived from [myFeedbackProvider], so it needs no listener of its own.
final myFeedbackForItemProvider =
    Provider.family<AsyncValue<FeedbackModel?>, String>((ref, itemId) {
      return ref
          .watch(myFeedbackProvider)
          .whenData(
            (list) => list.where((f) => f.itemId == itemId).firstOrNull,
          );
    });

/// Submits, edits and deletes the user's feedback, exposing loading / error
/// state to the screens.
class FeedbackController extends AsyncNotifier<void> with AsyncActionRunner {
  @override
  Future<void> build() async {}

  FeedbackRepository get _repository => ref.read(feedbackRepositoryProvider);

  /// Creates the user's review of [itemId], or updates it if one exists.
  Future<bool> submit({
    required String itemId,
    required int rating,
    String review = '',
    String suggestion = '',
  }) {
    return runAction(() async {
      final uid = ref.read(signedInUidProvider);
      if (uid == null) throw const AppException('Please log in again.');
      final name = ref.read(currentUserProvider).value?.name;
      await _repository.submit(
        itemId: itemId,
        userId: uid,
        userName: (name == null || name.isEmpty) ? 'User' : name,
        rating: rating,
        review: review,
        suggestion: suggestion,
      );
    });
  }

  Future<bool> delete(FeedbackModel feedback) {
    return runAction(() => _repository.deleteFeedback(feedback.id));
  }
}

final feedbackControllerProvider =
    AsyncNotifierProvider<FeedbackController, void>(FeedbackController.new);
