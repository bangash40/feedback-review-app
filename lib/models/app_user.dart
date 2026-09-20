import 'package:cloud_firestore/cloud_firestore.dart';

/// Role stored on the user profile. Admins are promoted out-of-band
/// (Firebase console); the client can only ever create `user` profiles.
enum UserRole {
  user,
  admin;

  static UserRole fromName(String? name) =>
      UserRole.values.firstWhere((r) => r.name == name, orElse: () => user);
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

  bool get isAdmin => role == UserRole.admin;

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

  AppUser copyWith({String? name}) => AppUser(
    uid: uid,
    name: name ?? this.name,
    email: email,
    role: role,
    createdAt: createdAt,
  );
}
