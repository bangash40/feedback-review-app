import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/utils/app_exception.dart';
import '../../../providers/auth_providers.dart';

/// Call from a screen's `build` to show auth failures as they happen.
///
/// Reacts only to a genuine [AsyncError]. While a retry is loading, the
/// controller's state is an `AsyncLoading` that still carries the previous
/// error (`hasError` is true), and reacting to that would replay the old
/// pop-up on every new attempt.
void listenForAuthErrors(BuildContext context, WidgetRef ref) {
  ref.listen(authControllerProvider, (_, next) {
    if (next is AsyncError) showAuthError(context, next.error);
  });
}

/// Tells the user why an auth action failed.
///
/// When the account does not exist a dialog offers to go to the sign-up
/// screen; every other failure is a snackbar.
void showAuthError(BuildContext context, Object error) {
  // Screens pushed on top of each other (login -> forgot password) all listen
  // to the same auth controller; only the visible one should react.
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;

  final exception = AppException.from(error);

  if (exception.suggestSignUp) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.person_add_alt_1_outlined),
        title: const Text('No account found'),
        content: Text(exception.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push(AppRoutes.register);
            },
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
    return;
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(exception.message)));
}
