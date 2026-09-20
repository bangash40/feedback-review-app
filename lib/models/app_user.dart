import 'package:cloud_firestore/cloud_firestore.dart';

/// Role stored on the user profile.
///
/// - [user] reviews items.
/// - [admin] manages items and reads all feedback.
/// - [superAdmin] is an admin who can also change other users' roles. It is
///   only ever set by hand in the Firebase console; the app cannot grant it.
///
/// The stored string is the enum name, so the console value for a super admin
/// is exactly `superAdmin`.
enum UserRole {
  user,
  admin,
  superAdmin;

  static UserRole fromName(String? name) =>
      UserRole.values.firstWhere((r) => r.name == name, orElse: () => user);

  /// Human-readable label for the UI.
  String get label => switch (this) {
    UserRole.user => 'User',
    UserRole.admin => 'Admin',
    UserRole.superAdmin => 'Super admin',
  };
}

/// A user profile document: `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  /// True for admins and the super admin: both get the admin screens.
  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;

  bool get isSuperAdmin => role == UserRole.superAdmin;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: UserRole.fromName(map['role'] as String?),
      // createdAt is null briefly on the local snapshot of a pending
      // server-timestamp write, so fall back to "now".
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'role': role.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  AppUser copyWith({String? name, UserRole? role}) => AppUser(
    uid: uid,
    name: name ?? this.name,
    email: email,
    role: role ?? this.role,
    createdAt: createdAt,
  );
}
