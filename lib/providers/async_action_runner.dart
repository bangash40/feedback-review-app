import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';

/// Shared plumbing for "controller" notifiers that run one action at a time
/// and expose loading / error state to a form.
mixin AsyncActionRunner on AsyncNotifier<void> {
  /// Runs [action]. Returns true on success; a failure becomes an
  /// [AppException] in `state` and the method returns false.
  Future<bool> runAction(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(AppException.from(error), stackTrace);
      return false;
    }
  }
}
