import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../repositories/auth_repository.dart';
import 'async_action_runner.dart';
import 'firebase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authService: ref.watch(authServiceProvider),
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

/// The signed-in Firebase user, or null when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// The signed-in user's id, or null when signed out.
///
/// Providers that read Firestore data watch this so they rebuild whenever the
/// user changes. Otherwise a listener opened for one user outlives the
/// sign-out, gets PERMISSION_DENIED from Firestore, and the next user would
/// be shown that stale error until they pressed Retry.
final signedInUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((auth) => auth.value?.uid));
});

/// The signed-in user's profile document (gives the role). Emits null when
/// signed out or while the profile document does not exist yet.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(signedInUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUser(uid);
});

/// Runs the auth actions and exposes loading / error state to the forms.
class AuthController extends AsyncNotifier<void> with AsyncActionRunner {
  @override
  Future<void> build() async {}

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) {
    return runAction(
      () => _repository.signIn(email: email.trim(), password: password),
    );
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return runAction(
      () => _repository.signUp(name: name, email: email, password: password),
    );
  }

  Future<bool> sendPasswordReset(String email) {
    return runAction(() => _repository.sendPasswordReset(email));
  }

  Future<bool> signOut() => runAction(_repository.signOut);
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

/// Runs profile edits (currently just the display name).
class ProfileController extends AsyncNotifier<void> with AsyncActionRunner {
  @override
  Future<void> build() async {}

  Future<bool> updateName(String name) {
    return runAction(() async {
      final uid = ref.read(signedInUidProvider);
      if (uid == null) throw const AppException('Please log in again.');
      await ref.read(authRepositoryProvider).updateName(uid: uid, name: name);
    });
  }
}

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, void>(ProfileController.new);
