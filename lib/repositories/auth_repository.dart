import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Authentication plus the `users/{uid}` profile document that holds the role.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required FirestoreService firestoreService,
  }) : _auth = authService,
       _firestore = firestoreService;

  final AuthService _auth;
  final FirestoreService _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Live profile for [uid]; emits null while the document does not exist.
  Stream<AppUser?> watchUser(String uid) {
    return _firestore.users.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : AppUser.fromMap(data);
    });
  }

  /// Creates the account and its profile. The role is always `user`; admins
  /// are promoted out-of-band in the Firebase console.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signUp(email: email, password: password);
    await _createProfile(
      uid: credential.user!.uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    final credential = await _auth.signIn(email: email, password: password);
    await _ensureProfile(credential.user!);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email.trim());

  /// Changes the display name on the profile document. The security rules
  /// allow a user to change only their own name, nothing else.
  Future<void> updateName({required String uid, required String name}) {
    return _firestore.users.doc(uid).update({'name': name.trim()});
  }

  Future<void> _createProfile({
    required String uid,
    required String name,
    required String email,
  }) {
    final profile = AppUser(
      uid: uid,
      name: name,
      email: email,
      role: UserRole.user,
      createdAt: DateTime.now(),
    );
    return _firestore.users.doc(uid).set(profile.toMap());
  }

  /// Recreates a missing profile, e.g. when sign-up created the auth account
  /// but the profile write failed (network drop), so the user is not stuck.
  Future<void> _ensureProfile(User user) async {
    final doc = await _firestore.users.doc(user.uid).get();
    if (doc.exists) return;
    final email = (user.email ?? '').toLowerCase();
    await _createProfile(
      uid: user.uid,
      name: user.displayName ?? email.split('@').first,
      email: email,
    );
  }
}
