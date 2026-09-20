import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/app_exception.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';

/// One page of user search results.
class UserPage {
  const UserPage({required this.users, required this.hasMore, this.cursor});

  final List<AppUser> users;

  /// Pass back as `startAfter` to fetch the next page.
  final DocumentSnapshot<JsonMap>? cursor;
  final bool hasMore;
}

/// Reads other users' profiles and changes their roles (super admin only;
/// enforced by Firestore rules, and checked here as well).
class UserRepository {
  UserRepository({required FirestoreService firestoreService})
    : _firestore = firestoreService;

  final FirestoreService _firestore;

  /// How many admins the "Admins only" view loads. There are few admins, so
  /// this list is not paged.
  static const adminListLimit = 100;

  /// Finds users whose email starts with [emailPrefix] (case-insensitive,
  /// since emails are stored lowercase), ordered by email and paged.
  ///
  /// With [adminsOnly] it lists admins and super admins instead, filtered by
  /// the same prefix on the client. That avoids a composite index and the
  /// list is short anyway.
  Future<UserPage> searchUsers({
    String emailPrefix = '',
    bool adminsOnly = false,
    int limit = 20,
    DocumentSnapshot<JsonMap>? startAfter,
  }) async {
    final prefix = emailPrefix.trim().toLowerCase();
    return adminsOnly
        ? _searchAdmins(prefix)
        : _searchAll(prefix, limit, startAfter);
  }

  Future<UserPage> _searchAll(
    String prefix,
    int limit,
    DocumentSnapshot<JsonMap>? startAfter,
  ) async {
    Query<JsonMap> query = _firestore.users.orderBy('email');
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    } else if (prefix.isNotEmpty) {
      query = query.startAt([prefix]);
    }
    if (prefix.isNotEmpty) query = query.endAt(['$prefix']);

    // Ask for one extra document to learn whether another page exists.
    final snapshot = await query.limit(limit + 1).get();
    final docs = snapshot.docs;
    final hasMore = docs.length > limit;
    final page = hasMore ? docs.sublist(0, limit) : docs;

    return UserPage(
      users: page.map((doc) => AppUser.fromMap(doc.data())).toList(),
      hasMore: hasMore,
      cursor: page.isEmpty ? null : page.last,
    );
  }

  Future<UserPage> _searchAdmins(String prefix) async {
    final snapshot = await _firestore.users
        .where('role', whereIn: [UserRole.admin.name, UserRole.superAdmin.name])
        .limit(adminListLimit)
        .get();

    final users =
        snapshot.docs
            .map((doc) => AppUser.fromMap(doc.data()))
            .where((user) => user.email.startsWith(prefix))
            .toList()
          ..sort((a, b) => a.email.compareTo(b.email));
    return UserPage(users: users, hasMore: false);
  }

  /// Sets [uid]'s role to [role], which must be `user` or `admin`.
  ///
  /// Runs in a transaction that re-reads the target, so a stale screen can
  /// never demote a super admin who was promoted after the list loaded.
  Future<void> setRole({required String uid, required UserRole role}) async {
    if (role == UserRole.superAdmin) {
      throw const AppException(
        'The super admin role can only be set in the Firebase console.',
      );
    }
    final doc = _firestore.users.doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data();
      if (data == null) throw const AppException('That user no longer exists.');
      if (UserRole.fromName(data['role'] as String?) == UserRole.superAdmin) {
        throw const AppException("The super admin's role cannot be changed.");
      }
      transaction.update(doc, {'role': role.name});
    });
  }
}
