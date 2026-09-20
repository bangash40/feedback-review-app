import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../repositories/user_repository.dart';
import '../services/firestore_service.dart';
import 'async_action_runner.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(firestoreService: ref.watch(firestoreServiceProvider));
});

/// What the Manage users screen is showing.
class UserSearchState {
  const UserSearchState({
    this.query = '',
    this.adminsOnly = false,
    this.users = const [],
    this.hasMore = false,
    this.cursor,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final String query;
  final bool adminsOnly;
  final List<AppUser> users;
  final bool hasMore;
  final DocumentSnapshot<JsonMap>? cursor;
  final bool isLoadingMore;
  final bool loadMoreFailed;

  UserSearchState copyWith({
    List<AppUser>? users,
    bool? hasMore,
    DocumentSnapshot<JsonMap>? cursor,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return UserSearchState(
      query: query,
      adminsOnly: adminsOnly,
      users: users ?? this.users,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// Search box + "Admins only" filter + paging over all users.
class UserSearch extends AsyncNotifier<UserSearchState> {
  /// Identifies the latest request so a slow, older search can never
  /// overwrite the results of a newer one.
  int _requestId = 0;

  UserRepository get _repository => ref.read(userRepositoryProvider);

  @override
  Future<UserSearchState> build() {
    // Start over (empty search) whenever a different user signs in, and do not
    // query at all while signed out (Firestore would deny it).
    final uid = ref.watch(signedInUidProvider);
    if (uid == null) return Future.value(const UserSearchState());
    return _loadFirstPage(query: '', adminsOnly: false);
  }

  Future<UserSearchState> _loadFirstPage({
    required String query,
    required bool adminsOnly,
  }) async {
    final page = await _repository.searchUsers(
      emailPrefix: query,
      adminsOnly: adminsOnly,
    );
    return UserSearchState(
      query: query,
      adminsOnly: adminsOnly,
      users: page.users,
      hasMore: page.hasMore,
      cursor: page.cursor,
    );
  }

  /// Runs a new search, keeping whatever is not passed.
  Future<void> search({String? query, bool? adminsOnly}) async {
    final current = state.value ?? const UserSearchState();
    final nextQuery = query ?? current.query;
    final nextAdminsOnly = adminsOnly ?? current.adminsOnly;
    if (nextQuery == current.query && nextAdminsOnly == current.adminsOnly) {
      return;
    }

    final requestId = ++_requestId;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _loadFirstPage(query: nextQuery, adminsOnly: nextAdminsOnly),
    );
    if (requestId == _requestId) state = result;
  }

  /// Reloads the current search from the first page.
  Future<void> refresh() async {
    final current = state.value ?? const UserSearchState();
    final requestId = ++_requestId;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () =>
          _loadFirstPage(query: current.query, adminsOnly: current.adminsOnly),
    );
    if (requestId == _requestId) state = result;
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final requestId = _requestId;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreFailed: false),
    );
    try {
      final page = await _repository.searchUsers(
        emailPrefix: current.query,
        adminsOnly: current.adminsOnly,
        startAfter: current.cursor,
      );
      if (requestId != _requestId) return;
      state = AsyncData(
        current.copyWith(
          users: [...current.users, ...page.users],
          hasMore: page.hasMore,
          cursor: page.cursor,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      if (requestId != _requestId) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreFailed: true),
      );
    }
  }

  /// Reflects a successful role change in the visible list.
  void applyRole(String uid, UserRole role) {
    final current = state.value;
    if (current == null) return;
    final users = [
      for (final user in current.users)
        if (user.uid == uid) user.copyWith(role: role) else user,
    ];
    // In "Admins only" a demoted user no longer belongs in the list.
    state = AsyncData(
      current.copyWith(
        users: current.adminsOnly
            ? users.where((user) => user.isAdmin).toList()
            : users,
      ),
    );
  }
}

final userSearchProvider = AsyncNotifierProvider<UserSearch, UserSearchState>(
  UserSearch.new,
);

/// Changes a user's role, exposing loading / error state to the screen.
class RoleController extends AsyncNotifier<void> with AsyncActionRunner {
  @override
  Future<void> build() async {}

  /// Sets [target]'s role to [role] (user or admin). Only the super admin may
  /// do this, and never to themselves.
  Future<bool> setRole(AppUser target, UserRole role) {
    return runAction(() async {
      final acting = ref.read(currentUserProvider).value;
      if (acting == null || !acting.isSuperAdmin) {
        throw const AppException('Only the super admin can change roles.');
      }
      if (target.uid == acting.uid) {
        throw const AppException("You can't change your own role.");
      }
      await ref
          .read(userRepositoryProvider)
          .setRole(uid: target.uid, role: role);
      ref.read(userSearchProvider.notifier).applyRole(target.uid, role);
    });
  }
}

final roleControllerProvider = AsyncNotifierProvider<RoleController, void>(
  RoleController.new,
);
